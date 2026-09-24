#!/usr/bin/env python3
"""mister_kbd_client.py — forward THIS terminal's keystrokes to the MiSTer.

Runs on the LAPTOP (goatboxter-fw16). Puts the terminal in raw mode, reads
each keypress as it happens, translates it to the token grammar understood by
/media/fat/ssh_kbd.py on the MiSTer, and streams the tokens down an SSH pipe
(through goatbox-lab as the ProxyJump host).

No root, no evdev — just stdlib termios. Captures only while THIS terminal
window is focused, so your laptop stays usable. Press the QUIT key (default
Ctrl-] ) to exit cleanly.

Limitation: terminals deliver characters, not key-down/up events, so this
does TAPS only (no held keys). For held-key / gameplay input you need the
evdev tier instead.

Usage (on the laptop):
  python3 mister_kbd_client.py
  # or override the ssh hop:
  MISTER_SSH="ssh -J goatbox-lab root@192.168.100.10" python3 mister_kbd_client.py

Setup it assumes (one-time, on the laptop's ~/.ssh/config):
  Host goatbox-lab
      HostName 192.168.1.99
      User brandon
Then `ssh -J goatbox-lab root@192.168.100.10` works, which is what this drives.
"""
import os, sys, termios, tty, subprocess, shlex, signal

MISTER_SSH = os.environ.get(
    "MISTER_SSH",
    "ssh -J goatbox-lab root@192.168.100.10",
)
REMOTE_CMD = "python3 /media/fat/ssh_kbd.py"
QUIT = b"\x1d"  # Ctrl-] — exit the client

# single chars → injector token
CHARMAP = {
    "\r": "ENTER", "\n": "ENTER", "\x7f": "BACKSPACE", "\x08": "BACKSPACE",
    "\x1b": "ESC", "\t": "TAB", " ": "SPACE",
}
# multi-byte escape sequences (arrows, F-keys, nav) → token
ESCMAP = {
    "[A": "UP", "[B": "DOWN", "[C": "RIGHT", "[D": "LEFT",
    "[H": "HOME", "[F": "END", "[2~": "INSERT", "[3~": "DELETE",
    "[5~": "PAGEUP", "[6~": "PAGEDOWN",
    "OP": "F1", "OQ": "F2", "OR": "F3", "OS": "F4",
    "[15~": "F5", "[17~": "F6", "[18~": "F7", "[19~": "F8",
    "[20~": "F9", "[21~": "F10", "[23~": "F11", "[24~": "F12",
}
# letters/digits/punct the injector knows by literal name
NAMED = set("abcdefghijklmnopqrstuvwxyz0123456789")
PUNCT = {"-": "MINUS", "=": "EQUAL", ".": "DOT", ",": "COMMA", "/": "SLASH"}


def read_key(fd):
    """Read one logical keypress (handles multi-byte escape sequences)."""
    ch = os.read(fd, 1)
    if ch != b"\x1b":
        return ch
    # possible escape sequence — read the rest non-greedily
    seq = b""
    # set a tiny timeout so a lone ESC still works
    import select
    while True:
        r, _, _ = select.select([fd], [], [], 0.02)
        if not r:
            break
        seq += os.read(fd, 1)
        # stop at a terminator for CSI/SS3 sequences
        if seq[-1:] in (b"A", b"B", b"C", b"D", b"H", b"F", b"~", b"P", b"Q", b"R", b"S"):
            break
    return b"\x1b" + seq


def to_token(key: bytes):
    if key == b"\x1b":
        return "ESC"
    if key.startswith(b"\x1b"):
        return ESCMAP.get(key[1:].decode("latin1"), None)
    s = key.decode("latin1")
    if s in CHARMAP:
        return CHARMAP[s]
    low = s.lower()
    if low in NAMED:
        # uppercase letter → shift-tap; injector handles +/- holds, so chord it
        if s.isupper():
            return f"+LSHIFT {low} -LSHIFT"
        return low
    if s in PUNCT:
        return PUNCT[s]
    return None  # unmapped — ignore


def main():
    cmd = shlex.split(MISTER_SSH) + [REMOTE_CMD]
    sys.stderr.write(f"[mister-kbd] connecting: {' '.join(cmd)}\n")
    sys.stderr.write("[mister-kbd] keys now forward to the MiSTer. Ctrl-] to quit.\n")
    sys.stderr.flush()
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        while True:
            key = read_key(fd)
            if key == QUIT:
                break
            tok = to_token(key)
            if tok:
                proc.stdin.write((tok + "\n").encode())
                proc.stdin.flush()
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)
        try:
            proc.stdin.close()
        except Exception:
            pass
        proc.terminate()
        sys.stderr.write("\n[mister-kbd] disconnected.\n")


if __name__ == "__main__":
    main()
