#import <UIKit/UIKit.h>

@interface ConnectToComputerInstallationViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property(nonatomic, weak) IBOutlet UITableView *tableView;

@property(nonatomic, weak) IBOutlet UIBarButtonItem *currentStepButtonItem;

@end
