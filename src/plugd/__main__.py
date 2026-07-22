"""Entrypoint for `python -m plugd` and the `plugd` console script."""
from __future__ import annotations

import sys

from loguru import logger

from plugd import __version__

_USAGE = """\
plugd — a plug-and-play personal AI (Claude CLI × Discord)

usage:
  plugd            start the bot (Discord + scheduled brief)
  plugd --help     show this help
  plugd --version  print version

config:  config/plugd.yaml   secrets: .env   persona: personas/rochana.md
setup:   ./setup.sh   (or setup.ps1 on Windows)
"""


def main() -> None:
    args = sys.argv[1:]
    if args:
        if args[0] in ("-h", "--help"):
            print(_USAGE)
            return
        if args[0] in ("-V", "--version"):
            print(f"plugd {__version__}")
            return
        print(f"plugd: unknown argument {args[0]!r}\n", file=sys.stderr)
        print(_USAGE, file=sys.stderr)
        raise SystemExit(2)

    logger.remove()
    logger.add(sys.stderr, level="INFO",
               format="<green>{time:HH:mm:ss}</green> <level>{level: <7}</level> {message}")
    from plugd.app import run_blocking
    run_blocking()


if __name__ == "__main__":
    main()
