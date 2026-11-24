"""Lingoy API readiness service: stdlib-only WSGI, AI/OCR intentionally disabled.

Local development: python server.py (127.0.0.1:8080).
Production: serve application with the hosting provider's WSGI runner behind TLS.
"""
from __future__ import annotations
import argparse
import json
from http import HTTPStatus
from wsgiref.simple_server import make_server

CAPABILITIES = {"translation": False, "grammar": False, "image_translation": False}
MAX_REQUEST_BYTES = 10 * 1024 * 1024

def application(environ, start_response):
    path = environ.get("PATH_INFO", "")
    method = environ.get("REQUEST_METHOD", "GET")
    status, data = 404, {"error": {"code": "not_found", "message": "Endpoint topilmadi."}}
    if path == "/v1/health":
        if method == "GET":
            status, data = 200, {"api_version": "1", "service": "lingoy", "status": "ready",
                                 "capabilities": dict(CAPABILITIES)}
        else:
            status, data = 405, {"error": {"code": "method_not_allowed", "message": "GET kerak."}}
    elif path in {"/v1/translate", "/v1/grammar", "/v1/image-translate"}:
        if method != "POST":
            status, data = 405, {"error": {"code": "method_not_allowed", "message": "POST kerak."}}
        else:
            try:
                size = int(environ.get("CONTENT_LENGTH") or "0")
            except ValueError:
                size = -1
            if size < 0:
                status, data = 400, {"error": {"code": "invalid_length", "message": "So‘rov hajmi noto‘g‘ri."}}
            elif size > MAX_REQUEST_BYTES:
                status, data = 413, {"error": {"code": "request_size", "message": "So‘rov juda katta."}}
            else:
                # Do not read, store, log or forward personal text/images while disabled.
                status, data = 503, {"error": {"code": "feature_disabled",
                    "message": "Xizmat hali ulanmagan. Oflayn imkoniyatlardan foydalaning."}}
    body = json.dumps(data, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    headers = [("Content-Type", "application/json; charset=utf-8"),
               ("Content-Length", str(len(body))), ("Cache-Control", "no-store"),
               ("X-Content-Type-Options", "nosniff"),
               ("Content-Security-Policy", "default-src 'none'")]
    if status == 405:
        headers.append(("Allow", "GET" if path.endswith("health") else "POST"))
    start_response(f"{status} {HTTPStatus(status).phrase}", headers)
    return [body]

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8080)
    args = parser.parse_args()
    with make_server(args.host, args.port, application) as server:
        print(f"Lingoy readiness API: http://{args.host}:{args.port}; AI/OCR disabled", flush=True)
        server.serve_forever()
