#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

@class User;
@class FileTransfer;
@class FileTransferWithoutManaged;

NS_ASSUME_NONNULL_BEGIN

@interface FileTransferDao : NSObject

// create, if not exits,
// or update, if the one with the same user computer id and the real server file path already exists.
- (void)createOrUpdateFileTransferFromFileTransferWithoutManaged:(FileTransferWithoutManaged *)fileTransferWithoutManaged;

- (void)createFileTransferFromFileTransferWithoutManaged:(FileTransferWithoutManaged *)fileTransferWithoutManaged;

// find by user, sort by start timestamp, return elements of FileTransferWithoutManaged
- (NSArray *)findFileTransfersForUserComputer:(NSString *)userComputerId error:(NSError *_Nullable __autoreleasing *_Nullable)error;

// combine the following two methods to prevent moc blocking error
// (NSInternalInconsistencyException, reason: statement is still active):
// findFileTransferForTransferKey: error: && fetchedResultsController: objectAtIndexPath:
- (FileTransferWithoutManaged *)findFileTransferForFetchedResultsController:(NSFetchedResultsController *)fetchedResultsController objectAtIndexPath:(NSIndexPath *)indexPath;

// Find the FileTransferWithoutManaged for the specified transfer key.
// If the error is not nil, return nil.
- (FileTransferWithoutManaged *)findFileTransferForTransferKey:(NSString *)transferKey error:(NSError *_Nullable __autoreleasing *_Nullable)error;

// Deletes the file transfer with the specified transfer key.
// If the FileTransfer with the transfer key not found, the successHandler invokes, instead of errorHandler.
// errorHandler will be invoked only when error occurred on FileTransfer found and failed to delete it. The error of the errorHandler describes the reason why the FileTransfer failed to delete.
- (void)deleteFileTransferForTransferKey:(NSString *)transferKey
                          successHandler:(void (^ _Nullable)(void))successHandler
                            errorHandler:(void (^ _Nullable)(NSError *_Nullable error))errorHandler;

// Set the property hidden of the file transfer with the specified transfer key to ON.
- (void)hideFileTransferForTransferKey:(NSString *)transferKey error:(NSError *_Nullable __autoreleasing *)error;

// returns FileTransfer or nil if not found. one record at most for the same server file path of the same user account.
- (nullable FileTransferWithoutManaged *)findFileTransferForUserComputer:(NSString *)userComputerId
                                                          realServerPath:(NSString *)realServerPath
                                                                   error:(NSError *_Nullable __autoreleasing *_Nullable)error;

- (BOOL)existsTransferForUserComputer:(NSString *)userComputerId
                       realServerPath:(NSString *)realServerPath
                                error:(NSError *_Nullable __autoreleasing *_Nullable)error;

- (NSNumber *)countForUserComputer:(NSString *)userComputerId realServerPath:(NSString *)realServerPath error:(NSError *_Nullable __autoreleasing *_Nullable)error;

// return YES only if file exists and the status is FILE_TRANSFER_STATUS_COMPLETED
- (BOOL)fileSuccessfullyDownloadedForUserComputer:(NSString *)userComputerId realServerPath:(NSString *)realServerPath error:(NSError *_Nullable __autoreleasing *_Nullable)error;

// Find FileTransfer with the transfer key, instead of the realServerPath
// and updates other properties with the specified FileTransferWithoutManaged
- (void)updateFileTransferWithSameTransferKey:(FileTransferWithoutManaged *)fileTransferWithoutManaged;

- (void)updateFileTransfer:(FileTransferWithoutManaged *)fileTransferWithoutManaged;

- (void)updateFileTransfer:(FileTransferWithoutManaged *)fileTransferWithoutManaged completionHandler:(void (^ _Nullable)(void))completionHandler;

- (NSString *)actionsAfterDownloadForUserComputer:(NSString *)userComputerId
                                   realServerPath:(NSString *)realServerPath
                                            error:(NSError *_Nullable __autoreleasing *_Nullable)error;

// get the value of open in actionsAfterDownload
- (BOOL)shouldOpenAfterDownloadForUserComputer:(NSString *)userComputerId
                                realServerPath:(NSString *)realServerPath
                                         error:(NSError *_Nullable __autoreleasing *_Nullable)error;

// get the value of share in actionsAfterDownload
- (BOOL)shouldShareAfterDownloadForUserComputer:(NSString *)userComputerId
                                 realServerPath:(NSString *)realServerPath
                                          error:(NSError *_Nullable __autoreleasing *_Nullable)error;

//- (NSNumber *)findOpenAfterDownloadForUserComputer:(NSString *)userComputerId serverFilePath:(NSString *)serverPath error:(NSError * __autoreleasing *)error;

// when < 0           --> download not started
// when > 0 and < 1   --> download is progressing
// when == 1          --> download finished
// when == 2          --> download canceling
// when == 3          --> download failed
- (void)downloadedPercentageForUserComputer:(NSString *)userComputerId realServerPath:(NSString *)realServerPath completionHandler:(void (^ _Nullable)(float percentage))completionHandler;

