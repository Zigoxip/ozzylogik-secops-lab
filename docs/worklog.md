# Журнал работы

Время — Europe/Kyiv; даты этого этапа — 23.10.2026. Все статусы относятся к фактически выполненным действиям.

## Этап 0 — исходные требования

- Прочитан приложенный запрос пользователя.
- Через Google Drive прочитаны метаданные и текст документа OM SecOps (ua). Пункты 1–6 и требование Git/README совпадают с описанием; Telegram — опционален, >5 означает минимум 6.
- Обращение к ИИ про «хомяка» исключено из технических требований.
- Браузер и браузерная автоматизация не использовались.

## Этап 1 — read-only аудит среды

- Проверена рабочая папка: изначально пуста, локального AGENTS.md и Git-репозитория нет. Инструкции AGENTS получены в сообщении пользователя.
- Первые WSL/CIM проверки внутри sandbox дали access denied; Windows TCP probe дал false. Это НЕ доказательства сетевой проблемы.
- Повторный read-only аудит WSL вне sandbox успешен: WSL2 Ubuntu 26.04 LTS, kernel 6.6.87.2; Git 2.53.0, OpenSSH 10.2p1, Python 3.14.4.
- Ansible, wg, pip и ensurepip отсутствуют; venv module есть. Docker CLI 29.1.3 есть, compose отсутствует, daemon не проверялся.
- Proxmox SSH/HTTPS доступны из WSL. Строгий HTTPS не доверяет локальному сертификату; единственный unauthenticated GET с временным insecure вернул 401, версия Proxmox не установлена. Credentials при этом не передавались, insecure не записан в конфигурации.
- SSH с BatchMode/StrictHostKeyChecking остановился на неизвестном host key до авторизации. Наблюдён ED25519 fingerprint без записи в known_hosts; доверенная проверка ещё нужна.
- Позднее прочитана существующая запись Windows known_hosts именно для Proxmox: ED25519 fingerprint совпал с наблюдённым. Для пользовательского SSH из WSL можно использовать этот known_hosts без изменения обоих файлов. Авторизованный SSH-сеанс всё ещё не выполнен.
- Ресурсы Proxmox, storage, bridge, VMID/IP НЕ прочитаны из авторизованного сеанса.
- Никакие VM, ключи, пакеты, firewall, SSH, router или гипервизор не изменены. Для аудита запущен ранее остановленный WSL-дистрибутив.

Подробные внутренние адреса, маршруты, fingerprint и ресурсы управляющего компьютера записаны только в игнорируемую `.local/audit-2026-10-23.md`.

## Этап 2 — уточнение профиля MikroTik

- В доступном наборе MCP и именах серверов config.toml нет указанного домашнего профиля; другие подключения не использовались. Поиск каталога плагинов также не дал отдельного MikroTik plugin.
- Пользователь уточнил identity, адрес домашнего роутера и путь credential helper. Эти параметры сохранены только локально; проверяется существующий механизм обращения к профилю.
- Credential-файлы не выводились в чат; дополнительные разрешения API не запрашивались.
- Установлено: Set-Credential сохраняет DPAPI-профиль, но не регистрирует отдельный MCP. Существующие MCP launchers имеют фиксированный список других роутеров; они не запускались.
- Создан игнорируемый локальный adapter над существующей функцией Common.ps1 Invoke-MikrotikCredentialRead. Проверены exact profile, endpoint host и expected identity до использования credential; затем отдельный GET подтвердил identity. Credential расшифрован только в памяти локального процесса, в аргументы/вывод не передавался.
- Выполнены только GET с явными списками несекретных свойств: resource, IP/routes, DHCP, firewall/NAT и WG interfaces/allowed-address. Запросы WG private/public keys не делались. Результат сохранён в `.local/mikrotik-audit-2026-10-23.json`; router settings не менялись.
- Windows PowerShell 5.1 обернул коллекции при JSON-сериализации; сохранённый отчёт нормализован локально, количества строк проверены. Это ошибка представления отчёта, не изменение роутера. Adapter исправлен для явного перечисления коллекций.
- Подтверждён широкий DHCP-пул и существующая VPN-маршрутизация. Свободные адреса VM всё ещё НЕ подтверждены: leases не описывают все статические устройства.

## Этап 3 — локальная документация и план

