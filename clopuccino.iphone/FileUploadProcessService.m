#import "FileUploadProcessService.h"
#import "FileUploadViewController.h"
#import "FileUploadSummaryViewController.h"

@implementation FileUploadProcessService {
}

static FileUploadProcessService *defaultService = nil;

+ (instancetype)defaultService {
    static dispatch_once_t defaultFileUploadProcessServiceToken;
    dispatch_once(&defaultFileUploadProcessServiceToken, ^{
        defaultService = [[FileUploadProcessService alloc] init];

        defaultService.selectedAssetIdentifiers = [NSMutableArray array];
        defaultService.downloadedFiles = [NSMutableArray array];
    });

    return defaultService;
}

- (void)pushToUploadSummaryViewControllerFromViewController:(UIViewController * _Nonnull)viewController {
    FileUploadSummaryViewController *fileUploadSummaryViewController = [Utility instantiateViewControllerWithIdentifier:@"FileUploadSummary"];

    dispatch_async(dispatch_get_main_queue(), ^{
        [viewController.navigationController pushViewController:fileUploadSummaryViewController animated:YES];
    });
}

- (void)reset {
    self.fromViewController = nil;

    if (self.selectedAssetIdentifiers) {
        [self.selectedAssetIdentifiers removeAllObjects];
    }

    if (self.downloadedFiles) {
        [self.downloadedFiles removeAllObjects];
    }
}

- (void)updateBadgeBarButtonItem:(BBBadgeBarButtonItem * __nonnull)badgeBarButtonItem {
    NSUInteger count = [self.selectedAssetIdentifiers count] + [self.downloadedFiles count];

    badgeBarButtonItem.badgeValue = [NSString stringWithFormat:@"%ld", (unsigned long)count];

    badgeBarButtonItem.shouldHideBadgeAtZero = YES;

    [badgeBarButtonItem setEnabled:(count > 0)];
}

- (NSUInteger)totalSelectedCount {
    return [self.selectedAssetIdentifiers count] + [self.downloadedFiles count];
}

- (nullable FileTransferWithoutManaged *)findFromDownloadedFilesWithTransferKey:(NSString *_Nonnull)transferKey {
    FileTransferWithoutManaged *found;

    if (self.downloadedFiles && [self.downloadedFiles count] > 0) {
        for (FileTransferWithoutManaged *fileTransferWithoutManaged in self.downloadedFiles) {
            if ([transferKey isEqualToString:fileTransferWithoutManaged.transferKey]) {
                found = [fileTransferWithoutManaged copy];

                break;
            }
        }
    }

    return found;
}

- (void)removeDownloadedFileWithTransferKey:(NSString *_Nonnull)transferKey {
    if (self.downloadedFiles && [self.downloadedFiles count] > 0) {
        for (NSUInteger index = 0; index < [self.downloadedFiles count]; index++) {
            FileTransferWithoutManaged *currentFileTransferWithoutManaged = self.downloadedFiles[index];

            if ([transferKey isEqualToString:currentFileTransferWithoutManaged.transferKey]) {
                [self.downloadedFiles removeObjectAtIndex:index];

                break;
            }
        }
    }
}

@end