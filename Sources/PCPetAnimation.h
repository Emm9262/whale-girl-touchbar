#import <Cocoa/Cocoa.h>
NS_ASSUME_NONNULL_BEGIN
/// Native renderer for original PC2005-cloud/dsh-pet v0.3.8 animation clips.
/// Clips retain their complete duration; RGBA atlases are sampled at 12 fps.
@interface PCPetAnimation : NSObject
@property(nonatomic, readonly, copy) NSString *currentAction;
@property(nonatomic, readonly, copy) NSString *currentTitle;
@property(nonatomic, readonly) NSTimeInterval currentDuration;
@property(nonatomic, readonly) CGFloat currentAspectRatio;
@property(nonatomic, readonly) BOOL locomoting;
/// Uses the stable side-running part of the original clip while the actor actually moves.
- (void)setLocomoting:(BOOL)moving time:(NSTimeInterval)time;
+ (BOOL)available;
/// Entries contain id, title, category, duration and aspectRatio.
+ (NSArray<NSDictionary *> *)catalogue;
+ (NSDictionary *)assetSummary;
+ (NSDictionary *)runAssetTests;
/// Select without restarting a selection that is already playing. Unknown ids fail.
- (BOOL)setAction:(NSString *)action time:(NSTimeInterval)time;
/// Explicit user selection; keeps the full clip until complete unless a task interrupts.
- (BOOL)playAction:(NSString *)action time:(NSTimeInterval)time;
/// Releases only the explicit-selection hold; a following user action can replace it.
- (void)cancelManualPlayback;
/// Follows the existing scene states and uses weighted full-clip rotation when idle.
/// Pass the scene's visible clock, which freezes while the Touch Bar is hidden.
- (void)advanceAtTime:(NSTimeInterval)time state:(NSString *)state autonomous:(BOOL)autonomous;
/// Fits transparently inside rect, preserves aspect, and mirrors when facing < 0.
- (void)drawInRect:(NSRect)rect time:(NSTimeInterval)time facing:(CGFloat)facing;
@end
NS_ASSUME_NONNULL_END
