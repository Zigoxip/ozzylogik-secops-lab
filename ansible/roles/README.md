# Роли стенда

Все роли применены к двум новым VM. Baseline/WireGuard/firewall и commit доступа проверены; WAF/центральные логи подтверждены. Steady-state secure/site дали changed=0 на обоих узлах. Обычный restart Alloy при доступном Loki, отдельный outage Loki и две ротации прошли. Совмещённый outage+restart потерял marker; ротация требует короткого перезапуска WAF. Разрешённые последовательные reboot и postboot-приёмка прошли; финальные post-reboot secure/site также дали changed=0 на обоих узлах. Точный текущий статус — в [verification.md](../../docs/verification.md).

| Роль | Ответственность |
|---|---|
| baseline | Пользователь, public key, пакеты, проверенные sshd drop-ins, время и ограничения journald |
| wireguard | Конфигурация hub/peers, /32 routes, только нужный forwarding на ubu2 |
| firewall | nftables inet INPUT/FORWARD default deny, необходимый ICMP/DHCP/IPv6, безопасный rollback |
| web_waf | Nginx + ModSecurity On + CRS, тестовая страница, access/audit logs, image digest и rotation |
| log_shipper | Alloy, оба log streams, постоянные позиции/WAL при поддержке, права на логи |
| monitoring | Loki retention и persistent data, Grafana datasource и сохранённое состояние |

Каждая роль: tasks/main.yml, handlers/main.yml, templates по необходимости; секретные tasks с no_log и без diff. Bootstrap и окончательное ужесточение SSH/firewall разделить проверяемым переходом.
