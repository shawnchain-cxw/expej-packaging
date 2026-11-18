<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2026 Shawn Chain -->
# Expej Debian 软件包

[English](README.md)

## 在 A733 上安装

### 核对系统要求

使用 Debian 13 ARM64 系统，支持 `6.6.98-5-aw2511` 和 `6.6.98-6-aw2511` 两个内核版本。模块包依赖对应版本的 `linux-image` 包。先检查内核、架构和固件，再选模块包。

```sh
uname -r
dpkg --print-architecture
dpkg-query -W "linux-image-$(uname -r)"
ls /lib/firmware/powervr/rogue_36.56.104.183_v1.fw*
```

固件也可能以压缩文件提供。如果缺少该文件，先安装设备所需的配套固件，再加载 `powervr`。

### 下载并安装

从成功的构建中下载产物，分别解压到与产物同名的目录。Vulkan 和 OpenGL/GLES 请选择 `build-info.txt` 中 `Mesa commit` 相同的产物。GitHub 的构建产物保留 30 天。

| 工作流 | 产物 | 选择方式 |
| --- | --- | --- |
| [PowerVR 模块](https://github.com/shawnchain-cxw/expej-packaging/actions/workflows/powervr-deb.yml) | `expej-powervr-6.6.98-5-arm64` 或 `expej-powervr-6.6.98-6-arm64` | 按 `uname -r` 二选一。 |
| [Vulkan](https://github.com/shawnchain-cxw/expej-packaging/actions/workflows/vulkan-deb.yml) | `expej-vulkan-arm64` | 两个内核版本通用。 |
| [OpenGL 和 GLES](https://github.com/shawnchain-cxw/expej-packaging/actions/workflows/opengl-deb.yml) | `expej-opengl-arm64` | 两个内核版本通用。 |

在三个解压目录的上一级执行下面的命令。

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

内核模块包用 `depmod` 更新模块依赖索引。Vulkan 和 OpenGL/GLES 安装到各自的路径，试装时可以按应用选择驱动。

如果拿到的是合并后的 ZIP，解压后在 `.deb` 所在目录运行下面的命令。

```sh
sha256sum -c SHA256SUMS && sudo apt install \
  ./expej-powervr-"$(uname -r)"_*.deb \
  ./expej-vulkan_*.deb ./expej-opengl_*.deb vulkan-tools mesa-utils
```

### 重启并验证

安装后重启，检查 DRM 渲染节点的驱动。以普通用户运行 Vulkan 和 EGL 验证。

```sh
ls -l /sys/class/drm/renderD*/device/driver
```

```sh
PVR_I_WANT_A_BROKEN_VULKAN_DRIVER=1 \
  VK_DRIVER_FILES=/usr/share/expej/vulkan/icd.d/powervr_icd.aarch64.json \
  vulkaninfo --summary

expej-gl-run eglinfo -B
```

Vulkan 应枚举到 PowerVR GPU 并报告包里的驱动流水号。EGL 应报告 `Expej vNNNN`，其中 `NNNN` 是包里的 OpenGL/GLES 流水号。若检查失败，保留命令输出，并用 `sudo journalctl -k -b -n 100` 查看内核日志。

如需卸载，移除 Expej 软件包后重启。

```sh
sudo apt remove "expej-powervr-$(uname -r)" expej-vulkan expej-opengl
sudo reboot
```

## CI 构建

ARM64 工作流由手动触发，产物包含 `.deb`、SHA-256 校验值和构建信息。

| 工作流 | 输入 | 软件包 |
| --- | --- | --- |
| Vulkan ARM64 package | `expej-mesa` 的完整提交 SHA | `expej-vulkan`，按应用选择的 Vulkan ICD |
| OpenGL and GLES ARM64 package | 包含原生 PowerVR Gallium 构建目标的完整 Mesa 提交 SHA | `expej-opengl`，通过 `expej-gl-run` 选用 |
| PowerVR ARM64 module packages | 对应版本的内核 headers 和固定版本的 PowerVR 回移植源码 | 每个支持的内核发行号对应一个 `expej-powervr-*` 包 |

用户态工作流通过 `EXPEJ_MESA_DEPLOY_KEY` 只读访问 Mesa 仓库，产物记录所选 Mesa 提交和打包仓库提交。模块工作流使用内核 headers 和 PowerVR 补丁系列独立构建，当前目标为 `6.6.98-5-aw2511` 和 `6.6.98-6-aw2511`。

两条用户态工作流默认选择同一 Mesa 提交。Debian 版本号的后缀记录打包修订号，驱动流水号按源码确定。
