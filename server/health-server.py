#!/usr/bin/env python3
"""
VPN Health Check Server
Simple HTTP server that checks WireGuard and Squid services
"""

import http.server
import subprocess
import socketserver

class HealthHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            # Check WireGuard service
            wg_ok = subprocess.call(
                ['systemctl', 'is-active', '--quiet', 'wg-quick@wg0']
            ) == 0

            # Check Squid service
            squid_ok = subprocess.call(
                ['systemctl', 'is-active', '--quiet', 'squid']
            ) == 0

            if wg_ok and squid_ok:
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'OK')
            else:
                self.send_response(503)
                self.end_headers()
                error_msg = []
                if not wg_ok:
                    error_msg.append('WireGuard down')
                if not squid_ok:
                    error_msg.append('Squid down')
                self.wfile.write(', '.join(error_msg).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        # Suppress default logging to reduce noise
        pass

if __name__ == '__main__':
    PORT = 8080
    with socketserver.TCPServer(("", PORT), HealthHandler) as httpd:
        print(f"Health check server running on port {PORT}")
        httpd.serve_forever()
