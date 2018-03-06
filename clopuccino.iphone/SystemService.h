#import <Foundation/Foundation.h>

@interface SystemService : NSObject

@property(nonatomic, assign) NSURLRequestCachePolicy cachePolicy;

@property(nonatomic, assign) NSTimeInterval timeInterval;

+ (void)parsePingDesktopResponseJson:(NSData *)data completionHandler:(void (^)(NSDictionary *))handler;

- (id)initWithCachePolicy:(NSURLRequestCachePolicy)policy timeInterval:(NSTimeInterval)interval;

- (void)pingDesktop:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler;

@end
