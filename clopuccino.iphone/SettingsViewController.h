#import <UIKit/UIKit.h>

@interface SettingsViewController : UITableViewController <UITableViewDelegate, UITableViewDataSource, ProcessableViewController>

- (void)selectLoginWithAnotherAccountAndInvokeDelegateMethod;

@end
