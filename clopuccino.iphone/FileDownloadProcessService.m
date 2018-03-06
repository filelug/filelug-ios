#import "FileDownloadProcessService.h"
#import "DownloadFileViewController.h"
#import "FileDownloadSummaryViewController.h"

@interface FileDownloadProcessService()

@property (nonatomic, strong) RecentDirectoryService *recentDirectoryService;

@end

@implementation FileDownloadProcessService

static FileDownloadProcessService *defaultService = nil;

+ (instancetype)defaultService {
    static dispatch_once_t defaultFileDownloadProcessServiceToken;
    dispatch_once(&defaultFileDownloadProcessServiceToken, ^{
        defaultService = [[FileDownloadProcessService alloc] init];

        defaultService.selectedHierarchicalModels = [NSMutableArray array];
    });

    return defaultService;
}

- (RecentDirectoryService *)recentDirectoryService {
    if (!_recentDirectoryService) {
        _recentDirectoryService = [[RecentDirectoryService alloc] init];
    }

    return _recentDirectoryService;
}

- (void)pushToDownloadSummaryViewControllerFromViewController:(UIViewController * _Nonnull)viewController {
    // create/update recent directories before push to summary view controller

    if (self.selectedHierarchicalModels && [self.selectedHierarchicalModels count] > 0) {
        @autoreleasepool {
            NSArray *hierarchicalModels = [self.selectedHierarchicalModels copy];

            for (HierarchicalModelWithoutManaged *hierarchicalModel in hierarchicalModels) {
                NSString *directoryPath = hierarchicalModel.parent;
                NSString *directoryRealPath = hierarchicalModel.realParent;

                [self.recentDirectoryService createOrUpdateRecentDirectoryWithDirectoryPath:directoryPath directoryRealPath:directoryRealPath completionHandler:nil];
            }
        }
    }

    // push to summary view controller

    FileDownloadSummaryViewController *fileDownloadSummaryViewController = [Utility instantiateViewControllerWithIdentifier:@"FileDownloadSummary"];

    dispatch_async(dispatch_get_main_queue(), ^{
        [viewController.navigationController pushViewController:fileDownloadSummaryViewController animated:YES];
    });
}

- (void)reset {
    self.fromViewController = nil;

    if (self.selectedHierarchicalModels) {
        [self.selectedHierarchicalModels removeAllObjects];
    }
}

- (void)updateBadgeBarButtonItem:(BBBadgeBarButtonItem * __nonnull)badgeBarButtonItem {
    NSUInteger count = [self.selectedHierarchicalModels count];

    badgeBarButtonItem.badgeValue = [NSString stringWithFormat:@"%ld", (unsigned long)count];

    badgeBarButtonItem.shouldHideBadgeAtZero = YES;

    [badgeBarButtonItem setEnabled:(count > 0)];
}

@end
