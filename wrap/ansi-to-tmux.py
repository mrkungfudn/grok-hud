#!/usr/bin/env python3
"""Convert grok-hud ANSI to tmux status format (#[fg=...]). English-only.

tmux status-format does not honor raw CSI; it only paints its own #[] styles.
That's why the HUD looked monochrome inside launch.sh even though --once is
colored in a real TTY. Keep truecolor (#rrggbb) for tmux 3.2+.
"""
from __future__ import annotations

import re
import sys

CSI = re.compile(r"\x1b\[([0-9;]*)m")

FG = {
    "30": "black",
    "31": "red",
    "32": "green",
    "33": "yellow",
    "34": "blue",
    "35": "magenta",
    "36": "cyan",
    "37": "white",
    "90": "brightblack",
    "91": "brightred",
    "92": "brightgreen",
    "93": "brightyellow",
    "94": "brightblue",
    "95": "brightmagenta",
    "96": "brightcyan",
    "97": "brightwhite",
}


def _attrs(inner: str) -> str:
    if inner == "" or inner == "0":
        return "default"
    parts = inner.split(";") if inner else ["0"]
    out: list[str] = []
    i = 0
    while i < len(parts):
        p = parts[i]
        if p in ("", "0"):
            out.append("default")
        elif p == "1":
            out.append("bold")
        elif p == "2":
            out.append("dim")
        elif p == "22":
            out.append("nobold")
            out.append("nodim")
        elif p == "39":
            out.append("fg=default")
        elif p in FG:
            out.append(f"fg={FG[p]}")
        elif p == "38" and i + 1 < len(parts):
            if parts[i + 1] == "2" and i + 4 < len(parts):
                try:
                    r, g, b = (int(parts[i + 2]), int(parts[i + 3]), int(parts[i + 4]))
                    out.append(f"fg=#{r:02x}{g:02x}{b:02x}")
                except ValueError:
                    pass
                i += 4
            elif parts[i + 1] == "5" and i + 2 < len(parts):
                out.append(f"fg=colour{parts[i + 2]}")
                i += 2
        i += 1
    return ",".join(out) if out else "default"


def convert(text: str) -> str:
    return CSI.sub(lambda m: "#[" + _attrs(m.group(1)) + "]", text)


def main() -> None:
    sys.stdout.write(convert(sys.stdin.read()))


if __name__ == "__main__":
    main()
