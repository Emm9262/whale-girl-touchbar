#import <Cocoa/Cocoa.h>
#import <objc/message.h>
#import <signal.h>
#import <dlfcn.h>
#import "WhaleScene.h"
#import "WhaleBackend.h"
#import "CatCompanion.h"
#import "PetBarContainer.h"
#import "CompanionPanelView.h"
#import "PCPetAnimation.h"

static const CGFloat PetBarWidth = 920;
static const long long PetBarPlacement = 1;
static const long long SystemControlsPlacement = 0;

static NSString * const TargetID = @"com.deepseek.dsh";
static NSString * const SceneID = @"org.whalegirl.touchbar.scene";
static NSString * const ReturnTrayID = @"org.whalegirl.touchbar.return-to-pets";
static NSString * const ControlsReturnID = @"org.whalegirl.touchbar.controls-return-button";
static NSString * const PauseNotification = @"org.whalegirl.touchbar.pause";
static NSString * const ResumeNotification = @"org.whalegirl.touchbar.resume";
static NSString * const ActionNotification = @"org.whalegirl.touchbar.action";
static NSString * const QuitNotification = @"org.whalegirl.touchbar.quit";

static BOOL SupportsPresentation(void) {
    return [NSTouchBar respondsToSelector:NSSelectorFromString(@"presentSystemModalTouchBar:placement:systemTrayItemIdentifier:")]
        && [NSTouchBar respondsToSelector:NSSelectorFromString(@"dismissSystemModalTouchBar:")];
}
typedef void (*ControlStripPresenceFunction)(NSString *,BOOL);
static ControlStripPresenceFunction ControlStripPresence(void) {
    static ControlStripPresenceFunction function;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *framework=dlopen("/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation",RTLD_LAZY|RTLD_LOCAL);
        if(framework) function=(ControlStripPresenceFunction)dlsym(framework,"DFRElementSetControlStripPresenceForIdentifier");
    });
    return function;
}
static BOOL SupportsReturnTray(void) {
    return ControlStripPresence()!=NULL
        && [NSTouchBarItem respondsToSelector:NSSelectorFromString(@"addSystemTrayItem:")]
        && [NSTouchBarItem respondsToSelector:NSSelectorFromString(@"removeSystemTrayItem:")];
}
static BOOL ShouldShow(NSString *bundle, BOOL enabled, BOOL suspended, BOOL suppressed, BOOL systemControlsVisible) {
    return enabled && !suspended && !suppressed && !systemControlsVisible
        && ![bundle isEqualToString:@"com.apple.loginwindow"];
}
static BOOL ShouldShowControls(NSString *bundle,BOOL enabled,BOOL suspended,BOOL systemControlsVisible) {
    return enabled&&!suspended&&systemControlsVisible&&![bundle isEqualToString:@"com.apple.loginwindow"];
}
static NSString *DuoStoryTitle(NSString *story) {
    return @{@"block":@"猫咪挡路",@"dash":@"跑远等你",@"reunion":@"回来陪你"}[story?:@""]?:@"自由活动";
}
static NSString *DuoPhaseTitle(NSString *story,NSString *phase) {
    NSDictionary *all=@{
        @"block":@{@"approach":@"小猫跑到她前面，准备挡路",@"blocked":@"她停下看看，小猫还挡在前面",@"sidestep":@"她正在绕开小猫",@"intercept":@"小猫又跑到前面拦她",@"standoff":@"两位停下来对视，小猫蹦一下",@"breakaway":@"她加速跑开，小猫在后面追",@"yield":@"小猫让路，她慢慢走过去",@"rejoin":@"小猫追上来，回到她身边",@"together":@"一起散步，闹完又和好"},
        @"dash":@{@"walk":@"先一起走一小段",@"sprint":@"她突然跑远，小猫努力追赶",@"wait":@"她停下回头等，小猫还在追",@"catchup":@"她继续等，小猫加快速度追上来",@"close":@"小猫追到了，她开心地迎接它",@"together":@"一起慢慢走",@"rest":@"两位靠近歇一会儿"},
        @"reunion":@{@"depart":@"小猫跑开，她还没注意到",@"notice":@"她停下来，回头看看小猫",@"return":@"小猫正跑回她身边",@"close":@"小猫回来了，两位凑近",@"rest":@"一起安静歇一会儿",@"stroll":@"休息好了，继续一起散步"}
    };
    return all[story?:@""][phase?:@""]?:@"这一段正在进行";
}
static NSString *FreeActivityTitle(NSString *behavior) {
    return @{@"run":@"鲸鱼娘在跑动",@"play":@"鲸鱼娘在玩耍",@"dance":@"鲸鱼娘在跳舞",@"snack":@"鲸鱼娘在吃东西",@"sulk":@"鲸鱼娘闹了点小脾气",@"cuddle":@"鲸鱼娘在撒娇",@"hungry":@"鲸鱼娘有点饿了",@"nap":@"鲸鱼娘在打盹",@"feed":@"鲸鱼娘正在吃你投喂的食物",@"eat":@"鲸鱼娘正在吃东西",@"drag":@"正在跟着你的手指移动",@"think":@"鲸鱼娘在思考",@"working":@"鲸鱼娘陪你工作",@"wait":@"鲸鱼娘正在等你",@"walk":@"鲸鱼娘在散步",@"joy":@"鲸鱼娘很开心",@"celebrate":@"鲸鱼娘在庆祝",@"sleep":@"鲸鱼娘睡着了",@"wake":@"鲸鱼娘刚刚醒来"}[behavior?:@""]?:@"鲸鱼娘和小猫正在自由活动";
}
static NSDictionary *PresentationPolicyTests(void) {
    NSMutableArray *passed=[NSMutableArray new],*failed=[NSMutableArray new];
    void (^check)(BOOL,NSString *)=^(BOOL ok,NSString *name){[(ok?passed:failed) addObject:name];};
    for(NSString *bundle in @[@"com.deepseek.dsh",@"com.apple.finder",@"com.openai.codex",@"com.apple.Safari",@"com.apple.Terminal",@"org.example.other-app"]) {
        check(ShouldShow(bundle,YES,NO,NO,NO),[NSString stringWithFormat:@"global-pets-show-in-%@",bundle]);
        check(!ShouldShow(bundle,YES,NO,NO,YES),[NSString stringWithFormat:@"system-controls-stay-open-in-%@",bundle]);
        check(ShouldShowControls(bundle,YES,NO,YES),[NSString stringWithFormat:@"named-return-button-stays-with-system-controls-in-%@",bundle]);
    }
    check(ShouldShow(nil,YES,NO,NO,NO),@"global-pets-also-support-apps-without-a-bundle-identifier");
    check(!ShouldShow(@"com.apple.loginwindow",YES,NO,NO,NO),@"login-window-never-receives-pet-overlay");
    check(!ShouldShow(TargetID,NO,NO,NO,NO),@"pause-restores-system-touchbar");
    check(!ShouldShow(TargetID,YES,YES,NO,NO),@"sleep-or-lock-restores-system-touchbar");
    check(!ShouldShow(TargetID,YES,NO,YES,NO),@"system-dismissal-is-respected-until-resumed");
    check(ShouldShow(@"com.apple.finder",YES,NO,NO,NO),@"returning-from-controls-restores-pets-outside-dsh");
    check(!ShouldShowControls(TargetID,NO,NO,YES)&&!ShouldShowControls(TargetID,YES,YES,YES),@"return-touchbar-dismisses-during-pause-and-sleep");
    check(!ShouldShowControls(@"com.apple.loginwindow",YES,NO,YES)&&!ShouldShowControls(TargetID,YES,NO,NO),@"return-touchbar-only-appears-in-system-controls-mode");
    return @{@"passed":@(failed.count==0),@"checks":passed,@"failures":failed};
}
static void SendJSON(NSDictionary *value) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:nil];
    fwrite(data.bytes, 1, data.length, stdout); fputc('\n', stdout); fflush(stdout);
}

