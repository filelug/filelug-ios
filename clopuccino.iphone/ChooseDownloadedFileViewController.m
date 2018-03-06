#import "ChooseDownloadedFileViewController.h"
#import "AppService.h"
#import "FilelugUtility.h"
#import "FileInfoViewController.h"
#import "FilePreviewController.h"
#import "FileUploadProcessService.h"
#import "UIButton+UploadBadgeBarButton.h"
#import "AppDelegate.h"

@interface ChooseDownloadedFileViewController ()

@property(nonatomic, strong) FileTransferDao *fileTransferDao;

@property(nonatomic, strong) HierarchicalModelDao *hierarchicalModelDao;

@property(nonatomic, strong) NSFetchedResultsController *fetchedResultsController;

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) AppService *appService;

// Keep the reference to prevent error like: 'UIDocumentInteractionController has gone away prematurely!'
@property(nonatomic, strong) id keptController;

@property(nonatomic, strong) DirectoryService *directoryService;

@property(nonatomic, strong) FileDownloadGroupDao *fileDownloadGroupDao;

//@property(nonatomic, strong) FileTransferService *fileTransferService;

@property(nonatomic, strong) UIButton *uploadBadgeBarButton;

@property(nonatomic, strong) BBBadgeBarButtonItem *doneButtonItem;

@property(nonatomic, strong) FileUploadProcessService *uploadProcessService;

@end

@implementation ChooseDownloadedFileViewController

@synthesize processing;

@synthesize progressView;

- (void)viewDidLoad {
    [super viewDidLoad];

    self.processing = @NO;

    [Utility viewController:self useNavigationLargeTitles:YES];

    _preferredContentSizeCategoryService = [[PreferredContentSizeCategoryService alloc] init];

    _uploadProcessService = [[FilelugUtility applicationDelegate] fileUploadProcessService];

    // Change the back button for the next view controller
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Back", @"") style:UIBarButtonItemStylePlain target:nil action:nil];

    [self.navigationItem setBackBarButtonItem:backButton];

    // refresh control
    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];

    [refresh setAttributedTitle:[[NSAttributedString alloc] initWithString:NSLocalizedString(@"Pull to refresh", @"")]];

    self.refreshControl = refresh;

    // upload badge

    _uploadBadgeBarButton = [UIButton uploadBadgeBarButton];

    BBBadgeBarButtonItem *badgeBarButtonItem = [[BBBadgeBarButtonItem alloc] initWithUploadBadgeBarButton:_uploadBadgeBarButton];

    self.doneButtonItem = badgeBarButtonItem;

    self.navigationItem.rightBarButtonItem = self.doneButtonItem;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // always update badge and table no matter if go back or not
    [self.uploadProcessService updateBadgeBarButtonItem:self.doneButtonItem];

    NSError *fetchError;
    [self.fileTransferDao fetchedResultsController:self.fetchedResultsController performFetch:&fetchError];

    if (fetchError) {
        NSLog(@"Error on perform fetch reuslts contraller\n%@", fetchError);
    }

    // adding observers

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangePreferredContentSize:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];

    [self.uploadBadgeBarButton addTarget:self action:@selector(doneSelection:) forControlEvents:UIControlEventTouchUpInside];

    [self addObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];

    [self.refreshControl addTarget:self action:@selector(reloadDownloadFiles:) forControlEvents:UIControlEventValueChanged];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self reloadDownloadFilesWithCompletionHandler:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    // removing observers

    [self.refreshControl removeTarget:self action:@selector(reloadDownloadFiles:) forControlEvents:UIControlEventValueChanged];

    [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) context:NULL];

    [self.uploadBadgeBarButton removeTarget:self action:@selector(doneSelection:) forControlEvents:UIControlEventTouchUpInside];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    if (self.keptController) {
        self.keptController = nil;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (FileTransferDao *)fileTransferDao {
    if (!_fileTransferDao) {
        _fileTransferDao = [[FileTransferDao alloc] init];
    }

    return _fileTransferDao;
}

- (HierarchicalModelDao *)hierarchicalModelDao {
    if (!_hierarchicalModelDao) {
        _hierarchicalModelDao = [[HierarchicalModelDao alloc] init];
    }

    return _hierarchicalModelDao;
}

- (AuthService *)authService {
    if (!_authService) {
        _authService = [[AuthService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];
    }

    return _authService;
}

- (AppService *)appService {
    if (!_appService) {
        _appService = [[AppService alloc] init];
    }

    return _appService;
}

- (DirectoryService *)directoryService {
    if (!_directoryService) {
        _directoryService = [[DirectoryService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];
    }

    return _directoryService;
}

- (FileDownloadGroupDao *)fileDownloadGroupDao {
    if (!_fileDownloadGroupDao) {
        _fileDownloadGroupDao = [[FileDownloadGroupDao alloc] init];
    }

    return _fileDownloadGroupDao;
}

- (NSFetchedResultsController *)fetchedResultsController {
    if (!_fetchedResultsController) {
        _fetchedResultsController = [self.fileTransferDao createFileDownloadFetchedResultsControllerForAllUsersWithDelegate:self];
    }

    return _fetchedResultsController;
}

- (void)didChangePreferredContentSize:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (void)doneSelection:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.uploadProcessService pushToUploadSummaryViewControllerFromViewController:self];
    });
}

