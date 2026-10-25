#import "CompanionPanelView.h"
#import <math.h>

static NSColor *CPRGB(unsigned value) {
    return [NSColor colorWithSRGBRed:((value>>16)&255)/255.0 green:((value>>8)&255)/255.0 blue:(value&255)/255.0 alpha:1];
}
static BOOL CPIsDark(NSView *view) {
    return [[view.effectiveAppearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua,NSAppearanceNameDarkAqua]] isEqualToString:NSAppearanceNameDarkAqua];
}
static NSFont *CPFont(CGFloat size,BOOL bold) {
    NSFont *font=[NSFont fontWithName:bold?@"PingFangSC-Semibold":@"PingFangSC-Regular" size:size];
    return font?:[NSFont systemFontOfSize:size weight:bold?NSFontWeightSemibold:NSFontWeightRegular];
}
static void CPDrawText(NSString *text,NSRect rect,CGFloat size,BOOL bold,NSColor *color,NSTextAlignment alignment) {
    if (!text.length) return;
    NSMutableParagraphStyle *paragraph=[NSMutableParagraphStyle new];
    paragraph.alignment=alignment;paragraph.lineBreakMode=NSLineBreakByWordWrapping;paragraph.lineSpacing=2;
    NSDictionary *attrs=@{NSFontAttributeName:CPFont(size,bold),NSForegroundColorAttributeName:color,NSParagraphStyleAttributeName:paragraph};
    [NSGraphicsContext saveGraphicsState];NSRectClip(rect);
    [text drawWithRect:rect options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading attributes:attrs];
    [NSGraphicsContext restoreGraphicsState];
}
static NSString *CPText(id value,NSString *fallback) {
    return [value isKindOfClass:NSString.class]&&[value length]?value:fallback;
}
static BOOL CPBool(id value) { return [value respondsToSelector:@selector(boolValue)]&&[value boolValue]; }

@interface CPDrawnButton : NSButton
@property(nonatomic, copy) NSString *actionID;
@property(nonatomic) BOOL active;
@property(nonatomic) BOOL quiet;
@property(nonatomic) BOOL destructive;
@end
@implementation CPDrawnButton
- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return NO; }
- (void)drawRect:(NSRect)dirtyRect {
    BOOL dark=CPIsDark(self),pressed=self.cell.isHighlighted;
    NSColor *fill=CPRGB(dark?0x292C32:0xECEEF1),*stroke=CPRGB(dark?0x40454E:0xD6DAE0);
    if (self.active) { fill=CPRGB(dark?0x253B49:0xDFEDF5);stroke=CPRGB(dark?0x4E748D:0xA3BDCD); }
    if (pressed) fill=CPRGB(dark?0x46515E:0xCFDAE6);
    if (self.quiet&&!pressed) { fill=CPRGB(dark?0x17191D:0xFAFAFA);stroke=CPRGB(dark?0x34383F:0xDEE1E5); }
    NSRect box=NSInsetRect(self.bounds,.5,.5);
    NSBezierPath *shape=[NSBezierPath bezierPathWithRoundedRect:box xRadius:6 yRadius:6];
    [fill setFill];[shape fill];[stroke setStroke];shape.lineWidth=1;[shape stroke];
    NSColor *text=CPRGB(dark?0xF5F6F7:0x202226);
    if(!self.enabled)text=CPRGB(dark?0x7E8794:0x9299A3);
    if (self.destructive) text=CPRGB(dark?0xEDBBB5:0x8A3028);
    CGFloat fontSize=[self.actionID isEqualToString:@"close"]?19:12.5;
    NSFont *font=CPFont(fontSize,NO);
    CGFloat height=font.ascender-font.descender+4;
    NSRect title=NSMakeRect(5,(NSHeight(self.bounds)-height)*.5,MAX(0,NSWidth(self.bounds)-10),height);
    CPDrawText(self.title,title,fontSize,NO,text,NSTextAlignmentCenter);
    if (self.window.firstResponder==self) {
        NSBezierPath *focus=[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds,2,2) xRadius:5 yRadius:5];
        [CPRGB(dark?0x97C9EB:0x3F779D) setStroke];focus.lineWidth=1.5;[focus stroke];
    }
}
- (void)resetCursorRects { [self addCursorRect:self.bounds cursor:NSCursor.pointingHandCursor]; }
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance];self.needsDisplay=YES; }
@end

