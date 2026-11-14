#!/usr/bin/env python3
"""Servidor HTTP mínimo que imita POST /api/chat do Ollama, para testes.

Uso: mock_ollama.py PORTA
O comportamento depende do nome do modelo enviado na requisição.
"""
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _responder(self, conteudo):
        corpo = json.dumps(
            {"message": {"role": "assistant", "content": conteudo}}
        ).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(corpo)

    def do_POST(self):
        tamanho = int(self.headers["Content-Length"])
        req = json.loads(self.rfile.read(tamanho))
        modelo = req["model"]

        if modelo == "qwen3-think":
            # Só responde se o raciocínio for desativado (think: false).
            self._responder("Listar Arquivos no Bash" if req.get("think") is False else "")
        elif modelo == "gemma-nothink":
            # Modelo que rejeita o parâmetro "think".
            if "think" in req:
                self.send_response(400)
                self.end_headers()
                self.wfile.write(b'{"error":"does not support thinking"}')
            else:
                self._responder('"Título: Receita de Bolo."\n\nExplicação extra')
        elif modelo == "think-tags":
            self._responder("<think>raciocinando\nem linhas\n</think>\n\nDúvidas sobre Bash")
        elif modelo == "longo":
            self._responder("A" * 200)
        else:  # "vazio" e qualquer outro
            self._responder("")


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
