# uFMOD x64

A port of [uFMOD](https://ufmod.sourceforge.io/) 1.25.2a (Win32) to 64-bit Windows.

uFMOD is a tiny XM (FastTracker II) player library written in assembly language by Asterix and
Quantum. This repository builds it as a static library for both Win32 (x86) and Win64 (x64) from
the same sources. The x86 build produces the same code as the original release.

For documentation, tools, examples and the other uFMOD ports, see the official site:
**https://ufmod.sourceforge.io/**

## Download

Prebuilt libraries are attached to the [releases](../../releases):

- `ufmod-<version>-x86.zip` – `ufmod.lib` and `ufmod.h` for Win32
- `ufmod-<version>-x64.zip` – `ufmod.lib` and `ufmod.h` for Win64

They use the WINMM output driver, 48 kHz mixing and ANSI file names, and link with MSVC and MinGW.
The x86 library is marked SafeSEH-compatible.

## Usage

```c
#include "ufmod.h"
#pragma comment(lib, "ufmod.lib")
#pragma comment(lib, "winmm.lib")

/* Play an XM image from memory; the track loops until stopped */
uFMOD_PlaySong(xm_data, (void *)xm_size, XM_MEMORY);
/* ... */
uFMOD_PlaySong(0, 0, 0); /* stop */
```

`XM_FILE` plays a file and `XM_RESOURCE` an `RT_RCDATA` resource. Combine with `XM_NOLOOP` to play
once or `XM_SUSPENDED` to load without starting. See `include/ufmod.h` for the full API.

## Building

Requires NASM 2.x and `llvm-lib` (or MinGW's `ar`):

```sh
./mk_dist.sh
```

This writes `dist/x86` and `dist/x64`. Settings can be overridden from the environment:

| Variable  | Values                                  | Default  |
|-----------|-----------------------------------------|----------|
| `UF_FREQ` | `22050`, `44100`, `48000`               | `48000`  |
| `UF_RAMP` | `NONE`, `WEAK`, `STRONG` (volume ramping) | `STRONG` |
| `UF_UFS`  | `ANSI`, `UNICODE` (file name encoding)  | `ANSI`   |
| `UF_MODE` | `NORMAL`, `UNSAFE`, `BENCHMARK`         | `NORMAL` |

`src/eff.inc` selects the XM effects and features compiled in. The `eff.exe` tool from the original
package can generate it for a specific song to make the library smaller.

To assemble directly, use `nasm -t -fwin64 -dX64 ...` for x64, or `-fwin32` for x86 (see
`mk_dist.sh`).

## License

uFMOD sources, binaries and utility programs are © 2005–2008 Asterix and Quantum. The original
package states "All rights reserved", and its sources are marked "uFMOD public source code release.
Provided as-is." It contains no separate license file. This port is distributed under the same
terms as the original uFMOD release. For questions about using uFMOD, refer to the authors at
https://ufmod.sourceforge.io/.
