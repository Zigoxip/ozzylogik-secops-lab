# Приёмочные проверки

## Текущий статус

Стенд развёрнут: `101 / ubu1` и `102 / ubu2` — отдельные full-clone Ubuntu VM с 2 vCPU каждая, 2/4 GiB RAM и дисками 20/30 GiB соответственно. DHCP leases новых узлов закреплены; исходный template `9000` сохранён. Базовые пакеты обновлены, cloud-init завершён с `errors=[]`; известная Proxmox deprecation учтена отдельно.

Bootstrap завершён без failed; через WG подтверждены новые key-only SSH-сеансы `labadmin` и sudo на обе VM. Окончательная SSH/firewall-политика применена: root/password/keyboard-interactive входы отвергнуты, эффективная SSHD-конфигурация проверена. Независимые новые Windows Ethernet LAN TCP22-пробы не проходят на обе VM, тогда как новый VPN SSH работает. Secure завершён `ok=38 changed=6 failed=0`, commit — `ok=5 changed=1 failed=0` на каждом узле. После commit оба guard отдельно проверены: pending snapshot отсутствует, rollback timer inactive и disabled.

Базовая приёмка подтвердила HTTP 200/SQLi 403, CRS blocking, центральные access/audit, client IP и Grafana→Loki health. После исправлений Docker forwarding реальные повторные secure/site дали changed=0/failed=0/unreachable=0 на обоих узлах. Обычный restart Alloy при доступном Loki, отдельный outage Loki при работающем Alloy и две ротации с доставкой новых access/audit прошли. Совмещённый outage+restart потерял marker; ротация требует короткого restart WAF. Разрешённые последовательные reboot прошли: повторены WAF/логи, SSH/auth, 18 VPN и 36 LAN IPv4/IPv6 TCP-проб, Grafana health; старый baseline Loki сохранён. Финальные secure/site после reboot также дали changed=0/failed=0/unreachable=0 на обоих узлах. [Очищенное evidence](evidence/baseline.json). WAN DNAT TCP/80 и UDP/51820 остаются **disabled**, Telegram не реализован.

Работающая конфигурация: Nginx, ModSecurity и OWASP CRS на `ubu1`; Loki и Grafana на `ubu2`; Alloy на `ubu1` доставляет оба вида веб-логов. WireGuard hub на `ubu2`, peers — `ubu1` и управляющий WSL; reviewer peer готовится отдельно на demo. Внутри туннеля NAT нет. App versions/checksums закреплены в versions.md; Docker.io apt candidate прочитан и зафиксирован до web role. Эти решения проекта подтверждены runtime-проверками, перечисленными ниже.

Аудит управляющей среды/Proxmox выполнен: SSH ключом работает, ресурсы были проверены перед созданием. Он не заменяет гостевые проверки ниже. Root-вход на гипервизор не нарушает запрет root SSH именно на тестовых Ubuntu VM. Полные операционные журналы остаются в `.local/`; перед публикацией нужны очищенные выписки без домашней LAN, MAC, host fingerprints и секретов.

## Матрица требований

