#!/usr/bin/env python3
import http.server
import socketserver
import os
import sys
import mimetypes
import socket

mimetypes.add_type('application/wasm', '.wasm')
mimetypes.add_type('application/javascript', '.js')
mimetypes.add_type('application/javascript', '.mjs')
mimetypes.add_type('application/json', '.json')
mimetypes.add_type('image/svg+xml', '.svg')
mimetypes.add_type('font/ttf', '.ttf')
mimetypes.add_type('font/otf', '.otf')

PORT = int(os.environ.get("PORT", 3000))
WEB_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "build", "web"))

class SpaHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def translate_path(self, path):
        clean_path = path.split('?')[0].split('#')[0]
        # First check standard path
        standard_path = super().translate_path(clean_path)
        if os.path.exists(standard_path) and not os.path.isdir(standard_path):
            return standard_path
        if os.path.isdir(standard_path) and os.path.exists(os.path.join(standard_path, "index.html")):
            return os.path.join(standard_path, "index.html")
        # SPA fallback: return index.html for unknown routes (/hours, /reports, etc.)
        return os.path.join(WEB_DIR, "index.html")

    def end_headers(self):
        # Disable caching for JS, HTML, JSON, and WASM to allow instant hot-reload/refresh
        if self.path.endswith('.html') or self.path == '/' or self.path.endswith('.js') or self.path.endswith('.json') or self.path.endswith('.wasm'):
            self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0')
            self.send_header('Pragma', 'no-cache')
            self.send_header('Expires', '0')
        else:
            self.send_header('Cache-Control', 'public, max-age=60')

        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS')
        super().end_headers()

    def log_message(self, format, *args):
        sys.stderr.write(f"[{self.log_date_time_string()}] {args[0]} -> {args[1]}\n")

def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

if __name__ == "__main__":
    if not os.path.exists(WEB_DIR):
        print(f"Error: Web build directory '{WEB_DIR}' does not exist.", file=sys.stderr)
        sys.exit(1)

    # Flutter loads its JavaScript, CanvasKit, fonts, and assets concurrently.
    # A single-threaded TCPServer can be held open by one browser connection and
    # starve every other request, leaving the app stuck on a blank/loading page.
    socketserver.ThreadingTCPServer.allow_reuse_address = True
    socketserver.ThreadingTCPServer.daemon_threads = True
    with socketserver.ThreadingTCPServer(("0.0.0.0", PORT), SpaHandler) as httpd:
        local_ip = get_local_ip()
        print(f"Server started on http://{local_ip}:{PORT}")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down server.")
