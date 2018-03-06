#import <UIKit/UIKit.h>
#import "ScannerView.h"

@interface ConnectToComputerScanQRCodeViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, ScannerViewDelegate, ProcessableViewController>

@property(nonatomic, weak) IBOutlet UITableView *tableView;

@property(nonatomic, weak) IBOutlet UIBarButtonItem *currentStepButtonItem;

@end
