<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2026 Shawn Chain -->
# Expej Debian packages

[简体中文](README.zh-CN.md)

## Install on A733

Use a Debian 13 ARM64 system with its GPU firmware and kernel `6.6.98-5-aw2511` or `6.6.98-6-aw2511`.

Download the dated ARM64 ZIP from [GitHub Releases](https://github.com/shawnchain-cxw/expej-packaging/releases), extract it into an empty directory, and run the following there. The command selects the module for the running kernel and installs both userspace drivers.

```sh
sudo apt install \
  ./expej-powervr-"$(uname -r)"_*.deb \
  ./expej-vulkan_*.deb ./expej-opengl_*.deb && sudo reboot
```

The current packages select Expej Vulkan and OpenGL/GLES per application. See the commands below to try them after reboot.

<details>
<summary>Optional verification and removal</summary>

Run `sha256sum -c SHA256SUMS` in the extracted directory to verify the download. After reboot, check which driver is bound to the DRM render node and install the test tools.

```sh
ls -l /sys/class/drm/renderD*/device/driver
sudo apt install vulkan-tools mesa-utils
```

A DRM render node should be bound to `powervr`. Run the following as your normal user to check that Vulkan reports a PowerVR GPU and EGL reports `Expej vNNNN`.

```sh
PVR_I_WANT_A_BROKEN_VULKAN_DRIVER=1 \
  VK_DRIVER_FILES=/usr/share/expej/vulkan/icd.d/powervr_icd.aarch64.json \
  vulkaninfo --summary

expej-gl-run eglinfo -B
```

If a check fails, inspect the kernel log with `sudo journalctl -k -b -n 100`. To remove the packages, run the following and reboot.

```sh
sudo apt remove "expej-powervr-$(uname -r)" expej-vulkan expej-opengl && sudo reboot
```

</details>

## Building a release

Run the [A733 ARM64 release workflow](https://github.com/shawnchain-cxw/expej-packaging/actions/workflows/a733-release.yml) on `main` with one full `expej-mesa` commit SHA. The workflow uses `EXPEJ_MESA_DEPLOY_KEY` for read-only access to Mesa. It builds both userspace drivers and the two modules in parallel, verifies all four packages, and publishes one ZIP to Releases. The run and attempt numbers keep multiple builds from the same date distinct. Packaging revisions follow the Debian version suffix, and driver build identifiers follow the source.
