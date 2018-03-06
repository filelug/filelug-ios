#import <Foundation/Foundation.h>


@interface DownloadNotificationService : NSObject

// type of the download notification, use the index order purposely, wrapping a NSUInteger
@property(nonatomic, readonly, strong) NSNumber *type;

@property(nonatomic, readonly, strong) NSString *name;

// key: notification type, class of NSNumber
// value: notification name: class of NSString
+ (NSDictionary *)allTypeAndNameDictionaryWithOrder;

// Elements of type NSNumber, wrapping NSUInteger
+ (NSArray *)allTypesWithOrder;

// Elements of type NSString
+ (NSArray *)namesOfAllTypesWithOrder;

+ (NSInteger)defaultType;

+ (NSNumber *)downloadNotificationTypeWithDownloadNotificationName:(NSString *)downloadNotificationName;

- (instancetype)initWithDownloadNotificationType:(NSNumber *)downloadNotificationType;

- (instancetype)initWithPersistedType;

- (void)persistWithSession:(NSString *)sessionId completionHandler:(void (^)(NSURLResponse *, NSData *, NSError *))completionHandler;

- (NSString *)description;

@end
