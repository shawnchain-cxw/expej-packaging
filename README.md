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

The default userspace workflow inputs select the same Mesa commit. Use `expej-gl-run eglinfo -B` to check the selected EGL renderer on a system with the PowerVR DRM driver loaded. For an existing OpenGL application, pass its command line to `expej-gl-run`.

Use [the trial instructions](packaging/TESTING.md) to select the right kernel module and validate Vulkan on the target board. Packaging revisions follow the Debian version suffix. Driver build identifiers follow the source.
