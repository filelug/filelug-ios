#import "DPChooseDownloadedFileViewController.h"
#import "FilelugDocProviderUtility.h"
#import "DocumentPickerViewController.h"

@interface DPChooseDownloadedFileViewController ()

@property(nonatomic, strong) FileTransferDao *fileTransferDao;

@property(nonatomic, strong) HierarchicalModelDao *hierarchicalModelDao;

@property(nonatomic, strong) NSFetchedResultsController *fetchedResultsController;

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) DirectoryService *directoryService;

@property(nonatomic, strong) FileDownloadGroupDao *fileDownloadGroupDao;

@end

@implementation DPChooseDownloadedFileViewController

@synthesize processing;

@synthesize progressView;

- (void)viewDidLoad {
    [super viewDidLoad];

    self.processing = @NO;

    [Utility viewController:self useNavigationLargeTitles:YES];

    _preferredContentSizeCategoryService = [[PreferredContentSizeCategoryService alloc] init];

    // Change the back button for the next view controller
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Back", @"") style:UIBarButtonItemStylePlain target:nil action:nil];

    [self.navigationItem setBackBarButtonItem:backButton];

    // refresh control
    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];

    [refresh setAttributedTitle:[[NSAttributedString alloc] initWithString:NSLocalizedString(@"Pull to refresh", @"")]];

    self.refreshControl = refresh;

    [self.navigationItem setTitle:NSLocalizedString(@"Choose File", @"")];

    // Change the back button for the next view controller
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel", @"") style:UIBarButtonItemStylePlain target:self action:@selector(didCanceled:)];

    [self.navigationItem setRightBarButtonItem:cancelButton];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

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

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];
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
                        MBProgressHUD *progressHUD = [Utility prepareProgressViewWithSuperview:self.view inTabWithTabName:nil refreshControl:self.refreshControl];

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

- (void)didCanceled:(id)sender {
    if (self.documentPickerExtensionViewController) {
        [self.documentPickerExtensionViewController dismissGrantingAccessToURL:nil];
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    FileTransferWithoutManaged *fileTransferWithoutManaged = [self.fileTransferDao fetchedResultsController:self.fetchedResultsController objectAtIndexPath:indexPath];

    if (fileTransferWithoutManaged && [fileTransferWithoutManaged.status isEqualToString:FILE_TRANSFER_STATUS_SUCCESS]) {
        NSString *localPath = fileTransferWithoutManaged.localPath;

        NSString *userComputerId = fileTransferWithoutManaged.userComputerId;

        NSURL *documentStorageURL = self.documentPickerExtensionViewController.documentStorageURL;

        NSString *docProviderFilePath = [FilelugDocProviderUtility docProviderFilePathWithDocumentStorageURL:documentStorageURL
                                                                                              userComputerId:userComputerId
                                                                                     downloadedFileLocalPath:localPath];

        // use existing file in local path and copy to document storage url

        // create intermediate directory of the target if not exists
        // If directory exists, sometimes error occurred even if intermediateDirectories set to YES (maybe it is because the permission owner is different)
        // So we have to test it first anyway.

        NSString *directoryOfTargetFilePath = [docProviderFilePath stringByDeletingLastPathComponent];

        NSFileManager *fileManager = [NSFileManager defaultManager];

        BOOL isDirectory;
        BOOL pathExists = [fileManager fileExistsAtPath:directoryOfTargetFilePath isDirectory:&isDirectory];

        if (!pathExists || !isDirectory) {
            NSError *createError;
            [fileManager createDirectoryAtPath:directoryOfTargetFilePath withIntermediateDirectories:YES attributes:nil error:&createError];

            if (createError) {
                NSLog(@"Error on createing directory: '%@'\n%@", directoryOfTargetFilePath, [createError userInfo]);
            }
        }

        // convert localPath to the absolute path,

        NSString *absolutePath = [DirectoryService absoluteFilePathFromLocalPath:localPath userComputerId:userComputerId];

        NSError *copyError;
        [fileManager copyItemAtPath:absolutePath toPath:docProviderFilePath error:&copyError];

        if (copyError) {
            NSLog(@"Error on copying file: '%@' to '%@'\n%@", absolutePath, docProviderFilePath, [copyError userInfo]);
        }

        NSURL *targetFileURL = [NSURL fileURLWithPath:docProviderFilePath];

        [self.documentPickerExtensionViewController dismissGrantingAccessToURL:targetFileURL];
    } else {
        NSString *localFilename = [fileTransferWithoutManaged.localPath lastPathComponent];

        NSString *message = [NSString stringWithFormat:NSLocalizedString(@"File %@ not exists or not finished downloading", @""), localFilename];
        
        [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"Refresh", @"") delayInSeconds:0 actionHandler:^(UIAlertAction *action) {
            [self reloadDownloadFiles:nil];
        }];
    }
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
        cell.textLabel.textColor = [UIColor blackColor];
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
        NSString *localFilename = [fileTransferWithoutManaged.localPath lastPathComponent];

        cell.textLabel.text = localFilename;
        cell.textLabel.textColor = [UIColor blackColor];

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
        [attributedString setText:displaySize withColor:[UIColor blackColor]];
        [attributedString setText:lastModified withColor:[UIColor lightGrayColor]];

        [cell.detailTextLabel setAttributedText:attributedString];

        // disabled cell if the file can't open by the invoking app

        BOOL disabledCell;

        if (self.documentPickerExtensionViewController) {
            NSArray *validTypes = self.documentPickerExtensionViewController.validTypes;

            disabledCell = [FilelugDocProviderUtility filename:localFilename conformToValidTypes:validTypes];
        } else {
            disabledCell = NO;
        }

        cell.userInteractionEnabled = !disabledCell;

        // colors for text label and detail text label are based on value of disabledCell

        if (disabledCell) {
            cell.textLabel.textColor = [UIColor lightGrayColor];
            cell.detailTextLabel.textColor = [UIColor lightGrayColor];
        }

        // To resolve the width of the detail text not correctly updated
        [cell layoutSubviews];
    }
}

- (void)handleFetchedResultsControllerErrorWithMethodName:(NSString *)methodNameForLogging exception:(NSException *)e {
    NSLog(@"Error on %@.\n%@", methodNameForLogging, e);

    [self reloadDownloadFilesWithCompletionHandler:nil];
}

@end