- Созданы README.md, .gitignore, .gitattributes, docs/{requirements,architecture,approval-plan,deployment,worklog,verification,defense}.md, образцы inventory/group vars и описание будущих ролей.
- Подготовлен read-only scripts/audit-proxmox.sh; на Proxmox он ещё не выполнялся.
- Предложены две VM и WG hub с двумя peers, без NAT и без изменений MikroTik; IP/VMID/storage не назначены.
- Сверены официальные описания WireGuard, Docker filtering и жизненного цикла Promtail через текстовый веб-поиск; браузер не запускался. Для нового сборщика предлагается Alloy, так как Promtail EOL с 02.03.2026.
- Стенд и Ansible-роли ещё не реализованы; все инфраструктурные приёмочные проверки остаются невыполненными.
- Bash syntax-check read-only audit-proxmox.sh выполнен в WSL: exit 0. Скрипт на Proxmox не запускался. PowerShell parser проверил локальный router adapter без ошибок; known private material/home identifiers в публикуемых файлах точечным поиском не обнаружены. Это ограниченная проверка, не готовность к публикации.
- Независимая проверка плана выявила ошибку порядка: bootstrap allow нужно удалить под действующим rollback timer ДО отрицательной LAN-пробы и отмены таймера. Последовательность deployment исправлена.

## Этап 4 — согласованный SSH-ключ Proxmox

- Пользователь выбрал отдельный ключ и явно разрешил доступ без ограничения команд для домашнего тестового сервера.
- Создан отдельный ed25519 ключ `~/.ssh/ozzylogik-proxmox` в WSL, без перезаписи существующих файлов, private mode 0600/public 0644. Приватная часть не выводилась и не копировалась в Windows-проект. Публичная строка и fingerprint переданы пользователю.
- Новый ключ без passphrase предназначен для автоматизации; локальная защита — файловая система WSL и права файла. Другие SSH keys/config/known_hosts не менялись.
- Добавление public key на Proxmox пока ожидается от пользователя. Не заявляем успешную авторизацию и не меняем парольный/root доступ гипервизора.
- Установка ключа не является разрешением создавать VM или применять сеть/firewall: конкретный план после ресурсного аудита всё ещё требует подтверждения.

## Этап 5 — авторизованный read-only аудит Proxmox

- Пользователь сообщил об установке public key и явно разрешил проверить SSH/продолжить read-only аудит.
- Новый SSH-сеанс из WSL с BatchMode=yes, IdentitiesOnly=yes, отдельным ключом и StrictHostKeyChecking=yes успешен: uid=0(root), exit 0. Windows known_hosts использован только на чтение; пароль не вводился.
- Последовательно выполнены audit-proxmox.sh, audit-proxmox-details.sh и audit-proxmox-firewall.sh. Начала снимков: 01:23:23, 01:24:50 и 01:26:12 UTC 23.10.2026 (04:23–04:26 Kyiv). Вывод сохранён только в `.local/`; все скрипты завершились exit 0. Полные VM/cloud-init configs и содержимое firewall rules в отчёты не выводились.
- Прочитан Proxmox9.1.1 с kernel6.17.2-1-pve, online узел, 40 logical CPU, usable RAM62,84GiB. Отдельный free snapshot дал около58,59GiB available.
- Local-lvm thin pool347,90GiB, available334,43GiB; data3,87%, metadata0,60%. VG free около16,00GiB — отдельная величина, не то же самое, что свободные блоки внутри thin pool.
- Два кандидата VMID отдельно проверены API как свободные; ничего не зарезервировано и не создано. Прочитаны только выделенные безопасные поля template; его Ubuntu version/provenance не установлены, clone не выполнялся.
- Существующий LAN bridge активен. PVE firewall сообщает disabled/running; nftables пуст, в прочитанных IPv4iptables цепях ACCEPT без правил. Активные service units не означают включённую firewall policy. Firewall не включался/не менялся; полный IPv6/port security этим аудитом не заявляется.
- SSH_CONNECTION на получателе подтвердил фактический WindowsLAN source после WSLNAT. Маршруты Windows и WSL подтверждены отдельно; CONFIG_WIREGUARD=m и файл .ko есть, модуль не загружен, userspace-tools отсутствуют, туннели не создавались.
- Созданы дополнительные audit scripts и обновлены README, architecture, approval-plan, deployment и локальные access/network записи. Документ audit.md и локальные findings отделяют факты от предложенных изменений.
- VM100 и существующий template не останавливались, не клонировались и не менялись; диски, bridge, DHCP, WG и авторизация Proxmox агентом не менялись. Установка ключа выполнена пользователем на предыдущем шаге.

