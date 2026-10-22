"""Serve the test build and one exact gitignored manifest on loopback only.
No token appears in a command, URL query, access log or committed fixture.
"""
import argparse
import http.server
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--build', type=Path, required=True)
parser.add_argument('--manifest', type=Path, required=True)
args = parser.parse_args()
manifest_path = args.manifest.resolve(strict=True)
if '.superpowers' not in manifest_path.parts:
    raise SystemExit('Manifest must remain in gitignored .superpowers')

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *values, **kwargs):
        super().__init__(*values, directory=str(args.build.resolve()), **kwargs)

    def do_GET(self):
        if self.path == '/__scenario/manifest':
            data = manifest_path.read_bytes()
            if json.loads(data).get('testOnly') is not True:
                self.send_error(403)
                return
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Cache-Control', 'no-store')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        super().do_GET()

    def log_message(self, format, *values):
        pass

print('TEST preview on http://127.0.0.1:8766; credential responses are not logged.')
http.server.ThreadingHTTPServer(('127.0.0.1', 8766), Handler).serve_forever()
