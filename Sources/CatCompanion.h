#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// A transparent hand-drawn calico companion with one pixel scale and baseline across 12 frames.
@interface CatCompanion : NSObject
+ (BOOL)isAvailable;
+ (NSDictionary *)assetSummary;
+ (NSDictionary *)runAssetTests;
/// Positive facing moves right; negative facing moves left. Time is in seconds.
+ (void)drawInRect:(NSRect)rect
            facing:(NSInteger)facing
            moving:(BOOL)moving
           running:(BOOL)running
              time:(NSTimeInterval)time;
@end

NS_ASSUME_NONNULL_END
