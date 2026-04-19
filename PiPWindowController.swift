import Cocoa
import AVFoundation

class PiPWindowController: NSWindowController, NSWindowDelegate {
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var trackingTimer: Timer?
    private var virtualDisplayID: CGDirectDisplayID?
    
    // 用于在标题栏右侧显示小绿点的视图
    private var activeIndicator: NSView?
    
    // Callback to notify AppDelegate when the window is closed by user
    var onWindowClosed: (() -> Void)?
    
    init() {
        let contentRect = NSRect(x: 100, y: 100, width: 480, height: 270)
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .resizable, .miniaturizable]
        
        let window = NSWindow(contentRect: contentRect,
                              styleMask: styleMask,
                              backing: .buffered,
                              defer: false)
        window.title = "AwakeDisplay"
        window.level = .floating // Keeps window always on top
        window.isOpaque = false
        window.backgroundColor = NSColor.black
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        super.init(window: window)
        window.delegate = self
        
        let contentView = NSView(frame: contentRect)
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
        
        // 尝试获取原生的标题栏视图并将指示器添加到它的右侧
        if let titlebarView = window.standardWindowButton(.closeButton)?.superview {
            titlebarView.addSubview(indicator)
            
            NSLayoutConstraint.activate([
                // 距离右边距 12 点，并垂直居中
                indicator.trailingAnchor.constraint(equalTo: titlebarView.trailingAnchor, constant: -12),
                indicator.centerYAnchor.constraint(equalTo: titlebarView.centerYAnchor),
                indicator.widthAnchor.constraint(equalToConstant: dotSize),
                indicator.heightAnchor.constraint(equalToConstant: dotSize)
            ])
        }
        
        self.activeIndicator = indicator
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func startPiP(for displayID: CGDirectDisplayID) {
        guard let window = self.window, let contentView = window.contentView else { return }
        
        stopPiP()
        
        let session = AVCaptureSession()
        session.sessionPreset = .high // Try to keep high quality
        
        guard let input = AVCaptureScreenInput(displayID: displayID) else {
            showPermissionAlert()
            return
        }
        
        input.capturesCursor = true
        input.capturesMouseClicks = true
        input.minFrameDuration = CMTimeMake(value: 1, timescale: 60) // 提升帧率到 60fps
        
        if session.canAddInput(input) {
            session.addInput(input)
        } else {
            showPermissionAlert()
            return
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
    }
    
    private func startMouseTracking() {
        trackingTimer?.invalidate()
        // 每隔 0.1 秒检查一次鼠标位置，判断是否进入虚拟显示器
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkMousePosition()
        }
    }
    
    private func checkMousePosition() {
        guard let vDisplayID = self.virtualDisplayID else { return }
        
        // NSEvent.mouseLocation 返回的是以左下角为原点的坐标系
        let mouseLocation = NSEvent.mouseLocation
        
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
                    self.window?.title = "AwakeDisplay"
                    self.activeIndicator?.isHidden = false // 显示右上角小绿点
                } else {
                    self.window?.title = "AwakeDisplay"
                    self.activeIndicator?.isHidden = true // 隐藏小绿点
                }
            }
        }
    }
    
    func stopPiP() {
        trackingTimer?.invalidate()
        trackingTimer = nil
        self.virtualDisplayID = nil
        
        if let session = captureSession {
            DispatchQueue.global(qos: .userInitiated).async {
                session.stopRunning()
            }
        }
        
        previewLayer?.removeFromSuperlayer()
        captureSession = nil
        previewLayer = nil
        self.window?.orderOut(nil)
    }
    
    private func showPermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "需要屏幕录制权限"
            alert.informativeText = "画中画功能需要捕获虚拟显示器的画面。请在「系统设置 -> 隐私与安全性 -> 屏幕录制」中为本应用（或 Terminal）授予权限后重试。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "好的")
            alert.runModal()
        }
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        // Stop the capture session completely when user clicks the red close button
        stopPiP()
        onWindowClosed?()
    }
}
