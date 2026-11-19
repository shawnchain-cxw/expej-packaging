#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Shawn Chain
set -euo pipefail

source=$1
recipe_commit=$2
output=$3
test "$(dpkg --print-architecture)" = arm64
mkdir -p "$output"
output=$(cd "$output" && pwd)
recipe=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$source"
commit=$(git rev-parse --verify HEAD)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/source"
git archive "$commit" | tar -x -C "$work/source"
cd "$work/source"

serial=$(awk '$2 == "EXPEJ_VULKAN_RELEASE" { gsub(/"/, "", $3); print $3 }' src/imagination/expej_version.h)
[[ $serial =~ ^[0-9]{4}$ ]]
version="$(cat VERSION)+expej${serial}-2"
package=expej-vulkan
prefix=/usr/lib/aarch64-linux-gnu/expej
manifest=/usr/share/expej/vulkan/icd.d/powervr_icd.aarch64.json
root="$work/package"
export MESA_GIT_SHA1_OVERRIDE="$commit"

meson setup "$work/build" --wrap-mode=nodownload --buildtype=release \
    --prefix=/usr --libdir=lib/aarch64-linux-gnu \
    -Db_ndebug=true -Dplatforms=x11,wayland -Dvulkan-drivers=imagination \
    -Dimagination-srv=false -Dgallium-drivers= -Dopengl=false -Dglx=disabled \
    -Degl=disabled -Dgles1=disabled -Dgles2=disabled -Dgbm=disabled \
    -Dllvm=enabled -Dvideo-codecs= -Dtools= -Dbuild-tests=false
ninja -C "$work/build" -j "$(nproc)"

build="$work/build/src/imagination/vulkan"
library="$root$prefix/libvulkan_powervr_mesa.so"
install -Dm755 "$build/libvulkan_powervr_mesa.so" "$library"
strip --strip-unneeded "$library"
install -d "$(dirname "$root$manifest")"
python3 - "$build/powervr_mesa_icd.aarch64.json" "$root$manifest" "$prefix" <<'PY'
import json
import sys

source, destination, library_dir = sys.argv[1:]
with open(source, encoding="utf-8") as file:
    manifest = json.load(file)
manifest["ICD"]["library_path"] = library_dir + "/libvulkan_powervr_mesa.so"
with open(destination, "w", encoding="utf-8") as file:
    json.dump(manifest, file, indent=2)
    file.write("\n")
PY
install -Dm644 docs/license.rst "$root/usr/share/doc/$package/copyright"

mkdir -p "$work/debian" "$root/DEBIAN"
cat > "$work/debian/control" <<EOF
Source: $package
Section: libs
Priority: optional
Maintainer: Shawn Chain <w243698397@gmail.com>

Package: $package
Architecture: arm64
Description: Expej PowerVR Vulkan driver
EOF
shlibdeps=$(cd "$work" && dpkg-shlibdeps -O -e"$library")
[[ $shlibdeps == shlibs:Depends=* ]]
cat > "$root/DEBIAN/control" <<EOF
Package: $package
Version: $version
Architecture: arm64
Section: libs
Priority: optional
Maintainer: Shawn Chain <w243698397@gmail.com>
Depends: libvulkan1, ${shlibdeps#shlibs:Depends=}
Description: Expej PowerVR Vulkan driver for ARM64
 Includes a selectable Vulkan ICD for testing alongside a system driver.
EOF

{
    printf 'Mesa commit: %s\nPackaging commit: %s\nDriver build: v%s\n' "$commit" "$recipe_commit" "$serial"
    readelf -n "$library" | grep 'Build ID:'
    sha256sum "$library" | cut -d ' ' -f 1
} > "$output/build-info.txt"
install -Dm644 "$recipe/TESTING.md" "$output/TESTING.md"
deb="${package}_${version}_arm64.deb"
dpkg-deb --root-owner-group --build "$root" "$output/$deb"
dpkg-deb --info "$output/$deb"
(cd "$output" && sha256sum "$deb" > SHA256SUMS)
