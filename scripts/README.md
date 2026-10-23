# Вспомогательные скрипты

`audit-proxmox.sh` выполняет только GET/чтение: версия, ресурсы, VMID без имён чужих VM, ёмкость storage, bridge и маршруты. Не читает конфигурации VM/cloud-init и секреты. Не резервирует nextid, не проверяет свободные LAN IP и не заменяет DHCP/static audit.

23.10.2026 выполнен из WSL по отдельно согласованному SSH-ключу. Отчёт — только в `.local/`, поскольку содержит домашнюю топологию.

`audit-proxmox-details.sh` дополнительно читает free/lvs/vgs, проверяет два кандидата VMID, выбранные несекретные поля существующего template, firewall options/runtime и таблицу neighbors без активных проб. Полные конфиги VM не выводятся.

`audit-proxmox-firewall.sh` читает статус PVE firewall и выводит только таблицы/цепочки/policies/counts из nftables/iptables; значения правил не сохраняет. Отсутствие правил в этом снимке не доказывает закрытие портов или полное состояние IPv6/других сетевых фильтров.

Оба дополнительных скрипта также выполнены read-only. Создание VM, clone, firewall/network changes и нагрузочные проверки ими не выполняются.

`bootstrap-proxmox.sh` — отдельный **изменяющий инфраструктуру** bootstrap, выполняется только с `--apply` после конкретного согласования. Проверяет template/два свободных target ID/один ed25519 public key, создаёт только два full clones, записывает cloud-init и запускает новые VM. Он уже выполнен для текущего стенда; повторно не запускать на существующих ID. При сбое новые частичные объекты сохраняются для разбора, автоматического удаления нет.

`ansible.sh` запускает установленный pinned venv Ansible и явно выбирает project cfg для WSL DrvFS. Первоначальный bootstrap использует отдельный inventory с ubuntu; после проверки нового VPN-пути secure → независимая приёмка доступа → commit-access → site используют обычного администратора по WG. Multiplexing отключён, проверка SSH host key сохраняется. Точные домашние inventories не публикуются.

`verify-http-logs.py` использует только Python stdlib и делает normal/SQLi запросы исключительно к явно указанному `http://10.77.42.2` на80. Proxy и redirects отключены; запросы получают уникальные correlation IDs. JSON содержит статусы и body hashes без body/credentials. Скрипт сам не опрашивает Loki и оставляет `waf_audit_pending=true`: для приёмки отдельно сопоставить central access/audit, engine и CRS rules. Такой baseline уже подтверждён и очищен в [evidence](../docs/evidence/baseline.json); повторные проверки создают новые markers.