#pragma mark - NSKeyValueObserving

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(processing))]) {
        NSNumber *newValue = change[NSKeyValueChangeNewKey];
        NSNumber *oldValue = change[NSKeyValueChangeOldKey];

        if (![newValue isEqualToNumber:oldValue]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([newValue boolValue]) {
                    [self.tableView setScrollEnabled:NO];

                    if (!self.progressView) {
                        // Get the current tab name from MenuTabViewController
                        NSString *selectedTabName = [FilelugUtility selectedTabName];

                        MBProgressHUD *progressHUD = [Utility prepareProgressViewWithSuperview:self.view inTabWithTabName:selectedTabName refreshControl:self.refreshControl];

                        self.progressView = progressHUD;
                    } else {
                        [self.progressView show:YES];
                    }
                } else {
                    [self.tableView setScrollEnabled:YES];

                    if (self.progressView) {
                        [self.progressView hide:YES];
                    }
                }
            });
        }
    }
}

- (void)reloadDownloadFiles:(id)sender {
    [self reloadDownloadFilesWithCompletionHandler:nil];
}

// The completionHandler runs under main queue, so use the background queue if needed.
- (void)reloadDownloadFilesWithCompletionHandler:(void (^)(void))completionHandler {
    NSError *fetchError;
    [self.fileTransferDao fetchedResultsController:self.fetchedResultsController performFetch:&fetchError];

    if (fetchError) {
        NSLog(@"Error on perform fetch reuslts contraller\n%@", fetchError);
    }

    if (self.refreshControl) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.refreshControl endRefreshing];
        });
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];

        if (completionHandler) {
            completionHandler();
        }
    });
}

#pragma mark - UITableViewDelegate

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    return [self tableView:tableView beforeSelectRowAtIndexPath:indexPath];
}

- (NSIndexPath *)tableView:(UITableView *)tableView willDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    return [self tableView:tableView beforeSelectRowAtIndexPath:indexPath];
}

- (NSIndexPath *)tableView:(UITableView *)tableView beforeSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];

    FileTransferWithoutManaged *fileTransferWithoutManaged = [self.fileTransferDao fetchedResultsController:self.fetchedResultsController objectAtIndexPath:indexPath];

    // get absolute path of the downloaded file
    NSString *transferKey = fileTransferWithoutManaged.transferKey;

    FileTransferWithoutManaged *existingFileTransferWithoutManaged = [self.uploadProcessService findFromDownloadedFilesWithTransferKey:transferKey];

    if (!existingFileTransferWithoutManaged) {
        // select it

        [self.uploadProcessService.downloadedFiles addObject:[fileTransferWithoutManaged copy]];

        if (cell) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [cell setAccessoryType:UITableViewCellAccessoryCheckmark];

                // update badge

                [self.uploadProcessService updateBadgeBarButtonItem:self.doneButtonItem];
            });
        }
    } else {
        // deselect it

        [self.uploadProcessService removeDownloadedFileWithTransferKey:transferKey];

        dispatch_async(dispatch_get_main_queue(), ^{
            [cell setAccessoryType:UITableViewCellAccessoryNone];

            // update badge

            [self.uploadProcessService updateBadgeBarButtonItem:self.doneButtonItem];
        });
    }

    return indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // did nothing
}

