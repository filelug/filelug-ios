#import <Foundation/Foundation.h>

@class FileUploadViewController;
@class BBBadgeBarButtonItem;

@interface FileUploadProcessService : NSObject

// the staring view controll to initiate the upload process, type of FileUploadViewController
@property(nullable, nonatomic, weak) FileUploadViewController *fromViewController;

// iOS 7 --> value of property ALAssetPropertyAssetURL of selected ALAsset in self.assets, elements of type NSString, converted from [ALAsset absoluteString]
// iOS 8 --> localIdentifier of selected PHAsset, elements of type NSString
@property(nonnull, nonatomic, strong) NSMutableArray *selectedAssetIdentifiers;

// For files from file-sharing, file path relative to the Document directory
// The Document directory is changing based on the Apple's security policy, so
// absolute path of a file from file-sharing may not exist when then next time the app is activated.
//@property(nonnull, nonatomic, strong) NSMutableArray *selectedFileRelPaths;

// For downloaded files from all users and computers, the files are saved locally in differrent folders, so
// saving as the relative path is not working, and if we save it as the absolute path, it might not be found
// because the sandbox mechanism changed the folder abolute path next time the device start up.
// So what we can use for now is by saving FileTransferWithoutManged directly.
@property(nonnull, nonatomic, strong) NSMutableArray<FileTransferWithoutManaged *> *downloadedFiles;

// Only one instance for one application
+ (instancetype __nonnull)defaultService;

// Go to FileUploadSummaryViewController with necessary information
- (void)pushToUploadSummaryViewControllerFromViewController:(UIViewController *__nonnull)viewController;

// Set fromViewController to nil, remove all objects to selectedAssetIdentifiers and selectedFileRelPaths
- (void)reset;

// Update BBBadgeBarButtonItem based on the total selected files and assets.
// Usually executed in main queue to reflect the UI change of BBBadgeBarButtonItem
- (void)updateBadgeBarButtonItem:(BBBadgeBarButtonItem *_Nonnull)badgeBarButtonItem;

// count of selectedFileRelPaths and selectedAssetIdentifiers
- (NSUInteger)totalSelectedCount;

- (nullable FileTransferWithoutManaged *)findFromDownloadedFilesWithTransferKey:(NSString *_Nonnull)transferKey;

// Do nothing if the FileTransferWithoutManaged with the specified transferKey not found.
- (void)removeDownloadedFileWithTransferKey:(NSString *_Nonnull)transferKey;

@end