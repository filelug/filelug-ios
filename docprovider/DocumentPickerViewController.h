#import <UIKit/UIKit.h>

@interface DocumentPickerViewController : UIDocumentPickerExtensionViewController <UITableViewDataSource, UITableViewDelegate, ProcessableViewController>

@property(nonatomic, weak) IBOutlet UITableView *tableView;

@end
