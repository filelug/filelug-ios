#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import "FilePreviewControllerDelegate.h"

@class NSFetchedResultsController;

@interface DownloadFileViewController : UITableViewController <NSFetchedResultsControllerDelegate, UIDocumentInteractionControllerDelegate, FilePreviewControllerDelegate, ProcessableViewController>

// if not nil, scroll to the index path of the cell with the transfer key
@property(nonatomic, strong, nullable) NSString *transferKeyToScrollTo;

// if not nil, programmatically press on the specified cell with the transfer key
@property(nonatomic, strong, nullable) NSString *transferKeyToPressOn;

- (IBAction)addFile:(nullable id)sender;

#pragma mark - FilePreviewControllerDelegate

@property(nullable, nonatomic, strong) QLPreviewController *previewController;

@end