| ID | Требование | Ожидаемое доказательство | Статус | Причина |
|---|---|---|---|---|
| V01 | Два узла Ubuntu с ролями `ubu1` и `ubu2` | Инвентаризация созданных VM, ОС и назначений | выполнено и проверено | VM101/102 созданы; ресурсы, cloud-init, runtime Ubuntu 24.04.5 и назначения приложений проверены |
| V02 | Firewall default deny, только необходимые соединения | Действующие правила, перечень слушающих сокетов и проверки разрешённых/запрещённых соединений | выполнено и проверено | Конечная политика committed; после site совпали18 VPN и36 LAN IPv4/IPv6 TCP-проб по согласованному списку портов |
| V03 | Административный пользователь входит по ключу на обе VM | Новые успешные сеансы по VPN, без SSH multiplexing | выполнено и проверено | Новые строгие VPN SSH-сеансы labadmin и sudo uid0 успешны на обоих узлах |
| V04 | Root SSH запрещён на обеих VM | Отказ на уровне SSH через работающий VPN и эффективная конфигурация | выполнено и проверено | Root-вход отвергнут на обе VM; эффективная SSHD-политика проверена, запрет не выведен только из отсутствия root key |
| V05 | Парольный и keyboard-interactive SSH запрещены | Раздельные попытки через VPN без ключа; сервер не предлагает эти способы | выполнено и проверено | Обе отдельные auth-пробы отвергнуты на обе VM; сервер предлагает только publickey, effective policy соответствует |
| V06 | WireGuard размещён на `ubu2` | Hub/peer-конфигурация и реальный трафик к WG-IP обеих VM | выполнено и проверено | Bootstrap применён, hub на ubu2 и WSL→WG SSH к обоим узлам работают; клиентский MTU1200 устранил наблюдённый kex hang |
| V07 | SSH к `ubu1` работает только через VPN | Новый WSL → WG-IP SSH успешен; независимый новый Windows Ethernet LAN → LAN-IP TCP22 запрещён | выполнено и проверено | LAN TCP22 false для обе VM при успешном новом VPN SSH; secure и commit завершены, guard clear проверен |
| V08 | Лишние порты закрыты; учтены IPv6 и Docker | Пробы согласованных портов, IPv6-политика, host-network/no-published-ports invariants | выполнено и проверено | Все54 TCP-пробы совпали; LAN IPv4/IPv6 закрыты, VPN открывает только web22/80 и hub22/3000 среди проверенных портов; не заявляется полный TCP/UDP scan |
| V09 | Веб/WAF-стек развёрнут Ansible | Playbook и фактический результат на `ubu1` | выполнено и проверено | Исправленный второй site завершён без failed/unreachable; container invariants/nginx-t/HTTP80 и HTTP-приёмка прошли |
| V10 | ModSecurity блокирует; CRS загружен | Engine Enabled, реальный CRS rule ID и blocking action | выполнено и проверено | В audit Enabled, OWASP_CRS4.30.0, SQLi942100 и blocking949110; HTTP403 сопоставлен с событием |
| V11 | Обычный HTTP-запрос проходит и централизованно виден | HTTP200 и запись Nginx на `ubu2` с correlation ID | выполнено и проверено | Baseline normal200 найден в центральном access stream по уникальному marker |
| V12 | SQLi блокируется и централизованно виден | HTTP403, access/audit events, rule ID и общий идентификатор | выполнено и проверено | Baseline SQLi403 найден в обоих центральных streams; audit transaction ID совпал с access request ID |
| V13 | Известен IP клиента, наблюдаемый WAF | Сопоставление источника теста и фактических access/audit полей | выполнено и проверено | Наблюдён проектный WG-IP клиента10.77.42.3, correlation и request/transaction ID совпали; packet capture этим результатом не заявляется |
| V14 | Доставка логов переживает рестарт; работают checkpoints и ротация | Маркеры до/после restart/rotation, состояние и потери/дубликаты | выполнено и проверено | Обычный restart, отдельный Loki outage и две ротации дали по одной записи каждого ожидаемого типа; совместный outage+restart потерял marker и остаётся ограничением, ротация кратко перезапускает WAF |
| V15 | Хранение логов ограничено и диск контролируется | Настройки и проверка local logrotate, Loki retention, служебных/container logs и занимаемого места | выполнено без проверки | Две ротации, gzip, права и timer проверены; retention 168h настроен, реальное семисуточное удаление ещё не наблюдалось |
| V16 | Повторный запуск Ansible идемпотентен | Реальный повтор steady-state secure/site: changed0/failed0/unreachable0 | выполнено и проверено | Secure обе VM ok34/changed0, site ubu1 ok45/changed0 и ubu2 ok25/changed0; failed/unreachable0 во всех четырёх recap |
| V17 | Стенд переживает согласованную перезагрузку | Отдельное согласование reboot; повторные проверки VPN, SSH, WAF, логов и хранения после старта | выполнено и проверено | Обе boot ID сменились, ядро 6.8.0-147; повторены WAF/логи, SSH/auth, 18 VPN и 36 LAN TCP-проб, Grafana; старый baseline Loki сохранён |
| V18 | Ansible-код и короткий README готовы к GitHub/GitLab | Полный локальный комплект, версии, инструкции, ограничения и проверка на секреты | выполнено и проверено | Локальный комплект и очищенное evidence готовы; JSON, ссылки и privacy patterns проверены. Публикация/отправка отдельно не разрешались, финальная вычитка владельцем задачи остаётся |
| O01 | Опционально: алерт при более 5 блокировках/IP/мин | Проверены 5/6 событий, окно, разделение IP, текст с IP/количеством и подавление повторов | не выполнено | Опциональный этап не начинался; сначала обязательная приёмка |

