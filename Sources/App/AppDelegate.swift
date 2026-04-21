import Cocoa
import ServiceManagement
import os.log

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var pipController: PiPWindowController?
    
    // 菜单项
    var toggleItem: NSMenuItem!
    var pipItem: NSMenuItem!
    var autoStartItem: NSMenuItem!
    var mirrorModeItem: NSMenuItem!
    var aboutItem: NSMenuItem!
    var updateItem: NSMenuItem!
    var languageItem: NSMenuItem!
    var quitItem: NSMenuItem!
    
    var zhItem: NSMenuItem!
    var enItem: NSMenuItem!
    
    private let aboutController = AboutWindowController()
    
    private var currentUpdateProgress: Int?
    private var readyToInstallVersion: String?
    
    // SVG 图标
    private var lineIcon: NSImage?
    private var fillIcon: NSImage?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 设置状态栏项
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // 加载自定义 SVG 图标
        if let lineURL = Bundle.main.url(forResource: "bar-icon-line", withExtension: "svg") {
            lineIcon = NSImage(contentsOf: lineURL)
            lineIcon?.size = NSSize(width: 18, height: 18) // 缩小以适应标准状态栏尺寸
            lineIcon?.isTemplate = true // 允许 macOS 在深色/浅色模式下自动调整颜色
        } else {
            os_log("未找到 bar-icon-line.svg 图标资源", type: .error)
        }
        
        if let fillURL = Bundle.main.url(forResource: "bar-icon-fill", withExtension: "svg") {
            fillIcon = NSImage(contentsOf: fillURL)
            fillIcon?.size = NSSize(width: 18, height: 18)
            fillIcon?.isTemplate = true
        } else {
            os_log("未找到 bar-icon-fill.svg 图标资源", type: .error)
        }
        
        if let button = statusItem.button {
            if let img = lineIcon {
                button.image = img
            } else if let image = NSImage(systemSymbolName: "display", accessibilityDescription: "AwakeDisplay") {
                // 确保图标在深色和浅色模式下都能正常显示
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "AD"
            }
        }
        
        setupMenu()
        setupUpdateObserver()
        UpdateCoordinator.shared.checkForUpdates()
        
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: NSNotification.Name("LanguageChanged"), object: nil)
    }
    
    func setupMenu() {
        let menu = NSMenu()
        
        // 1. 开启/关闭虚拟显示器
        toggleItem = NSMenuItem(title: "Turn On Virtual Display".localized, action: #selector(toggleDisplay), keyEquivalent: "")
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 2. 显示模式 (镜像 / 扩展)
        mirrorModeItem = NSMenuItem(title: "Switch to Extended Display".localized, action: #selector(toggleMirrorMode), keyEquivalent: "")
        mirrorModeItem.isHidden = true
        menu.addItem(mirrorModeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 3. 画中画视图 (仅在扩展模式下可见)
        pipItem = NSMenuItem(title: "Turn On PiP".localized, action: #selector(togglePiP), keyEquivalent: "")
        pipItem.isHidden = true // 初始隐藏，因为显示器未开启
        menu.addItem(pipItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 4. 开机自启动
        autoStartItem = NSMenuItem(title: "Open at Login".localized, action: #selector(toggleAutoStart), keyEquivalent: "")
        if #available(macOS 13.0, *) {
            autoStartItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
        menu.addItem(autoStartItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 5. 语言
        languageItem = NSMenuItem(title: "Language".localized, action: nil, keyEquivalent: "")
        let langMenu = NSMenu()
        zhItem = NSMenuItem(title: "中文", action: #selector(switchLanguage(_:)), keyEquivalent: "")
        zhItem.representedObject = "zh-Hans"
        enItem = NSMenuItem(title: "English", action: #selector(switchLanguage(_:)), keyEquivalent: "")
        enItem.representedObject = "en"
        langMenu.addItem(zhItem)
        langMenu.addItem(enItem)
        languageItem.submenu = langMenu
        menu.addItem(languageItem)
        updateLanguageMenuState()
        
        menu.addItem(NSMenuItem.separator())
        
        // 6. 更新（默认隐藏，只在检测到并下载时显示）
        updateItem = NSMenuItem(title: "Checking for Updates...".localized, action: nil, keyEquivalent: "")
        updateItem.isHidden = true
        menu.addItem(updateItem)
        
        // 7. 关于
        aboutItem = NSMenuItem(title: "About".localized, action: #selector(showAbout), keyEquivalent: "")
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 8. 退出
        quitItem = NSMenuItem(title: "Quit".localized, action: #selector(quitApp), keyEquivalent: "")
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        menu.delegate = self
        
        updateMenuState()
    }
    
    @objc func switchLanguage(_ sender: NSMenuItem) {
        if let langString = sender.representedObject as? String, let lang = Language(rawValue: langString) {
            LanguageManager.shared.currentLanguage = lang
        }
    }
    
    private func updateLanguageMenuState() {
        zhItem.state = LanguageManager.shared.currentLanguage == .zh ? .on : .off
        enItem.state = LanguageManager.shared.currentLanguage == .en ? .on : .off
    }

    @objc func languageChanged() {
        updateLanguageMenuState()
        autoStartItem.title = "Open at Login".localized
        aboutItem.title = "About".localized
        languageItem.title = "Language".localized
        quitItem.title = "Quit".localized
        
        if let progress = currentUpdateProgress {
            updateItem.title = String(format: "Downloading Update %d%%".localized, progress)
        } else if let version = readyToInstallVersion {
            updateItem.title = String(format: "Restart to Update %@".localized, version)
        } else if updateItem.action == nil {
            updateItem.title = "Checking for Updates...".localized
        } else {
            updateItem.title = "Update Download Failed".localized
        }
        
        updateMenuState()
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc func showAbout() {
        aboutController.show()
    }

    private func setupUpdateObserver() {
        UpdateCoordinator.shared.onUpdateStateChanged = { [weak self] state in
            guard let self = self else { return }
            
            switch state {
            case .checking:
                break
                
            case .downloading(let progress):
                self.currentUpdateProgress = progress
                self.updateItem.isHidden = false
                self.updateItem.title = String(format: "Downloading Update %d%%".localized, progress)
                self.updateItem.isEnabled = false
                
            case .readyToInstall(let version):
                self.currentUpdateProgress = nil
                self.readyToInstallVersion = version
                self.updateItem.isHidden = false
                self.updateItem.title = String(format: "Restart to Update %@".localized, version)
                self.updateItem.isEnabled = true
                self.updateItem.action = #selector(self.performInstall)
                self.updateItem.target = self
                
            case .error(let msg):
                self.currentUpdateProgress = nil
                self.readyToInstallVersion = nil
                os_log("自动更新发生错误: %{public}@", type: .error, msg)
                self.updateItem.isHidden = false
                self.updateItem.title = "Update Download Failed".localized
                self.updateItem.isEnabled = false
            }
        }
    }
    
    @objc func performInstall() {
        UpdateCoordinator.shared.installAndRestart()
    }
    
    @objc func toggleDisplay() {
        if AwakeDisplayManager.shared.isDisplayActive {
            AwakeDisplayManager.shared.destroyDisplay()
        } else {
            AwakeDisplayManager.shared.createDisplay()
        }
        
        // 给予额外时间让镜像模式切换完成再更新菜单
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.updateMenuState()
        }
    }
    

    @objc func togglePiP() {
        if pipController == nil {
            pipController = PiPWindowController()
            pipController?.onWindowClosed = { [weak self] in
                self?.pipItem.title = "Turn On PiP".localized
                // 彻底释放 PiP 控制器，确保下次点开能重新初始化录屏会话
                self?.pipController = nil
            }
        }
        
        if let pipWindow = pipController?.window, pipWindow.isVisible {
            pipController?.stopPiP()
            pipItem.title = "Turn On PiP".localized
            pipController = nil
        } else {
            if let displayID = AwakeDisplayManager.shared.activeDisplayID {
                let success = pipController?.startPiP(for: displayID) ?? false
                if success {
                    pipItem.title = "Turn Off PiP".localized
                } else {
                    pipItem.title = "Turn On PiP".localized
                    pipController = nil
                }
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
                os_log("切换自启动失败: %{public}@", type: .error, error.localizedDescription)
                
                let alert = NSAlert()
                alert.messageText = "Failed to toggle auto-start".localized
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // 清理资源
        pipController?.stopPiP()
        AwakeDisplayManager.shared.destroyDisplay()
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        updateMenuState()
    }
    
    private func updateMenuState() {
        let isActive = AwakeDisplayManager.shared.isDisplayActive
        
        toggleItem.title = isActive ? "Turn Off Virtual Display".localized : "Turn On Virtual Display".localized
        
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
        
        // 更新镜像模式开关
        mirrorModeItem.isHidden = !isActive
        mirrorModeItem.isEnabled = isActive
        if isActive {
            mirrorModeItem.title = isMirroring ? "Switch to Extended Display".localized : "Switch to Mirrored Display".localized
        }
        
        // 如果显示器关闭或处于镜像模式，隐藏画中画选项
        pipItem.isHidden = !isActive || isMirroring
        pipItem.isEnabled = !pipItem.isHidden
        
        if !pipItem.isHidden {
            let isPiPActive = pipController != nil
            pipItem.title = isPiPActive ? "Turn Off PiP".localized : "Turn On PiP".localized
        } else {
            // 如果切换到镜像模式或关闭了显示器，自动关闭画中画
            pipController?.stopPiP()
            pipController = nil
            pipItem.title = "Turn On PiP".localized
        }
    }
    
    @objc func toggleMirrorMode() {
        let isMirroring = AwakeDisplayManager.shared.isMirroring
        AwakeDisplayManager.shared.setMirroring(!isMirroring)
        
        // 给予系统片刻时间应用显示配置后再更新菜单
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateMenuState()
        }
    }
}
