#import <Foundation/Foundation.h>

@class FileTransferWithoutManaged;
@class UserComputerWithoutManaged;

NS_ASSUME_NONNULL_BEGIN

@interface FileDownloadGroupWithoutManaged : NSObject

@property (nullable, nonatomic, strong) NSString *downloadGroupId;

@property (nullable, nonatomic, strong) NSNumber *notificationType;

@property (nullable, nonatomic, strong) NSNumber *createTimestamp;

@property (nullable, nonatomic, strong) NSSet<NSString *> *fileTransferKeys;

@property (nullable, nonatomic, strong) NSString *userComputerId;

- (instancetype)initWithDownloadGroupId:(nullable NSString *)downloadGroupId
                       notificationType:(nullable NSNumber *)notificationType
                        createTimestamp:(nullable NSNumber *)createTimestamp
                       fileTransferKeys:(nullable NSSet<NSString *> *)fileTransferKeys
                         userComputerId:(nullable NSString *)userComputerId;

- (NSString *)description;


@end

NS_ASSUME_NONNULL_END
