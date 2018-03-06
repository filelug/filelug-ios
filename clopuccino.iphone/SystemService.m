#import "SystemService.h"
#import "NSString+Utlities.h"
#import "Utility.h"

@implementation SystemService {
}

+ (void)parsePingDesktopResponseJson:(NSData *)data completionHandler:(void (^)(NSDictionary *))handler {
    NSError *jsonError = nil;
    NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];
    
    if (handler) {
        if (jsonError) {
            handler(nil);
        } else {
            handler(jsonObject);
        }
    }
}

- (id)initWithCachePolicy:(NSURLRequestCachePolicy)policy timeInterval:(NSTimeInterval)interval {
    if (self = [super init]) {
        _cachePolicy = policy;
        _timeInterval = interval;
    }
    
    return self;
}

- (void)pingDesktop:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    NSString *urlString = [Utility composeAAServerURLStringWithPath:@"system/dping"];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
    
    [request setHTTPMethod:@"POST"];
    
    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];
    
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *account = [[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_ID] escapeIllegalJsonCharacter];
    
    NSString *bodyString = [NSString stringWithFormat:@"{\"account\":\"%@\"}", account];
    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/json; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
}

@end
