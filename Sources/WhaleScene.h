#import <Cocoa/Cocoa.h>
NS_ASSUME_NONNULL_BEGIN
/// Native Touch Bar adaptation of vlln/whale-girl (MIT, Sam Gao).
/// The bundled manifest and original sprite sheets remain unchanged.
@interface WhaleScene : NSView
@property(nonatomic) BOOL animating;
@property(nonatomic) BOOL autonomousEnabled;
@property(nonatomic) BOOL pc2005Enabled;
@property(nonatomic, readonly, copy) NSString *pcActionTitle;
@property(nonatomic, readonly) BOOL pcWalking;
- (void)prepareSideWalkPreviewFacing:(CGFloat)direction elapsed:(NSTimeInterval)elapsed;
- (BOOL)playPCAction:(NSString *)action;
+ (NSDictionary *)runPCIntegrationTests;
@property(nonatomic, readonly, copy) NSString *currentBehavior;
@property(nonatomic, readonly, copy) NSString *companionBehavior;
@property(nonatomic, readonly, copy) NSString *companionActivity;
@property(nonatomic, readonly, copy) NSString *needsSummary;
@property(nonatomic, readonly, copy) NSString *duoStory;
@property(nonatomic, readonly, copy) NSString *duoPhase;
@property(nonatomic) NSTimeInterval fixedTime;
@property(nonatomic, copy, nullable) NSString *forcedState;
@property(nonatomic, readonly, copy) NSString *currentState;
@property(nonatomic, readonly) BOOL menuOpen;
@property(nonatomic, copy, nullable) void (^interactionHandler)(NSString *action);
- (void)playAtX:(CGFloat)x;
- (void)performAction:(NSString *)action;
- (void)showReply:(NSString *)text;
- (void)applyBackendSnapshot:(NSDictionary *)snapshot;
+ (NSDictionary *)runBehaviorTests;
+ (NSDictionary *)runAutonomyTests;
+ (NSDictionary *)runWaterWorldTests;
+ (NSDictionary *)runCatFollowTests;
+ (NSDictionary *)runCatRoamingTests;
+ (NSDictionary *)runIdlePairTests;
+ (NSDictionary *)runStoryTests;
+ (NSDictionary *)runDuoStoryTests;
- (void)prepareDuoStoryPreview:(NSString *)story elapsed:(NSTimeInterval)elapsed;
- (void)prepareStoryPreview:(NSString *)story elapsed:(NSTimeInterval)elapsed;
@end
NS_ASSUME_NONNULL_END