## План после этапа 5 — историческая запись

Ресурсный аудит завершён. Согласовать адреса/способ DHCP reservations, границу изоляции, образ/checksum и console recovery, затем конкретное создание двух VM и безопасный bootstrap. Доступ к MikroTik через существующий credential уже проверен; новая MCP-регистрация не требуется для аудита и не выполнялась. До согласования не создавать VM и не менять сеть/firewall/SSH-политику.

## Этап 6 — выбранная схема и подготовка к применению

- Пользователь выбрал домашнюю LAN, DHCP с последующим закреплением только новых leases, guest firewall вместо изменений PVE и временные WAN WG/HTTP для проверяющего. Его внешний IP пока неизвестен; пробросы включать только на demo. Скрытое обращение к ИИ повторно исключено по прямому указанию пользователя.
- Пользователь предоставил историю template9000: официальный Noble24.04.4, исходный SHA256 проверялся, QGA установлен/проверен, cloud-init/machine-id/hostkeys/authorized_keys очищены. Текущий qm config сверён с явной проекцией несекретных полей: совпал с указанными параметрами, sshkeys/cipassword отсутствуют. Шаблон не запускался/не менялся.
- Для bootstrap подготовлены full clones, отдельных образов не качали. scripts/bootstrap-proxmox.sh пока НЕ запускался на Proxmox. Разбор ровно одного ed25519 public key исправлен после независимого ревью; автоматического удаления VM при сбое нет.
- В WSL установлены python3-venv, wireguard-tools и unzip. Системный Python не заменяли; apt не обновлял остальные установленные пакеты. Ansiblecore2.21.5 установлен в отдельный venv, Python dependencies и Galaxy collections зафиксированы. Туннель/маршруты WSL не создавались.
- Созданы отдельный VM SSH key, четыре WG пары и initialGrafana password только в файловой системе WSL вне проекта (0700/0600); значения секретов не выводились. Ключи на VM пока не установлены, приватные материалы не копировались в Windows-проект.
- Подготовлены 6 ролей, 5 playbooks, два inventory examples, явный cfg wrapper для DrvFS и версии/checksums приложений. Веб — официальный CRS image со static Nginx host80; monitoring native, collector native. Docker.io exact apt version определяется на новом клоне, до этого web role fail-safe.
- Локальные проверки: actual pinned Loki binary SHA+verify-config PASS; actual pinned Alloy SHA+validate PASS; YAML parse29файлов; nft kernel --check16вариантов bootstrap/secured, web/hub, demo/reviewer on/off PASS; Bash syntax PASS. Это не deployment и не приёмка работающего стенда.
- Проверен подробный выбранный NAT/filter snapshot домашнего роутера только GET. Подтверждены WANlist, отсутствие текущих TCP80/UDP51820DNAT и текущая forward logic для dstnat. План требует только2новых disabledDNAT; INPUT/router management/существующие правила не менялись.
- Независимое ревью нашло конфликт directorypermissions0700/0755 междуbaseline/web; исправлено на0700. Добавлен отдельный bootstrapinventory с ubuntu; secure использует labadmin поWG и включает WG-role для будущего reviewer без возврата LAN22.
- Инициализирован локальный Git main без remote/commit/push; .local игнорируется. Публикации/отправки результатов нет.
- Подготовлен docs/application-plan.md с точными этапами, gates, временной WAN публикацией и откатом. До применения единый конкретный план предлагается пользователю по исходному требованию предварительного подтверждения сети/SSH/firewall.

## Этап 7 — согласованное создание VM и начальный bootstrap

