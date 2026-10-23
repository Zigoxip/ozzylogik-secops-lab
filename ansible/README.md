# Состояние Ansible

Реализованы preflight/prepare/bootstrap/site/secure/commit-access/reboot playbooks и шесть ролей. Bootstrap, secure и commit выполнены; steady-state secure/site дали changed=0/failed=0/unreachable=0 на обоих узлах. WAF/центральные логи, SSH/портовые пробы, обычный restart Alloy, отдельный outage Loki и две ротации подтверждены в [verification.md](../docs/verification.md). Совмещённый outage Loki+restart Alloy потерял marker; ротация требует короткого restart WAF. Разрешённые последовательные reboot и postboot-приёмка прошли; финальные post-reboot secure/site также дали changed=0 на обоих узлах.

Не копировать placeholders в действующий inventory без фактических DHCP leases. `.yml.example` — только образец: перед использованием скопировать в файл с расширением `.yml`. Приложения закреплены по версии/checksum; Ansible2.21.5 совместим с Python3.14 контроллера и установлен в отдельный WSL venv.

Запускать через `bash scripts/ansible.sh`: wrapper явно выбирает конфигурацию этого проекта при DrvFS world-writable предупреждении. Порядок и guards — в [плане применения](../docs/application-plan.md). `secure.yml` требует подтверждённый новый VPN-путь, `commit-access.yml` — фактические положительные/отрицательные access tests. Не подставлять true gates заранее.

Секретный vars file — только файловая система WSL вне проекта, путь задаёт lab_controller_secret_file. Main playbook не включает сетевое ужесточение автоматически: это отдельный контролируемый переход.

`reboot.yml` требует явного `lab_reboot_approved`, clear guard и выполняет ubu1→ubu2 последовательно с проверками после старта. Обе VM успешно прошли последовательный reboot и postboot-приёмку; при воспроизведении требуется новое согласование.
