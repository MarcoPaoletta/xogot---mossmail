#!/usr/bin/env python3
"""Minimal MCP (Streamable HTTP) client for the Unreal editor's native MCP server. Standard library only.

The editor must be running with the MCP server up (Editor Preferences > General > Model Context Protocol > Auto Start,
or launch with -ModelContextProtocolStartServer -ModelContextProtocolPort=8000). Endpoint: UE_MCP_URL, then the
project's .mcp.json, then http://127.0.0.1:8000/mcp.

  python tools/mcp_client.py list-toolsets
  python tools/mcp_client.py describe NAME [--brief]
  python tools/mcp_client.py call TOOLSET TOOL [JSON | @file.json] [--max N]

A client that lists tools and sees only 3 is CONNECTED, not broken: the real surface is list_toolsets / describe_toolset /
call_tool. The describe parameter is `toolset_name`. A bare GET to the endpoint answers 405, which is correct.
Never run this client through ue_py.py: that executes inside the editor's game thread, which would then wait on
itself (see unreal-engine.md, "Two Python worlds").
"""
import argparse
import json
import os
import sys
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ue_common as C  # noqa: E402

PROTOCOL = "2025-11-25"


def maybe_json(value):
    if isinstance(value, str):
        s = value.strip()
        if s[:1] in "{[":
            try:
                return json.loads(s)
            except Exception:
                return value
    return value


class Mcp:
    def __init__(self, url=None, timeout=900.0):
        self.url = url or C.mcp_endpoint()
        self.timeout = timeout
        self.session = None
        self._id = 0

    def _headers(self):
        h = {"Content-Type": "application/json", "Accept": "application/json, text/event-stream", "MCP-Protocol-Version": PROTOCOL}
        if self.session:
            h["Mcp-Session-Id"] = self.session
        return h

    def _post(self, payload, want_id):
        req = urllib.request.Request(self.url, data=json.dumps(payload).encode("utf-8"), headers=self._headers(), method="POST")
        with urllib.request.urlopen(req, timeout=self.timeout) as resp:
            sid = resp.headers.get("Mcp-Session-Id") or resp.headers.get("mcp-session-id")
            if sid:
                self.session = sid
            body = resp.read().decode("utf-8", "replace")
            ctype = (resp.headers.get("Content-Type") or "").lower()
        if want_id is None or not body.strip():
            return None
        if "text/event-stream" in ctype:
            for block in body.split("\n\n"):
                data = "".join(line[5:].strip() for line in block.splitlines() if line.startswith("data:"))
                if not data:
                    continue
                try:
                    msg = json.loads(data)
                except Exception:
                    continue
                if msg.get("id") == want_id:
                    return msg
            raise RuntimeError("no matching SSE response")
        return json.loads(body)

    def initialize(self):
        self._id += 1
        r = self._post({"jsonrpc": "2.0", "id": self._id, "method": "initialize",
                        "params": {"protocolVersion": PROTOCOL, "capabilities": {}, "clientInfo": {"name": "game-dev-helper", "version": "1.0"}}}, self._id)
        if "error" in r:
            raise RuntimeError(f"initialize failed: {r['error']}")
        self._post({"jsonrpc": "2.0", "method": "notifications/initialized"}, None)
        return r

    def rpc(self, method, params):
        if self.session is None and method != "initialize":
            self.initialize()
        self._id += 1
        r = self._post({"jsonrpc": "2.0", "id": self._id, "method": method, "params": params}, self._id)
        if "error" in r:
            raise RuntimeError(f"{method} error: {json.dumps(r['error'])[:800]}")
        return r["result"]

    def tool(self, name, arguments):
        res = self.rpc("tools/call", {"name": name, "arguments": arguments})
        if res.get("isError"):
            text = " ".join(c.get("text", "") for c in res.get("content", []) if c.get("type") == "text")
            raise RuntimeError(f"tool error: {text[:1500]}")
        if res.get("structuredContent") is not None:
            return res["structuredContent"]
        return maybe_json("".join(c.get("text", "") for c in res.get("content", []) if c.get("type") == "text"))

    def call(self, toolset, tool, args=None):
        out = self.tool("call_tool", {"toolset_name": toolset, "tool_name": tool, "arguments": args or {}})
        if isinstance(out, dict) and "returnValue" in out and len(out) == 1:
            out = out["returnValue"]
        return maybe_json(out)

    def describe(self, toolset):
        return maybe_json(self.tool("describe_toolset", {"toolset_name": toolset}))

    def list_toolsets(self):
        return self.tool("list_toolsets", {})


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list-toolsets")
    d = sub.add_parser("describe")
    d.add_argument("name")
    d.add_argument("--brief", action="store_true")
    c = sub.add_parser("call")
    c.add_argument("toolset")
    c.add_argument("tool")
    c.add_argument("args", nargs="?", default="{}")
    c.add_argument("--max", type=int, default=6000)
    a = ap.parse_args()
    m = Mcp()
    if a.cmd == "list-toolsets":
        out = m.list_toolsets()
    elif a.cmd == "describe":
        out = m.describe(a.name)
        if a.brief and isinstance(out, dict):
            out = {k: (v if not isinstance(v, (dict, list)) else f"<{len(v)} items>") for k, v in out.items()}
    else:
        raw = a.args
        if raw.startswith("@"):
            with open(raw[1:], "r", encoding="utf-8-sig") as f:
                raw = f.read()
        out = m.call(a.toolset, a.tool, json.loads(raw))
    text = json.dumps(out, indent=1, ensure_ascii=False) if not isinstance(out, str) else out
    print(text[: getattr(a, "max", 6000)] if a.cmd == "call" else text)


if __name__ == "__main__":
    main()
