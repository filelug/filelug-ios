#import <UIKit/UIKit.h>

@interface DownloadHistoryViewController : UITableViewController <ProcessableViewController>

- (void)search:(id)sender;

- (void)reloadData:(id)sender;

@end
