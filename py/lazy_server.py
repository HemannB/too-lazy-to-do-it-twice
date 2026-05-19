#!/usr/bin/env python3
"""
lazy_serve.py
Sobe um servidor HTTP na pasta atual (ou em qualquer pasta).
Mostra todos os IPs da rede pra acessar de outros dispositivos.

Uso:
  python lazy_serve.py              # porta 8000, pasta atual
  python lazy_serve.py 3000         # porta customizada
  python lazy_serve.py 3000 ./dist  # porta + pasta
  python lazy_serve.py --no-browser # não abre o browser automaticamente
"""

import argparse
import http.server
import ipaddress
import os
import socket
import socketserver
import sys
import threading
import webbrowser
from pathlib import Path


# ── Cores (desativadas se não for terminal) ───────────────────────────────────
if sys.stdout.isatty():
    R     = "\033[0m"
    BOLD  = "\033[1m"
    GREEN = "\033[0;32m"
    CYAN  = "\033[0;36m"
    DIM   = "\033[2m"
    YELLOW= "\033[0;33m"
else:
    R = BOLD = GREEN = CYAN = DIM = YELLOW = ""


# ── Argumentos ────────────────────────────────────────────────────────────────
parser = argparse.ArgumentParser(
    description="Servidor HTTP simples.",
    formatter_class=argparse.RawDescriptionHelpFormatter,
    epilog=__doc__,
)
parser.add_argument("port",      nargs="?", type=int, default=8000, help="Porta (padrão: 8000)")
parser.add_argument("directory", nargs="?", default=".",            help="Diretório a servir (padrão: .)")
parser.add_argument("--no-browser", action="store_true",            help="Não abrir o browser automaticamente")
args = parser.parse_args()

PORT      = args.port
DIRECTORY = Path(args.directory).resolve()
OPEN_BROWSER = not args.no_browser

if not DIRECTORY.is_dir():
    print(f"Erro: '{DIRECTORY}' não é um diretório válido.")
    sys.exit(1)


# ── Pega IPs locais da máquina ────────────────────────────────────────────────
def get_local_ips():
    ips = []
    try:
        # Conecta num endereço externo só pra descobrir qual interface usa
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            ips.append(s.getsockname()[0])
    except Exception:
        pass

    # Fallback: todos os endereços do hostname
    try:
        for info in socket.getaddrinfo(socket.gethostname(), None):
            addr = info[4][0]
            try:
                ip = ipaddress.ip_address(addr)
                if ip.version == 4 and not ip.is_loopback:
                    if addr not in ips:
                        ips.append(addr)
            except ValueError:
                pass
    except Exception:
        pass

    return ips or ["<ip não encontrado>"]


# ── Handler com diretório configurável ───────────────────────────────────────
class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(DIRECTORY), **kwargs)

    def log_message(self, fmt, *fmtargs):
        # Formata o log de acesso com cores
        code = fmtargs[1] if len(fmtargs) > 1 else "-"
        color = GREEN if str(code).startswith("2") else YELLOW
        print(f"  {DIM}{self.address_string()}{R}  {color}{code}{R}  {fmtargs[0]}")


# ── Servidor com SO_REUSEADDR ─────────────────────────────────────────────────
class Server(socketserver.TCPServer):
    allow_reuse_address = True


# ── Banner ────────────────────────────────────────────────────────────────────
local_ips = get_local_ips()

print()
print(f"{BOLD}{CYAN}╔══════════════════════════════════════════════╗{R}")
print(f"{BOLD}{CYAN}║{R}          {BOLD}serve.py — http server{R}               {BOLD}{CYAN}║{R}")
print(f"{BOLD}{CYAN}╚══════════════════════════════════════════════╝{R}")
print(f"  {DIM}Servindo : {DIRECTORY}{R}")
print()
print(f"  {BOLD}Local    :{R}  {GREEN}http://localhost:{PORT}{R}")
for ip in local_ips:
    print(f"  {BOLD}Rede     :{R}  {GREEN}http://{ip}:{PORT}{R}")
print()
print(f"  {DIM}Ctrl+C para parar{R}")
print()

# ── Abre browser ──────────────────────────────────────────────────────────────
if OPEN_BROWSER:
    threading.Timer(0.5, lambda: webbrowser.open(f"http://localhost:{PORT}")).start()

# ── Sobe o servidor ───────────────────────────────────────────────────────────
try:
    with Server(("", PORT), Handler) as httpd:
        httpd.serve_forever()
except OSError as e:
    print(f"{YELLOW}Erro: porta {PORT} já está em uso.{R}")
    print(f"  Tente outra: {DIM}python lazy_serve.py {PORT + 1}{R}")
    sys.exit(1)
except KeyboardInterrupt:
    print(f"\n  {GREEN}✔  Servidor encerrado.{R}\n")