#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FileTransferWithoutManaged : NSObject <NSCopying>

@property(nonatomic, strong) NSString *userComputerId;
@property(nonatomic, strong) NSString *downloadGroupId;
@property(nonatomic, strong) NSString *serverPath;
@property(nonatomic, strong) NSString *realServerPath;

@property(nonatomic, strong) NSString *_Nullable localPath;
@property(nonatomic, strong) NSString *_Nullable contentType;
@property(nonatomic, strong) NSString *_Nullable displaySize;
@property(nonatomic, strong) NSString *_Nullable type;
@property(nonatomic, strong) NSString *_Nullable lastModified;
@property(nonatomic, strong) NSString *_Nullable status;
@property(nonatomic, strong) NSNumber *_Nullable totalSize;
@property(nonatomic, strong) NSNumber *_Nullable transferredSize;
@property(nonatomic, strong) NSNumber *_Nullable startTimestamp;
@property(nonatomic, strong) NSNumber *_Nullable endTimestamp;
@property(nonatomic, strong) NSString *_Nullable actionsAfterDownload;
@property(nonatomic, strong) NSString *_Nullable transferKey;
@property(nonatomic, retain) NSNumber *_Nullable hidden;
@property(nonatomic, strong) NSNumber *_Nullable waitToConfirm;


// Should modified if actions are more than two.
+ (NSString *)prepareActionsAfterDownloadWithOpen:(BOOL)open share:(BOOL)share;

// reverse of actionArrayFromActionsAfterDownload:
+ (NSString *)actionsAfterDownloadFromActionArray:(NSArray *)actionArray;

// elements of NSNumber from litteral boolean string like @YES or @NO.
// Can be accessed via ex. NSLog(@"Value is %d:", [array[0]  boolValue]);
+ (NSMutableArray *)actionArrayFromActionsAfterDownload:(NSString *)actionsAfterDownload;

+ (BOOL)openInActionsAfterDownload:(NSString *_Nullable)actionsAfterDownload;

+ (BOOL)shareInActionsAfterDownload:(NSString *_Nullable)actionsAfterDownload;

- (id)initWithUserComputerId:(NSString *)userComputerId
             downloadGroupId:(NSString *)downloadGroupId
                  serverPath:(NSString *)serverPath
              realServerPath:(NSString *)realServerPath
                   localPath:(NSString *_Nullable)localPath
                 contentType:(NSString *_Nullable)contentType
                 displaySize:(NSString *_Nullable)displaySize
                        type:(NSString *_Nullable)type
                lastModified:(NSString *_Nullable)lastModified
                      status:(NSString *_Nullable)status
                   totalSize:(NSNumber *_Nullable)totalSize
             transferredSize:(NSNumber *_Nullable)transferredSize
              startTimestamp:(NSNumber *_Nullable)startTimestamp
                endTimestamp:(NSNumber *_Nullable)endTimestamp
        actionsAfterDownload:(NSString *_Nullable)actionsAfterDownload
                 transferKey:(NSString *_Nullable)transferKey
                      hidden:(NSNumber *_Nullable)hidden
               waitToConfirm:(NSNumber *_Nullable)waitToConfirm;

//- (id)initWithUserComputerId:(NSString *)userComputerId serverPath:(NSString *)serverPath realServerPath:(NSString *)realServerPath localPath:(NSString *)localPath contentType:(NSString *)contentType displaySize:(NSString *)displaySize type:(NSString *)type lastModified:(NSString *)lastModified status:(NSString *)status totalSize:(NSNumber *)totalSize transferredSize:(NSNumber *)transferredSize startTimestamp:(NSNumber *)startTimestamp endTimestamp:(NSNumber *)endTimestamp actionsAfterDownload:(NSString *)actionsAfterDownload transferKey:(NSString *)transferKey hidden:(NSNumber *)hidden waitToConfirm:(NSNumber *)waitToConfirm;

- (NSString *)description;

// elements of NSNumber from litteral boolean string like @YES or @NO.
// Can be accessed via ex. NSLog(@"Value is %d:", [array[0]  boolValue]);
// Return nil if property actionsAfterDownload is nil or empty.
// Should modified if actions are more than two.
- (NSArray *)actionArrayAfterDownload;

- (NSUInteger)countActionsAfterDownload;

- (BOOL)openAfterDownload;

- (BOOL)shareAfterDownload;

- (id)copyWithZone:(nullable NSZone *)zone;

@end

NS_ASSUME_NONNULL_END
