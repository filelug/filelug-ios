#import <Foundation/Foundation.h>

@interface UploadSubdirectoryService : NSObject

// type of the upload subdirectory, use the index order purposely, wrapping a NSUInteger
@property(nonatomic, readonly, strong) NSNumber *type;

@property(nonatomic, readonly, strong) NSString *name;

// if YES, user should enter something
@property(nonatomic) BOOL customizable;

// that is, upload_subdirectory_value
@property(nonatomic, strong) NSString *customizedValue;

// key: notification type, class of NSNumber
// value: notification name: class of NSString
+ (NSDictionary *)allTypeAndNameDictionaryWithOrder;

// Elements of type NSNumber, wrapping NSUInteger
+ (NSArray *)allTypesWithOrder;

// Elements of type NSString
+ (NSArray *)namesOfAllTypesWithOrder;

+ (NSInteger)defaultType;

+ (BOOL)isCustomizableWithType:(NSInteger)type;

+ (NSString *)uploadSubdirectoryNameWithUploadSubdirectoryType:(NSNumber *)uploadSubdirectoryType;

+ (NSNumber *)uploadSubdirectoryTypeWithUploadSubdirectoryName:(NSString *)uploadSubdirectoryName;

- (instancetype)initWithUploadSubdirectoryType:(NSNumber *)uploadSubdirectoryType uploadSubdirectoryValue:(NSString *)uploadSubdirectoryValue;

- (instancetype)initWithPersistedTypeAndValue;

- (NSString *)generateRealSubdirectoryValue;

- (NSString *)displayedText;

- (void)persistWithSession:(NSString *)sessionId completionHandler:(void (^)(NSURLResponse *, NSData *, NSError *))completionHandler;

- (NSString *)description;

@end
