# web_waf

Deploys a static page directly from Nginx in the official OWASP ModSecurity/CRS image. There is no application upstream or Python service to maintain. The complete custom `nginx.conf` excludes generated `conf.d` proxy/TLS/metrics servers, so the container has one IPv4 HTTP/80 listener.

## Inputs and dependencies

- Ansible collection: **community.docker 5.4.0** (requires ansible-core >=2.17); the root `requirements.yml` must pin it.
- Required `lab_docker_package_version`: exact `apt-cache policy docker.io` candidate observed on the cloned Ubuntu VM and recorded in the local deployment manifest. Empty by default and deployment stops rather than guessing. `docker.io=<version>` is installed with `allow_downgrade: false`.
- `lab_web_http_port=80`, `lab_web_bind_address=0.0.0.0`; the separately approved guest firewall owns admission policy. No Docker published ports/bridge DNAT are used: `network_mode: host` keeps incoming traffic in the host INPUT path. The role does not change firewall policy.
- Shared collector contract: `lab_web_log_dir=/var/log/ozzylogik/nginx`, `lab_log_group=lab-logs`, `lab_log_group_gid=2800`. The pinned image worker UID is checked against `lab_web_nginx_uid=101` before starting the web container.
- Distribution support packages `python3-requests` and `logrotate` use Ubuntu repositories/security updates; record their actual deployed package versions with the deployment evidence. These are not floating container/component tags.

## Immutable component pin, checked 23.10.2026

`owasp/modsecurity-crs:4.30.0-nginx-202610180210@sha256:7698c48a41a43138ae317feeec964d1515b861cc1d9e50617bc1cdfe9f314e1d`

The digest is the multi-platform index, with `platform: linux/amd64`; Docker Hub returned amd64 manifest `sha256:0205eea12a0c1c80eb6fe045e93ae2770824712848fe59b347ed45e46666afe4`. The image fixes CRS and the included Nginx/ModSecurity build together. Runtime evidence must still record `nginx -V` and the audit `transaction.producer` versions.

Official sources: [Docker Hub exact tag metadata](https://hub.docker.com/v2/repositories/owasp/modsecurity-crs/tags/4.30.0-nginx-202610180210), [image documentation](https://github.com/coreruleset/modsecurity-crs-docker), [upstream setup.conf](https://github.com/coreruleset/modsecurity-crs-docker/blob/main/src/etc/modsecurity.d/setup.conf), [collection release](https://github.com/ansible-collections/community.docker/releases/tag/5.4.0).

## WAF, correlation and privilege model

`MODSEC_RULE_ENGINE=On`, CRS blocking paranoia 1 and inbound anomaly threshold 5 are explicit. `/etc/modsecurity.d/setup.conf` loads the supplied ModSecurity config, CRS setup and all CRS rule files. `RelevantOnly` records blocked/relevant transactions as serial JSON with request headers (part B), response headers and rule messages; successful requests are in the JSON access log. Audit request headers preserve `X-Lab-Correlation-ID`; access JSON records it alongside the socket client IP and Nginx `$request_id`. `modsecurity_transaction_id` uses that same request ID. Unique IDs are not Loki labels.

The actual TCP peer is logged; there is no trust of caller-provided X-Forwarded-For. Host networking adds no Docker source NAT. Routing through WireGuard must preserve the intended source as verified separately. A fabricated `X-Forwarded-For` should not change `client_ip`.

The official image normally runs unprivileged and rejects low `PORT`/`SSL_PORT` environment values before reading custom Nginx configuration. The role retains its unused 8080/8443 template defaults, runs a root Nginx master with CHOWN/DAC_OVERRIDE/FOWNER/NET_BIND_SERVICE/SETUID/SETGID capabilities, and explicitly binds 80 in the custom config. FOWNER lets startup generators preserve permissions on image files owned by the worker user. Workers run as image user `nginx`; no 8080/8443 listener is included. The custom healthcheck uses HTTP/80. The image needs a writable container root filesystem for its startup generators; host site/config mounts are read-only, and only the host log directory is writable. The restart handler restarts the existing container without reconciling a partial container specification.

This unauthenticated static lab must not receive real credentials, cookies or tokens. ModSecurity v3 does not support the sanitiseRequestHeader action, so no unsupported redaction claim is made. Access JSON omits query strings/auth headers; audit evidence can contain supplied request headers/URI. Use only controlled test traffic and clean evidence before sharing.

## Rotation and runtime evidence

Host logs rotate by rename/create, daily or above 20M when a five-minute timer checks; fourteen archives are retained, with compression delayed one generation. This is an evaluated size threshold, not a hard disk quota. Container diagnostic logs separately use Docker's bounded local driver (10m × 3).

The first runtime rotation test found that HUP left the Nginx master's ModSecurity serial audit descriptor on the rotated inode. The applied postrotate helper validates Nginx, restarts the existing WAF container, then waits for the local HTTP/80 healthcheck. This closes the old descriptors at the cost of a short HTTP interruption; no `copytruncate` is used. Two rotation rounds passed: unique requests appeared in active access/audit files and each expected central record appeared once; five gzip archives, the active timer and the successful rotation service were checked.

Runtime acceptance demonstrated normal 200, SQLi 403, audit engine Enabled/CRS rule IDs, both centralized streams, the real WG client IP, listed unrelated ports closed and two rotations. HTTP/WAF and central delivery were checked again after approved sequential VM reboots; the full site repeat after reboot returned changed=0 on both guests. Successful tested scenarios do not imply lossless delivery under the combined Loki-outage/Alloy-restart failure documented in the collector role and project verification.
