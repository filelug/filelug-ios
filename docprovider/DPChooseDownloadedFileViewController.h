#import <UIKit/UIKit.h>

@class DocumentPickerViewController;

@interface DPChooseDownloadedFileViewController : UITableViewController <NSFetchedResultsControllerDelegate, UIDocumentInteractionControllerDelegate, ProcessableViewController>

@property(nonatomic, strong) DocumentPickerViewController *documentPickerExtensionViewController;

@end
