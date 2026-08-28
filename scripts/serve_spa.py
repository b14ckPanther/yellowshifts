#!/usr/bin/env python3
import os
import sys
from http.server import HTTPServer, SimpleHTTPRequestHandler

DIRECTORY = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "build", "web"))

class SPAHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def send_head(self):
        path = self.translate_path(self.path)
        if not os.path.exists(path):
            self.path = "/index.html"
        return super().send_head()

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        super().end_headers()

def run(port=8080):
    server_address = ("0.0.0.0", port)
    httpd = HTTPServer(server_address, SPAHandler)
    print(f"[*] Serving YellowShifts SPA from {DIRECTORY}")
    print(f"[*] Listening on http://0.0.0.0:{port}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n[*] Server stopped.")

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    run(port)
