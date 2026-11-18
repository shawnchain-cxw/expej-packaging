<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2026 Shawn Chain -->
# Expej Debian packages

The manually triggered ARM64 workflows publish `.deb` files, SHA-256 checksums and build metadata as workflow artifacts.

| Workflow | Inputs | Package |
| --- | --- | --- |
| Vulkan ARM64 package | Full commit SHA from `expej-mesa` | `expej-vulkan`, a selectable Vulkan ICD |
| OpenGL and GLES ARM64 package | Full commit SHA with the native PowerVR Gallium build target | `expej-opengl`, selected per application with `expej-gl-run` |
| PowerVR ARM64 module packages | Published kernel headers and a pinned PowerVR backport | One `expej-powervr-*` package for each supported kernel release |

The userspace workflows use the `EXPEJ_MESA_DEPLOY_KEY` Actions secret with read-only access to the Mesa repository. Their artifacts record both the selected Mesa commit and the packaging commit. The module workflow uses the kernel headers and PowerVR patch series without a Mesa checkout. The current module targets are `6.6.98-5-aw2511` and `6.6.98-6-aw2511`.

The default OpenGL source checkpoint, `e5d00daf4e6`, still needs the native Gallium Meson entry and matching PowerVR compiler and command encoding sources. Its workflow currently reports a source configuration failure and has no package artifact. Once a complete source commit is available, select that commit in the workflow input.

Use [the trial instructions](packaging/TESTING.md) to select the right kernel module and validate Vulkan on the target board. Packaging revisions follow the Debian version suffix. Driver build identifiers follow the source.
