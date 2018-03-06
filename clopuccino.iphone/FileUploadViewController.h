#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import "FilePreviewControllerDelegate.h"

@interface FileUploadViewController : UITableViewController <NSFetchedResultsControllerDelegate, FilePreviewControllerDelegate, ProcessableViewController>

@property(nonatomic, strong, nonnull) DirectoryService *directoryService;

// if not nil, scroll to the index path of the cell with the transfer key
@property(nonatomic, strong, nullable) NSString *transferKeyToScrollTo;

- (IBAction)showActions:(id _Nonnull)sender;

#pragma mark - FilePreviewControllerDelegate

@property(nullable, nonatomic, strong) QLPreviewController * previewController;

@end
