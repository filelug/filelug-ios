#import <Foundation/Foundation.h>

@interface UploadNotificationService : NSObject

// type of the upload notification, use the index order purposely, wrapping a NSUInteger
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

+ (NSString *)uploadNotificationNameWithUploadNotificationType:(NSNumber *)uploadNotificationType;

+ (NSNumber *)uploadNotificationTypeWithUploadNotificationName:(NSString *)uploadNotificationName;

- (instancetype)initWithUploadNotificationType:(NSNumber *)uploadNotificationType;

- (instancetype)initWithPersistedType;

- (void)persistWithSession:(NSString *)sessionId completionHandler:(void (^)(NSURLResponse *, NSData *, NSError *))completionHandler;

- (NSString *)description;

@end
