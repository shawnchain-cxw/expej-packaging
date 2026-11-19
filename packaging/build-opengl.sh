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
cd "$source"
commit=$(git rev-parse --verify HEAD)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/source"
git archive "$commit" | tar -x -C "$work/source"
cd "$work/source"

serial=$(awk '$2 == "EXPEJ_GL_RELEASE" { gsub(/"/, "", $3); print $3 }' src/imagination/expej_version.h)
[[ $serial =~ ^[0-9]{4}$ ]]
version="$(cat VERSION)+expej${serial}-3"
package=expej-opengl
prefix=/usr/lib/aarch64-linux-gnu/expej-gl
root="$work/package"
export MESA_GIT_SHA1_OVERRIDE="$commit"

meson setup "$work/build" --wrap-mode=nodownload --buildtype=release \
    --prefix="$prefix" --libdir=lib -Ddri-drivers-path="$prefix/lib/dri" \
    -Db_ndebug=true -Dplatforms=x11,wayland -Dvulkan-drivers= -Dgallium-drivers=powervr \
    -Dopengl=true -Dglx=dri -Degl=enabled -Dgles1=enabled -Dgles2=enabled \
    -Dglvnd=enabled -Dgbm=enabled -Dllvm=enabled -Dvideo-codecs= -Dtools= -Dbuild-tests=false
ninja -C "$work/build" -j "$(nproc)"
meson install -C "$work/build" --no-rebuild --destdir "$root" --tags runtime

library_dir="$root$prefix/lib"
dri="$library_dir/dri/powervr_dri.so"
manifest="$root$prefix/share/glvnd/egl_vendor.d/50_mesa.json"
desktop_damage="$prefix/lib/libexpej_egl_desktop_damage.so"
test -f "$dri"
test -f "$manifest"
if (( 10#$serial >= 226 )); then
    test -f "$root$desktop_damage"
fi
mapfile -t gallium_libraries < <(find "$library_dir" -maxdepth 1 -type f -name 'libgallium-*.so')
test "${#gallium_libraries[@]}" = 1
gallium=${gallium_libraries[0]}
strings "$gallium" | grep -Fx "Expej v$serial"

install -Dm644 docs/license.rst "$root/usr/share/doc/$package/copyright"
mkdir -p "$root/usr/bin" "$root/DEBIAN" "$work/debian"
desktop_damage_elf=()
if test -f "$root$desktop_damage"; then
    desktop_damage_elf=(-e"$root$desktop_damage")
    plasma_dropin="$root/usr/lib/systemd/user/plasma-plasmashell.service.d"
    mkdir -p "$plasma_dropin"
    cat > "$plasma_dropin/70-expej-egl-damage.conf" <<EOF
[Service]
Environment="LD_PRELOAD=$desktop_damage"
EOF
fi
cat > "$root/usr/bin/expej-gl-run" <<EOF
#!/bin/sh
export LD_LIBRARY_PATH="$prefix/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
export LIBGL_DRIVERS_PATH="$prefix/lib/dri"
export GBM_BACKENDS_PATH="$prefix/lib/gbm"
export __EGL_VENDOR_LIBRARY_FILENAMES="$prefix/share/glvnd/egl_vendor.d/50_mesa.json"
export __GLX_VENDOR_LIBRARY_NAME=mesa
exec "\$@"
EOF
chmod 0755 "$root/usr/bin/expej-gl-run"

cat > "$work/debian/control" <<EOF
Source: $package
Section: libs
Priority: optional
Maintainer: Shawn Chain <w243698397@gmail.com>

Package: $package
Architecture: arm64
Description: Expej PowerVR OpenGL and GLES driver
EOF
shlibdeps=$(cd "$work" && dpkg-shlibdeps -O -l"$library_dir" \
    -S"$root" -e"$dri" -e"$gallium" \
    -e"$library_dir/libEGL_mesa.so.0" -e"$library_dir/libGLX_mesa.so.0" \
    "${desktop_damage_elf[@]}")
[[ $shlibdeps == shlibs:Depends=* ]]
cat > "$root/DEBIAN/control" <<EOF
Package: $package
Version: $version
Architecture: arm64
Section: libs
Priority: optional
Maintainer: Shawn Chain <w243698397@gmail.com>
Depends: libegl1, libgl1, libgles1, libgles2, ${shlibdeps#shlibs:Depends=}
Description: Expej PowerVR OpenGL and GLES driver for ARM64
 Provides EGL and GLX vendor libraries and a native PowerVR DRI driver.
 Run applications through expej-gl-run to select these libraries.
EOF

{
    printf 'Mesa commit: %s\nPackaging commit: %s\nDriver build: v%s\n' "$commit" "$recipe_commit" "$serial"
    readelf -n "$gallium" | grep 'Build ID:'
} > "$output/build-info.txt"
deb="${package}_${version}_arm64.deb"
dpkg-deb --root-owner-group --build "$root" "$output/$deb"
dpkg-deb --info "$output/$deb"
(cd "$output" && sha256sum "$deb" > SHA256SUMS)
