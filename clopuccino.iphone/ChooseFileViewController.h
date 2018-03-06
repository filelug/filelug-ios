#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@class NSFetchedResultsController;

@interface ChooseFileViewController : UITableViewController <NSFetchedResultsControllerDelegate, ProcessableViewController>

@property(nonatomic, strong) NSString *parentPath;

@property(nonatomic, strong) UIViewController *triggeredViewController;

@property(nonatomic, strong) HierarchicalModelDao *hierarchicalModelDao;

@property(nonatomic, strong) NSFetchedResultsController *fetchedResultsController;

// show only the directory (ie, no files) for this view.
@property(nonatomic, assign) BOOL directoryOnly;

- (void)addDirectory:(UITapGestureRecognizer *)sender;

@end
