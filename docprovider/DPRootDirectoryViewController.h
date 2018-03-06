#import <UIKit/UIKit.h>

@class DocumentPickerViewController;

@interface DPRootDirectoryViewController : UITableViewController <ProcessableViewController>

@property(nonatomic, strong) DocumentPickerViewController *documentPickerExtensionViewController;

@end
