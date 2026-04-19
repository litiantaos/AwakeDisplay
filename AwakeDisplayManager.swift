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
        descriptor.maxPixelsWide = 3840
        descriptor.maxPixelsHigh = 2160
        descriptor.sizeInMillimeters = CGSize(width: 600, height: 340)
        descriptor.productID = 0x0123
        descriptor.vendorID = 0x4567
        descriptor.serialNum = 0x0001
        descriptor.queue = DispatchQueue.global(qos: .userInteractive)
        
        self.displayDescriptor = descriptor
        self.virtualDisplay = CGVirtualDisplay(descriptor: descriptor)
        
        applyResolution(width: currentResolution.width, height: currentResolution.height)
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
        guard let mode = CGVirtualDisplayMode(width: width, height: height, refreshRate: 60.0) else { return }
        settings.modes = [mode]
        
        _ = display.apply(settings)
    }
}
