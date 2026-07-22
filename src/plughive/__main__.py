"""Entrypoint for `python -m plughive` and the `plughive` console script."""
from __future__ import annotations

import sys

from loguru import logger

from plughive import __version__

_USAGE = """\
plughive — a plug-and-play personal AI (Claude CLI × Discord)

usage:
  plughive            start the bot (Discord + scheduled brief)
  plughive --help     show this help
  plughive --version  print version

config:  config/plughive.yaml   secrets: .env   persona: personas/rochana.md
setup:   ./setup.sh   (or setup.ps1 on Windows)
"""


def main() -> None:
    args = sys.argv[1:]
    if args:
        if args[0] in ("-h", "--help"):
            print(_USAGE)
            return
        if args[0] in ("-V", "--version"):
            print(f"plughive {__version__}")
            return
        print(f"plughive: unknown argument {args[0]!r}\n", file=sys.stderr)
        print(_USAGE, file=sys.stderr)
        raise SystemExit(2)

    logger.remove()
    logger.add(sys.stderr, level="INFO",
               format="<green>{time:HH:mm:ss}</green> <level>{level: <7}</level> {message}")
    from plughive.app import run_blocking
    run_blocking()


if __name__ == "__main__":
    main()
