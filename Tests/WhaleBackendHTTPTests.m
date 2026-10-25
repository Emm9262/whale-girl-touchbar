#import <Foundation/Foundation.h>
#import "../Sources/WhaleBackend.h"

static NSString *RuntimeFixturePath;
@interface DiscoveryFixtureBackend : WhaleBackend
@end
@implementation DiscoveryFixtureBackend
- (NSString *)runtimeInfoPath { return RuntimeFixturePath; }
@end
static BOOL WaitUntil(NSTimeInterval seconds,BOOL (^predicate)(void)) {
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:seconds];
    while(!predicate()&&deadline.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.02]];
    return predicate();
}
static void RunFor(NSTimeInterval seconds) { WaitUntil(seconds,^BOOL(void){return NO;}); }
int main(int argc,const char *argv[]) {
    @autoreleasepool {
        if(argc!=6){fprintf(stderr,"Usage: backend-http-tests <origin> <redirect-origin> <html-origin> <new-origin> <report.json>\n");return 2;}
        NSMutableDictionary *checks=[NSMutableDictionary new];
        WhaleBackend *backend=[[WhaleBackend alloc] initWithBaseURL:[NSURL URLWithString:[NSString stringWithUTF8String:argv[1]]]];
        __block NSUInteger snapshots=0,replies=0;
        __block BOOL hasThinking=NO;
        __block NSString *lastReply=@"";
        NSMutableArray *deadlines=[NSMutableArray new];
        backend.snapshotHandler=^(NSDictionary *snapshot){
            snapshots++;if([snapshot[@"activity"][@"sessionThink"] boolValue])hasThinking=YES;
            if([snapshot[@"pcTaskState"] isEqual:@"success"])[deadlines addObject:snapshot[@"activity"][@"turnCompletedUntil"]];
        };
        backend.replyHandler=^(NSString *reply){replies++;lastReply=reply;};
        [backend start];[backend start];
        checks[@"connectsToDocumentedState"]=@(WaitUntil(5,^BOOL(void){return snapshots>0&&backend.connected;}));
        checks[@"normalizesThinking"]=@(hasThinking);
        checks[@"localFeedAndPlayMakeNoHTTPRequest"]=@(![backend interact:@"feed"]&&![backend interact:@"play"]);
        checks[@"acceptsWhisper"]=@([backend requestWhisper]);
        checks[@"onlyOneActionAtATime"]=@(backend.actionBusy&&![backend sendChat:@"must-not-send"]);
        checks[@"receivesWhisperText"]=@(WaitUntil(5,^BOOL(void){return [lastReply isEqual:@"fixture-whisper"]&&!backend.actionBusy;}));
        checks[@"rejectsEmptyAndOversizeChat"]=@(![backend sendChat:@"   "]&&![backend sendChat:[@"x" stringByPaddingToLength:2001 withString:@"x" startingAtIndex:0]]);
        checks[@"acceptsChat"]=@([backend sendChat:@"hello fixture"]);
        checks[@"receivesChatText"]=@(WaitUntil(5,^BOOL(void){return [lastReply isEqual:@"fixture-chat"]&&!backend.actionBusy;}));
        checks[@"acceptsBusinessFailureRequest"]=@([backend sendChat:@"fixture-error"]);
        checks[@"reportsBusinessFailureInsteadOfFakeReply"]=@(WaitUntil(5,^BOOL(void){return [lastReply hasPrefix:@"请求失败："]&&!backend.actionBusy;}));
        checks[@"acceptsManualBalance"]=@([backend refreshBalance]);
        checks[@"unsupportedBalanceStaysExplicit"]=@(WaitUntil(5,^BOOL(void){return !backend.actionBusy&&[backend.petSummary[@"balanceText"] containsString:@"不支持"];}));
        checks[@"pollsAgain"]=@(WaitUntil(4,^BOOL(void){return deadlines.count>=3;}));
        BOOL stable=deadlines.count>=3;
        for(NSNumber *deadline in deadlines)stable&=[deadline isEqual:deadlines.firstObject];
        checks[@"repeatedTerminalCounterDoesNotRestartCelebration"]=@(stable);
        checks[@"safeSummaryContainsProviderAndReply"]=@([backend.petSummary[@"source"] isEqual:@"PC2005/dsh-pet"]&&[backend.petSummary[@"lastReply"] hasPrefix:@"请求失败："]);
        [backend stop];NSUInteger stoppedSnapshots=snapshots,stoppedReplies=replies;
        RunFor(1.4);
        checks[@"stopCancelsTimersAndCallbacks"]=@(!backend.connected&&!backend.running&&!backend.actionBusy&&snapshots==stoppedSnapshots&&replies==stoppedReplies);
        checks[@"offlineActionsRejected"]=@(![backend requestWhisper]&&![backend refreshBalance]&&![backend sendChat:@"offline"]);
        [backend start];checks[@"sameClientReconnects"]=@(WaitUntil(5,^BOOL(void){return snapshots>stoppedSnapshots&&backend.connected;}));[backend stop];
        for(int i=2;i<=3;i++){
            WhaleBackend *bad=[[WhaleBackend alloc] initWithBaseURL:[NSURL URLWithString:[NSString stringWithUTF8String:argv[i]]]];
            __block BOOL failed=NO;__block NSUInteger accepted=0;
            bad.statusHandler=^(NSString *status){if([status containsString:@"未连接"])failed=YES;};
            bad.snapshotHandler=^(NSDictionary *snapshot){accepted++;};
            [bad start];BOOL handled=WaitUntil(5,^BOOL(void){return failed;});
            checks[i==2?@"rejectsHTTPRedirect":@"rejectsHTMLLoginPage"]=@(handled&&!bad.connected&&accepted==0);[bad stop];
        }
        RuntimeFixturePath=[[[NSString stringWithUTF8String:argv[5]] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"runtime-fixture.json"];
        NSURL *newOrigin=[NSURL URLWithString:[NSString stringWithUTF8String:argv[4]]];
        void (^writeRuntime)(NSString *)=^(NSString *origin){NSData *data=[NSJSONSerialization dataWithJSONObject:@{@"baseURL":origin} options:0 error:nil];[data writeToFile:RuntimeFixturePath atomically:YES];};
        writeRuntime([NSString stringWithUTF8String:argv[3]]);
        DiscoveryFixtureBackend *discovery=[DiscoveryFixtureBackend new];
        __block BOOL discoveryFailed=NO;__block NSUInteger discoveredSnapshots=0;
        discovery.statusHandler=^(NSString *status){if([status containsString:@"未连接"])discoveryFailed=YES;};
        discovery.snapshotHandler=^(NSDictionary *snapshot){discoveredSnapshots++;};
        [discovery start];checks[@"runtimeDiscoveryHandlesUnavailableHost"]=@(WaitUntil(4,^BOOL(void){return discoveryFailed;}));
        writeRuntime(newOrigin.absoluteString);
        checks[@"discoversPortPublishedAfterInitialFailure"]=@(WaitUntil(6,^BOOL(void){return discoveredSnapshots>0&&discovery.connected&&[discovery.baseURL isEqual:newOrigin];}));
        writeRuntime([NSString stringWithUTF8String:argv[1]]);
        NSURL *originalOrigin=[NSURL URLWithString:[NSString stringWithUTF8String:argv[1]]];
        checks[@"followsRuntimePortChangesWhileConnected"]=@(WaitUntil(3,^BOOL(void){return [discovery.baseURL isEqual:originalOrigin];}));
        [discovery stop];
        WhaleBackend *fixed=[[WhaleBackend alloc]initWithBaseURL:originalOrigin];
        writeRuntime(newOrigin.absoluteString);[fixed start];
        checks[@"manualOriginRemainsFixed"]=@(WaitUntil(3,^BOOL(void){return fixed.connected;})&&[fixed.baseURL isEqual:originalOrigin]);[fixed stop];
        NSDictionary *parsing=[WhaleBackend runParsingTests];checks[@"documentedShapeAndMappingTests"]=parsing[@"passed"];
        BOOL passed=YES;for(NSNumber *value in checks.allValues)passed&=value.boolValue;
        NSDictionary *report=@{@"passed":@(passed),@"checks":checks,@"snapshotCallbacks":@(snapshots),@"replyCallbacks":@(replies),@"parser":parsing,@"usedRealNSURLSession":@YES,@"modifiedDSHOrSystem":@NO};
        NSData *data=[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil];
        [data writeToFile:[NSString stringWithUTF8String:argv[5]] atomically:YES];fwrite(data.bytes,1,data.length,stdout);fputc('\n',stdout);
        return passed?0:1;
    }
}
