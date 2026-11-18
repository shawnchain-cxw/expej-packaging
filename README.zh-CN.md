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

在 [GitHub Releases](https://github.com/shawnchain-cxw/expej-packaging/releases) 按构建日期选版本，下载 `expej-a733-YYYY-MM-DD-<run>.<attempt>-arm64.zip`。每个 ZIP 包含同一 Mesa 提交构建的 Vulkan 和 OpenGL/GLES、两个内核版本的 PowerVR 模块，以及 SHA-256 校验值和构建信息。日期按构建产物打包时的 UTC 日期计算。

将 ZIP 解压到空目录，在该目录运行下面的命令。安装命令会选择与正在运行的内核匹配的 PowerVR 模块包。

```sh
sha256sum -c SHA256SUMS && sudo apt install \
  ./expej-powervr-"$(uname -r)"_*.deb \
  ./expej-vulkan_*.deb ./expej-opengl_*.deb vulkan-tools mesa-utils
```

内核模块包用 `depmod` 更新模块依赖索引。Vulkan 和 OpenGL/GLES 安装到各自的路径，试装时可以按应用选择驱动。

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

## 构建发行包

在 `main` 上手动运行 [A733 ARM64 release 工作流](https://github.com/shawnchain-cxw/expej-packaging/actions/workflows/a733-release.yml)，指定一个完整的 `expej-mesa` 提交 SHA。工作流通过 `EXPEJ_MESA_DEPLOY_KEY` 只读访问 Mesa 仓库，并行构建两个用户态驱动和两个内核模块，校验四个软件包后将一个 ZIP 发布到 Releases。文件名中的运行编号和重试次数用于区分同日构建。Debian 版本号的后缀记录打包修订号，驱动流水号按源码确定。
