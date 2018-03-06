#import <Foundation/Foundation.h>

@class DownloadFileViewController;

@interface FileDownloadProcessService : NSObject

// the staring view controll to initiate the upload process, type of DownloadFileViewController
@property(nullable, nonatomic, weak) DownloadFileViewController *fromViewController;

// elements of HierarchicalModelWithoutManaged
@property(nonnull, nonatomic, strong) NSMutableArray *selectedHierarchicalModels;

// Only one instance for one application
+ (instancetype __nonnull)defaultService;

// Go to FileDownloadSummaryViewController with necessary information
- (void)pushToDownloadSummaryViewControllerFromViewController:(UIViewController *__nonnull)viewController;

// Set fromViewController to nil, remove all objects to selectedHierarchicalModels
- (void)reset;

// Update BBBadgeBarButtonItem based on the total selected files.
// Usually executed in main queue to reflect the UI change of BBBadgeBarButtonItem
- (void)updateBadgeBarButtonItem:(BBBadgeBarButtonItem *_Nonnull)badgeBarButtonItem;

@end
