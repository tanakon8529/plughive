"""Entrypoint for `python -m rochana` and the `rochana` console script."""
from __future__ import annotations

import sys

from loguru import logger

from rochana.app import run_blocking


def main() -> None:
    logger.remove()
    logger.add(sys.stderr, level="INFO",
               format="<green>{time:HH:mm:ss}</green> <level>{level: <7}</level> {message}")
    run_blocking()


if __name__ == "__main__":
    main()
