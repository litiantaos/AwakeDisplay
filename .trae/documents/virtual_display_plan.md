# VirtualDisplay App 实施计划

## 1. 目标与现状分析
- **目标**：为 MacBook M1 (macOS 14+) 开发一个「小而美」的菜单栏 (Status Bar) 应用，通过创建虚拟外接显示器来触发 macOS 的官方 Clamshell Mode（合盖不休眠）。
- **功能需求**：
  1. 纯菜单栏 App，点击图标展开菜单。
  2. 核心功能：开启/关闭虚拟显示器。
  3. 分辨率调节：提供 2-3 个预设分辨率选项。
  4. 画中画 (PiP) 模式：提供开关，可悬浮查看虚拟显示器画面。
- **现状**：目录 `/Users/litiantao/Code/VirtualDisplay` 为空。由于 macOS 没有公开的 API 用于直接创建虚拟显示器，业界（如 BetterDisplay 等）均采用 CoreGraphics 中的私有 API `CGVirtualDisplay`。我们将通过 Swift 桥接调用该 API，结合 AVFoundation 实现极简的画中画功能。

## 2. 方案与技术选型
- **构建方式**：通过原生的 `swiftc` 和 Shell 脚本直接构建 `.app` 包。避免复杂的 Xcode 工程文件，做到真正的「极简」和「优雅」。
- **虚拟显示器**：使用 `CGVirtualDisplay` 及相关私有类。通过 Objective-C Bridging Header 暴露给 Swift 使用。
- **画中画 (PiP)**：使用 `AVFoundation` 中的 `AVCaptureScreenInput` 捕获虚拟显示器的 `displayID`，并在无边框、可悬浮（Floating）的 `NSWindow` 中通过 `AVCaptureVideoPreviewLayer` 渲染。
- **UI 呈现**：纯代码实现 `NSMenu` 和 `NSStatusItem`，无冗余的 Storyboard/XIB。

## 3. 具体修改步骤 (Proposed Changes)

我们将创建以下文件：

1. **`build.sh`**
   - **作用**：编译 Swift 代码并打包成 macOS 规范的 `.app` 目录结构。
   - **细节**：创建 `VirtualDisplay.app/Contents/MacOS` 目录，生成包含屏幕录制权限（用于 PiP）的 `Info.plist`，调用 `swiftc` 编译代码。

2. **`Bridging-Header.h`**
   - **作用**：声明 `CGVirtualDisplay`、`CGVirtualDisplayDescriptor`、`CGVirtualDisplaySettings` 和 `CGVirtualDisplayMode` 的 Objective-C 接口，使 Swift 能类型安全地调用私有 API。

3. **`VirtualDisplayManager.swift`**
   - **作用**：封装虚拟显示器的生命周期管理。
   - **细节**：包含 `createDisplay()` 和 `destroyDisplay()` 方法，以及根据预设（如 1080p, 2K）切换分辨率的逻辑。

4. **`PiPWindowController.swift`**
   - **作用**：管理画中画悬浮窗。
   - **细节**：创建一个 `NSWindow`（无标题栏，置顶 `level = .floating`），通过 `AVCaptureSession` 和 `AVCaptureScreenInput` 读取虚拟显示器的画面实时输出。

5. **`AppDelegate.swift`**
   - **作用**：应用生命周期与菜单栏 UI 绑定。
   - **细节**：配置 `NSStatusItem`，绑定「开启/关闭」、「分辨率切换 (1920x1080, 2560x1440)」、「画中画开关」和「退出」等菜单事件。

6. **`main.swift`**
   - **作用**：App 入口点，实例化 `NSApplication` 并绑定 `AppDelegate`。

## 4. 假设与决策
- **系统限制**：`CGVirtualDisplay` 为私有 API，可能在未来的 macOS 升级中发生变化，但目前在 Apple Silicon (M1/M2/M3) 的 macOS 14/15 上依然可用且稳定。
- **权限要求**：画中画功能依赖 `AVCaptureScreenInput`，首次开启 PiP 时，macOS 会请求**屏幕录制权限**，需用户在系统设置中放行。
- **镜像问题**：若新建的虚拟显示器默认处于镜像模式，可能需要用户在系统「显示器」设置中手动调整为「扩展显示器」以达到最佳 Clamshell 效果。

## 5. 验证步骤
1. 执行 `sh build.sh` 生成 `VirtualDisplay.app`。
2. 运行 `VirtualDisplay.app`，检查状态栏是否出现图标。
3. 点击菜单「开启虚拟显示器」，前往「系统设置 -> 显示器」验证是否多出一个显示器。
4. 开启「画中画」模式，检查是否弹出悬浮窗（并授权屏幕录制）。
5. 在有电源连接的情况下，合上 MacBook 盖子，验证是否成功触发 Clamshell Mode 且不休眠。