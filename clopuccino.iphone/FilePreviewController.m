#import "FilePreviewController.h"
#import "FilePreviewControllerDelegate.h"

@implementation FilePreviewController {

}

- (void)preview {
    NSFileManager *fileManager = [NSFileManager defaultManager];

    BOOL isDirectory;
    BOOL pathExists = [fileManager fileExistsAtPath:self.fileAbsolutePath isDirectory:&isDirectory];
    
    if (pathExists && !isDirectory) { // not possible a directory
        
        // Must be starting with scheme:file://
        _previewItemURL = [NSURL fileURLWithPath:self.fileAbsolutePath];
        
        _previewItemTitle = [self.fileAbsolutePath lastPathComponent];
        
        QLPreviewController *previewController = [[QLPreviewController alloc] init];

        previewController.view.userInteractionEnabled = YES;

        previewController.dataSource = self;
        
        // hold it to prevent lose reference
        self.delegate.previewController = previewController;
        
        // hides tab bar
        [previewController setHidesBottomBarWhenPushed:YES];

        // disabled large titles
        [Utility viewController:previewController useNavigationLargeTitles:NO];
        
        if (self.fromViewController.navigationController) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.fromViewController.navigationController pushViewController:previewController animated:YES];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.fromViewController presentViewController:previewController animated:YES completion:nil];
            });
        }
    } else {
        [self showFailedToPreviewAlert];
    }
}

- (void)showFailedToPreviewAlert {
    [Utility viewController:self.fromViewController alertWithMessageTitle:@"" messageBody:NSLocalizedString(@"Can't preview this file.", @"") actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
}

#pragma mark - QLPreviewControllerDataSource

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller {
    return 1;
}

- (id <QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
    // Values of previewItemURL and previewItemTitle are specified in [self previewFileWithFileAbsolutePath:...]

    return self;
}

@end