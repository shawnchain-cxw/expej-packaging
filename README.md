<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2026 Shawn Chain -->
# Expej Debian packages

[简体中文](README.zh-CN.md)

## Install on A733

### Check the system requirements

Use a Debian 13 ARM64 system with kernel `6.6.98-5-aw2511` or `6.6.98-6-aw2511`. The module package requires the installed `linux-image` package for that exact release. Check the kernel, architecture and firmware before selecting a module package.

```sh
uname -r
dpkg --print-architecture
dpkg-query -W "linux-image-$(uname -r)"
ls /lib/firmware/powervr/rogue_36.56.104.183_v1.fw*
```

The firmware may be compressed. If it is missing, install the corresponding firmware for your device before loading `powervr`.

### Download and install

Download artifacts from successful runs and extract each to a directory named after the artifact. Choose Vulkan and OpenGL/GLES artifacts with the same `Mesa commit` in `build-info.txt`. GitHub retains build artifacts for 30 days.

| Workflow | Artifact | Selection |
| --- | --- | --- |
| [PowerVR module](https://github.com/shawnchain-cxw/expej-packaging/actions/workflows/powervr-deb.yml) | `expej-powervr-6.6.98-5-arm64` or `expej-powervr-6.6.98-6-arm64` | Match `uname -r`. |
| [Vulkan](https://github.com/shawnchain-cxw/expej-packaging/actions/workflows/vulkan-deb.yml) | `expej-vulkan-arm64` | Either kernel release. |
| [OpenGL and GLES](https://github.com/shawnchain-cxw/expej-packaging/actions/workflows/opengl-deb.yml) | `expej-opengl-arm64` | Either kernel release. |

Run from the parent directory of the three extracted artifacts.

```sh
(
  set -e
  kernel=$(uname -r)
  module_artifact="expej-powervr-${kernel%-aw2511}-arm64"
  for artifact in "$module_artifact" expej-vulkan-arm64 expej-opengl-arm64; do
    (cd "$artifact" && sha256sum -c SHA256SUMS)
  done
  sudo apt install \
    ./"$module_artifact"/expej-powervr-"$kernel"_*.deb \
    ./expej-vulkan-arm64/expej-vulkan_*.deb \
    ./expej-opengl-arm64/expej-opengl_*.deb \
    vulkan-tools mesa-utils
)
```

The kernel module package updates the module dependency index with `depmod`. Vulkan and OpenGL/GLES install in their own paths and can be selected per application for testing.

If you received a combined ZIP, run the following from its extracted directory instead.

```sh
sha256sum -c SHA256SUMS && sudo apt install \
  ./expej-powervr-"$(uname -r)"_*.deb \
  ./expej-vulkan_*.deb ./expej-opengl_*.deb vulkan-tools mesa-utils
```

### Reboot and verify

Reboot after installation and check the driver bound to the DRM render node. Run the Vulkan and EGL checks as your normal user.

```sh
ls -l /sys/class/drm/renderD*/device/driver
```

```sh
PVR_I_WANT_A_BROKEN_VULKAN_DRIVER=1 \
  VK_DRIVER_FILES=/usr/share/expej/vulkan/icd.d/powervr_icd.aarch64.json \
  vulkaninfo --summary

expej-gl-run eglinfo -B
```

Vulkan should enumerate a PowerVR GPU and report the packaged build. EGL should report `Expej vNNNN`, where `NNNN` is the OpenGL/GLES build number. If a check fails, collect its output and the kernel log from `sudo journalctl -k -b -n 100`.

To remove the Expej packages, run the following and reboot.

```sh
sudo apt remove "expej-powervr-$(uname -r)" expej-vulkan expej-opengl
sudo reboot
```

## CI builds

The manually triggered ARM64 workflows publish `.deb` files, SHA-256 checksums and build metadata as workflow artifacts.

| Workflow | Inputs | Package |
| --- | --- | --- |
| Vulkan ARM64 package | Full commit SHA from `expej-mesa` | `expej-vulkan`, a selectable Vulkan ICD |
| OpenGL and GLES ARM64 package | Full commit SHA with the native PowerVR Gallium build target | `expej-opengl`, selected per application with `expej-gl-run` |
| PowerVR ARM64 module packages | Published kernel headers and a pinned PowerVR backport | One `expej-powervr-*` package for each supported kernel release |

The userspace workflows use the `EXPEJ_MESA_DEPLOY_KEY` Actions secret with read-only access to the Mesa repository. Their artifacts record both the selected Mesa commit and the packaging commit. The module workflow uses the kernel headers and PowerVR patch series without a Mesa checkout. The current module targets are `6.6.98-5-aw2511` and `6.6.98-6-aw2511`.

The default userspace workflow inputs select the same Mesa commit. Packaging revisions follow the Debian version suffix. Driver build identifiers follow the source.
