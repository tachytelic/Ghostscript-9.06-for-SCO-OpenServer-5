#!/bin/sh
# Build Ghostscript 9.06 natively on SCO OpenServer 5.0.7.
#
# Run this script ON the SCO machine, in a writable directory.
#
# Required:
#   GCC 3.4 or later as a C compiler (built with gcc-3.4.6). No C++ needed
#       — the Ghostscript core is C; the bundled libs are C too.
#   /usr/gnu/bin/gmake, bash (fast configure shell), perl (base SCO).
#   curl or wget, OR drop ghostscript-9.06.tar.gz next to this script.
#   ~200 MB free scratch space for the build tree.
#
# Output: ./ghostscript-9.06/bin/gs — a single, self-contained, RELOCATABLE
#   ~14 MB stripped binary. Ghostscript's init files, resources and the
#   standard fonts are baked into the executable via the ROM filesystem
#   (COMPILE_INITS=1), so the one file is everything — copy it anywhere and
#   run it. Dynamic deps: /usr/lib/libc.so.1 and /usr/lib/libm.so.1 only,
#   both stock SCO 5.0.7 (built --disable-fontconfig precisely so it does
#   NOT pull libfontconfig/libexpat from the gwxlibs add-on).
#
# Why 9.06: last of the pure-C, pre-AGPL line that already reads essentially
#   all common real-world PDFs (PDF 1.7). Newer releases add nothing for
#   common PDFs and drag in heavier machinery. SCO Skunkware shipped 5.50,
#   which predates modern PDF entirely.

set -e

SCRIPT_DIR=`cd \`dirname "$0"\` && pwd`
VERSION=9.06
TARBALL=ghostscript-${VERSION}.tar.gz
SRCDIR=ghostscript-${VERSION}
PREFIX=/usr/local/ghostscript-${VERSION}

if [ -n "$GCC" ]; then
    CC="$GCC"
elif [ -z "$CC" ]; then
    if which gcc-3.4.6 >/dev/null 2>&1; then
        CC=gcc-3.4.6
    else
        CC=gcc
    fi
fi
export CC

# /usr/local/bin first: that's where gcc-3.4.6, bash and curl live.
PATH=/usr/local/bin:/usr/gnu/bin:/usr/ccs/bin:/usr/bin:/bin
export PATH

if [ ! -f "$TARBALL" ]; then
    echo "Fetching $TARBALL..."
    # 9.06 is not on Artifex's GitHub (that only goes back to 9.18); use the
    # SourceForge source mirror. The GNU-Ghostscript 9.06 fork on ftp.gnu.org
    # is an .tar.xz (no xz on stock SCO) — this .gz is the Artifex original.
    GS_URL="https://master.dl.sourceforge.net/project/portableapps/Source/Ghostscript/${TARBALL}"
    if which curl >/dev/null 2>&1; then
        curl -kL -o "$TARBALL" "$GS_URL"
    elif which wget >/dev/null 2>&1; then
        wget --no-check-certificate -O "$TARBALL" "$GS_URL"
    else
        echo "ERROR: no curl or wget. Drop $TARBALL next to this script." >&2
        exit 1
    fi
fi

if [ ! -d "$SRCDIR" ]; then
    echo "Unpacking $TARBALL..."
    gzip -dc "$TARBALL" | tar xf -
fi

cd "$SRCDIR"

SHELL_BIN=`which bash 2>/dev/null || true`

echo "Configuring..."
# --without-x        — no X display device; file/raster output only.
# --disable-fontconfig — drop the libfontconfig dependency (and libexpat,
#                      which fontconfig drags in). Both live in the gwxlibs
#                      add-on, not base SCO, so linking them would break the
#                      binary on a bare box. gs finds its fonts via the
#                      baked-in ROM filesystem instead — no capability loss.
# --disable-cups/dbus/gtk — not present / not wanted on SCO.
if [ -n "$SHELL_BIN" ]; then
    CONFIG_SHELL="$SHELL_BIN" "$SHELL_BIN" configure \
        --prefix="$PREFIX" --without-x \
        --disable-fontconfig --disable-cups --disable-dbus --disable-gtk \
        CC="$CC"
else
    ./configure --prefix="$PREFIX" --without-x \
        --disable-fontconfig --disable-cups --disable-dbus --disable-gtk \
        CC="$CC"
fi

# --- Two SCO fixes, BOTH applied AFTER configure -----------------------
# configure regenerates both Makefile and tiff/libtiff/tif_config.h, so
# these MUST come after it, not before, or they get clobbered.
#
# Fix 1: the bundled libtiff ships tif_config.h with USE_WIN32_FILEIO
# hardcoded on, which forces the Windows HFILE typedef path on Unix and
# breaks every tiff*.c with "syntax error before thandle_t". This is a
# Ghostscript packaging bug, not a real libtiff portability problem — the
# box is not Windows, so just turn it off.
echo "SCO fix 1/2: disabling USE_WIN32_FILEIO in bundled libtiff..."
perl -i -pe "s{^#define USE_WIN32_FILEIO 1}{/* SCO fix: not Windows */\n#undef USE_WIN32_FILEIO}" tiff/libtiff/tif_config.h

# Fix 2: SCO OpenServer 5 has documented compiler optimizer bugs
# (Ghostscript's own historical Make.htm says "compile without -O"). gs
# builds fine at -O but SIGSEGVs at render time. Build with no optimization.
echo "SCO fix 2/2: forcing -O0 (OpenServer optimizer bug)..."
perl -i -pe "s{^CFLAGS_STANDARD= -O\$}{CFLAGS_STANDARD= -O0}" Makefile
# ----------------------------------------------------------------------

echo "Compiling (this is the long part — ~900 objects)..."
gmake

echo "Stripping..."
strip "$SCRIPT_DIR/$SRCDIR/bin/gs" 2>/dev/null || true

ls -l "$SCRIPT_DIR/$SRCDIR/bin/gs"
echo
echo "Built: $SCRIPT_DIR/$SRCDIR/bin/gs  (single self-contained binary)"
echo
echo "Install: just copy it onto PATH — it needs no support files."
echo "  cp $SRCDIR/bin/gs /usr/local/bin/gs"
echo
echo "Test:  gs --version"
echo "       gs -q -dNOPAUSE -dBATCH -sDEVICE=png16m -r72 -o out.png in.pdf"
