#!/bin/sh
# Build the uFMOD static library (WINMM driver) for Win32 and Win64:
#
#   dist/x86/ufmod.lib  dist/x86/ufmod.h
#   dist/x64/ufmod.lib  dist/x64/ufmod.h
#
# Requires NASM 2.x and llvm-lib (or MinGW's ar). The libraries work with
# MSVC and MinGW; the x86 one is marked SafeSEH-compatible.
#
# The settings below can be overridden from the environment, e.g.:
#   UF_FREQ=44100 UF_UFS=UNICODE ./mk_dist.sh

set -e
cd "$(dirname "$0")"

# Mixing rate: 22050, 44100 or 48000
UF_FREQ=${UF_FREQ:-48000}
# Volume ramping mode (interpolation): NONE, WEAK or STRONG
UF_RAMP=${UF_RAMP:-STRONG}
# Strings encoding: ANSI or UNICODE
UF_UFS=${UF_UFS:-ANSI}
# Build mode: NORMAL, UNSAFE or BENCHMARK
UF_MODE=${UF_MODE:-NORMAL}
# Tools and output directory
NASM=${NASM:-nasm}
DIST=${DIST:-dist}

check() { # name value allowed...
	name=$1; value=$2; shift 2
	for v in "$@"; do [ "$value" = "$v" ] && return; done
	echo "$name=$value not supported (use one of: $*)" >&2
	exit 1
}
check UF_FREQ "$UF_FREQ" 22050 44100 48000
check UF_RAMP "$UF_RAMP" NONE WEAK STRONG
check UF_UFS "$UF_UFS" ANSI UNICODE
check UF_MODE "$UF_MODE" NORMAL UNSAFE BENCHMARK
command -v "$NASM" > /dev/null || { echo "$NASM not found" >&2; exit 1; }

# Pack ufmod.obj in the current directory into a static library
mklib() { # arch out
	if command -v llvm-lib > /dev/null; then
		llvm-lib /nologo /machine:$1 /out:"$2" ufmod.obj
	else
		if [ $1 = x64 ]; then ar=x86_64-w64-mingw32-ar; else ar=i686-w64-mingw32-ar; fi
		command -v $ar > /dev/null || { echo "neither llvm-lib nor $ar found" >&2; exit 1; }
		rm -f "$2"
		$ar rcs "$2" ufmod.obj
	fi
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for arch in x86 x64; do
	if [ $arch = x64 ]; then fmt="-fwin64 -dX64"; else fmt="-fwin32 -dSAFESEH"; fi
	mkdir -p "$tmp/$arch" "$DIST/$arch"
	"$NASM" -O4 -t $fmt -df$UF_FREQ -d$UF_RAMP -d$UF_UFS -d$UF_MODE -dOBJ -dWINMM \
		-isrc/ -o "$tmp/$arch/ufmod.obj" src/nasm.asm
	(cd "$tmp/$arch" && mklib $arch ufmod.lib) # member name: ufmod.obj
	cp "$tmp/$arch/ufmod.lib" "$DIST/$arch/ufmod.lib"
	cp include/ufmod.h "$DIST/$arch/ufmod.h"
	echo "$DIST/$arch: ufmod.lib ufmod.h"
done
