import Cocoa
import AVFoundation
import os.log

class PiPWindowController: NSWindowController, NSWindowDelegate {
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var trackingEventMonitors: [Any] = []
    private var virtualDisplayID: CGDirectDisplayID?
    
    // 用于在标题栏右侧显示小绿点的视图
    private var activeIndicator: NSView?
    
    // 当用户关闭窗口时通知 AppDelegate 的回调
    var onWindowClosed: (() -> Void)?
    
    init() {
        let contentWidth: CGFloat = 480
        let contentHeight: CGFloat = 270
        
        // 尝试获取主屏幕的右上角位置
        var xPos: CGFloat = 100
        var yPos: CGFloat = 100
        
        if let mainScreen = NSScreen.main {
            // 右上角，减去一些 padding (例如 20)，再减去窗口自身宽高
            xPos = mainScreen.visibleFrame.maxX - contentWidth - 20
            yPos = mainScreen.visibleFrame.maxY - contentHeight - 20
        }
        
        let contentRect = NSRect(x: xPos, y: yPos, width: contentWidth, height: contentHeight)
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .resizable, .miniaturizable]
        
        let window = NSWindow(contentRect: contentRect,
                              styleMask: styleMask,
                              backing: .buffered,
                              defer: false)
        window.title = "AwakeDisplay"
        window.level = .floating // 保持窗口总在最前
        window.isOpaque = false
        window.backgroundColor = NSColor.black
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        super.init(window: window)
        window.delegate = self
        
        // 修复 contentView 的 frame 起点问题，不应使用 contentRect (它是屏幕坐标)
        let boundsRect = NSRect(origin: .zero, size: contentRect.size)
        let contentView = NSView(frame: boundsRect)
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.black.cgColor
        window.contentView = contentView
        
