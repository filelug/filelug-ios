@interface SHChooseFileViewController : UITableViewController <NSFetchedResultsControllerDelegate, ProcessableViewController>

@property(nonatomic, strong) NSString *parentPath;

@property(nonatomic, strong) UIViewController *triggeredViewController;

@property(nonatomic, strong) HierarchicalModelDao *hierarchicalModelDao;

@property(nonatomic, strong) NSFetchedResultsController *fetchedResultsController;

- (void)addDirectory:(UITapGestureRecognizer *)sender;

@end
