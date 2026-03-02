#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from typing import Any


def _split_config(config_str: str) -> dict[str, str]:
    out: dict[str, str] = {}
    if not config_str.strip():
        return out
    for chunk in config_str.split(";"):
        part = chunk.strip()
        if not part:
            continue
        if "=" not in part:
            raise ValueError(f"Invalid config item: '{part}'. Expected key=value")
        key, value = part.split("=", 1)
        out[key.strip()] = value.strip()
    return out


def _execute_job(
    ecu: str,
    job: str,
    parameters: str,
    result_filter: str,
    config: str,
    timeout_seconds: int,
) -> dict[str, Any]:
    started_at = time.time()

    try:
        from pydiabas import PyDIABAS  # type: ignore
        from pydiabas import ediabas as ediabas_mod  # type: ignore
    except Exception as exc:
        return {
            "ok": False,
            "error": f"pydiabas import failed: {exc}",
            "started_at": started_at,
            "ended_at": time.time(),
        }

    config_map = _split_config(config)

    try:
        with PyDIABAS() as client:
            if config_map:
                client.config(**config_map)

            client.ediabas.job(ecu=ecu, job_name=job, job_param=parameters, results=result_filter)

            deadline = time.time() + timeout_seconds
            state = client.ediabas.state()
            while state == ediabas_mod.API_STATE.BUSY and time.time() < deadline:
                time.sleep(0.05)
                state = client.ediabas.state()

            if state == ediabas_mod.API_STATE.BUSY:
                return {
                    "ok": False,
                    "error": f"Timed out waiting for job completion after {timeout_seconds}s",
                    "state": int(state),
                    "started_at": started_at,
                    "ended_at": time.time(),
                }

            if state == ediabas_mod.API_STATE.ERROR:
                return {
                    "ok": False,
                    "error": client.ediabas.errorText(),
                    "state": int(state),
                    "error_code": int(client.ediabas.errorCode()),
                    "started_at": started_at,
                    "ended_at": time.time(),
                }

            return {
                "ok": True,
                "state": int(state),
                "error": "",
                "started_at": started_at,
                "ended_at": time.time(),
            }

    except Exception as exc:
        return {
            "ok": False,
            "error": str(exc),
            "started_at": started_at,
            "ended_at": time.time(),
        }


class _Handler(BaseHTTPRequestHandler):
    def _reply(self, code: int, payload: dict[str, Any]) -> None:
        data = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(data)

    def do_OPTIONS(self) -> None:  # noqa: N802
        self._reply(204, {"ok": True})

    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/health":
            self._reply(200, {"ok": True, "service": "ediabas_pydiabas_sidecar"})
            return
        self._reply(404, {"ok": False, "error": "Not found"})

    def do_POST(self) -> None:  # noqa: N802
        if self.path != "/job":
            self._reply(404, {"ok": False, "error": "Not found"})
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
            body = self.rfile.read(length).decode("utf-8") if length > 0 else "{}"
            payload = json.loads(body)

            result = _execute_job(
                ecu=str(payload.get("ecu", "")),
                job=str(payload.get("job", "")),
                parameters=str(payload.get("parameters", "")),
                result_filter=str(payload.get("result_filter", "")),
                config=str(payload.get("config", "")),
                timeout_seconds=int(payload.get("timeout_seconds", 60)),
            )
            self._reply(200 if result.get("ok") else 500, result)
        except Exception as exc:
            self._reply(500, {"ok": False, "error": str(exc)})


def _run_server(host: str, port: int) -> int:
    server = HTTPServer((host, port), _Handler)
    print(f"Sidecar listening on http://{host}:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


def _run_job(args: argparse.Namespace) -> int:
    result = _execute_job(
        ecu=args.ecu,
        job=args.job,
        parameters=args.parameters,
        result_filter=args.result_filter,
        config=args.config,
        timeout_seconds=args.timeout_seconds,
    )
    print(json.dumps(result, ensure_ascii=False))
    return 0 if result.get("ok") else 2


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="EDIABAS pydiabas sidecar (CLI/HTTP)")
    sub = parser.add_subparsers(dest="command", required=True)

    run_job = sub.add_parser("run-job", help="Run one EDIABAS job")
    run_job.add_argument("--ecu", required=True)
    run_job.add_argument("--job", required=True)
    run_job.add_argument("--parameters", default="")
    run_job.add_argument("--result-filter", default="")
    run_job.add_argument("--config", default="")
    run_job.add_argument("--timeout-seconds", type=int, default=60)

    serve = sub.add_parser("serve", help="Run local HTTP sidecar")
    serve.add_argument("--host", default="127.0.0.1")
    serve.add_argument("--port", type=int, default=8777)

    return parser


def main() -> int:
    parser = _build_parser()
    args = parser.parse_args()

    if args.command == "run-job":
        return _run_job(args)
    if args.command == "serve":
        return _run_server(args.host, args.port)

    parser.print_help()
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
