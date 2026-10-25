#import "WhaleScene.h"
#import "CatCompanion.h"
#import "PCPetAnimation.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

// Behavior adapted from vlln/whale-girl/lib/client/{logic,index}.mjs.
// Copyright (c) 2026 Sam Gao (vlln), MIT. See bundled whale-girl-LICENSE.txt.
static NSString *const WGPositionKey = @"WhaleGirlTouchBarV2.PetNormalizedX";

static NSArray<NSString *> *WGStates(void) {
    return @[@"idle",@"working",@"celebrate",@"error",@"disappointed",@"joy",@"eat",@"play",@"drag",@"walk",@"sleep",@"wake",@"welcome",@"think",@"wait"];
}
static NSColor *WGColor(CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    return [NSColor colorWithSRGBRed:r green:g blue:b alpha:a];
}
static CGFloat WGRandom(CGFloat min, CGFloat max) {
    return min+(max-min)*(arc4random_uniform(1000000)/1000000.0);
}
static CGFloat WGClamp(CGFloat x, CGFloat min, CGFloat max) { return MAX(min,MIN(max,x)); }
static BOOL WGTruth(id value) { return [value respondsToSelector:@selector(boolValue)] && [value boolValue]; }
static double WGNumber(id value) { return [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] : 0; }

@interface WGSprite : NSObject
@property NSDictionary *config;
@property NSArray<NSImage *> *frames;
@property NSSize contentSize;
@end
@implementation WGSprite
@end

@interface WhaleScene ()
@property(nonatomic) NSTimer *timer;
@property(nonatomic) PCPetAnimation *pcAnimation;
@property(nonatomic) NSTimeInterval pcManualUntil;
@property(nonatomic) CGFloat pcDragVelocity;
@property(nonatomic) NSTimeInterval pcDragAt;
@property(nonatomic) CGFloat pcThrowVelocity;
@property(nonatomic) NSTimeInterval pcThrowUntil;
@property(nonatomic) NSTimeInterval pcLastMovingAt;
@property(nonatomic) CGFloat pcWalkingFacing;
@property(nonatomic) NSDictionary<NSString *,WGSprite *> *sprites;
@property(nonatomic) CGFloat spriteScale;
@property(nonatomic, readwrite, copy) NSString *currentState;
@property(nonatomic, readwrite) BOOL menuOpen;
@property(nonatomic) CGFloat petX;
@property(nonatomic) BOOL persistsPosition;
@property(nonatomic) CGFloat facing;
@property(nonatomic) BOOL pressed;
@property(nonatomic) BOOL dragging;
@property(nonatomic) BOOL moved;
@property(nonatomic) BOOL interactionFromSleep;
@property(nonatomic) NSInteger pressedButton;
@property(nonatomic) NSPoint pressPoint;
@property(nonatomic) CGFloat pressOffset;
@property(nonatomic) CGFloat lastPointerX;
@property(nonatomic) NSTimeInterval lastInteraction;
@property(nonatomic) NSTimeInterval idleSince;
@property(nonatomic) NSTimeInterval dragReleaseUntil;
@property(nonatomic) NSTimeInterval transientUntil;
@property(nonatomic, copy, nullable) NSString *transient;
@property(nonatomic) NSTimeInterval joyUntil;
@property(nonatomic) NSTimeInterval nextWalkAt;
@property(nonatomic) NSTimeInterval walkUntil;
@property(nonatomic) CGFloat walkDirection;
@property(nonatomic) NSTimeInterval facingAt;
@property(nonatomic) NSTimeInterval workingUntil;
@property(nonatomic) BOOL workingActive;
@property(nonatomic) uint32_t storyRandomState;
@property(nonatomic) NSTimeInterval visibleElapsed;
@property(nonatomic) NSTimeInterval visibleLastTick;
@property(nonatomic) NSTimeInterval hungerVisible;
@property(nonatomic) NSTimeInterval hungerAfter;
@property(nonatomic) NSTimeInterval nextHungerReminder;
@property(nonatomic) NSTimeInterval nextAutonomyAt;
@property(nonatomic) NSTimeInterval nextCuddleAt;
@property(nonatomic) NSTimeInterval nextNapAt;
@property(nonatomic) NSTimeInterval nextSpeechAt;
@property(nonatomic) NSTimeInterval lastUserVisible;
@property(nonatomic, copy, nullable) NSString *behavior;
@property(nonatomic, copy, nullable) NSString *lastAutonomousBehavior;
@property(nonatomic) NSTimeInterval behaviorUntil;
@property(nonatomic) NSTimeInterval behaviorStarted;
@property(nonatomic) BOOL userBehavior;
@property(nonatomic) BOOL hasAutonomousAction;
@property(nonatomic) CGFloat behaviorTarget;
@property(nonatomic) CGFloat behaviorSpeed;
@property(nonatomic) NSTimeInterval starUntilVisible;
@property(nonatomic) CGFloat starX;
@property(nonatomic) NSTimeInterval pressedAt;
@property(nonatomic) BOOL longPressFired;
@property(nonatomic) BOOL backgroundPressed;
@property(nonatomic) BOOL backgroundMoved;
@property(nonatomic) BOOL hasBeenFed;
@property(nonatomic) CGFloat companionX;
@property(nonatomic) CGFloat companionFacing;
@property(nonatomic) NSTimeInterval companionPhase;
@property(nonatomic) CGFloat companionSpeed;
@property(nonatomic) CGFloat companionLastPetX;
@property(nonatomic) CGFloat companionFollowDirection;
@property(nonatomic) BOOL companionPressed;
@property(nonatomic) BOOL companionTouchMoved;
@property(nonatomic, readwrite, copy) NSString *companionActivity;
@property(nonatomic) BOOL companionRoamingEnabled;
@property(nonatomic) uint32_t companionRandomState;
@property(nonatomic) NSTimeInterval nextCompanionRoamAt;
@property(nonatomic) NSTimeInterval companionActivityUntil;
@property(nonatomic) NSTimeInterval companionNextTargetAt;
@property(nonatomic) CGFloat companionTarget;
@property(nonatomic) CGFloat companionRoamAnchor;
@property(nonatomic) CGFloat companionRoamSide;
@property(nonatomic) CGFloat companionTravelSpeed;
@property(nonatomic) BOOL duoEnabled;
@property(nonatomic, copy) NSString *duoKind;
@property(nonatomic, copy) NSString *lastDuoKind;
@property(nonatomic, copy) NSString *duoStage;
@property(nonatomic) uint32_t duoRandomState;
@property(nonatomic) NSTimeInterval nextDuoAt;
@property(nonatomic) NSTimeInterval duoStarted;
@property(nonatomic) NSTimeInterval duoDuration;
@property(nonatomic) CGFloat duoDirection;
@property(nonatomic) CGFloat duoOrigin;
@property(nonatomic) CGFloat duoGirlTarget;
@property(nonatomic) CGFloat duoCatTarget;
@property(nonatomic) CGFloat duoGirlDepth;
@property(nonatomic) CGFloat duoCatHop;
@property(nonatomic) BOOL duoPetMoving;
@property(nonatomic) BOOL duoQuickEnding;
@property(nonatomic) BOOL duoUserRequested;
@property(nonatomic) NSTimeInterval bubbleUntil;
@property(nonatomic, copy) NSString *bubble;
@property(nonatomic) NSTimeInterval heartsUntil;
@property(nonatomic) NSTimeInterval stateBegan;
@property(nonatomic) NSTimeInterval lastFrameAt;
@property(nonatomic) NSTimeInterval blinkAt;
@property(nonatomic) BOOL blinkActive;
@property(nonatomic) NSInteger frameIndex;
@property(nonatomic) NSInteger frameDirection;
@property(nonatomic) NSTimeInterval previousTick;
@property(nonatomic) NSTimeInterval clockOverride;
@property(nonatomic) NSDictionary *backendSnapshot;
@property(nonatomic) BOOL backendThink;
@property(nonatomic) BOOL backendWait;
@property(nonatomic) NSTimeInterval backendCelebrateUntil;
@end

@implementation WhaleScene
- (instancetype)initWithFrame:(NSRect)frame {
    return [self initWithFrame:frame persistsPosition:YES];
}
- (instancetype)initWithFrame:(NSRect)frame persistsPosition:(BOOL)persistsPosition {
    if ((self=[super initWithFrame:frame])) {
        _fixedTime=-1; _clockOverride=-1; _autonomousEnabled=YES;
        _storyRandomState=arc4random()?:1;
        _persistsPosition=persistsPosition;
        _petX=frame.size.width*.5; _facing=1;
        if (persistsPosition) {
            id saved=[NSUserDefaults.standardUserDefaults objectForKey:WGPositionKey];
            if ([saved isKindOfClass:NSNumber.class] && isfinite([saved doubleValue]))
                _petX=WGClamp([saved doubleValue]*frame.size.width,24,MAX(24,frame.size.width-24));
        }
        _currentState=@"idle"; _frameDirection=1;
        _bubble=@""; _pressedButton=-1;
        NSTimeInterval now=[self now];
        _lastInteraction=now; _idleSince=now; _stateBegan=now; _lastFrameAt=now;
        _nextWalkAt=now+WGRandom(18,40);
        _visibleLastTick=now;_hungerAfter=240;_nextHungerReminder=240;
        _nextAutonomyAt=5;_nextCuddleAt=WGRandom(45,120);_nextNapAt=WGRandom(480,720);
        _backendSnapshot=@{};
        self.wantsLayer=YES;
        self.layer.backgroundColor=WGColor(10.0/255,10.0/255,10.0/255,1).CGColor;
        self.allowedTouchTypes=NSTouchTypeMaskDirect|NSTouchTypeMaskIndirect;
        [self setAccessibilityElement:YES];
        [self setAccessibilityRole:NSAccessibilityButtonRole];
        [self setAccessibilityLabel:@"鲸鱼娘。轻触打开投喂、玩耍、摸摸和跳舞；长按摸头，拖动搬家，点空白让她追星星。"];
        [self loadSprites];
        _companionX=WGClamp(_petX+76,24,MAX(24,frame.size.width-24));
        if (_companionX-_petX<56) _companionX=MAX(24,_petX-76);
        _companionFollowDirection=_companionX<_petX?1:-1;
        _companionFacing=_companionFollowDirection;_companionLastPetX=_petX;
        _companionActivity=@"follow";_companionRoamingEnabled=YES;
        _companionRandomState=arc4random()?:1;
        _duoEnabled=YES;_duoRandomState=arc4random()?:1;
        _nextDuoAt=12+[self nextDuoRandom]*10;
        _nextCompanionRoamAt=8+[self nextCompanionRandom]*8;
    }
    return self;
}
- (void)setPc2005Enabled:(BOOL)value {
    _pc2005Enabled=value&&[PCPetAnimation available];
    if (_pc2005Enabled&&!self.pcAnimation) self.pcAnimation=[PCPetAnimation new];
    [self.pcAnimation setLocomoting:NO time:self.visibleElapsed];self.pcLastMovingAt=-100;
    self.pcManualUntil=0;self.pcThrowVelocity=0;self.needsDisplay=YES;
}
- (NSString *)pcActionTitle { return self.pc2005Enabled?self.pcAnimation.currentTitle:@"原版鲸鱼娘"; }
- (BOOL)pcWalking { return self.pc2005Enabled&&self.pcAnimation.locomoting; }
- (void)prepareSideWalkPreviewFacing:(CGFloat)direction elapsed:(NSTimeInterval)elapsed {
    self.pc2005Enabled=YES;self.petX=self.bounds.size.width*.5;self.facing=direction>0?-1:1;
    [self.pcAnimation setLocomoting:YES time:0];self.fixedTime=elapsed;self.currentState=@"walk";
}

