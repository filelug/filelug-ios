#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@class NSFetchedResultsController;
@class FileDownloadProcessService;

@interface ChooseMultipleFileViewController : UITableViewController <NSFetchedResultsControllerDelegate, ProcessableViewController>

@property(nonatomic, strong) NSString *parentPath;

@property(nonatomic, strong) UIViewController *triggeredViewController;

@property(nonatomic, strong) HierarchicalModelDao *hierarchicalModelDao;

@property(nonatomic, strong) NSFetchedResultsController *fetchedResultsController;

@end
