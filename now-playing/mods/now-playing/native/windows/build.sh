#!/bin/sh
# The Windows backend needs no build: nowplaying.ps1 runs in Windows PowerShell 5.1,
# which ships with Windows. This only checks that it is there and can reach GSMTC.
set -eu
cd "$(dirname "$0")"
if ! command -v powershell.exe >/dev/null 2>&1; then
  echo "powershell.exe (Windows PowerShell 5.1) is not on PATH; the Now Playing block needs it" >&2
  exit 1
fi
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File nowplaying.ps1 send nothing NoSuchApp >/dev/null 2>&1 && code=0 || code=$?
# exit 4 means the helper loaded GSMTC and found no session by that name: it works.
if [ "$code" != 4 ]; then
  echo "native/windows/nowplaying.ps1 could not reach GSMTC (exit $code)" >&2
  exit 1
fi
echo "checked native/windows: Windows PowerShell 5.1 reaches GSMTC"
