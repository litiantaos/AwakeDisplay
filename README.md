# AwakeDisplay

[English](#english) | [中文](#中文)

## 中文

**AwakeDisplay** 是一款专为 Apple Silicon (M1/M2/M3) MacBook 打造的极简状态栏（Menu Bar）应用。它通过创建一个虚拟的外接显示器，优雅地触发 macOS 原生的 Clamshell Mode（合盖不休眠模式），而无需任何物理外接显示器或电源。

### 核心功能

- **零硬件触发合盖模式**：利用系统未公开 API (`CGVirtualDisplay`) 模拟外接显示器连接。
- **画中画实时预览 (PiP)**：内置画中画悬浮窗，当鼠标移动至虚拟显示器区域时，会有优雅的绿点提示。
- **自定义分辨率**：支持一键切换 1080p, 2K, 4K 分辨率，适应不同场景的需求。
- **极简纯原生**：无冗余的 Xcode 工程文件或 Storyboard。全代码实现，构建仅依赖一个 Bash 脚本。
- **智能状态图标**：支持深/浅色模式无缝切换的状态栏 SVG 动态图标。

### 应用截图

<p align="center">
  <img src="assets/screenshots/1.png" width="100%" alt="AwakeDisplay Screenshot">
</p>

### 快速开始

#### 安装与运行

您可以直接从 GitHub Releases 下载预编译好的 App，或者自己从源码构建。

**方式一：直接下载 (推荐)**

1. 前往本仓库的 [Releases](https://github.com/litiantaos/AwakeDisplay/releases) 页面。
2. 下载最新的 `AwakeDisplay.zip`。
3. 解压后将 `AwakeDisplay.app` 拖入您的 `应用程序 (Applications)` 文件夹中，双击运行即可。

**方式二：源码构建**
不需要繁重的 Xcode，只需要在终端运行即可：

```bash
git clone https://github.com/litiantaos/AwakeDisplay.git
cd AwakeDisplay
sh build.sh
open AwakeDisplay.app
```

#### 注意事项

- **权限**: 画中画 (PiP) 功能需要屏幕录制权限，首次使用时请在「系统设置 -> 隐私与安全性 -> 屏幕录制」中授予。
- **单例限制**: 默认阻止多开运行。
- **镜像模式**: 如果首次开启虚拟显示器发现屏幕变成了镜像模式，请进入系统的「显示器」设置中，将其更改为「扩展显示器」。

### 技术细节

该项目完全通过原生的 `swiftc` 直接编译生成 `.app` 文件，展示了使用 Swift 调用 C/Objective-C API 和封装 App Bundle 的原生优雅方式。包含 `AVFoundation` 捕捉屏幕、`CoreGraphics` 操作虚拟屏幕的底层运用。

---

## English

**AwakeDisplay** is a minimalist Menu Bar application tailored for Apple Silicon (M1/M2/M3) MacBooks. It elegantly triggers macOS's native Clamshell Mode (closing the lid without sleeping) by creating a virtual external display, without the need for any physical external monitors.

### Features

- **Zero-Hardware Clamshell Mode**: Simulates an external display connection using the undocumented system API (`CGVirtualDisplay`).
- **Picture-in-Picture (PiP)**: Includes a floating PiP window to monitor the virtual screen, featuring a sleek green dot indicator when your cursor enters the virtual display.
- **Customizable Resolutions**: Switch easily between 1080p, 2K, and 4K presets to fit your workflow.
- **Pure Native & Minimalist**: No bloated Xcode project files or Storyboards. Pure code implementation, built with a single Bash script.
- **Smart Status Icons**: Dynamic SVG icons in the Menu Bar that seamlessly adapt to Light and Dark modes.

### Screenshots

<p align="center">
  <img src="assets/screenshots/1.png" width="100%" alt="AwakeDisplay Screenshot">
</p>

### Quick Start

#### Installation & Run

You can download the pre-compiled App directly from GitHub Releases, or build it yourself from source.

**Method 1: Direct Download (Recommended)**

1. Go to the [Releases](https://github.com/litiantaos/AwakeDisplay/releases) page of this repository.
2. Download the latest `AwakeDisplay.zip`.
3. Unzip and drag `AwakeDisplay.app` into your `Applications` folder, then double-click to run.

**Method 2: Build from Source**
No heavy Xcode required. Just use the terminal:

```bash
git clone https://github.com/litiantaos/AwakeDisplay.git
cd AwakeDisplay
sh build.sh
open AwakeDisplay.app
```

#### Important Notes

- **Permissions**: The Picture-in-Picture (PiP) feature requires Screen Recording permissions. Please grant it in `System Settings -> Privacy & Security -> Screen Recording` upon first use.
- **Singleton**: The app strictly prohibits multiple instances from running simultaneously.
- **Mirror Mode**: If you find your screen mirrored upon the first activation, please go to the system's "Displays" settings and change the virtual display to "Extended Display".

### Technical Details

This project demonstrates the elegant, pure-native way of compiling an `.app` bundle directly via `swiftc`. It showcases low-level usages of bridging Swift with C/Objective-C APIs, utilizing `AVFoundation` for screen capture and `CoreGraphics` for virtual display manipulation.

---

## License

MIT License. See [LICENSE](LICENSE) for details.
