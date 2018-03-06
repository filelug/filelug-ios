@interface SHRootDirectoryViewController : UITableViewController <ProcessableViewController>

@property (nonatomic, strong) UIViewController *fromViewController;

- (void)addDirectory:(UITapGestureRecognizer *)sender;

@end