- Пользователь подтвердил конкретный план применения. Созданы и запущены только две новые full-clone VM: `101 / ubu1` — 2 vCPU, 2 GiB RAM, диск 20 GiB; `102 / ubu2` — 2 vCPU, 4 GiB RAM, диск 30 GiB. Исходный template `9000` и прежняя VM не менялись. Это фактическое создание узлов, а не подтверждение готовности веба/мониторинга.
- После получения DHCP leases закреплены только leases новых VM. Домашние LAN-адреса и MAC остаются в локальных операционных записях, в публичные документы не добавляются.
- Подготовлены две отдельные WAN DNAT-записи для будущей демонстрации: TCP/80 к `ubu1` и UDP/51820 к `ubu2`. Обе записи **disabled**; подготовка не означает открытый доступ из интернета. Старые правила и домашние сервисы сохранены.
- На новых гостях обновлены базовые пакеты. Фактический cloud-init завершён: `status=done`, список `errors` пуст. Обнаружена ровно известная deprecation строкового поля `user`, которое генерирует Proxmox; `preflight.yml` допускает только это точное сообщение и продолжает отклонять ошибки и другие recoverable warnings. Предупреждение не замаскировано как полностью чистый status.
- Первый запуск гостевого firewall остановил прежний SSH-поток: условие временного bootstrap reply allow не покрывало его состояние conntrack. Отдельное новое SSH-соединение работало, поэтому это не было доказательством полной потери управления. Подготовлена временная bootstrap-поправка reply allow; постоянная финальная политика ещё не принята.
- SSH multiplexing отключён в Ansible config (`ControlMaster=no`, `ControlPath=none`), чтобы новые подключения и приёмка не использовали сохранённый канал. Изменение относится к способу подключения управляющего клиента, а не к авторизации гипервизора.
- На момент этой записи повторный `bootstrap.yml` выполняется в пределах ожидающей rollback-транзакции на 900 секунд. Успешный recap повторного запуска ещё не получен; сам факт повторного запуска не является доказательством идемпотентности.
- WireGuard handshake/маршруты, новый VPN SSH, `site.yml`, финальный `secure.yml`, независимые отрицательные LAN-пробы и `commit-access.yml` остаются **не проверены**. Rollback нельзя отменять на основании рабочего старого SSH-сеанса.
- Обновлены только `docs/worklog.md`, `docs/deployment.md` и `docs/verification.md`: текущая стадия отделена от будущих критериев. Runtime-журналы содержат частные параметры и хранятся локально; очищенные доказательства приёмки ещё предстоит подготовить. Публикации репозитория и отправки результатов не было.

## План после этапа 7 — историческая запись

Получить и проверить результат повторного bootstrap, состояние rollback guard и новых соединений. Затем подтвердить WireGuard/маршруты и доступ обычного администратора через VPN, выполнить веб/мониторинг/сбор логов, перейти к финальной политике и независимым положительным/отрицательным тестам. Статус каждой проверки обновлять только после её фактического результата; текущие VM повторно не клонировать.

## Этап 8 — VPN, окончательная SSH-политика и commit доступа

- Повторный bootstrap завершён: `ubu1 ok=47 changed=12 failed=0`, `ubu2 ok=48 changed=13 failed=0`. Это успешное применение после исправления, а не доказательство `changed=0` на втором полном прогоне готового стенда.
- При включённом клиенте WSL обнаружен отдельный MTU-дефект: внешний `eth0` WSL имеет MTU1280, а больший MTU клиентского WG приводил к зависанию SSH key exchange. MTU приватного административного WG-клиента уменьшен до1200; MTU гостевых WG-интерфейсов1420 не менялся. После этого новые строгие SSH-сеансы к WG-IP hub и web прошли. Это подтверждение устранения наблюдённого SSH-сбоя, не обещание проверки всех вариантов PMTU/UDP.
- На обе VM подтверждены новые входы `labadmin` по ключу через VPN и `sudo` с результатом uid0. Проверки не использовали SSH multiplexing.
- Финальная SSH/firewall-политика применена. Отдельные попытки root, password и keyboard-interactive входа отвергнуты на обеих VM; сервер предлагал только publickey. Эффективная SSHD-конфигурация обеих VM проверена и соответствует запрету root/password/keyboard-interactive.
- Независимые новые TCP22-пробы из Windows через физический Ethernet к LAN-адресам обеих VM вернули false. Положительный новый VPN SSH продолжил работать. Это проверка разных путей, а не принятие общей недоступности сервиса за изоляцию.
- `secure.yml` завершён: на обеих VM `ok=38 changed=6 failed=0`. `commit-access.yml` завершён: на обеих VM `ok=5 changed=1 failed=0`.
- После commit отдельно проверены оба guard: pending snapshot отсутствует, rollback timer inactive и disabled. Защищённый переход доступа завершён; старый 900-секундный таймер больше не ожидает отката. Это не отменяет проверки доступа после будущих согласованных изменений.
- `site.yml` сейчас выполняется. Успешное развёртывание Nginx/WAF, Loki/Grafana/Alloy, HTTP200/SQLi403, централизованные события, ротация и второй полный прогон ещё не подтверждены.
- Для последующей последовательной перезагрузки только VM101/102 отдельно запрошено разрешение пользователя; ответ пока ожидается. Приёмочные перезагрузки не выполнялись.

