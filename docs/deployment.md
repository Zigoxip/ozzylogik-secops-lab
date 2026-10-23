# Развёртывание и восстановление

Развёртывание начато после подтверждения пользователем конкретного плана. Созданы full clones `101 / ubu1` (2 vCPU, 2 GiB, 20 GiB) и `102 / ubu2` (2 vCPU, 4 GiB, 30 GiB), закреплены DHCP leases новых VM. Template `9000` сохранён без изменений. Базовые гостевые пакеты обновлены; cloud-init завершён без ошибок, с отдельно учтённой известной Proxmox deprecation.

Bootstrap, VPN, окончательная SSH/firewall-политика и commit доступа завершены. Исправленный site и базовая приёмка подтвердили HTTP 200/SQLi 403, центральные access/audit, CRS blocking, Grafana→Loki health и ожидаемые TCP-пробы: [очищенное evidence](evidence/baseline.json). Повторные secure/site дали changed=0 на обоих узлах. Отдельно прошли обычный restart Alloy при доступном Loki, outage Loki при работающем Alloy и две принудительные ротации с доставкой новых access/audit. Совмещённый outage+restart потерял два marker и остаётся известным ограничением; ротация требует короткого перезапуска WAF. Разрешённые последовательные reboot и postboot-приёмка прошли; финальные secure/site после них также дали changed=0 на обоих узлах. WAN DNAT TCP/80 и UDP/51820 остаются **disabled**; текущие VM повторно не создавать.

## Prerequisites

- WSL2, Git, OpenSSH, Python — наличие проверено; подробности в локальном аудите.
- Ansiblecore2.21.5 в отдельном venv, pinned collections, wireguard-tools и Python venv bootstrap уже установлены в WSL. Системный Python не заменён.
- App versions/checksums закреплены в versions.md. Фактический Docker.io candidate `29.1.3-0ubuntu3~24.04.2` прочитан в клоне и зафиксирован перед web role; при воспроизведении доступность этой версии проверить отдельно.
- Авторизованный Proxmox-доступ проверен новым ключом. SSH host key совпал с существующей записью Windows known_hosts; она используется из WSL без изменения файлов. До guard на обеих VM подтверждён Guest Agent recovery: `qm guest exec` с `id -u` вернул0.
- Фактические ресурсы, bridge/storage и свободные VMID были проверены до создания; сейчас выделены только VM101/102 и закреплены их DHCP leases. Точные LAN-параметры остаются в игнорируемом локальном inventory; выбранная VPN-схема описана в architecture.md и подтверждена новыми SSH-сеансами к WG-IP обеих VM.
- Отдельный ключ Proxmox согласован, создан в WSL и установлен пользователем; новый SSH-сеанс успешен. Согласованные VM/WireGuard/Grafana секреты уже подготовлены только в защищённой файловой системе WSL вне репозитория. Их содержимое не копировать в команды и отчёты.

## 1. Завершить аудит

`scripts/audit-proxmox.sh` выполнен по SSH из WSL: получены версия, ресурсы, storage, bridge и VMID. Дополнительные `audit-proxmox-details.sh` и `audit-proxmox-firewall.sh` прочитали thin pool/metadata, выбранные несекретные поля template и runtime firewall. Скрипты не создают VM, не меняют сеть и не выводят SSH private keys или cloud-init passwords. Вывод содержит внутреннюю топологию: сохранён в `.local/`, не публикуется. Полный firewall ruleset и полные VM configs в отчёты не сохранялись.

Варианты: пользователь выполняет скрипт сам; либо после отдельного согласования устанавливается ограниченный audit-ключ и скрипт запускается по SSH. Для первого варианта подготовлена игнорируемая локальная `.local/collect-proxmox-audit.sh`: она использует существующий Windows known_hosts, запрашивает пароль только в локальном терминале SSH и пишет вывод в `.local/`. Credentials в команду или отчёт не включаются. Проверка доступа по TCP не является авторизованным аудитом Proxmox.

MikroTik: использовать только существующий credential profile с подтверждённой identity. Сначала system/identity, затем адреса/маршруты/DHCP pools/leases без секретных полей. Не читать private-key WG, пароли, backups или полный export. Если MCP не предоставляет профиль, сначала установить точный поддерживаемый способ обращения к нему; не подставлять чужой MCP endpoint.

## 2. Зафиксировать параметры и получить согласование

Заполнить таблицы ресурсов и потоков, указать точные объекты изменений и откат в approval-plan. Проверить отсутствие адресных конфликтов. Если план не требует MikroTik changes, не менять роутер.

Ручной bootstrap Proxmox допустим: создание двух VM с отдельными дисками и cloud-init, пользователь labadmin и public key, DHCP/статическая конфигурация по выбранной схеме. Каждый шаг записывать с причиной в worklog. Не строить отдельный проект полной автоматизации гипервизора.

