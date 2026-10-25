#import "WhaleBackend.h"
#import <math.h>

static NSString *const PCPrefix = @"/dsh-pet-7340";
static NSString *const PCOffline = @"本地陪伴 · 未连接 PC2005 dsh-pet";
static NSString *const PCConnected = @"已连接 PC2005 dsh-pet · 实时任务同步";
static NSDictionary *PCDict(id value) { return [value isKindOfClass:NSDictionary.class]?value:@{}; }
static NSString *PCText(id value, NSUInteger limit) {
    if (![value isKindOfClass:NSString.class]) return @"";
    NSString *text=[value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if(text.length>limit)text=[text substringToIndex:[text rangeOfComposedCharacterSequencesForRange:NSMakeRange(0,limit)].length];
    return text;
}
static BOOL PCBool(id value) { return [value isKindOfClass:NSNumber.class]&&[value boolValue]; }
static BOOL PCNumber(id value) { return [value isKindOfClass:NSNumber.class]&&isfinite([value doubleValue])&&[value doubleValue]>=0; }
static BOOL IsLoopbackOrigin(NSURL *url) {
    if (![url isKindOfClass:NSURL.class]) return NO;
    NSURLComponents *parts=[NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    NSString *host=parts.host.lowercaseString;
    BOOL local=[host isEqualToString:@"127.0.0.1"]||[host isEqualToString:@"localhost"]||[host isEqualToString:@"::1"]||[host isEqualToString:@"[::1]"];
    BOOL path=!parts.path.length||[parts.path isEqualToString:@"/"];
    BOOL port=!parts.port||(parts.port.integerValue>0&&parts.port.integerValue<=65535);
    return [parts.scheme.lowercaseString isEqualToString:@"http"]&&local&&path&&port&&!parts.user.length&&!parts.password.length&&!parts.query.length&&!parts.fragment.length;
}
static NSURL *PCDefaultURL(NSString *path) {
    NSDictionary *attributes=[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    if([attributes fileSize]>0&&[attributes fileSize]<=16384){
        NSData *data=[NSData dataWithContentsOfFile:path];
        NSDictionary *runtime=PCDict(data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil);
        NSString *origin=PCText(runtime[@"baseURL"],200);NSURL *url=origin.length?[NSURL URLWithString:origin]:nil;
        if(IsLoopbackOrigin(url))return url;
    }
    return nil;
}
static BOOL PCLeaf(id value) {
    if(![value isKindOfClass:NSDictionary.class])return NO;
    return PCNumber(value[@"counter"])&&(value[@"data"]==NSNull.null||[value[@"data"] isKindOfClass:NSDictionary.class]);
}
static BOOL IsSnapshot(id value) {
    if(![value isKindOfClass:NSDictionary.class]||!PCNumber(value[@"counter"])||![value[@"sections"] isKindOfClass:NSDictionary.class]||![value[@"pets"] isKindOfClass:NSDictionary.class])return NO;
    NSDictionary *sections=value[@"sections"];
    for(NSString *key in @[@"workStatus",@"balance",@"notify",@"config"])if(!PCLeaf(sections[key]))return NO;
    NSDictionary *work=PCDict(sections[@"workStatus"][@"data"]);
    id state=work[@"state"];
    if(state&&state!=NSNull.null&&(![state isKindOfClass:NSString.class]||![@[@"thinking",@"working",@"result",@"waiting",@"success",@"error"] containsObject:state]))return NO;
    NSDictionary *pets=value[@"pets"];
    for(id key in pets){
        if(![key isKindOfClass:NSString.class]||![pets[key] isKindOfClass:NSDictionary.class])return NO;
        for(NSString *leaf in @[@"say",@"anim",@"position",@"throw",@"lock"])if(!PCLeaf(pets[key][leaf]))return NO;
    }
    return YES;
}
static NSString *PCBalanceText(NSDictionary *balance) {
    if(!balance.count)return @"余额：尚未查询";
    if(!PCBool(balance[@"ok"])){
        NSDictionary *reasons=@{@"unsupported":@"当前服务商不支持查余额",@"credential-missing":@"请先在 DSH 配置服务商",@"fetch-error":@"余额查询失败"};
        return [@"余额：" stringByAppendingString:reasons[PCText(balance[@"reason"],80)]?:@"暂不可用"];
    }
    NSDictionary *data=PCDict(balance[@"data"]);if(!data.count)data=balance;
    NSString *shape=PCText(balance[@"shape"],20);
    if([shape isEqualToString:@"money"]){
        NSMutableArray *wallets=[NSMutableArray new];
        if([data[@"wallets"] isKindOfClass:NSArray.class])for(id item in data[@"wallets"]){
            NSDictionary *wallet=PCDict(item);NSString *currency=PCText(wallet[@"currency"],12),*total=PCText(wallet[@"total"],30);
            if(currency.length&&total.length)[wallets addObject:[NSString stringWithFormat:@"%@ %@",currency,total]];
            if(wallets.count>=4)break;
        }
        return wallets.count?[@"余额：" stringByAppendingString:[wallets componentsJoinedByString:@" · "]]:@"余额：未返回金额";
    }
    if([shape isEqualToString:@"points"]){
        NSDictionary *points=PCDict(data[@"points"]);NSString *total=PCText(points[@"total"],30),*unit=PCText(points[@"unit"],20);
        return total.length?[NSString stringWithFormat:@"余额：%@ %@",total,unit]:@"余额：未返回点数";
    }
    if([shape isEqualToString:@"windows"]){
        NSMutableArray *windows=[NSMutableArray new];
        for(NSArray *entry in @[@[@"rolling",@"5小时"],@[@"weekly",@"周"],@[@"monthly",@"月"]]){
            id used=data[entry[0]];
            if(PCNumber(used)&&[used doubleValue]<=100)[windows addObject:[NSString stringWithFormat:@"%@已用 %.0f%%",entry[1],[used doubleValue]]];
        }
        return windows.count?[@"额度：" stringByAppendingString:[windows componentsJoinedByString:@" · "]]:@"额度：未返回窗口用量";
    }
    return @"余额：已更新";
}
static NSString *PCNotifyText(NSDictionary *frame) {
    NSString *type=PCText(frame[@"type"],80);
    if([type isEqualToString:@"approval/requested"])return @"DSH 正等待你确认权限";
    if([type isEqualToString:@"question/requested"])return @"DSH 正等待你的选择";
    if([type isEqualToString:@"host/agent-error"])return @"DSH 任务发生错误";
    NSDictionary *event=PCDict(frame[@"event"]);
    NSString *reason=PCText(PCDict(PCDict(event[@"data"])[@"reason"])[@"kind"],50);
    if([reason isEqualToString:@"completed"])return @"DSH 任务已完成";
    if([reason isEqualToString:@"error"])return @"DSH 任务发生错误";
    if([reason isEqualToString:@"max-tokens"])return @"DSH 输出达到长度限制";
    return @"";
}
static NSString *PCFailureText(NSDictionary *result) {
    NSDictionary *reasons=@{@"provider-missing":@"请先在 DSH 选择可用模型",@"generate-error":@"DSH 生成失败，请稍后重试",@"pet-required":@"未指定宠物",@"unknown-pet":@"DSH 中没有 main 这只宠物",@"bad-request":@"请求参数未被插件接受",@"pet-not-displayed":@"请在 DSH 启用宠物显示后再聊天",@"standalone-unsupported":@"该能力需要 DSH 宿主"};
    return reasons[PCText(result[@"reason"],80)]?:@"插件没有完成本次请求";
}

@interface WhaleBackend () <NSURLSessionTaskDelegate>
@property(nonatomic, readwrite) BOOL connected;
@property(nonatomic, readwrite) BOOL running;
@property(nonatomic, readwrite) BOOL actionBusy;
@property(nonatomic, readwrite, strong, nullable) NSURL *baseURL;
@property(nonatomic, readwrite, copy) NSDictionary *petSummary;
@property(nonatomic, readwrite, copy) NSString *connectionStatus;
@property(nonatomic) NSUInteger generation;
@property(nonatomic) BOOL discoversRuntime;
@property(nonatomic, copy) NSNumber *lastWorkCounter;
@property(nonatomic) double lastWorkUntil;
@property(nonatomic) NSUInteger consecutiveFailures;
@property(nonatomic, strong) NSURLSession *session;
@property(nonatomic, strong) NSURLSessionDataTask *pollTask;
@property(nonatomic, strong) NSURLSessionDataTask *actionTask;
@property(nonatomic, strong) NSTimer *pollTimer;
@property(nonatomic, strong) NSDictionary *lastSnapshot;
@property(nonatomic, copy) NSNumber *lastSayCounter;
@property(nonatomic, copy) NSString *lastDeliveredReply;
@end

@implementation WhaleBackend
- (NSString *)runtimeInfoPath { return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/WhaleGirlTouchBar/pc2005-runtime.json"]; }
- (instancetype)init {
    NSURL *runtime=PCDefaultURL([self runtimeInfoPath]);
    self=[self initWithBaseURL:runtime?:[NSURL URLWithString:@"http://localhost"]];
    if(self){self.discoversRuntime=YES;self.baseURL=runtime;}return self;
}
- (instancetype)initWithBaseURL:(NSURL *)baseURL {
    if(!IsLoopbackOrigin(baseURL))return nil;
    if((self=[super init])){
        NSURLComponents *parts=[NSURLComponents componentsWithURL:baseURL resolvingAgainstBaseURL:NO];parts.path=@"";_baseURL=parts.URL;
        _connectionStatus=PCOffline;
        _petSummary=@{@"source":@"PC2005/dsh-pet",@"taskState":@"idle",@"taskLabel":@"本地陪伴",@"balanceText":@"余额：尚未查询",@"notificationText":@"",@"lastReply":@""};
    }
    return self;
}
- (void)publishStatus:(NSString *)status {
    if([self.connectionStatus isEqualToString:status])return;
    self.connectionStatus=status;
    if(self.statusHandler)self.statusHandler(status);
}
- (void)start {
    NSAssert(NSThread.isMainThread,@"WhaleBackend is owned by the main thread");
    if(self.running)return;
    self.running=YES;self.generation++;self.consecutiveFailures=0;
    NSURLSessionConfiguration *config=NSURLSessionConfiguration.ephemeralSessionConfiguration;
    config.timeoutIntervalForRequest=3;config.timeoutIntervalForResource=70;
    config.requestCachePolicy=NSURLRequestReloadIgnoringLocalCacheData;config.URLCache=nil;
    config.HTTPCookieStorage=nil;config.HTTPCookieAcceptPolicy=NSHTTPCookieAcceptPolicyNever;config.HTTPShouldSetCookies=NO;
    config.URLCredentialStorage=nil;config.HTTPMaximumConnectionsPerHost=2;config.HTTPAdditionalHeaders=@{@"Accept":@"application/json"};
    self.session=[NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:NSOperationQueue.mainQueue];
    [self publishStatus:@"正在连接 PC2005 dsh-pet…"];[self poll];
}
- (void)stop {
    NSAssert(NSThread.isMainThread,@"WhaleBackend is owned by the main thread");
    if(!self.running&&!self.session)return;
    self.running=NO;self.connected=NO;self.actionBusy=NO;self.generation++;
    [self.pollTimer invalidate];self.pollTimer=nil;
    [self.pollTask cancel];self.pollTask=nil;[self.actionTask cancel];self.actionTask=nil;
    [self.session invalidateAndCancel];self.session=nil;
    [self publishStatus:@"后台连接已暂停"];
}
- (NSMutableURLRequest *)requestForPath:(NSString *)path method:(NSString *)method timeout:(NSTimeInterval)timeout {
    NSURL *url=[NSURL URLWithString:[PCPrefix stringByAppendingString:path] relativeToURL:self.baseURL].absoluteURL;
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:timeout];
    request.HTTPMethod=method;request.HTTPShouldHandleCookies=NO;
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"no-store" forHTTPHeaderField:@"Cache-Control"];
    return request;
}
- (void)schedulePollAfter:(NSTimeInterval)delay {
    [self.pollTimer invalidate];self.pollTimer=nil;
    if(!self.running)return;
    __weak WhaleBackend *owner=self;
    self.pollTimer=[NSTimer timerWithTimeInterval:delay repeats:NO block:^(NSTimer *timer){[owner poll];}];
    self.pollTimer.tolerance=.15;[NSRunLoop.mainRunLoop addTimer:self.pollTimer forMode:NSRunLoopCommonModes];
}
- (NSDictionary *)normalizeSnapshot:(NSDictionary *)raw now:(NSTimeInterval)now {
    NSDictionary *sections=raw[@"sections"],*work=PCDict(PCDict(sections[@"workStatus"])[@"data"]);
    NSString *state=PCText(work[@"state"],30);if(!state.length)state=@"idle";
    double workCounter=[sections[@"workStatus"][@"counter"] doubleValue];
    if(![self.lastWorkCounter isEqual:sections[@"workStatus"][@"counter"]]){
        self.lastWorkCounter=sections[@"workStatus"][@"counter"];
        self.lastWorkUntil=MIN(workCounter+4000,now*1000+4000);
    }
    double until=self.lastWorkUntil;
    BOOL thinking=[@[@"thinking",@"working",@"result"] containsObject:state],waiting=[state isEqualToString:@"waiting"];
    NSString *name=@"idle";
    if(thinking)name=[state isEqualToString:@"thinking"]?@"think":@"working";
    else if(waiting)name=@"wait";
    else if([state isEqualToString:@"success"]&&until>now*1000)name=@"celebrate";
    else if([state isEqualToString:@"error"]&&until>now*1000)name=@"error";
    NSDictionary *activity=@{@"name":name,@"sessionThink":@(thinking),@"sessionWait":@(waiting),@"turnCompletedUntil":@([state isEqualToString:@"success"]?until:0),@"until":@(([@[@"success",@"error"] containsObject:state])?until:0)};
    NSDictionary *main=PCDict(raw[@"pets"][@"main"]),*say=PCDict(PCDict(main[@"say"])[@"data"]),*anim=PCDict(PCDict(main[@"anim"])[@"data"]);
    NSString *reply=PCText(say[@"text"],4000);
    NSDictionary *labels=@{@"idle":@"自由活动",@"thinking":@"DSH 正在思考",@"working":@"DSH 正在执行工具",@"result":@"DSH 正在整理结果",@"waiting":@"DSH 等待你确认",@"success":@"DSH 任务完成",@"error":@"DSH 任务出错"};
    NSMutableDictionary *summary=[self.petSummary mutableCopy];
    summary[@"source"]=@"PC2005/dsh-pet";summary[@"taskState"]=state;
    summary[@"taskLabel"]=labels[state]?:@"自由活动";summary[@"taskDetail"]=PCText(work[@"task"],300);
    summary[@"balanceText"]=PCBalanceText(PCDict(PCDict(sections[@"balance"])[@"data"]));
    summary[@"notificationText"]=PCNotifyText(PCDict(PCDict(sections[@"notify"])[@"data"]));
    summary[@"stateCounter"]=raw[@"counter"];
    if(reply.length)summary[@"lastReply"]=reply;
    self.petSummary=summary;
    return @{@"apiVersion":@1,@"pet":@{},@"activity":activity,@"pcTaskState":state,@"pcTaskCounter":sections[@"workStatus"][@"counter"],@"pcAnimation":PCText(anim[@"name"],160),@"pcSay":reply,@"pcSummary":summary};
}
- (void)poll {
    if(!self.running||self.pollTask)return;
    if(self.discoversRuntime){NSURL *origin=PCDefaultURL([self runtimeInfoPath]);if(![origin isEqual:self.baseURL])self.baseURL=origin;}
    if(!self.baseURL){
        self.connected=NO;
        [self publishStatus:@"本地陪伴 · 未检测到 DSH 适配，请查看使用帮助"];
        [self schedulePollAfter:3];return;
    }
    NSUInteger generation=self.generation;__weak WhaleBackend *owner=self;
    self.pollTask=[self.session dataTaskWithRequest:[self requestForPath:@"/state" method:@"GET" timeout:3] completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
        dispatch_async(dispatch_get_main_queue(),^{
            WhaleBackend *strong=owner;if(!strong||!strong.running||strong.generation!=generation)return;
            strong.pollTask=nil;
            NSHTTPURLResponse *http=[response isKindOfClass:NSHTTPURLResponse.class]?(id)response:nil;
            id raw=nil;if(!error&&http.statusCode==200&&data.length>0&&data.length<=1024*1024)raw=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if(IsSnapshot(raw)){
                strong.connected=YES;strong.consecutiveFailures=0;
                NSDictionary *snapshot=[strong normalizeSnapshot:raw now:NSDate.date.timeIntervalSince1970];strong.lastSnapshot=snapshot;
                [strong publishStatus:strong.actionBusy?@"PC2005 正在处理请求…":PCConnected];
                if(strong.snapshotHandler)strong.snapshotHandler(snapshot);
                NSDictionary *say=PCDict(PCDict(PCDict(raw[@"pets"])[@"main"])[@"say"]);
                if(![strong.lastSayCounter isEqual:say[@"counter"]]){
                    strong.lastSayCounter=say[@"counter"];
                    NSString *reply=PCText(PCDict(say[@"data"])[@"text"],4000);
                    // A freshly attached native renderer must not replay historical speech.
                    double counter=[say[@"counter"] doubleValue];
                    if(reply.length&&counter>NSDate.date.timeIntervalSince1970*1000-15000&&![reply isEqualToString:strong.lastDeliveredReply]){
                        strong.lastDeliveredReply=reply;if(strong.replyHandler)strong.replyHandler(reply);
                    }
                }
                [strong schedulePollAfter:1];
            }else{
                strong.connected=NO;strong.consecutiveFailures++;
                NSString *status=http.statusCode==401||http.statusCode==403?@"DSH 连接需要授权 · 请从 DSH 启用 Touch Bar 桥接":PCOffline;
                [strong publishStatus:status];
                [strong schedulePollAfter:MIN(15,3*pow(2,MIN(strong.consecutiveFailures-1,3)))];
            }
        });
    }];[self.pollTask resume];
}
- (BOOL)interact:(NSString *)action { return NO; }
- (BOOL)performActionPath:(NSString *)path body:(NSDictionary *)body label:(NSString *)label {
    NSAssert(NSThread.isMainThread,@"WhaleBackend is owned by the main thread");
    if(!self.running||!self.connected||self.actionBusy)return NO;
    self.actionBusy=YES;[self publishStatus:label];
    NSMutableURLRequest *request=[self requestForPath:path method:@"POST" timeout:60];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    request.HTTPBody=[NSJSONSerialization dataWithJSONObject:body?:@{} options:0 error:nil];
    NSUInteger generation=self.generation;__weak WhaleBackend *owner=self;
    self.actionTask=[self.session dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
        dispatch_async(dispatch_get_main_queue(),^{
            WhaleBackend *strong=owner;if(!strong||!strong.running||strong.generation!=generation)return;
            strong.actionBusy=NO;strong.actionTask=nil;
            NSHTTPURLResponse *http=[response isKindOfClass:NSHTTPURLResponse.class]?(id)response:nil;
            id value=nil;if(!error&&http.statusCode==200&&data.length>0&&data.length<=1024*1024)value=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSDictionary *result=PCDict(value);NSString *reply=@"";
            if(error||http.statusCode!=200||!result.count)reply=@"请求失败：DSH 没有返回有效结果";
            else if(!PCBool(result[@"ok"]))reply=[@"请求失败：" stringByAppendingString:PCFailureText(result)];
            else reply=PCText(result[@"text"],4000);
            if(reply.length){
                NSMutableDictionary *summary=[strong.petSummary mutableCopy];summary[@"lastReply"]=reply;strong.petSummary=summary;
                if(![reply isEqualToString:strong.lastDeliveredReply]){strong.lastDeliveredReply=reply;if(strong.replyHandler)strong.replyHandler(reply);}
            }
            [strong publishStatus:strong.connected?PCConnected:PCOffline];
            if(strong.lastSnapshot&&strong.snapshotHandler){NSMutableDictionary *snapshot=[strong.lastSnapshot mutableCopy];snapshot[@"pcSummary"]=strong.petSummary;strong.snapshotHandler(snapshot);}
            [strong.pollTimer invalidate];strong.pollTimer=nil;
            [strong poll];
        });
    }];[self.actionTask resume];return YES;
}
- (BOOL)requestWhisper { return [self performActionPath:@"/whisper?pet=main&surface=any" body:@{} label:@"正在请 PC2005 鲸鱼娘说句话…"]; }
- (BOOL)refreshBalance { return [self performActionPath:@"/balance" body:@{} label:@"正在读取 DSH 服务商余额…"]; }
- (BOOL)sendChat:(NSString *)text {
    if(![text isKindOfClass:NSString.class])return NO;
    NSString *trimmed=[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if(!trimmed.length||trimmed.length>2000)return NO;
    return [self performActionPath:@"/chat?pet=main&surface=any" body:@{@"text":trimmed} label:@"PC2005 鲸鱼娘正在回复…"];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler { completionHandler(nil); }
- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition,NSURLCredential * _Nullable))completionHandler { completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge,nil); }
+ (NSDictionary *)runParsingTests {
    NSDictionary *empty=@{@"counter":@0,@"data":NSNull.null};
    double now=NSDate.date.timeIntervalSince1970;
    NSDictionary *(^make)(id,NSNumber *)=^NSDictionary *(id state,NSNumber *counter){return @{@"counter":counter,@"sections":@{@"workStatus":@{@"counter":counter,@"data":@{@"state":state,@"task":NSNull.null}},@"balance":empty,@"notify":empty,@"config":empty},@"pets":@{}};};
    WhaleBackend *backend=[WhaleBackend new];NSMutableDictionary *checks=[NSMutableDictionary new];
    checks[@"acceptsDocumentedEmptyState"]=@(IsSnapshot(make(NSNull.null,@0)));
    checks[@"rejectsHTML"]=@(!IsSnapshot(@"<html>DSH GUI</html>"));
    checks[@"rejectsLegacyWhaleGirlShape"]=@(!IsSnapshot(@{@"pet":@{},@"activity":@{@"name":@"think"}}));
    checks[@"rejectsMalformedLeaf"]=@(!IsSnapshot(@{@"counter":@1,@"sections":@{@"workStatus":@"thinking"},@"pets":@{}}));
    checks[@"rejectsUnknownWorkState"]=@(!IsSnapshot(make(@"pretend",@1)));
    NSDictionary *thinking=[backend normalizeSnapshot:make(@"thinking",@1) now:now];
    checks[@"thinkingUsesRealSessionFlag"]=@([thinking[@"activity"][@"sessionThink"] boolValue]);
    NSDictionary *waiting=[backend normalizeSnapshot:make(@"waiting",@2) now:now];
    checks[@"waitingUsesRealSessionFlag"]=@([waiting[@"activity"][@"sessionWait"] boolValue]);
    NSNumber *counter=@(floor(now*1000));
    NSDictionary *success=[backend normalizeSnapshot:make(@"success",counter) now:now];
    NSDictionary *same=[backend normalizeSnapshot:make(@"success",counter) now:now+2];
    checks[@"successExpiresFromEventCounterNotPollTime"]=@([success[@"activity"][@"turnCompletedUntil"] isEqual:same[@"activity"][@"turnCompletedUntil"]]);
    NSDictionary *stale=[backend normalizeSnapshot:make(@"success",@1) now:now];
    checks[@"oldSuccessDoesNotReplay"]=@([stale[@"activity"][@"name"] isEqualToString:@"idle"]);
    NSDictionary *error=[backend normalizeSnapshot:make(@"error",counter) now:now];
    checks[@"errorMapsToTimedErrorAnimation"]=@([error[@"activity"][@"name"] isEqualToString:@"error"]);
    checks[@"moneySummaryUsesReturnedCurrency"]=@([PCBalanceText(@{@"ok":@YES,@"shape":@"money",@"wallets":@[@{@"currency":@"CNY",@"total":@"8.16"},@{@"currency":@"USD",@"total":@"2.00"}]}) isEqualToString:@"余额：CNY 8.16 · USD 2.00"]);
    checks[@"unsupportedBalanceExplicit"]=@([PCBalanceText(@{@"ok":@NO,@"reason":@"unsupported"}) containsString:@"不支持"]);
    checks[@"terminalNotificationSummary"]=@([PCNotifyText(@{@"type":@"session/event",@"event":@{@"type":@"turn/end",@"data":@{@"reason":@{@"kind":@"completed"}}}}) isEqualToString:@"DSH 任务已完成"]);
    checks[@"loopbackOriginsOnly"]=@(IsLoopbackOrigin([NSURL URLWithString:@"http://127.0.0.1:41001"])&&IsLoopbackOrigin([NSURL URLWithString:@"http://localhost:3080/"])&&IsLoopbackOrigin([NSURL URLWithString:@"http://[::1]:3080"])&&!IsLoopbackOrigin([NSURL URLWithString:@"https://127.0.0.1:3080"])&&!IsLoopbackOrigin([NSURL URLWithString:@"http://127.0.0.1.example.org:3080"])&&!IsLoopbackOrigin([NSURL URLWithString:@"http://example.org:3080"])&&!IsLoopbackOrigin([NSURL URLWithString:@"http://user:password@127.0.0.1:3080"])&&!IsLoopbackOrigin([NSURL URLWithString:@"http://127.0.0.1:3080/other"]));
    checks[@"feedingAndPlayAreLocalOnly"]=@(![backend interact:@"feed"]&&![backend interact:@"play"]);
    checks[@"offlineModelCallsRejected"]=@(![backend requestWhisper]&&![backend refreshBalance]&&![backend sendChat:@"hello"]);
    BOOL passed=YES;for(NSNumber *value in checks.allValues)passed&=value.boolValue;
    return @{@"passed":@(passed),@"checks":checks,@"defaultOrigin":@"runtime-discovery-only",@"apiPrefix":PCPrefix,@"source":@"PC2005-cloud/dsh-pet v0.3.8"};
}
@end
