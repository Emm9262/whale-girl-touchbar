#import "PetBarContainer.h"
#import <QuartzCore/QuartzCore.h>

static const CGFloat PetControlsWidth=36;
static const CGFloat PetCircleSize=14;

static NSColor *PetBarBackground(void) {
    return [NSColor colorWithSRGBRed:10.0/255 green:10.0/255 blue:10.0/255 alpha:1];
}
static NSImage *PetCircleImage(void) {
    static NSImage *circle;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSImage *symbol=[NSImage imageWithSystemSymbolName:@"circle" accessibilityDescription:nil];
        if(symbol) symbol=[symbol imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:PetCircleSize weight:NSFontWeightRegular]];
        circle=[NSImage imageWithSize:NSMakeSize(PetCircleSize,PetCircleSize) flipped:NO drawingHandler:^BOOL(NSRect rect) {
            NSColor *color=[NSColor colorWithWhite:.92 alpha:1];
            if(symbol) {
                [symbol drawInRect:rect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:NO hints:nil];
                [color setFill];NSRectFillUsingOperation(rect,NSCompositingOperationSourceIn);
            } else {
                [color setStroke];
                NSBezierPath *outline=[NSBezierPath bezierPathWithOvalInRect:NSInsetRect(rect,1,1)];
                outline.lineWidth=1.35;[outline stroke];
            }
            return YES;
        }];
        circle.template=NO;
    });
    return circle;
}

@interface PetBarContainer ()
@property(nonatomic, strong, readwrite) WhaleScene *scene;
@property(nonatomic, strong) NSButton *systemControlsButton;
@end

@implementation PetBarContainer
- (instancetype)initWithFrame:(NSRect)frame scene:(WhaleScene *)scene {
    if((self=[super initWithFrame:frame])) {
        _scene=scene;
        _scene.translatesAutoresizingMaskIntoConstraints=YES;
        _scene.wantsLayer=YES;_scene.layer.masksToBounds=YES;
        [self addSubview:_scene];
        _systemControlsButton=[NSButton buttonWithImage:PetCircleImage() target:self action:@selector(showSystemControls:)];
        _systemControlsButton.title=@"";
        _systemControlsButton.bordered=NO;
        _systemControlsButton.imagePosition=NSImageOnly;
        _systemControlsButton.imageScaling=NSImageScaleNone;
        _systemControlsButton.refusesFirstResponder=YES;
        [_systemControlsButton setButtonType:NSButtonTypeMomentaryChange];
        _systemControlsButton.toolTip=@"显示原版 Touch Bar 音量、亮度等控件";
        [_systemControlsButton setAccessibilityLabel:@"显示原版 Touch Bar 控件"];
        [_systemControlsButton setAccessibilityHelp:@"切换到系统原有的音量、亮度和其他 Touch Bar 设置。"];
        [self addSubview:_systemControlsButton];
        [self layoutContent];
    }
    return self;
}
- (BOOL)isOpaque { return YES; }
- (NSSize)intrinsicContentSize { return NSMakeSize(NSViewNoIntrinsicMetric,30); }
- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [self layoutContent];
}
- (void)layout {
    [super layout];
    [self layoutContent];
}
- (void)layoutContent {
    if(!self.scene||!self.systemControlsButton) return;
    CGFloat width=MAX(0,NSWidth(self.bounds)),height=MAX(0,NSHeight(self.bounds));
    CGFloat controlsWidth=MIN(PetControlsWidth,width),sceneWidth=width-controlsWidth;
    NSRect sceneFrame=NSMakeRect(0,0,sceneWidth,height);
    NSRect buttonFrame=NSMakeRect(sceneWidth,0,controlsWidth,height);
    if(!NSEqualRects(self.scene.frame,sceneFrame)) self.scene.frame=sceneFrame;
    if(!NSEqualRects(self.systemControlsButton.frame,buttonFrame)) self.systemControlsButton.frame=buttonFrame;
}
- (void)showSystemControls:(id)sender {
    if(self.systemControlsHandler) self.systemControlsHandler();
}
- (void)drawRect:(NSRect)dirtyRect {
    [PetBarBackground() setFill];NSRectFill(self.bounds);
}
- (void)drawPreviewInCurrentContext {
    [self layoutContent];
    [self drawRect:self.bounds];
    [NSGraphicsContext saveGraphicsState];
    NSAffineTransform *translation=[NSAffineTransform transform];
    [translation translateXBy:NSMinX(self.scene.frame) yBy:NSMinY(self.scene.frame)];
    [translation concat];
    NSRectClip(self.scene.bounds);
    [self.scene drawRect:self.scene.bounds];
    [NSGraphicsContext restoreGraphicsState];
    NSRect button=self.systemControlsButton.frame;
    NSRect glyph=NSMakeRect(NSMidX(button)-PetCircleSize*.5,NSMidY(button)-PetCircleSize*.5,PetCircleSize,PetCircleSize);
    [PetCircleImage() drawInRect:glyph fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:NO hints:nil];
}
+ (NSDictionary *)runLayoutTests {
    NSMutableArray *passed=[NSMutableArray new],*failed=[NSMutableArray new];
    void (^check)(BOOL,NSString *)=^(BOOL ok,NSString *name){[(ok?passed:failed) addObject:name];};
    WhaleScene *scene=[[WhaleScene alloc] initWithFrame:NSMakeRect(0,0,884,30)];
    scene.animating=NO;scene.fixedTime=0;scene.forcedState=@"idle";
    PetBarContainer *container=[[PetBarContainer alloc] initWithFrame:NSMakeRect(0,0,920,30) scene:scene];
    for(NSNumber *value in @[@920,@1004,@664]) {
        CGFloat width=value.doubleValue;
        [container setFrameSize:NSMakeSize(width,30)];
        NSRect pet=scene.frame,button=container.systemControlsButton.frame;
        BOOL fits=NSContainsRect(container.bounds,pet)&&NSContainsRect(container.bounds,button)
            &&fabs(NSMinX(pet))<.001&&fabs(NSMaxX(pet)-NSMinX(button))<.001
            &&fabs(NSWidth(button)-PetControlsWidth)<.001&&fabs(NSMaxX(button)-width)<.001
            &&fabs(NSHeight(pet)-30)<.001&&!NSIntersectsRect(pet,button);
        check(fits,[NSString stringWithFormat:@"scene-and-right-circle-fit-separate-regions-at-%ld-points",(long)width]);
    }
    NSPoint rightTap=NSMakePoint(NSWidth(container.bounds)-PetControlsWidth*.5,15);
    check(NSPointInRect(rightTap,container.systemControlsButton.frame)&&!NSPointInRect(rightTap,scene.frame),@"far-right-circle-touch-is-outside-the-pet-scene");
    __block NSUInteger calls=0,petActions=0;
    scene.interactionHandler=^(NSString *action){petActions++;};
    container.systemControlsHandler=^{calls++;};
    [container.systemControlsButton performClick:nil];
    check(calls==1&&petActions==0,@"native-circle-button-calls-system-handler-once-without-pet-interaction");
    container.systemControlsHandler=nil;
    [container.systemControlsButton performClick:nil];
    check(calls==1&&petActions==0,@"circle-with-no-handler-does-not-send-any-action");
    check(PetCircleImage()!=nil&&[container.systemControlsButton accessibilityLabel].length>0,@"circle-has-a-visible-glyph-and-accessible-system-controls-label");
    return @{@"passed":@(failed.count==0),@"checks":passed,@"failures":failed,
             @"controlsWidthPoints":@(PetControlsWidth),@"circleSizePoints":@(PetCircleSize)};
}
@end
