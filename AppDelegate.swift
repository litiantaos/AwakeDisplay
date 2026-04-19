import Cocoa
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var pipController: PiPWindowController?
    
    // Menu items
    var toggleItem: NSMenuItem!
    var pipItem: NSMenuItem!
    var autoStartItem: NSMenuItem!
    
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
        
        // 2. Resolution Options
        let resMenu = NSMenu()
        let item1080 = NSMenuItem(title: "1920 x 1080 (1080p)", action: #selector(set1080p), keyEquivalent: "")
        item1080.state = .on // Default
        let item2k = NSMenuItem(title: "2560 x 1440 (2K)", action: #selector(set2k), keyEquivalent: "")
        let item4k = NSMenuItem(title: "3840 x 2160 (4K)", action: #selector(set4k), keyEquivalent: "")
        
        resMenu.addItem(item1080)
        resMenu.addItem(item2k)
        resMenu.addItem(item4k)
        
        let resItem = NSMenuItem(title: "显示器分辨率", action: nil, keyEquivalent: "")
        resItem.submenu = resMenu
        menu.addItem(resItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 3. Picture in Picture (PiP)
        pipItem = NSMenuItem(title: "开启画中画", action: #selector(togglePiP), keyEquivalent: "")
        pipItem.isHidden = true // hidden initially because display is off
        menu.addItem(pipItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 4. Auto Start
        autoStartItem = NSMenuItem(title: "登录时打开", action: #selector(toggleAutoStart), keyEquivalent: "")
        if #available(macOS 13.0, *) {
            autoStartItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        } else {
            // Fallback for older macOS versions is omitted for brevity since we target macOS 14+
            autoStartItem.state = .off
        }
        menu.addItem(autoStartItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 5. Quit
        let quitItem = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "")
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc func toggleDisplay() {
        AwakeDisplayManager.shared.toggleDisplay()
        
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
        
        pipItem.isHidden = !isActive
        pipItem.isEnabled = isActive
        
        if !isActive {
            // Turn off PiP if display is closed
            pipController?.stopPiP()
            pipItem.title = "开启画中画"
        }
    }
    
    @objc func set1080p(_ sender: NSMenuItem) {
        updateResolution(width: 1920, height: 1080, sender: sender)
    }
    
    @objc func set2k(_ sender: NSMenuItem) {
        updateResolution(width: 2560, height: 1440, sender: sender)
    }
    
    @objc func set4k(_ sender: NSMenuItem) {
        updateResolution(width: 3840, height: 2160, sender: sender)
    }
    
    private func updateResolution(width: UInt32, height: UInt32, sender: NSMenuItem) {
        AwakeDisplayManager.shared.applyResolution(width: width, height: height)
        
        // Update menu states
        if let menu = sender.menu {
            for item in menu.items {
                item.state = .off
            }
        }
        sender.state = .on
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
}