@interface CompanionPanelView ()
@property(nonatomic) NSMutableDictionary<NSString *,CPDrawnButton *> *buttons;
@property(nonatomic) NSArray<NSString *> *orderedActions;
@property(nonatomic) NSTextField *chatField;
@property(nonatomic) BOOL libraryVisible;
@property(nonatomic) NSUInteger libraryPage;
@end
@implementation CompanionPanelView
+ (NSSize)preferredSize { return NSMakeSize(430,750); }
- (instancetype)initWithFrame:(NSRect)frame {
    frame.size=CompanionPanelView.preferredSize;
    if ((self=[super initWithFrame:frame])) {
        _buttons=[NSMutableDictionary new];
        _state=@{@"current":@"自由活动",@"detail":@"鲸鱼娘和猫咪正在一起玩。",@"autonomous":@YES,@"enabled":@YES,@"controlsVisible":@NO,@"backend":@"本地互动"};
        [self setAccessibilityElement:YES];[self setAccessibilityRole:NSAccessibilityGroupRole];[self setAccessibilityLabel:@"鲸鱼娘与三花猫控制面板"];
        [self addButton:@"×" action:@"close" rect:NSMakeRect(390,12,24,24)];
        CGFloat width=(398-16)/3.0;
        NSArray *stories=@[@[@"猫咪挡路",@"duo-block"],@[@"跑远等你",@"duo-dash"],@[@"回来陪你",@"duo-reunion"]];
        for (NSUInteger i=0;i<stories.count;i++) [self addButton:stories[i][0] action:stories[i][1] rect:NSMakeRect(16+i*(width+8),137,width,32)];
        CGFloat cell=(398-24)/4.0;
        NSArray *interactions=@[@[@"投喂",@"feed"],@[@"一起玩",@"play"],@[@"摸摸",@"pet"],@[@"跳舞",@"dance"],@[@"跑一圈",@"run"],@[@"撒个娇",@"cuddle"],@[@"打个盹",@"nap"],@[@"饿不饿",@"status"]];
        for (NSUInteger i=0;i<interactions.count;i++) [self addButton:interactions[i][0] action:interactions[i][1] rect:NSMakeRect(16+(i%4)*(cell+8),211+(i/4)*40,cell,32)];
        [self addButton:@"主动互动：开启" action:@"toggle-autonomy" rect:NSMakeRect(16,298,195,32)];
        [self addButton:@"暂停桌宠" action:@"toggle-pause" rect:NSMakeRect(219,298,195,32)];
        [self addButton:@"显示系统音量、亮度等控件" action:@"system-controls" rect:NSMakeRect(16,578,398,34)];
        NSArray *tools=@[@[@"桌面预览",@"preview"],@[@"使用帮助",@"backup"],@[@"连接插件",@"connect"]];
        for (NSUInteger i=0;i<tools.count;i++) {
            CPDrawnButton *button=[self addButton:tools[i][0] action:tools[i][1] rect:NSMakeRect(16+i*(width+8),620,width,30)];button.quiet=YES;
        }
        CPDrawnButton *quit=[self addButton:@"退出桌宠" action:@"quit" rect:NSMakeRect(16,703,398,31)];quit.quiet=YES;quit.destructive=YES;
        [self addButton:@"PC2005 动画：开启" action:@"pc-toggle" rect:NSMakeRect(16,345,245,32)];
        [self addButton:@"打开动作库" action:@"pc-library" rect:NSMakeRect(269,345,145,32)];
        self.chatField=[[NSTextField alloc]initWithFrame:NSMakeRect(16,390,318,30)];
        self.chatField.placeholderString=@"对鲸鱼娘说句话…";self.chatField.font=CPFont(12.5,NO);
        self.chatField.target=self;self.chatField.action=@selector(sendChat:);self.chatField.cell.sendsActionOnEndEditing=NO;
        [self.chatField setAccessibilityLabel:@"对鲸鱼娘说句话"];[self addSubview:self.chatField];
        [self addButton:@"发送" action:@"pc-chat-send" rect:NSMakeRect(342,390,72,30)];
        [self addButton:@"来句碎碎念" action:@"pc-whisper" rect:NSMakeRect(16,432,195,32)];
        [self addButton:@"查看余额 / 额度" action:@"pc-balance" rect:NSMakeRect(219,432,195,32)];
        [self addButton:@"查看完整对话" action:@"pc-transcript" rect:NSMakeRect(16,550,398,22)];
        [self addButton:@"上一页" action:@"library-prev" rect:NSMakeRect(16,300,125,32)];
        [self addButton:@"下一页" action:@"library-next" rect:NSMakeRect(289,300,125,32)];
        [self addButton:@"返回控制面板" action:@"library-back" rect:NSMakeRect(16,348,398,34)];
        self.buttons[@"close"].quiet=YES;
        self.orderedActions=@[@"close",@"duo-block",@"duo-dash",@"duo-reunion",@"feed",@"play",@"pet",@"dance",@"run",@"cuddle",@"nap",@"status",@"toggle-autonomy",@"toggle-pause",@"system-controls",@"preview",@"backup",@"connect",@"quit",@"pc-toggle",@"pc-chat-send",@"pc-whisper",@"pc-balance",@"pc-transcript",@"pc-library"];
        [self setState:_state];
    }
    return self;
}
- (CPDrawnButton *)addButton:(NSString *)title action:(NSString *)action rect:(NSRect)rect {
    CPDrawnButton *button=self.buttons[action];
    if(button){button.title=title;button.frame=rect;return button;}
    button=[[CPDrawnButton alloc] initWithFrame:rect];
    button.actionID=action;button.title=title;button.bordered=NO;button.target=self;button.action=@selector(clicked:);
    [button setButtonType:NSButtonTypeMomentaryPushIn];button.focusRingType=NSFocusRingTypeNone;
    [button setAccessibilityLabel:[action isEqualToString:@"close"]?@"关闭面板":title];
    self.buttons[action]=button;[self addSubview:button];return button;
}
- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return YES; }
- (void)setState:(NSDictionary *)state {
    _state=[state isKindOfClass:NSDictionary.class]?[state copy]:@{};
    BOOL autonomous=CPBool(_state[@"autonomous"]),enabled=CPBool(_state[@"enabled"]),controls=CPBool(_state[@"controlsVisible"]);
    CPDrawnButton *autonomy=self.buttons[@"toggle-autonomy"];
    autonomy.title=autonomous?@"主动互动：开启":@"主动互动：关闭";autonomy.active=autonomous;
    self.buttons[@"toggle-pause"].title=enabled?@"暂停桌宠":@"继续桌宠";
    self.buttons[@"system-controls"].title=controls?@"返回鲸鱼娘和猫咪":@"显示系统音量、亮度等控件";
    self.buttons[@"system-controls"].active=controls;
    for (CPDrawnButton *button in self.buttons.allValues) {
        [button setAccessibilityLabel:[button.actionID isEqualToString:@"close"]?@"关闭面板":button.title];button.needsDisplay=YES;
    }
    [self setAccessibilityValue:[NSString stringWithFormat:@"%@，%@",CPText(_state[@"current"],@"自由活动"),CPText(_state[@"detail"],@"鲸鱼娘和猫咪正在一起玩。")]];
    self.buttons[@"pc-toggle"].title=CPBool(_state[@"pcEnabled"])?@"PC2005 动画：开启":@"原版鲸鱼娘：开启";
    BOOL canRequest=CPBool(_state[@"connected"])&&!CPBool(_state[@"busy"]);
    for(NSString *key in @[@"pc-chat-send",@"pc-whisper",@"pc-balance"])self.buttons[key].enabled=canRequest;
    self.chatField.enabled=!CPBool(_state[@"busy"]);
    [self refreshLibrary];
    self.needsDisplay=YES;
}
- (NSString *)chatText{return self.chatField.stringValue?:@"";}
- (void)clearChatText{self.chatField.stringValue=@"";}
- (void)sendChat:(id)sender{if(self.buttons[@"pc-chat-send"].enabled&&self.actionHandler)self.actionHandler(@"pc-chat-send");}
- (void)showActionLibrary:(BOOL)show{self.libraryVisible=show;self.libraryPage=0;[self refreshLibrary];}
- (void)refreshLibrary {
    NSArray *actions=[self.state[@"actions"] isKindOfClass:NSArray.class]?self.state[@"actions"]:@[];
    NSUInteger pages=MAX(1,(actions.count+11)/12);self.libraryPage=MIN(self.libraryPage,pages-1);
    NSMutableSet *wanted=[NSMutableSet new];
    if(self.libraryVisible)for(NSUInteger i=self.libraryPage*12;i<MIN(self.libraryPage*12+12,actions.count);i++)[wanted addObject:[@"pc-action-" stringByAppendingString:actions[i][@"id"]]];
    for(NSString *key in [self.buttons.allKeys copy])if([key hasPrefix:@"pc-action-"]&&![wanted containsObject:key]){[self.buttons[key] removeFromSuperview];[self.buttons removeObjectForKey:key];}
    for(NSString *key in self.buttons)self.buttons[key].hidden=self.libraryVisible?!([key isEqualToString:@"close"]||[key hasPrefix:@"library-"]||[wanted containsObject:key]):[key hasPrefix:@"library-"];
    self.chatField.hidden=self.libraryVisible;
    if(self.libraryVisible){
        CGFloat width=(398-16)/3.;NSUInteger start=self.libraryPage*12;
        for(NSUInteger i=start;i<MIN(start+12,actions.count);i++){
            NSDictionary *entry=actions[i];NSUInteger n=i-start;
            CPDrawnButton *button=[self addButton:CPText(entry[@"title"],entry[@"id"]) action:[@"pc-action-" stringByAppendingString:entry[@"id"]] rect:NSMakeRect(16+(n%3)*(width+8),96+(n/3)*46,width,36)];
            button.active=[entry[@"title"] isEqualToString:self.state[@"pcAction"]];
        }
    }
    self.buttons[@"library-prev"].enabled=self.libraryPage>0;
    self.buttons[@"library-next"].enabled=self.libraryPage+1<pages;self.needsDisplay=YES;
}
- (void)clicked:(CPDrawnButton *)sender {
    if([sender.actionID isEqualToString:@"library-prev"]){if(self.libraryPage)self.libraryPage--;[self refreshLibrary];return;}
    if([sender.actionID isEqualToString:@"library-next"]){self.libraryPage++;[self refreshLibrary];return;}
    if([sender.actionID isEqualToString:@"library-back"]){[self showActionLibrary:NO];return;}
    if([sender.actionID isEqualToString:@"pc-library"])[self showActionLibrary:YES];
    if(self.actionHandler)self.actionHandler(sender.actionID);
}
- (BOOL)activateAction:(NSString *)action {
    CPDrawnButton *button=self.buttons[action];
    if (!button||!button.enabled) return NO;
    [button performClick:nil];return YES;
}
- (void)drawRect:(NSRect)dirtyRect {
    BOOL dark=CPIsDark(self);
    [CPRGB(dark?0x17191D:0xFAFAFA) setFill];NSRectFill(self.bounds);
    NSColor *primary=CPRGB(dark?0xF5F6F7:0x202226),*secondary=CPRGB(dark?0xB5BDC8:0x59616D);
    if(self.libraryVisible){
        NSArray *actions=[self.state[@"actions"] isKindOfClass:NSArray.class]?self.state[@"actions"]:@[];
        CPDrawText(@"PC2005 原版动作库",NSMakeRect(16,14,358,25),18,YES,primary,NSTextAlignmentLeft);
        CPDrawText([NSString stringWithFormat:@"%lu 段完整动作 · 第 %lu / %lu 页",(unsigned long)actions.count,(unsigned long)self.libraryPage+1,(unsigned long)MAX(1,(actions.count+11)/12)],NSMakeRect(16,53,398,25),12,NO,secondary,NSTextAlignmentLeft);
        CPDrawText(@"点击动作，即刻在 Touch Bar 播放。",NSMakeRect(16,405,398,24),12,NO,primary,NSTextAlignmentLeft);
        CPDrawText([NSString stringWithFormat:@"现在：%@",CPText(self.state[@"pcAction"],@"自由活动")],NSMakeRect(16,441,398,50),13,YES,primary,NSTextAlignmentLeft);
        CPDrawText(@"动作会完整播完；你触摸角色或 DSH 需要处理任务时，会优先响应。",NSMakeRect(16,510,398,65),12,NO,secondary,NSTextAlignmentLeft);return;
    }
    CPDrawText(@"鲸鱼娘与三花猫",NSMakeRect(16,14,358,25),18,YES,primary,NSTextAlignmentLeft);
    CPDrawText(@"当前状态",NSMakeRect(16,53,398,16),11.5,NO,secondary,NSTextAlignmentLeft);
    NSString *current=CPText(self.state[@"current"],@"自由活动"),*detail=CPText(self.state[@"detail"],@"鲸鱼娘和猫咪正在一起玩。");
    CPDrawText(current,NSMakeRect(16,73,398,22),14,YES,primary,NSTextAlignmentLeft);
    CGFloat detailSize=12;
    while (detailSize>10.5) {
        NSRect measure=[detail boundingRectWithSize:NSMakeSize(398,CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:CPFont(detailSize,NO)}];
        if (measure.size.height<=32) break;
        detailSize-=.5;
    }
    CPDrawText(detail,NSMakeRect(16,99,398,33),detailSize,NO,secondary,NSTextAlignmentLeft);
    NSBezierPath *separator=[NSBezierPath bezierPath];
    [separator moveToPoint:NSMakePoint(16,183)];[separator lineToPoint:NSMakePoint(414,183)];
    [separator moveToPoint:NSMakePoint(16,697)];[separator lineToPoint:NSMakePoint(414,697)];
    [CPRGB(dark?0x34383F:0xDEE1E5) setStroke];separator.lineWidth=.6;[separator stroke];
    CPDrawText(@"互动",NSMakeRect(16,190,398,17),11.5,NO,secondary,NSTextAlignmentLeft);
    NSRect replyBox=NSMakeRect(16,477,398,72);
    [CPRGB(dark?0x22262D:0xEDF3F6) setFill];[[NSBezierPath bezierPathWithRoundedRect:replyBox xRadius:8 yRadius:8] fill];
    CPDrawText(CPText(self.state[@"reply"],@"点「来句碎碎念」，或输入一句话和她聊天。"),NSInsetRect(replyBox,10,8),12,NO,primary,NSTextAlignmentLeft);
    CPDrawText(CPText(self.state[@"backend"],@"本地互动"),NSMakeRect(16,660,398,33),11.5,NO,secondary,NSTextAlignmentLeft);
}
- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];self.needsDisplay=YES;
    for (NSView *button in self.subviews) button.needsDisplay=YES;
}
- (BOOL)renderPNGAtPath:(NSString *)path scale:(CGFloat)scale {
    if (!path.length||!isfinite(scale)||scale<.5||scale>4) return NO;
    NSInteger width=(NSInteger)ceil(NSWidth(self.bounds)*scale),height=(NSInteger)ceil(NSHeight(self.bounds)*scale);
    NSBitmapImageRep *rep=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:width pixelsHigh:height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    if (!rep) return NO;rep.size=self.bounds.size;
    [self layoutSubtreeIfNeeded];
    [self cacheDisplayInRect:self.bounds toBitmapImageRep:rep];
    NSData *png=[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    return png&&[png writeToFile:path atomically:YES];
}
+ (NSDictionary *)runInteractionTests {
    NSMutableArray *passed=[NSMutableArray new],*failed=[NSMutableArray new];
    void (^check)(BOOL,NSString *)=^(BOOL ok,NSString *name){[(ok?passed:failed) addObject:name];};
    CompanionPanelView *view=[[self alloc] initWithFrame:NSZeroRect];
    check(NSEqualSizes(view.bounds.size,NSMakeSize(430,750)),@"panel-fits-controls-and-pc2005-chat");
    BOOL inBounds=view.buttons.count==28,nonoverlap=YES;
    NSArray *buttons=view.buttons.allValues;
    for (NSUInteger i=0;i<buttons.count;i++) {
        NSView *button=buttons[i];inBounds&=NSContainsRect(view.bounds,button.frame);
        for (NSUInteger j=i+1;j<buttons.count;j++) if (!button.hidden&&![buttons[j] isHidden]&&NSIntersectsRect(button.frame,[buttons[j] frame])) nonoverlap=NO;
    }
    check(inBounds&&nonoverlap,@"all-visible-native-buttons-fit-without-overlap");
    view.state=@{@"connected":@YES};
    NSMutableArray *delivered=[NSMutableArray new];view.actionHandler=^(NSString *action){[delivered addObject:action];};
    BOOL activated=YES;
    for (NSString *action in view.orderedActions) activated&=[view activateAction:action];
    check(activated&&[delivered isEqualToArray:view.orderedActions],@"every-real-button-performclick-delivers-its-action-once");
    [view showActionLibrary:NO];
    NSUInteger before=delivered.count;
    check(![view activateAction:@"unknown"]&&delivered.count==before,@"unknown-actions-do-not-dispatch");
    view.state=@{@"current":@"猫咪挡路",@"detail":@"鲸鱼娘停下来等猫咪让路。",@"autonomous":@NO,@"enabled":@NO,@"controlsVisible":@YES,@"backend":@"本地互动"};
    check([view.buttons[@"toggle-autonomy"].title isEqualToString:@"主动互动：关闭"]&&[view.buttons[@"toggle-pause"].title isEqualToString:@"继续桌宠"]&&[view.buttons[@"system-controls"].title isEqualToString:@"返回鲸鱼娘和猫咪"]&&[view.state[@"current"] isEqualToString:@"猫咪挡路"],@"live-state-updates-actual-toggle-and-return-button-titles");
    view.state=@{@"connected":@YES,@"actions":@[@{@"id":@"hotpot",@"title":@"吃火锅"}]};
    [view showActionLibrary:YES];CPDrawnButton *clip=view.buttons[@"pc-action-hotpot"];
    [view setState:view.state];[view setState:view.state];
    check(clip==view.buttons[@"pc-action-hotpot"]&&!clip.hidden,@"action-buttons-stay-visible-and-identical-across-live-updates");
    [view activateAction:@"pc-action-hotpot"];
    check([delivered.lastObject isEqualToString:@"pc-action-hotpot"],@"catalogue-button-dispatches-actual-selected-clip");
    [view activateAction:@"library-back"];
    check(!view.buttons[@"feed"].hidden&&view.buttons[@"library-back"].hidden,@"return-from-library-restores-control-buttons");
    return @{@"passed":@(failed.count==0),@"checks":passed,@"failures":failed};
}
@end