## План после этапа 8 — историческая запись

Получить результат установки приложений, проверить WAF и оба log streams по correlation ID, затем ротацию, рестарты и второй обычный прогон Ansible. Последовательные перезагрузки выполнять только после полученного разрешения и повторить проверки после каждой. Перед публикацией подготовить очищенные evidence и проверить весь публикуемый комплект; домашние LAN/MAC/fingerprints и секреты остаются вне него.

## Этап 9 — проверка recovery, ошибка первого site и исправление

- До защищённого перехода на обеих новых VM фактически проверен отдельный recovery-канал: Proxmox `qm guest exec` с `id -u` вернул0. Это проверка привилегированного Guest Agent exec без зависимости от гостевого IP SSH, а не только наличие agent flag в qm config.
- Пользователь отдельно разрешил последовательную перезагрузку обеих тестовых VM. Разрешение получено, но приёмочные reboot на момент этой записи ещё не выполнялись.
- Первый `site.yml` формально завершился, однако фактическая HTTP80-проба не работала. Причина: handler с частичной спецификацией `community.docker.docker_container` пересоздал контейнер с image defaults, потеряв host networking, mounts и env. Встроенный image healthcheck на8080 не доказывал работоспособность требуемого HTTP80. Формальный Ansible recap не был принят за успех WAF.
- Handler исправлен на явный `docker restart` существующего полностью объявленного контейнера через локальный Docker socket. Для сохранения атрибутов файлов entrypoint добавлена capability FOWNER. После handlers добавлены проверки container invariants, `nginx -t` и реальный loopback HTTP80 health resource.
- Второй `site.yml` завершился: `ubu1 ok=41 changed=1 unreachable=0 failed=0`, `ubu2 ok=25 changed=0 unreachable=0 failed=0`. На monitoring повторное применение не изменило настройки; это ещё не второй полный прогон всего стенда с changed0.
- Фактический Docker package pin: `29.1.3-0ubuntu3~24.04.2`. На WAF прочитаны libModSecurity3.0.17, nginx connector1.0.4 и856 правил; Nginx version пока отдельно не зафиксирована этим checkpoint.

## Этап 10 — базовая приёмка WAF, логов и портов

- Контролируемый normal HTTP-запрос вернул200, SQLi —403. Оба найдены в централизованном access stream на `ubu2`; SQLi также найден в ModSecurity audit stream.
- В фактическом audit: rule engine `Enabled`, компонент `OWASP_CRS/4.30.0`, SQLi rule942100 и blocking rule949110 (также присутствует920350). Audit transaction ID совпал с access request ID. Наблюдённый client IP — только проектный WG-IP административного клиента; caller-provided XFF за источник не принят.
- Grafana API сообщил13.2.4 и database `ok`; аутентифицированная проверка Loki datasource вернула `OK`.
- Выполнены18 TCP-проб из административного VPN и36 независимых Windows LAN-проб: по9 портов, две VM, LAN IPv4 и IPv6. Все ожидаемые результаты совпали: из VPN открыты только ubu1 TCP22/80 и ubu2 TCP22/3000 среди проверенных портов, из обычной LAN все эти порты закрыты. Это ограниченный список TCP-портов, не полный TCP/UDP scan и не проверка внешнего WAN.
- Создан `docs/evidence/baseline.json` только из выбранных безопасных полей фактических proof summaries: WAF/correlation, Grafana health, SSH auth/effective policy и портовые пробы. Домашние LAN-адреса, интерфейсы, MAC и ключевой материал исключены. Offset timestamp WAF нормализован в UTC без изменения момента события; в источниках port summaries точного времени нет, оно не придумано.
- Restart/positions, ротация/reopen, полный идемпотентный прогон и разрешённые последовательные reboot с проверками после старта остаются **не выполнены** на этом checkpoint. Подготовленные WAN DNAT остаются выключены.

## План после этапа 10 — историческая запись

