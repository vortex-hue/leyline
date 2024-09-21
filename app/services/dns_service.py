import socket

def resolve_ipv4(domain: str) -> str:
    try:
        ipv4_addresses = [ip for ip in socket.gethostbyname_ex(domain)[2] if '.' in ip]
        return ipv4_addresses
    except socket.gaierror:
        return []
