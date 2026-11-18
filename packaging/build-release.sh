#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Shawn Chain
set -euo pipefail
shopt -s nullglob

artifacts=$1
bundle=$2
build_date=$3
packaging_commit=$4
mesa_commit=$5
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

printf 'Build date (UTC): %s\n' "$build_date" > "$stage/build-info.txt"
for package in expej-powervr-6.6.98-5-aw2511 expej-powervr-6.6.98-6-aw2511 \
               expej-vulkan expej-opengl; do
    artifact="$artifacts/${package%-aw2511}-arm64"
    debs=("$artifact"/"${package}_"*_arm64.deb)
    if [[ ${#debs[@]} != 1 ]]; then
        printf 'Expected exactly one ARM64 package for %s\n' "$package" >&2
        exit 1
    fi
    deb=${debs[0]}
    filename=${deb##*/}
    (cd "$artifact" && sha256sum "$filename" | diff - SHA256SUMS)
    test "$(dpkg-deb -f "$deb" Package)" = "$package"
    test "$(dpkg-deb -f "$deb" Architecture)" = arm64
    info="$artifact/build-info.txt"
    grep -Fx "Packaging commit: $packaging_commit" "$info"
    case "$package" in
        expej-vulkan|expej-opengl) grep -Fx "Mesa commit: $mesa_commit" "$info" ;;
        *) grep -Fx "Target release: ${package#expej-powervr-}" "$info" ;;
    esac
    cp "$deb" "$stage/"
    printf '\n[%s]\n' "$filename" >> "$stage/build-info.txt"
    cat "$info" >> "$stage/build-info.txt"
done

(
    cd "$stage"
    sha256sum -- *.deb build-info.txt > SHA256SUMS
    zip -q -0 "$bundle" -- *.deb build-info.txt SHA256SUMS
)
unzip -tq "$bundle"
