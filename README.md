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

Choose a build date on [GitHub Releases](https://github.com/shawnchain-cxw/expej-packaging/releases) and download the `expej-a733-YYYY-MM-DD-<run>.<attempt>-arm64.zip` asset. Each ZIP contains Vulkan and OpenGL/GLES built from the same Mesa commit, PowerVR module packages for both supported kernels, SHA-256 checksums and build information. The date is the UTC date when the build bundle was assembled.

Extract the ZIP into an empty directory and run the following there. The install command selects the PowerVR module package for the running kernel.

```sh
sha256sum -c SHA256SUMS && sudo apt install \
  ./expej-powervr-"$(uname -r)"_*.deb \
  ./expej-vulkan_*.deb ./expej-opengl_*.deb vulkan-tools mesa-utils
```

The kernel module package updates the module dependency index with `depmod`. Vulkan and OpenGL/GLES install in their own paths and can be selected per application for testing.

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

## Building a release

Run the [A733 ARM64 release workflow](https://github.com/shawnchain-cxw/expej-packaging/actions/workflows/a733-release.yml) on `main` with one full `expej-mesa` commit SHA. The workflow uses `EXPEJ_MESA_DEPLOY_KEY` for read-only access to Mesa. It builds both userspace drivers and the two modules in parallel, verifies all four packages, and publishes one ZIP to Releases. The run and attempt numbers keep multiple builds from the same date distinct. Packaging revisions follow the Debian version suffix, and driver build identifiers follow the source.
