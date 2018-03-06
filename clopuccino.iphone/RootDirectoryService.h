#import <Foundation/Foundation.h>

@interface RootDirectoryService : NSObject

@property(nonatomic, assign) NSURLRequestCachePolicy cachePolicy;

@property(nonatomic, assign) NSTimeInterval timeInterval;

// elements of RootDirectoryModel
+ (NSMutableArray *)parseJsonAsRootDirectoryModelArray:(NSData *)data error:(NSError * __autoreleasing *)error;

// Get the image name from type of the root directory
+ (NSString *)imageNameFromRootDirectoryType:(NSString *)type;

- (id)initWithCachePolicy:(NSURLRequestCachePolicy)policy timeInterval:(NSTimeInterval)interval;

- (void)findRootsAndHomeDirectoryWithSession:(NSString *)sessionId showHidden:(BOOL)showHidden completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler;

@end