- (void)doPreviewFileWithFileTransferKey:(NSString *)transferKey {
    FileTransferWithoutManaged *fileTransferWithoutManaged = [self.fileTransferDao findFileTransferForTransferKey:transferKey error:NULL];

    if (fileTransferWithoutManaged) {
        // delay for 500 ms, so the system gets time to save it, or sometimes it shows an empty content.

        NSString *userComputerId = fileTransferWithoutManaged.userComputerId;
        NSString *localRelPath = fileTransferWithoutManaged.localPath;
        NSString *fileAbsolutePath = [DirectoryService absoluteFilePathFromLocalPath:localRelPath userComputerId:userComputerId];

        FilePreviewController *filePreviewController = [[FilePreviewController alloc] init];

        filePreviewController.fileAbsolutePath = fileAbsolutePath;
        filePreviewController.fromViewController = self;
        filePreviewController.delegate = self;

        [filePreviewController preview];

        self.keptController = filePreviewController;
    } else {
        [Utility viewController:self alertWithMessageTitle:@"" messageBody:NSLocalizedString(@"File not found. Try again later.", @"") actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
    }
}

- (void)navigateToFileInfoViewControllerWithFileTransferKey:(NSString *)transferKey {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        FileTransferWithoutManaged *fileTransferWithoutManaged = [self.fileTransferDao findFileTransferForTransferKey:transferKey error:NULL];

        FileInfoViewController *fileInfoViewController = [Utility instantiateViewControllerWithIdentifier:@"FileInfo"];

        fileInfoViewController.filePath = fileTransferWithoutManaged.serverPath;
        fileInfoViewController.realFilePath = fileTransferWithoutManaged.realServerPath;
        fileInfoViewController.filename = [fileTransferWithoutManaged.localPath lastPathComponent];

        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSString *separator = [userDefaults stringForKey:USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR];

        if (separator) {
            fileInfoViewController.fileParent = [DirectoryService parentPathFromServerFilePath:fileTransferWithoutManaged.serverPath separator:separator];
        }

        fileInfoViewController.fileSize = fileTransferWithoutManaged.displaySize;
        fileInfoViewController.fileMimetype = [Utility contentTypeFromFilenameExtension:[fileTransferWithoutManaged.realServerPath pathExtension]];
        fileInfoViewController.fileLastModifiedDate = fileTransferWithoutManaged.lastModified;

        NSNumber *hiddenNumber = fileTransferWithoutManaged.hidden;

        if (hiddenNumber && [hiddenNumber boolValue]) {
            fileInfoViewController.fileHidden = NSLocalizedString(@"Hidden YES", @"");
        } else {
            fileInfoViewController.fileHidden = NSLocalizedString(@"Hidden NO", @"");
        }

        fileInfoViewController.fromViewController = self;

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.navigationController pushViewController:fileInfoViewController animated:YES];
        });
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    NSInteger count;

    // To prevent app terminated due to uncaught exception 'NSInternalInconsistencyException':
    // An exception was caught from the delegate of NSFetchedResultsController during a call to -controllerDidChangeContent: ...
    @try {
        count = [self.fileTransferDao numberOfSectionsForFetchedResultsController:self.fetchedResultsController];
    } @catch (NSException *e) {
        [self handleFetchedResultsControllerErrorWithMethodName:@"numberOfSectionsInTableView:" exception:e];
    }

    return count;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return TABLE_VIEW_CELL_ROW_HEIGHT_FOR_MEDIUM_CONTENT_SIZE_CATEGORY;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat height;

    if ([self.preferredContentSizeCategoryService isXXLargeContentSizeCategory]) {
        height = TABLE_VIEW_CELL_ROW_HEIGHT_FOR_XX_LARGE_CONTENT_SIZE_CATEGORY;
    } else if ([self.preferredContentSizeCategoryService isLargeContentSizeCategory]) {
        height = TABLE_VIEW_CELL_ROW_HEIGHT_FOR_LARGE_CONTENT_SIZE_CATEGORY;
    } else if ([self.preferredContentSizeCategoryService isMediumContentSizeCategory]) {
        height = TABLE_VIEW_CELL_ROW_HEIGHT_FOR_MEDIUM_CONTENT_SIZE_CATEGORY;
    } else {
        height = TABLE_VIEW_CELL_ROW_HEIGHT_FOR_SMALL_CONTENT_SIZE_CATEGORY;
    }

    return height;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *title;

    // To prevent app terminated due to uncaught exception 'NSInternalInconsistencyException':
    // An exception was caught from the delegate of NSFetchedResultsController during a call to -controllerDidChangeContent: ...
    @try {
        title = [self.fileTransferDao fetchedResultsController:self.fetchedResultsController titleForHeaderInSection:section includingComputerName:YES];
    } @catch (NSException *e) {
        [self handleFetchedResultsControllerErrorWithMethodName:@"tableView:titleForHeaderInSection:" exception:e];
    }

    return title;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger count;

    // To prevent app terminated due to uncaught exception 'NSInternalInconsistencyException':
    // An exception was caught from the delegate of NSFetchedResultsController during a call to -controllerDidChangeContent: ...
    @try {
        count = [self.fileTransferDao fetchedResultsController:self.fetchedResultsController numberOfRowsInSection:section];
    } @catch (NSException *e) {
        [self handleFetchedResultsControllerErrorWithMethodName:@"tableView:numberOfRowsInSection:" exception:e];
    }

    return count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"DownloadedFileCell";
    UITableViewCell *cell;

    // To prevent app terminated due to uncaught exception 'NSInternalInconsistencyException':
    // An exception was caught from the delegate of NSFetchedResultsController during a call to -controllerDidChangeContent: ...
    @try {
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];

        // configure the preferred font

        cell.imageView.image = [UIImage imageNamed:@"ic_file"];

        cell.accessoryType = UITableViewCellAccessoryNone;

        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        cell.textLabel.textColor = [UIColor darkTextColor];
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.adjustsFontSizeToFitWidth = NO;
        cell.textLabel.lineBreakMode = NSLineBreakByCharWrapping;
        cell.textLabel.textAlignment = NSTextAlignmentNatural;

        cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
        cell.detailTextLabel.numberOfLines = 1;
        cell.detailTextLabel.adjustsFontSizeToFitWidth = NO;
        cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        cell.detailTextLabel.textAlignment = NSTextAlignmentNatural;

        // Configure the cell
        [self configureCell:cell atIndexPath:indexPath];
    } @catch (NSException *e) {
        [self handleFetchedResultsControllerErrorWithMethodName:@"tableView:cellForRowAtIndexPath:" exception:e];
    }

    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
    // To prevent app terminated due to uncaught exception 'NSInternalInconsistencyException':
    // An exception was caught from the delegate of NSFetchedResultsController during a call to -controllerDidChangeContent: ...
    @try {
        switch (type) {
            case NSFetchedResultsChangeInsert:

                [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];

                break;
            case NSFetchedResultsChangeDelete:

                [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];

                break;
            case NSFetchedResultsChangeMove:
                NSLog(@"No reaction to NSFetchedResultsChangeMove");

                break;
            case NSFetchedResultsChangeUpdate:
                NSLog(@"No reaction to NSFetchedResultsChangeUpdate");

                break;
        }
    } @catch (NSException *e) {
        [self handleFetchedResultsControllerErrorWithMethodName:@"controller:didChangeSection:atIndex:forChangeType:" exception:e];
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    // To prevent app terminated due to uncaught exception 'NSInternalInconsistencyException':
    // An exception was caught from the delegate of NSFetchedResultsController during a call to -controllerDidChangeContent: ...
    @try {
        switch (type) {
            case NSFetchedResultsChangeInsert:

                [self.tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];

                break;
            case NSFetchedResultsChangeDelete:

                [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];

                break;
            case NSFetchedResultsChangeUpdate:

                [self configureCell:[self.tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];

                break;
            case NSFetchedResultsChangeMove:

                [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];

                [self.tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];

                break;
        }
    } @catch (NSException *e) {
        [self handleFetchedResultsControllerErrorWithMethodName:@"controller:didChangeObject:atIndexPath:forChangeType:newIndexPath:" exception:e];
    }

}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView endUpdates];
}

