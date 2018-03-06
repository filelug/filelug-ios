#import <UIKit/UIKit.h>

@interface ConnectToComputerStartupViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property(nonatomic, weak) IBOutlet UITableView *tableView;

@property(nonatomic, weak) IBOutlet UIBarButtonItem *currentStepButtonItem;


@end
