#import <Cocoa/Cocoa.h>
#import "WhaleScene.h"

NS_ASSUME_NONNULL_BEGIN

/// Full-width Touch Bar content with a separate native system-controls button.
@interface PetBarContainer : NSView
@property(nonatomic, strong, readonly) WhaleScene *scene;
@property(nonatomic, copy, nullable) void (^systemControlsHandler)(void);
- (instancetype)initWithFrame:(NSRect)frame scene:(WhaleScene *)scene;
/// Offline preview uses the same scene frame and circle image as the live view.
- (void)drawPreviewInCurrentContext;
+ (NSDictionary *)runLayoutTests;
@end

NS_ASSUME_NONNULL_END
