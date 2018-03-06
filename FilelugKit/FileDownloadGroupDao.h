#import <Foundation/Foundation.h>

@class FileDownloadGroup;
@class FileTransfer;
@class UserComputer;
@class FileDownloadGroupWithoutManaged;

NS_ASSUME_NONNULL_BEGIN

@interface FileDownloadGroupDao : NSObject

- (void)createFileDownloadGroupWithDownloadGroupId:(NSString *)downloadGroupId notificationType:(NSInteger)notificationType userComputerId:(NSString *)userComputerId completionHandler:(void (^ _Nullable)(void))completionHandler;

// The method must invoke in the specified managedObjectContext block
- (void)createFileDownloadGroupButNotSaveInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext downloadGroupId:(NSString *)downloadGroupId notificationType:(NSInteger)notificationType userComputer:(UserComputer *)userComputer fileTransfers:(NSSet<FileTransfer *> *)fileTransfers;

// The method can only be invoked in the block of the specified NSManagedObjectContext
- (nullable FileDownloadGroup *)findFileDownloadGroupByDownloadGroupId:(NSString *)downloadGroupId managedObjectContext:(NSManagedObjectContext *)managedObjectContext;

- (FileDownloadGroupWithoutManaged *)findFileDownloadGroupByTransferKey:(NSString *)transferKey;

@end

NS_ASSUME_NONNULL_END