- (BOOL)playPCAction:(NSString *)action {
    NSDictionary *entry=nil;
    for (NSDictionary *item in [PCPetAnimation catalogue]) if ([item[@"id"] isEqualToString:action]) { entry=item;break; }
    if (!entry) return NO;
    self.pc2005Enabled=YES;
    [self stopBehavior];[self recordInteractionFromSleep:NO];self.menuOpen=NO;
    self.pcThrowVelocity=0;self.pcManualUntil=self.visibleElapsed+MAX(.1,[entry[@"duration"] doubleValue]);
    [self.pcAnimation playAction:action time:self.visibleElapsed];self.needsDisplay=YES;return YES;
}
- (NSTimeInterval)now { return self.clockOverride>=0?self.clockOverride:NSDate.date.timeIntervalSince1970; }
- (NSSize)intrinsicContentSize { return NSMakeSize(NSViewNoIntrinsicMetric,30); }
- (BOOL)isOpaque { return YES; }
- (BOOL)acceptsFirstResponder { return NO; }
- (void)dealloc { [_timer invalidate]; }
- (void)accountVisibleTo:(NSTimeInterval)now {
    if (self.animating) {
        NSTimeInterval delta=MAX(0,now-self.visibleLastTick);
        if (isfinite(delta)) { self.visibleElapsed+=delta;self.hungerVisible+=delta; }
    }
    self.visibleLastTick=now;
}
- (void)setAnimating:(BOOL)value {
    if (_animating==value) return;
    if (_animating) [self accountVisibleTo:[self now]];
    _animating=value;
    [_timer invalidate];_timer=nil;
    if (value) {
        self.previousTick=[self now];self.visibleLastTick=[self now];
        __weak WhaleScene *weak=self;
        self.timer=[NSTimer timerWithTimeInterval:1.0/30.0 repeats:YES block:^(NSTimer *timer) {
            WhaleScene *view=weak;
            if (!view) { [timer invalidate];return; }
            if (view.hidden || (view.window&&!view.window.visible)) { view.visibleLastTick=[view now];return; }
            [view advanceTo:[view now]];
        }];
        self.timer.tolerance=.007;
        [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
    } else {
        [self abortPointer];[self stopBehavior];
        [self.pcAnimation setLocomoting:NO time:self.visibleElapsed];self.pcLastMovingAt=-100;
        self.menuOpen=NO;self.bubbleUntil=0;self.heartsUntil=0;self.starUntilVisible=0;self.pcThrowVelocity=0;self.pcManualUntil=0;
        self.transient=nil;self.transientUntil=0;self.joyUntil=0;self.walkUntil=0;
        [self setState:[self selectStateAt:[self now]] now:[self now]];
    }
    self.needsDisplay=YES;
}
- (void)setAutonomousEnabled:(BOOL)value {
    if (_autonomousEnabled==value) return;
    _autonomousEnabled=value;
    [self cancelDuoStory];
    [self cancelCompanionPlay];
    [self stopBehavior];
    self.lastUserVisible=self.visibleElapsed;self.nextAutonomyAt=self.visibleElapsed+5;
    self.nextCuddleAt=self.visibleElapsed+WGRandom(45,120);
    self.nextNapAt=self.visibleElapsed+WGRandom(480,720);
    self.idleSince=[self now];self.needsDisplay=YES;
}
- (NSString *)currentBehavior {
    if (self.duoKind.length) return [@"duo-" stringByAppendingString:self.duoKind];
    if (self.dragging) return @"drag";
    if (self.behavior.length) return self.behavior;
    if ([self.currentState isEqualToString:@"eat"]) return @"feed";
    return self.currentState?:@"idle";
}
- (NSString *)needsSummary {
    if (self.hungerVisible>=self.hungerAfter) return @"有点饿啦 · 点🍗投喂我";
    if (self.hasBeenFed && self.hungerVisible<120) return @"肚子饱饱 · 谢谢你陪我♡";
    if ([self.behavior isEqualToString:@"nap"]) return @"小睡一会儿 · 很快就醒";
    return @"精神满满 · 长按摸摸我♡";
}
- (void)stopBehavior {
    self.behavior=nil;self.behaviorUntil=0;self.starUntilVisible=0;
    self.nextAutonomyAt=MAX(self.lastUserVisible+5,self.visibleElapsed+.25);
}
- (BOOL)canSulk {
    CGFloat direction=self.petX>=self.companionX?1:-1;
    CGFloat available=direction>0?self.bounds.size.width-34-self.petX:self.petX-34;
    return available>=160;
}
- (NSString *)nextIdleStory {
    if (!self.hasAutonomousAction) return @"run";
    // A per-scene random seed keeps the live sequence varied and tests reproducible.
    uint32_t x=self.storyRandomState?:1;x^=x<<13;x^=x>>17;x^=x<<5;self.storyRandomState=x;
    NSUInteger roll=x%100;
    NSString *name=roll<30?@"run":(roll<45?@"play":(roll<65?@"dance":(roll<85?@"snack":@"sulk")));
    return [name isEqualToString:@"sulk"]&&![self canSulk]?@"run":name;
}
- (CGFloat)nextPairRunTarget {
    // The cat follows independently; the girl's route no longer depends on a fixed pair offset.
    CGFloat low=70,high=MAX(low,self.bounds.size.width-70);
    return self.petX<(low+high)*.5?high:low;
}
- (void)beginBehavior:(NSString *)name user:(BOOL)user duration:(NSTimeInterval)duration {
    if ([name isEqualToString:@"sulk"]&&![self canSulk]) name=@"run";
    self.behavior=name;self.userBehavior=user;
    self.behaviorStarted=self.visibleElapsed;self.behaviorUntil=self.visibleElapsed+duration;
    self.walkUntil=0;
    if (!user) { self.lastAutonomousBehavior=name;self.hasAutonomousAction=YES; }
    if ([@[@"run",@"chase"] containsObject:name]) {
        self.behaviorSpeed=WGRandom(80,110);
        if ([name isEqualToString:@"run"]) {
            CGFloat limit=MAX(24,self.bounds.size.width-24);
            self.behaviorTarget=self.petX<self.bounds.size.width*.5?WGRandom(MAX(self.petX+80,self.bounds.size.width*.6),limit):WGRandom(24,MIN(self.petX-80,self.bounds.size.width*.4));
            self.behaviorTarget=WGClamp(self.behaviorTarget,24,limit);
            if (!user) {
                [self constrainCompanion];
                self.behaviorTarget=[self nextPairRunTarget];
                self.behaviorSpeed=90;
            }
        }
        self.facing=self.behaviorTarget>self.petX?-1:1;
    }
    if ([name isEqualToString:@"sulk"]) {
        self.behaviorTarget=self.petX>=self.companionX?self.bounds.size.width-34:34;
        self.behaviorSpeed=210;self.bubble=@"哼，我要跑到那边去！";self.bubbleUntil=[self now]+1.7;
    } else if ([name isEqualToString:@"snack"]) {
        self.bubble=@"中场休息，吃一小口～";self.bubbleUntil=[self now]+2.2;
        self.facing=self.companionX>self.petX?-1:1;
    }
    if ([@[@"cuddle",@"hungry"] containsObject:name]) {
        self.bubble=[name isEqualToString:@"hungry"]?@"肚子有点饿啦，想吃一小口～":@"摸摸我嘛～♡";
        self.bubbleUntil=[self now]+3.2;self.heartsUntil=[self now]+1.8;
        self.nextSpeechAt=self.visibleElapsed+45;
    }
}
- (NSString *)behaviorState {
    if ([self.behavior isEqualToString:@"snack"]) return @"eat";
    if ([self.behavior isEqualToString:@"sulk"]) return self.visibleElapsed-self.behaviorStarted<.6||fabs(self.behaviorTarget-self.petX)<.5?@"disappointed":@"walk";
    if ([@[@"run",@"chase"] containsObject:self.behavior]) return @"walk";
    if ([self.behavior isEqualToString:@"dance"]) return fmod(self.visibleElapsed-self.behaviorStarted,1.3)<.8?@"celebrate":@"joy";
    if ([self.behavior isEqualToString:@"play"]) return @"play";
    if ([self.behavior isEqualToString:@"stretch"]) return @"wake";
    if ([self.behavior isEqualToString:@"nap"]) return @"sleep";
    return @"joy";
}
- (BOOL)hasTaskPriorityAt:(NSTimeInterval)now {
    return self.backendThink||self.backendWait||self.backendCelebrateUntil>now||[self burstActiveAt:now name:NULL];
}
- (void)advanceAutonomyAt:(NSTimeInterval)now {
    if (self.behavior && self.visibleElapsed>=self.behaviorUntil) {
        BOOL nap=[self.behavior isEqualToString:@"nap"];
        [self stopBehavior];
        if (nap) { self.transient=@"wake";self.transientUntil=now+3;self.nextNapAt=self.visibleElapsed+WGRandom(480,720); }
    }
    BOOL occupied=self.pressed||self.dragging||self.pressedButton>=0||self.companionPressed||self.backgroundPressed||self.menuOpen||self.transient||self.joyUntil>now||self.dragReleaseUntil>now||[self hasTaskPriorityAt:now];
    if (self.duoKind.length && (occupied||(!self.autonomousEnabled&&!self.duoUserRequested)||self.forcedState)) [self cancelDuoStory];
    if (self.behavior && !self.userBehavior && (occupied||!self.autonomousEnabled)) [self stopBehavior];
    if (self.duoKind.length) return;
    if (self.animating && self.autonomousEnabled && self.duoEnabled && !occupied && !self.behavior && !self.forcedState
        && self.visibleElapsed-self.lastUserVisible>5 && self.visibleElapsed>=self.nextDuoAt
        && ![@[@"roam",@"return"] containsObject:self.companionActivity] && fabs(self.petX-self.companionX)<145
        && self.bounds.size.width>=420) {
        NSArray *kinds=@[@"block",@"dash",@"reunion"];
        NSUInteger choice=(NSUInteger)floor([self nextDuoRandom]*kinds.count)%kinds.count;
        if ([kinds[choice] isEqualToString:self.lastDuoKind]) choice=(choice+1)%kinds.count;
        [self beginDuoStory:kinds[choice]];return;
    }
    if (!self.animating || !self.autonomousEnabled || self.forcedState || occupied || self.behavior || self.visibleElapsed-self.lastUserVisible<=5) return;
    if (self.hungerVisible>=self.hungerAfter && self.visibleElapsed>=self.nextHungerReminder && self.visibleElapsed>=self.nextSpeechAt) {
        [self beginBehavior:@"hungry" user:NO duration:3.2];self.nextHungerReminder=self.visibleElapsed+480;return;
    }
    if (self.visibleElapsed-self.lastUserVisible>=480 && self.visibleElapsed>=self.nextNapAt) {
        [self beginBehavior:@"nap" user:NO duration:WGRandom(12,20)];return;
    }
    if (self.visibleElapsed>=self.nextCuddleAt && self.visibleElapsed>=self.nextSpeechAt) {
        [self beginBehavior:@"cuddle" user:NO duration:3.2];self.nextCuddleAt=self.visibleElapsed+WGRandom(45,120);return;
    }
    if (self.visibleElapsed>=self.nextAutonomyAt) {
        [self beginBehavior:[self nextIdleStory] user:NO duration:5];
    }
}
- (void)setFixedTime:(NSTimeInterval)value { _fixedTime=value; self.needsDisplay=YES; }
- (void)setForcedState:(NSString *)value {
    _forcedState=[value copy];
    if (value && [WGStates() containsObject:value]) [self setState:value now:[self now]];
    self.needsDisplay=YES;
}
- (void)loadSprites {
    NSURL *root=[NSBundle.mainBundle.resourceURL URLByAppendingPathComponent:@"whale-girl-assets" isDirectory:YES];
    NSData *manifestData=[NSData dataWithContentsOfURL:[root URLByAppendingPathComponent:@"manifest.json"]];
    NSDictionary *manifest=manifestData?[NSJSONSerialization JSONObjectWithData:manifestData options:0 error:nil]:nil;
    NSDictionary *states=manifest[@"characters"][@"whale-girl"][@"states"];
    if (![states isKindOfClass:NSDictionary.class]) { self.sprites=@{};return; }
    NSMutableDictionary *all=[NSMutableDictionary new]; CGFloat maxContentH=1;
    for (NSString *name in WGStates()) {
        NSDictionary *cfg=states[name];
        if (![cfg isKindOfClass:NSDictionary.class]) continue;
        NSString *sheet=cfg[@"sheet"];
        if (![sheet isKindOfClass:NSString.class] || [sheet containsString:@"/"] || [sheet containsString:@".."] ) continue;
        NSURL *url=[[root URLByAppendingPathComponent:@"characters/whale-girl"] URLByAppendingPathComponent:sheet];
        NSImage *whole=[[NSImage alloc] initWithContentsOfURL:url];
        if (!whole) continue;
        CGImageRef source=[whole CGImageForProposedRect:NULL context:nil hints:nil];
        NSInteger count=[cfg[@"frames"] integerValue];
        size_t fullW=source?CGImageGetWidth(source):0, h=source?CGImageGetHeight(source):0;
        if (!source || count<1 || fullW%count || !h || h>4096 || fullW>16384) continue;
        size_t fw=fullW/count;
        NSMutableData *rgba=[NSMutableData dataWithLength:fullW*h*4];
        CGColorSpaceRef cs=CGColorSpaceCreateDeviceRGB();
        CGContextRef ctx=CGBitmapContextCreate(rgba.mutableBytes,fullW,h,8,fullW*4,cs,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(cs);
        if (!ctx) continue;
        CGContextDrawImage(ctx,CGRectMake(0,0,fullW,h),source); CGContextRelease(ctx);
        unsigned char *pixels=rgba.mutableBytes;
        size_t left=fw,top=h,right=0,bottom=0;
        for (size_t y=0;y<h;y++) for (size_t x=0;x<fullW;x++) {
            if (pixels[(y*fullW+x)*4+3]>16) {
                size_t fx=x%fw;
                left=MIN(left,fx);right=MAX(right,fx);top=MIN(top,y);bottom=MAX(bottom,y);
            }
        }
        if (left>=fw || top>=h) continue;
        // Trim only transparent padding at runtime. All original asset bytes stay intact.
        CGFloat cropW=right-left+1,cropH=bottom-top+1;
        NSMutableArray *frames=[NSMutableArray new];
        for (NSInteger i=0;i<count;i++) {
            CGImageRef crop=CGImageCreateWithImageInRect(source,CGRectMake(i*fw+left,top,cropW,cropH));
            if (crop) { [frames addObject:[[NSImage alloc] initWithCGImage:crop size:NSMakeSize(cropW,cropH)]]; CGImageRelease(crop); }
        }
        if ((NSInteger)frames.count!=count) continue;
        WGSprite *sprite=[WGSprite new];sprite.frames=frames;sprite.config=cfg;sprite.contentSize=NSMakeSize(cropW,cropH);
        all[name]=sprite;maxContentH=MAX(maxContentH,cropH);
    }
    self.sprites=all; self.spriteScale=29.0/maxContentH;
}
- (void)setState:(NSString *)state now:(NSTimeInterval)now {
    if ([self.currentState isEqualToString:state]) return;
    self.currentState=state;self.frameIndex=0;self.frameDirection=1;
    self.stateBegan=now;self.lastFrameAt=now;self.blinkAt=0;self.blinkActive=NO;
    self.needsDisplay=YES;
}
- (BOOL)burstActiveAt:(NSTimeInterval)now name:(NSString **)name {
    NSDictionary *act=self.backendSnapshot[@"activity"];
    if (![act isKindOfClass:NSDictionary.class]) return NO;
    NSString *candidate=act[@"name"];
    if (![candidate isKindOfClass:NSString.class] || ![WGStates() containsObject:candidate] || [candidate isEqualToString:@"idle"] || [candidate isEqualToString:@"working"]) return NO;
    if (WGNumber(act[@"until"])/1000.0<=now) return NO;
    if (name) *name=candidate;return YES;
}
- (NSString *)selectStateAt:(NSTimeInterval)now {
    // Same first-match order as upstream STATE_TABLE, including drag-release buffer.
    if (self.forcedState && [WGStates() containsObject:self.forcedState]) return self.forcedState;
    if (self.dragging) return @"drag";
    if (self.dragReleaseUntil>now && ![self.transient isEqualToString:@"wake"]) return @"idle";
    NSString *burst=nil;
    if ([self burstActiveAt:now name:&burst]) return burst;
    if (self.transient) return self.transient;
    if (self.behavior && self.userBehavior) return [self behaviorState];
    if (self.backendWait) return @"wait";
    if (self.backendCelebrateUntil>now) return @"celebrate";
    if (self.workingActive && self.backendThink) return @"working";
    if (self.backendThink) return @"think";
    if (self.joyUntil>now) return @"joy";
    if (self.behavior) return [self behaviorState];
    if (self.duoKind.length) return [self duoState];
    if (!self.autonomousEnabled && now-self.idleSince>=60) return @"sleep";
    if (self.walkUntil>now) return @"walk";
    return @"idle";
}
- (void)advanceFramesAt:(NSTimeInterval)now {
    WGSprite *sprite=self.sprites[self.currentState];
    NSInteger count=sprite.frames.count;
    if (count<2) return;
    NSString *mode=sprite.config[@"playback"];
    if ([mode isEqualToString:@"blink"]) {
        if (!self.blinkActive) {
            self.frameIndex=0;
            if (!self.blinkAt) self.blinkAt=now+WGRandom(3,9);
            if (now<self.blinkAt) return;
            self.blinkActive=YES;self.lastFrameAt=now;
            return;
        }
    }
    for (NSInteger n=0;n<32;n++) {
        NSArray *holds=sprite.config[@"frameMs"];
        double fps=MAX(1,WGNumber(sprite.config[@"fps"]));
        double hold=([holds isKindOfClass:NSArray.class] && self.frameIndex<(NSInteger)holds.count)?WGNumber(holds[self.frameIndex])/1000.0:1.0/fps;
        hold=MAX(.016,hold);
        if (now-self.lastFrameAt+1e-7<hold) break;
        self.lastFrameAt+=hold;
        if ([mode isEqualToString:@"pingpong"]) {
            self.frameIndex+=self.frameDirection;
            if (self.frameIndex>=count-1 || self.frameIndex<=0) self.frameDirection*=-1;
            self.frameIndex=MAX(0,MIN(count-1,self.frameIndex));
        } else if ([mode isEqualToString:@"once"]) {
            self.frameIndex=MIN(count-1,self.frameIndex+1);
        } else {
            self.frameIndex++;
            if (self.frameIndex>=count) {
                self.frameIndex=0;
                if ([mode isEqualToString:@"blink"]) {
                    self.blinkActive=NO;self.blinkAt=now+WGRandom(3,9);break;
                }
            }
        }
    }
}
- (void)advanceTo:(NSTimeInterval)now {
    CGFloat pcTickStartX=self.petX;
    [self accountVisibleTo:now];
    CGFloat dt=MIN(.08,MAX(0,now-self.previousTick));self.previousTick=now;
    if (self.pressed&&!self.dragging&&!self.moved&&!self.longPressFired&&now-self.pressedAt>=.65) {
        self.longPressFired=YES;[self performAction:@"pet"];
    }
    if (self.transient && now>=self.transientUntil) {
        BOOL fun=[self.transient isEqualToString:@"eat"]||[self.transient isEqualToString:@"play"];
        self.transient=nil;self.transientUntil=0;
        if (fun) self.joyUntil=now+1.6;
    }
    if (self.backendThink) {
        if (!self.workingUntil) self.workingUntil=now+WGRandom(12,30);
        else if (now>=self.workingUntil) {
            self.workingActive=!self.workingActive;
            self.workingUntil=now+(self.workingActive?WGRandom(2.5,6):WGRandom(12,30));
        }
    } else { self.workingActive=NO;self.workingUntil=0; }
    [self advanceAutonomyAt:now];
    [self advanceDuoStoryAt:now dt:dt];
    NSString *candidate=[self selectStateAt:now];
    if (!self.autonomousEnabled && [candidate isEqualToString:@"idle"] && !self.pressed && !self.menuOpen && now>=self.nextWalkAt) {
        self.walkUntil=now+WGRandom(3,6);
        self.walkDirection=self.petX<self.bounds.size.width*.25?1:(self.petX>self.bounds.size.width*.75?-1:(arc4random_uniform(2)?1:-1));
        self.facing=self.walkDirection>0?-1:1;candidate=@"walk";
        self.nextWalkAt=self.walkUntil+WGRandom(18,40);
    }
    if ([self.currentState isEqualToString:@"sleep"] && ![candidate isEqualToString:@"sleep"] && !self.dragging && !self.transient) {
        self.transient=@"wake";self.transientUntil=now+3;candidate=[self selectStateAt:now];
    }
    [self setState:candidate now:now];
    if (!self.duoKind.length && [candidate isEqualToString:@"walk"] && self.behavior && !self.pressed && !self.menuOpen) {
        CGFloat distance=self.behaviorTarget-self.petX;
        CGFloat step=MIN(fabs(distance),self.behaviorSpeed*dt);
        if (fabs(distance)>.2) self.facing=distance>0?-1:1;
        self.petX=WGClamp(self.petX+copysign(step,distance),24,MAX(24,self.bounds.size.width-24));
        if (fabs(self.behaviorTarget-self.petX)<.5) {
            if (!self.userBehavior&&[self.behavior isEqualToString:@"run"]) self.behaviorTarget=[self nextPairRunTarget];
            else if (!self.userBehavior&&[self.behavior isEqualToString:@"sulk"]) [self setState:@"disappointed" now:now];
            else { [self stopBehavior];[self setState:[self selectStateAt:now] now:now]; }
        }
    } else if (!self.duoKind.length && [candidate isEqualToString:@"walk"] && !self.pressed && !self.menuOpen) {
        self.petX=WGClamp(self.petX+self.walkDirection*45*dt,24,MAX(24,self.bounds.size.width-24));
        if (self.petX<=24 || self.petX>=self.bounds.size.width-24) {
            self.walkUntil=0;self.nextWalkAt=now+WGRandom(18,40);
            [self setState:[self selectStateAt:now] now:now];
        }
    }
    if ([@[@"idle",@"think",@"wait"] containsObject:candidate]) {
        if (!self.facingAt) self.facingAt=now+WGRandom(10,25);
        if (now>=self.facingAt) { self.facing=-self.facing;self.facingAt=now+WGRandom(10,25); }
    } else self.facingAt=0;
    [self updateCompanionAt:now dt:dt];
    [self advanceFramesAt:now];
    if (self.pc2005Enabled) {
        BOOL occupied=self.pressed||self.menuOpen||[self hasTaskPriorityAt:now];
        if (occupied) self.pcManualUntil=0;
        if (self.pcThrowVelocity!=0 && !occupied && self.pcThrowUntil>self.visibleElapsed) {
            CGFloat edge=MAX(24,MIN(60,[self petDrawingRect].size.width*.5+2));
            CGFloat next=self.petX+self.pcThrowVelocity*dt;
            if(next<edge||next>self.bounds.size.width-edge){self.pcThrowVelocity*=-.62;next=WGClamp(next,edge,self.bounds.size.width-edge);}
            self.petX=next;self.facing=self.pcThrowVelocity>0?-1:1;
            self.pcThrowVelocity*=pow(.18,dt);if(fabs(self.pcThrowVelocity)<12)self.pcThrowVelocity=0;
        } else self.pcThrowVelocity=0;
        CGFloat moved=self.petX-pcTickStartX;
        if(fabs(moved)>.03){self.pcLastMovingAt=self.visibleElapsed;self.pcWalkingFacing=moved>0?-1:1;}
        BOOL moving=!self.pressed&&!self.menuOpen&&!self.dragging&&(fabs(moved)>.03||self.visibleElapsed-self.pcLastMovingAt<.08);
        if(moving)self.facing=self.pcWalkingFacing;
        [self.pcAnimation setLocomoting:moving time:self.visibleElapsed];
        if(!moving&&self.pcManualUntil<=self.visibleElapsed){
            NSString *pcState=self.currentState;
            NSString *sourceState=[self.backendSnapshot[@"pcTaskState"] isKindOfClass:NSString.class]?self.backendSnapshot[@"pcTaskState"]:@"";
            if(!self.dragging&&!self.menuOpen){
                if(self.backendWait)pcState=@"wait";
                else if(self.backendThink&&[@[@"thinking",@"working",@"result"] containsObject:sourceState])pcState=@{@"thinking":@"think",@"working":@"working",@"result":@"review"}[sourceState];
                else if(![self hasTaskPriorityAt:now]&&!self.userBehavior&&!self.transient)pcState=@"idle";
            }
            [self.pcAnimation advanceAtTime:self.visibleElapsed state:pcState autonomous:self.autonomousEnabled&&!self.menuOpen&&!self.pressed];
        }
    }
    self.needsDisplay=YES;
}
- (void)recordInteractionFromSleep:(BOOL)sleeping {
    NSTimeInterval now=[self now];self.lastInteraction=now;self.idleSince=now;
    self.lastUserVisible=self.visibleElapsed;self.nextAutonomyAt=self.visibleElapsed+5;
    [self cancelDuoStory];
    [self cancelCompanionPlay];
    self.nextNapAt=self.visibleElapsed+WGRandom(480,720);self.nextCuddleAt=self.visibleElapsed+WGRandom(45,120);
    self.nextSpeechAt=MAX(self.nextSpeechAt,self.visibleElapsed+18);
    self.walkUntil=0;self.nextWalkAt=now+WGRandom(18,40);
    if (sleeping) { self.transient=@"wake";self.transientUntil=now+3; }
}
- (void)performAction:(NSString *)action {
    [self.pcAnimation setLocomoting:NO time:self.visibleElapsed];self.pcLastMovingAt=-100;
    [self.pcAnimation cancelManualPlayback];self.pcManualUntil=0;
    NSTimeInterval now=[self now];
    BOOL sleeping=[self.currentState isEqualToString:@"sleep"];
    if ([@[@"duo-block",@"duo-dash",@"duo-reunion"] containsObject:action]) {
        [self stopBehavior];[self recordInteractionFromSleep:sleeping];self.menuOpen=NO;
        self.transient=nil;self.transientUntil=0;self.joyUntil=0;self.dragReleaseUntil=0;
        // Explicit playback starts immediately, including when the old frame was asleep.
        if(sleeping)[self setState:@"idle" now:now];
        [self beginDuoStory:[action substringFromIndex:4]];self.duoUserRequested=YES;
    } else if ([action isEqualToString:@"close-menu"]) { [self stopBehavior];[self recordInteractionFromSleep:sleeping];self.menuOpen=NO; }
    else if ([action isEqualToString:@"status"]) {
        [self stopBehavior];[self recordInteractionFromSleep:sleeping];[self showReply:self.hungerVisible>=self.hungerAfter?@"肚子有点饿啦，想吃一小口～":@"有你在，我就很开心♡"];
    } else if ([action isEqualToString:@"toggle-menu"]) {
        [self stopBehavior];[self recordInteractionFromSleep:sleeping];
        self.menuOpen=!self.menuOpen;if (self.menuOpen) { self.bubbleUntil=0; [self constrainCompanion]; }
    } else if ([@[@"feed",@"play",@"pet",@"dance",@"run",@"cuddle",@"nap"] containsObject:action]) {
        [self stopBehavior];[self recordInteractionFromSleep:sleeping];self.menuOpen=NO;
        self.transient=nil;self.transientUntil=0;self.joyUntil=0;
        if ([action isEqualToString:@"feed"] || [action isEqualToString:@"play"]) {
            self.transient=[action isEqualToString:@"feed"]?@"eat":@"play";self.transientUntil=now+1.5;
            if ([action isEqualToString:@"feed"]) {
                self.hungerVisible=0;self.hungerAfter=720;self.nextHungerReminder=self.visibleElapsed+720;self.hasBeenFed=YES;
                self.bubble=@"吃饱啦，谢谢你♡";
            } else {
                NSArray *pool=@[@"嘿嘿，再来一次！",@"玩得好开心～",@"我赢了！再来！"];
                self.bubble=pool[arc4random_uniform((uint32_t)pool.count)];
            }
            self.bubbleUntil=now+2.5;self.heartsUntil=now+1.8;
            if (self.interactionHandler) self.interactionHandler(action);
        } else if ([action isEqualToString:@"pet"] || [action isEqualToString:@"cuddle"]) {
            [self beginBehavior:@"cuddle" user:YES duration:2.5];
            self.bubble=[action isEqualToString:@"pet"]?@"嘿嘿，好喜欢你摸摸♡":@"再陪我一会儿嘛～♡";
        } else if ([action isEqualToString:@"dance"]) {
            [self beginBehavior:@"dance" user:YES duration:5];self.bubble=@"给你跳一支开心的舞♪";self.bubbleUntil=now+2.5;
        } else if ([action isEqualToString:@"run"]) [self beginBehavior:@"run" user:YES duration:5];
        else if ([action isEqualToString:@"nap"]) [self beginBehavior:@"nap" user:YES duration:15];
    } else if ([action isEqualToString:@"wake"]) {
        [self stopBehavior];[self recordInteractionFromSleep:sleeping];
    }
    if(self.pc2005Enabled){
        NSString *clip=@{@"feed":@"snack",@"play":@"cube",@"pet":@"tickle",@"cuddle":@"tickle",@"dance":@"dance",@"run":@"walk",@"nap":@"sleep",@"wake":@"stretch"}[action];
        if(clip.length){[self.pcAnimation playAction:clip time:self.visibleElapsed];self.pcManualUntil=self.visibleElapsed+self.pcAnimation.currentDuration;}
    }
    [self advanceTo:now];
}
- (void)playAtX:(CGFloat)x {
    // Compatibility helper for the previous preview API; actual pet taps open a menu.
    self.petX=WGClamp(x,24,MAX(24,self.bounds.size.width-24));
    [self performAction:@"play"];
}
- (void)applyBackendSnapshot:(NSDictionary *)snapshot {
    if (![snapshot isKindOfClass:NSDictionary.class]) return;
    BOOL wasActive=self.backendThink||self.backendWait;
    self.backendSnapshot=snapshot;
    NSDictionary *act=[snapshot[@"activity"] isKindOfClass:NSDictionary.class]?snapshot[@"activity"]:@{};
    NSDictionary *mood=[snapshot[@"sessionMood"] isKindOfClass:NSDictionary.class]?snapshot[@"sessionMood"]:@{};
    self.backendThink=WGTruth(act[@"sessionThink"])||WGTruth(mood[@"thinking"]);
    self.backendWait=WGTruth(act[@"sessionWait"])||WGTruth(mood[@"waiting"]);
    self.backendCelebrateUntil=MAX(WGNumber(act[@"turnCompletedUntil"]),WGNumber(snapshot[@"roundCelebrateUntil"]))/1000.0;
    if (WGTruth(act[@"turnCompleted"]) && self.backendCelebrateUntil==0) self.backendCelebrateUntil=[self now]+4;
    if (wasActive && !self.backendThink && !self.backendWait) self.idleSince=[self now];
    NSString *activityName=[act[@"name"] isKindOfClass:NSString.class]?act[@"name"]:@"idle";
    if (![activityName isEqualToString:@"idle"] || WGNumber(act[@"until"])/1000.0>[self now]) self.idleSince=[self now];
    NSString *reply=[snapshot[@"reply"] isKindOfClass:NSString.class]?snapshot[@"reply"]:nil;
    if (reply.length) [self showReply:reply];
    if (self.animating) [self advanceTo:[self now]];
}
- (void)showReply:(NSString *)text {
    if (![text isKindOfClass:NSString.class] || !text.length) return;
    self.menuOpen=NO;self.bubble=text;self.bubbleUntil=[self now]+2.5;self.needsDisplay=YES;
}
- (NSRect)petDrawingRect {
    if(self.pc2005Enabled){CGFloat width=36;CGFloat center=WGClamp(self.petX,19,MAX(19,self.bounds.size.width-19));return NSMakeRect(center-width*.5,.5,width,29);}
    WGSprite *sprite=self.sprites[self.currentState]?:self.sprites[@"idle"];
    CGFloat scale=self.spriteScale;
    CGFloat width=sprite.contentSize.width*scale,height=sprite.contentSize.height*scale;
    width=MAX(1,width);height=MAX(1,height);
    return NSMakeRect(self.petX-width*.5,1,width,height);
}
- (NSRect)petHitRect {
    NSRect rect=[self petDrawingRect];
    return NSMakeRect(self.petX-MAX(44,rect.size.width)*.5,0,MAX(44,rect.size.width),self.bounds.size.height);
}
- (NSArray<NSValue *> *)menuRects {
    CGFloat total=272,width=self.bounds.size.width,preferred=self.petX+29;
    if (preferred+total>width-4) preferred=self.petX-29-total;
    CGFloat x=WGClamp(preferred,4,MAX(4,width-total-4));
    NSRect girl=NSInsetRect([self petDrawingRect],-5,0),cat=NSInsetRect([self companionDrawingRect],-7,0);
    NSArray *positions=@[@(x),@(self.petX-29-total),@(NSMaxX(girl)+4),@(NSMinX(girl)-total-4),@(NSMaxX(cat)+4),@(NSMinX(cat)-total-4),@4,@(width-total-4)];
    CGFloat bestDistance=HUGE_VAL;
    for (NSNumber *position in positions) {
        CGFloat candidate=WGClamp(position.doubleValue,4,MAX(4,width-total-4));
        NSRect rect=NSMakeRect(candidate,2,total,26);
        if (!NSIntersectsRect(rect,girl)&&!NSIntersectsRect(rect,cat)&&fabs(candidate-preferred)<bestDistance) {
            x=candidate;bestDistance=fabs(candidate-preferred);
        }
    }
    return @[[NSValue valueWithRect:NSMakeRect(x,2,65,26)],
             [NSValue valueWithRect:NSMakeRect(x+69,2,65,26)],
             [NSValue valueWithRect:NSMakeRect(x+138,2,65,26)],
             [NSValue valueWithRect:NSMakeRect(x+207,2,65,26)]];
}
- (void)savePetPosition {
    if (!self.persistsPosition || self.bounds.size.width<=0) return;
    [NSUserDefaults.standardUserDefaults setDouble:WGClamp(self.petX/self.bounds.size.width,0,1) forKey:WGPositionKey];
}
- (void)setFrameSize:(NSSize)newSize {
    if (self.duoKind.length) [self cancelDuoStory];
    CGFloat oldWidth=self.bounds.size.width;
    CGFloat ratio=oldWidth>0?self.petX/oldWidth:.5;
    [super setFrameSize:newSize];
    self.petX=WGClamp(ratio*newSize.width,24,MAX(24,newSize.width-24));
    if (oldWidth>0) self.companionX=WGClamp(self.companionX/oldWidth*newSize.width,16,MAX(16,newSize.width-16));
    if (oldWidth>0&&[self.companionActivity isEqualToString:@"roam"])
        self.companionTarget=WGClamp(self.companionTarget/oldWidth*newSize.width,[self companionSize].width*.5+3,MAX([self companionSize].width*.5+3,newSize.width-[self companionSize].width*.5-3));
    self.companionLastPetX=self.petX;[self constrainCompanion];
}
- (void)noteUserTouch {
    [self accountVisibleTo:[self now]];
    self.lastUserVisible=self.visibleElapsed;self.nextAutonomyAt=self.visibleElapsed+5;
    [self cancelDuoStory];
    [self cancelCompanionPlay];
}
- (void)pointerDownAt:(NSPoint)point {
    [self.pcAnimation setLocomoting:NO time:self.visibleElapsed];self.pcLastMovingAt=-100;
    [self.pcAnimation cancelManualPlayback];
    self.pcThrowVelocity=0;self.pcDragVelocity=0;self.pcDragAt=[self now];self.pcManualUntil=0;
    [self noteUserTouch];[self stopBehavior];self.walkUntil=0;
    self.pressedButton=-1;self.backgroundPressed=NO;self.companionPressed=NO;
    if (self.menuOpen) {
        NSArray *rects=[self menuRects];
        for (NSInteger i=0;i<(NSInteger)rects.count;i++) if (NSPointInRect(point,[rects[i] rectValue])) { [self stopBehavior];self.walkUntil=0;self.pressedButton=i;return; }
    }
    if (!self.menuOpen && NSPointInRect(point,[self companionHitRect]) && !NSPointInRect(point,[self petHitRect])) {
        [self stopBehavior];self.walkUntil=0;self.companionPressed=YES;self.companionTouchMoved=NO;self.pressPoint=point;
        [self recordInteractionFromSleep:NO];return;
    }
    if (!NSPointInRect(point,[self petHitRect])) {
        BOOL dismissedMenu=self.menuOpen;
        self.menuOpen=NO;self.backgroundPressed=YES;self.backgroundMoved=dismissedMenu;self.pressPoint=point;
        self.needsDisplay=YES;return;
    }
    self.interactionFromSleep=[self.currentState isEqualToString:@"sleep"];
    [self stopBehavior];self.walkUntil=0;
    self.pressed=YES;self.dragging=NO;self.moved=NO;self.longPressFired=NO;self.pressedAt=[self now];
    self.pressPoint=point;self.pressOffset=point.x-self.petX;self.lastPointerX=point.x;
    [self recordInteractionFromSleep:NO];
}
- (void)pointerMovedTo:(NSPoint)point {
    if (self.pressed||self.companionPressed||self.backgroundPressed||self.pressedButton>=0) [self noteUserTouch];
    if (self.companionPressed) { if (fabs(point.x-self.pressPoint.x)+fabs(point.y-self.pressPoint.y)>6) self.companionTouchMoved=YES;return; }
    if (self.backgroundPressed) { if (fabs(point.x-self.pressPoint.x)+fabs(point.y-self.pressPoint.y)>6) self.backgroundMoved=YES;return; }
    if (!self.pressed) return;
    if (fabs(point.x-self.pressPoint.x)+fabs(point.y-self.pressPoint.y)>6) {
        self.moved=YES;self.dragging=YES;self.menuOpen=NO;[self stopBehavior];
        self.transient=nil;self.transientUntil=0;self.joyUntil=0;
    }
    if (self.dragging) {
        if (fabs(point.x-self.lastPointerX)>.1) self.facing=point.x<self.lastPointerX?1:-1;
        self.petX=WGClamp(point.x-self.pressOffset,24,MAX(24,self.bounds.size.width-24));[self advanceTo:[self now]];
    }
    NSTimeInterval pointerNow=[self now],pointerDelta=pointerNow-self.pcDragAt;
    if(self.dragging&&pointerDelta>.001&&pointerDelta<.25)self.pcDragVelocity=WGClamp(.35*self.pcDragVelocity+.65*(point.x-self.lastPointerX)/pointerDelta,-650,650);
    self.pcDragAt=pointerNow;self.lastPointerX=point.x;
}
- (void)pointerUpAt:(NSPoint)point {
    if (self.pressed||self.companionPressed||self.backgroundPressed||self.pressedButton>=0) [self noteUserTouch];
    if (self.companionPressed) {
        self.companionPressed=NO;
        // The cat only walks and runs. A tap acknowledges the touch without starting a game.
        if (!self.companionTouchMoved && NSPointInRect(point,[self companionHitRect])) [self recordInteractionFromSleep:NO];
        self.needsDisplay=YES;return;
    }
    if (self.backgroundPressed) {
        self.backgroundPressed=NO;
        if (!self.backgroundMoved) {
            [self stopBehavior];[self recordInteractionFromSleep:[self.currentState isEqualToString:@"sleep"]];
            self.transient=nil;self.behaviorTarget=WGClamp(point.x,24,MAX(24,self.bounds.size.width-24));
            self.starX=self.behaviorTarget;
            [self beginBehavior:@"chase" user:YES duration:MIN(7,MAX(2,fabs(self.behaviorTarget-self.petX)/90+1))];
            self.starUntilVisible=self.behaviorUntil;[self advanceTo:[self now]];
        }
        return;
    }
    if (self.pressedButton>=0) {
        NSInteger button=self.pressedButton;self.pressedButton=-1;
        if (button<4 && NSPointInRect(point,[[self menuRects][button] rectValue])) [self performAction:@[@"feed",@"play",@"pet",@"dance"][button]];
        return;
    }
    if (!self.pressed) return;
    self.pressed=NO;self.dragging=NO;
    if (self.moved) {
        [self savePetPosition];self.dragReleaseUntil=[self now]+1.5;
        [self recordInteractionFromSleep:self.interactionFromSleep];
        if(self.pc2005Enabled&&[self now]-self.pcDragAt<.1&&fabs(self.pcDragVelocity)>120){self.pcThrowVelocity=self.pcDragVelocity;self.pcThrowUntil=self.visibleElapsed+2.5;}
        self.moved=NO;[self advanceTo:[self now]];
    } else if (self.longPressFired) {
        self.longPressFired=NO;[self recordInteractionFromSleep:NO];
    } else {
        [self recordInteractionFromSleep:self.interactionFromSleep];[self performAction:@"toggle-menu"];
    }
}
- (void)abortPointer {
    if (self.pressed||self.companionPressed||self.backgroundPressed||self.pressedButton>=0) [self noteUserTouch];
    self.pressedButton=-1;self.backgroundPressed=NO;self.longPressFired=NO;self.companionPressed=NO;
    if (self.pressed || self.dragging) {
        BOOL moved=self.moved;
        self.pressed=NO;self.dragging=NO;self.moved=NO;
        if (moved) { self.dragReleaseUntil=[self now]+1.5;[self recordInteractionFromSleep:self.interactionFromSleep]; }
        [self advanceTo:[self now]];
    }
}
- (void)mouseDown:(NSEvent *)event { [self pointerDownAt:[self convertPoint:event.locationInWindow fromView:nil]]; }
- (void)mouseDragged:(NSEvent *)event { [self pointerMovedTo:[self convertPoint:event.locationInWindow fromView:nil]]; }
- (void)mouseUp:(NSEvent *)event { [self pointerUpAt:[self convertPoint:event.locationInWindow fromView:nil]]; }
- (NSPoint)locationForTouch:(NSTouch *)touch {
    return touch.type==NSTouchTypeDirect?[touch locationInView:self]:NSMakePoint(touch.normalizedPosition.x*self.bounds.size.width,touch.normalizedPosition.y*self.bounds.size.height);
}
- (void)touchesBeganWithEvent:(NSEvent *)event {
    NSTouch *touch=[[event touchesMatchingPhase:NSTouchPhaseBegan inView:self] anyObject];
    if (touch) [self pointerDownAt:[self locationForTouch:touch]];
}
- (void)touchesMovedWithEvent:(NSEvent *)event {
    NSTouch *touch=[[event touchesMatchingPhase:NSTouchPhaseMoved inView:self] anyObject];
    if (touch) [self pointerMovedTo:[self locationForTouch:touch]];
}
- (void)touchesEndedWithEvent:(NSEvent *)event {
    NSTouch *touch=[[event touchesMatchingPhase:NSTouchPhaseEnded inView:self] anyObject];
    if (touch) [self pointerUpAt:[self locationForTouch:touch]];
}
- (void)touchesCancelledWithEvent:(NSEvent *)event { [self abortPointer]; }
- (BOOL)accessibilityPerformPress { [self performAction:@"toggle-menu"];return YES; }

- (NSTimeInterval)waterTime { return self.fixedTime>=0?self.fixedTime:self.visibleElapsed; }
- (NSString *)companionBehavior {
    if (self.menuOpen||self.companionPressed||fabs(self.companionSpeed)<3) return @"idle";
    return fabs(self.companionSpeed)>=115?@"run":@"walk";
}
- (NSSize)companionSize { return NSMakeSize(27.36,18.72); }
- (NSRect)companionDrawingRect {
    NSSize size=[self companionSize];
    NSTimeInterval phase=self.fixedTime>=0?self.fixedTime:self.companionPhase;
    // The running cat makes small bounds-safe hops; its resting pose stays still.
    CGFloat hop=[self.companionBehavior isEqualToString:@"run"]?fabs(sin(phase*12))*2:0;
    return NSMakeRect(self.companionX-size.width*.5,1+hop,size.width,size.height);
}
- (NSRect)companionHitRect {
    return NSMakeRect(self.companionX-20,0,40,self.bounds.size.height);
}
- (BOOL)isCompanionXSafe:(CGFloat)x menu:(NSRect)menu {
    CGFloat half=[self companionSize].width*.5;
    if (x-half<3||x+half>self.bounds.size.width-3) return NO;
    NSRect rect=NSMakeRect(x-half,1,half*2,28);
    return NSIsEmptyRect(menu)||!NSIntersectsRect(NSInsetRect(rect,-4,0),menu);
}
- (void)constrainCompanion {
    // Layout/resize safety only: never move the cat across the girl to enforce a gap.
    // Direction reversals instead use the same bounded walking path as normal following.
    CGFloat half=[self companionSize].width*.5;
    self.companionX=WGClamp(self.companionX,half+3,MAX(half+3,self.bounds.size.width-half-3));
}
- (CGFloat)nextCompanionRandom {
    // Keep the cat's curiosity independent of the girl's existing story sequence.
    uint32_t x=self.companionRandomState?:1;x^=x<<13;x^=x>>17;x^=x<<5;
    self.companionRandomState=x;
    return (x%1000000)/1000000.0;
}
- (void)cancelCompanionPlay {
    self.companionActivity=@"follow";self.companionActivityUntil=0;
    self.companionNextTargetAt=0;
    self.nextCompanionRoamAt=self.visibleElapsed+8+[self nextCompanionRandom]*8;
}
- (void)chooseCompanionPlayTarget {
    CGFloat half=[self companionSize].width*.5,low=half+3,high=MAX(low,self.bounds.size.width-half-3);
    CGFloat distance=150+[self nextCompanionRandom]*110;
    self.companionTarget=WGClamp(self.companionRoamAnchor+self.companionRoamSide*distance,low,high);
    self.companionTravelSpeed=[self nextCompanionRandom]<.45?85:170;
    self.companionNextTargetAt=self.visibleElapsed+1.1+[self nextCompanionRandom]*1.2;
}
- (void)beginCompanionPlay {
    self.companionActivity=@"roam";
    self.companionActivityUntil=self.visibleElapsed+4+[self nextCompanionRandom]*4;
    self.companionRoamAnchor=self.petX;
    CGFloat left=self.petX-24,right=self.bounds.size.width-24-self.petX;
    self.companionRoamSide=[self nextCompanionRandom]<.5?-1:1;
    if((self.companionRoamSide<0?left:right)<150) self.companionRoamSide=-self.companionRoamSide;
    [self chooseCompanionPlayTarget];
}
- (void)updateCompanionAt:(NSTimeInterval)now dt:(CGFloat)dt {
    if (!self.animating) return;
    CGFloat movement=self.petX-self.companionLastPetX;
    self.companionLastPetX=self.petX;
    if (fabs(movement)>.05) self.companionFollowDirection=movement>0?1:-1;
    if (!self.companionFollowDirection) self.companionFollowDirection=self.companionX<self.petX?1:-1;
    self.companionPhase=self.visibleElapsed;
    if (self.duoKind.length) return;
    BOOL touching=self.pressed||self.dragging||self.menuOpen||self.companionPressed||self.pressedButton>=0||self.backgroundPressed;
    if ((!self.autonomousEnabled||touching)&&![self.companionActivity isEqualToString:@"follow"]) [self cancelCompanionPlay];
    if (self.menuOpen||self.companionPressed||self.pressedButton>=0||self.backgroundPressed||(self.pressed&&!self.dragging)) { self.companionSpeed=0;return; }
    if (dt<=0) return;
    BOOL mayPlay=self.autonomousEnabled&&self.companionRoamingEnabled&&!touching&&self.visibleElapsed-self.lastUserVisible>5;
    if ([self.companionActivity isEqualToString:@"follow"]&&mayPlay&&self.visibleElapsed>=self.nextCompanionRoamAt) [self beginCompanionPlay];
    if ([self.companionActivity isEqualToString:@"roam"]&&self.visibleElapsed>=self.companionActivityUntil) self.companionActivity=@"return";
    if ([self.companionActivity isEqualToString:@"rest"]&&self.visibleElapsed>=self.companionActivityUntil) {
        self.companionActivity=@"follow";
        self.nextCompanionRoamAt=self.visibleElapsed+8+[self nextCompanionRandom]*8;
    }
    CGFloat half=[self companionSize].width*.5;
    CGFloat target=WGClamp(self.petX-self.companionFollowDirection*60,half+3,MAX(half+3,self.bounds.size.width-half-3));
    BOOL roaming=[self.companionActivity isEqualToString:@"roam"];
    BOOL returning=[self.companionActivity isEqualToString:@"return"];
    if(roaming) {
        if(self.visibleElapsed>=self.companionNextTargetAt||fabs(self.companionTarget-self.companionX)<3) [self chooseCompanionPlayTarget];
        target=self.companionTarget;
    }
    CGFloat delta=target-self.companionX;
    if (fabs(delta)<.6) {
        self.companionX=target;self.companionSpeed=0;
        if(returning) {
            self.companionActivity=@"rest";
            self.companionActivityUntil=self.visibleElapsed+2+[self nextCompanionRandom]*2;
        }
        return;
    }
    CGFloat girlSpeed=fabs(movement)/dt;
    BOOL catchingUp=self.dragging||girlSpeed>115||fabs(delta)>100||returning;
    CGFloat limit=roaming?self.companionTravelSpeed:(catchingUp?520:110);
    CGFloat wanted;
    if(roaming) wanted=copysign(MIN(limit,MAX(22,fabs(delta)*6)),delta);
    else if(returning) wanted=copysign(MIN(limit,MAX(120,fabs(delta)*6+girlSpeed)),delta);
    else wanted=copysign(MIN(limit,MAX(22,fabs(delta)*6+girlSpeed*.85)),delta);
    CGFloat acceleration=catchingUp&&!roaming?2800:1000;
    self.companionSpeed+=WGClamp(wanted-self.companionSpeed,-acceleration*dt,acceleration*dt);
    CGFloat step=self.companionSpeed*dt;
    if (step*delta>0&&fabs(step)>=fabs(delta)) { step=delta;self.companionSpeed=0; }
    CGFloat next=WGClamp(self.companionX+step,half+3,MAX(half+3,self.bounds.size.width-half-3));
    if (fabs(next-self.companionX)>.05) self.companionFacing=next>self.companionX?1:-1;
    self.companionX=next;
    if(returning&&fabs(target-next)<.6) {
        self.companionActivity=@"rest";
        self.companionActivityUntil=self.visibleElapsed+2+[self nextCompanionRandom]*2;
    }
}
- (void)drawWater {
    // Harness website: .harness-site[data-theme=dark] --ds-color-bg-page: #0a0a0a.
    [WGColor(10.0/255,10.0/255,10.0/255,1) setFill];
    NSRectFill(self.bounds);
    NSTimeInterval t=[self waterTime];CGFloat width=NSWidth(self.bounds),height=NSHeight(self.bounds);
    for(NSInteger row=0;row<3;row++) {
        NSBezierPath *wave=[NSBezierPath bezierPath];
        for(CGFloat x=0;x<=width+12;x+=12) {
            CGFloat y=height*(.16+row*.31)+sin(x/55+t*(.7+row*.13)+row)*(.8+row*.15);
            if(x==0)[wave moveToPoint:NSMakePoint(x,y)];else[wave lineToPoint:NSMakePoint(x,y)];
        }
        [WGColor(1,1,1,.10+row*.025) setStroke];wave.lineWidth=.6;[wave stroke];
    }
    NSInteger count=MAX(5,(NSInteger)(width/72));
    for(NSInteger i=0;i<count;i++) {
        CGFloat x=fmod(i*73.1+sin(t*.25+i)*8+width,width),y=fmod(i*11.7+t*(2.5+(i%3)*.5),height+5)-2;
        CGFloat size=1.3+(i%3)*.6;
        NSBezierPath *bubble=[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x,y,size,size)];
        [WGColor(1,1,1,.35) setStroke];bubble.lineWidth=.5;[bubble stroke];
    }

}


- (NSString *)duoStory { return self.duoKind?:@"none"; }
- (NSString *)duoPhase { return self.duoStage?:@"none"; }
- (CGFloat)nextDuoRandom {
    uint32_t x=self.duoRandomState?:1;x^=x<<13;x^=x>>17;x^=x<<5;
    self.duoRandomState=x;return (x%1000000)/1000000.0;
}
- (NSTimeInterval)duoAge { return MAX(0,self.visibleElapsed-self.duoStarted); }
- (void)cancelDuoStory {
    self.duoUserRequested=NO;
    if (!self.duoKind.length) return;
    self.lastDuoKind=self.duoKind;self.duoKind=nil;self.duoStage=nil;
    self.duoPetMoving=NO;self.duoGirlDepth=0;self.duoCatHop=0;self.companionSpeed=0;
    self.nextDuoAt=self.visibleElapsed+12+[self nextDuoRandom]*10;
    self.nextAutonomyAt=MAX(self.nextAutonomyAt,self.visibleElapsed+.6);
    [self cancelCompanionPlay];
}
- (CGFloat)duoBound:(CGFloat)x cat:(BOOL)cat {
    CGFloat margin=cat?[self companionSize].width*.5+3:24;
    return WGClamp(x,margin,MAX(margin,self.bounds.size.width-margin));
}
- (void)beginDuoStory:(NSString *)kind {
    if (![@[@"block",@"dash",@"reunion"] containsObject:kind]) return;
    [self cancelCompanionPlay];self.duoUserRequested=NO;
    self.duoKind=kind;self.duoStage=nil;self.duoStarted=self.visibleElapsed;
    self.duoDuration=[kind isEqualToString:@"reunion"]?21:20;
    // Prefer the longer route: a full block story needs up to 459pt.
    // The initial walking stage lets the cat line up behind her first.
    CGFloat direction=self.petX<self.bounds.size.width*.5?1:-1;
    self.duoDirection=direction;self.duoOrigin=self.petX;
    self.duoGirlTarget=self.petX;self.duoCatTarget=self.companionX;
    self.duoQuickEnding=[self nextDuoRandom]<.5;
    self.duoPetMoving=NO;self.duoGirlDepth=0;self.duoCatHop=0;self.walkUntil=0;
}
- (NSString *)duoStageForAge:(CGFloat)age {
    if ([self.duoKind isEqualToString:@"block"]) {
        if(age<2.2)return @"approach";if(age<3.8)return @"blocked";if(age<6.4)return @"sidestep";
        if(age<9.4)return @"intercept";if(age<11.2)return @"standoff";
        if(age<15.2)return self.duoQuickEnding?@"breakaway":@"yield";
        if(age<17.2)return @"rejoin";return @"together";
    }
    if ([self.duoKind isEqualToString:@"dash"]) {
        if(age<2)return @"walk";if(age<4.5)return @"sprint";if(age<6.3)return @"wait";
        if(age<9.5)return @"catchup";if(age<12.5)return @"close";if(age<17.5)return @"together";return @"rest";
    }
    if(age<3)return @"depart";if(age<5)return @"notice";if(age<9)return @"return";
    if(age<12)return @"close";if(age<17)return @"rest";return @"stroll";
}
- (void)enterDuoStage:(NSString *)stage {
    self.duoStage=stage;CGFloat d=self.duoDirection,g=self.petX,c=self.companionX;
    self.duoGirlTarget=g;self.duoCatTarget=c;
    if ([self.duoKind isEqualToString:@"block"]) {
        if([stage isEqualToString:@"approach"]) {self.duoGirlTarget=self.duoOrigin+d*40;self.duoCatTarget=self.duoOrigin+d*74;}
        else if([stage isEqualToString:@"sidestep"]) self.duoGirlTarget=c+d*60;
        else if([stage isEqualToString:@"intercept"]) {self.duoGirlTarget=g+d*60;self.duoCatTarget=g+d*94;}
        else if([stage isEqualToString:@"breakaway"]) {self.duoGirlTarget=g+d*230;self.duoCatTarget=g+d*130;}
        else if([stage isEqualToString:@"yield"]) {self.duoGirlTarget=g+d*100;self.duoCatTarget=g-d*32;}
        else if([stage isEqualToString:@"rejoin"]) self.duoCatTarget=g-d*34;
        else if([stage isEqualToString:@"together"]) self.duoGirlTarget=g+d*35;
    } else if([self.duoKind isEqualToString:@"dash"]) {
        if([stage isEqualToString:@"walk"]) {self.duoGirlTarget=g+d*55;self.duoCatTarget=g+d*21;}
        else if([stage isEqualToString:@"sprint"]) {self.duoGirlTarget=g+d*300;self.duoCatTarget=g+d*170;}
        else if([@[@"wait",@"catchup",@"close"] containsObject:stage]) self.duoCatTarget=g-d*34;
        else if([stage isEqualToString:@"together"]) self.duoGirlTarget=g+d*65;
    } else {
        if([stage isEqualToString:@"depart"]) {self.duoGirlTarget=g-d*30;self.duoCatTarget=c+d*210;}
        else if([@[@"return",@"close",@"rest"] containsObject:stage]) self.duoCatTarget=g+d*30;
        else if([stage isEqualToString:@"stroll"]) self.duoGirlTarget=g-d*55;
    }
    self.duoGirlTarget=[self duoBound:self.duoGirlTarget cat:NO];
    self.duoCatTarget=[self duoBound:self.duoCatTarget cat:YES];
}
- (CGFloat)moveDuoActor:(CGFloat)x toward:(CGFloat)target speed:(CGFloat)speed dt:(CGFloat)dt cat:(BOOL)cat {
    target=[self duoBound:target cat:cat];CGFloat delta=target-x;
    return [self duoBound:x+copysign(MIN(fabs(delta),speed*dt),delta) cat:cat];
}
- (NSString *)duoState {
    if(self.duoPetMoving)return @"walk";
    if([@[@"blocked",@"standoff",@"notice",@"wait",@"catchup"] containsObject:self.duoStage])return @"think";
    if([self.duoStage isEqualToString:@"close"])return @"joy";
    return @"idle";
}
- (void)advanceDuoStoryAt:(NSTimeInterval)now dt:(CGFloat)dt {
    if (!self.duoKind.length || !self.animating) return;
    CGFloat age=[self duoAge],d=self.duoDirection;
    if(age>=self.duoDuration){[self cancelDuoStory];return;}
    NSString *stage=[self duoStageForAge:age];if(![stage isEqualToString:self.duoStage])[self enterDuoStage:stage];
    CGFloat girlSpeed=0,catSpeed=0;
    if([self.duoKind isEqualToString:@"block"]) {
        if([stage isEqualToString:@"approach"]){girlSpeed=50;catSpeed=155;}
        else if([stage isEqualToString:@"sidestep"])girlSpeed=75;
        else if([stage isEqualToString:@"intercept"]){girlSpeed=52;catSpeed=180;}
        else if([stage isEqualToString:@"breakaway"]){girlSpeed=185;catSpeed=82;}
        else if([stage isEqualToString:@"yield"]){girlSpeed=60;catSpeed=100;}
        else if([stage isEqualToString:@"rejoin"])catSpeed=200;
        else if([stage isEqualToString:@"together"]){girlSpeed=28;catSpeed=80;self.duoCatTarget=self.petX-d*34;}
    } else if([self.duoKind isEqualToString:@"dash"]) {
        if([stage isEqualToString:@"walk"]){girlSpeed=40;catSpeed=85;}
        else if([stage isEqualToString:@"sprint"]){girlSpeed=185;catSpeed=65;}
        else if([stage isEqualToString:@"wait"])catSpeed=65;
        else if([stage isEqualToString:@"catchup"])catSpeed=165;
        else if([stage isEqualToString:@"close"])catSpeed=55;
        else if([stage isEqualToString:@"together"]){girlSpeed=25;catSpeed=80;self.duoCatTarget=self.petX-d*34;}
    } else {
        if([stage isEqualToString:@"depart"]){girlSpeed=20;catSpeed=155;}
        else if([stage isEqualToString:@"return"])catSpeed=125;
        else if([@[@"close",@"rest"] containsObject:stage])catSpeed=45;
        else if([stage isEqualToString:@"stroll"]){girlSpeed=28;catSpeed=75;self.duoCatTarget=self.petX+d*34;}
    }
    CGFloat oldGirl=self.petX,oldCat=self.companionX;
    self.petX=[self moveDuoActor:oldGirl toward:self.duoGirlTarget speed:girlSpeed dt:dt cat:NO];
    self.companionX=[self moveDuoActor:oldCat toward:self.duoCatTarget speed:catSpeed dt:dt cat:YES];
    self.duoPetMoving=fabs(self.petX-oldGirl)>.02;
    if(self.duoPetMoving)self.facing=self.petX>oldGirl?-1:1;
    else self.facing=self.companionX>self.petX?-1:1;
    if([self.duoKind isEqualToString:@"reunion"]&&[stage isEqualToString:@"depart"])self.facing=d>0?1:-1;
    self.companionSpeed=dt>0?(self.companionX-oldCat)/dt:0;
    if(fabs(self.companionSpeed)>1)self.companionFacing=self.companionSpeed>0?1:-1;
    else self.companionFacing=self.petX>self.companionX?1:-1;
    self.companionLastPetX=self.petX;self.companionPhase=self.visibleElapsed;
    CGFloat near=WGClamp((43-fabs(self.petX-self.companionX))/12,0,1);
    BOOL passing=(girlSpeed>0||catSpeed>0)&&![@[@"close",@"rest",@"rejoin",@"catchup",@"wait"] containsObject:stage];
    CGFloat wantedDepth=passing?near:0;
    self.duoGirlDepth+=WGClamp(wantedDepth-self.duoGirlDepth,-dt*5,dt*5);
    self.duoCatHop=0;
    if([stage isEqualToString:@"standoff"])self.duoCatHop=MAX(0,sin((age-9.4)*M_PI*2))*1.5;
}
- (void)prepareDuoStoryPreview:(NSString *)kind elapsed:(NSTimeInterval)elapsed {
    if(![@[@"block",@"dash",@"reunion"] containsObject:kind])return;
    self.forcedState=nil;self.clockOverride=1000;self.visibleLastTick=1000;self.previousTick=1000;
    self.visibleElapsed=0;self.lastUserVisible=0;self.petX=self.bounds.size.width*.32;self.companionX=self.petX-60;
    self.companionLastPetX=self.petX;self.companionFollowDirection=1;self.companionSpeed=0;
    self.nextCuddleAt=HUGE_VAL;self.nextNapAt=HUGE_VAL;self.hungerAfter=HUGE_VAL;self.behavior=nil;
    self.duoRandomState=12345;self.animating=YES;[self beginDuoStory:kind];
    elapsed=WGClamp(elapsed,0,self.duoDuration-.05);
    for(NSTimeInterval t=0;t<elapsed;t+=1.0/30){self.clockOverride=1000+MIN(elapsed,t+1.0/30);[self advanceTo:self.clockOverride];}
    self.fixedTime=elapsed;[self.timer invalidate];self.timer=nil;_animating=NO;
}
- (void)drawCompanion {
    NSString *mode=self.companionBehavior;NSRect cat=[self companionDrawingRect];
    cat.origin.y=MIN(cat.origin.y+self.duoCatHop,self.bounds.size.height-cat.size.height-1);
    [CatCompanion drawInRect:cat facing:self.companionFacing>=0?1:-1 moving:![mode isEqualToString:@"idle"] running:[mode isEqualToString:@"run"] time:self.fixedTime>=0?self.fixedTime:self.companionPhase];
}

- (void)drawStoryProps {
    if (self.menuOpen) return;
    CGFloat age=self.visibleElapsed-self.behaviorStarted;
    if ([self.behavior isEqualToString:@"snack"]) {
        CGFloat side=self.companionX>self.petX?1:-1;
        CGFloat cycle=fmod(MAX(0,age),1.25)/1.25;
        NSArray *positions=@[@(self.petX+side*(NSWidth([self petDrawingRect])*.5+6))];
        for (NSNumber *value in positions) {
            CGFloat x=value.doubleValue,r=3.7-cycle*1.5,y=12+sin(cycle*M_PI)*2;
            [WGColor(.98,.76,.37,1) setFill];[[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x-r,y-r,r*2,r*2)] fill];
            [WGColor(.43,.24,.12,1) setFill];
            for (NSInteger i=0;i<3;i++) [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x+cos(i*2.1)*1.3-.5,y+sin(i*2.1)*1.3-.5,1,1)] fill];
            for (NSInteger i=0;i<2;i++) {
                [WGColor(1,.83,.5,(1-cycle)*.8) setFill];
                [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x+(i?1:-1)*(3+cycle*3),y-cycle*6,1.2,1.2)] fill];
            }
        }
    } else if ([self.behavior isEqualToString:@"sulk"]&&age>=.6&&fabs(self.behaviorTarget-self.petX)>.5) {
        CGFloat behind=self.behaviorTarget>self.petX?-1:1;
        for (NSInteger i=0;i<3;i++) {
            CGFloat x=self.petX+behind*(NSWidth([self petDrawingRect])*.5+6+i*4);
            if (x<4||x>self.bounds.size.width-4) continue;
            [WGColor(.75,.85,1,.35) setStroke];NSBezierPath *line=[NSBezierPath bezierPath];
            [line moveToPoint:NSMakePoint(x,8+i*6)];[line lineToPoint:NSMakePoint(x+behind*5,8+i*6)];line.lineWidth=.8;[line stroke];
        }
    }
}
- (void)prepareStoryPreview:(NSString *)story elapsed:(NSTimeInterval)elapsed {
    if (![@[@"run",@"play",@"dance",@"snack",@"sulk"] containsObject:story]) return;
    self.forcedState=nil;self.clockOverride=1000;self.visibleLastTick=1000;self.previousTick=1000;
    self.visibleElapsed=0;self.lastUserVisible=0;self.petX=self.bounds.size.width*.5;self.companionX=self.petX+60;self.companionLastPetX=self.petX;self.companionFollowDirection=-1;self.companionSpeed=0;
    self.nextCuddleAt=HUGE_VAL;self.nextNapAt=HUGE_VAL;self.hungerAfter=HUGE_VAL;
    self.animating=YES;[self beginBehavior:story user:NO duration:5];
    elapsed=WGClamp(elapsed,0,4.9);
    for (NSTimeInterval t=0;t<elapsed;t+=1.0/30) {self.clockOverride=1000+MIN(elapsed,t+1.0/30);[self advanceTo:self.clockOverride];}
    self.fixedTime=elapsed;[self.timer invalidate];self.timer=nil;_animating=NO;
}
- (NSRect)replyDrawingRect {
    NSDictionary *attrs=@{NSFontAttributeName:[NSFont systemFontOfSize:10]};
    NSString *text=self.bubble.length>32?[[self.bubble substringToIndex:31] stringByAppendingString:@"…"]:self.bubble;
    CGFloat wanted=[text sizeWithAttributes:attrs].width+12;
    NSRect actors=NSUnionRect([self petDrawingRect],[self companionDrawingRect]);
    CGFloat right=MAX(0,NSWidth(self.bounds)-4-NSMaxX(actors)-10);
    CGFloat left=MAX(0,NSMinX(actors)-14);
    BOOL useRight=right>=wanted || (left<wanted && right>=left);
    CGFloat width=MIN(wanted,useRight?right:left);
    width=MAX(1,width);
    CGFloat x=useRight?NSMaxX(actors)+10:NSMinX(actors)-10-width;
    return NSMakeRect(WGClamp(x,4,MAX(4,NSWidth(self.bounds)-width-4)),6,width,18);
}
- (void)drawHeartAt:(NSPoint)point alpha:(CGFloat)alpha {
    NSBezierPath *heart=[NSBezierPath bezierPath];
    [heart moveToPoint:NSMakePoint(point.x,point.y-2.5)];
    [heart curveToPoint:NSMakePoint(point.x-3,point.y+.8) controlPoint1:NSMakePoint(point.x-1,point.y-1) controlPoint2:NSMakePoint(point.x-4,point.y)];
    [heart curveToPoint:NSMakePoint(point.x,point.y+1.6) controlPoint1:NSMakePoint(point.x-3,point.y+3) controlPoint2:NSMakePoint(point.x-1,point.y+3)];
    [heart curveToPoint:NSMakePoint(point.x+3,point.y+.8) controlPoint1:NSMakePoint(point.x+1,point.y+3) controlPoint2:NSMakePoint(point.x+3,point.y+3)];
    [heart curveToPoint:NSMakePoint(point.x,point.y-2.5) controlPoint1:NSMakePoint(point.x+4,point.y) controlPoint2:NSMakePoint(point.x+1,point.y-1)];
    [WGColor(1,.5,.67,alpha) setFill];[heart fill];
}
- (void)drawRect:(NSRect)dirtyRect {
    [self drawWater];
    WGSprite *sprite=self.sprites[self.currentState]?:self.sprites[@"idle"];
    if (!sprite.frames.count) {
        [@"鲸鱼娘素材未加载" drawAtPoint:NSMakePoint(12,8) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:11],NSForegroundColorAttributeName:NSColor.secondaryLabelColor}];return;
    }
    NSTimeInterval now=[self now],t=[self waterTime];
    NSInteger frame=MAX(0,MIN((NSInteger)sprite.frames.count-1,self.frameIndex));
    if (self.fixedTime>=0) {
        NSString *mode=sprite.config[@"playback"];NSInteger step=(NSInteger)floor(t*MAX(1,WGNumber(sprite.config[@"fps"])));
        if ([mode isEqualToString:@"once"]) {
            NSArray *holds=sprite.config[@"frameMs"];
            if ([holds isKindOfClass:NSArray.class]) { double elapsed=t;frame=0;while(frame<(NSInteger)sprite.frames.count-1 && elapsed>=WGNumber(holds[frame])/1000.0){elapsed-=WGNumber(holds[frame])/1000.0;frame++;} }
            else frame=MIN((NSInteger)sprite.frames.count-1,step);
        } else if ([mode isEqualToString:@"blink"]) frame=0;
        else if ([mode isEqualToString:@"pingpong"] && sprite.frames.count>1) { NSInteger period=2*(sprite.frames.count-1),p=step%period;frame=p<(NSInteger)sprite.frames.count?p:period-p; }
        else frame=step%sprite.frames.count;
    }
    BOOL catInFront=self.duoKind.length&&self.duoGirlDepth>.01;
    if (!catInFront) [self drawCompanion];
    NSRect rect=[self petDrawingRect];
    NSString *motion=sprite.config[@"motion"];
    CGFloat dx=0,dy=0,rotation=0;
    if ([self.behavior isEqualToString:@"dance"]) { CGFloat age=self.fixedTime>=0?self.fixedTime:self.visibleElapsed-self.behaviorStarted;dx=sin(age*7)*1.1;dy=(1+sin(age*8))*.5;rotation=sin(age*5.5)*3; }
    if ([motion isEqualToString:@"float"]) dy=sin(t*2.4)*.6;
    else if ([motion isEqualToString:@"wiggle"]) rotation=sin(t*4)*2;
    else if ([motion isEqualToString:@"tilt"]) rotation=sin(t*11)*5;
    else if ([motion isEqualToString:@"shake"]) dx=sin(t*42)*.6;
    CGFloat drift=self.fixedTime>=0?self.fixedTime:self.companionPhase;
    dy+=sin(drift*1.7)*.4;rotation+=sin(drift*1.2)*1.1;
    if(self.pc2005Enabled){dx=0;dy=0;rotation=0;}
    CGFloat depthScale=self.pc2005Enabled?1:(1-.1*self.duoGirlDepth);
    rect.size.width*=depthScale;rect.size.height*=depthScale;
    if(!self.pc2005Enabled)dy+=self.duoGirlDepth*1.4;
    CGFloat radians=rotation*M_PI/180,bboxH=fabs(NSWidth(rect)*sin(radians))+fabs(NSHeight(rect)*cos(radians));
    CGFloat fit=MIN(1,(self.bounds.size.height-1)/MAX(1,bboxH));
    CGFloat centerY=WGClamp(NSMidY(rect)+dy,bboxH*fit*.5+.5,self.bounds.size.height-bboxH*fit*.5-.5);
    [NSGraphicsContext saveGraphicsState];
    NSAffineTransform *tr=[NSAffineTransform transform];
    [tr translateXBy:(self.pc2005Enabled?NSMidX(rect):self.petX)+dx yBy:centerY];
    [tr rotateByDegrees:rotation];[tr scaleXBy:self.facing*fit yBy:fit];[tr concat];
    NSRect local=NSMakeRect(-rect.size.width*.5,-rect.size.height*.5,rect.size.width,rect.size.height);
    if(self.pc2005Enabled){
        [self.pcAnimation drawInRect:local time:(self.fixedTime>=0?self.fixedTime:self.visibleElapsed) facing:1];
    } else {
    [sprite.frames[frame] drawInRect:local fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:NO hints:@{NSImageHintInterpolation:@(NSImageInterpolationHigh)}];
    }
    [NSGraphicsContext restoreGraphicsState];
    if (catInFront) [self drawCompanion];
    [self drawStoryProps];
    if (self.menuOpen) {
        NSArray *labels=@[@"🍗 投喂",@"🎾 一起玩",@"🐾 摸摸",@"♪ 跳舞"];
        NSArray *rects=[self menuRects];
        for(NSInteger i=0;i<(NSInteger)labels.count;i++) {
            NSRect r=[rects[i] rectValue];
            [(i==self.pressedButton?WGColor(.58,.81,.96,.98):WGColor(.96,.99,1,.94)) setFill];
            [[NSBezierPath bezierPathWithRoundedRect:r xRadius:5 yRadius:5] fill];
            NSDictionary *attrs=@{NSFontAttributeName:[NSFont systemFontOfSize:11 weight:NSFontWeightMedium],NSForegroundColorAttributeName:WGColor(.08,.23,.43,1)};
            NSSize size=[labels[i] sizeWithAttributes:attrs];
            [labels[i] drawAtPoint:NSMakePoint(NSMidX(r)-size.width*.5,NSMidY(r)-size.height*.5) withAttributes:attrs];
        }
    }
    if (self.starUntilVisible>self.visibleElapsed && !self.menuOpen) {
        NSBezierPath *star=[NSBezierPath bezierPath];
        for(NSInteger i=0;i<10;i++) { CGFloat a=M_PI*.5+i*M_PI/5,r=i%2?2:4.5;NSPoint point=NSMakePoint(self.starX+cos(a)*r,15+sin(a)*r);if(i==0)[star moveToPoint:point];else[star lineToPoint:point]; }
        [star closePath];[WGColor(1,.86,.35,.9) setFill];[star fill];
    }
    if (self.heartsUntil>now && !self.menuOpen) {
        for(NSInteger i=0;i<4;i++) {
            CGFloat phase=fmod(now*1.1+i*.25,1);
            [self drawHeartAt:NSMakePoint(self.petX-27+i*18,7+phase*19) alpha:(1-phase)*.8];
        }
    }
}