@interface WhaleApp : NSObject <NSApplicationDelegate, NSTouchBarDelegate, NSWindowDelegate, NSMenuDelegate>
@property NSStatusItem *statusItem;
@property NSStatusItem *returnStatusItem;
@property NSPopover *controlPopover;
@property CompanionPanelView *controlView;
@property NSString *panelFeedback;
@property NSTimeInterval panelFeedbackUntil;
@property NSString *lastPCReply;
@property NSMutableString *pcTranscript;
@property NSWindow *pcTranscriptWindow;
@property NSTextView *pcTranscriptView;
@property NSMenuItem *stateItem;
@property NSMenuItem *phaseItem;
@property NSArray<NSMenuItem *> *storyMenuItems;
@property NSMenuItem *toggleItem;
@property NSMenuItem *backendItem;
@property NSMenuItem *petInfoItem;
@property NSMenuItem *autonomyItem;
@property NSMenuItem *needsItem;
@property NSMenuItem *controlsItem;
@property WhaleBackend *backend;
@property NSTouchBar *petBar;
@property NSTouchBar *controlsBar;
@property NSButton *controlsReturnButton;
@property BOOL controlsPresented;
@property WhaleScene *scene;
@property PetBarContainer *barContainer;
@property NSCustomTouchBarItem *returnTrayItem;
@property NSButton *returnButton;
@property BOOL trayRegistered;
@property BOOL systemControlsVisible;
@property WhaleScene *previewScene;
@property NSWindow *previewWindow;
@property NSTimer *monitor;
@property BOOL enabled;
@property BOOL suspended;
@property NSMutableSet<NSString *> *suspendReasons;
@property BOOL suppressed;
@property BOOL presented;
@property BOOL sawVisible;
@property NSString *lastFront;
@property NSString *lastReportedBehavior;
@property NSString *lastReportedCatActivity;
@property NSString *lastReportedDuoStory;
@property NSString *lastReportedDuoPhase;
@property NSString *statusPath;
@property NSString *eventPath;
@property dispatch_source_t termSource;
@property dispatch_source_t interruptSource;
@end