Для текущего стенда этот этап уже выполнен: full clones101/102 из template9000, начальный cloud-init пользователь `ubuntu`, отдельный согласованный public key и DHCP с закреплением новых leases. Обычный `labadmin` создаётся ролью baseline. Две новые WAN DNAT-записи пока выключены; не включать их автоматически при повторах Ansible или ради bootstrap.

## 3. Подготовить WSL и зависимости

Установить недостающие инструменты согласованным способом, создать отдельный venv, сохранить точные версии в `ansible/requirements*.txt` и `ansible/requirements.yml`. Под Python 3.14 нельзя без проверки брать произвольную старую версию ansible-core. System Python не заменять.

Для образов фиксировать одновременно читаемый tag и digest, checksum установочных/cloud образов и фактические версии Nginx/ModSecurity/CRS. Для APT описать подход: конкретные версии либо выбранный репозиторий/снимок с lock-файлом; не обещать вечную доступность версии в обычном moving repository. Обновления безопасности выполнять отдельным изменением lock-файла с повторной проверкой.

## 4. Реализовать Ansible

План структуры:

```text
ansible/
  ansible.cfg
  site.yml
  requirements.yml
  requirements-control.txt
  inventory/hosts.yml.example
  inventory/hosts.yml                 # локальный, игнорируется
  group_vars/all/main.yml.example
  group_vars/all/local.yml            # локальный, игнорируется
  host_vars/                          # локальные параметры, игнорируются
  roles/{baseline,wireguard,firewall,web_waf,log_shipper,monitoring}/
    tasks/main.yml
    handlers/main.yml
    templates/
```

Созданы preflight.yml, prepare.yml, bootstrap.yml, site.yml, secure.yml, commit-access.yml, reboot.yml, ansible.cfg, pinned requirements, шесть ролей и два inventory examples. Сначала копировать example в .yml и заполнять фактическими адресами; CLI-u не переопределяет inventory ansible_user, поэтому bootstrap использует отдельный inventory с ubuntu. Рабочий inventory и секреты в Git не включать.

`bash scripts/ansible.sh` явно выбирает cfg, потому что WSL DrvFS может представлять checkout как world-writable. Порядок: preflight/prepare/bootstrap (ubuntu/LAN) → новый VPN SSH labadmin и отдельный WG inventory → secure → свежие положительные VPN и отрицательные LAN/auth проверки → commit-access → site. Тяжёлая установка приложений выполняется после завершения commit, а не под ожидающим rollback timer. Не запускать bootstrap повторно на уже защищённом стенде ради новых peers: secure включает и WireGuard роль.

Согласованные параметры source template сверены; Clone bootstrap требует его прежнее ожидаемое состояние и свободные целевые VMID. Actual Guest Agent/cloud-init/ОС проверяются после запуска клона, до ужесточения. Root Guest Agent exec служит отдельным recovery-каналом при потере IP SSH; gate console_recovery_verified выставлять только после такой фактической проверки, не ради обхода assert.

В текущем запуске `preflight.yml` читает JSON-статус cloud-init: требует `done` и пустой `errors`, а среди recoverable warnings разрешает только точную известную Proxmox deprecation строкового поля `user`. Другие предупреждения не игнорируются. Для bootstrap используется отдельный inventory с `ubuntu`; multiplexing отключён, проверки идут новыми SSH-соединениями.

Первое применение guest firewall выявило проблему ответа по старому SSH/conntrack-потоку при рабочем свежем SSH. Исправление ограничено временным bootstrap reply allow; это не основание ослаблять финальную политику или менять firewall Proxmox/роутера. При воспроизведении после bootstrap проверить новый VPN-путь, состояние pending rollback и итоговый recap до продолжения; не принимать старый открытый канал за доказательство доступа.

Повторный bootstrap теперь завершён (`failed=0` на обеих VM); следом завершены secure и commit. Независимая проверка после commit подтвердила отсутствие pending snapshot и отключённые rollback timers на обеих VM. Сохранять эти проверки при воспроизведении; первый успешный SSH не является разрешением заранее отменять guard.

Для управляющего WSL фактический внешний `eth0` MTU1280 потребовал MTU1200 в приватном административном WG-client config: больший размер приводил к зависанию SSH key exchange. Гостевые WG-интерфейсы оставлены с MTU1420. При воспроизведении проверить реальный внешний MTU и route, затем новые SSH-сеансы; не копировать1420 в клиент автоматически и не выдавать исправление одного SSH-сбоя за полную PMTU-проверку.

Использовать модули user/authorized_key/package/template/systemd и профильные модули вместо shell, когда они подходят. Для сложных операций нужны creates/changed_when/проверка состояния и пояснение причин. Изменённые конфиги активировать handlers. Нельзя перезапускать службы на каждом прогоне без изменения конфигурации.

