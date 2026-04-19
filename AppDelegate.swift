import Cocoa
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var pipController: PiPWindowController?
    
    // Menu items
    var toggleItem: NSMenuItem!
    var pipItem: NSMenuItem!
    var autoStartItem: NSMenuItem!
    var mirrorModeItem: NSMenuItem!
    
    // SVG Icons
    private var lineIcon: NSImage?
    private var fillIcon: NSImage?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Setup status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Load custom SVG icons
        if let lineURL = Bundle.main.url(forResource: "bar-icon-line", withExtension: "svg") {
            lineIcon = NSImage(contentsOf: lineURL)
            lineIcon?.size = NSSize(width: 18, height: 18) // Scale down to fit standard menu bar size
            lineIcon?.isTemplate = true // Allows macOS to tint it for dark/light mode
        }
        if let fillURL = Bundle.main.url(forResource: "bar-icon-fill", withExtension: "svg") {
            fillIcon = NSImage(contentsOf: fillURL)
            fillIcon?.size = NSSize(width: 18, height: 18) // Scale down
            fillIcon?.isTemplate = true
        }
        
        if let button = statusItem.button {
            if let img = lineIcon {
                button.image = img
            } else if let image = NSImage(systemSymbolName: "display", accessibilityDescription: "AwakeDisplay") {
                // Ensure the icon works well in both Light and Dark modes
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "AD"
            }
        }
        
        setupMenu()
    }
    
    func setupMenu() {
        let menu = NSMenu()
        
        // 1. Toggle Display
        toggleItem = NSMenuItem(title: "开启虚拟显示器", action: #selector(toggleDisplay), keyEquivalent: "")
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 2. Display Mode (Mirror / Extended)
        mirrorModeItem = NSMenuItem(title: "切换为扩展", action: #selector(toggleMirrorMode), keyEquivalent: "")
        mirrorModeItem.isHidden = true
        menu.addItem(mirrorModeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 3. PiP View (Only visible in Extended Mode)
        pipItem = NSMenuItem(title: "开启画中画", action: #selector(togglePiP), keyEquivalent: "")
        pipItem.isHidden = true // hidden initially because display is off
        menu.addItem(pipItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 3. Auto Start
        autoStartItem = NSMenuItem(title: "登录时打开", action: #selector(toggleAutoStart), keyEquivalent: "")
        if #available(macOS 13.0, *) {
            autoStartItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
        menu.addItem(autoStartItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 4. Quit
        let quitItem = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "")
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        menu.delegate = self
        
        updateMenuState()
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc func toggleDisplay() {
        if AwakeDisplayManager.shared.isDisplayActive {
            AwakeDisplayManager.shared.destroyDisplay()
        } else {
            AwakeDisplayManager.shared.createDisplay()
        }
        
        // Give it extra time for the mirror mode toggle to settle on init
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.updateMenuState()
        }
    }
    

    @objc func togglePiP() {
        if pipController == nil {
            pipController = PiPWindowController()
            pipController?.onWindowClosed = { [weak self] in
                self?.pipItem.title = "开启画中画"
                // 彻底释放 PiP 控制器，确保下次点开能重新初始化录屏会话
                self?.pipController = nil
            }
        }
        
        if let pipWindow = pipController?.window, pipWindow.isVisible {
            pipController?.stopPiP()
            pipItem.title = "开启画中画"
            pipController = nil
        } else {
            if let displayID = AwakeDisplayManager.shared.activeDisplayID {
                pipController?.startPiP(for: displayID)
                pipItem.title = "关闭画中画"
            }
        }
    }
    
    @objc func toggleAutoStart() {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    autoStartItem.state = .off
                } else {
                    try SMAppService.mainApp.register()
                    autoStartItem.state = .on
                }
            } catch {
                print("Failed to toggle auto start: \(error.localizedDescription)")
            }
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Clean up
        pipController?.stopPiP()
        AwakeDisplayManager.shared.destroyDisplay()
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        updateMenuState()
    }
    
    private func updateMenuState() {
        let isActive = AwakeDisplayManager.shared.isDisplayActive
        
        toggleItem.title = isActive ? "关闭虚拟显示器" : "开启虚拟显示器"
        
        if isActive, let img = fillIcon {
            statusItem.button?.image = img
            statusItem.button?.title = ""
        } else if !isActive, let img = lineIcon {
            statusItem.button?.image = img
            statusItem.button?.title = ""
        } else if let image = NSImage(systemSymbolName: isActive ? "display.2" : "display", accessibilityDescription: "AwakeDisplay") {
            image.isTemplate = true
            statusItem.button?.image = image
            statusItem.button?.title = ""
        } else {
            statusItem.button?.title = isActive ? "AD(On)" : "AD"
        }
        
        let isMirroring = AwakeDisplayManager.shared.isMirroring
        
        // Update mirror mode toggle
        mirrorModeItem.isHidden = !isActive
        mirrorModeItem.isEnabled = isActive
        if isActive {
            mirrorModeItem.title = isMirroring ? "切换为扩展显示器" : "切换为镜像显示器"
        }
        
        // Hide PiP option if display is off or in mirroring mode
        pipItem.isHidden = !isActive || isMirroring
        pipItem.isEnabled = !pipItem.isHidden
        
        if !pipItem.isHidden {
            let isPiPActive = pipController != nil
            pipItem.title = isPiPActive ? "关闭画中画" : "开启画中画"
        } else {
            // Auto close PiP if we switched to mirror mode or turned off display
            pipController?.stopPiP()
            pipController = nil
            pipItem.title = "开启画中画"
        }
    }
    
    @objc func toggleMirrorMode() {
        let isMirroring = AwakeDisplayManager.shared.isMirroring
        AwakeDisplayManager.shared.setMirroring(!isMirroring)
        
        // Give the OS a moment to apply the display configuration before updating the menu
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateMenuState()
        }
    }
}
