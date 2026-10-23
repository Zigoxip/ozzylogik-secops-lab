# Native Loki и Grafana

Пины проверены 23.10.2026 по [GitHub release Loki](https://github.com/grafana/loki/releases/tag/v3.7.9) и [официальной странице Grafana OSS](https://grafana.com/grafana/download/13.2.4?edition=oss&platform=linux). SHA256 проверяются get_url до установки. Роль применена на ubu2: readiness, authenticated Grafana datasource health и центральные access/audit события проверены, полный site повторился с changed=0, в том числе после согласованных reboot.

Секретный вход `lab_grafana_admin_password` передаётся из защищённого WSL-local файла, минимум 20 символов. В Git остаётся только имя переменной. Copy секрета имеет no_log/diff:false; Grafana читает файл через file provider. Этот пароль применяется при первоначальном создании базы Grafana. Изменение файла не является реализацией ротации уже существующего пользователя.

Loki использует persistent filesystem + TSDB v13 + compactor retention 168h. Это ограничение по времени, а не жёсткая квота диска. Loki без встроенной HTTP-аутентификации, его доступ ограничивается guest firewall: loopback для Grafana и WG-IP ubu1 для collector. Оба HTTP listener на VM, но TCP3000/3100 не пробрасываются через MikroTik.

Все readiness-проверки выполняются на loopback VM. Docker на VPN hub не устанавливается этой ролью. Systemd restart происходит только по изменению файлов/бинарника. Доставка после отдельной недоступности Loki и после согласованных последовательных reboot проверена; старые центральные baseline записи сохранились. Сочетание outage Loki с рестартом Alloy выявило документированное ограничение доставки. Реальное удаление данных после retention 168h ещё не наблюдалось.