- (BOOL)isLoading {
    return (self.processing && [self.processing boolValue]);
}

- (void)stopLoading {
    self.processing = @NO;
}

// Customize the appearance of table view cells.
- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    FileTransferWithoutManaged *fileTransferWithoutManaged = [self.fileTransferDao fetchedResultsController:self.fetchedResultsController objectAtIndexPath:indexPath];

    if (fileTransferWithoutManaged) {
        cell.textLabel.text = [fileTransferWithoutManaged.localPath lastPathComponent];
        cell.imageView.image = [DirectoryService imageForLocalFilePath:fileTransferWithoutManaged.localPath isDirectory:NO];

        NSString *displaySize = fileTransferWithoutManaged.displaySize;

        NSString *lastModified;

        NSString *lastModifiedFromServer = fileTransferWithoutManaged.lastModified;

        if (lastModifiedFromServer) {
            NSDate *lastModifiedDate = [Utility dateFromString:lastModifiedFromServer format:DATE_FORMAT_FOR_SERVER];

            if (lastModifiedDate) {
                lastModified = [Utility dateStringFromDate:lastModifiedDate];
            }
        }

        NSString *detailLabelText;

        if (lastModified) {
            detailLabelText = [NSString stringWithFormat:@"%@, %@", displaySize, lastModified];
        } else {
            detailLabelText = [NSString stringWithFormat:@"%@", displaySize];
        }

        NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:detailLabelText];
        [attributedString setText:displaySize withColor:[UIColor darkGrayColor]];
        [attributedString setText:lastModified withColor:[UIColor lightGrayColor]];

        [cell.detailTextLabel setAttributedText:attributedString];

        FileTransferWithoutManaged *selectedFileTransferWithoutManaged = [self.uploadProcessService findFromDownloadedFilesWithTransferKey:fileTransferWithoutManaged.transferKey];

        if (selectedFileTransferWithoutManaged) {
            // already selected
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            // not selected
            cell.accessoryType = UITableViewCellAccessoryNone;
        }

        // To resolve the width of the detail text not correctly updated
        [cell layoutSubviews];
    }
}