Начальные документы сами по себе не означают выполнение V18. Публикация репозитория требует отдельного согласования.

## Правила выполнения и фиксации

- Все команды с `<PLACEHOLDER>` — **образцы**, непригодные для запуска без подстановки проверенных значений. IP, интерфейсы, пути, порты и имена пользователей не назначены этим документом.
- Сначала согласовать конкретные изменения сети, firewall, SSH и постоянного доступа вместе с откатом. Проверять новый путь до отключения действующего. Таймер отката отменять только после проверки отдельным новым соединением.
- Проверки перезапуска сервисов и ротации включить в согласованный план. **Перезагрузка VM требует отдельного явного согласования**; этот документ разрешением не является.
- Использовать новые SSH/TCP-сеансы. Сохранённое соединение по established и SSH ControlMaster может скрыть потерю доступа.
- Не помещать секреты в команды, Git, отчёты или снимки. Не сохранять private keys и WireGuard dumps с секретами. Не отключать проверку SSH host key; ключи хостов предварительно проверить.
- SQLi отправлять **только на наш подтверждённый тестовый `ubu1`**. Внешние адреса и сторонние системы исключены.
- Для каждого запуска записывать время с часовым поясом, точку запуска, цель, ожидаемый и фактический результат, ссылку на очищенное доказательство. При сбое сохранить причину; не менять статус на «выполнено» до проверки.

## 1. Базовый доступ и SSH-аутентификация

С WSL создать отдельные новые сеансы к WG-IP обеих VM. Пример для каждой VM:

```bash
ssh -p <SSH_PORT> -S none -o ControlMaster=no -o ControlPath=none \
  -o IdentitiesOnly=yes -o IdentityAgent=none -o BatchMode=yes \
  -i <LOCAL_TEST_PRIVATE_KEY> <ADMIN_USER>@<VM_WG_IP> 'id -un'
```

Ожидается успешная аутентификация по согласованному ключу именно обычного административного пользователя. Проверить sudo отдельно, не выводя пароль. Фактически: новые строгие VPN SSH-сеансы `labadmin` успешны на обеих VM, отдельно подтверждён `sudo` uid0; multiplexing отключён.

Проверять root и пароль **через уже работающий VPN**, чтобы отказ firewall нельзя было принять за запрет SSH-аутентификации. Сначала положительный тест обычного пользователя на том же адресе/порту, затем:

```bash
# Root с ключом: сервер SSH должен быть достижим и отказать во входе.
ssh -vv -p <SSH_PORT> -S none -o ControlMaster=no -o ControlPath=none \
  -o IdentitiesOnly=yes -o IdentityAgent=none -o BatchMode=yes \
  -i <LOCAL_TEST_PRIVATE_KEY> root@<VM_WG_IP> true

# Password: ключи и keyboard-interactive исключены.
ssh -v -p <SSH_PORT> -S none -o ControlMaster=no -o ControlPath=none \
  -o PubkeyAuthentication=no -o KbdInteractiveAuthentication=no \
  -o PreferredAuthentications=password <ADMIN_USER>@<VM_WG_IP> true

# Keyboard-interactive: ключи и password исключены.
ssh -v -p <SSH_PORT> -S none -o ControlMaster=no -o ControlPath=none \
  -o PubkeyAuthentication=no -o PasswordAuthentication=no \
  -o PreferredAuthentications=keyboard-interactive <ADMIN_USER>@<VM_WG_IP> true
```

Ожидается отказ на уровне SSH. Password и keyboard-interactive не должны предлагаться сервером; отказ из-за неверного введённого пароля не доказывает запрет способа аутентификации. Не вводить и не записывать реальные пароли для этих проб.

Дополнительно проверить эффективную конфигурацию для root и административного пользователя с учётом `Match`/include-файлов, используя контекст реального VPN-подключения:

```bash
sudo sshd -T -C user=<TEST_USER>,addr=<WSL_WG_IP>,host=<CLIENT_HOSTNAME>,laddr=<VM_WG_IP>,lport=<SSH_PORT>
sudo journalctl -u ssh --since '<TEST_START_TIME>' --until '<TEST_END_TIME>'
```

Ожидаемые настройки: `permitrootlogin no`, `passwordauthentication no`, `kbdinteractiveauthentication no`, `pubkeyauthentication yes`. Сам по себе отказ root с неавторизованным ключом недостаточен: сопоставить его с эффективной политикой; при разборе отказов использовать серверный журнал. Не добавлять ключ root ради этой проверки. Фактически: root, password и keyboard-interactive пробы отвергнуты на обеих VM, сервер предлагал только publickey; эффективная конфигурация обоих SSHD проверена и соответствует.

## 2. Доказательство VPN-only SSH

Предварительные ограничения: на `ubu1` вход SSH разрешён только с `wg0` от WG-IP WSL; на hub forwarding разрешён только между нужными peers/портами. Одного условия source IP недостаточно: пакет с похожим адресом не должен приниматься с LAN-интерфейса.

Примеры проверки маршрутов и handshakes:

```bash
# WSL: маршрут к ubu1 должен идти через WireGuard.
ip -4 route get <UBU1_WG_IP>
sudo wg show <WSL_WG_INTERFACE> latest-handshakes
sudo wg show <WSL_WG_INTERFACE> allowed-ips

# ubu2: маршрут пересылаемого пакета WSL → ubu1.
ip -4 route get <UBU1_WG_IP> from <WSL_WG_IP> iif <HUB_WG_INTERFACE>

# ubu1: обратный маршрут к WSL.
ip -4 route get <WSL_WG_IP>
```

Во время **нового** положительного SSH-сеанса одновременно снять ограниченный захват на `ubu1`:

```bash
sudo tcpdump -ni <UBU1_WG_INTERFACE> -c <PACKET_LIMIT> 'host <WSL_WG_IP> and tcp port <SSH_PORT>'
sudo tcpdump -ni <UBU1_LAN_INTERFACE> -c <PACKET_LIMIT> 'udp port <HUB_WG_PORT> or tcp port <SSH_PORT>'
```

Ожидается внутренний TCP/SSH с WG-IP WSL на WireGuard-интерфейсе и WireGuard UDP на физическом интерфейсе. Параллельные captures запускать отдельными сеансами/консолью; ограничить длительность и объём. Handshake без успешного SSH и маршрута недостаточен.

Отрицательную проверку выполнять из **обычного Windows PowerShell вне WSL**, при отсутствии VPN-маршрута Windows к тестовой VM:

```powershell
Get-NetRoute -AddressFamily IPv4
Test-NetConnection -ComputerName '<UBU1_LAN_IP>' -Port <SSH_PORT> -InformationLevel Detailed
ssh.exe -p <SSH_PORT> -S none -o ControlMaster=no -o ControlPath=none -o ConnectTimeout=5 -o BatchMode=yes <ADMIN_USER>@<UBU1_LAN_IP> true
```

Ожидается отсутствие TCP/SSH-доступа из LAN. Зафиксировать реальный исходящий интерфейс/источник Windows. Проверить запрещённый путь и к WG-IP с LAN, если к нему существует LAN-маршрут; отсутствие такого маршрута не заменяет проверку правила `iifname` на `ubu1`. Повторить положительную VPN-проверку после отрицательной, чтобы исключить отказ всего сервиса. Фактически: новые Windows Ethernet LAN TCP22-пробы к обеим VM дали false, при этом новые VPN SSH-сеансы работают. Проба к WG-IP из LAN и пакетный capture этим результатом не заявляются.

## 3. Firewall, IPv6 и Docker

```bash
sudo nft -a list ruleset
sudo ss -lntup
ip -6 address show
ip -6 route show
```

Сопоставить слушающие сокеты с будущей таблицей разрешённых потоков. Input/forward должны запрещать всё, кроме согласованных соединений, включая необходимые служебные протоколы. Проверить новые соединения из WSL/VPN и Windows/LAN; один перечень правил не заменяет сетевые пробы.