Практическое исправление: WAF handler выполняет только `docker restart` уже объявленного контейнера. Частичная повторная спецификация `docker_container` в первом site пересоздала контейнер с default network и потеряла mounts/env. Поэтому после handlers роль проверяет host networking, mounts/image, `nginx -t` и настоящий HTTP80, а не только встроенный image healthcheck8080. FOWNER нужна entrypoint для сохранения атрибутов файлов.

Фактическая первая ротация выявила отдельную проблему pinned ModSecurity: HUP переоткрыл access, но audit writer продолжал писать в старый архив. Helper теперь перезапускает WAF и ожидает локальный HTTP 200. После исправления обе повторные ротации дали новые marker в активных access/audit и по одной центральной записи каждого ожидаемого типа. Это сопровождается коротким перерывом доступности веба; бесшовная ротация не заявляется.

Секреты: предпочтительно отдельное локальное хранилище в файловой системе WSL, каталог 0700 и файлы 0600, без секретов в inventory/examples. Альтернатива — согласованный Ansible Vault. Приватные WireGuard keys и Grafana credentials — `no_log: true`, `diff: false`, защищённые remote files; отдельный режим no_log для секретных operations. Не помещать секреты в argv, screenshots, debug, Ansible fact cache или логи. `.gitignore` — дополнительная мера, не замена проверке содержимого перед публикацией.

## 5. Переход на защищённый доступ

1. Проверить console recovery и согласованный snapshot при наличии.
2. Установить ключ labadmin, проверить новый SSH-сеанс и sudo на обеих VM.
3. Настроить WireGuard, проверить handshake и маршруты; убедиться, что WSL kernel поддерживает WG.
4. Проверить новый VPN SSH-сеанс к ubu1 и ubu2.
5. Сохранить прежние конфиги и подготовить автоматический rollback timer; проверить его готовность.
6. Выполнить `sshd -t`, `nft -c -f <CANDIDATE_RULESET>`, применить конечную SSH/firewall-политику через Ansible, включая удаление временного bootstrap allow. Автоматический rollback в этот момент ещё активен.
7. Новыми соединениями проверить разрешённый VPN и запрещённый LAN доступ, в том числе IPv6; убедиться, что временных allow уже нет.
8. Отменить rollback только после успеха обеих сторон. После отмены таймера не выполнять дополнительных изменений, влияющих на доступ, без нового защищённого перехода.

Не выключать старый путь управления до проверки нового. Не смешивать этот этап с изменением авторизации Proxmox.

## 6. Проверки и идемпотентность

Следовать verification.md. После полной конфигурации уже выполнены обычные steady-state secure/site: на обоих узлах changed0/failed0/unreachable0. Recap включён в [baseline evidence](evidence/baseline.json). Для будущего воспроизведения сохранить каждый recap и объяснить неожиданные изменения; syntax-check/check mode реальный повтор не заменяют.

На выделенной web VM Docker работает без bridge, iptables/ip6tables, автоматического ip-forward и masquerade. Это исправило наблюдённый drift forwarding, который secure прежде возвращал в0. Такие daemon-настройки относятся только к web VM с host-network контейнером и не переносятся автоматически на другие Docker-хосты.

Отдельные Loki outage и обычный Alloy restart прошли с normal/access и SQLi/access+audit по1, checkpoints/WAL state сохранились, старые записи доступны. Совмещённый Loki outage+Alloy restart не прошёл: новые marker не доставлены, host logs остались, backfill не выполнялся. Lossless-гарантии для этого сочетания нет. Retention Loki168h настроен, но удаление после семи суток пока не наблюдалось.

Пользователь разрешил последовательные reboot только VM101/102. Отдельный `reboot.yml` с gate, проверкой clear guard и порядком ubu1→ubu2 прошёл: обе VM `ok=7 changed=1 failed=0 unreachable=0`, boot ID сменились, новое ядро 6.8.0-147-generic. Повторены VPN SSH/отказы, WAF, новые и старые центральные логи, Grafana и независимые LAN-пробы; forwarding web=0/hub=1 сохранён. Точные границы — в [verification](verification.md), короткий сценарий — в [demo](demo.md). Гипервизор и домашний роутер не перезагружались.

## Восстановление

При потере доступа использовать Proxmox console, сохранить диагностический вывод без секретов и вернуть прежние SSH/nftables/WG конфиги. Если откат по таймеру не сработал, это отдельный дефект, который записывается в worklog и проверяется до повторного применения. Не применять `flush ruleset` или ослабление firewall ко всему гипервизору.

Переустановка стенда затрагивает только согласованные VMID и их volumes. Логи и Grafana/Loki state перед удалением сохранять при необходимости в локальное защищённое хранилище; параметры секретов восстанавливать из согласованного локального механизма. Все ручные шаги отражать в worklog.
