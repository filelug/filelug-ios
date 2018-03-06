#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@class DocumentPickerViewController;

@interface DPCenterViewController : UITableViewController <NSFetchedResultsControllerDelegate, ProcessableViewController>

@property(nonatomic, strong) NSString *parentPath;

@property(nonatomic, strong) DocumentPickerViewController *documentPickerExtensionViewController;

@end