Проверить IPv6 отдельно: если включён, повторить нужные разрешённые/запрещённые пробы по его адресам и убедиться в общей политике IPv4/IPv6. Если в проекте его отключат, документировать это решение и подтвердить фактическое состояние после старта. Не предполагать, что отсутствие плановых IPv6-адресов означает отсутствие IPv6-доступа.

Docker WAF использует host network с фильтрацией INPUT, published ports отсутствуют; monitoring и collector — native services. После handlers роль отдельно проверяет network/mounts/image invariants. Фактически совпали18 VPN и36 независимых LAN IPv4/IPv6 TCP-проб: порты22,80,443,3000,3100,8080,8443,9096,12345 для обеих VM. Из административного VPN разрешены только ubu1 TCP22/80 и ubu2 TCP22/3000 среди проверенных; из LAN все закрыты. [Baseline evidence](evidence/baseline.json). Это не полный scan и не доказательство внешней WAN-доступности.

## 4. HTTP 200, SQLi 403 и корреляция

Сначала подтвердить тестовый адрес и блокирующий режим ModSecurity, загрузку CRS и путь к audit log. Для каждого запроса использовать новый уникальный маркер; настроить его запись в Nginx access log и сохранение request headers в соответствующем WAF audit event. Маркер теста — поле содержимого лога, а не высококардинальная Loki label.

Обычный запрос с WSL по VPN, только к нашей VM:

```bash
curl -sS --get --data-urlencode 'lab_id=<NORMAL_UUID>' \
  -H 'X-Lab-Correlation-ID: <NORMAL_UUID>' \
  -w '\nHTTP %{http_code}\n' 'http://<UBU1_WG_IP>/'
```

Ожидается HTTP 200. Найти соответствующий access event в централизованном хранилище на `ubu2`; локальной записи на `ubu1` недостаточно. Для обычного запроса отдельная WAF audit-запись может отсутствовать при политике записи только значимых событий.

SQLi-пример применим исключительно к нашему подтверждённому тестовому `ubu1`:

```bash
curl -sS --get --data-urlencode "id=1' OR '1'='1" \
  --data-urlencode 'lab_id=<SQLI_UUID>' \
  -H 'X-Lab-Correlation-ID: <SQLI_UUID>' \
  -w '\nHTTP %{http_code}\n' 'http://<UBU1_WG_IP>/'
```

Ожидается HTTP 403. Подтвердить, что его вернул WAF из-за CRS, а не firewall, отсутствующего файла или другого обработчика. На `ubu2` найти Nginx access event и WAF audit event; записать фактические CRS rule ID, WAF transaction ID и общий correlation ID. Не подставлять предполагаемый rule ID в отчёт. Если выбранный payload не блокируется, требование остаётся непроверенным до разбора режима, правил и порога; не выдавать detection-only за успех.

Фактические labels для повторения запросов LogQL:

```logql
{job="ozzylogik",instance="ubu1",log_type="access"} |= "<NORMAL_UUID>"
{job="ozzylogik",instance="ubu1",log_type="access"} |= "<SQLI_UUID>"
{job="ozzylogik",instance="ubu1",log_type="audit"} |= "<SQLI_UUID>"
```

Фактически normal200 и SQLi403 найдены на `ubu2`; SQLi есть одновременно в access и audit. Engine `Enabled`, component OWASP_CRS4.30.0, rule IDs942100/949110 (также920350) взяты из реального события. Audit transaction ID и access request ID совпали. Наблюдённый source — `10.77.42.3`, проектный WG-IP WSL. Заголовок XFF не используется как доказательство источника. [Очищенная baseline-запись](evidence/baseline.json) сохраняет markers и IDs; её WAF timestamp приведён к UTC с учётом исходного +03 offset.

Для новых controlled requests можно запускать `scripts/verify-http-logs.py --web-url http://10.77.42.2` из WSL. Сам скрипт доказывает только HTTP statuses и выдаёт `waf_audit_pending=true`; отдельно подтвердить оба central streams, как выполнено в baseline. Не пересылать в лабораторный audit реальные cookies, credentials и tokens.

## 5. Alloy, checkpoints, рестарты и ротация

