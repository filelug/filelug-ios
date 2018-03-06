#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>


@class AssetFileWithoutManaged;
@class NSFetchedResultsController;
@class AssetFile;


NS_ASSUME_NONNULL_BEGIN

@interface AssetFileDao : NSObject

- (void)createAssetFileFromAssetFileWithoutManaged:(AssetFileWithoutManaged *)assetFileWithoutManaged completionHandler:(void (^ _Nullable)(void))completionHandler;

- (nullable NSNumber *)countForTransferKey:(NSString *)transferKey error:(NSError * __autoreleasing *)error;

- (nullable AssetFileWithoutManaged *)findAssetFileForFetchedResultsController:(NSFetchedResultsController *)fetchedResultsController objectAtIndexPath:(NSIndexPath *)indexPath;

- (nullable AssetFileWithoutManaged *)findAssetFileForTransferKey:(NSString *)transferKey error:(NSError * __autoreleasing *)error;

- (void)findAssetFileForTransferKey:(NSString *)transferKey completionHandler:(void (^ _Nullable)(AssetFileWithoutManaged *assetFileWithoutManaged, NSError *error))completionHandler;

- (void)findAssetFileForDownloadedFileTransferKey:(NSString *)downloadedFileTransferKey completionHandler:(void (^ _Nullable)(NSArray<AssetFileWithoutManaged *> *, NSError *))completionHandler;

- (nullable NSNumber *)countForUserComputer:(NSString *)userComputerId fileUploadGroupId:(nullable NSString *)fileUploadGroupId assetURL:(NSString *)assetURL directory:(NSString *)directory filename:(NSString *)filename error:(NSError * __autoreleasing *)error;

// return array with elements of AssetFileWithoutManaged
- (nullable NSArray *)findAssetFileForUserComputer:(NSString *)userComputerId fileUploadGroupId:(nullable NSString *)fileUploadGroupId directory:(NSString *)directory filename:(NSString *)filename error:(NSError * __autoreleasing *)error;

// completionHandler will be invoked on each found AssetFile
- (void)findAssetFilesWithFileUploadGroupId:(NSString *)fileUploadGroupId completionHandler:(void (^ _Nullable)(AssetFile *))completionHandler;

- (nullable AssetFileWithoutManaged *)findAssetFileForUserComputer:(NSString *)userComputerId fileUploadGroupId:(nullable NSString *)fileUploadGroupId assetURL:(NSString *)assetURL directory:(NSString *)directory filename:(NSString *)filename error:(NSError * __autoreleasing *)error;

- (void)updateAssetFile:(AssetFileWithoutManaged *)assetFileWithoutManaged;

- (void)updateAssetFile:(AssetFile *)assetFile managedObjectContext:(NSManagedObjectContext *)moc;

- (void)updateAssetFile:(AssetFileWithoutManaged *)assetFileWithoutManaged completionHandler:(void (^ _Nullable)(void))completionHandler;

#pragma mark NSFetchedResultsController

- (NSFetchedResultsController *)createFileUploadFetchedResultsControllerForUserComputerId:(NSString *)userComputerId delegate:(nullable id <NSFetchedResultsControllerDelegate>)delegate;

- (NSFetchedResultsController *)createFileUploadFetchedResultsControllerForTransferKey:(NSString *)transferKey delegate:(id <NSFetchedResultsControllerDelegate>)delegate;

- (BOOL)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController performFetch:(NSError * __autoreleasing *)error;

- (nullable AssetFileWithoutManaged *)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController objectAtIndexPath:(NSIndexPath *)indexPath;

- (NSInteger)numberOfSectionsForFetchedResultsController:(NSFetchedResultsController *)fetchedResultsController;

- (nullable NSString *)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController titleForHeaderInSection:(NSInteger)section;

- (NSInteger)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController numberOfRowsInSection:(NSInteger)section;

- (NSIndexPath *)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController indexPathForTransferKey:(NSString *)transferKey;

// If completionHandler is nil or no wait-to-comfirm uploading file, do nothing.
- (void)findWaitToConfirmAssetFileTransferKeyAndStatusDictionaryWithCompletionHandler:(void (^ _Nullable)(NSDictionary *transferKeyAndStatusDictionary))completionHandler;

- (nullable NSDictionary *)findWaitToConfirmAssetFileTransferKeyAndStatusDictionary;

- (void)findWaitToConfirmAssetFileWithCompletionHandler:(void (^ _Nullable)(AssetFileWithoutManaged *assetFileWithoutManaged))completionHandler;

- (nullable NSString *)findComputerNameForTransferKey:(NSString *)transferKey;

- (nullable NSString *)findFileUploadStatusForTransferKey:(NSString *)transferKey;

// Deletes the asset file with the specified transfer key.
// errorHandler will be invoked only when error is non-nil
- (void)deleteAssetFileForTransferKey:(NSString *)transferKey successHandler:(void (^ _Nullable)(void))successHandler errorHandler:(void (^ _Nullable)(NSError *error))errorHandler;

- (nullable NSArray *)findAssetFilesForAssetURL:(NSString *)assetURL;

- (BOOL)existsAssetFilesForAssetURL:(NSString *)assetURL;

- (nullable NSArray *)findAssetFilesForAssetURLWithSuffix:(NSString *)suffix;

- (nullable NSDictionary *)findUnfinishedAssetFileTransferKeyAndStatusDictionary;

- (BOOL)existingUnfinishedAssetFile;

- (nullable AssetFileWithoutManaged *)findFirstAssetFileWithStatusPreparingOrderByStartTimestampASC;

- (BOOL)existsAssetFileWithStatusPreparing;

- (void)prepareUploadStatusWithAssetFileWithoutManaged:(AssetFileWithoutManaged *)assetFileWithoutManaged
                                   currentStatusString:(NSString *)currentStatusString
                                    currentStatusColor:(UIColor *)currentStatusColor
                                     completionHandler:(void (^)(NSString *statusString, UIColor *statusColor))completionHandler;

- (void)findAssetFileForZeroOrEmptySourceTypeWithCompletionHandler:(void (^)(AssetFile *, NSManagedObjectContext *))completionHandler;

- (AssetFileWithoutManaged *)findOneUnfinishedUploadForUserComputer:(NSString *)userComputerId error:(NSError * __autoreleasing *)error;

- (NSArray<NSString *> *)findAssetURLWithSourceType:(NSNumber *)sourceType;

- (void)deleteAssetFilesWithSourceTypeOfSharedFileButNoDownloadedTransferKeyWithCompletionHandler:(void (^ _Nullable)(NSError *_Nullable))completionHandler;

- (void)deleteAssetFilesForUploadedSuccessfullyWithCompletionHandler:(void (^)(NSError *))completionHandler;

@end

NS_ASSUME_NONNULL_END
