from __future__ import annotations

import asyncio
import shutil
import struct
import tempfile
from pathlib import Path
from typing import TYPE_CHECKING

import pytest

from nixbot_effects.daemon_proxy import nix_daemon_proxy

if TYPE_CHECKING:
    from collections.abc import Iterator

WORKER_MAGIC_1 = 0x6E697863  # "nixc": client hello
WORKER_MAGIC_2 = 0x6478696F  # "dxio": daemon reply


@pytest.fixture
def sock_path() -> Iterator[Path]:
    if shutil.which("nix-daemon") is None:
        pytest.skip("nix-daemon not available")
    # tmp_path exceeds the AF_UNIX path limit (104 bytes on macOS)
    with tempfile.TemporaryDirectory(prefix="proxy-") as tmpdir:
        yield Path(tmpdir) / "socket"


async def test_proxy_answers_the_nix_handshake(sock_path: Path) -> None:
    async with nix_daemon_proxy(sock_path, [("max-jobs", "1")]):
        reader, writer = await asyncio.open_unix_connection(str(sock_path))
        writer.write(struct.pack("<Q", WORKER_MAGIC_1))
        await writer.drain()
        reply = await asyncio.wait_for(reader.readexactly(8), timeout=10)
        writer.close()
        assert struct.unpack("<Q", reply)[0] == WORKER_MAGIC_2


async def test_proxy_propagates_eof(sock_path: Path) -> None:
    """Client half-close must reach the daemon, or every connection
    leaks a nix-daemon process that waits for more input."""
    async with nix_daemon_proxy(sock_path, []):
        reader, writer = await asyncio.open_unix_connection(str(sock_path))
        writer.write(struct.pack("<Q", WORKER_MAGIC_1))
        await writer.drain()
        reply = await asyncio.wait_for(reader.readexactly(8), timeout=10)
        assert struct.unpack("<Q", reply)[0] == WORKER_MAGIC_2
        writer.write_eof()
        # Drain until EOF: only arrives if the daemon exited.
        await asyncio.wait_for(reader.read(), timeout=10)
        writer.close()
