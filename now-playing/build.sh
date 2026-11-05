#!/bin/sh
# Builds the MediaRemote helper the mod runs through /usr/bin/perl.
# Needs the Xcode Command Line Tools (clang). Output: bin/libnowplaying.dylib (arm64 + x86_64).
set -eu
cd "$(dirname "$0")"
mkdir -p bin
clang -dynamiclib -O2 -fobjc-arc -arch arm64 -arch x86_64 -mmacosx-version-min=12.0 \
  -framework Foundation -framework AppKit \
  -o bin/libnowplaying.dylib native/nowplaying.m
echo "built bin/libnowplaying.dylib"
