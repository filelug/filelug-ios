#import <UIKit/UIKit.h>

@interface ChooseSharingFileViewController : UITableViewController

// relative directory path of parent directories, exlcuding the root path of the sharing directory
@property(nonatomic, strong) NSString *parentRelPath;

@end