До теста определить реальные log paths, пользователя Alloy, права чтения и постоянный каталог состояния. Checkpoints должны сохраняться между рестартами и пересозданием контейнера, если он используется; временный каталог для них не подходит.

План проверки после согласования:

1. Создать уникальные маркеры обычного запроса и SQLi, дождаться обоих типов логов на `ubu2`.
2. Зафиксировать состояние доставки и checkpoints без раскрытия секретов, перезапустить Alloy на `ubu1`, создать новые маркеры, проверить старые и новые события на `ubu2`.
3. Проверить повторное подключение к Loki после рестарта сервиса на `ubu2`; подтвердить доставку накопленного хвоста. Допустимое окно недоступности и политика буферизации должны быть описаны, а не предполагаться.
4. Выполнить согласованную контролируемую ротацию access/audit logs. Создавать маркеры до, во время и после неё; проверить чтение переименованного файла и нового файла, права и повторное открытие файла веб-процессом.
5. Сопоставить количество событий по маркерам. Зафиксировать потери или дубликаты; не обещать exactly-once без подтверждённого механизма. `copytruncate` отдельно оценить из-за риска потери данных во время копирования/усечения.

Фактически отдельный Loki outage без restart Alloy восстановил normal/access и SQLi/access+audit по одной записи; обычный Alloy restart при доступном Loki сохранил по одной, новые marker после restart также по одной. Positions до/после и WAL state присутствуют, старый baseline сохранился после рестартов Loki.

Первая HUP-only ротация не прошла: access переоткрылся, но ModSecurity продолжал писать audit в переименованный архив, поэтому новый SQLi audit не попал в центральный результат. Helper исправлен на restart WAF с ожиданием локального HTTP 200. Это даёт короткий перерыв доступности, а не бесшовный reopen.

Две повторные принудительные ротации прошли: в каждом раунде новые normal/SQLi найдены в активном access, SQLi — в активном audit; центральные counts normal/access, SQLi/access и SQLi/audit равны 1. Access inode менялся в обоих раундах; в первом audit был пуст до ротации и сохранил inode, во втором audit inode изменился. Активные файлы имеют 0640 с проверенными owner/group, после второго раунда присутствуют пять gzip-архивов. Timer enabled/active, обычный service result success/exit 0. Числовые inode и домашние пути в public evidence не копируются.

**Известный провал совмещённого сценария:** restart Alloy при остановленном Loki потерял два новых marker в центральной доставке (counts0/0) при сохранённых host logs. Shutdown flush/drop зафиксирован, backfill не выполнялся. Этот результат сохранён в baseline как limitation и не отменяется успехом двух отдельных сценариев. Lossless/exactly-once для такого отказа не заявляются.

## 6. Retention и пределы хранения

Предусмотреть и затем проверить ограничения для Nginx access/audit logs, Loki data, journal и Docker logs, если Docker выбран. Настройки local logrotate не ограничивают размер Loki автоматически. Для Loki нужны явно заданная retention-политика, поддерживаемые выбранной версией механизмы удаления и постоянное хранилище.

```bash
df -h <WEB_LOG_FS_PATH> <LOKI_DATA_FS_PATH>
du -sh <WEB_LOG_DIR> <LOKI_DATA_DIR>
```

Записать выбранные сроки хранения, пределы/запас диска, расписание ротации, сжатие и ожидаемую задержку удаления. Проверка конфигурации — промежуточный шаг. Реальное удаление устаревших данных подтвердить выдержанным сроком хранения либо отдельным согласованным контролируемым тестом, поддерживаемым выбранной версией; не выдавать ещё не истёкший срок за успешный retention test. Фактически: **не запускалось**.

## 7. Ansible: повторный запуск и отдельный reboot

После начального развёртывания выполнить ещё один **реальный** прогон тем же inventory и переменными:

```bash
ansible-playbook -i <INVENTORY_PATH> <PLAYBOOK_PATH>
```

Фактически повторные secure/site дали changed0/failed0/unreachable0 на обеих VM; [recap](evidence/baseline.json) получен обычным запуском. Secure: ok34 на каждом; site: ok45 web и ok25 hub. До этого Docker forwarding drift исправлен, не скрыт. `--syntax-check`/`--check` за этот результат не выдавались; bootstrap повторно не запускается на уже защищённом стенде.

