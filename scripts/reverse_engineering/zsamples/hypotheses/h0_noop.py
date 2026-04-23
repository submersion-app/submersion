"""Baseline hypothesis that returns no samples. Used to validate the harness."""
from __future__ import annotations


def decode(blob: bytes) -> list[dict]:
    return []
