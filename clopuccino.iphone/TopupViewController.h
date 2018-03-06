#import <UIKit/UIKit.h>

@interface TopupViewController : UITableViewController <ProcessableViewController>

// e.g. 2048 MB (2147483648 bytes)
@property (nonatomic, weak) IBOutlet UILabel *capacityLabel;

@end
