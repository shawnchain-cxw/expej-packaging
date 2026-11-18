#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Shawn Chain
set -euo pipefail

kernel=$1
commit=$2
output=$3
test "$(dpkg --print-architecture)" = arm64
case "$kernel" in
    6.6.98-5) headers_digest=70257be0802ab6af623a983614e39834bfb75c34c6987edf4ca96b8d66f3be1a ;;
    6.6.98-6) headers_digest=3515940446c10a2f62d6aa527e55fc9ced3f892c948d12cd70a08e9f45f134c9 ;;
    *) printf 'Unsupported target kernel %s\n' "$kernel" >&2; exit 1 ;;
esac

mkdir -p "$output"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
release="$kernel-aw2511"
recipe=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
package="expej-powervr-$release"
version="$kernel+expej0078-2"
root="$work/package"

download() {
    local url=$1 destination=$2 digest=$3
    curl --fail --silent --show-error --location --retry 3 "$url" --output "$destination"
    printf '%s  %s\n' "$digest" "$destination" | sha256sum --check --status
}

headers_url="https://github.com/radxa-pkg/linux-aw2511/releases/download/$kernel/linux-headers-${release}_${kernel}_arm64.deb"
download "$headers_url" "$work/headers.deb" "$headers_digest"
dpkg-deb --extract "$work/headers.deb" "$work/headers"
headers="$work/headers/usr/src/linux-headers-$release"
test -s "$headers/Module.symvers"
test "$(cat "$headers/include/config/kernel.release")" = "$release"

revision=fd50d1520d1140c48628f0ad6eb4e46226ad1b4b
project="https://raw.githubusercontent.com/ayiejosh/a733-powervr-fex/$revision"
download "$project/open-driver-perf/backup-2026-10-10/kernel-powervr-src.tgz" \
    "$work/source.tgz" 856be4c1b8f603e7617748839b587de56776849bc4dfa6d9ad6208d76dd09a92
source_dir="$work/source"
mkdir "$source_dir"
# The snapshot also contains object files and generated Kbuild metadata.
tar -xzf "$work/source.tgz" -C "$source_dir" --strip-components=1 \
    --exclude='*.o' --exclude='*.ko' --exclude='*.cmd' --exclude='*.mod' \
    --exclude='*.mod.c' --exclude=Module.symvers --exclude=modules.order
for prefix in 0001 0002 0003 0004 0005 0006 0007; do
    case "$prefix" in
        0001) name=pvr_fw-add-os_config_flags-test-knob-for-the-firmwar ;;
        0002) name=pvr_queue-check-paired-and-chained-fragment-commands ;;
        0003) name=drm-imagination-acquire-vm_ctx-lock-before-mapping-m ;;
        0004) name=drm-imagination-Propagate-map-failures-correctly-fro ;;
        0005) name=drm-imagination-Fix-page-count-for-page-table-for-ma ;;
        0006) name=drm-imagination-Size-page-table-preallocation-by-dev ;;
        0007) name=drm-imagination-Fix-reference-and-vm_bo-handling-in- ;;
    esac
    file="$prefix-$name.patch"
    curl --fail --silent --show-error --location --retry 3 \
        "$project/kernel/powervr-backport/$file" --output "$work/$file"
    (cd "$source_dir" && git apply "$work/$file")
done
for name in module-metadata firmware-statistics core-count serialized-submission \
            benchmark-scheduling clock-parent fragment-submission-order; do
    (cd "$source_dir" && git apply "$recipe/powervr/$name.patch")
done

make -C "$headers" M="$source_dir" ARCH=arm64 -j "$(nproc)" modules
module="$source_dir/powervr.ko"
read -r vermagic _ < <(modinfo -F vermagic "$module")
test "$vermagic" = "$release"
modinfo -F firmware "$module" | grep -Fx 'powervr/rogue_36.56.104.183_v1.fw'
install -Dm644 "$module" "$root/lib/modules/$release/updates/expej/powervr.ko"
install -d "$root/DEBIAN" "$root/usr/share/doc/$package"
cat > "$root/usr/share/doc/$package/copyright" <<EOF
Source: $project/kernel/powervr-backport
Copyright and author notices are retained in the source files.
License: GPL-2.0-only
 See /usr/share/common-licenses/GPL-2.
EOF
cat > "$root/DEBIAN/control" <<EOF
Package: $package
Version: $version
Architecture: arm64
Section: kernel
Priority: optional
Maintainer: Shawn Chain <w243698397@gmail.com>
Depends: kmod, linux-image-$release
Description: Expej PowerVR DRM module for Linux $release
 Installs the loadable module for manual GPU bring-up and validation.
EOF
for hook in postinst postrm; do
    cat > "$root/DEBIAN/$hook" <<EOF
#!/bin/sh
set -e
if [ -d /lib/modules/$release ]; then
    depmod -a $release
fi
EOF
    chmod 0755 "$root/DEBIAN/$hook"
done

{
    printf 'Packaging commit: %s\nModule build: 0078\nTarget release: %s\n' "$commit" "$release"
    printf 'Headers SHA-256: %s\nBase backport commit: %s\n' "$headers_digest" "$revision"
    readelf -n "$module" | grep 'Build ID:'
    modinfo "$module" | grep -Ev '^(filename|parm):'
} > "$output/build-info.txt"
install -Dm644 "$recipe/TESTING.md" "$output/TESTING.md"
deb="${package}_${version}_arm64.deb"
dpkg-deb --root-owner-group --build "$root" "$output/$deb"
dpkg-deb --info "$output/$deb"
(cd "$output" && sha256sum "$deb" > SHA256SUMS)
