"""Servidor HTTP mínimo para o nó "Chamar Gerador do Mapa" do fluxo n8n 02.

    POST /gerar-mapa   (corpo JSON, mesmo contrato do gera_mapa.py)  ->  arquivo .xlsx
    GET  /health

Só biblioteca padrão + openpyxl. Escuta em 127.0.0.1 por padrão; dentro de um
container use HOST=0.0.0.0 e deixe a porta só na rede interna (não há autenticação).
"""
import io
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from gera_mapa import gera_mapa

LIMITE = 5 * 1024 * 1024
XLSX = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"


class Handler(BaseHTTPRequestHandler):
    def _responde(self, status, tipo, corpo):
        self.send_response(status)
        self.send_header("Content-Type", tipo)
        self.send_header("Content-Length", str(len(corpo)))
        self.end_headers()
        self.wfile.write(corpo)

    def do_GET(self):
        if self.path == "/health":
            return self._responde(200, "application/json", b'{"ok":true}')
        self._responde(404, "application/json", b'{"erro":"nao encontrado"}')

    def do_POST(self):
        if self.path != "/gerar-mapa":
            return self._responde(404, "application/json", b'{"erro":"nao encontrado"}')
        tamanho = int(self.headers.get("Content-Length") or 0)
        if tamanho <= 0 or tamanho > LIMITE:
            return self._responde(413, "application/json", b'{"erro":"corpo vazio ou grande demais"}')
        try:
            buf = io.BytesIO()
            gera_mapa(json.loads(self.rfile.read(tamanho)), buf)
        except (ValueError, KeyError, TypeError, AttributeError) as e:  # AttributeError: JSON que não é objeto (ex.: [])
            return self._responde(400, "application/json", json.dumps({"erro": str(e)}).encode())
        self._responde(200, XLSX, buf.getvalue())


def endereco(env):
    """HOST e PORT do ambiente. Vazio vale como ausente: um .env copiado do .env.example traz `HOST=` e `PORT=` em branco,
    e sem isso o servidor cairia em int('') ou escutaria em todas as interfaces (host '')."""
    return env.get("HOST") or "127.0.0.1", int(env.get("PORT") or 5000)


if __name__ == "__main__":
    host, porta = endereco(os.environ)
    print(f"mapa-service em http://{host}:{porta}")
    ThreadingHTTPServer((host, porta), Handler).serve_forever()