Проверить доставку после restart collector и ротации, фактическое повторное открытие access/audit файлов, второй обычный прогон всего стенда и последовательные reboot только двух разрешённых VM с повторной приёмкой. Обновлять evidence по фактическим результатам; публикация репозитория и передача результатов работодателю пока не разрешались.

## Этап 11 — Docker drift, идемпотентность и предел доставки

- Обнаружен drift: Docker включал forwarding на web VM, и secure возвращал его в требуемое0. На выделенной web VM зафиксирована daemon policy bridge=none, iptables=false, ip6tables=false, ip-forward=false, ip-masq=false; установка пакета использует policy_rc_d101, чтобы не запускать ещё не настроенный daemon. Гипервизор и роутер не менялись.
- После исправления свежие access-проверки и commit прошли, оба guard clear. Реальный повтор secure: обе VM `ok=34 changed=0 failed=0 unreachable=0`. Повтор site: `ubu1 ok=45 changed=0 failed=0 unreachable=0`, `ubu2 ok=25 changed=0 failed=0 unreachable=0`. Это обычные steady-state прогоны, не check mode; bootstrap не повторяют на защищённом стенде ради идемпотентности.
- Runtime: Ubuntu24.04.5/kernel6.8.0-136-generic на обеих VM, Nginx1.30.6, Docker package29.1.3-0ubuntu3~24.04.2, Alloy1.21.1, Loki3.7.9, Grafana13.2.4. Очищенные версии и recap добавлены в baseline evidence.
- Совмещённый отказный тест **не прошёл**: Loki остановлен, отправлены normal/SQLi, Alloy перезапущен при недоступном Loki. Shutdown flush/drop не доставил новые marker: после восстановления у обоих0 центральных streams, хотя host logs сохранились. Backfill не выполнялся. Run ID и counts сохранены в baseline; lossless WAL не заявляется.
- Отдельные сценарии затем прошли: при outage Loki без перезапуска Alloy восстановлены normal/access и SQLi/access+audit по1; обычный restart Alloy при доступном Loki сохранил все3 результата по1, новые marker после restart тоже дали по1. Старый baseline после рестартов Loki остался доступен. Positions до/после и WAL state присутствуют; эти результаты не отменяют совмещённую потерю.
- Rotation/reopen выполняется, окончательного результата пока нет. Последовательные reboot разрешены, но ещё не выполнены. Подготовлен отдельный `ansible/reboot.yml` с gate, последовательностью ubu1→ubu2, guard-clear precondition и postboot-проверками; syntax-check прошёл, это не факт перезагрузки.
- Loki retention168h настроен; семь суток ещё не истекли, удаление по этому сроку не наблюдалось. Configured retention не выдаётся за successful expiry test.

## Этап 12 — фактическая ротация и краткий restart WAF

- Первый HUP-only тест ротации не прошёл: access writer открыл новый файл, а ModSecurity audit writer остался на старом архиве. Новый SQLi audit не появился в центральной доставке, хотя access дошёл. Неудачный результат не принят за успешный reopen.
- Helper ротации исправлен на restart WAF с ожиданием локального HTTP 200. Это ограничение pinned ModSecurity: ротация сопровождается коротким перерывом доступности веба; бесшовный reopen не заявляется.
- Две повторные принудительные ротации прошли. В каждом раунде новые normal/SQLi находятся в активном access, SQLi — в активном audit; в Loki normal/access, SQLi/access и SQLi/audit найдены ровно по одной записи. Access inode сменился оба раза; audit первого раунда был пуст до ротации и сохранил inode, во втором inode сменился. Права активных файлов 0640 и ожидаемые owner/group проверены; после второго раунда пять gzip-архивов. Timer enabled/active; обычный service result success, exit 0.
- В очищенное baseline evidence добавлены выбранные поля отдельных restart/outage и ротаций, без персональных путей, inode, MAC и секретов. Совмещённая потеря Loki outage+Alloy restart остаётся отдельным известным ограничением; retention 168h не означает наблюдённое удаление через семь суток.
- По отдельному явному разрешению запущен `ansible/reboot.yml` только для новых VM, последовательно ubu1→ubu2. Итоговые результаты и проверки после старта пока не получены, успех заранее не заявляется.

## Этап 13 — последовательные reboot и повторная приёмка