@implementation WhaleApp
- (void)logEvent:(NSString *)event bundle:(NSString *)bundle {
    if (!self.statusPath.length || !self.eventPath.length) return;
    NSDictionary *state = @{@"time":@([[NSDate date] timeIntervalSince1970]), @"event":event,
        @"frontmostBundle":bundle ?: @"", @"presented":@(self.presented),
        @"enabled":@(self.enabled), @"barVisible":@(self.petBar.isVisible), @"suspended":@(self.suspended),
        @"suppressed":@(self.suppressed), @"backendTargetBundle":TargetID, @"version":@"12.0.2", @"statusUI":@"drawn-control-panel", @"controlPanelVisible":@(self.controlPopover.shown), @"controlPanelState":@{@"current":self.controlView.state[@"current"]?:@"",@"detail":self.controlView.state[@"detail"]?:@""}, @"statusMenu":@{@"current":self.stateItem.title?:@"",@"detail":self.phaseItem.title?:@"",@"stories":[self.storyMenuItems valueForKey:@"title"]?:@[]}, @"statusToolTip":self.statusItem.button.toolTip?:@"", @"duoStory":self.scene.duoStory?:@"none", @"duoPhase":self.scene.duoPhase?:@"idle", @"dialogueBubblesVisible":@NO, @"displayScope":@"all-apps", @"systemControlsVisible":@(self.systemControlsVisible), @"controlsBarPresented":@(self.controlsPresented), @"controlsBarVisible":@(self.controlsBar.isVisible), @"controlsReturnTitle":self.controlsReturnButton.title?:@"", @"menuReturnVisible":@(self.returnStatusItem!=nil), @"returnCircleRegistered":@(self.trayRegistered), @"returnCircleWindowVisible":@(self.returnButton.window.visible), @"idlePairThresholdSeconds":@5, @"waterWorld":@YES, @"companionKind":@"cat", @"companionStyle":@"05-calico-picturebook", @"sceneWidth":@(self.scene.bounds.size.width), @"companionBehavior":self.scene.companionBehavior ?: @"idle", @"companionActivity":self.scene.companionActivity?:@"follow", @"fullWidth":@YES, @"animationState":self.scene.currentState ?: @"idle", @"behavior":self.scene.currentBehavior ?: @"idle", @"autonomousEnabled":@(self.scene.autonomousEnabled), @"backendConnected":@(self.backend.connected), @"backendProvider":@"PC2005-cloud/dsh-pet", @"backendOrigin":self.backend.baseURL.absoluteString?:@"", @"pc2005Enabled":@(self.scene.pc2005Enabled), @"pcAnimation":self.scene.pcActionTitle?:@"", @"pcWalking":@(self.scene.pcWalking), @"pcAssets":[PCPetAnimation assetSummary]};
    NSData *data = [NSJSONSerialization dataWithJSONObject:state options:NSJSONWritingPrettyPrinted error:nil];
    [data writeToFile:self.statusPath atomically:YES];
    NSData *line = [NSJSONSerialization dataWithJSONObject:state options:0 error:nil];
    NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:self.eventPath];
    if (file) { if ([file seekToEndOfFile] > 1048576) [file truncateFileAtOffset:0]; [file seekToEndOfFile]; [file writeData:line]; [file writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]]; [file closeFile]; }
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    for (NSRunningApplication *app in NSWorkspace.sharedWorkspace.runningApplications) {
        if ([app.bundleIdentifier isEqualToString:NSBundle.mainBundle.bundleIdentifier] && app.processIdentifier != getpid()) {
            [NSApp terminate:nil]; return;
        }
    }
    self.enabled = YES;
    self.suspendReasons = [NSMutableSet new];
    NSString *folder = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/WhaleGirlTouchBar"];
    [NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
    self.statusPath = [folder stringByAppendingPathComponent:@"status.json"];
    self.eventPath = [folder stringByAppendingPathComponent:@"events.jsonl"];
    if (![NSFileManager.defaultManager fileExistsAtPath:self.eventPath]) [NSFileManager.defaultManager createFileAtPath:self.eventPath contents:nil attributes:nil];
    // Bound our own event log; no target app content is collected.
    NSDictionary *attrs = [NSFileManager.defaultManager attributesOfItemAtPath:self.eventPath error:nil];
    if ([attrs fileSize] > 524288) [[NSData data] writeToFile:self.eventPath atomically:YES];

    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    NSImage *icon = [NSImage imageWithSystemSymbolName:@"fish.fill" accessibilityDescription:@"鲸鱼娘"];
    icon.template = YES;
    self.statusItem.button.image = icon;
    self.statusItem.button.toolTip = @"鲸鱼娘与三花猫 · 所有应用陪伴";
    if (!icon) self.statusItem.button.title = @"鲸";
    NSMenu *menu = [NSMenu new];
    self.controlsItem = [menu addItemWithTitle:@"显示系统音量、亮度等控件" action:@selector(toggleSystemControls:) keyEquivalent:@""]; self.controlsItem.target = self;
    [menu addItem:NSMenuItem.separatorItem];
    self.stateItem = [menu addItemWithTitle:@"鲸鱼娘正在准备…" action:nil keyEquivalent:@""];
    self.phaseItem=[menu addItemWithTitle:@"点「播放双宠剧情」可立即选一段观看" action:nil keyEquivalent:@""];
    NSMenuItem *stories=[menu addItemWithTitle:@"播放双宠剧情" action:nil keyEquivalent:@""];
    NSMenu *storyMenu=[[NSMenu alloc] initWithTitle:@"播放双宠剧情"];
    NSMutableArray *storyItems=[NSMutableArray new];
    for(NSArray *entry in @[@[@"猫咪挡路 · 拦路 → 绕开 → 再拦",@"duo-block"],@[@"跑远等你 · 加速 → 回头等 → 追上",@"duo-dash"],@[@"回来陪你 · 跑开 → 察觉 → 团聚",@"duo-reunion"]]) {
        NSMenuItem *item=[storyMenu addItemWithTitle:entry[0] action:@selector(playDuoStory:) keyEquivalent:@""];
        item.target=self;item.representedObject=entry[1];[storyItems addObject:item];
    }
    stories.submenu=storyMenu;self.storyMenuItems=storyItems;
    [menu addItem:NSMenuItem.separatorItem];
    self.backendItem = [menu addItemWithTitle:@"本地互动 · 未连接 DSH whale-girl 插件" action:nil keyEquivalent:@""];
    self.petInfoItem = [menu addItemWithTitle:@"鲸鱼娘 · 三花绘本猫" action:nil keyEquivalent:@""];
    self.needsItem = [menu addItemWithTitle:@"她正在等你…" action:nil keyEquivalent:@""];
    self.autonomyItem = [menu addItemWithTitle:@"主动互动：开启" action:@selector(toggleAutonomy:) keyEquivalent:@""]; self.autonomyItem.target = self;
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *feed = [menu addItemWithTitle:@"🍗 投喂鲸鱼娘" action:@selector(feed:) keyEquivalent:@""]; feed.target = self;
    NSMenuItem *play = [menu addItemWithTitle:@"🎾 陪鲸鱼娘玩" action:@selector(play:) keyEquivalent:@""]; play.target = self;
    NSArray *extras = @[@[@"💕 摸摸头",@"pet"],@[@"🎵 跳个舞",@"dance"],@[@"🏃 跑一圈",@"run"],@[@"🥺 撒个娇",@"cuddle"],@[@"🍽 饿不饿？",@"status"],@[@"😴 打个小盹",@"nap"]];
    for (NSArray *entry in extras) {
        NSMenuItem *item = [menu addItemWithTitle:entry[0] action:@selector(companionAction:) keyEquivalent:@""];
        item.target = self; item.representedObject = entry[1];
    }
    [menu addItem:NSMenuItem.separatorItem];
    self.toggleItem = [menu addItemWithTitle:@"暂停鲸鱼娘，恢复原 Touch Bar" action:@selector(toggle:) keyEquivalent:@""];
    self.toggleItem.target = self;
    NSMenuItem *preview = [menu addItemWithTitle:@"看看鲸鱼娘（桌面预览）" action:@selector(showPreview:) keyEquivalent:@""];
    preview.target = self;
    NSMenuItem *backup = [menu addItemWithTitle:@"打开使用帮助" action:@selector(showBackup:) keyEquivalent:@""];
    backup.target = self;
    NSMenuItem *connect = [menu addItemWithTitle:@"连接 PC2005 桌宠宿主…" action:@selector(configureBackend:) keyEquivalent:@""]; connect.target = self;
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *quit = [menu addItemWithTitle:@"退出鲸鱼娘，恢复原 Touch Bar" action:@selector(quit:) keyEquivalent:@"q"];
    quit.target = self;
    self.statusItem.menu=nil;self.statusItem.button.target=self;self.statusItem.button.action=@selector(toggleControlPanel:);
    self.scene = [[WhaleScene alloc] initWithFrame:NSMakeRect(0, 0, PetBarWidth-36, 30)];
    id pcPreference=[NSUserDefaults.standardUserDefaults objectForKey:@"PC2005.Enabled"];
    self.scene.pc2005Enabled=pcPreference?[pcPreference boolValue]:YES;
    self.pcTranscript=[NSMutableString new];
    self.barContainer = [[PetBarContainer alloc] initWithFrame:NSMakeRect(0,0,PetBarWidth,30) scene:self.scene];
    __weak WhaleApp *buttonOwner = self;
    self.barContainer.systemControlsHandler = ^{ [buttonOwner showSystemControls:nil]; };
    id autonomousPreference = [NSUserDefaults.standardUserDefaults objectForKey:@"WhaleGirlV3.AutonomousEnabled"];
    self.scene.autonomousEnabled = autonomousPreference ? [autonomousPreference boolValue] : YES;
    self.petBar = [NSTouchBar new];
    self.petBar.delegate = self;
    self.controlsBar=[NSTouchBar new];self.controlsBar.delegate=self;
    self.controlsBar.defaultItemIdentifiers=@[ControlsReturnID,NSTouchBarItemIdentifierFlexibleSpace];
    [self.petBar addObserver:self forKeyPath:@"visible" options:NSKeyValueObservingOptionNew context:NULL];
    self.petBar.defaultItemIdentifiers = @[SceneID];
    self.petBar.principalItemIdentifier = SceneID;
    NSNotificationCenter *workspace = NSWorkspace.sharedWorkspace.notificationCenter;
    [workspace addObserver:self selector:@selector(frontChanged:) name:NSWorkspaceDidActivateApplicationNotification object:nil];
    [workspace addObserver:self selector:@selector(sleep:) name:NSWorkspaceWillSleepNotification object:nil];
    [workspace addObserver:self selector:@selector(sleep:) name:NSWorkspaceScreensDidSleepNotification object:nil];
    [workspace addObserver:self selector:@selector(sleep:) name:NSWorkspaceSessionDidResignActiveNotification object:nil];
    [workspace addObserver:self selector:@selector(wake:) name:NSWorkspaceDidWakeNotification object:nil];
    [workspace addObserver:self selector:@selector(wake:) name:NSWorkspaceScreensDidWakeNotification object:nil];
    [workspace addObserver:self selector:@selector(wake:) name:NSWorkspaceSessionDidBecomeActiveNotification object:nil];
    NSDistributedNotificationCenter *distributed = NSDistributedNotificationCenter.defaultCenter;
    [distributed addObserver:self selector:@selector(sleep:) name:@"com.apple.screenIsLocked" object:nil];
    [distributed addObserver:self selector:@selector(wake:) name:@"com.apple.screenIsUnlocked" object:nil];
    [distributed addObserver:self selector:@selector(pause:) name:PauseNotification object:nil];
    [distributed addObserver:self selector:@selector(resume:) name:ResumeNotification object:nil];
    [distributed addObserver:self selector:@selector(quit:) name:QuitNotification object:nil];
    [distributed addObserver:self selector:@selector(remoteAction:) name:ActionNotification object:nil];
    // SIGTERM/INT are handled on the main queue, so normal termination always dismisses.
    signal(SIGTERM, SIG_IGN); signal(SIGINT, SIG_IGN);
    self.termSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGTERM, 0, dispatch_get_main_queue());
    self.interruptSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGINT, 0, dispatch_get_main_queue());
    __weak WhaleApp *weak = self;
    self.scene.interactionHandler = ^(NSString *action) { [weak.backend interact:action]; };
    [self createBackend:nil];
    [self createControlPanel];
    dispatch_source_set_event_handler(self.termSource, ^{ [weak quit:nil]; });
    dispatch_source_set_event_handler(self.interruptSource, ^{ [weak quit:nil]; });
    dispatch_resume(self.termSource); dispatch_resume(self.interruptSource);
    self.monitor = [NSTimer timerWithTimeInterval:0.35 repeats:YES block:^(NSTimer *timer) { [weak updateFront]; }];
    self.monitor.tolerance = 0.08;
    [NSRunLoop.mainRunLoop addTimer:self.monitor forMode:NSRunLoopCommonModes];
    [self logEvent:SupportsPresentation() ? @"started" : @"unsupported-runtime" bundle:nil];
    [self registerReturnCircle];
    [self updateFront];
}
- (void)registerReturnCircle {
    if(!SupportsReturnTray()||self.trayRegistered) return;
    NSImage *image=[NSImage imageWithSystemSymbolName:@"circle" accessibilityDescription:@"回到鲸鱼娘和小猫"];
    if(!image) return;
    image=[image imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:14 weight:NSFontWeightRegular]];
    self.returnButton=[NSButton buttonWithImage:image target:self action:@selector(returnToPets:)];
    self.returnButton.translatesAutoresizingMaskIntoConstraints=NO;
    self.returnButton.frame=NSMakeRect(0,0,36,30);
    self.returnButton.bordered=NO;self.returnButton.imagePosition=NSImageOnly;
    self.returnButton.toolTip=@"回到鲸鱼娘和小猫";
    [self.returnButton setAccessibilityLabel:@"回到鲸鱼娘和小猫"];
    [self.returnButton.widthAnchor constraintEqualToConstant:36].active=YES;
    [self.returnButton.heightAnchor constraintEqualToConstant:30].active=YES;
    self.returnTrayItem=[[NSCustomTouchBarItem alloc] initWithIdentifier:ReturnTrayID];self.returnTrayItem.view=self.returnButton;
    @try {
        ((void (*)(id,SEL,NSTouchBarItem *))objc_msgSend)(NSTouchBarItem.class,NSSelectorFromString(@"addSystemTrayItem:"),self.returnTrayItem);
        self.trayRegistered=YES;ControlStripPresence()(ReturnTrayID,YES);
    } @catch(NSException *exception) { [self unregisterReturnCircle]; }
}
- (void)unregisterReturnCircle {
    if(!self.trayRegistered) return;
    @try {
        if(ControlStripPresence()) ControlStripPresence()(ReturnTrayID,NO);
        if([NSTouchBarItem respondsToSelector:NSSelectorFromString(@"removeSystemTrayItem:")])
            ((void (*)(id,SEL,NSTouchBarItem *))objc_msgSend)(NSTouchBarItem.class,NSSelectorFromString(@"removeSystemTrayItem:"),self.returnTrayItem);
    } @catch(NSException *exception) { }
    self.trayRegistered=NO;self.returnTrayItem=nil;self.returnButton=nil;
}
- (NSTouchBarItem *)touchBar:(NSTouchBar *)bar makeItemForIdentifier:(NSTouchBarItemIdentifier)identifier {
    if(bar==self.controlsBar&&[identifier isEqualToString:ControlsReturnID]) {
        NSCustomTouchBarItem *item=[[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        self.controlsReturnButton=[NSButton buttonWithTitle:@"🐾 返回桌宠" target:self action:@selector(returnToPets:)];
        self.controlsReturnButton.translatesAutoresizingMaskIntoConstraints=NO;
        self.controlsReturnButton.font=[NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
        self.controlsReturnButton.bezelStyle=NSBezelStyleTexturedRounded;
        self.controlsReturnButton.toolTip=@"收起系统控件，继续显示鲸鱼娘和小猫";
        [self.controlsReturnButton setAccessibilityLabel:@"返回鲸鱼娘和小猫"];
        [self.controlsReturnButton.widthAnchor constraintEqualToConstant:120].active=YES;
        [self.controlsReturnButton.heightAnchor constraintEqualToConstant:30].active=YES;
        item.view=self.controlsReturnButton;return item;
    }
    if (![identifier isEqualToString:SceneID]) return nil;
    NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
    self.barContainer.translatesAutoresizingMaskIntoConstraints = NO;
    item.view = self.barContainer;
    // Prefer filling all available space, but retain the known-good minimum.
    [self.barContainer setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSLayoutConstraint *preferred = [self.barContainer.widthAnchor constraintEqualToConstant:1004];
    preferred.priority = NSLayoutPriorityDefaultHigh; preferred.active = YES;
    [self.barContainer.widthAnchor constraintGreaterThanOrEqualToConstant:PetBarWidth].active = YES;
    [self.barContainer.widthAnchor constraintLessThanOrEqualToConstant:1004].active = YES;
    [self.barContainer.heightAnchor constraintEqualToConstant:30].active = YES;
    return item;
}
- (void)frontChanged:(NSNotification *)note { [self updateFront]; }
- (void)updateFront {
    NSString *front = NSWorkspace.sharedWorkspace.frontmostApplication.bundleIdentifier ?: @"";
    BOOL changed = ![front isEqualToString:self.lastFront];
    if (changed) self.suppressed = NO;
    self.lastFront = front;
    BOOL show = ShouldShow(front, self.enabled, self.suspended, self.suppressed, self.systemControlsVisible) && SupportsPresentation();
    if (show && !self.presented) {
        [self dismissControlsBar];
        SEL selector = NSSelectorFromString(@"presentSystemModalTouchBar:placement:systemTrayItemIdentifier:");
        @try {
            ((void (*)(id, SEL, NSTouchBar *, long long, NSString *))objc_msgSend)(NSTouchBar.class, selector, self.petBar, PetBarPlacement, self.trayRegistered ? ReturnTrayID : nil);
            self.presented = YES;
            self.sawVisible = self.petBar.isVisible;
            self.scene.animating = self.petBar.isVisible;
            if (self.petBar.isVisible) [self.backend start];
            [self logEvent:@"presented" bundle:front];
        } @catch (NSException *exception) {
            self.enabled = NO; [self dismiss]; [self logEvent:@"presentation-failed" bundle:front];
        }
    } else if (!show && self.presented) {
        [self dismiss]; [self logEvent:@"dismissed" bundle:front];
    } else if (changed) {
        [self logEvent:@"front-changed" bundle:front];
    }
    BOOL showControls=ShouldShowControls(front,self.enabled,self.suspended,self.systemControlsVisible)&&SupportsPresentation();
    if(showControls&&!self.controlsPresented) {
        @try {
            ((void (*)(id,SEL,NSTouchBar *,long long,NSString *))objc_msgSend)(NSTouchBar.class,NSSelectorFromString(@"presentSystemModalTouchBar:placement:systemTrayItemIdentifier:"),self.controlsBar,SystemControlsPlacement,nil);
            self.controlsPresented=YES;[self logEvent:@"system-controls-return-button-shown" bundle:front];
        } @catch(NSException *exception) { self.controlsPresented=NO; }
    } else if(!showControls&&self.controlsPresented) [self dismissControlsBar];
    [self updateReturnStatusItem];
    if (!SupportsPresentation()) self.stateItem.title = @"当前系统接口不可用，已保持原 Touch Bar";
    else if (!self.enabled) self.stateItem.title = @"已暂停 · 原 Touch Bar";
    else if (self.suspended) self.stateItem.title = @"休息中 · 原 Touch Bar";
    else if (self.systemControlsVisible) self.stateItem.title = @"系统控件 · 点「🐾 返回桌宠」继续陪伴";
    else if (self.suppressed) self.stateItem.title = @"已收起 · 点圆圈或菜单继续陪伴";
    else if(!self.presented) self.stateItem.title=@"等待继续陪伴 · 原 Touch Bar";
    else if(![self.scene.duoStory isEqualToString:@"none"]) self.stateItem.title=[@"当前剧情：" stringByAppendingString:DuoStoryTitle(self.scene.duoStory)];
    else if([self.scene.companionActivity isEqualToString:@"roam"]) self.stateItem.title=@"小猫自己去玩啦 · 鲸鱼娘在旁边♡";
    else if([self.scene.companionActivity isEqualToString:@"return"]) self.stateItem.title=@"小猫玩累了，正在回她身边♡";
    else if([self.scene.companionActivity isEqualToString:@"rest"]) self.stateItem.title=@"小猫在鲸鱼娘身边歇一会儿♡";
    else self.stateItem.title=@"鲸鱼娘与小猫一起陪你♡";
    if(!self.enabled||self.suspended||self.systemControlsVisible||self.suppressed||!self.presented)
        self.phaseItem.title=@"选择「播放双宠剧情」可返回桌宠并播放";
    else if(![self.scene.duoStory isEqualToString:@"none"])
        self.phaseItem.title=[@"现在：" stringByAppendingString:DuoPhaseTitle(self.scene.duoStory,self.scene.duoPhase)];
    else self.phaseItem.title=[@"现在：" stringByAppendingString:FreeActivityTitle(self.scene.currentBehavior)];
    self.statusItem.button.toolTip=[NSString stringWithFormat:@"%@\n%@\n点开菜单，可选择三段双宠剧情",self.stateItem.title,self.phaseItem.title];
    NSString *behavior = self.scene.currentBehavior ?: @"idle";
    if (![behavior isEqualToString:self.lastReportedBehavior]) {
        self.lastReportedBehavior = behavior;
        [self logEvent:@"behavior-changed" bundle:front];
    }
    NSString *catActivity=self.scene.companionActivity?:@"follow";
    if(![catActivity isEqualToString:self.lastReportedCatActivity]) {
        self.lastReportedCatActivity=catActivity;[self logEvent:@"cat-activity-changed" bundle:front];
    }
    NSString *duo=self.scene.duoStory?:@"none",*phase=self.scene.duoPhase?:@"idle";
    if(![duo isEqualToString:self.lastReportedDuoStory]||![phase isEqualToString:self.lastReportedDuoPhase]) {
        self.lastReportedDuoStory=duo;self.lastReportedDuoPhase=phase;
        [self logEvent:@"duo-story-phase-changed" bundle:front];
    }
    self.needsItem.title = self.scene.needsSummary ?: @"她正在等你…";
    self.autonomyItem.title = self.scene.autonomousEnabled ? @"主动互动：开启" : @"主动互动：关闭";
    self.controlsItem.title = self.systemControlsVisible ? @"🐾 返回桌宠（鲸鱼娘与小猫）" : @"显示系统音量、亮度等控件";
    self.toggleItem.title = self.enabled ? @"暂停鲸鱼娘，恢复原 Touch Bar" : @"继续显示鲸鱼娘与小猫";
    [self updateControlPanel];
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == self.petBar && [keyPath isEqualToString:@"visible"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.petBar.isVisible && self.presented) {
                self.sawVisible = YES;
                self.scene.animating = YES;
                [self.backend start];
                [self logEvent:@"visible" bundle:self.lastFront];
            } else if (self.sawVisible && self.presented) {
                self.suppressed = YES;
                [self dismiss];
                [self logEvent:@"closed-by-system-or-user" bundle:self.lastFront];
                [self updateFront];
            }
        });
    } else { [super observeValueForKeyPath:keyPath ofObject:object change:change context:context]; }
}
- (void)dismiss {
    self.scene.animating = NO;
    [self.backend stop];
    self.sawVisible = NO;
    if (self.presented && [NSTouchBar respondsToSelector:NSSelectorFromString(@"dismissSystemModalTouchBar:")]) {
        @try { ((void (*)(id, SEL, NSTouchBar *))objc_msgSend)(NSTouchBar.class, NSSelectorFromString(@"dismissSystemModalTouchBar:"), self.petBar); }
        @catch (NSException *exception) { /* Leave the original system services alone. */ }
    }
    self.presented = NO;
}
- (void)dismissControlsBar {
    if(self.controlsPresented&&[NSTouchBar respondsToSelector:NSSelectorFromString(@"dismissSystemModalTouchBar:")]) {
        @try { ((void (*)(id,SEL,NSTouchBar *))objc_msgSend)(NSTouchBar.class,NSSelectorFromString(@"dismissSystemModalTouchBar:"),self.controlsBar); }
        @catch(NSException *exception) { }
    }
    self.controlsPresented=NO;
}
- (void)updateReturnStatusItem {
    BOOL show=self.systemControlsVisible&&self.enabled&&!self.suspended;
    if(show&&!self.returnStatusItem) {
        self.returnStatusItem=[NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
        self.returnStatusItem.button.title=@"🐾 回桌宠";
        self.returnStatusItem.button.target=self;self.returnStatusItem.button.action=@selector(returnToPets:);
        self.returnStatusItem.button.toolTip=@"收起系统控件，回到鲸鱼娘和小猫";
        [self.returnStatusItem.button setAccessibilityLabel:@"回到鲸鱼娘和小猫"];
    } else if(!show&&self.returnStatusItem) {
        [NSStatusBar.systemStatusBar removeStatusItem:self.returnStatusItem];self.returnStatusItem=nil;
    }
}
- (void)createBackend:(NSURL *)url {
    [self.backend stop];
    self.backend = url ? [[WhaleBackend alloc] initWithBaseURL:url] : [WhaleBackend new];
    __weak WhaleApp *weak = self;
    self.backend.snapshotHandler = ^(NSDictionary *snapshot) {
        [weak.scene applyBackendSnapshot:snapshot];
        [weak.previewScene applyBackendSnapshot:snapshot];
        [weak updateControlPanel];
        NSDictionary *pet = snapshot[@"pet"];
        if ([pet[@"level"] isKindOfClass:NSNumber.class]) weak.petInfoItem.title = [NSString stringWithFormat:@"鲸鱼娘 · Lv.%@（DSH 原始成长记录）", pet[@"level"]];
    };
    self.backend.statusHandler = ^(NSString *status) {
        weak.backendItem.title = status;
        [weak updateControlPanel];
        if (!weak.backend.connected) {
            [weak.scene applyBackendSnapshot:@{}];
            [weak.previewScene applyBackendSnapshot:@{}];
            weak.petInfoItem.title = @"鲸鱼娘 · 三花绘本猫";
        }
    };
    self.backend.replyHandler = ^(NSString *reply) {
        weak.lastPCReply=reply;
        [weak.pcTranscript appendFormat:@"鲸鱼娘：%@\n\n",reply];
        [weak.scene showReply:reply];[weak.previewScene showReply:reply];
        if(weak.scene.pc2005Enabled)[weak.scene playPCAction:@"whisper"];if(weak.previewScene.pc2005Enabled)[weak.previewScene playPCAction:@"whisper"];
        [weak updatePCTranscript];[weak updateControlPanel];
    };
}
- (void)configureBackend:(id)sender {
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"连接 PC2005 桌宠宿主";
    alert.informativeText = @"通常无需修改：默认会自动发现 DSH 端口。手动连接仅支持本机 HTTP 地址。聊天和碎碎念会使用 DSH 当前模型额度。";
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0,0,360,24)];
    field.stringValue = self.backend.baseURL.absoluteString ?: @"http://127.0.0.1:3080";
    alert.accessoryView = field; [alert addButtonWithTitle:@"连接"]; [alert addButtonWithTitle:@"取消"];
    if ([alert runModal] != NSAlertFirstButtonReturn) return;
    NSURL *url = [NSURL URLWithString:[field.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
    WhaleBackend *candidate = url ? [[WhaleBackend alloc] initWithBaseURL:url] : nil;
    if (!candidate) {
        NSAlert *invalid = [NSAlert new]; invalid.messageText = @"请输入有效的本机 HTTP 地址";
        invalid.informativeText = @"例如 http://127.0.0.1:3080，只支持这台电脑上的服务。"; [invalid runModal]; return;
    }
    [self createBackend:url];
    if (self.presented && self.petBar.isVisible) [self.backend start];
}
- (WhaleScene *)interactionScene {
    return self.previewWindow.isKeyWindow ? self.previewScene : self.scene;
}
- (void)toggleAutonomy:(id)sender {
    self.scene.autonomousEnabled = !self.scene.autonomousEnabled;
    self.previewScene.autonomousEnabled = self.scene.autonomousEnabled;
    [NSUserDefaults.standardUserDefaults setBool:self.scene.autonomousEnabled forKey:@"WhaleGirlV3.AutonomousEnabled"];
    [self updateFront];
}
- (void)createControlPanel {
    self.controlView=[[CompanionPanelView alloc] initWithFrame:NSMakeRect(0,0,CompanionPanelView.preferredSize.width,CompanionPanelView.preferredSize.height)];
    __weak WhaleApp *owner=self;
    self.controlView.actionHandler=^(NSString *action){[owner controlAction:action];};
    NSViewController *controller=[NSViewController new];controller.view=self.controlView;
    self.controlPopover=[NSPopover new];self.controlPopover.behavior=NSPopoverBehaviorTransient;
    self.controlPopover.contentViewController=controller;self.controlPopover.contentSize=CompanionPanelView.preferredSize;
    self.controlPopover.animates=NO;
}
- (void)updateControlPanel {
    if(!self.controlView) return;
    NSString *detail=self.panelFeedbackUntil>NSDate.date.timeIntervalSince1970?self.panelFeedback:self.phaseItem.title;
    NSString *current=self.stateItem.title?:@"鲸鱼娘与三花猫";
    if([current hasPrefix:@"当前剧情："])current=[current substringFromIndex:[@"当前剧情：" length]];
    NSDictionary *summary=self.backend.petSummary?:@{};
    NSString *task=[summary[@"taskLabel"] isKindOfClass:NSString.class]?summary[@"taskLabel"]:@"";
    if(self.backend.connected&&task.length&&![summary[@"taskState"] isEqualToString:@"idle"]){current=task;detail=summary[@"taskDetail"]?:detail;}
    NSString *reply=self.backend.actionBusy?@"正在处理你的请求，请稍等…":self.lastPCReply;
    if(!reply.length&&[summary[@"balanceText"] length])reply=summary[@"balanceText"];
    self.controlView.state=@{@"current":current,@"detail":detail?:@"正在准备",@"autonomous":@(self.scene.autonomousEnabled),@"enabled":@(self.enabled),@"controlsVisible":@(self.systemControlsVisible),@"backend":self.backend.connectionStatus?:@"本地陪伴",@"connected":@(self.backend.connected),@"busy":@(self.backend.actionBusy),@"pcEnabled":@(self.scene.pc2005Enabled),@"pcAction":self.scene.pcActionTitle?:@"",@"actions":[PCPetAnimation catalogue],@"reply":reply?:@"手动聊天会使用 DSH 当前模型额度；自动聊天已关闭。"};
}
- (void)showControlPanel {
    [self updateFront];
    if(!self.controlPopover.shown && self.statusItem.button.window) {
        [self.controlPopover showRelativeToRect:self.statusItem.button.bounds ofView:self.statusItem.button preferredEdge:NSMinYEdge];
        [self.controlView.window makeKeyWindow];
    }
    [self logEvent:@"control-panel-opened" bundle:self.lastFront];
}
- (void)toggleControlPanel:(id)sender {
    if(self.controlPopover.shown)[self.controlPopover performClose:nil];else[self showControlPanel];
}
- (void)updatePCTranscript {
    if(self.pcTranscriptView){self.pcTranscriptView.string=self.pcTranscript.length?self.pcTranscript:@"对话会显示在这里。聊天与碎碎念使用 DSH 模型额度，仅在你主动点击时调用。";[self.pcTranscriptView scrollRangeToVisible:NSMakeRange(self.pcTranscriptView.string.length,0)];}
}
- (void)showPCTranscript {
    if(!self.pcTranscriptWindow){
        self.pcTranscriptWindow=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,520,400) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
        self.pcTranscriptWindow.title=@"和鲸鱼娘聊天 · PC2005";self.pcTranscriptWindow.releasedWhenClosed=NO;
        NSScrollView *scroll=[[NSScrollView alloc]initWithFrame:NSMakeRect(0,0,520,400)];scroll.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;scroll.hasVerticalScroller=YES;
        self.pcTranscriptView=[[NSTextView alloc]initWithFrame:NSMakeRect(0,0,500,400)];self.pcTranscriptView.editable=NO;self.pcTranscriptView.selectable=YES;self.pcTranscriptView.font=[NSFont systemFontOfSize:14];self.pcTranscriptView.textColor=NSColor.labelColor;self.pcTranscriptView.backgroundColor=NSColor.textBackgroundColor;self.pcTranscriptView.textContainerInset=NSMakeSize(18,18);self.pcTranscriptView.autoresizingMask=NSViewWidthSizable;self.pcTranscriptView.verticallyResizable=YES;self.pcTranscriptView.textContainer.widthTracksTextView=YES;
        scroll.documentView=self.pcTranscriptView;self.pcTranscriptWindow.contentView=scroll;[self.pcTranscriptWindow center];
    }
    [self updatePCTranscript];[self.pcTranscriptWindow makeKeyAndOrderFront:nil];[NSApp activateIgnoringOtherApps:YES];
}
- (void)controlAction:(NSString *)action {
    if([action hasPrefix:@"pc-action-"]){NSString *clip=[action substringFromIndex:10];[self returnToPets:nil];[self.scene playPCAction:clip];if(self.previewScene)[self.previewScene playPCAction:clip];[self updateControlPanel];[self logEvent:@"pc-animation-selected" bundle:self.lastFront];return;}
    if([action isEqualToString:@"pc-library"]){[self updateControlPanel];return;}
    if([action isEqualToString:@"pc-transcript"]){[self.controlPopover performClose:nil];[self showPCTranscript];return;}
    if([action isEqualToString:@"pc-toggle"]){self.scene.pc2005Enabled=!self.scene.pc2005Enabled;self.previewScene.pc2005Enabled=self.scene.pc2005Enabled;[NSUserDefaults.standardUserDefaults setBool:self.scene.pc2005Enabled forKey:@"PC2005.Enabled"];[self updateControlPanel];return;}
    if([action isEqualToString:@"pc-whisper"]||[action isEqualToString:@"pc-balance"]||[action isEqualToString:@"pc-chat-send"]){
        BOOL sent=NO;
        if([action isEqualToString:@"pc-whisper"])sent=[self.backend requestWhisper];
        else if([action isEqualToString:@"pc-balance"]){self.lastPCReply=nil;sent=[self.backend refreshBalance];}
        else {NSString *text=[self.controlView.chatText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];if(text.length){sent=[self.backend sendChat:text];if(sent){[self.pcTranscript appendFormat:@"你：%@\n\n",text];[self.controlView clearChatText];[self updatePCTranscript];}}}
        if(sent&&![action isEqualToString:@"pc-balance"])self.lastPCReply=nil;
        [self updateControlPanel];return;
    }

    if([action isEqualToString:@"close"]){[self.controlPopover performClose:nil];return;}
    if([action isEqualToString:@"quit"]){[self.controlPopover performClose:nil];[self quit:nil];return;}
    if([action isEqualToString:@"preview"]){[self.controlPopover performClose:nil];[self showPreview:nil];return;}
    if([action isEqualToString:@"backup"]){[self.controlPopover performClose:nil];[self showBackup:nil];return;}
    if([action isEqualToString:@"connect"]){[self.controlPopover performClose:nil];[self configureBackend:nil];return;}
    if([action isEqualToString:@"toggle-autonomy"])[self toggleAutonomy:nil];
    else if([action isEqualToString:@"toggle-pause"])[self toggle:nil];
    else if([action isEqualToString:@"system-controls"])[self toggleSystemControls:nil];
    else if([@[@"duo-block",@"duo-dash",@"duo-reunion",@"feed",@"play",@"pet",@"dance",@"run",@"cuddle",@"nap",@"status"] containsObject:action]) {
        [self returnToPets:nil];[self.scene performAction:action];
        if([action isEqualToString:@"status"]){self.panelFeedback=self.scene.needsSummary;self.panelFeedbackUntil=NSDate.date.timeIntervalSince1970+5;}
    }
    [self updateFront];[self logEvent:@"control-panel-action" bundle:self.lastFront];
}
- (void)menuWillOpen:(NSMenu *)menu { [self updateFront]; }
- (void)playDuoStory:(NSMenuItem *)sender {
    [self returnToPets:nil];
    [self.scene performAction:sender.representedObject];
    [self updateFront];[self logEvent:@"menu-story-selected" bundle:self.lastFront];
}
- (void)companionAction:(NSMenuItem *)sender { [[self interactionScene] performAction:sender.representedObject]; }
- (void)feed:(id)sender { [[self interactionScene] performAction:@"feed"]; }
- (void)play:(id)sender { [[self interactionScene] performAction:@"play"]; }
- (void)remoteAction:(NSNotification *)note {
    NSString *action = note.userInfo[@"action"];
    if([action isEqualToString:@"pc-action"]){NSString *clip=note.userInfo[@"clip"];if([clip isKindOfClass:NSString.class])[self controlAction:[@"pc-action-" stringByAppendingString:clip]];return;}
    if([action isEqualToString:@"pc-library"]){[self showControlPanel];[self.controlView showActionLibrary:YES];return;}
    if([@[@"pc-toggle",@"pc-whisper",@"pc-balance"] containsObject:action]){[self controlAction:action];return;}
    if ([action isEqualToString:@"system-controls"]) { [self showSystemControls:nil]; return; }
    if ([action isEqualToString:@"pets"]) { if(self.controlsReturnButton) [self.controlsReturnButton performClick:nil]; else if(self.returnButton) [self.returnButton performClick:nil]; else [self returnToPets:nil]; return; }
    if ([action isEqualToString:@"snapshot"]) { [self updateFront];[self logEvent:@"snapshot" bundle:self.lastFront]; return; }
    if([@[@"duo-block",@"duo-dash",@"duo-reunion"] containsObject:action]) { [self.controlView activateAction:action];return; }
    if([action isEqualToString:@"panel"]){[self showControlPanel];return;}
    if([action isEqualToString:@"close-panel"]){[self.controlPopover performClose:nil];return;}
    if([action isEqualToString:@"panel-snapshot"]){
        [self showControlPanel];[self updateControlPanel];
        NSString *path=note.userInfo[@"path"];
        if(path.length)[self.controlView renderPNGAtPath:path scale:2];
        [self logEvent:@"control-panel-rendered" bundle:self.lastFront];return;
    }
    if ([action isEqualToString:@"preview"]) { [self showPreview:nil]; return; }
    if ([action isEqualToString:@"close-preview"]) { [self.previewWindow close]; return; }
    if ([action isEqualToString:@"feed"]) [self feed:nil];
    else if ([action isEqualToString:@"play"]) [self play:nil];
    else if ([@[@"toggle-menu",@"wake",@"pet",@"dance",@"run",@"cuddle",@"nap",@"status"] containsObject:action]) [[self interactionScene] performAction:action];
}
- (void)showSystemControls:(id)sender {
    self.systemControlsVisible=YES;self.suppressed=NO;
    [self dismiss];[self updateFront];[self logEvent:@"system-controls-shown" bundle:self.lastFront];
}
- (void)returnToPets:(id)sender {
    self.systemControlsVisible=NO;self.suppressed=NO;self.enabled=YES;
    [self dismissControlsBar];[self updateFront];[self logEvent:@"returned-to-pets" bundle:self.lastFront];
}
- (void)toggleSystemControls:(id)sender {
    if(self.systemControlsVisible) [self returnToPets:sender];else [self showSystemControls:sender];
}
- (void)pause:(id)sender { self.enabled=NO;[self updateFront];[self logEvent:@"paused" bundle:self.lastFront]; }
- (void)resume:(id)sender { [self returnToPets:sender]; }
- (void)toggle:(id)sender { self.enabled=!self.enabled;self.suppressed=NO;if(self.enabled)self.systemControlsVisible=NO;[self updateFront];[self logEvent:@"toggled" bundle:self.lastFront]; }
- (NSString *)suspensionReason:(NSString *)name {
    if ([name isEqualToString:@"com.apple.screenIsLocked"] || [name isEqualToString:@"com.apple.screenIsUnlocked"]) return @"locked";
    if ([name isEqualToString:NSWorkspaceSessionDidResignActiveNotification] || [name isEqualToString:NSWorkspaceSessionDidBecomeActiveNotification]) return @"session";
    if ([name isEqualToString:NSWorkspaceScreensDidSleepNotification] || [name isEqualToString:NSWorkspaceScreensDidWakeNotification]) return @"screen";
    return @"system";
}
- (void)sleep:(NSNotification *)note {
    [self.suspendReasons addObject:[self suspensionReason:note.name]];
    self.suspended = self.suspendReasons.count > 0;
    self.previewScene.animating = NO;
    [self dismiss];[self dismissControlsBar]; [self logEvent:@"suspended" bundle:self.lastFront]; [self updateFront];
}
- (void)wake:(NSNotification *)note {
    [self.suspendReasons removeObject:[self suspensionReason:note.name]];
    self.suspended = self.suspendReasons.count > 0;
    self.previewScene.animating = self.previewWindow.visible && !self.suspended;
    [self updateFront];
}
- (void)showBackup:(id)sender {
    NSURL *help=[NSBundle.mainBundle URLForResource:@"HELP" withExtension:@"md"];
    if(help){NSTask *opener=[NSTask new];opener.executableURL=[NSURL fileURLWithPath:@"/usr/bin/open"];opener.arguments=@[help.path];[opener launchAndReturnError:nil];}
}

- (void)showPreview:(id)sender {
    if (!self.previewWindow) {
        self.previewWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 720, 150) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
        self.previewWindow.title = @"鲸鱼娘与三花猫 · 双宠小剧情";
        self.previewWindow.releasedWhenClosed = NO;
        self.previewWindow.delegate = self;
        NSView *content = self.previewWindow.contentView;
        NSTextField *title = [NSTextField labelWithString:@"挡路、追赶、回头等一等，再一起歇会儿。"];
        title.font = [NSFont systemFontOfSize:17 weight:NSFontWeightMedium];
        title.frame = NSMakeRect(28, 105, 640, 26); [content addSubview:title];
        self.previewScene = [[WhaleScene alloc] initWithFrame:NSMakeRect(0,0,628,30)];
        PetBarContainer *previewContainer=[[PetBarContainer alloc] initWithFrame:NSMakeRect(28,58,664,30) scene:self.previewScene];
        __weak WhaleApp *previewOwner=self;previewContainer.systemControlsHandler=^{[previewOwner showSystemControls:nil];};
        [content addSubview:previewContainer];
        self.previewScene.autonomousEnabled = self.scene.autonomousEnabled;
        self.previewScene.pc2005Enabled=self.scene.pc2005Enabled;
        __weak WhaleApp *weak = self;
        self.previewScene.interactionHandler = ^(NSString *action) { [weak.backend interact:action]; };
        NSTextField *caption = [NSTextField labelWithString:@"所有应用陪伴 · 圆圈打开系统控件 · 点「返回桌宠」回来。"];
        caption.textColor = NSColor.secondaryLabelColor; caption.font = [NSFont systemFontOfSize:12];
        caption.frame = NSMakeRect(28, 19, 664, 22); [content addSubview:caption];
        [self.previewWindow center];
    }
    self.previewScene.animating = !self.suspended;
    [self.previewWindow makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}
- (void)windowWillClose:(NSNotification *)notification { if(notification.object==self.previewWindow)self.previewScene.animating = NO; }
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return NO; }
- (void)quit:(id)sender { [self dismiss];[self dismissControlsBar]; [NSApp terminate:nil]; }
- (void)applicationWillTerminate:(NSNotification *)notification {
    [self.controlPopover performClose:nil];
    [self.monitor invalidate];[self dismiss];[self dismissControlsBar];self.previewScene.animating=NO;
    if(self.returnStatusItem) { [NSStatusBar.systemStatusBar removeStatusItem:self.returnStatusItem];self.returnStatusItem=nil; }
    [self unregisterReturnCircle];
    [self.petBar removeObserver:self forKeyPath:@"visible"];
    [self logEvent:@"terminated" bundle:NSWorkspace.sharedWorkspace.frontmostApplication.bundleIdentifier];
    [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
    [NSDistributedNotificationCenter.defaultCenter removeObserver:self];
    [NSStatusBar.systemStatusBar removeStatusItem:self.statusItem];
}
@end

static int RenderPreview(NSString *path, NSString *state, double time, BOOL menu, NSString *action, NSString *story, NSString *duo) {
    WhaleScene *scene = [[WhaleScene alloc] initWithFrame:NSMakeRect(0,0,964,30)];
    PetBarContainer *container=[[PetBarContainer alloc] initWithFrame:NSMakeRect(0,0,1000,30) scene:scene];
    scene.pc2005Enabled=YES;
    scene.fixedTime = time;
    scene.forcedState = state ?: @"idle";
    if (menu) [scene performAction:@"toggle-menu"];
    if (action.length) { scene.forcedState = nil;if([action hasPrefix:@"pc-action-"])[scene playPCAction:[action substringFromIndex:10]];else if([action hasPrefix:@"sidewalk-"])[scene prepareSideWalkPreviewFacing:[action isEqualToString:@"sidewalk-right"]?1:-1 elapsed:time];else[scene performAction:action]; }
    if (story.length) [scene prepareStoryPreview:story elapsed:time];
    if (duo.length) [scene prepareDuoStoryPreview:duo elapsed:time];
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:2000 pixelsHigh:60 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    [NSGraphicsContext saveGraphicsState]; NSGraphicsContext.currentContext=context;
    CGContextScaleCTM(context.CGContext,2,2); [container drawPreviewInCurrentContext];
    [NSGraphicsContext restoreGraphicsState];
    BOOL ok = [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
    return ok ? 0 : 1;
}
static int RenderControlPanel(NSString *path,BOOL dark) {
    CompanionPanelView *view=[[CompanionPanelView alloc] initWithFrame:NSMakeRect(0,0,CompanionPanelView.preferredSize.width,CompanionPanelView.preferredSize.height)];
    view.appearance=[NSAppearance appearanceNamed:dark?NSAppearanceNameDarkAqua:NSAppearanceNameAqua];
    view.state=@{@"current":@"PC2005 原版动作",@"detail":@"鲸鱼娘和小猫正在自由活动",@"autonomous":@YES,@"enabled":@YES,@"controlsVisible":@NO,@"backend":@"PC2005 dsh-pet · 手动聊天使用模型额度",@"pcEnabled":@YES,@"connected":@YES,@"actions":[PCPetAnimation catalogue],@"pcAction":@"吃火锅"};
    return [view renderPNGAtPath:path scale:2]?0:1;
}
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSArray<NSString *> *args = NSProcessInfo.processInfo.arguments;
        if ([args containsObject:@"--behavior-tests"]) {
            NSDictionary *scene = [WhaleScene runBehaviorTests];
            NSDictionary *backend = [WhaleBackend runParsingTests];
            NSDictionary *autonomy = [WhaleScene runAutonomyTests];
            NSDictionary *water = [WhaleScene runWaterWorldTests];
            NSDictionary *idlePair = [WhaleScene runIdlePairTests];
            NSDictionary *stories = [WhaleScene runStoryTests];
            NSDictionary *cat = [WhaleScene runCatFollowTests];
            NSDictionary *catRoaming=[WhaleScene runCatRoamingTests];
            NSDictionary *duo=[WhaleScene runDuoStoryTests];
            NSDictionary *panel=[CompanionPanelView runInteractionTests];
            NSDictionary *pcAssets=[PCPetAnimation runAssetTests],*pcIntegration=[WhaleScene runPCIntegrationTests];
            NSDictionary *catAssets = [CatCompanion runAssetTests];
            NSDictionary *layout=[PetBarContainer runLayoutTests];
            NSDictionary *presentation=PresentationPolicyTests();
            SendJSON(@{@"scene":scene,@"backend":backend,@"autonomy":autonomy,@"water":water,@"idlePair":idlePair,@"stories":stories,@"cat":cat,@"catAssets":catAssets,@"layout":layout,@"presentation":presentation,@"catRoaming":catRoaming,@"duo":duo,@"panel":panel,@"pcAssets":pcAssets,@"pcIntegration":pcIntegration});
            return [scene[@"passed"] boolValue] && [backend[@"passed"] boolValue] && [autonomy[@"passed"] boolValue] && [water[@"passed"] boolValue] && [idlePair[@"passed"] boolValue] && [stories[@"passed"] boolValue] && [cat[@"passed"] boolValue] && [catAssets[@"passed"] boolValue] && [layout[@"passed"] boolValue] && [presentation[@"passed"] boolValue] && [catRoaming[@"passed"] boolValue] && [duo[@"passed"] boolValue] && [panel[@"passed"] boolValue] && [pcAssets[@"passed"] boolValue] && [pcIntegration[@"passed"] boolValue] ? 0 : 1;
        }
        if ([args containsObject:@"--self-test"]) {
            NSDictionary *policy=PresentationPolicyTests();BOOL ok=[policy[@"passed"] boolValue];
            SendJSON(@{@"policyTestsPassed":@(ok),@"runtimeSupportsTouchBar":@(SupportsPresentation()),@"runtimeSupportsReturnCircle":@(SupportsReturnTray()),@"displayScope":@"all-apps",@"writesSystemOrDSHFiles":@NO,@"catAssetLoaded":@([CatCompanion isAvailable]),@"catAssetSummary":[CatCompanion assetSummary]});
            return ok && SupportsPresentation() && SupportsReturnTray() && [CatCompanion isAvailable] ? 0 : 1;
        }
        NSUInteger panelRender=[args indexOfObject:@"--render-control-panel"];
        if(panelRender!=NSNotFound&&panelRender+1<args.count)return RenderControlPanel(args[panelRender+1],[args containsObject:@"--dark"]);
        NSUInteger pcAction=[args indexOfObject:@"--pc-action"];
        if(pcAction!=NSNotFound&&pcAction+1<args.count){[NSDistributedNotificationCenter.defaultCenter postNotificationName:ActionNotification object:nil userInfo:@{@"action":@"pc-action",@"clip":args[pcAction+1]} deliverImmediately:YES];return 0;}
        NSUInteger panelSnapshot=[args indexOfObject:@"--panel-snapshot"];
        if(panelSnapshot!=NSNotFound&&panelSnapshot+1<args.count){
            [NSDistributedNotificationCenter.defaultCenter postNotificationName:ActionNotification object:nil userInfo:@{@"action":@"panel-snapshot",@"path":args[panelSnapshot+1]} deliverImmediately:YES];return 0;
        }
        NSUInteger render = [args indexOfObject:@"--render-preview"];
        if (render!=NSNotFound && render+1<args.count) {
            NSUInteger state = [args indexOfObject:@"--state"];
            NSUInteger time = [args indexOfObject:@"--time"];
            NSUInteger action = [args indexOfObject:@"--action"];
            NSUInteger story = [args indexOfObject:@"--story"];
            NSUInteger duo = [args indexOfObject:@"--duo-story"];
            return RenderPreview(args[render+1], state!=NSNotFound && state+1<args.count ? args[state+1] : @"idle", time!=NSNotFound && time+1<args.count ? [args[time+1] doubleValue] : 1.1, [args containsObject:@"--menu-preview"], action!=NSNotFound && action+1<args.count ? args[action+1] : nil, story!=NSNotFound && story+1<args.count ? args[story+1] : nil, duo!=NSNotFound && duo+1<args.count ? args[duo+1] : nil);
        }
        NSDictionary *actionCommands = @{@"--pc-library":@"pc-library",@"--pc-toggle":@"pc-toggle",@"--pc-whisper":@"pc-whisper",@"--pc-balance":@"pc-balance",@"--panel":@"panel",@"--close-panel":@"close-panel",@"--duo-block":@"duo-block",@"--duo-dash":@"duo-dash",@"--duo-reunion":@"duo-reunion",@"--system-controls":@"system-controls",@"--pets":@"pets",@"--snapshot":@"snapshot",@"--feed":@"feed",@"--play":@"play",@"--menu":@"toggle-menu",@"--wake":@"wake",@"--preview":@"preview",@"--close-preview":@"close-preview",@"--pet":@"pet",@"--dance":@"dance",@"--run":@"run",@"--cuddle":@"cuddle",@"--nap":@"nap",@"--status":@"status"};
        for (NSString *arg in actionCommands) {
            if ([args containsObject:arg]) {
                [NSDistributedNotificationCenter.defaultCenter postNotificationName:ActionNotification object:nil userInfo:@{@"action":actionCommands[arg]} deliverImmediately:YES]; return 0;
            }
        }
        NSDictionary *commands = @{@"--pause":PauseNotification,@"--resume":ResumeNotification,@"--quit":QuitNotification};
        for (NSString *arg in commands) {
            if ([args containsObject:arg]) {
                [NSDistributedNotificationCenter.defaultCenter postNotificationName:commands[arg] object:nil userInfo:nil deliverImmediately:YES];
                return 0;
            }
        }
        WhaleApp *delegate = [WhaleApp new];
        NSApp.delegate = delegate;
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [NSApp run];
    }
    return 0;
}