+ (NSDictionary *)runPCIntegrationTests {
    NSMutableArray *passed=[NSMutableArray new],*failed=[NSMutableArray new];
    void(^check)(BOOL,NSString*)=^(BOOL ok,NSString *name){[(ok?passed:failed) addObject:name];};
    WhaleScene *v=[[self alloc]initWithFrame:NSMakeRect(0,0,968,30) persistsPosition:NO];
    v.clockOverride=1000;v.pc2005Enabled=YES;
    check(v.pc2005Enabled&&v.pcAnimation!=nil,@"pc-original-assets-enable-native-renderer");
    NSArray *catalogue=[PCPetAnimation catalogue];NSString *action=catalogue.firstObject[@"id"];
    check(action.length&&[v playPCAction:action]&&v.pcManualUntil>v.visibleElapsed,@"catalogue-action-starts-full-duration-manual-playback");
    NSTimeInterval end=v.pcManualUntil;v.visibleElapsed=end-.1;[v advanceTo:1000.01];
    check([v.pcAnimation.currentAction isEqualToString:action],@"manual-animation-is-not-randomly-cut-short");
    check(![v playPCAction:@"unknown"],@"unknown-action-is-rejected");
    check(NSHeight([v petDrawingRect])<=30&&NSHeight([v companionDrawingRect])<20,@"girl-and-smaller-cat-fit-touchbar-height");
    [v performAction:@"feed"];check([v.pcAnimation.currentAction isEqualToString:@"snack"]&&v.pcManualUntil>=v.visibleElapsed+9,@"feeding-interrupts-old-selection-and-keeps-full-food-clip");
    [v performAction:@"dance"];check([v.pcAnimation.currentAction isEqualToString:@"dance"],@"dance-button-immediately-selects-original-dance");
    [v.pcAnimation cancelManualPlayback];v.pcManualUntil=0;v.transient=nil;v.joyUntil=0;[v stopBehavior];
    v.clockOverride=2000;v.previousTick=2000;v.visibleLastTick=2000;v.autonomousEnabled=NO;v.duoEnabled=NO;v.companionRoamingEnabled=NO;v.nextWalkAt=HUGE_VAL;v.animating=YES;
    v.petX=400;[v performAction:@"run"];v.behaviorTarget=650;
    v.clockOverride=2000.04;[v advanceTo:v.clockOverride];
    check(v.pcWalking&&v.facing<0,@"first-rightward-movement-tick-immediately-uses-side-running");
    v.behaviorTarget=200;v.clockOverride=2000.08;[v advanceTo:v.clockOverride];
    check(v.pcWalking&&v.facing>0,@"leftward-reversal-flips-side-pose-without-resetting-movement");
    [v stopBehavior];v.walkUntil=0;v.clockOverride=2000.2;[v advanceTo:v.clockOverride];
    check(!v.pcWalking,@"girl-stops-side-running-when-only-the-cat-is-moving");
    [v applyBackendSnapshot:@{@"activity":@{@"name":@"working",@"sessionThink":@YES},@"pcTaskState":@"working"}];
    [v performAction:@"run"];v.behaviorTarget=v.petX+100;v.clockOverride=2000.24;[v advanceTo:v.clockOverride];
    check(v.pcWalking&&v.facing<0,@"explicit-running-stays-sideways-even-while-dsh-is-busy");
    [v stopBehavior];v.walkUntil=0;v.facing=1;v.clockOverride=2000.25;[v advanceTo:v.clockOverride];
    check(v.pcWalking&&v.facing<0,@"short-stop-grace-keeps-the-last-true-movement-facing");

    v.animating=NO;v.fixedTime=0;[v playPCAction:@"idle"];
    NSRect stableRect=[v petDrawingRect];BOOL rectStable=YES;
    for(NSString *clip in @[@"idle",@"work",@"celebrate",@"snack",@"walk"]){[v playPCAction:clip];rectStable&=NSEqualRects(stableRect,[v petDrawingRect]);}
    check(rectStable,@"switching-props-and-work-clips-does-not-resize-the-body-box");
    NSData *(^pixels)(void)=^NSData *{
        NSBitmapImageRep *rep=[[NSBitmapImageRep alloc]initWithBitmapDataPlanes:NULL pixelsWide:1936 pixelsHigh:60 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
        NSGraphicsContext *context=[NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
        [NSGraphicsContext saveGraphicsState];NSGraphicsContext.currentContext=context;CGContextScaleCTM(context.CGContext,2,2);[v drawRect:v.bounds];[NSGraphicsContext restoreGraphicsState];
        return [NSData dataWithBytes:rep.bitmapData length:rep.bytesPerRow*rep.pixelsHigh];
    };
    [v playPCAction:@"idle"];v.duoGirlDepth=0;NSData *front=pixels();v.duoGirlDepth=1;NSData *behind=pixels();
    check([front isEqualToData:behind],@"actual-rendered-pixels-do-not-shrink-when-duo-depth-changes");
    v.pc2005Enabled=NO;check(!v.pc2005Enabled&&v.sprites.count==15,@"original-skin-remains-available");
    return @{@"passed":@(failed.count==0),@"checks":passed,@"failures":failed};
}

+ (NSDictionary *)runBehaviorTests {
    NSMutableArray *passed=[NSMutableArray new],*failed=[NSMutableArray new];
    void (^check)(BOOL,NSString *)=^(BOOL ok,NSString *name) { [(ok?passed:failed) addObject:name]; };
    WhaleScene *v=[[WhaleScene alloc] initWithFrame:NSMakeRect(0,0,620,30) persistsPosition:NO];
        v.duoEnabled=NO;
    v.autonomousEnabled=NO;
    v.companionRoamingEnabled=NO;v.clockOverride=1000;v.idleSince=1000;v.previousTick=1000;v.nextWalkAt=2000;
    check(v.sprites.count==15,@"all-15-original-sprite-sheets-loaded");
    [v pointerDownAt:NSMakePoint(v.petX,15)];[v pointerMovedTo:NSMakePoint(v.petX+3,15)];[v pointerUpAt:NSMakePoint(v.petX+3,15)];
    check(v.menuOpen&&!v.dragging,@"small-finger-motion-is-click-opens-menu");
    NSRect feed=[[v menuRects][0] rectValue];
    [v pointerDownAt:NSMakePoint(NSMidX(feed),15)];[v pointerUpAt:NSMakePoint(NSMidX(feed),15)];
    check([v.currentState isEqualToString:@"eat"]&&!v.menuOpen,@"feed-button-closes-menu-and-starts-eat");
    v.clockOverride=1001.51;[v advanceTo:1001.51];
    check([v.currentState isEqualToString:@"joy"],@"eat-finishes-into-joy");
    v.clockOverride=1003.2;[v advanceTo:1003.2];
    check([v.currentState isEqualToString:@"idle"],@"joy-expires-back-to-underlying-idle");
    CGFloat start=v.petX;
    [v pointerDownAt:NSMakePoint(start,15)];[v pointerMovedTo:NSMakePoint(start+6,15)];
    check(!v.dragging,@"six-point-motion-does-not-start-drag");
    [v pointerMovedTo:NSMakePoint(start+20,15)];
    check(v.dragging&&[v.currentState isEqualToString:@"drag"]&&fabs(v.petX-start-20)<.01,@"beyond-six-point-drag-follows-finger");
    [v pointerUpAt:NSMakePoint(start+20,15)];
    check(!v.dragging&&[v.currentState isEqualToString:@"idle"]&&!v.menuOpen,@"drop-buffers-idle-without-opening-menu");
    v.clockOverride=1070;v.nextWalkAt=2000;[v advanceTo:1070];
    check([v.currentState isEqualToString:@"sleep"],@"sixty-seconds-idle-sleeps");
    [v pointerDownAt:NSMakePoint(v.petX,15)];[v pointerUpAt:NSMakePoint(v.petX,15)];
    check([v.currentState isEqualToString:@"wake"]&&v.menuOpen,@"tapping-sleeper-wakes-and-opens-menu");
    v.clockOverride=1073.1;[v advanceTo:1073.1];
    check(![v.currentState isEqualToString:@"sleep"],@"wake-interaction-resets-idle-clock");
    v.menuOpen=NO;v.backendThink=YES;v.workingUntil=2000;v.clockOverride=1074;[v advanceTo:1074];
    check([v.currentState isEqualToString:@"think"],@"actual-session-think-overrides-idle");
    v.backendWait=YES;[v advanceTo:1074];
    check([v.currentState isEqualToString:@"wait"],@"approval-wait-overrides-thinking");
    [v applyBackendSnapshot:@{}];[v advanceTo:1074];
    check(!v.backendThink&&!v.backendWait&&[v.currentState isEqualToString:@"idle"],@"empty-backend-snapshot-clears-stale-task-mood");
    [v applyBackendSnapshot:@{@"activity":@{@"name":@"idle",@"sessionThink":@YES,@"sessionWait":@YES}}];[v advanceTo:1074];
    check([v.currentState isEqualToString:@"wait"],@"upstream-activity-session-fields-drive-real-mood");
    v.backendSnapshot=@{@"activity":@{@"name":@"error",@"until":@1078000}};[v advanceTo:1074];
    [v performAction:@"play"];
    check([v.currentState isEqualToString:@"error"],@"event-burst-keeps-upstream-priority-over-interaction");
    v.backendThink=NO;v.backendWait=NO;v.backendSnapshot=@{};v.transient=nil;v.joyUntil=0;
    [v setState:@"walk" now:1080];v.lastFrameAt=1080;
    [v advanceFramesAt:1080+1.0/6.0];NSInteger a=v.frameIndex;
    [v advanceFramesAt:1080+2.0/6.0];NSInteger b=v.frameIndex;
    [v advanceFramesAt:1080+3.0/6.0];NSInteger c=v.frameIndex;
    [v advanceFramesAt:1080+4.0/6.0];NSInteger d=v.frameIndex;
    check(a==1&&b==2&&c==1&&d==0,@"walk-manifest-pingpong-is-0-1-2-1-0");
    [v setState:@"wake" now:1090];v.lastFrameAt=1090;
    [v advanceFramesAt:1090.9];NSInteger early=v.frameIndex;
    [v advanceFramesAt:1091.01];NSInteger late=v.frameIndex;
    [v advanceFramesAt:1093];
    check(early==0&&late==1&&v.frameIndex==1,@"wake-holds-first-frame-one-second-then-last-frame");
    v.clockOverride=1200;v.transient=nil;v.joyUntil=0;v.backendSnapshot=@{};v.backendThink=NO;v.backendWait=NO;v.idleSince=1200;v.nextWalkAt=2000;
    [v performAction:@"toggle-menu"];v.clockOverride=1220;[v advanceTo:1220];
    check(v.menuOpen,@"menu-stays-open-until-user-dismisses");
    [v pointerDownAt:NSMakePoint(4,15)];
    check(!v.menuOpen,@"outside-touch-closes-menu");
    [v pointerUpAt:NSMakePoint(4,15)];
    v.petX=595;v.walkDirection=1;v.walkUntil=1230;v.previousTick=1220;v.nextWalkAt=2000;
    [v advanceTo:1220.08];
    check(v.walkUntil==0&&[v.currentState isEqualToString:@"idle"]&&v.nextWalkAt>=1238.08&&v.nextWalkAt<=1260.08,@"walk-stops-at-edge-and-reschedules-without-bouncing");
    v.petX=155;[v setFrameSize:NSMakeSize(1240,30)];
    check(fabs(v.petX-310)<.01&&!v.persistsPosition,@"normalized-position-scales-with-width-and-tests-disable-persistence");
    v.animating=YES;v.animating=NO;
    check(v.timer==nil,@"hidden-scene-stops-animation-timer");
    return @{@"passed":@(failed.count==0),@"checks":passed,@"failures":failed,@"loadedStates":@(v.sprites.count)};
}
+ (NSDictionary *)runAutonomyTests {
    NSMutableArray *passed=[NSMutableArray new],*failed=[NSMutableArray new],*instances=[NSMutableArray new];
    void (^check)(BOOL,NSString *)=^(BOOL ok,NSString *name) { [(ok?passed:failed) addObject:name]; };
    WhaleScene *(^make)(void)=^{
        WhaleScene *v=[[WhaleScene alloc] initWithFrame:NSMakeRect(0,0,620,30) persistsPosition:NO];
        v.duoEnabled=NO;
        v.companionRoamingEnabled=NO;v.clockOverride=1000;v.visibleLastTick=1000;v.previousTick=1000;v.idleSince=1000;
        v.nextAutonomyAt=5;v.nextCuddleAt=90;v.nextNapAt=600;v.animating=YES;[instances addObject:v];return v;
    };
    void (^step)(WhaleScene *,double)=^(WhaleScene *v,double clock) { v.clockOverride=clock;[v advanceTo:clock]; };
    WhaleScene *v=make();step(v,1004.99);
    check(v.behavior==nil,@"no-autonomous-action-before-five-idle-seconds");
    step(v,1005.01);
    check([v.behavior isEqualToString:@"run"],@"five-idle-seconds-start-paired-chase");
    v=make();step(v,1001);[v showReply:@"旧泡泡"];
    double visible=v.visibleElapsed,hunger=v.hungerVisible;
    v.animating=NO;step(v,7000);v.animating=YES;step(v,7001);
    check(fabs(v.visibleElapsed-visible-1)<.01&&fabs(v.hungerVisible-hunger-1)<.01,@"hidden-hours-add-no-visible-time-or-hunger");
    check(v.bubbleUntil==0&&v.behavior==nil,@"return-from-hidden-does-not-replay-old-bubble-or-action");
    v=make();v.nextAutonomyAt=HUGE_VAL;v.nextCuddleAt=HUGE_VAL;v.nextNapAt=HUGE_VAL;
    step(v,1240);
    check([v.currentBehavior isEqualToString:@"hungry"]&&[v.needsSummary containsString:@"饿"],@"four-visible-minutes-create-gentle-hunger-request");
    double nextReminder=v.nextHungerReminder;
    step(v,1244);v.nextAutonomyAt=HUGE_VAL;step(v,1300);
    check(nextReminder==720&&![v.behavior isEqualToString:@"hungry"],@"hunger-speech-has-eight-minute-cooldown-with-no-punishment");
    [v performAction:@"feed"];
    check(v.hungerVisible==0&&v.hungerAfter==720&&[v.bubble containsString:@"吃饱"]&&[v.needsSummary containsString:@"饱"],@"user-feeding-clears-hunger-and-thanks-user");
    v=make();[v beginBehavior:@"run" user:NO duration:5];CGFloat stationary=v.petX;
    [v pointerDownAt:NSMakePoint(v.petX,15)];step(v,1000.4);
    check(v.behavior==nil&&fabs(v.petX-stationary)<.01&&!v.dragging,@"finger-down-immediately-cancels-autonomous-run-and-freezes-position");
    [v pointerUpAt:NSMakePoint(v.petX,15)];v.nextAutonomyAt=0;step(v,1030);
    check(v.menuOpen&&v.behavior==nil&&fabs(v.petX-stationary)<.01,@"open-menu-is-never-stolen-by-autonomous-actions");
    v=make();[v beginBehavior:@"dance" user:NO duration:5];
    [v applyBackendSnapshot:@{@"activity":@{@"name":@"idle",@"sessionThink":@YES}}];
    check(v.behavior==nil&&[@[@"think",@"working"] containsObject:v.currentState],@"real-task-thinking-preempts-autonomous-entertainment");
    [v applyBackendSnapshot:@{@"activity":@{@"name":@"idle",@"sessionWait":@YES}}];
    check([v.currentState isEqualToString:@"wait"]&&v.behavior==nil,@"real-approval-wait-preempts-autonomous-entertainment");
    v=make();[v beginBehavior:@"nap" user:NO duration:12];step(v,1013);
    check([v.currentState isEqualToString:@"wake"],@"short-nap-automatically-starts-three-second-wake-transition");
    step(v,1016.1);
    check(![v.currentState isEqualToString:@"sleep"]&&v.behavior!=nil&&![v.behavior isEqualToString:@"nap"],@"short-nap-wakes-and-resumes-idle-pair-play");
    v=make();v.nextAutonomyAt=HUGE_VAL;v.nextCuddleAt=HUGE_VAL;v.hungerAfter=HUGE_VAL;
    step(v,1480);v.animating=NO;step(v,9000);v.animating=YES;v.nextAutonomyAt=HUGE_VAL;step(v,9001);
    check(v.behavior==nil&&v.visibleElapsed<600,@"hidden-wall-clock-hours-do-not-trigger-nap");
    step(v,9121);
    check([v.behavior isEqualToString:@"nap"]&&v.behaviorUntil-v.visibleElapsed>=12&&v.behaviorUntil-v.visibleElapsed<=20,@"long-visible-idleness-allows-only-bounded-twelve-to-twenty-second-nap");
    v=make();[v pointerDownAt:NSMakePoint(v.petX,15)];step(v,1000.66);
    check(v.longPressFired&&[v.currentState isEqualToString:@"joy"]&&v.heartsUntil>1000.66,@"holding-still-for-point-six-five-seconds-pets-with-hearts");
    [v pointerUpAt:NSMakePoint(v.petX,15)];
    check(!v.menuOpen,@"long-press-release-does-not-open-click-menu");
    v=make();CGFloat dragStart=v.petX;
    [v pointerDownAt:NSMakePoint(dragStart,15)];step(v,1000.2);[v pointerMovedTo:NSMakePoint(dragStart+20,15)];step(v,1001);
    check(v.dragging&&!v.longPressFired&&[v.currentState isEqualToString:@"drag"],@"dragging-past-six-points-never-becomes-long-press");
    [v pointerUpAt:NSMakePoint(v.petX,15)];
    v=make();CGFloat chaseStart=v.petX;
    [v pointerDownAt:NSMakePoint(24,15)];[v pointerUpAt:NSMakePoint(24,15)];step(v,1000.1);
    check([v.behavior isEqualToString:@"chase"]&&v.starUntilVisible>0&&v.petX<chaseStart,@"tapping-empty-strip-creates-star-and-pet-chases-touchpoint");
    v=make();__block NSInteger backendCalls=0;v.interactionHandler=^(NSString *action) { backendCalls++; };
    [v beginBehavior:@"play" user:NO duration:2.5];step(v,1000.5);[v performAction:@"dance"];
    check(backendCalls==0,@"autonomous-and-local-play-never-send-backend-interactions");
    [v performAction:@"play"];
    check(backendCalls==1,@"explicit-user-play-sends-exactly-one-backend-interaction");
    for(WhaleScene *instance in instances) instance.animating=NO;
    return @{@"passed":@(failed.count==0),@"checks":passed,@"failures":failed,
        @"timing":@{@"idlePairPlayAfterSeconds":@5,@"betweenPairActionsSeconds":@0.25,@"firstHungerVisibleSeconds":@240,@"hungerAfterFeedVisibleSeconds":@720,@"hungerReminderCooldownSeconds":@480,@"cuddleIntervalSeconds":@[@45,@120],@"napAfterVisibleIdleSeconds":@[@480,@720],@"napSeconds":@[@12,@20],@"longPressSeconds":@0.65}};
}

+ (NSDictionary *)runIdlePairTests {
    NSMutableArray *passed=[NSMutableArray new],*failed=[NSMutableArray new],*instances=[NSMutableArray new];
    void (^check)(BOOL,NSString *)=^(BOOL ok,NSString *name){[(ok?passed:failed) addObject:name];};
    WhaleScene *(^make)(CGFloat)=^(CGFloat width){
        WhaleScene *v=[[WhaleScene alloc] initWithFrame:NSMakeRect(0,0,width,30) persistsPosition:NO];
        v.duoEnabled=NO;
        v.companionRoamingEnabled=NO;v.clockOverride=1000;v.visibleLastTick=1000;v.previousTick=1000;v.idleSince=1000;
        v.nextCuddleAt=HUGE_VAL;v.nextNapAt=HUGE_VAL;v.hungerAfter=HUGE_VAL;v.storyRandomState=1;
        v.animating=YES;[instances addObject:v];return v;
    };
    void (^step)(WhaleScene *,double)=^(WhaleScene *v,double t){v.clockOverride=t;[v advanceTo:t];};
    WhaleScene *v=make(1004);step(v,1005);
    check(v.behavior==nil,@"exactly-five-seconds-still-waits");
    step(v,1005.01);
    check([v.behavior isEqualToString:@"run"],@"strictly-over-five-seconds-starts-chase");
    BOOL continuous=YES,safe=YES,smooth=YES,walk=NO,run=NO,modesOnly=YES;NSMutableArray *sequence=[NSMutableArray new];
    double previousStart=-1,gapStart=-1;NSUInteger runFrames=0;
    for(NSInteger frame=1;frame<=65*30;frame++) {
        double t=1005.01+frame/30.0;CGFloat oldGirl=v.petX,oldWhale=v.companionX;
        step(v,t);
        if (v.behavior) {
            if (v.behaviorStarted!=previousStart) [sequence addObject:v.behavior];
            previousStart=v.behaviorStarted;gapStart=-1;
        } else { if(gapStart<0)gapStart=t;continuous &= t-gapStart<=.3; }
        if ([v.behavior isEqualToString:@"run"]) {
            runFrames++;walk |= [v.companionBehavior isEqualToString:@"walk"];run |= [v.companionBehavior isEqualToString:@"run"];
        }
        smooth &= fabs(v.petX-oldGirl)<8&&fabs(v.companionX-oldWhale)<=520.0/30+.01;
        safe &= NSContainsRect(v.bounds,[v petDrawingRect])&&NSContainsRect(v.bounds,[v companionDrawingRect]);
        modesOnly &= [@[@"idle",@"walk",@"run"] containsObject:v.companionBehavior];
    }
    check(sequence.count>=10&&[sequence containsObject:@"run"]&&[sequence containsObject:@"play"]&&[sequence containsObject:@"dance"]&&[sequence containsObject:@"snack"]&&[sequence containsObject:@"sulk"],@"natural-frames-randomly-mix-five-story-types");
    check(continuous&&runFrames>100,@"pair-keeps-playing-with-only-quarter-second-transitions");
    check(walk&&run&&modesOnly,@"cat-only-walks-or-runs-through-girl-story-rounds");
    check(safe&&smooth,@"full-width-cat-follow-stays-in-bounds-without-teleport");
    v=make(920);step(v,1005.01);CGFloat stationary=v.petX;
    [v pointerDownAt:NSMakePoint(4,15)];step(v,1020);
    check(v.backgroundPressed&&v.behavior==nil&&fabs(v.petX-stationary)<.01,@"holding-water-stops-chase-even-after-five-seconds");
    [v pointerMovedTo:NSMakePoint(14,15)];[v pointerUpAt:NSMakePoint(14,15)];step(v,1024.99);
    check(v.behavior==nil,@"water-release-restarts-full-five-second-countdown");
    step(v,1025.01);check(v.behavior!=nil,@"idle-pair-resumes-after-water-release-countdown");
    [v pointerDownAt:NSMakePoint(v.companionX,15)];step(v,1035);
    check(v.companionPressed&&v.behavior==nil,@"holding-cat-blocks-autonomous-play");
    [v abortPointer];step(v,1039.99);
    check(v.behavior==nil,@"cancelled-touch-also-restarts-idle-countdown");
    step(v,1040.01);check(v.behavior!=nil,@"autonomy-resumes-five-seconds-after-touch-cancel");
    [v performAction:@"toggle-menu"];step(v,1060);
    check(v.menuOpen&&v.behavior==nil,@"open-menu-remains-still-during-long-idle");
    [v performAction:@"close-menu"];step(v,1064.99);
    check(v.behavior==nil,@"closing-menu-restarts-idle-countdown");
    step(v,1065.01);check(v.behavior!=nil,@"pair-resumes-after-closing-menu");
    __block NSUInteger calls=0;v.interactionHandler=^(NSString *action){calls++;};
    for(NSInteger frame=1;frame<=20*30;frame++)step(v,1065.01+frame/30.0);
    check(calls==0,@"continuous-idle-games-send-no-backend-actions");
    v=make(1004);[v performAction:@"toggle-menu"];
    [v pointerDownAt:NSMakePoint(4,15)];step(v,1015);
    check(!v.menuOpen&&v.backgroundPressed&&v.behavior==nil,@"outside-menu-touch-stays-paused-until-release");
    [v pointerUpAt:NSMakePoint(4,15)];step(v,1019.99);
    check(v.behavior==nil,@"dismiss-menu-release-waits-full-five-seconds");
    step(v,1020.01);check([v.behavior isEqualToString:@"run"],@"outside-menu-release-resumes-pair-after-five-seconds");
    for(WhaleScene *instance in instances)instance.animating=NO;
    return @{@"passed":@(failed.count==0),@"checks":passed,@"failures":failed,@"observedSequence":sequence};
}

+ (NSDictionary *)runStoryTests {
    NSMutableArray *passed=[NSMutableArray new],*failed=[NSMutableArray new],*instances=[NSMutableArray new];
    void (^check)(BOOL,NSString *)=^(BOOL ok,NSString *name){[(ok?passed:failed) addObject:name];};
    WhaleScene *(^make)(void)=^{
        WhaleScene *v=[[WhaleScene alloc] initWithFrame:NSMakeRect(0,0,1004,30) persistsPosition:NO];
        v.duoEnabled=NO;
        v.companionRoamingEnabled=NO;v.clockOverride=1000;v.visibleLastTick=1000;v.previousTick=1000;v.idleSince=1000;
        v.nextCuddleAt=HUGE_VAL;v.nextNapAt=HUGE_VAL;v.hungerAfter=HUGE_VAL;v.storyRandomState=1;
        v.animating=YES;[instances addObject:v];return v;
    };
    void (^advance)(WhaleScene *,double)=^(WhaleScene *v,double duration){
        double start=v.clockOverride;
        for (NSInteger i=1;i<=(NSInteger)ceil(duration*30);i++) {v.clockOverride=start+MIN(duration,i/30.0);[v advanceTo:v.clockOverride];}
    };
    WhaleScene *v=make();[v beginBehavior:@"run" user:NO duration:5];advance(v,4.99);
    check([v.behavior isEqualToString:@"run"],@"chasing-keeps-full-five-second-round-even-after-turning");
    advance(v,.02);check(v.behavior==nil,@"story-round-ends-after-five-seconds");
    advance(v,.27);check(v.behavior!=nil&&fabs(v.behaviorUntil-v.behaviorStarted-5)<.001,@"next-random-round-also-lasts-five-seconds");
    NSMutableSet *seen=[NSMutableSet new];BOOL repeats=NO;NSString *previous=nil;
    v=make();v.hasAutonomousAction=YES;
    for (NSInteger i=0;i<512;i++) {NSString *name=[v nextIdleStory];[seen addObject:name];repeats |= [previous isEqualToString:@"run"]&&[name isEqualToString:@"run"];previous=name;}
    check(seen.count==5&&[seen containsObject:@"sulk"]&&[seen containsObject:@"snack"],@"seeded-random-selection-reaches-all-five-stories");
    check(repeats,@"random-selection-allows-continued-chasing");
    v=make();__block NSUInteger calls=0;v.interactionHandler=^(NSString *action){calls++;};
    v.hungerVisible=100;[v beginBehavior:@"snack" user:NO duration:5];advance(v,2);
    check([v.currentState isEqualToString:@"eat"]&&[v.companionBehavior isEqualToString:@"idle"],@"girl-snacks-while-cat-waits-without-eating");
    check(calls==0&&!v.hasBeenFed&&v.hungerVisible>=100,@"autonomous-snacks-do-not-send-feeding-or-reset-user-hunger");
    v=make();[v beginBehavior:@"sulk" user:NO duration:5];advance(v,.59);
    check([v.currentState isEqualToString:@"disappointed"],@"sulk-begins-with-brief-grumpy-pose");
    CGFloat girl=v.petX,cat=v.companionX;advance(v,1);
    check(girl-v.petX>190&&cat-v.companionX>150&&fabs(v.companionX-v.petX)<100,@"cat-runs-fast-enough-to-follow-girl-sulk-dash");
    BOOL safe=YES,smooth=YES,modesOnly=YES;
    for(NSInteger i=0;i<98;i++) {
        CGFloat oldGirl=v.petX,oldWhale=v.companionX;advance(v,1.0/30);
        safe &= v.petX<v.companionX&&NSContainsRect(v.bounds,[v petDrawingRect])&&NSContainsRect(v.bounds,[v companionDrawingRect]);
        smooth &= fabs(v.petX-oldGirl)<=7.01&&fabs(v.companionX-oldWhale)<=520.0/30+.01;
    }
    check([v.behavior isEqualToString:@"sulk"]&&[v.currentState isEqualToString:@"disappointed"]&&fabs(fabs(v.companionX-v.petX)-60)<1&&!NSIntersectsRect([v petDrawingRect],[v companionDrawingRect]),@"cat-catches-up-and-waits-beside-girl-at-edge");
    check(safe&&smooth,@"sulk-dash-keeps-both-characters-in-bounds-without-teleport");
    [v beginBehavior:@"run" user:NO duration:5];
    for(NSInteger i=0;i<140;i++) {
        CGFloat oldGirl=v.petX,oldWhale=v.companionX;advance(v,1.0/30);
        safe &= NSContainsRect(v.bounds,[v petDrawingRect])&&NSContainsRect(v.bounds,[v companionDrawingRect]);
        modesOnly &= [@[@"idle",@"walk",@"run"] containsObject:v.companionBehavior];
        smooth &= fabs(v.petX-oldGirl)<8&&fabs(v.companionX-oldWhale)<=520.0/30+.01;
    }
    check(safe&&smooth&&modesOnly,@"cat-follows-next-run-without-special-escape-or-lead-mode");
    v=make();v.petX=50;v.companionX=126;[v beginBehavior:@"sulk" user:NO duration:5];
    check([v.behavior isEqualToString:@"run"],@"escape-with-no-room-falls-back-to-safe-chasing");
    v=make();[v beginBehavior:@"snack" user:NO duration:5];advance(v,1);
    [v applyBackendSnapshot:@{@"activity":@{@"name":@"idle",@"sessionWait":@YES}}];
    check(v.behavior==nil&&[v.currentState isEqualToString:@"wait"],@"real-task-wait-interrupts-snack-story");
    v=make();[v beginBehavior:@"sulk" user:NO duration:5];advance(v,1);
    [v pointerDownAt:NSMakePoint(4,15)];advance(v,10);
    check(v.behavior==nil&&v.backgroundPressed,@"finger-down-interrupts-escape-and-keeps-it-paused");
    for(WhaleScene *instance in instances)instance.animating=NO;
    return @{@"passed":@(failed.count==0),@"checks":passed,@"failures":failed,@"storyTypes":[seen allObjects]};
}

 + (NSDictionary *)runWaterWorldTests {
    NSMutableArray *passed=[NSMutableArray new],*failed=[NSMutableArray new];
    void (^check)(BOOL,NSString *)=^(BOOL ok,NSString *name){[(ok?passed:failed) addObject:name];};
    WhaleScene *v=[[WhaleScene alloc] initWithFrame:NSMakeRect(0,0,920,30) persistsPosition:NO];
        v.duoEnabled=NO;
    v.companionRoamingEnabled=NO;v.clockOverride=1000;v.visibleLastTick=1000;v.previousTick=1000;v.idleSince=1000;
    v.nextAutonomyAt=HUGE_VAL;v.nextCuddleAt=HUGE_VAL;v.nextNapAt=HUGE_VAL;v.animating=YES;
    void (^advance)(double)=^(double duration){
        double start=v.clockOverride;
        for (NSInteger i=1;i<=(NSInteger)ceil(duration*30);i++) {v.clockOverride=start+MIN(duration,i/30.0);[v advanceTo:v.clockOverride];}
    };
    check([CatCompanion isAvailable],@"cat-sprite-atlas-loads");
    [v constrainCompanion];advance(1);
    check(NSContainsRect(v.bounds,[v companionDrawingRect])&&!NSIntersectsRect([v petDrawingRect],[v companionDrawingRect]),@"resting-girl-and-cat-fit-water-without-overlap");
    [v performAction:@"run"];advance(.5);
    check([@[@"walk",@"run"] containsObject:v.companionBehavior],@"cat-walks-or-runs-after-moving-girl");
    BOOL onlyFollowing=YES;
    for (NSString *action in @[@"play",@"dance",@"nap",@"pet",@"feed"]) {
        [v performAction:action];advance(2);
        onlyFollowing &= [v.companionBehavior isEqualToString:@"idle"];
    }
    check(onlyFollowing,@"cat-does-not-mirror-girl-play-dance-sleep-petting-or-food");
    [v showReply:@"小猫一直跟着我呀♡"];
    NSRect bubble=[v replyDrawingRect];
    check(!NSIntersectsRect(bubble,[v petDrawingRect])&&!NSIntersectsRect(bubble,[v companionDrawingRect]),@"reply-bubble-never-covers-either-character");
    [v performAction:@"toggle-menu"];
    BOOL clear=YES;
    for(NSValue *r in [v menuRects]) clear &= !NSIntersectsRect(r.rectValue,[v companionDrawingRect]);
    check(clear,@"menu-does-not-cover-cat");
    __block NSInteger calls=0;v.interactionHandler=^(NSString *action){calls++;};
    NSRect feed=[[v menuRects][0] rectValue];
    [v pointerDownAt:NSMakePoint(NSMidX(feed),15)];[v pointerUpAt:NSMakePoint(NSMidX(feed),15)];
    check(calls==1&&[v.currentState isEqualToString:@"eat"],@"menu-feed-has-priority-and-sends-one-action");
    v.transient=nil;v.joyUntil=0;[v setState:@"idle" now:v.clockOverride];[v constrainCompanion];
    NSPoint catPoint=NSMakePoint(v.companionX,15);
    [v pointerDownAt:catPoint];[v pointerUpAt:catPoint];
    check(calls==1&&v.behavior==nil&&[v.companionBehavior isEqualToString:@"idle"],@"tapping-cat-never-starts-game-or-sends-backend-action");
    [v pointerDownAt:NSMakePoint(v.companionX,15)];[v abortPointer];[v pointerUpAt:NSMakePoint(v.companionX,15)];
    check(calls==1&&!v.companionPressed,@"cancelled-cat-touch-cannot-start-play");
    advance(1);
    v.animating=NO;double water=[v waterTime],x=v.companionX,phase=v.companionPhase;
    v.clockOverride=9000;[v advanceTo:9000];
    check(fabs([v waterTime]-water)<.001&&fabs(v.companionX-x)<.001&&fabs(v.companionPhase-phase)<.001,@"hidden-water-and-cat-freeze-without-offline-drift");
    [v setFrameSize:NSMakeSize(1004,30)];[v constrainCompanion];
    check(NSContainsRect(v.bounds,[v companionDrawingRect])&&!NSIntersectsRect([v petDrawingRect],[v companionDrawingRect]),@"resizing-full-width-keeps-both-actors-safe");
    return @{@"passed":@(failed.count==0),@"checks":passed,@"failures":failed};
}

+ (NSDictionary *)runCatFollowTests {
    NSMutableArray *passed=[NSMutableArray new],*failed=[NSMutableArray new],*instances=[NSMutableArray new];
    void (^check)(BOOL,NSString *)=^(BOOL ok,NSString *name){[(ok?passed:failed) addObject:name];};
    WhaleScene *(^make)(CGFloat)=^(CGFloat width){
        WhaleScene *v=[[WhaleScene alloc] initWithFrame:NSMakeRect(0,0,width,30) persistsPosition:NO];
        v.duoEnabled=NO;
        v.companionRoamingEnabled=NO;v.clockOverride=1000;v.visibleLastTick=1000;v.previousTick=1000;v.idleSince=1000;
        v.autonomousEnabled=NO;v.nextWalkAt=HUGE_VAL;v.animating=YES;[instances addObject:v];return v;
    };
    void (^advance)(WhaleScene *,double)=^(WhaleScene *v,double duration){
        double start=v.clockOverride;
        for (NSInteger i=1;i<=(NSInteger)ceil(duration*30);i++) {v.clockOverride=start+MIN(duration,i/30.0);[v advanceTo:v.clockOverride];}
    };
    // Use the volatile argument domain to exercise the real saved-position initializer.
    // This test neither persists nor changes the user's saved position.
    NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
    NSDictionary *originalArguments=[defaults volatileDomainForName:NSArgumentDomain]?:@{};
    for (NSNumber *position in @[@.03,@.97]) {
        NSMutableDictionary *arguments=[originalArguments mutableCopy];arguments[WGPositionKey]=position;
        [defaults setVolatileDomain:arguments forName:NSArgumentDomain];
        WhaleScene *edge=[[WhaleScene alloc] initWithFrame:NSMakeRect(0,0,920,30) persistsPosition:YES];
        edge.duoEnabled=NO;
        edge.companionRoamingEnabled=NO;edge.clockOverride=1000;edge.visibleLastTick=1000;edge.previousTick=1000;edge.idleSince=1000;
        edge.autonomousEnabled=NO;edge.nextWalkAt=HUGE_VAL;edge.animating=YES;[instances addObject:edge];
        advance(edge,2);
        check(fabs(edge.companionX-edge.petX)>=56&&!NSIntersectsRect([edge petDrawingRect],[edge companionDrawingRect]),
              position.doubleValue<.5?@"saved-left-edge-starts-cat-on-safe-following-side":@"saved-right-edge-starts-cat-on-safe-following-side");
    }
    [defaults setVolatileDomain:originalArguments forName:NSArgumentDomain];
    WhaleScene *v=make(920);advance(v,1);
    CGFloat rest=v.companionX;advance(v,2);
    check([v.companionBehavior isEqualToString:@"idle"]&&fabs(v.companionX-rest)<.01,@"cat-rests-without-independent-idle-wandering");
    v.behavior=@"run";v.userBehavior=YES;v.behaviorUntil=1009;v.behaviorTarget=760;v.behaviorSpeed=80;
    advance(v,2);
    check(!v.autonomousEnabled&&v.companionX<v.petX&&v.companionFacing>0&&fabs(v.petX-v.companionX)<90,@"cat-follows-rightward-even-with-autonomy-disabled");
    CGFloat beforeTurn=v.companionX;
    v.behaviorTarget=110;advance(v,1.0/30);
    check(fabs(v.companionX-beforeTurn)<=520.0/30+.01,@"cat-turns-with-bounded-motion-instead-of-swapping-sides");
    advance(v,2.5);
    check(v.companionX>v.petX&&v.companionFacing<0&&fabs(v.petX-v.companionX)<90,@"cat-catches-up-behind-leftward-girl-after-reversal");
    [v stopBehavior];v.walkUntil=0;
    CGFloat oldCat=v.companionX;
    [v pointerDownAt:NSMakePoint(v.petX,15)];[v pointerMovedTo:NSMakePoint(850,15)];
    BOOL noTeleport=fabs(v.companionX-oldCat)<.01;
    advance(v,.5);
    check(v.dragging&&v.companionX>oldCat+100&&[v.companionBehavior isEqualToString:@"run"]&&noTeleport,@"cat-runs-toward-dragged-girl-without-pointer-event-teleport");
    advance(v,2);
    check(v.dragging&&fabs((v.petX-60)-v.companionX)<1,@"cat-catches-up-while-finger-is-still-dragging-girl");
    [v pointerUpAt:NSMakePoint(v.petX,15)];
    BOOL inBounds=YES,smooth=YES,clear=YES;
    for(NSNumber *width in @[@920,@1004]) {
        v=make(width.doubleValue);advance(v,1);
        for(NSNumber *target in @[@24,@(width.doubleValue-24),@24]) {
            CGFloat old=v.companionX;
            [v pointerDownAt:NSMakePoint(v.petX,15)];[v pointerMovedTo:NSMakePoint(target.doubleValue,15)];
            smooth &= fabs(v.companionX-old)<.01;
            for (NSInteger i=0;i<90;i++) {
                old=v.companionX;advance(v,1.0/30);
                smooth &= fabs(v.companionX-old)<=520.0/30+.01;
                inBounds &= NSContainsRect(v.bounds,[v companionDrawingRect]);
            }
            [v pointerUpAt:NSMakePoint(v.petX,15)];
            [v performAction:@"toggle-menu"];
            CGFloat menuCatX=v.companionX;
            for(NSValue *r in [v menuRects]) clear &= !NSIntersectsRect(r.rectValue,[v companionDrawingRect]);
            advance(v,1);clear &= fabs(v.companionX-menuCatX)<.01;
            [v performAction:@"close-menu"];
        }
    }
    check(inBounds&&smooth,@"cat-follows-between-both-edges-at-two-touchbar-widths-without-teleport");
    check(clear,@"menus-open-clear-of-cat-and-keep-it-still");
    v=make(920);v.companionX=v.petX+3;
    [v pointerDownAt:NSMakePoint(v.petX,15)];
    check(v.pressed&&!v.companionPressed,@"girl-touch-has-priority-while-cat-passes-on-reversal");
    [v abortPointer];
    for(WhaleScene *instance in instances)instance.animating=NO;
    return @{@"passed":@(failed.count==0),@"checks":passed,@"failures":failed};
}
+ (NSDictionary *)runCatRoamingTests {
    NSMutableArray *passed=[NSMutableArray new],*failed=[NSMutableArray new],*instances=[NSMutableArray new];
    void (^check)(BOOL,NSString *)=^(BOOL ok,NSString *name){[(ok?passed:failed) addObject:name];};
    WhaleScene *(^make)(CGFloat)=^(CGFloat width){
        WhaleScene *v=[[WhaleScene alloc] initWithFrame:NSMakeRect(0,0,width,30) persistsPosition:NO];
        v.duoEnabled=NO;
        v.clockOverride=1000;v.visibleLastTick=1000;v.previousTick=1000;v.idleSince=1000;
        v.nextAutonomyAt=HUGE_VAL;v.nextCuddleAt=HUGE_VAL;v.nextNapAt=HUGE_VAL;v.hungerAfter=HUGE_VAL;v.nextWalkAt=HUGE_VAL;
        v.companionRandomState=1;v.nextCompanionRoamAt=1;v.animating=YES;[instances addObject:v];return v;
    };
    void (^advance)(WhaleScene *,double)=^(WhaleScene *v,double duration){
        double start=v.clockOverride;
        for(NSInteger i=1;i<=(NSInteger)ceil(duration*30);i++) {v.clockOverride=start+MIN(duration,i/30.0);[v advanceTo:v.clockOverride];}
    };
    WhaleScene *v=make(968);advance(v,4.99);
    check([v.companionActivity isEqualToString:@"follow"],@"cat-does-not-roam-during-the-first-five-idle-seconds");
    advance(v,.04);check([v.companionActivity isEqualToString:@"roam"],@"idle-cat-starts-its-own-play-without-a-girl-action");
    NSMutableSet *activities=[NSMutableSet new],*modes=[NSMutableSet new];
    CGFloat widestGap=0;BOOL safe=YES,smooth=YES,returnedBeside=YES;NSUInteger rounds=0;NSString *previous=@"follow";
    __block NSUInteger calls=0;v.interactionHandler=^(NSString *action){calls++;};
    for(NSInteger frame=0;frame<90*30;frame++) {
        CGFloat old=v.companionX;advance(v,1.0/30);
        [activities addObject:v.companionActivity];[modes addObject:v.companionBehavior];
        widestGap=MAX(widestGap,fabs(v.companionX-v.petX));
        safe &= NSContainsRect(v.bounds,[v companionDrawingRect]);
        smooth &= fabs(v.companionX-old)<=520.0/30+.01;
        if([v.companionActivity isEqualToString:@"roam"]&&![previous isEqualToString:@"roam"]) rounds++;
        if([v.companionActivity isEqualToString:@"rest"]&&![previous isEqualToString:@"rest"]) returnedBeside &= fabs(fabs(v.companionX-v.petX)-60)<2;
        previous=v.companionActivity;
    }
    check([activities containsObject:@"roam"]&&[activities containsObject:@"return"]&&[activities containsObject:@"rest"]&&[activities containsObject:@"follow"]&&rounds>=2,@"seeded-cat-repeats-play-return-rest-and-follow-cycles");
    check(widestGap>150,@"cat-really-leaves-the-girl-to-play-at-a-visible-distance");
    check(returnedBeside,@"tired-cat-returns-beside-girl-before-resting");
    check(safe&&smooth,@"all-roaming-and-return-frames-stay-in-bounds-without-teleport");
    check([modes isSubsetOfSet:[NSSet setWithArray:@[@"idle",@"walk",@"run"]]]&&[modes containsObject:@"run"]&&[modes containsObject:@"walk"],@"independent-play-only-uses-walking-running-and-idle-art");
    check(calls==0,@"independent-cat-play-never-sends-backend-interactions");
    v=make(968);advance(v,5.1);[v performAction:@"toggle-menu"];CGFloat menuX=v.companionX;advance(v,3);
    BOOL clear=YES;for(NSValue *rect in [v menuRects]) clear &= !NSIntersectsRect(rect.rectValue,[v companionDrawingRect]);
    check(v.menuOpen&&[v.companionActivity isEqualToString:@"follow"]&&fabs(v.companionX-menuX)<.01&&clear,@"opening-menu-cancels-roaming-and-keeps-cat-clear-and-still");
    [v performAction:@"close-menu"];advance(v,7.9);
    check([v.companionActivity isEqualToString:@"follow"],@"menu-release-allows-a-fresh-pause-before-next-cat-outing");
    v=make(968);advance(v,5.1);[v pointerDownAt:NSMakePoint(v.companionX,15)];
    check(v.companionPressed&&[v.companionActivity isEqualToString:@"follow"],@"touching-cat-cancels-independent-play-immediately");
    [v abortPointer];
    v=make(968);advance(v,5.1);CGFloat before=v.companionX;
    [v pointerDownAt:NSMakePoint(v.petX,15)];[v pointerMovedTo:NSMakePoint(850,15)];advance(v,.8);
    check(v.dragging&&[v.companionActivity isEqualToString:@"follow"]&&v.companionX>before,@"dragging-girl-brings-the-cat-back-to-follow-mode");
    [v pointerUpAt:NSMakePoint(v.petX,15)];
    v=make(968);advance(v,5.1);v.autonomousEnabled=NO;advance(v,30);
    check([v.companionActivity isEqualToString:@"follow"],@"turning-off-autonomy-stops-cat-outings-but-keeps-following");
    v=make(968);advance(v,5.5);v.animating=NO;
    CGFloat x=v.companionX;double visible=v.visibleElapsed,phase=v.companionPhase,remaining=v.companionActivityUntil-v.visibleElapsed;
    NSString *activity=v.companionActivity;advance(v,1000);
    BOOL frozen=fabs(v.companionX-x)<.001&&fabs(v.visibleElapsed-visible)<.001&&fabs(v.companionPhase-phase)<.001&&[v.companionActivity isEqualToString:activity];
    v.animating=YES;advance(v,.2);
    check(frozen&&[v.companionActivity isEqualToString:@"roam"]&&fabs((v.companionActivityUntil-v.visibleElapsed)-(remaining-.2))<.001,@"hidden-or-system-controls-mode-freezes-and-resumes-the-current-cat-outing");
    v=make(968);advance(v,5.5);[v setFrameSize:NSMakeSize(628,30)];BOOL resizedSafe=YES;
    for(NSInteger i=0;i<20*30;i++){advance(v,1.0/30);resizedSafe &= NSContainsRect(v.bounds,[v companionDrawingRect]);}
    check(resizedSafe,@"resizing-during-an-outing-keeps-cat-inside-the-smaller-stage");
    v=make(968);v.nextAutonomyAt=5;v.storyRandomState=1;NSUInteger roamingFrames=0;BOOL dynamicSafe=YES;
    for(NSInteger i=0;i<90*30;i++) {
        advance(v,1.0/30);roamingFrames += [v.companionActivity isEqualToString:@"roam"];
        dynamicSafe &= NSContainsRect(v.bounds,[v companionDrawingRect])&&NSContainsRect(v.bounds,[v petDrawingRect]);
    }
    check(roamingFrames>100&&dynamicSafe&&v.hasAutonomousAction,@"cat-outings-coexist-with-the-girls-real-random-stories");
    for(WhaleScene *instance in instances)instance.animating=NO;
    return @{@"passed":@(failed.count==0),@"checks":passed,@"failures":failed,@"activities":[activities allObjects],@"rounds":@(rounds),@"maximumSeparationPoints":@(widestGap)};
}


+ (NSDictionary *)runDuoStoryTests {
    NSMutableArray *passed=[NSMutableArray new],*failed=[NSMutableArray new],*instances=[NSMutableArray new];
    void (^check)(BOOL,NSString *)=^(BOOL ok,NSString *name){[(ok?passed:failed) addObject:name];};
    WhaleScene *(^make)(CGFloat)=^(CGFloat width){
        WhaleScene *v=[[WhaleScene alloc] initWithFrame:NSMakeRect(0,0,width,30) persistsPosition:NO];
        [instances addObject:v];v.duoEnabled=YES;v.duoRandomState=12345;v.storyRandomState=7;v.companionRandomState=19;
        v.clockOverride=1000;v.previousTick=1000;v.visibleLastTick=1000;
        v.petX=width*.32;v.companionX=v.petX-60;v.companionLastPetX=v.petX;
        v.nextDuoAt=12;v.nextAutonomyAt=5;v.nextNapAt=HUGE_VAL;v.nextCuddleAt=HUGE_VAL;v.hungerAfter=HUGE_VAL;
        v.animating=YES;return v;
    };
    void (^advance)(WhaleScene *,double)=^(WhaleScene *v,double seconds){
        NSInteger ticks=MAX(1,(NSInteger)ceil(seconds*30));double dt=seconds/ticks;
        for(NSInteger i=0;i<ticks;i++){v.clockOverride+=dt;[v advanceTo:v.clockOverride];}
    };
    WhaleScene *v=make(968);advance(v,4.99);
    check([v.duoStory isEqualToString:@"none"],@"duo-stories-respect-the-first-five-seconds-after-touch");
    v=make(968);v.nextDuoAt=0;v.nextAutonomyAt=100;advance(v,5.1);
    check(![v.duoStory isEqualToString:@"none"]&&!v.behavior,@"due-duo-story-starts-before-the-next-ordinary-idle-story");
    v=make(968);NSMutableSet *seen=[NSMutableSet new];BOOL bounded=YES,smooth=YES,exclusive=YES,alternating=YES;
    NSUInteger starts=0;NSString *previous=@"none",*lastKind=nil;
    for(NSInteger i=0;i<450*30;i++) {
        CGFloat g=v.petX,c=v.companionX;NSString *old=v.duoStory;advance(v,1.0/30);NSString *kind=v.duoStory;
        if(![kind isEqualToString:@"none"]) {
            [seen addObject:kind];bounded &= NSContainsRect(v.bounds,[v petDrawingRect])&&NSContainsRect(v.bounds,[v companionDrawingRect]);
            exclusive &= v.behavior==nil&&![v.companionActivity isEqualToString:@"roam"];
            if(![old isEqualToString:@"none"])smooth &= fabs(v.petX-g)<=185.0/30+.001&&fabs(v.companionX-c)<=200.0/30+.001;
            if([previous isEqualToString:@"none"]){starts++;alternating &= ![lastKind isEqualToString:kind];lastKind=kind;}
        }
        previous=kind;
    }
    check(seen.count==3&&starts>=6,@"production-sequence-shows-all-three-duo-stories-amid-ordinary-stories-and-cat-outings");
    check(exclusive&&alternating,@"duo-stories-own-motion-exclusively-and-do-not-repeat-the-same-story-consecutively");
    check(bounded&&smooth,@"long-production-sequence-keeps-continuous-bounded-motion-and-both-pets-in-view");
    for(NSString *kind in @[@"block",@"dash",@"reunion"]) {
        v=make(968);__block NSUInteger backendCalls=0;v.interactionHandler=^(NSString *action){backendCalls++;};v.bubble=@"unchanged";
        CGFloat g=v.petX,c=v.companionX;[v beginDuoStory:kind];
        check(v.petX==g&&v.companionX==c,[kind stringByAppendingString:@"-entry-does-not-teleport-either-character"]);
        advance(v,5);check([v.duoStory isEqualToString:kind]&&v.duoStage.length>0&&backendCalls==0&&[v.bubble isEqualToString:@"unchanged"],[kind stringByAppendingString:@"-has-readable-phases-without-backend-interactions-or-dialogue"]);
        advance(v,17);check([v.duoStory isEqualToString:@"none"]&&v.nextDuoAt-v.visibleElapsed>8,[kind stringByAppendingString:@"-finishes-and-restores-a-gap-for-ordinary-play"]);
    }
    v=make(968);[v beginDuoStory:@"block"];v.duoQuickEnding=YES;advance(v,3);
    check([v.duoPhase isEqualToString:@"blocked"]&&!v.duoPetMoving&&fabs(v.companionX-v.petX)>=30,@"blocking-cat-makes-the-girl-stop-before-she-walks-around-it");
    advance(v,2);check([v.duoPhase isEqualToString:@"sidestep"]&&v.petX>v.companionX,@"girl-passes-the-first-blocking-position-without-moving-the-cat-instantly");
    advance(v,5);check([v.duoPhase isEqualToString:@"standoff"]&&v.companionX>v.petX,@"cat-runs-ahead-and-blocks-a-second-time");
    advance(v,4);check([v.duoPhase isEqualToString:@"breakaway"]&&fabs(v.petX-v.companionX)>75,@"one-block-story-ending-lets-the-girl-accelerate-away");
    v=make(968);[v beginDuoStory:@"block"];v.duoQuickEnding=NO;advance(v,14);
    check([v.duoPhase isEqualToString:@"yield"]&&v.petX>v.companionX,@"the-other-block-story-ending-lets-the-cat-step-aside");
    BOOL dashEdges=YES;
    for(NSNumber *start in @[@24,@304,@350,@550,@664,@944]) {
        v=make(968);v.petX=start.doubleValue;v.companionX=[v duoBound:v.petX+(v.petX<484?60:-60) cat:YES];v.companionLastPetX=v.petX;
        [v beginDuoStory:@"dash"];advance(v,4.45);dashEdges &= fabs(v.petX-v.companionX)>100;
        advance(v,.55);CGFloat stopped=v.petX,c=v.companionX;advance(v,.7);
        dashEdges &= [v.duoPhase isEqualToString:@"wait"]&&fabs(v.petX-stopped)<.001&&fabs(v.companionX-c)>10;
        advance(v,4.3);dashEdges &= fabs(v.petX-v.companionX)>=28&&fabs(v.petX-v.companionX)<=45;
    }
    check(dashEdges,@"dash-opens-a-real-gap-even-near-edges-then-girl-waits-while-cat-runs-alone-and-catches-up");
    BOOL blockEdges=YES;
    for(NSNumber *start in @[@24,@350,@550,@664,@944]) {
        v=make(968);v.petX=start.doubleValue;v.companionX=[v duoBound:v.petX+(v.petX<484?60:-60) cat:YES];v.companionLastPetX=v.petX;
        [v beginDuoStory:@"block"];v.duoQuickEnding=YES;advance(v,14);
        blockEdges &= fabs(v.petX-v.companionX)>=75&&NSContainsRect(v.bounds,[v petDrawingRect])&&NSContainsRect(v.bounds,[v companionDrawingRect]);
    }
    check(blockEdges,@"block-breakaway-has-room-for-a-real-gap-from-center-and-edge-starts");
    v=make(968);[v beginDuoStory:@"dash"];advance(v,10);CGFloat rested=v.petX;advance(v,2);
    check([v.duoPhase isEqualToString:@"close"]&&v.petX==rested&&fabs(v.companionSpeed)<.001,@"reunited-pets-stay-close-and-still-for-at-least-two-seconds");
    v=make(968);[v beginDuoStory:@"reunion"];advance(v,4);
    check([v.duoPhase isEqualToString:@"notice"]&&!v.duoPetMoving&&fabs(v.petX-v.companionX)>100,@"girl-notices-the-cat-has-gone-away-and-stops-to-look-back");
    advance(v,6);check([v.duoPhase isEqualToString:@"close"]&&fabs(v.petX-v.companionX)>=28&&fabs(v.petX-v.companionX)<=35,@"independent-cat-returns-and-settles-close-to-the-girl");
    advance(v,4);check([v.duoPhase isEqualToString:@"rest"]&&!v.duoPetMoving&&fabs(v.companionSpeed)<.001,@"reunion-ends-in-a-visible-quiet-rest");
    v=make(968);[v beginDuoStory:@"dash"];advance(v,3);NSTimeInterval age=[v duoAge];CGFloat g=v.petX,c=v.companionX;NSString *stage=v.duoPhase;
    v.animating=NO;v.clockOverride+=3600;[v advanceTo:v.clockOverride];BOOL frozen=fabs([v duoAge]-age)<.0001&&v.petX==g&&v.companionX==c&&[v.duoPhase isEqualToString:stage];
    v.animating=YES;advance(v,.2);check(frozen&&fabs([v duoAge]-age-.2)<.001,@"hidden-or-system-controls-time-freezes-and-resumes-the-exact-story-stage");
    v=make(968);[v beginDuoStory:@"block"];advance(v,5);g=v.petX;c=v.companionX;[v pointerDownAt:NSMakePoint(v.petX,15)];
    check([v.duoStory isEqualToString:@"none"]&&v.petX==g&&v.companionX==c,@"touch-cancels-the-duo-story-immediately-without-repositioning-pets");
    [v pointerMovedTo:NSMakePoint(g+60,15)];[v pointerUpAt:NSMakePoint(g+60,15)];check(v.petX>g+50&&[v.duoStory isEqualToString:@"none"],@"girl-remains-draggable-after-interrupting-a-story");
    v=make(968);[v beginDuoStory:@"dash"];advance(v,3);[v performAction:@"toggle-menu"];check([v.duoStory isEqualToString:@"none"]&&v.menuOpen,@"interaction-menu-takes-priority-over-the-duo-story");
    v=make(968);[v beginDuoStory:@"reunion"];advance(v,3);[v performAction:@"dance"];check([v.duoStory isEqualToString:@"none"]&&[v.behavior isEqualToString:@"dance"]&&v.userBehavior,@"manual-actions-take-priority-over-the-duo-story");
    v=make(968);[v beginDuoStory:@"dash"];advance(v,3);v.autonomousEnabled=NO;check([v.duoStory isEqualToString:@"none"],@"turning-autonomy-off-clears-the-current-story");
    v=make(968);[v beginDuoStory:@"block"];advance(v,3);[v applyBackendSnapshot:@{@"activity":@{@"sessionThink":@YES}}];check([v.duoStory isEqualToString:@"none"]&&[@[@"think",@"working"] containsObject:v.currentState],@"backend-task-states-interrupt-duo-stories");
    v=make(968);[v beginDuoStory:@"reunion"];advance(v,3);[v setFrameSize:NSMakeSize(340,30)];check([v.duoStory isEqualToString:@"none"]&&NSContainsRect(v.bounds,[v petDrawingRect])&&NSContainsRect(v.bounds,[v companionDrawingRect]),@"resize-cancels-the-story-and-keeps-both-pets-inside-the-new-width");
    for(NSString *kind in @[@"block",@"dash",@"reunion"]) {
        v=make(968);[v performAction:[@"duo-" stringByAppendingString:kind]];advance(v,.5);
        check([v.duoStory isEqualToString:kind]&&v.duoUserRequested&&v.duoPhase.length>0,[kind stringByAppendingString:@"-menu-playback-starts-the-requested-live-story"]);
    }
    v=make(968);v.autonomousEnabled=NO;__block NSUInteger playbackBackendCalls=0;v.interactionHandler=^(NSString *action){playbackBackendCalls++;};
    [v performAction:@"duo-dash"];advance(v,3.5);
    check(!v.autonomousEnabled&&[v.duoStory isEqualToString:@"dash"]&&[v.duoPhase isEqualToString:@"sprint"]&&playbackBackendCalls==0,@"manual-playback-advances-with-autonomy-off-without-changing-preference-or-calling-backend");
    v=make(968);v.autonomousEnabled=NO;[v setState:@"sleep" now:v.clockOverride];v.transient=@"wake";v.transientUntil=v.clockOverride+3;v.dragReleaseUntil=v.clockOverride+1.5;
    [v performAction:@"duo-reunion"];advance(v,.5);
    check([v.duoStory isEqualToString:@"reunion"]&&v.transient==nil&&v.dragReleaseUntil==0&&!v.autonomousEnabled,@"manual-playback-clears-old-sleep-wake-and-drag-release-buffers");
    [v applyBackendSnapshot:@{@"activity":@{@"sessionThink":@YES}}];BOOL backendCancelled=[v.duoStory isEqualToString:@"none"]&&!v.duoUserRequested;
    [v applyBackendSnapshot:@{@"activity":@{@"sessionThink":@NO}}];[v performAction:@"duo-block"];advance(v,.3);[v pointerDownAt:NSMakePoint(v.petX,15)];
    check(backendCancelled&&[v.duoStory isEqualToString:@"none"]&&!v.duoUserRequested,@"backend-work-and-a-new-touch-still-cancel-manually-requested-playback");
    for(WhaleScene *instance in instances)instance.animating=NO;
    return @{@"passed":@(failed.count==0),@"checks":passed,@"failures":failed,@"observedStories":seen.allObjects,@"storyStarts":@(starts),@"simulationSeconds":@450};
}


@end
