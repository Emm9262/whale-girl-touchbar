#import "PCPetAnimation.h"
#import <math.h>

static NSDictionary *PCManifest(void) {
    static NSDictionary *manifest;static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURL *url=[NSBundle.mainBundle URLForResource:@"manifest" withExtension:@"json" subdirectory:@"pc2005-assets"];
        NSData *data=url?[NSData dataWithContentsOfURL:url]:nil;
        id value=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
        manifest=[value isKindOfClass:NSDictionary.class]?value:@{};
    });return manifest;
}
static NSDictionary *PCDefinitions(void) {
    static NSDictionary *definitions;static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableDictionary *result=[NSMutableDictionary new];
        id entries=PCManifest()[@"actions"];
        if([entries isKindOfClass:NSArray.class]) for(id value in entries) {
            if(![value isKindOfClass:NSDictionary.class])continue;
            NSDictionary *entry=value;
            NSString *identifier=entry[@"id"],*file=entry[@"file"];
            if(![identifier isKindOfClass:NSString.class]||![file isKindOfClass:NSString.class]||!identifier.length||
               ![file.lastPathComponent isEqualToString:file]||[entry[@"frames"] integerValue]<1||
               [entry[@"columns"] integerValue]<1||[entry[@"frameWidth"] integerValue]<1||
               [entry[@"frameHeight"] integerValue]<1||[entry[@"fps"] doubleValue]<=0)continue;
            result[identifier]=entry;
        }
        definitions=[result copy];
    });return definitions;
}
static NSArray<NSImage *> *PCFrames(NSString *identifier) {
    static NSCache<NSString *,NSArray<NSImage *> *> *cache;static dispatch_once_t once;
    dispatch_once(&once, ^{cache=[NSCache new];cache.countLimit=4;cache.totalCostLimit=24*1024*1024;});
    NSArray *cached=[cache objectForKey:identifier];if(cached)return cached;
    NSDictionary *entry=PCDefinitions()[identifier];if(!entry)return @[];
    NSURL *folder=[NSBundle.mainBundle URLForResource:@"pc2005-assets" withExtension:nil];
    NSImage *atlas=folder?[[NSImage alloc] initWithContentsOfURL:[folder URLByAppendingPathComponent:entry[@"file"]]]:nil;
    CGImageRef source=atlas?[atlas CGImageForProposedRect:NULL context:nil hints:nil]:NULL;
    if(!source)return @[];
    NSUInteger width=[entry[@"frameWidth"] unsignedIntegerValue],height=[entry[@"frameHeight"] unsignedIntegerValue];
    NSUInteger columns=[entry[@"columns"] unsignedIntegerValue],count=[entry[@"frames"] unsignedIntegerValue];
    if(width*columns!=CGImageGetWidth(source)||height*((count+columns-1)/columns)!=CGImageGetHeight(source))return @[];
    NSMutableArray *frames=[NSMutableArray arrayWithCapacity:count];
    for(NSUInteger i=0;i<count;i++) {
        CGImageRef image=CGImageCreateWithImageInRect(source,CGRectMake((i%columns)*width,(i/columns)*height,width,height));
        if(!image)return @[];
        NSImage *frame=[[NSImage alloc] initWithCGImage:image size:NSMakeSize(width,height)];
        CGImageRelease(image);[frames addObject:frame];
    }
    NSArray *result=[frames copy];[cache setObject:result forKey:identifier cost:width*height*count*4];return result;
}
static BOOL PCFrameHasContent(NSImage *image) {
    CGImageRef source=[image CGImageForProposedRect:NULL context:nil hints:nil];if(!source)return NO;
    size_t width=CGImageGetWidth(source),height=CGImageGetHeight(source);
    NSMutableData *pixels=[NSMutableData dataWithLength:width*height*4];
    CGColorSpaceRef colorSpace=CGColorSpaceCreateDeviceRGB();
    CGContextRef context=CGBitmapContextCreate(pixels.mutableBytes,width,height,8,width*4,colorSpace,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);if(!context)return NO;
    CGContextDrawImage(context,CGRectMake(0,0,width,height),source);CGContextRelease(context);
    const unsigned char *bytes=pixels.bytes;BOOL visible=NO,transparent=NO;
    for(size_t i=0;i<width*height;i++){visible|=bytes[i*4+3]>32;transparent|=bytes[i*4+3]==0;}
    return visible&&transparent;
}
// Every atlas retains its source coordinates. Props and particles must not
// change the character's world scale, horizontal pivot or standing baseline.
static const CGFloat PCWorldScale=25.5/266.5;
static NSRect PCSourceDrawingRect(NSDictionary *entry,NSPoint foot) {
    NSArray *crop=[entry[@"sourceCrop"] isKindOfClass:NSArray.class]?entry[@"sourceCrop"]:nil;
    if(crop.count!=4)return NSZeroRect;
    CGFloat left=[crop[0] doubleValue],top=[crop[1] doubleValue],right=[crop[2] doubleValue],bottom=[crop[3] doubleValue];
    return NSMakeRect(foot.x+(left-320)*PCWorldScale,foot.y+(331-bottom)*PCWorldScale,(right-left)*PCWorldScale,(bottom-top)*PCWorldScale);
}
static NSArray<NSString *> *PCActionsForState(NSString *state) {
    static NSDictionary *mapping;static dispatch_once_t once;
    dispatch_once(&once, ^{mapping=@{
        @"idle":@[@"idle"],@"walk":@[@"walk"],@"run":@[@"walk"],@"drag":@[@"drag"],
        @"think":@[@"think"],@"thinking":@[@"think"],@"working":@[@"work"],@"work":@[@"work"],
        @"wait":@[@"wait"],@"waiting":@[@"wait"],@"review":@[@"review"],@"result":@[@"review"],
        @"celebrate":@[@"celebrate"],@"success":@[@"celebrate"],@"error":@[@"error"],
        @"eat":@[@"snack",@"rice",@"hotpot",@"icecream"],@"feed":@[@"snack",@"rice",@"hotpot",@"icecream"],
        @"play":@[@"cube",@"pet-cat",@"juggle",@"bubbles"],@"dance":@[@"dance",@"cute-dance",@"sway-dance"],
        @"sleep":@[@"sleep"],@"nap":@[@"sleep"],@"wake":@[@"stretch"],@"welcome":@[@"wave"],
        @"joy":@[@"wave",@"tickle"],@"pet":@[@"tickle"],@"cuddle":@[@"tickle"],
        @"disappointed":@[@"angry"],@"whisper":@[@"whisper"]
    };});return mapping[state]?:@[@"idle"];
}
static BOOL PCPriorityState(NSString *state) {
    return [@[@"drag",@"think",@"thinking",@"working",@"work",@"wait",@"waiting",@"review",@"result",@"celebrate",@"success",@"error"] containsObject:state];
}
@interface PCPetAnimation ()
@property(nonatomic, readwrite, copy) NSString *currentAction;
@property(nonatomic, readwrite) BOOL locomoting;
@property(nonatomic) NSTimeInterval locomotionBegan;
@property(nonatomic) NSTimeInterval actionBegan;
@property(nonatomic) NSTimeInterval manualUntil;
@property(nonatomic) NSTimeInterval lastTime;
@property(nonatomic, copy) NSString *lastSceneState;
@property(nonatomic) BOOL lastAutonomous;
@end
@implementation PCPetAnimation
+ (BOOL)available {
    NSDictionary *definitions=PCDefinitions();if(definitions.count<12)return NO;
    NSURL *folder=[NSBundle.mainBundle URLForResource:@"pc2005-assets" withExtension:nil];
    if(!folder)return NO;
    for(NSDictionary *entry in definitions.allValues) {
        if(![NSFileManager.defaultManager fileExistsAtPath:[[folder URLByAppendingPathComponent:entry[@"file"]] path]])return NO;
    }return YES;
}
+ (NSArray<NSDictionary *> *)catalogue {
    id actions=PCManifest()[@"actions"];return [actions isKindOfClass:NSArray.class]?actions:@[];
}
+ (NSDictionary *)assetSummary {
    NSUInteger frames=0;double duration=0;
    for(NSDictionary *entry in self.catalogue){frames+=[entry[@"frames"] unsignedIntegerValue];duration+=[entry[@"duration"] doubleValue];}
    return @{@"available":@(self.available),@"actionCount":@(self.catalogue.count),@"totalFrames":@(frames),
             @"totalClipSeconds":@(duration),@"fps":PCManifest()[@"fps"]?:@0,@"fullClips":PCManifest()[@"fullClips"]?:@NO,
             @"upstream":PCManifest()[@"upstream"]?:@"",@"tag":PCManifest()[@"tag"]?:@"",@"commit":PCManifest()[@"commit"]?:@""};
}
- (instancetype)init {
    if((self=[super init])){_currentAction=@"idle";_lastSceneState=@"";_lastTime=-1;_actionBegan=-1;}
    return self;
}
- (NSString *)currentTitle {return self.locomoting?@"侧身走路":(PCDefinitions()[self.currentAction][@"title"]?:self.currentAction);}
- (NSTimeInterval)currentDuration {return MAX(.1,[PCDefinitions()[self.currentAction][@"duration"] doubleValue]);}
- (CGFloat)currentAspectRatio {return MAX(.1,[PCDefinitions()[self.locomoting?@"walk":self.currentAction][@"aspectRatio"] doubleValue]);}
- (BOOL)setAction:(NSString *)action time:(NSTimeInterval)time {
    if(!PCDefinitions()[action]||!isfinite(time))return NO;
    if([self.currentAction isEqualToString:action]&&self.actionBegan>=0)return YES;
    self.currentAction=action;self.actionBegan=time;return YES;
}
- (BOOL)playAction:(NSString *)action time:(NSTimeInterval)time {
    if(!PCDefinitions()[action]||!isfinite(time))return NO;
    [self setLocomoting:NO time:time];self.currentAction=action;self.actionBegan=time;self.manualUntil=time+self.currentDuration;return YES;
}
- (NSString *)chooseFrom:(NSArray<NSString *> *)candidates {
    if(!candidates.count)return @"idle";
    NSMutableArray *other=[NSMutableArray new];
    for(NSString *candidate in candidates)if(PCDefinitions()[candidate]&&![candidate isEqualToString:self.currentAction])[other addObject:candidate];
    if(!other.count)return candidates.firstObject;
    return other[arc4random_uniform((uint32_t)other.count)];
}
- (NSString *)chooseIdleAction {
    NSMutableArray *pool=[NSMutableArray new];
    for(NSDictionary *entry in PCPetAnimation.catalogue) {
        NSUInteger weight=[entry[@"weight"] unsignedIntegerValue];
        if([entry[@"id"] isEqualToString:self.currentAction])continue;
        for(NSUInteger i=0;i<MIN(weight,20);i++)[pool addObject:entry[@"id"]];
    }
    return [self chooseFrom:pool];
}
- (void)setLocomoting:(BOOL)moving time:(NSTimeInterval)time {
    if(!isfinite(time)||self.locomoting==moving)return;
    if(moving){self.locomotionBegan=time;}
    else {
        NSTimeInterval paused=MAX(0,time-self.locomotionBegan);
        if(self.actionBegan>=0)self.actionBegan+=paused;
        if(self.manualUntil>0)self.manualUntil+=paused;
    }
    self.locomoting=moving;
}
- (void)cancelManualPlayback { self.manualUntil=0; }
- (void)advanceAtTime:(NSTimeInterval)time state:(NSString *)state autonomous:(BOOL)autonomous {
    if(!isfinite(time))return;
    if(self.locomoting){if(PCPriorityState(state))[self setLocomoting:NO time:time];else return;}
    BOOL initial=self.lastTime<0||!self.lastSceneState.length;
    BOOL reset=self.lastTime>=0&&time<self.lastTime;
    if(reset){self.actionBegan=time;self.manualUntil=0;self.lastSceneState=@"";}
    self.lastTime=time;
    if(self.actionBegan<0)self.actionBegan=time;
    BOOL incomingPriority=PCPriorityState(state),leavingPriority=PCPriorityState(self.lastSceneState)&&!incomingPriority;
    BOOL stoppedAutonomy=self.lastAutonomous&&!autonomous;
    BOOL changed=![self.lastSceneState isEqualToString:state]||self.lastAutonomous!=autonomous;
    BOOL elapsed=time-self.actionBegan>=self.currentDuration;
    self.lastAutonomous=autonomous;
    if(stoppedAutonomy&&!incomingPriority) {
        self.manualUntil=0;[self setAction:@"idle" time:time];self.actionBegan=time;self.lastSceneState=state;
        return;
    }
    if(self.manualUntil>time&&!incomingPriority)return;
    BOOL priorityInterruptedManual=self.manualUntil>time&&incomingPriority;
    self.manualUntil=0;
    // Ordinary autonomous scene phases can be only a few seconds long. Let the
    // original clip finish, while task entry/exit and explicit selections remain immediate.
    if(changed&&!elapsed&&!initial&&!reset&&!incomingPriority&&!leavingPriority)return;
    if(changed||elapsed||priorityInterruptedManual) {
        NSString *next=([state isEqualToString:@"idle"]&&autonomous)?[self chooseIdleAction]:[self chooseFrom:PCActionsForState(state)];
        if(!changed&&[next isEqualToString:self.currentAction])self.actionBegan=time;
        else {[self setAction:next time:time];if(changed||priorityInterruptedManual)self.actionBegan=time;}
        self.lastSceneState=state;
    }
}
- (void)drawInRect:(NSRect)rect time:(NSTimeInterval)time facing:(CGFloat)facing {
    if(!isfinite(time)||NSIsEmptyRect(rect))return;
    NSArray<NSImage *> *frames=PCFrames(self.locomoting?@"walk":self.currentAction);if(!frames.count)return;
    double elapsed=MAX(0,time-MAX(0,self.actionBegan));
    double fps=[PCDefinitions()[self.currentAction][@"fps"] doubleValue];
    NSUInteger frame=(NSUInteger)floor(fmod(elapsed,self.currentDuration)*fps)%frames.count;
    if(self.locomoting){
        // Frames 24..47 are the two-second, left-facing side-run cycle. The
        // full original clip remains available in the action library unchanged.
        frame=24+((NSUInteger)floor(MAX(0,time-self.locomotionBegan)*12)%24);
        frame=MIN(frame,frames.count-1);
    }
    NSImage *image=frames[frame];
    NSDictionary *entry=PCDefinitions()[self.locomoting?@"walk":self.currentAction];
    NSRect target=PCSourceDrawingRect(entry,NSMakePoint(0,0));
    if(NSIsEmptyRect(target))return;
    [NSGraphicsContext saveGraphicsState];
    NSAffineTransform *transform=[NSAffineTransform transform];
    [transform translateXBy:NSMidX(rect) yBy:NSMinY(rect)];if(facing<0)[transform scaleXBy:-1 yBy:1];[transform concat];
    [image drawInRect:target fromRect:NSZeroRect
             operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:NO
                 hints:@{NSImageHintInterpolation:@(NSImageInterpolationHigh)}];
    [NSGraphicsContext restoreGraphicsState];
}
+ (NSDictionary *)runAssetTests {
    NSMutableArray *passed=[NSMutableArray new],*failed=[NSMutableArray new];
    void (^check)(BOOL,NSString *)=^(BOOL ok,NSString *name){[(ok?passed:failed) addObject:name];};
    check(self.available,@"pc2005-original-clip-atlases-are-bundled");
    BOOL geometry=YES,fullClips=YES,endpoints=YES;NSUInteger frames=0;
    for(NSDictionary *entry in self.catalogue){
        NSArray *images=PCFrames(entry[@"id"]);geometry&=images.count==[entry[@"frames"] unsignedIntegerValue];
        fullClips&=[entry[@"duration"] doubleValue]>.5&&[entry[@"fps"] doubleValue]==12&&fabs([entry[@"duration"] doubleValue]-[entry[@"sourceDuration"] doubleValue])<.11;
        frames+=images.count;
        endpoints&=images.count>0&&PCFrameHasContent(images.firstObject)&&PCFrameHasContent(images.lastObject);
    }
    check(geometry&&frames>2000,@"every-atlas-cell-loads-at-declared-dimensions");
    check(endpoints,@"first-and-final-frame-of-every-clip-retain-visible-content-and-alpha");
    check(fullClips&&[PCManifest()[@"fullClips"] boolValue],@"all-selected-clips-retain-full-duration-at-twelve-fps");
    PCPetAnimation *animation=[self new];[animation playAction:@"hotpot" time:100];
    [animation advanceAtTime:101 state:@"idle" autonomous:YES];
    check([animation.currentAction isEqualToString:@"hotpot"],@"explicit-actions-play-complete-before-idle-rotation");
    [animation advanceAtTime:102 state:@"wait" autonomous:YES];
    check([animation.currentAction isEqualToString:@"wait"],@"real-task-wait-interrupts-local-entertainment");
    NSString *before=animation.currentAction;BOOL rejected=![animation playAction:@"not-a-real-action" time:103];
    check(rejected&&[animation.currentAction isEqualToString:before],@"invalid-animation-id-cannot-change-selection");
    [animation advanceAtTime:90 state:@"idle" autonomous:NO];
    check([animation.currentAction isEqualToString:@"idle"],@"clock-reset-and-disabled-autonomy-return-to-idle");
    animation=[self new];[animation advanceAtTime:200 state:@"play" autonomous:YES];
    NSString *firstAction=animation.currentAction;
    [animation advanceAtTime:202 state:@"dance" autonomous:YES];
    [animation advanceAtTime:209.99 state:@"eat" autonomous:YES];
    check([animation.currentAction isEqualToString:firstAction],@"autonomous-scene-changes-preserve-original-clip-until-its-end");
    [animation advanceAtTime:210.01 state:@"dance" autonomous:YES];
    check([PCActionsForState(@"dance") containsObject:animation.currentAction],@"pending-autonomous-state-begins-after-complete-clip");
    [animation advanceAtTime:211 state:@"wait" autonomous:YES];
    [animation advanceAtTime:212 state:@"play" autonomous:YES];
    check([PCActionsForState(@"play") containsObject:animation.currentAction],@"leaving-real-task-state-immediately-restores-current-scene");
    [animation playAction:@"hotpot" time:213];[animation cancelManualPlayback];
    [animation playAction:@"wave" time:214];
    check([animation.currentAction isEqualToString:@"wave"]&&animation.manualUntil==224,@"cancelled-selection-allows-new-user-action-immediately");
    [animation advanceAtTime:215 state:@"idle" autonomous:NO];
    check([animation.currentAction isEqualToString:@"idle"]&&animation.manualUntil==0,@"turning-autonomy-off-immediately-stops-random-entertainment");
    animation=[self new];[animation advanceAtTime:300 state:@"idle" autonomous:YES];
    check(![animation.currentAction isEqualToString:@"idle"],@"initial-advance-starts-weighted-rotation-without-ten-second-delay");
    animation=[self new];[animation playAction:@"hotpot" time:100];
    [animation setLocomoting:YES time:101];double began=animation.locomotionBegan;
    [animation advanceAtTime:102 state:@"idle" autonomous:YES];[animation setLocomoting:YES time:102];
    check(animation.locomoting&&animation.locomotionBegan==began&&[animation.currentTitle isEqualToString:@"侧身走路"],@"movement-starts-side-cycle-without-restarting-it-every-tick");
    [animation setLocomoting:NO time:105];
    check(!animation.locomoting&&animation.actionBegan==104&&animation.manualUntil==114,@"standing-still-resumes-the-interrupted-clip-from-the-same-frame");
    [animation setLocomoting:YES time:106];[animation advanceAtTime:107 state:@"wait" autonomous:YES];
    check(!animation.locomoting&&[animation.currentAction isEqualToString:@"wait"],@"task-wait-immediately-preempts-locomotion");
    BOOL sideFrames=YES;NSArray *walkFrames=PCFrames(@"walk");
    for(NSUInteger i=24;i<=47;i++)sideFrames&=walkFrames.count>i&&PCFrameHasContent(walkFrames[i]);
    check(sideFrames,@"all-24-side-running-frames-have-visible-transparent-art");
    BOOL constantScale=YES,commonPivot=YES;
    for(NSDictionary *entry in self.catalogue){
        NSArray *crop=entry[@"sourceCrop"];NSRect target=PCSourceDrawingRect(entry,NSMakePoint(100,.5));
        constantScale&=fabs(NSWidth(target)/([crop[2] doubleValue]-[crop[0] doubleValue])-PCWorldScale)<1e-8;
        constantScale&=fabs(NSHeight(target)/([crop[3] doubleValue]-[crop[1] doubleValue])-PCWorldScale)<1e-8;
        commonPivot&=fabs(NSMinX(target)+(320-[crop[0] doubleValue])*PCWorldScale-100)<1e-8;
        commonPivot&=fabs(NSMinY(target)+([crop[3] doubleValue]-331)*PCWorldScale-.5)<1e-8;
    }
    check(constantScale,@"all-28-actions-share-identical-source-pixel-scale-despite-props");
    check(commonPivot,@"all-actions-share-one-body-pivot-and-foot-baseline");
    check(.5+(331-26.35)*PCWorldScale<30,@"highest-drag-head-stays-inside-the-touchbar");
    return @{@"passed":@(failed.count==0),@"checks":passed,@"failures":failed,@"assets":self.assetSummary};
}
@end
