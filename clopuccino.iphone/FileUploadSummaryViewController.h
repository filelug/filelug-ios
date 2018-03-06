#import <UIKit/UIKit.h>
#import <FilelugKit/FilelugKit.h>
#import "FilePreviewControllerDelegate.h"
#import "UploadDescriptionDataSource.h"

@interface FileUploadSummaryViewController : UITableViewController <UploadDescriptionDataSource, FilePreviewControllerDelegate, ProcessableViewController, PHPhotoLibraryChangeObserver>

@property(nonatomic, strong) NSString *directory;

#pragma mark - FilePreviewControllerDelegate

@property(nonatomic, strong) QLPreviewController *previewController;

#pragma mark - UploadDescriptionDataSource

@property(nonatomic, strong) UploadDescriptionService *uploadDescriptionService;

- (BOOL)needPersistIfChanged;

@end
