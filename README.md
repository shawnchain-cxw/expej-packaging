<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2026 Shawn Chain -->
# Expej Debian packages

The two manually triggered ARM64 workflows publish `.deb` files, SHA-256 checksums and build metadata as workflow artifacts.

| Workflow | Inputs | Package |
| --- | --- | --- |
| Vulkan ARM64 package | Full commit SHA from `expej-mesa` | `expej-vulkan`, a selectable Vulkan ICD |
| PowerVR ARM64 module packages | Published kernel headers and a pinned PowerVR backport | One `expej-powervr-*` package for each supported kernel release |

The Vulkan workflow uses the `EXPEJ_MESA_DEPLOY_KEY` Actions secret with read-only access to the Mesa repository. Its artifacts record both the selected Mesa commit and the packaging commit. The module workflow uses the kernel headers and PowerVR patch series without a Mesa checkout. The current module targets are `6.6.98-5-aw2511` and `6.6.98-6-aw2511`.

Use [the trial instructions](packaging/TESTING.md) to select the right kernel module and validate Vulkan on the target board. Packaging revisions follow the Debian version suffix. Driver build identifiers follow the source.
