#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// A compact menu-bar companion panel. Every visible label is drawn directly.
@interface CompanionPanelView : NSView
/// current/detail/backend are text; autonomous/enabled/controlsVisible are booleans.
@property(nonatomic, copy) NSDictionary *state;
@property(nonatomic, copy, nullable) void (^actionHandler)(NSString *action);
+ (NSSize)preferredSize;
@property(nonatomic, readonly, copy) NSString *chatText;
- (void)clearChatText;
- (void)showActionLibrary:(BOOL)show;
/// Invokes the real native button, using the same target/action as a mouse click.
- (BOOL)activateAction:(NSString *)action;
/// Renders this NSView and its actual button subviews to a PNG at the requested scale.
- (BOOL)renderPNGAtPath:(NSString *)path scale:(CGFloat)scale;
+ (NSDictionary *)runInteractionTests;
@end

NS_ASSUME_NONNULL_END
