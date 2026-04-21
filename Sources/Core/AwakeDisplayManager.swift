import Foundation
import CoreGraphics
import os.log

class AwakeDisplayManager {
    static let shared = AwakeDisplayManager()
    
    private var virtualDisplay: CGVirtualDisplay?
    private var displayDescriptor: CGVirtualDisplayDescriptor?
    
    // 保存当前分辨率以便需要时重新应用
    private(set) var currentResolution: (width: UInt32, height: UInt32) = (1920, 1080)
    
    var isDisplayActive: Bool {
        return virtualDisplay != nil
    }
    
    var activeDisplayID: CGDirectDisplayID? {
        return virtualDisplay?.displayID
    }
    
    func toggleDisplay() {
        if isDisplayActive {
            destroyDisplay()
        } else {
            createDisplay()
        }
    }
    
    func createDisplay() {
        guard virtualDisplay == nil else { return }
        
        guard let descriptor = CGVirtualDisplayDescriptor() else { return }
        descriptor.name = "AwakeDisplay"
        descriptor.maxPixelsWide = 1920
        descriptor.maxPixelsHigh = 1080
        descriptor.sizeInMillimeters = CGSize(width: 1600, height: 900)
        descriptor.productID = 0x0123
        descriptor.vendorID = 0x4567
        descriptor.serialNum = 0x0001
        // 注意：全局队列在某些高负载情况下可能会引起问题，此处维持原状以适配非公开 API 特性
        descriptor.queue = DispatchQueue.global(qos: .userInteractive)
        
        self.displayDescriptor = descriptor
        
        guard let settings = CGVirtualDisplaySettings() else { return }
        settings.hiDPI = 1 // 启用 HiDPI (Retina) 模式
        if let mode = CGVirtualDisplayMode(width: 1920, height: 1080, refreshRate: 60.0) {
            settings.modes = [mode]
        }
        
        // 直接创建虚拟显示器
        self.virtualDisplay = CGVirtualDisplay(descriptor: descriptor)
        
        // 等待片刻应用设置以确保显示器完全注册
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, let display = self.virtualDisplay else { return }
            
            let applySuccess = display.apply(settings)
            if !applySuccess {
                os_log("应用虚拟显示器设置失败", type: .error)
            }
            
            // 默认强制开启镜像模式
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.setMirroring(true)
            }
        }
    }
    
    func destroyDisplay() {
        self.virtualDisplay = nil
        self.displayDescriptor = nil
    }
    
    func applyResolution(width: UInt32, height: UInt32) {
        self.currentResolution = (width, height)
        
        guard let display = virtualDisplay else { return }
        
        guard let settings = CGVirtualDisplaySettings() else { return }
        settings.hiDPI = 1 // 启用 HiDPI (Retina) 模式
        if let mode = CGVirtualDisplayMode(width: width, height: height, refreshRate: 60.0) {
            settings.modes = [mode]
        }
        
        let applySuccess = display.apply(settings)
        if !applySuccess {
            os_log("应用分辨率设置失败", type: .error)
        }
    }
    
    var isMirroring: Bool {
        guard let id = activeDisplayID else { return false }
        let mirroredDisplay = CGDisplayMirrorsDisplay(id)
        return mirroredDisplay != kCGNullDirectDisplay
    }
    
    func setMirroring(_ shouldMirror: Bool) {
        guard let id = activeDisplayID else { return }
        let mainDisplayID = CGMainDisplayID()
        
        var config: CGDisplayConfigRef?
        let error = CGBeginDisplayConfiguration(&config)
        
        if error == .success, let cfg = config {
            if shouldMirror {
                // 将虚拟显示器设置为镜像主显示器
                let err = CGConfigureDisplayMirrorOfDisplay(cfg, id, mainDisplayID)
                if err != .success {
                    os_log("配置显示器镜像失败", type: .error)
                }
            } else {
                // 将虚拟显示器设置为扩展显示器（停止镜像）
                let err1 = CGConfigureDisplayMirrorOfDisplay(cfg, id, kCGNullDirectDisplay)
                // 将其位置设置在主显示器右侧以避免重叠
                let err2 = CGConfigureDisplayOrigin(cfg, id, Int32(CGDisplayPixelsWide(mainDisplayID)), 0)
                
                if err1 != .success || err2 != .success {
                    os_log("配置扩展显示器布局失败", type: .error)
                }
            }
            let completeError = CGCompleteDisplayConfiguration(cfg, CGConfigureOption.forSession)
            if completeError != .success {
                os_log("完成显示器配置失败", type: .error)
            }
        } else {
            os_log("开始显示器配置失败", type: .error)
        }
    }
}
