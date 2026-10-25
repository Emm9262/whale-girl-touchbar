#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Native client for an already-running PC2005-cloud/dsh-pet v0.3.8 host.
/// Uses its public loopback API; never reads credentials or installs a plugin.
@interface WhaleBackend : NSObject
@property(nonatomic, copy, nullable) void (^snapshotHandler)(NSDictionary *snapshot);
@property(nonatomic, copy, nullable) void (^statusHandler)(NSString *status);
@property(nonatomic, copy, nullable) void (^replyHandler)(NSString *reply);
@property(nonatomic, readonly) BOOL connected;
@property(nonatomic, readonly) BOOL running;
@property(nonatomic, readonly) BOOL actionBusy;
@property(nonatomic, readonly, strong, nullable) NSURL *baseURL;
/// Safe, display-ready values only; no raw provider credentials or conversation history.
@property(nonatomic, readonly, copy) NSDictionary *petSummary;
@property(nonatomic, readonly, copy) NSString *connectionStatus;
/// Accepts only credential-free HTTP loopback origins, with no path/query/fragment.
- (nullable instancetype)initWithBaseURL:(NSURL *)baseURL;
- (void)start;
- (void)stop;
/// PC2005 has no feeding/affinity API. These actions remain local and return NO.
- (BOOL)interact:(NSString *)action;
/// User-triggered model calls. At most one action is pending; all callbacks use main queue.
- (BOOL)requestWhisper;
- (BOOL)refreshBalance;
- (BOOL)sendChat:(NSString *)text;
+ (NSDictionary *)runParsingTests;
@end

NS_ASSUME_NONNULL_END
