#import <UIKit/UIKit.h>

@interface ManageComputerViewController : UITableViewController <UITableViewDelegate, UITableViewDataSource, ProcessableViewController>

#pragma mark - UploadDescriptionDataSource

@property(nonatomic, strong) UploadDescriptionService *uploadDescriptionService;

- (BOOL)needPersistIfChanged;

@end