        setupTitlebarIndicator(in: window)
    }
    
    private func setupTitlebarIndicator(in window: NSWindow) {
        // 创建一个小的圆形视图作为绿点指示器
        let dotSize: CGFloat = 8.0
        let indicator = NSView(frame: NSRect(x: 0, y: 0, width: dotSize, height: dotSize))
        indicator.wantsLayer = true
        indicator.layer?.backgroundColor = NSColor.systemGreen.cgColor
        indicator.layer?.cornerRadius = dotSize / 2.0 // 设置为完美的圆形
        indicator.isHidden = true // 默认隐藏
        indicator.translatesAutoresizingMaskIntoConstraints = false
        
        // 创建一个容器视图以承载绿点，并提供一些内边距
        let containerWidth: CGFloat = 24.0
        let containerHeight: CGFloat = 24.0
        let container = NSView(frame: NSRect(x: 0, y: 0, width: containerWidth, height: containerHeight))
        container.addSubview(indicator)
        
        NSLayoutConstraint.activate([
            indicator.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            indicator.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            indicator.widthAnchor.constraint(equalToConstant: dotSize),
            indicator.heightAnchor.constraint(equalToConstant: dotSize)
        ])
        
        // 使用系统推荐的 NSTitlebarAccessoryViewController 将其添加到标题栏
        let accessoryVC = NSTitlebarAccessoryViewController()
        accessoryVC.view = container
        accessoryVC.layoutAttribute = .right // 靠标题栏右侧显示
        window.addTitlebarAccessoryViewController(accessoryVC)
        
        self.activeIndicator = indicator
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        return nil
    }
    
    func startPiP(for displayID: CGDirectDisplayID) -> Bool {
        guard let window = self.window, let contentView = window.contentView else { return false }
        
        stopPiP()
        
        // 如果系统当前正在将此虚拟显示器设为镜像模式，则拒绝开启画中画
        // 避免 macOS 底层因为捕获被镜像的虚拟显示器而导致黑屏甚至死机
        let mirroredDisplay = CGDisplayMirrorsDisplay(displayID)
        let isMirroring = (mirroredDisplay != kCGNullDirectDisplay)
        
        if isMirroring {
            os_log("系统当前为镜像模式，拒绝开启画中画以防止系统挂起", type: .info)
            return false
        }
        
        let session = AVCaptureSession()
        
        // 扩展模式，保持高质量
        session.sessionPreset = .high
        
        guard let input = AVCaptureScreenInput(displayID: displayID) else {
            showPermissionAlert(reason: "Unable to create screen capture input. Please ensure screen recording permissions are granted in System Settings.".localized)
            return false
        }
        
        input.capturesCursor = true
        input.capturesMouseClicks = true
        input.minFrameDuration = CMTimeMake(value: 1, timescale: 60)
        
        if session.canAddInput(input) {
            session.addInput(input)
        } else {
            showPermissionAlert(reason: "Unable to add screen capture to the session.".localized)
            return false
        }
        
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = contentView.bounds
        preview.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        preview.videoGravity = .resizeAspect
        
        contentView.layer?.addSublayer(preview)
        self.previewLayer = preview
        self.captureSession = session
        
        // 提升 CALayer 渲染性能，禁用多余的镜像等可能带来的开销
        if let connection = preview.connection {
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }
        
        // 允许视频帧异步调度和刷新，降低主线程延迟
        DispatchQueue.global(qos: .userInteractive).async {
            session.startRunning()
        }
        
        window.makeKeyAndOrderFront(nil)
        
        self.virtualDisplayID = displayID
        startMouseTracking()
        return true
    }
    
    private func startMouseTracking() {
        stopMouseTracking()
        
        // 确保窗口能接收 local 的 mouseMoved 事件
        self.window?.acceptsMouseMovedEvents = true
        
        let handler: (NSEvent) -> Void = { [weak self] _ in
            self?.checkMousePosition(mouseLocation: NSEvent.mouseLocation)
        }
        
        // 使用全局鼠标事件监听器（当应用不在前台时触发）
        if let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged], handler: handler) {
            trackingEventMonitors.append(globalMonitor)
        }
        
        // 使用本地鼠标事件监听器（当应用在前台且如改变窗口大小时触发）
        if let localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged], handler: { event in
            handler(event)
            return event
        }) {
            trackingEventMonitors.append(localMonitor)
        }
        
        // 初始检查一次
        checkMousePosition(mouseLocation: NSEvent.mouseLocation)
    }
    
    private func stopMouseTracking() {
        for monitor in trackingEventMonitors {
            NSEvent.removeMonitor(monitor)
        }
        trackingEventMonitors.removeAll()
    }
    
    private func checkMousePosition(mouseLocation: NSPoint) {
        guard let vDisplayID = self.virtualDisplayID else { return }
        
        // 获取主屏幕（NSScreen.screens.first 始终是包含原点的屏幕）
        guard let mainScreen = NSScreen.screens.first else { return }
        
        // 将 NSEvent 的底部原点坐标转换为 CoreGraphics 的顶部原点坐标
        let point = CGPoint(x: mouseLocation.x, y: mainScreen.frame.height - mouseLocation.y)
        
        var displayCount: UInt32 = 0
        var displays = [CGDirectDisplayID](repeating: 0, count: 10)
        
        let error = CGGetDisplaysWithPoint(point, 10, &displays, &displayCount)
        if error == .success, displayCount > 0 {
            // 检查包含该点的显示器数组中，是否包含我们的虚拟显示器 ID
            let isMouseInVirtualDisplay = displays.prefix(Int(displayCount)).contains(vDisplayID)
            
            DispatchQueue.main.async {
                if isMouseInVirtualDisplay {
                    self.activeIndicator?.isHidden = false // 显示右上角小绿点
                } else {
                    self.activeIndicator?.isHidden = true // 隐藏小绿点
                }
            }
        }
    }
    
    func stopPiP() {
        stopMouseTracking()
        self.virtualDisplayID = nil
        
        let sessionToStop = captureSession
        let layerToRemove = previewLayer
        
        captureSession = nil
        previewLayer = nil
        
        if let session = sessionToStop {
            DispatchQueue.global(qos: .userInitiated).async {
                session.stopRunning()
                DispatchQueue.main.async {
                    layerToRemove?.removeFromSuperlayer()
                }
            }
        }
        
        self.window?.orderOut(nil)
    }
    
    private func showPermissionAlert(reason: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Screen Recording Permission".localized
            alert.informativeText = reason
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK".localized)
            alert.runModal()
        }
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        // 当用户点击红色关闭按钮时，彻底停止捕获会话
        stopPiP()
        onWindowClosed?()
    }
}
