#import <Foundation/Foundation.h>

@interface UploadDescriptionService : NSObject

// type of the upload description, use the index order purposely, wrapping a NSUInteger
@property(nonatomic, readonly, strong) NSNumber *type;

@property(nonatomic, readonly, strong) NSString *name;

// if YES, user should enter something
@property(nonatomic) BOOL customizable;

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

+ (NSString *)uploadDescriptionNameWithUploadDescriptionType:(NSNumber *)uploadDescriptionType;

+ (NSNumber *)uploadDescriptionTypeWithUploadDescriptionName:(NSString *)uploadDescriptionName;

- (instancetype)initWithUploadDescriptionType:(NSNumber *)uploadDescriptionType uploadDescriptionValue:(NSString *)uploadDescriptionValue;

- (instancetype)initWithPersistedTypeAndValue;

- (NSString *)generateRealDescriptionValueWithFilenames:(NSArray *)filenames;

- (NSString *)displayedText;

- (void)persistWithSession:(NSString *)sessionId completionHandler:(void (^)(NSURLResponse *, NSData *, NSError *))completionHandler;

- (NSString *)description;

@end
