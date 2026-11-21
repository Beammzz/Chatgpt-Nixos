#!/usr/bin/env python3
"""Exercise bundled app-server command execution without a model or login."""
import argparse
import asyncio
import json
from pathlib import Path


async def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--shell", required=True, type=Path)
    parser.add_argument("--workspace", required=True, type=Path)
    parser.add_argument("--sudo", action="store_true", help="Test existing passwordless sudo with id")
    args = parser.parse_args()
    workspace = args.workspace.resolve()
    workspace.mkdir(parents=True, exist_ok=True)
    with (workspace / "app-server-stderr.log").open("w") as stderr:
        server = await asyncio.create_subprocess_exec(
            str(args.shell.resolve()), "-c", 'exec "$CHATGPT_RESOURCES/codex" app-server',
            stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE, stderr=stderr,
        )

        async def send(message):
            server.stdin.write((json.dumps(message) + "\n").encode())
            await server.stdin.drain()

        async def request(identifier, method, params):
            await send({"id": identifier, "method": method, "params": params})
            while True:
                line = await asyncio.wait_for(server.stdout.readline(), timeout=20)
                if not line:
                    raise RuntimeError("app-server closed stdout")
                message = json.loads(line)
                if message.get("id") == identifier:
                    if "error" in message:
                        raise RuntimeError(message["error"])
                    return message["result"]

        try:
            await request(1, "initialize", {
                "clientInfo": {"name": "native-packaging-check", "version": "1"},
                "capabilities": {"experimentalApi": True},
            })
            await send({"method": "initialized", "params": {}})
            command = 'printf "command PID=%s PPID=%s\\n" "$$" "$PPID"; awk "/^NoNewPrivs:|^Seccomp:/" /proc/$$/status'
            if args.sudo:
                command += "; sudo -n id"
            full = await request(2, "command/exec", {
                "command": ["/bin/sh", "-c", command], "cwd": str(workspace),
                "sandboxPolicy": {"type": "dangerFullAccess"}, "timeoutMs": 10000,
            })
            print("Full access command:", json.dumps(full, indent=2))
            assert full["exitCode"] == 0, full
            assert "NoNewPrivs:\t0" in full["stdout"], full
            if args.sudo:
                assert "uid=0(root)" in full["stdout"], full
            sandbox = await request(3, "command/exec", {
                "command": ["/bin/sh", "-c", 'awk "/^NoNewPrivs:|^Seccomp:/" /proc/$$/status'],
                "cwd": str(workspace), "timeoutMs": 10000,
                "sandboxPolicy": {"type": "workspaceWrite", "writableRoots": [str(workspace)]},
            })
            print("Workspace sandbox command:", json.dumps(sandbox, indent=2))
            assert sandbox["exitCode"] == 0, sandbox
            assert "NoNewPrivs:\t1" in sandbox["stdout"], sandbox
            assert "Seccomp:\t2" in sandbox["stdout"], sandbox
        finally:
            if server.returncode is None:
                server.terminate()
                try:
                    await asyncio.wait_for(server.wait(), timeout=5)
                except TimeoutError:
                    server.kill()
                    await server.wait()


if __name__ == "__main__":
    asyncio.run(main())
