#!/usr/bin/python3
"""Validate a rendered config and matching local key without touching the network."""
# Этот скрипт читает временный конфиг перед установкой и не создаёт сетевой интерфейс.
import base64
import ipaddress
from pathlib import Path
import subprocess
import sys


def key(value):
    # WireGuard-ключ должен декодироваться из base64 ровно в 32 байта.
    if len(base64.b64decode(value, validate=True)) != 32:
        raise ValueError('Invalid key length')


def main():
    # Разбираем только ожидаемые секции и директивы, отвергая дубликаты.
    sections = []
    local_public = None
    for raw in Path(sys.argv[1]).read_text().splitlines():
        line = raw.strip()
        if line.startswith('# LocalPublicKey = '):
            local_public = line.split('=', 1)[1].strip()
        if not line or line.startswith('#'):
            continue
        if line in ['[Interface]', '[Peer]']:
            sections.append((line, {}))
            continue
        name, value = [item.strip() for item in line.split('=', 1)]
        if not sections or name in sections[-1][1]:
            raise ValueError('Invalid or duplicate directive')
        sections[-1][1][name] = value
    if not sections or sections[0][0] != '[Interface]' or len(sections) < 2:
        raise ValueError('Missing interface or peers')
    interface = sections[0][1]
    if set(interface) != {'Address', 'ListenPort', 'PrivateKey', 'MTU'}:
        raise ValueError('Unexpected interface directive')
    address = ipaddress.ip_interface(interface['Address'])
    if address.version != 4 or address.network.prefixlen != 29:
        raise ValueError('Expected the approved small IPv4 VPN prefix')
    if address.ip in [address.network.network_address, address.network.broadcast_address]:
        raise ValueError('Interface must use a host address')
    if not 1024 <= int(interface['ListenPort']) <= 65535 or not 1280 <= int(interface['MTU']) <= 1420:
        raise ValueError('Invalid listen port or MTU')
    key(interface['PrivateKey'])
    key(local_public)
    derived = subprocess.run(['wg', 'pubkey'], input=interface['PrivateKey'] + '\n', text=True, capture_output=True, check=True)
    # Сравнение выполняется локально; private key не включается в текст ошибки.
    if derived.stdout.strip() != local_public:
        raise ValueError('Local private/public key mismatch')
    seen_keys = {local_public}
    seen_addresses = {address.ip}
    for section, peer in sections[1:]:
        if section != '[Peer]' or not {'PublicKey', 'AllowedIPs'} <= set(peer):
            raise ValueError('Invalid peer')
        if set(peer) - {'PublicKey', 'AllowedIPs', 'Endpoint', 'PersistentKeepalive'}:
            raise ValueError('Unexpected peer directive')
        key(peer['PublicKey'])
        if peer['PublicKey'] in seen_keys:
            raise ValueError('Duplicate peer key')
        seen_keys.add(peer['PublicKey'])
        for value in peer['AllowedIPs'].split(','):
            # Разрешаем только отдельные /32 внутри VPN, без LAN/default маршрутов.
            network = ipaddress.ip_network(value.strip(), strict=True)
            if network.version != 4 or network.prefixlen != 32 or network.network_address not in address.network:
                raise ValueError('Only individual VPN addresses may be routed')
            if network.network_address in [address.network.network_address, address.network.broadcast_address]:
                raise ValueError('Peer must use a host address')
            if network.network_address in seen_addresses:
                raise ValueError('Overlapping peer address')
            seen_addresses.add(network.network_address)
        if 'Endpoint' in peer:
            host, port = peer['Endpoint'].rsplit(':', 1)
            if ipaddress.ip_address(host).version != 4 or not 1024 <= int(port) <= 65535:
                raise ValueError('Invalid endpoint')
        if 'PersistentKeepalive' in peer and not 0 <= int(peer['PersistentKeepalive']) <= 65535:
            raise ValueError('Invalid keepalive')


if __name__ == '__main__':
    try:
        main()
    except Exception:
        print('WireGuard configuration or supplied matching keys are invalid', file=sys.stderr)
        sys.exit(1)