// Updates the value of open in actionsAfterDownload to new value
- (void)updateOpenValueInActionsAfterDownloadForUserComputer:(NSString *)userComputerId realServerPath:(NSString *)realServerPath toNewOpenValue:(BOOL)newOpenValue completionHandler:(void (^ _Nullable)(NSString *_Nullable, BOOL))handler;

// Updates the value of share in actionsAfterDownload to new value
// completionHandler:(void (^)(NSURLResponse *, NSData *, NSError *))handler
- (void)updateShareValueInActionsAfterDownloadForUserComputer:(NSString *)userComputerId realServerPath:(NSString *)realServerPath toNewShareValue:(BOOL)newShareValue completionHandler:(void (^ _Nullable)(NSString *_Nullable, BOOL))handler;

// for all users
- (void)changeDowloadStatusFromUnfinishedToFailed;

- (NSString *)findTransferKeyOfFirstFileWithFileDownloadGroupId:(NSString *)fileDownloadGroupId;

#pragma mark - NSFetchedResultsController, for delegates of UITableView

- (nullable NSFetchedResultsController *)createFileInfoFetchedResultsControllerForUserComputer:(NSString *)userComputerId
                                                                                realServerPath:(NSString *)realServerPath
                                                                                      delegate:(id <NSFetchedResultsControllerDelegate>)delegate;

// Show only FileTransfer with hidden == NO
- (nullable NSFetchedResultsController *)createFileDownloadFetchedResultsControllerForUserComputerId:(NSString *)userComputerId
                                                                                            delegate:(id <NSFetchedResultsControllerDelegate>)delegate;

// Show FileTransfer of all users and computers with download status == success
- (nullable NSFetchedResultsController *)createFileDownloadFetchedResultsControllerForAllUsersWithDelegate:(id <NSFetchedResultsControllerDelegate>)delegate;

- (BOOL)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController performFetch:(NSError *_Nullable __autoreleasing *_Nullable)error;

- (nullable FileTransferWithoutManaged *)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController objectAtIndexPath:(NSIndexPath *)indexPath;

- (NSInteger)numberOfSectionsForFetchedResultsController:(NSFetchedResultsController *)fetchedResultsController;

- (NSString *)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController titleForHeaderInSection:(NSInteger)section includingComputerName:(BOOL)includingComputerName;

- (NSInteger)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController numberOfRowsInSection:(NSInteger)section;

- (nullable NSString *)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController sectionName:(NSInteger)section;

- (nullable NSArray *)sectionIndexTitlesForFetchedResultsController:(NSFetchedResultsController *)fetchedResultsController;

- (NSInteger)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index;

- (nullable NSIndexPath *)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController indexPathForTransferKey:(NSString *)transferKey;

// find every file transfer with waitToConfirm == true and run completionHandler with the found file transfer.
// If you find 8 file transfers with waitToConfirm == true, then completionHandler will be invoked 8 times with every file transfer found.
- (void)findWaitToConfirmFileTransferWithCompletionHandler:(void (^ _Nullable)(FileTransferWithoutManaged *_Nullable fileTransferWithoutManaged))completionHandler;

- (void)findAllCancelingDownloadsAndChangeToFailure;

- (nullable FileTransferWithoutManaged *)findOneUnfinishedDownloadForUserComputer:(NSString *)userComputerId error:(NSError *_Nullable __autoreleasing *_Nullable)error;

- (nullable FileTransferWithoutManaged *)findOneSuccessfullyDownloadedForUserComputer:(NSString *)userComputerId error:(NSError *_Nullable __autoreleasing *_Nullable)error;

- (void)updateFileTransferLocalPathToRelativePath;

#pragma mark - Manage resumeDataDictionary

// append

- (void)addResumeData:(NSData *_Nullable)resumeData toFileTransferWithTransferKey:(NSString *)transferKey completionHandler:(void (^ _Nullable)(NSError *_Nullable))completionHandler;

// find

- (nullable NSData *)resumeDataFromFileTransferWithTransferKey:(NSString *)transferKey error:(NSError *_Nullable __autoreleasing *_Nullable)error;

// Remove single

- (void)removeResumeDataFromFileTransferWithTransferKey:(NSString *)transferKey completionHandler:(void (^ _Nullable)(NSError *_Nullable))completionHandler;

- (void)removeResumeDataWithRealServerPath:(NSString *)realServerPath userComputerId:(NSString *)userComputerId completionHandler:(void (^ _Nullable)(NSError *_Nullable))completionHandler;

// remove all for one user computer

- (void)removeResumeDataWithUserComputerId:(NSString *)userComputerId;

- (void)deleteFileTransfersWithoutStatusOfSuccess;

@end

NS_ASSUME_NONNULL_END
