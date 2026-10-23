#!/usr/bin/env python3
"""Send two controlled requests to ubu1 and emit HTTP-only JSON evidence.

This script never queries Loki or changes a service. HTTP 403 alone does not
prove ModSecurity/CRS blocked the request: match the correlation ID against the
separate ubu2 audit stream before accepting the WAF requirement.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import http.client
import json
import re
import socket
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid


WEB_IP = "10.77.42.2"
BODY_SAMPLE_LIMIT = 65_536


class NoRedirects(urllib.request.HTTPRedirectHandler):
    """A lab redirect must never turn this into a request to another host."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="milliseconds")


def validate_web_url(value: str) -> str:
    """Allow only the reviewed ubu1 WireGuard IPv4 HTTP/80 endpoint."""
    try:
        parsed = urllib.parse.urlsplit(value)
        allowed = (
            parsed.scheme == "http"
            and parsed.hostname == WEB_IP
            and parsed.port in (None, 80)
            and parsed.username is None
            and parsed.password is None
            and parsed.path in ("", "/")
            and not parsed.query
            and not parsed.fragment
            and parsed.netloc in (WEB_IP, f"{WEB_IP}:80")
        )
    except (ValueError, TypeError):
        allowed = False
    if not allowed:
        # Do not echo an invalid URL that might contain credentials.
        raise argparse.ArgumentTypeError(
            "web URL must be exactly http://10.77.42.2[:80][/], without credentials"
        )
    return f"http://{WEB_IP}:80"


def bounded_timeout(value: str) -> float:
    try:
        number = float(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("timeout must be a number") from exc
    if not 0.1 <= number <= 30:
        raise argparse.ArgumentTypeError("timeout must be between 0.1 and 30 seconds")
    return number


def request_once(opener, base_url, case, target, expected, correlation_id, timeout):
    evidence = {
        "case": case,
        "started_at_utc": utc_now(),
        "method": "GET",
        "target": target,
        "correlation_id": correlation_id,
        "expected_http_status": expected,
        "actual_http_status": None,
        "http_status_matches": False,
    }
    request = urllib.request.Request(
        base_url + target,
        method="GET",
        headers={
            "User-Agent": "OZZYLOGIK-Lab-Verification/1.0",
            "X-Lab-Correlation-ID": correlation_id,
            "Accept": "text/html",
        },
    )
    started = time.monotonic()
    response = None
    try:
        try:
            response = opener.open(request, timeout=timeout)
        except urllib.error.HTTPError as exc:
            # HTTPError also carries the response to intentional 403/redirects.
            response = exc
        evidence["actual_http_status"] = response.status
        evidence["http_status_matches"] = response.status == expected
        request_id = response.headers.get("X-Lab-Request-ID", "")
        if re.fullmatch(r"[0-9a-f]{32}", request_id):
            evidence["nginx_request_id"] = request_id
        body = response.read(BODY_SAMPLE_LIMIT + 1)
        sample = body[:BODY_SAMPLE_LIMIT]
        evidence["body_sample_bytes"] = len(sample)
        evidence["body_sample_truncated"] = len(body) > BODY_SAMPLE_LIMIT
        evidence["body_sample_sha256"] = hashlib.sha256(sample).hexdigest()
    except urllib.error.URLError as exc:
        evidence["transport_error"] = (
            "timeout" if isinstance(exc.reason, (TimeoutError, socket.timeout)) else "connection_failed"
        )
    except (TimeoutError, socket.timeout):
        evidence["transport_error"] = "timeout"
    except http.client.HTTPException:
        evidence["transport_error"] = "http_protocol_failed"
    except OSError:
        evidence["transport_error"] = "io_failed"
    finally:
        if response is not None:
            response.close()
        evidence["elapsed_ms"] = round((time.monotonic() - started) * 1_000, 1)
        evidence["finished_at_utc"] = utc_now()
    return evidence


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--web-url", required=True, type=validate_web_url,
        help="explicit approved target: http://10.77.42.2 (HTTP/80 only)",
    )
    parser.add_argument("--timeout", type=bounded_timeout, default=10.0)
    args = parser.parse_args()

    # Ignore HTTP(S)_PROXY and never follow redirects to an unrelated service.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirects())
    run_id = uuid.uuid4().hex
    sql_query = urllib.parse.urlencode({"id": "1' OR 1=1-- -"})
    cases = [
        ("normal", "/", 200, f"ozzylogik-normal-{run_id}"),
        ("sqli", f"/?{sql_query}", 403, f"ozzylogik-sqli-{run_id}"),
    ]
    results = [
        request_once(opener, args.web_url, case, target, expected, correlation_id, args.timeout)
        for case, target, expected, correlation_id in cases
    ]
    passed = all(item["http_status_matches"] and "transport_error" not in item for item in results)
    report = {
        "schema_version": 1,
        "run_id": run_id,
        "web_url": args.web_url,
        "http_status_checks_passed": passed,
        "centralized_log_checks_performed": False,
        "waf_audit_pending": True,
        "acceptance_complete": False,
        "remaining_evidence": [
            "Locate the normal correlation ID in the ubu2 Nginx access stream.",
            "Locate the SQLi correlation ID in both ubu2 access and ModSecurity audit streams.",
            "Confirm audit response 403, enabled rule engine, CRS detection/blocking rule IDs and real client IP.",
        ],
        "requests": results,
    }
    print(json.dumps(report, indent=2, ensure_ascii=True))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