**Reboot — отдельный этап, разрешение на обе VM получено и выполнено.** Привилегированный Guest Agent recovery заранее подтверждён на обоих гостях. `reboot.yml` с gate и guard-clear precondition прошёл последовательно ubu1→ubu2: обе VM `ok=7 changed=1 failed=0 unreachable=0`. Boot ID обеих VM изменились, запущенное ядро теперь 6.8.0-147-generic. IPv4 forwarding: web=0, hub=1; IPv6 forwarding=0 на обеих VM. Снова прошли свежие VPN key/sudo и отдельные отказы root/password/keyboard-interactive, 18 VPN и 36 независимых LAN IPv4/IPv6 TCP-проб. Новые normal/SQLi дали HTTP 200/403 и по одной ожидаемой центральной access/audit записи, старые три baseline записи Loki сохранились. Grafana datasource health OK, guard clear подтверждён отдельно. Финальные обычные secure/site после reboot завершились: secure обе VM ok=34/changed=0, site ubu1 ok=45/changed=0 и ubu2 ok=25/changed=0; failed=0/unreachable=0 везде.

## 8. Опциональный Telegram-алерт

Начинать после обязательных пунктов и согласования внешней отправки. Токен и chat ID хранить вне Git и очищенных доказательств.

Проверить: 5 блокировок одного IP за минуту — алерта нет; 6 — алерт есть и содержит IP и фактическое количество. События разных IP не суммируются. Зафиксировать выбранную семантику минутного окна и проверить его границу; не считать фиксированное окно автоматически эквивалентным скользящему. Проверить подавление лавины одинаковых уведомлений и повторное уведомление после восстановления. Источником подсчёта должны быть уникальные блокировки, чтобы access и audit записи одного запроса не считались дважды. Фактически: **не запускалось**.

## Реестр доказательств

[docs/evidence/baseline.json](evidence/baseline.json) содержит WAF/центральную корреляцию, Grafana health, SSH auth/effective policy, 54 TCP-пробы, реальные runtime versions, идемпотентные recap secure/site, отдельные restart/outage, две ротации и post-reboot проверки. Домашние LAN targets заменены именами ubu1/ubu2, интерфейсы/MAC/ключи исключены. Исходные port summaries не содержали времени — точный timestamp не придуман. Совмещённая недоставка, короткий restart WAF при ротации и ненаблюдавшееся семисуточное expiry отмечены как ограничения. Артефакт отмечает `runtime_acceptance_complete=true` с перечисленными ограничениями; `acceptance_complete=false` сохранён, поскольку семисуточное удаление не наблюдалось. Финальная публикационная вычитка владельцем задачи остаётся отдельным шагом.

Для V01–V14 критерии подтверждены с указанными границами портовых проб и доставки, V16 подтверждён реальными повторами, V17 — фактическими последовательными reboot и postboot-проверками. После commit оба guard clear проверены отдельно. Полные операционные записи остаются в `.local/`. Незавершённые проверки и материальное ограничение V14 не скрываются за baseline. Для короткой защиты подготовлен [сценарий demo](demo.md); открытие WAN и публикация им не разрешаются.

Финальный snapshot после reboot и Ansible подтвердил активные ожидаемые службы, оба guard clear, disabled rollback timers и отсутствие pending snapshots. `ssh.service` active/disabled корректен при `ssh.socket` active/enabled; Guest Agent active/static запускается через udev. WAF healthy с host networking, без published port bindings, с двумя read-only mounts и одним writable log mount. Positions обоих streams и WAL state присутствуют, Loki storage существует. Свободно около 14.96 GB на ubu1 и 24.71 GB на ubu2 на момент snapshot; это текущий запас, не прогноз ёмкости. Числа и timestamp сохранены в final_state evidence.

Локальные предварительные проверки зафиксированы в worklog: actual Loki/Alloy binary validators, Ansible syntax-check и16nft kernel dry-runs. Они не являются приёмкой приложений. Runtime реестр должен содержать ID проверки, дату/время, точку запуска, ожидаемый и фактический результат, очищенный файл и итоговый статус. До появления файлов не добавлять фиктивные ссылки или успешные выводы.