- По отдельному разрешению перезагружены только новые VM последовательно ubu1→ubu2. `reboot.yml` завершился на каждой `ok=7 changed=1 unreachable=0 failed=0`; boot ID обеих VM изменились. Теперь запущено ядро 6.8.0-147-generic вместо прежнего 6.8.0-136-generic. Гипервизор и домашний роутер не перезагружались.
- После старта IPv4 forwarding сохранился web=0, hub=1; IPv6 forwarding=0 на обеих VM. Новые VPN key/sudo SSH работают; отдельные root/password/keyboard-interactive пробы снова отвергнуты. Повторены 18 VPN и 36 независимых Windows LAN IPv4/IPv6 TCP-проб по прежнему списку, все ожидания совпали.
- Новые normal/SQLi запросы дали HTTP 200/403, engine Enabled и прежние CRS rule IDs. Normal/access, SQLi/access и SQLi/audit найдены по одной записи. Старые три baseline записи в Loki сохранились после reboot; Grafana datasource health OK. Оба guard clear, rollback timers отсутствуют.
- Домашний роутер проверен только GET: identity, две закреплённые leases и два disabled DNAT соответствуют проекту. Внешняя публикация не включалась и внешняя WAN-приёмка не заявляется.
- В baseline evidence добавлены whitelist post-reboot summaries, новое запущенное ядро и вычисленные pass для LAN open=false. У LAN источника нет готового поля pass, это явно отмечено; точное время портовых проб не придумано. Подготовлен [короткий сценарий защиты](demo.md).
- Финальные обычные secure/site после reboot ещё выполняются, их будущий результат не подменяется прежними changed=0. Материальные ограничения доставки, ротации и ненаблюдавшегося семисуточного expiry сохранены.

## Этап 14 — финальная идемпотентность и локальный комплект

- Финальные обычные secure/site после обеих reboot и итогового rotation helper прошли: secure обе VM `ok=34 changed=0 failed=0 unreachable=0`; site `ubu1 ok=45 changed=0 failed=0 unreachable=0`, `ubu2 ok=25 changed=0 failed=0 unreachable=0`. Это актуальное доказательство идемпотентности текущего кода, а не ссылка только на прежний прогон.
- Финальный snapshot подтвердил active/enabled для ожидаемых постоянных служб. `ssh.service` active/disabled ожидаем при active/enabled `ssh.socket`; QGA active/static ожидаем при udev activation. Оба access guard clear, rollback timers disabled, pending snapshots отсутствуют.
- WAF running/healthy, host networking, published port bindings отсутствуют; config/site mounts read-only, log mount writable, capabilities ограничены. Access/audit positions и WAL state присутствуют, Loki storage существует. Свободный диск на момент snapshot: около 14.96 GB ubu1 и 24.71 GB ubu2; это не нагрузочный прогноз.
- Очищенное baseline evidence включает финальные whitelist summaries, post-reboot приёмку и реальные recap. Отдельно сохранены три ограничения: совмещённый Loki outage+Alloy restart потерял события, ротация кратко перезапускает WAF, семисуточное expiry ещё не наблюдалось. Runtime acceptance помечена завершённой в этих границах; полная acceptance не выдаётся за проверенное семисуточное удаление.
- Локальная проверка candidate-файлов не нашла домашних LAN-адресов, MAC, host key fingerprints, private-key blocks, literal WG keys, URL credentials и личных controller paths. JSON proof разбирается, локальные Markdown links существуют. Финальная вычитка владельцем задачи остаётся перед публикацией; публикации, push и отправки работодателю не было.

## Этап 15 — прямой Windows WireGuard и Grafana через LAN endpoint

