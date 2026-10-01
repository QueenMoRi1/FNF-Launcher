#!/usr/bin/env python3
"""Discord Rich Presence bridge for FNF Launcher (standard library only).

Usage: discord_rpc.py <application_id>

Reads JSON lines on stdin:
    {"activity": {...}}   set the presence (Discord SET_ACTIVITY format)
    {"clear": true}       clear it
Connects to the local Discord client over its IPC socket, reconnecting if
Discord restarts. Exits (clearing the presence) when stdin closes.
"""
import json
import os
import selectors
import socket
import struct
import sys
import time
import uuid

OP_HANDSHAKE, OP_FRAME, OP_CLOSE = 0, 1, 2
RETRY_SECONDS = 5

CLIENT_ID = sys.argv[1]
# Discord ties the activity to a process; use the launcher (our parent).
OWNER_PID = os.getppid()


def socket_paths():
    bases = [os.environ.get(k) for k in ("XDG_RUNTIME_DIR", "TMPDIR", "TMP", "TEMP")] + ["/tmp"]
    subdirs = ["", "app/com.discordapp.Discord", "app/dev.vencord.Vesktop",
               "app/com.discordapp.DiscordCanary", "snap.discord"]
    for base in filter(None, bases):
        for sub in subdirs:
            for i in range(10):
                yield os.path.join(base, sub, f"discord-ipc-{i}")


def send(sock, op, payload):
    data = json.dumps(payload).encode()
    sock.sendall(struct.pack("<II", op, len(data)) + data)


def recv(sock):
    header = sock.recv(8)
    if len(header) < 8:
        raise OSError("disconnected")
    op, length = struct.unpack("<II", header)
    body = b""
    while len(body) < length:
        chunk = sock.recv(length - len(body))
        if not chunk:
            raise OSError("disconnected")
        body += chunk
    return op, json.loads(body or b"{}")


def connect():
    for path in socket_paths():
        if not os.path.exists(path):
            continue
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            sock.settimeout(3)
            sock.connect(path)
            send(sock, OP_HANDSHAKE, {"v": 1, "client_id": CLIENT_ID})
            op, reply = recv(sock)
            if op == OP_CLOSE:
                log(f"Discord rejected the handshake: {reply.get('message')}")
                sock.close()
                return None
            sock.settimeout(None)
            log(f"connected to {path}")
            return sock
        except OSError:
            sock.close()
    return None


def set_activity(sock, activity):
    send(sock, OP_FRAME, {
        "cmd": "SET_ACTIVITY",
        "args": {"pid": OWNER_PID, "activity": activity},
        "nonce": str(uuid.uuid4()),
    })


def log(msg):
    try:
        print(f"[discord_rpc] {msg}", file=sys.stderr, flush=True)
    except OSError:  # nobody is reading our stderr; logging is optional
        pass


def main():
    sel = selectors.DefaultSelector()
    stdin_fd = sys.stdin.fileno()
    sel.register(stdin_fd, selectors.EVENT_READ, "stdin")
    sock = None
    activity = None
    dirty = False
    next_try = 0.0
    buf = b""

    def drop():
        nonlocal sock
        if sock:
            sel.unregister(sock)
            sock.close()
            sock = None

    while True:
        if sock is None and time.monotonic() >= next_try:
            sock = connect()
            next_try = time.monotonic() + RETRY_SECONDS
            if sock:
                sel.register(sock, selectors.EVENT_READ, "discord")
                dirty = True
        if sock and dirty:
            try:
                set_activity(sock, activity)
                dirty = False
            except OSError:
                drop()

        for key, _ in sel.select(timeout=None if sock else 1):
            if key.data == "stdin":
                chunk = os.read(stdin_fd, 65536)
                if not chunk:  # launcher closed
                    if sock:
                        try:
                            set_activity(sock, None)
                        except OSError:
                            pass
                    return
                buf += chunk
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    try:
                        msg = json.loads(line)
                    except ValueError:
                        continue
                    activity = None if msg.get("clear") else msg.get("activity")
                    dirty = True
            elif sock:
                try:
                    op, _ = recv(sock)  # responses are not needed
                    if op == OP_CLOSE:
                        drop()
                except OSError:
                    drop()


if __name__ == "__main__":
    main()
