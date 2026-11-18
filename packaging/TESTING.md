<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2026 Shawn Chain -->
# ARM64 PowerVR trial packages

Run `uname -r` and `dpkg --print-architecture`. Choose the PowerVR module whose
package name ends in your running kernel release. The userspace Vulkan package
is the same for both kernels. Verify each artifact with `sha256sum -c SHA256SUMS`
in its own directory.

Install the matching module and Vulkan driver with `sudo apt install ./PACKAGE.deb`
for each package. The module package updates the module dependency list. It uses the
installed kernel, device tree and firmware. The Vulkan ICD is selected per process so
that the system ICD selection stays intact during the trial.

Confirm that the required GPU firmware is installed, then reboot after installing
the packages. Verify the module and Vulkan driver with these commands.

```sh
modinfo -n powervr
ls -l /dev/dri/
PVR_I_WANT_A_BROKEN_VULKAN_DRIVER=1 \
  VK_DRIVER_FILES=/usr/share/expej/vulkan/icd.d/powervr_icd.aarch64.json \
  vulkaninfo --summary
sudo journalctl -k -b -n 100
```

The opt-in variable enables testing on this GPU. The reported Vulkan physical
device should be a PowerVR GPU. `vulkaninfo` is provided by `vulkan-tools`. Keep
the kernel log and driver version for the trial.
