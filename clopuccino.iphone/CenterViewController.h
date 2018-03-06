#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import "FilePreviewControllerDelegate.h"

@class NSFetchedResultsController;

@interface CenterViewController : UITableViewController <NSFetchedResultsControllerDelegate, UIDocumentInteractionControllerDelegate, FilePreviewControllerDelegate, ProcessableViewController>

@property(nonatomic, strong) NSString *parentPath;

@property(nonatomic, assign) BOOL directoryOnly;

#pragma mark - FilePreviewControllerDelegate

@property(nonatomic, strong) QLPreviewController *previewController;

@end
