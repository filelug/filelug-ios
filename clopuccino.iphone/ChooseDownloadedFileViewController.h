#import <UIKit/UIKit.h>
#import "FilePreviewControllerDelegate.h"

@interface ChooseDownloadedFileViewController : UITableViewController<NSFetchedResultsControllerDelegate, UIDocumentInteractionControllerDelegate, FilePreviewControllerDelegate, ProcessableViewController>

#pragma mark - FilePreviewControllerDelegate

@property(nullable, nonatomic, strong) QLPreviewController *previewController;

@end
