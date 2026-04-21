#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

// 暴露内部的 CGDisplay API 用于显示器配置
// 这些 API 存在于 CoreGraphics 中，但如果在 Swift 中未完全暴露，我们需要在此声明
CGError CGBeginDisplayConfiguration(CGDisplayConfigRef _Nullable * _Nullable config);
CGError CGConfigureDisplayMirrorOfDisplay(CGDisplayConfigRef _Nullable config, CGDirectDisplayID display, CGDirectDisplayID master);
CGError CGConfigureDisplayOrigin(CGDisplayConfigRef _Nullable config, CGDirectDisplayID display, int32_t x, int32_t y);
CGError CGCompleteDisplayConfiguration(CGDisplayConfigRef _Nullable config, CGConfigureOption option);

@interface CGVirtualDisplayDescriptor : NSObject
@property (nonatomic, retain) dispatch_queue_t queue;
@property (nonatomic, retain) NSString *name;
@property (nonatomic) unsigned int maxPixelsWide;
@property (nonatomic) unsigned int maxPixelsHigh;
@property (nonatomic) CGSize sizeInMillimeters;
@property (nonatomic) unsigned int productID;
@property (nonatomic) unsigned int vendorID;
@property (nonatomic) unsigned int serialNum;
- (instancetype)init;
@end

@interface CGVirtualDisplayMode : NSObject
@property (nonatomic, readonly) unsigned int width;
@property (nonatomic, readonly) unsigned int height;
@property (nonatomic, readonly) double refreshRate;
- (instancetype)initWithWidth:(unsigned int)width height:(unsigned int)height refreshRate:(double)refreshRate;
@end

@interface CGVirtualDisplaySettings : NSObject
@property (nonatomic, retain) NSArray<CGVirtualDisplayMode *> *modes;
@property (nonatomic) unsigned int hiDPI;
- (instancetype)init;
@end

@interface CGVirtualDisplay : NSObject
@property (nonatomic, readonly) unsigned int displayID;
@property (nonatomic, readonly) NSArray<CGVirtualDisplayMode *> *modes;
- (instancetype)initWithDescriptor:(CGVirtualDisplayDescriptor *)descriptor;
- (BOOL)applySettings:(CGVirtualDisplaySettings *)settings;
@end
