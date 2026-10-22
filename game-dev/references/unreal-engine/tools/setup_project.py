#!/usr/bin/env python3
"""Idempotent project setup so an agent can test headless: turns on Python Remote Execution (loopback only) and
lists what else must be on. Safe to run again. Run it with the editor CLOSED (the editor rewrites its ini files).

  python tools/setup_project.py            apply and report
  python tools/setup_project.py --check    report only
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ue_common as C  # noqa: E402

INI = os.path.join(C.ROOT, "Config", "DefaultEngine.ini")
SECTION = "[/Script/PythonScriptPlugin.PythonScriptPluginSettings]"
WANT = {"bRemoteExecution": "True", "RemoteExecutionMulticastBindAddress": "127.0.0.1", "RemoteExecutionMulticastTtl": "0"}


def main():
    check = "--check" in sys.argv
    os.makedirs(os.path.dirname(INI), exist_ok=True)
    text = ""
    if os.path.isfile(INI):
        with open(INI, "r", encoding="utf-8-sig", newline="") as f:
            text = f.read()
    nl = "\r\n" if "\r\n" in text else "\n"
    if SECTION not in text:
        missing = dict(WANT)
        new = text + ("" if not text or text.endswith(("\n", "\r")) else nl) + nl + SECTION + nl + nl.join(f"{k}={v}" for k, v in WANT.items()) + nl
    else:
        m = re.search(re.escape(SECTION) + r"(.*?)(?=\r?\n\[|\Z)", text, re.S)
        body = m.group(1)
        missing = {k: v for k, v in WANT.items() if not re.search(rf"^{k}={re.escape(v)}\s*$", body, re.M | re.I)}
        new = text
        for k, v in missing.items():
            if re.search(rf"^{k}=", body, re.M):
                new = re.sub(rf"^{k}=.*$", f"{k}={v}", new, count=1, flags=re.M)
            else:
                new = new.replace(SECTION, SECTION + nl + f"{k}={v}", 1)
    print("project:", C.PROJECT_NAME, "| ini:", os.path.relpath(INI, C.ROOT))
    if not missing:
        print("Python Remote Execution: already configured")
    elif check:
        print("Python Remote Execution: MISSING", missing)
    else:
        with open(INI, "w", encoding="utf-8", newline="") as f:
            f.write(new)
        print("Python Remote Execution: written", missing)
    print("Also required (the .uproject): plugins PythonScriptPlugin, ModelContextProtocol, AllToolsets enabled.")
    print("Launch the editor with -ModelContextProtocolStartServer -ModelContextProtocolPort=<port> (a plain launch never opens the port),")
    print("and add -NoSound for unattended work (a hung audio device can kill the editor).")


if __name__ == "__main__":
    main()
