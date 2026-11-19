<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2026 Shawn Chain -->
# Expej Debian 软件包

[English](README.md)

## 在 A733 上安装

软件包要求兼容 Debian 13 的 ARM64 系统、A733 GPU 固件，以及匹配的软件包内核版本。当前发行包包含 `6.6.98-5-aw2511` 和 `6.6.98-6-aw2511` 的模块。

从 [GitHub Releases](https://github.com/shawnchain-cxw/expej-packaging/releases) 下载对应日期的 ARM64 ZIP，解压到空目录，在该目录执行下面的命令。命令会选中与当前内核匹配的模块，并一并安装 Vulkan 和 OpenGL/GLES 驱动。

```sh
sudo apt install \
  ./expej-powervr-"$(uname -r)"_*.deb \
  ./expej-vulkan_*.deb ./expej-opengl_*.deb && sudo reboot
```

Vulkan 应用通过系统加载器自动发现 Expej。需要按应用选用包内的 OpenGL/GLES 驱动时，可用 `expej-gl-run` 启动。

<details>
<summary>可选验证和卸载</summary>

在解压目录运行 `sha256sum -c SHA256SUMS` 可核对下载内容。重启后可检查 DRM 渲染节点绑定的驱动，并安装验证工具。

```sh
ls -l /sys/class/drm/renderD*/device/driver
sudo apt install vulkan-tools mesa-utils
```

应有一个 DRM 渲染节点绑定到 `powervr`。用普通用户执行下面的命令，确认 PowerVR 的 Vulkan `driverInfo` 带有 Expej 版本号，EGL 显示 `Expej vNNNN`。

```sh
vulkaninfo --summary

expej-gl-run eglinfo -B -p surfaceless
```

验证失败时可用 `sudo journalctl -k -b -n 100` 查看内核日志。如需卸载，移除 Expej 软件包后重启。

```sh
sudo apt remove "expej-powervr-$(uname -r)" expej-vulkan expej-opengl && sudo reboot
```

</details>

## 构建发行包

在 `main` 上手动运行 [A733 ARM64 release 工作流](https://github.com/shawnchain-cxw/expej-packaging/actions/workflows/a733-release.yml)，指定一个完整的 `expej-mesa` 提交 SHA。工作流通过 `EXPEJ_MESA_DEPLOY_KEY` 只读访问 Mesa 仓库，并行构建两个用户态驱动和两个内核模块，校验四个软件包后将一个 ZIP 发布到 Releases。文件名中的运行编号和重试次数用于区分同日构建。Debian 版本号的后缀记录打包修订号，驱动流水号按源码确定。
