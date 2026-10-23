# log_shipper

Native Alloy on `ubu1` tails host-mounted Nginx access JSON and ModSecurity serial JSON, then pushes to Loki on `ubu2` over WireGuard. It does not need Docker socket access or secrets. JSON payloads and their correlation/request IDs remain unchanged; only low-cardinality stream labels are added.

## Contract and exact release

- `lab_loki_url=http://10.77.42.1:3100/loki/api/v1/push` is the approved `ubu2` WG endpoint; the role rejects an unexpected URL. The `ubu1` peer/source address is supplied by the separate WireGuard role (`10.77.42.2` in the project design).
- `lab_web_log_dir=/var/log/ozzylogik/nginx`, `lab_log_group=lab-logs`, `lab_log_group_gid=2800` must match `web_waf`. Run the web role first so files exist. The service reads logs through this group and cannot write them.
- `lab_alloy_state_dir=/var/lib/alloy` is persistent guest-disk storage owned by the unprivileged service account. Do not erase it or rename `loki.source.file.waf_access` / `waf_audit` casually: these components own the saved positions.
- `lab_log_instance` defaults to `inventory_hostname` (`ubu1`).
- `lab_alloy_version=1.21.1` and archive SHA256 `83e7ad1663a1271af2f507ad1af53cdb0a0fbb19a1b661895bcc426af68f2774` are fixed. The downloaded archive is checksum-verified before extraction.

Verified 23.10.2026 against [official v1.21.1 release API](https://api.github.com/repos/grafana/alloy/releases/tags/v1.21.1) and matching [official SHA256SUMS](https://github.com/grafana/alloy/releases/download/v1.21.1/SHA256SUMS). [Exact amd64 archive](https://github.com/grafana/alloy/releases/download/v1.21.1/alloy-linux-amd64.zip), [release notes](https://github.com/grafana/alloy/releases/tag/v1.21.1).

## Persistence and limits

The service always sets `--storage.path=/var/lib/alloy`, keeps file positions there and enables `loki.write` WAL. WAL in this pinned version is experimental, so both validation and service execution explicitly use `--stability.level=experimental`. Default maximum segment age is made explicit at one hour; old segments are eventually removed. This is not a promise of lossless arbitrary-duration offline delivery, bounded WAL byte size or exactly-once processing. Persistent positions describe reading progress; they are not end-to-end delivery receipts. Disk capacity and dropped-entry metrics still need verification/monitoring.

The reader tracks the active live filenames. Rename/create rotation lets a running tailer finish its old open file while opening the new one. If Alloy is stopped across rotation, unread portions of old archives can require a documented manual recovery; matching all rotated files would introduce duplicate/replay behavior and is not silently enabled.

The collector has a loopback-only status port `12345`; logs are sent to the private WG URL, without proxy or redirects. The unit limits memory to 384M and keeps no capabilities. System package prerequisites `ca-certificates`/`unzip` follow Ubuntu repositories and their actual deployed versions should be recorded with package evidence.

Sources: [file positions](https://grafana.com/docs/alloy/latest/reference/components/loki/loki.source.file/), [persistent storage flag](https://grafana.com/docs/alloy/latest/reference/cli/run/), [WAL/retry reference](https://grafana.com/docs/alloy/latest/reference/components/loki/loki.write/), [validate scope](https://grafana.com/docs/alloy/latest/reference/cli/validate/).

## Required runtime evidence

The template validator checks Alloy syntax/components, not file permissions, delivery or durability. Runtime tests queried both `{job="ozzylogik",instance="ubu1",log_type="access"}` and `log_type="audit"` using unique `X-Lab-Correlation-ID` markers. Ordinary collector restart with Loki available, standalone Loki outage/recovery, subsequent delivery, two rename/create rotations and approved sequential VM reboots passed. Each expected normal access/SQLi access/SQLi audit record appeared once in those tests; old central baseline records remained available. Full secure/site runs after reboot also returned changed=0 on both guests. Actual disk usage and dropped-entry metrics remain operational checks, and seven-day retention expiration has not yet been observed.

A stronger combined test failed: restarting Alloy while Loki was still stopped left test events absent centrally after recovery. Original host logs were retained; no backfill was performed. `max_backoff_retries=0` means indefinite retries in the pinned release, but shutdown drain can still cancel pending requests. Recover Loki and confirm delivery before a planned collector restart. Persistent positions/WAL are not a guarantee of lossless combined failure recovery.

Local preparation check on 23.10.2026: the actual official 1.21.1 archive was downloaded into temporary WSL storage and its SHA256 matched the pin. A render of this template with `instance=ubu1` passed that binary's `validate --config.format=alloy --stability.level=experimental` with exit 0 and no diagnostics. This preceded deployment; the native collector is now running on ubu1 and passed the runtime scenarios described above.