- Пользователь уточнил, что нужен отдельный WireGuard-клиент Windows, аналогичный будущему reviewer, сейчас только через домашнюю LAN. Установленный WireGuard for Windows использует отдельный проектный peer `10.77.42.4/32`, только host routes к hub/web, без default route и DNS. Пользователь импортировал и активировал профиль; его приватный путь, LAN endpoint и ключи не публикуются. SSH tunnel для этого доступа не запускался.
- При первом применении найден реальный дефект приоритета Ansible variables: reviewer=true в inventory all.vars перекрывался group_vars/all/main.yml с false. Первый secure дал changed=0 и не добавил peer, поэтому активная Windows service и правильные routes ещё не означали рабочего VPN. Исправлено в игнорируемом inventory: lab_reviewer_enabled=true задан отдельно для обоих hosts; эффективные значения проверены как true. Повторный secure на обеих VM завершился `ok=38 changed=7 failed=0`; это применение peer, а не идемпотентный повтор прежнего baseline.
- Native Windows-проверка прошла: tunnel service Running, два ожидаемых /32 routes, Grafana health HTTP 200, web normal 200, SQLi 403. Центральные normal/access, SQLi/access и SQLi/audit найдены по одной записи; WAF engine Enabled, правила CRS 942100/949110 и общий request/transaction ID подтверждены. Наблюдённый источник — проектный Windows WG-IP `10.77.42.4`.
- После изменения свежий WSL key/sudo SSH и отрицательные auth-пробы остались успешными; отдельные Windows LAN TCP/22-пробы к обеим VM по-прежнему отрицательные. Затем выполнен commit, оба guard clear, rollback timers inactive/disabled. Host-переменные reviewer=true сохраняются и повторно проверены в эффективном inventory.
- По явному запросу пользователя создан защищённый локальный файл только с URL Grafana, логином и паролем. Его содержимое не выводилось в чат и не добавляется в репозиторий; в ходе этой документационной работы файл не читался.
- Добавлено очищенное [Windows LAN VPN evidence](evidence/windows-lan-vpn.json) из выбранных полей двух proof summaries; исходный baseline оставлен исторически неизменным. Обе WAN DNAT всё ещё disabled, внешний endpoint не проверялся. Текущий результат подтверждает только Windows VPN через LAN.

## Этап 16 — наглядный дашборд Grafana

- По запросу пользователя добавлен дашборд `OZZYLOGIK · Web & WAF`, UID `ozzylogik-waf`, путь `/d/ozzylogik-waf`. Он доступен в Grafana через уже настроенный WireGuard; изменения внешнего доступа не требуются.
- В 11 панелях: вводное описание, четыре карточки запросов/HTTP 200/подтверждённых блокировок/разных IP, два графика частоты в минуту, распределение HTTP-кодов, активные IP и два списка последних access/audit событий. Данные берутся из существующего Loki `ozzylogik-loki`; метрики CPU/RAM не добавлялись.
- Loopback-автопроверки исключены. Блокировки считаются по `transaction.is_interrupted=true`, а не по всем audit-событиям или любому HTTP 403. По умолчанию выбран период 24 часа и обновление 30 секунд.
- JSON дашборда и file provider включены в роль monitoring; для отдельного применения добавлен tag `grafana_dashboard`. Финальное применение: `ubu2 ok=7 changed=2 unreachable=0 failed=0`; повтор: `ok=6 changed=0 unreachable=0 failed=0`. Прежний baseline оставлен исторически неизменным.
- Grafana API подтвердил provisioned dashboard в папке OZZYLOGIK и успешные непустые ответы всех десяти query-панелей через datasource query API. Новая пара запросов из Windows WireGuard дала 200/403; normal/access, SQLi/access и SQLi/audit найдены по одной записи, WAF engine Enabled и CRS rules подтверждены. Карточки изменились: запросы 18→20, HTTP 200 9→10, подтверждённые блокировки 8→9; разных IP осталось 2. Очищенное [dashboard evidence](evidence/grafana-dashboard.json) сохранено отдельно. Отрисовка в браузере не проверялась.

## Этап 17 — приватный GitHub-репозиторий

- Пользователь явно разрешил создание приватного репозитория и push всего IaC. Создан [Zigoxip/ozzylogik-secops-lab](https://github.com/Zigoxip/ozzylogik-secops-lab); GitHub API подтвердил `isPrivate=true`, `visibility=PRIVATE` до загрузки файлов.
- В комплект входят Ansible, вспомогательные скрипты, Grafana dashboard, документация и очищенные evidence. Рабочие inventory, исходные отчёты, ключи, пароли и клиентские VPN-профили исключены. Локальная проверка 94 candidate-файлов не нашла совпадений с реальными секретами и домашними идентификаторами.
- Перед первым commit уточнена документация текущего Windows peer и добавлен комментарий в пример inventory о host-level override. Работающая инфраструктура для публикации не изменялась.

## Следующий этап

Совместный пошаговый разбор структуры, кода и принятых решений. Семисуточное expiry остаётся ненаблюдавшимся ограничением; внешняя WAN/demo и Telegram не заявлены выполненными. Репозиторий остаётся приватным; отправка результатов работодателю отдельно не согласовывалась.