- (void)handleFetchedResultsControllerErrorWithMethodName:(NSString *)methodNameForLogging exception:(NSException *)e {
    NSLog(@"Error on %@.\n%@", methodNameForLogging, e);

    [self reloadDownloadFilesWithCompletionHandler:nil];
}

#pragma mark - UIDocumentInteractionControllerDelegate

- (UIViewController *)documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *)controller {
    return self;
}

- (UIView *)documentInteractionControllerViewForPreview:(UIDocumentInteractionController *)controller {
    return self.view;
}

//#pragma mark - Actions To Notifications From FileTransferService
//
//- (void)onFileDownloadDidResumeNotification:(NSNotification *)notification {
//    double delayInSeconds = 1.0;
//    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));
//    dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
//        self.processing = @NO;
//    });
//}
//
//- (void)onFileDownloadDidCompleteNotification:(NSNotification *)notification {
//    NSDictionary *userInfo = notification.userInfo;
//
//    if (userInfo) {
//        NSString *fileTransferStatus = userInfo[NOTIFICATION_KEY_DOWNLOAD_STATUS];
//        NSString *transferKey = userInfo[NOTIFICATION_KEY_DOWNLOAD_TRANSFER_KEY];
//        NSString *localPath = userInfo[NOTIFICATION_KEY_DOWNLOAD_FILE_LOCAL_PATH];
//        NSString *realFilename = userInfo[NOTIFICATION_KEY_DOWNLOAD_REAL_FILENAME];
//
//        if (fileTransferStatus && transferKey && localPath && realFilename) {
//            FilelugFileDownloadServiceDelegate *filelugFileDownloadServiceDelegate = [[FilelugFileDownloadServiceDelegate alloc] init];
//
//            [filelugFileDownloadServiceDelegate onDidCompleteWithFileTransferStatus:fileTransferStatus transferKey:transferKey localPath:localPath filename:realFilename];
//        }
//    }
//}

@end
