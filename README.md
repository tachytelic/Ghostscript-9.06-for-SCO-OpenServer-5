# Ghostscript 9.06 for SCO OpenServer 5

A working build of [Ghostscript 9.06](https://www.ghostscript.com/)
(August 2012) for **SCO OpenServer 5.0.7** — the PostScript/PDF
interpreter. Read and render **modern PDFs**, convert PostScript ⇄ PDF,
and rasterize either for printing.

```
$ gs --version
9.06

$ gs -q -dNOPAUSE -dBATCH -sDEVICE=png16m -r150 -o page1.png report.pdf   # PDF -> PNG
$ gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -o out.pdf in.ps              # PS  -> PDF
$ gs -q -dNOPAUSE -dBATCH -sDEVICE=ps2write -o out.ps in.pdf              # PDF -> PS
```

A real 23-page PDF (embedded fonts, colour, images) renders correctly —
verified end-to-end on SCO 5.0.7.

## Why 9.06?

SCO Skunkware shipped **Ghostscript 5.50** (1998), which predates the
modern PDF format — it chokes on essentially anything produced in the last
~20 years. 9.06 is the sweet spot for this old toolchain:

- **Reads essentially all common real-world PDFs** (PDF 1.7): transparency,
  CID/OpenType fonts, JBIG2, JPEG2000, AES encryption.
- **Pure C.** The Ghostscript core has always been C — no version ever
  needed C++ — so gcc 3.4.6 builds it. (The later "pdfi" PDF rewrite is
  also C, and only appears in ≥ 9.55, which adds nothing for common PDFs.)
- **Builds from bundled dependencies.** freetype, jpeg, libpng, zlib,
  lcms2, jbig2dec, openjpeg and tiff are all in the source tree — no
  separate dependency-porting projects.
- **GPLv3** (Ghostscript went AGPL at 9.07), if that matters to you.

Only **two tiny SCO fixes** were needed — see [The two fixes](#the-two-fixes).

## Install

> **Fresh SCO box?** Install [curl with TLS](https://github.com/tachytelic/curl-7.88.1-for-SCO-OpenServer-5)
> first — that's the only file that needs `scp`. After that everything,
> including this, fetches over HTTPS from GitHub.

Ghostscript's init files, resources and the standard 35 PostScript fonts
are **baked into the executable** (ROM filesystem), so this ships as a
**single, self-contained, relocatable binary** — no support files, no
fixed install path. Just drop it on `PATH`:

```sh
# On the SCO box (curl-with-TLS assumed on PATH):
curl -LO https://github.com/tachytelic/Ghostscript-9.06-for-SCO-OpenServer-5/releases/download/v1.0.0/gs
chmod +x gs
mv gs /usr/local/bin/gs
gs --version
```

The binary dynamically links `/usr/lib/libc.so.1` and `/usr/lib/libm.so.1`
only — both stock SCO 5.0.7. **No external runtime dependencies** (built
`--disable-fontconfig` so it doesn't pull `libfontconfig`/`libexpat` from
the gwxlibs add-on, which isn't on a base SCO install).

## What it's good for on SCO

### Reading modern PDFs

The headline capability 5.50 lacks. Render any page to an image, or dump
text:

```sh
gs -q -dNOPAUSE -dBATCH -sDEVICE=png16m -r150 -dFirstPage=1 -dLastPage=1 \
   -o page1.png document.pdf
gs -q -dNOPAUSE -dBATCH -sDEVICE=txtwrite -o - document.pdf   # extract text
```

### Printing PostScript/PDF — including to non-PostScript printers

This pairs naturally with [a2ps for SCO](https://github.com/tachytelic/a2ps-4.14-for-SCO-OpenServer-5).
a2ps turns text/source into PostScript; Ghostscript covers the two cases
a2ps alone can't:

```sh
# 1. Print a PDF on a PostScript network printer (convert PDF -> PS first):
gs -q -dNOPAUSE -dBATCH -sDEVICE=ps2write -o - report.pdf | \
    bash -c 'cat >/dev/tcp/192.168.1.50/9100'

# 2. Print to a NON-PostScript (PCL/inkjet) printer — rasterize first.
#    e.g. an HP PCL printer on port 9100:
gs -q -dNOPAUSE -dBATCH -sDEVICE=ljet4 -r600 -o - report.pdf | \
    bash -c 'cat >/dev/tcp/192.168.1.60/9100'
```

Ghostscript includes ~380 printer drivers (`gs -h` lists them): the
`ljet*`/`cljet*`/`pcl*` family, Epson ESC/P (`epson`, `escp`), Canon BJC,
inkjet `cdj*`/`hpdj*`, `pxlmono`/`pxlcolor`, and generic raster
(`png*`, `tiff*`, `bmp*`, `pnm`, `jpeg`). They're compiled in and cost
almost nothing in size, so the full set is kept.

### Format conversion

`pdfwrite` (PS/PDF → PDF, incl. downsampling/optimising), `ps2write`
(→ PostScript), `eps2write` (→ EPS). The classic `ps2pdf`/`pdf2ps`
wrappers are just these devices.

## The two fixes

Both are applied *after* `configure` (which regenerates the files they
touch), and both are baked into `build.sh`:

1. **Bundled libtiff — `USE_WIN32_FILEIO`.** GS 9.06 ships
   `tiff/libtiff/tif_config.h` with `#define USE_WIN32_FILEIO 1` hardcoded
   on, which forces the Windows `HFILE` typedef path and breaks every
   `tiff*.c` on a Unix box (`syntax error before "thandle_t"`). We
   `#undef` it. A Ghostscript packaging bug, not a real libtiff issue.

2. **`-O0` for the SCO optimizer bug.** Ghostscript's own historical
   `Make.htm` warns that SCO OpenServer 5's compiler has optimizer bugs —
   *"compile without `-O`."* Built at the default `-O`, gs compiles clean
   but **SIGSEGVs at render time**. Changing `CFLAGS_STANDARD= -O` to
   `-O0` fixes it. (Trade-off: rendering is a little slower than an
   optimised build would be — correctness first.)

That's the entire SCO delta. No source-code changes to Ghostscript itself.

## Building from source

You probably don't need to — the release binary is what `build.sh`
produces. This is a **native build** on SCO.

### Requirements

- **GCC 3.4+** as a C compiler (built with 3.4.6; no C++ needed).
- `/usr/gnu/bin/gmake`, **bash** (fast configure shell), **perl** (base SCO).
- ~200 MB scratch space.

### Build

```sh
cd ghostscript-sco
./build.sh
```

Fetches `ghostscript-9.06.tar.gz` (SourceForge source mirror — 9.06 isn't
on Artifex's GitHub, which only goes back to 9.18), configures
`--without-x --disable-fontconfig …`, applies the two fixes above, builds
(~900 objects), strips. Output: `ghostscript-9.06/bin/gs`, the single
self-contained binary.

## Repository layout

```
build.sh                     Native-build script (run on SCO)
prebuilt/
  gs                         ~14 MB self-contained binary  ← ships via Releases
LICENSE                      MIT (build script only)
README.md                    This file
```

The binary ships via the **[Releases](../../releases)** page (14 MB — too
big for clone bloat).

## License

Ghostscript 9.06 is © Artifex Software, distributed under
[GPLv3](https://www.gnu.org/licenses/gpl-3.0.html). The prebuilt binary is
upstream Ghostscript 9.06 with no source changes — only the two
post-configure build-config fixes above, which alter no Ghostscript code.

The build script in this repo is released under the MIT license — see
[LICENSE](LICENSE).

## See also

- [a2ps 4.14 for SCO](https://github.com/tachytelic/a2ps-4.14-for-SCO-OpenServer-5)
  — text/source → PostScript; the natural front-end to Ghostscript here.
- [curl 7.88.1 for SCO](https://github.com/tachytelic/curl-7.88.1-for-SCO-OpenServer-5)
  — the first install on a fresh SCO box.
- [More SCO OpenServer 5 binaries](https://scoexpert.com/guides/sco-openserver-5-binaries/)
  — the hub.
