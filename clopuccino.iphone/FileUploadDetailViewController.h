#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import "FilePreviewControllerDelegate.h"

@interface FileUploadDetailViewController : UITableViewController <NSFetchedResultsControllerDelegate, FilePreviewControllerDelegate>

// in order to refresh the upload status, pass the transfer key from 'fromViewController', instead of AssetFileWithoutManged
@property(nonnull, nonatomic, strong) NSString *transferKey;

@property(nonnull, nonatomic, strong) UIViewController *fromViewController;

@end
