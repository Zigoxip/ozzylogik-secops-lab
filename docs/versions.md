# Зафиксированные версии

Проверка источников и runtime: 23.10.2026. Ниже разделены immutable app pins и фактически прочитанные версии новых VM. Очищенная runtime-проекция и результаты повторного применения: [baseline.json](evidence/baseline.json). Пин сам по себе не заменяет чтение установленного компонента.

| Компонент | Версия / источник | Состояние |
|---|---|---|
| Proxmox | 9.1.1, kernel6.17.2-1-pve | Наблюдено, не обновляли |
| Guest Ubuntu | 24.04.5 LTS, kernel 6.8.0-147-generic на обоих узлах | Прочитано после согласованного reboot; до него работало 6.8.0-136-generic. Исходный template был 24.04.4, source не менялся |
| WSL Python | 3.14.4 | Наблюдено |
| ansible-core | 2.21.5 | Установлен в отдельный venv; [матрица Python3.12–3.14](https://docs.ansible.com/projects/ansible/latest/reference_appendices/release_and_maintenance.html) |
| Collections | ansible.posix2.1.0, community.docker5.4.0, community.library_inventory_filtering_v1 1.1.5 | Установлены в WSL, requirements.yml |
| Controller pip dependencies | requirements-control.txt | Все прямые/транзитивные версии зафиксированы после установки |
| WSL wireguard-tools | 1.0.20250521-1ubuntu1 | Установлен; административный WG-клиент работает, MTU1200 при внешнем WSL MTU1280 |
| OWASP CRS image | 4.30.0-nginx-202610180210 | [Официальный репозиторий](https://github.com/coreruleset/modsecurity-crs-docker), tag+digest в коде; runtime audit подтвердил CRS4.30.0 и blocking |
| Nginx в WAF | 1.30.6 | Фактически прочитано из запущенного pinned image |
| libModSecurity / connector | 3.0.17 / 1.0.4 | Фактически прочитано; загружено856 правил, audit engine Enabled |
| Alloy | 1.21.1 | [Release](https://github.com/grafana/alloy/releases/tag/v1.21.1), SHA/validate и runtime version проверены; центральная доставка подтверждена |
| Loki | 3.7.9 | [Release](https://github.com/grafana/loki/releases/tag/v3.7.9), SHA/verify-config и runtime version проверены; central queries работают |
| Grafana OSS | 13.2.4 | [Официальный deb/SHA](https://grafana.com/grafana/download/13.2.4?edition=oss&platform=linux), runtime package/API health и Loki datasource проверены |
| Docker Engine | docker.io29.1.3-0ubuntu3~24.04.2 | Реальный Noble apt candidate зафиксирован до установки, установленный package version прочитан |

Общие пакеты обеих VM, фактически прочитанные `dpkg-query`: nftables1.0.9-1ubuntu0.1; openssh-server1:9.6p1-3ubuntu13.20; qemu-guest-agent1:8.2.2+ds-0ubuntu1.18; sudo1.9.15p5-3ubuntu5.24.04.4; wireguard-tools1.0.20210914-1ubuntu4. Это гостевые версии, они отличаются от WSL controller packages.

## Проверяемые значения

- CRS image index digest: `sha256:7698c48a41a43138ae317feeec964d1515b861cc1d9e50617bc1cdfe9f314e1d`.
- Alloy linux-amd64.zip SHA256: `83e7ad1663a1271af2f507ad1af53cdb0a0fbb19a1b661895bcc426af68f2774`.
- Loki linux-amd64.zip SHA256: `17a5fae28ce733b3560c27c76620920b169bd2aea9473947b733b511f92e81dd`.
- Grafana deb SHA256: `f32ba4e166e35a376f39cbeb8dd47c57f7bf608b09339cb41adf6d39082af3c5`.

Release URLs и checksums проверены до установки, runtime versions прочитаны отдельно. Docker на выделенном web-узле использует bridge=none, iptables=false, ip6tables=false, ip-forward=false, ip-masq=false; это не глобальные настройки гипервизора. Ненужный Docker forwarding drift обнаружен и исправлен, затем steady-state secure/site повторены с changed0.

Базовые Ubuntu packages следуют security/updates выбранной Ubuntu, без выдуманных forever-пинов для moving repository. После обновления клонов сохранить фактический dpkg-query manifest. Для полного повторения package state потребуется snapshot APT repository; он в объём домашнего тестового не входит. Это явный компромисс воспроизводимости, а не использование latest для приложений.

Syntax/config validators были предварительным этапом. Теперь WAF blocking, VPN и центральные события подтверждены runtime отдельно; повторные secure/site дали changed=0 на обоих узлах как до, так и после последовательных reboot и развёртывания итогового rotation helper. Loki retention 168h настроен, но истечение семи суток и фактическое удаление по этому сроку пока не наблюдались.
