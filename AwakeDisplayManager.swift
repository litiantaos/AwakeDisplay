import Foundation
import CoreGraphics

class AwakeDisplayManager {
    static let shared = AwakeDisplayManager()
    
    private var virtualDisplay: CGVirtualDisplay?
    private var displayDescriptor: CGVirtualDisplayDescriptor?
    
    // Store current resolution to reapply if needed
    var currentResolution: (width: UInt32, height: UInt32) = (1920, 1080)
    
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
        descriptor.queue = DispatchQueue.global(qos: .userInteractive)
        
        self.displayDescriptor = descriptor
        
        guard let settings = CGVirtualDisplaySettings() else { return }
        settings.hiDPI = 1 // Enable HiDPI (Retina) mode
        if let mode = CGVirtualDisplayMode(width: 1920, height: 1080, refreshRate: 60.0) {
            settings.modes = [mode]
        }
        
        // Use applySettings directly if possible, or pass settings during init.
        // For CGVirtualDisplay, settings are usually applied after init.
        self.virtualDisplay = CGVirtualDisplay(descriptor: descriptor)
        
        // Wait a brief moment before applying settings to ensure display is fully registered
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, let display = self.virtualDisplay else { return }
            
            _ = display.apply(settings)
            
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
        settings.hiDPI = 1 // Enable HiDPI (Retina) mode
        if let mode = CGVirtualDisplayMode(width: width, height: height, refreshRate: 60.0) {
            settings.modes = [mode]
        }
        
        _ = display.apply(settings)
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
                // Set the virtual display to mirror the main display
                CGConfigureDisplayMirrorOfDisplay(cfg, id, mainDisplayID)
            } else {
                // Set the virtual display to be an extended display (stop mirroring)
                CGConfigureDisplayMirrorOfDisplay(cfg, id, kCGNullDirectDisplay)
                // Set its position to the right of the main display to avoid overlapping
                CGConfigureDisplayOrigin(cfg, id, Int32(CGDisplayPixelsWide(mainDisplayID)), 0)
            }
            CGCompleteDisplayConfiguration(cfg, CGConfigureOption.forSession)
        }
    }
}
