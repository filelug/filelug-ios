#import "FileUploadViewController.h"
#import "FileUploadDetailViewController.h"
#import "FilelugUtility.h"
#import "FileUploadProcessService.h"
#import "AppDelegate.h"
#import "FilelugFileUploadService.h"
#import "FilePreviewController.h"
#import "AssetsPreviewViewController.h"

@interface FileUploadViewController ()

@property(nonatomic, strong) AssetFileDao *assetFileDao;

@property(nonatomic, strong) NSFetchedResultsController *fetchedResultsController;

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

@property(nonatomic, strong) FilelugFileUploadService *fileUploadService;

@property(nonatomic, strong) FileTransferDao *fileTransferDao;

// Keep the reference to prevent error like: 'UIDocumentInteractionController/QLPreviewController has gone away prematurely!'
@property(nonatomic, strong) id keptController;

@property(nonatomic, strong) AuthService *authService;

@end

@implementation FileUploadViewController

@synthesize processing;

@synthesize progressView;

- (void)viewDidLoad {
    [super viewDidLoad];

    // action button
    self.processing = @NO;

    [Utility viewController:self useNavigationLargeTitles:YES];

    _preferredContentSizeCategoryService = [[PreferredContentSizeCategoryService alloc] init];

    // refresh control
    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    
    [refresh setAttributedTitle:[[NSAttributedString alloc] initWithString:NSLocalizedString(@"Pull to refresh", @"")]];

    self.refreshControl = refresh;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    NSError *fetchError;
    [self.assetFileDao fetchedResultsController:self.fetchedResultsController performFetch:&fetchError];

    if (fetchError) {
        NSLog(@"Error on perform asset file fetch results controller\n%@", fetchError);
    }

    // adding observers

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangePreferredContentSize:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onWillEnterForegroundNotification) name:UIApplicationWillEnterForegroundNotification object:nil];

    [self addObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];

    [self addObserver:self forKeyPath:NSStringFromSelector(@selector(transferKeyToScrollTo)) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];

    [self.refreshControl addTarget:self action:@selector(reloadUploadFilesAndConfirmUploads:) forControlEvents:UIControlEventValueChanged];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if ([self isMovingToParentViewController]) {
        // prompt permission request only when NOT back from other uploading page.

        // ask for only once for the lifetime of an application
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [FilelugUtility promptToAllowUsePhotosWithViewController:self];
        });
    }

    [self reloadUploadFilesWithCompletionHandler:^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSUserDefaults *userDefaults = [Utility groupUserDefaults];

            NSString *userComputerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

            [self reactValueChangedToUserComputerId:userComputerId];

            // confirm uploads
            [self confirmUploadsWithCompletionHandler:^{
                // scroll to the index path for the cell with the transfer key

                if (self.transferKeyToScrollTo) {
                    NSString *transferKeyCopy = [self.transferKeyToScrollTo copy];

                    self.transferKeyToScrollTo = nil;

                    [self scrollViewToCellWithTransferKey:transferKeyCopy];
                }
            }];
        });
    }];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    // removing observers

    [self.refreshControl removeTarget:self action:@selector(reloadUploadFilesAndConfirmUploads:) forControlEvents:UIControlEventValueChanged];

    [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(transferKeyToScrollTo)) context:NULL];

    [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) context:NULL];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];

    if (self.progressView) {
        self.progressView = nil;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (AssetFileDao *)assetFileDao {
    if (!_assetFileDao) {
        _assetFileDao = [[AssetFileDao alloc] init];
    }
    
    return _assetFileDao;
}

- (DirectoryService *)directoryService {
    if (!_directoryService) {
        _directoryService = [[DirectoryService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];
    }
    
    return _directoryService;
}

- (FilelugFileUploadService *)fileUploadService {
    if (!_fileUploadService) {
        _fileUploadService = [[FilelugFileUploadService alloc] init];
    }

    return _fileUploadService;
}

- (FileTransferDao *)fileTransferDao {
    if (!_fileTransferDao) {
        _fileTransferDao = [[FileTransferDao alloc] init];
    }

    return _fileTransferDao;
}

- (AuthService *)authService {
    if (!_authService) {
        _authService = [[AuthService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];
    }

    return _authService;
}

- (BOOL)isLoading {
    return (self.processing && [self.processing boolValue]);
}

- (void)stopLoading {
    self.processing = @NO;
}

- (NSFetchedResultsController *)fetchedResultsController {
    if (!_fetchedResultsController) {
        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSString *userComputerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

        _fetchedResultsController = [self.assetFileDao createFileUploadFetchedResultsControllerForUserComputerId:userComputerId delegate:self];
    }
    
    return _fetchedResultsController;
}

- (void)didChangePreferredContentSize:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

// Add the neccessary code in viewWillAppear and viewDidAppear after reset managed object contexts
- (void)onWillEnterForegroundNotification {
    [self reloadUploadFilesAndConfirmUploads:nil];
}

- (void)reactValueChangedToUserComputerId:(NSString *)userComputerId {
    BOOL enabledNewDownload = (userComputerId != nil);

    UIBarButtonItem *addUploadButtonItem = self.navigationItem.rightBarButtonItem;

    if (addUploadButtonItem) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [addUploadButtonItem setEnabled:enabledNewDownload];
        });
    }
}

- (void)reloadUploadFilesWithCompletionHandler:(void (^ _Nullable)(void))completionHandler {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSNumber *needReload = [userDefaults objectForKey:USER_DEFAULTS_KEY_NEED_RELOAD_UPLOAD_LIST];

    if (needReload && [needReload boolValue]) {
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_NEED_RELOAD_UPLOAD_LIST];

        if (self.transferKeyToScrollTo) {
            self.transferKeyToScrollTo = nil;
        }

        // set to nil so self.fetchedResultsController will re-assign the value based on the current user computer
        _fetchedResultsController = nil;
    }

    NSError *fetchError;
    [self.assetFileDao fetchedResultsController:self.fetchedResultsController performFetch:&fetchError];

    if (fetchError) {
        NSLog(@"Error on perform asset file fetch results controller\n%@", fetchError);
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

#pragma mark - NSKeyValueObserving

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(transferKeyToScrollTo))]) {
        id newValue = change[NSKeyValueChangeNewKey];
        id oldValue = change[NSKeyValueChangeOldKey];
        
        if (newValue && (newValue != [NSNull null]) && (oldValue == [NSNull null] || ![newValue isEqualToString:oldValue])) {
            [self scrollViewToCellWithTransferKey:newValue];

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

- (void)scrollViewToCellWithTransferKey:(NSString *)transferKey {
    if (transferKey) {
        NSIndexPath *indexPath = [self.assetFileDao fetchedResultsController:self.fetchedResultsController indexPathForTransferKey:transferKey];
        
        if (indexPath) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
            });
        }
    }
}

- (void)confirmUploadsWithCompletionHandler:(void (^ _Nullable)(void))completionHandler {
    [self.directoryService confirmUploadsWithCompletionHandler:^() {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.refreshControl && [self.refreshControl isRefreshing]) {
                [self.refreshControl endRefreshing];
            }
        });
        
        if (completionHandler) {
            completionHandler();
        }
    }];
}

- (void)reloadUploadFilesAndConfirmUploads:(id)sender {
    [self reloadUploadFilesWithCompletionHandler:^(){
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // confirm uploads
            [self confirmUploadsWithCompletionHandler:^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.tableView reloadData];
                });
            }];
        });
    }];
}

- (void)handleFetchedResultsControllerErrorWithMethodName:(NSString *)methodNameForLogging exception:(NSException *)e {
    NSLog(@"Error on %@.\n%@", methodNameForLogging, e);

    [self reloadUploadFilesWithCompletionHandler:nil];
}

- (IBAction)showActions:(id _Nonnull)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"" message:@"" preferredStyle:UIAlertControllerStyleActionSheet];

        // 1. Remove uploaded file info
        UIAlertAction *removeUploadedFilesAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Remove Uploaded Files", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self.assetFileDao deleteAssetFilesForUploadedSuccessfullyWithCompletionHandler:^(NSError *error){
                    if (error) {
                        NSLog(@"Failed to remove uploaded file records. Error:\n%@", [error userInfo]);
                    }

                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.tableView reloadData];
                    });
                }];
            });
        }];

        NSInteger sectionCount = [self numberOfSectionsInTableView:self.tableView];

        if (sectionCount > 0) {
            NSInteger rowCount = [self tableView:self.tableView numberOfRowsInSection:0];

            [removeUploadedFilesAction setEnabled:(rowCount > 0)];
        } else {
            [removeUploadedFilesAction setEnabled:NO];
        }

        [actionSheet addAction:removeUploadedFilesAction];
        // Last One: Cancel action

        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            // do nothing
        }];

        [actionSheet addAction:cancelAction];

//        if ([Utility isIPad]) {
//            UIView *sourceView = self.view;
//            CGRect sourceRect = self.view.frame;
//
//            actionSheet.popoverPresentationController.sourceView = sourceView;
//            actionSheet.popoverPresentationController.sourceRect = sourceRect;
//        }

        if ([self isVisible]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [actionSheet presentWithViewController:self sourceView:nil sourceRect:CGRectNull barButtonItem:(UIBarButtonItem *)sender animated:YES completion:nil];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [actionSheet presentWithAnimated:YES];
            });
        }
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    NSInteger count;

    // To prevent app terminated due to uncaught exception 'NSInternalInconsistencyException':
    // An exception was caught from the delegate of NSFetchedResultsController during a call to -controllerDidChangeContent: ...
    @try {
        count = [self.assetFileDao numberOfSectionsForFetchedResultsController:self.fetchedResultsController];
    } @catch (NSException *e) {
        [self handleFetchedResultsControllerErrorWithMethodName:@"numberOfSectionsInTableView:" exception:e];
    }

    return count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *title;

    // To prevent app terminated due to uncaught exception 'NSInternalInconsistencyException':
    // An exception was caught from the delegate of NSFetchedResultsController during a call to -controllerDidChangeContent: ...
    @try {
        title = [self.assetFileDao fetchedResultsController:self.fetchedResultsController titleForHeaderInSection:section];
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
        count = [self.assetFileDao fetchedResultsController:self.fetchedResultsController numberOfRowsInSection:section];
    } @catch (NSException *e) {
        [self handleFetchedResultsControllerErrorWithMethodName:@"tableView:numberOfRowsInSection:" exception:e];
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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"FileUploadCell";
    UITableViewCell *cell;

    // To prevent app terminated due to uncaught exception 'NSInternalInconsistencyException':
    // An exception was caught from the delegate of NSFetchedResultsController during a call to -controllerDidChangeContent: ...
    @try {
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];

        cell.accessoryType = UITableViewCellAccessoryNone;

        // configure the preferred font

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
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        AssetFileWithoutManaged *assetFileWithoutManaged = [self.assetFileDao findAssetFileForFetchedResultsController:self.fetchedResultsController objectAtIndexPath:indexPath];
        
        if (assetFileWithoutManaged) {
            [self deleteAssetFileWithoutManaged:assetFileWithoutManaged];
        }
    }
}

- (void)deleteAssetFileWithoutManaged:(AssetFileWithoutManaged *)assetFileWithoutManaged {
    NSString *status = assetFileWithoutManaged.status;

    if (!status || [status isEqualToString:FILE_TRANSFER_STATUS_PROCESSING]) {
        [self.fileUploadService cancelUploadFile:assetFileWithoutManaged.transferKey completionHandler:nil];
    } else {
        // Leave it because for status == success or failure and waitToConfirm == YES

        NSError *deleteError;
        [[TmpUploadFileService defaultService] removeTmpUploadFileAbsoluePathWithTransferKey:assetFileWithoutManaged.transferKey removeTmpUploadFile:YES deleteError:&deleteError];

        if (deleteError) {
            NSLog(@"[Upload List Commit Editing]Error on deleting tmp file for transferKey: %@\nError:\n%@", assetFileWithoutManaged.transferKey, [deleteError userInfo]);
        }
    }

    double delayInSeconds = 0.5;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        [self.assetFileDao deleteAssetFileForTransferKey:assetFileWithoutManaged.transferKey successHandler:^() {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView setEditing:NO animated:YES];

                [self.tableView reloadData];
            });
        } errorHandler:^(NSError *error) {
            if (error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.tableView setEditing:NO animated:YES];

                    [self.tableView reloadData];
                });

                NSString *message = (error.userInfo)[NSLocalizedDescriptionKey];

                [Utility viewController:self alertWithMessageTitle:@"" messageBody:(message ? message : NSLocalizedString(@"Error on deleting record.", @"")) actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
            }
        }];
    });
}

#pragma mark - UIScrollViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Show ActionSheet for user to choose action

    AssetFileWithoutManaged *assetFileWithoutManaged = [self.assetFileDao fetchedResultsController:self.fetchedResultsController objectAtIndexPath:indexPath];

    if (assetFileWithoutManaged) {
        UIAlertAction *deleteFileAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Delete File", @"") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [self deleteAssetFileWithoutManaged:assetFileWithoutManaged];
        }];

        [self showActionSheetWithTableView:tableView assetFileWithoutManaged:assetFileWithoutManaged deleteFileAction:deleteFileAction selectedRowAtIndexPath:indexPath];
    }
}

- (void)showActionSheetWithTableView:(UITableView *)view assetFileWithoutManaged:(AssetFileWithoutManaged *)assetFileWithoutManaged deleteFileAction:(UIAlertAction *)deleteFileAction selectedRowAtIndexPath:(NSIndexPath *)indexPath {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *serverFilename = assetFileWithoutManaged.serverFilename;

        UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:serverFilename message:@"" preferredStyle:UIAlertControllerStyleActionSheet];

        AssetFileDao *assetFileDao = [[AssetFileDao alloc] init];
        NSString *uploadStatus = [assetFileDao findFileUploadStatusForTransferKey:assetFileWithoutManaged.transferKey];

        if (uploadStatus) {
            if (![uploadStatus isEqualToString:FILE_TRANSFER_STATUS_SUCCESS] && ![uploadStatus isEqualToString:FILE_TRANSFER_STATUS_FAILED]) {

                // Stop Uploading - if status is not success and not failed

                UIAlertAction *stopUploadingAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"stop uploading", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [self cancelUploadWithAssetFileWithoutManaged:assetFileWithoutManaged uploadAgain:NO];
                }];

                [actionSheet addAction:stopUploadingAction];
            }

            // Upload Again - if status is not empty

            UIAlertAction *reUploadAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"re-upload", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [self cancelUploadWithAssetFileWithoutManaged:assetFileWithoutManaged uploadAgain:YES];
            }];

            [actionSheet addAction:reUploadAction];
        } else {

            // Upload - if status is empty

            UIAlertAction *uploadAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"upload", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [self cancelUploadWithAssetFileWithoutManaged:assetFileWithoutManaged uploadAgain:YES];
            }];

            [actionSheet addAction:uploadAction];
        }

        // File Information

        UIAlertAction *fileInfoAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"File Information", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self navigateToFileInfoViewControllerWithUploadFileTransferKey:assetFileWithoutManaged.transferKey];
        }];

        [actionSheet addAction:fileInfoAction];

        // Preview File

        UIAlertAction *previewAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Preview File", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self onPreviewFileWithAssetFileWithoutManaged:assetFileWithoutManaged];
        }];

        [actionSheet addAction:previewAction];

        // Delete selected file

        [actionSheet addAction:deleteFileAction];

        // Cancel Button at the bottom of the action sheet

        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:nil];

        [actionSheet addAction:cancelAction];

        if ([self isVisible]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIView *sourceView;
                CGRect sourceRect;

                if (indexPath && [self.tableView cellForRowAtIndexPath:indexPath]) {
                    UITableViewCell *selectedCell = [self.tableView cellForRowAtIndexPath:indexPath]; // must be called from main thread only

                    sourceView = selectedCell;
                    sourceRect = selectedCell.bounds; // must be called from main thread only
                } else {
                    sourceView = self.tableView;
                    sourceRect = self.tableView.frame;
                }

                [actionSheet presentWithViewController:self sourceView:sourceView sourceRect:sourceRect barButtonItem:nil animated:YES completion:nil];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [actionSheet presentWithAnimated:YES];
            });
        }
    });
}

- (void)onPreviewFileWithAssetFileWithoutManaged:(AssetFileWithoutManaged *)assetFileWithoutManaged {
    NSString *urlString = assetFileWithoutManaged.assetURL;

    if (urlString) {
        NSUInteger sourceTypeInteger = [assetFileWithoutManaged.sourceType unsignedIntegerValue];

        if (ASSET_FILE_SOURCE_TYPE_PHASSET == sourceTypeInteger) {
            [self previewAssetWithPhAssetLocalIdentifier:urlString];
        } else if (ASSET_FILE_SOURCE_TYPE_SHARED_FILE == sourceTypeInteger) {
            NSString *downloadedFileTransferKey = assetFileWithoutManaged.downloadedFileTransferKey;

            if (downloadedFileTransferKey) {
                NSError *foundError;
                FileTransferWithoutManaged *fileTransferWithoutManaged;

                fileTransferWithoutManaged = [self.fileTransferDao findFileTransferForTransferKey:downloadedFileTransferKey error:&foundError];

                if (fileTransferWithoutManaged) {
                    NSString *fileAbsolutePath = [DirectoryService absoluteFilePathFromLocalPath:fileTransferWithoutManaged.localPath userComputerId:fileTransferWithoutManaged.userComputerId];

                    FilePreviewController *filePreviewController = [[FilePreviewController alloc] init];

                    filePreviewController.fileAbsolutePath = fileAbsolutePath;
                    filePreviewController.fromViewController = self;
                    filePreviewController.delegate = self;

                    [filePreviewController preview];

                    self.keptController = filePreviewController;
                } else {
                    [self showFailedToPreviewAlert];
                }
            } else {
                [self showFailedToPreviewAlert];
            }
        } else if (ASSET_FILE_SOURCE_TYPE_EXTERNAL_FILE == sourceTypeInteger) {
            NSString *externalFileDirectoryPath = [DirectoryService directoryForExternalFilesWithCreatedIfNotExists:YES];

            NSString *fileAbsolutePath = [externalFileDirectoryPath stringByAppendingPathComponent:urlString];

            FilePreviewController *filePreviewController = [[FilePreviewController alloc] init];

            filePreviewController.fileAbsolutePath = fileAbsolutePath;
            filePreviewController.fromViewController = self;
            filePreviewController.delegate = self;

            [filePreviewController preview];

            self.keptController = filePreviewController;
        } else {
            [self showFailedToPreviewAlert];
        }
    } else {
        [self showFailedToPreviewAlert];
    }
}

- (void)cancelUploadWithAssetFileWithoutManaged:(AssetFileWithoutManaged *)assetFileWithoutManaged uploadAgain:(BOOL)uploadAgain {
    dispatch_queue_t gQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    dispatch_async(gQueue, ^{
        [self.fileUploadService cancelUploadFile:assetFileWithoutManaged.transferKey completionHandler:^() {
            if (uploadAgain) {
                double delayInSeconds = 1.0;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, gQueue, ^(void) {
                    [self uploadFileWithAssetFileWithoutManaged:assetFileWithoutManaged];
                });
            }
        }];
    });
}

- (void)showFailedToPreviewAlert {
    NSString *message = NSLocalizedString(@"Can't preview this file.", @"");

    [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
}

- (void)previewAssetWithPhAssetLocalIdentifier:(NSString *)phAssetLocalIdentifier {
    PHFetchResult *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[phAssetLocalIdentifier] options:nil];

    if ([fetchResult count] > 0) {
        // a file path from PHAsset

        PHAsset *phAsset = fetchResult.firstObject;

        [self previewAsset:phAsset];
    } else {
        [self showFailedToPreviewAlert];
    }
}

- (void)previewAsset:(id)asset {
    AssetsPreviewViewController *previewViewController = [Utility instantiateViewControllerWithIdentifier:@"AssetsPreview"];

    previewViewController.asset = asset;

    // hides tab bar
    [previewViewController setHidesBottomBarWhenPushed:YES];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.navigationController pushViewController:previewViewController animated:YES];
    });
}

- (void)navigateToFileInfoViewControllerWithUploadFileTransferKey:(NSString *_Nonnull)transferKey {
    FileUploadDetailViewController *detailViewController = [Utility instantiateViewControllerWithIdentifier:@"FileUploadDetail"];

    detailViewController.transferKey = transferKey;

    detailViewController.fromViewController = self;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.navigationController pushViewController:detailViewController animated:YES];
    });
}

- (void)uploadFileWithAssetFileWithoutManaged:(AssetFileWithoutManaged *)assetFileWithoutManaged {
    NSString *oldTransferKey = assetFileWithoutManaged.transferKey;
    NSString *filePath = assetFileWithoutManaged.assetURL;
    NSString *directory = assetFileWithoutManaged.serverDirectory;
    NSString *filename = assetFileWithoutManaged.serverFilename;

    if (!filePath || [filePath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length < 1) {
        // prompt that empty file path not allowed

        NSString *message = NSLocalizedString(@"File path should not be empty", @"");

        [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
    } else if (!directory || [directory stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length < 1) {
        // prompt that empty directory not allowed

        NSString *message = NSLocalizedString(@"Directory should not be empty", @"");

        [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
    } else if (!filename || [filename stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length < 1) {
        // prompt that empty filename not allowed

        NSString *message = NSLocalizedString(@"Filename should not be empty", @"");

        [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
    } else {
        // block as a local variable to find upload status and then go internal upload

        void (^findUploadStatusAndGoInternalUpload)(void) = ^void() {
            NSUserDefaults *userDefaults = [Utility groupUserDefaults];

            NSString *sessionId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

            [self.directoryService findFileUploadStatusWithTransferKey:oldTransferKey session:sessionId completionHandler:^(FileUploadStatusModel *fileUploadStatusModel, NSInteger statusCode, NSError *error) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    // if status code is 400, meaning that the server can't find FileUpload, which is the case when the previous upload happened in previous version,
                    // so just upload from the start

                    FileUploadStatusModel *localFileUploadStatusModel = fileUploadStatusModel;

                    if ((fileUploadStatusModel && !error) || statusCode == 400) {
                        if ([self fileExistsWithAssetFileWithoutManaged:[assetFileWithoutManaged copy]]) {
//                        if ([self fileExistsWithLocalRelPath:filePath sourceType:sourceType]) {
                            BOOL shouldCheckIfLocalFileChanged = (statusCode != 400);

                            if (statusCode == 400) {
                                localFileUploadStatusModel = [[FileUploadStatusModel alloc] initWithTransferKey:oldTransferKey transferredSize:@0 fileSize:@0 fileLastModifiedDate:@0];
                            }

                            [self internalUploadWithAssetFileWithoutManaged:[assetFileWithoutManaged copy] shouldCheckIfLocalFileChanged:shouldCheckIfLocalFileChanged fileUploadStatusModel:localFileUploadStatusModel tryAgainIfFailed:YES];
//                            [self internalUploadWithLocalRelPath:filePath sourceTyp:sourceType directory:directory filename:filename fileUploadGroupId:fileUploadGroupId shouldCheckIfLocalFileChanged:shouldCheckIfLocalFileChanged fileUploadStatusModel:localFileUploadStatusModel tryAgainIfFailed:YES];
                        } else {
                            NSString *message = [NSString stringWithFormat:NSLocalizedString(@"File %@ not exists", @""), filename];

                            [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                        }
                    } else {
                        NSString *errorMessage = error.localizedDescription ? error.localizedDescription : NSLocalizedString(@"Unknown error", @"");

                        [Utility viewController:self alertWithMessageTitle:@"" messageBody:errorMessage actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                    }
                });
            }];
        };

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // 1. cancel the current uploading, if any
            // 2. invoke service findFileUploadedByTransferKey to get the uploading data
            // 3. invoke service to upload the whole or partial file

            NSString *status = assetFileWithoutManaged.status;

            if ([status isEqualToString:FILE_TRANSFER_STATUS_PROCESSING]) {
                [self.fileUploadService cancelUploadFile:oldTransferKey completionHandler:^{
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        findUploadStatusAndGoInternalUpload();
                    });
                }];
            } else {
                // find tmp filename in tmpUploadFile dictionary, remove the file and remove the value in the dictionary
                NSError *deleteError;
                [[TmpUploadFileService defaultService] removeTmpUploadFileAbsoluePathWithTransferKey:oldTransferKey removeTmpUploadFile:YES deleteError:&deleteError];

                if (deleteError) {
                    NSLog(@"[Upload]Error on deleting tmp file for transferKey: %@\nError:\n%@", oldTransferKey, [deleteError userInfo]);
                }

                findUploadStatusAndGoInternalUpload();
            }
        });
    }
}

- (void)internalUploadWithAssetFileWithoutManaged:(AssetFileWithoutManaged *)assetFileWithoutManaged shouldCheckIfLocalFileChanged:(BOOL)shouldCheckIfLocalFileChanged fileUploadStatusModel:(FileUploadStatusModel *)fileUploadStatusModel tryAgainIfFailed:(BOOL)tryAgainIfFailed {
//    NSString *oldTransferKey = self.assetFileWithoutManaged.transferKey;
//    NSString *localRelPath = self.assetFileWithoutManaged.assetURL;
    NSString *directory = assetFileWithoutManaged.serverDirectory;
    NSString *filename = assetFileWithoutManaged.serverFilename;
    NSString *fileUploadGroupId = assetFileWithoutManaged.fileUploadGroupId;
    NSNumber *sourceType = assetFileWithoutManaged.sourceType;

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    NSString *tempLugServerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID];

    if (sessionId == nil || sessionId.length < 1) {
        [FilelugUtility alertEmptyUserSessionFromViewController:self];
    } else if (tempLugServerId == nil || tempLugServerId.length < 1) {
        [self requestConnectWithAuthService:self.authService userDefaults:userDefaults assetFileWithoutManaged:assetFileWithoutManaged shouldCheckIfLocalFileChanged:shouldCheckIfLocalFileChanged fileUploadStatusModel:fileUploadStatusModel];
    } else {
        self.processing = @YES;

        SystemService *systemService = [[SystemService alloc] initWithCachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeInterval:CONNECTION_TIME_INTERVAL];

        [systemService pingDesktop:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *pingError) {
            dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

            dispatch_async(queue, ^{
                self.processing = @NO;

                NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

                if (statusCode == 200) {
                    [SystemService parsePingDesktopResponseJson:data completionHandler:^(NSDictionary *dictionary) {
                        if (dictionary) {
                            BOOL canUpload = YES;

                            NSNumber *uploadSizeLimit = dictionary[@"upload-size-limit"];

                            long long int fileSizeLimit = [uploadSizeLimit longLongValue];

                            if (uploadSizeLimit) {
                                canUpload = [self checkIfFileSizeWithAssetFileWithoutManaged:assetFileWithoutManaged smallerThanFileSizeLimit:fileSizeLimit];

                                if (!canUpload) {
                                    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"exceed.upload.size.limit2", @""), filename];

                                    [Utility viewController:self alertWithMessageTitle:NSLocalizedString(@"File Too Large", @"") messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                                }
                            } else {
                                canUpload = NO;

                                NSLog(@"Skip check upload size limit for upload size limit not found.");
                            }

                            if (canUpload) {
                                dispatch_async(queue, ^{
                                    self.processing = @YES;

                                    // Type of PHAsset -> if sourceType is ASSET_FILE_SOURCE_TYPE_PHASSET
                                    // Type of FileTransferWithoutManaged with absolute file path -> if sourceType is ASSET_FILE_SOURCE_TYPE_SHARED_FILE
                                    // Type of NSString with absolute file path -> if sourceType is ASSET_FILE_SOURCE_TYPE_EXTERNAL_FILE
                                    id asset = [DirectoryService assetWithAssetFileWithoutManaged:assetFileWithoutManaged];
//                                    id asset = [DirectoryService assetWithAssetURL:localRelPath sourceType:sourceType];

                                    if (asset) {
                                        [self.fileUploadService uploadFileFromFileObject:asset sourceType:sourceType sessionId:sessionId fileUploadGroupId:fileUploadGroupId directory:directory filename:filename shouldCheckIfLocalFileChanged:shouldCheckIfLocalFileChanged fileUploadStatusModel:fileUploadStatusModel addToStartTimestampWithMillisec:0 completionHandler:^(NSError *error) {
                                            dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (DELAY_UPLOAD_TIMER_INTERVAL * NSEC_PER_SEC));
                                            dispatch_after(delayTime, queue, ^(void) {
                                                self.processing = @NO;

                                                if (error) {
                                                    NSString *errorMessage = [error localizedDescription];

                                                    if (!errorMessage || errorMessage.length < 1) {
                                                        errorMessage = [error localizedFailureReason];
                                                    }

                                                    if (!errorMessage || errorMessage.length < 1) {
                                                        errorMessage = NSLocalizedString(@"Failed to upload file. Please delete this upload and upload again.", @"");
                                                    }

                                                    [Utility viewController:self alertWithMessageTitle:@"" messageBody:errorMessage actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                                                }
                                            });
                                        }];
                                    } else {
                                        // alert if source type is empty

                                        [Utility viewController:self alertWithMessageTitle:@"" messageBody:NSLocalizedString(@"No such file.", @"") actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                                    }
                                });
                            }
                        }
                    }];
                } else if (tryAgainIfFailed && (statusCode == 401 || (pingError && ([pingError code] == NSURLErrorUserCancelledAuthentication || [pingError code] == NSURLErrorSecureConnectionFailed)))) {
                    self.processing = @YES;

                    [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                        if ([userDefaults objectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID]) {
                            /* recursively invoked */

                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                [self internalUploadWithAssetFileWithoutManaged:assetFileWithoutManaged shouldCheckIfLocalFileChanged:shouldCheckIfLocalFileChanged fileUploadStatusModel:fileUploadStatusModel tryAgainIfFailed:NO];
                            });
                        } else {
                            // server not connected, so request connection
                            [self requestConnectWithAuthService:self.authService userDefaults:userDefaults assetFileWithoutManaged:assetFileWithoutManaged shouldCheckIfLocalFileChanged:shouldCheckIfLocalFileChanged fileUploadStatusModel:fileUploadStatusModel];
                        }
                    } failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
                        self.processing = @NO;

                        NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                        [self alertToTryUploadAgainWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror assetFileWithoutManaged:assetFileWithoutManaged shouldCheckIfLocalFileChanged:shouldCheckIfLocalFileChanged fileUploadStatusModel:fileUploadStatusModel];
                    }];
                } else if (tryAgainIfFailed && statusCode == 503) {
                    // server not connected, so request connection
                    [self requestConnectWithAuthService:self.authService userDefaults:userDefaults assetFileWithoutManaged:assetFileWithoutManaged shouldCheckIfLocalFileChanged:shouldCheckIfLocalFileChanged fileUploadStatusModel:fileUploadStatusModel];
                } else {
                    self.processing = @NO;

                    NSString *messagePrefix = NSLocalizedString(@"Error on upload file.", @"");

                    [self alertToTryUploadAgainWithMessagePrefix:messagePrefix response:response data:data error:pingError assetFileWithoutManaged:assetFileWithoutManaged shouldCheckIfLocalFileChanged:shouldCheckIfLocalFileChanged fileUploadStatusModel:fileUploadStatusModel];
                }
            });
        }];
    }
}

// if file/asset not found with the specified localRelPath, return NO
- (BOOL)checkIfFileSizeWithAssetFileWithoutManaged:(AssetFileWithoutManaged *)assetFileWithoutManaged smallerThanFileSizeLimit:(long long int)fileSizeLimit {
    BOOL isSizeSmallerThanLimit = YES;

    NSUInteger sourceTypeInteger = [assetFileWithoutManaged.sourceType unsignedIntegerValue];

    if (ASSET_FILE_SOURCE_TYPE_PHASSET == sourceTypeInteger) {
        // assetURL is a PHAsset local identifier

        isSizeSmallerThanLimit = [self canUploadFileWithPHAssetLocalIdentfier:assetFileWithoutManaged.assetURL fileSizeLimit:fileSizeLimit];
    } else if (ASSET_FILE_SOURCE_TYPE_SHARED_FILE == sourceTypeInteger) {
        // assetURL is a relative path under shared folder

        NSString *downloadedFileTransferKey = assetFileWithoutManaged.downloadedFileTransferKey;

        if (downloadedFileTransferKey) {
            FileTransferWithoutManaged *fileTransferWithoutManaged = [self.fileTransferDao findFileTransferForTransferKey:downloadedFileTransferKey error:NULL];

            if (fileTransferWithoutManaged) {
                NSString *absolutePath = [DirectoryService absoluteFilePathFromLocalPath:fileTransferWithoutManaged.localPath userComputerId:fileTransferWithoutManaged.userComputerId];

                BOOL isDirectory;
                if ([[NSFileManager defaultManager] fileExistsAtPath:absolutePath isDirectory:&isDirectory]) {
                    if (!isDirectory) {
                        // a file from file-sharing

                        NSError *sizeError;
                        unsigned long long int fileSize = [Utility fileSizeWithAbsolutePath:absolutePath error:&sizeError];

                        if (sizeError || fileSize > fileSizeLimit) {
                            isSizeSmallerThanLimit = NO;
                        }
                    } else {
                        // file not found

                        isSizeSmallerThanLimit = NO;
                    }
                } else {
                    // file not found

                    isSizeSmallerThanLimit = NO;
                }
            }
        }
    } else if (ASSET_FILE_SOURCE_TYPE_EXTERNAL_FILE == sourceTypeInteger) {
        // assetURL is a relative path under external folder

        NSString *absolutePath = [[DirectoryService directoryForExternalFilesWithCreatedIfNotExists:YES] stringByAppendingPathComponent:assetFileWithoutManaged.assetURL];

        BOOL isDirectory;
        if ([[NSFileManager defaultManager] fileExistsAtPath:absolutePath isDirectory:&isDirectory]) {
            if (!isDirectory) {
                // a file from external file

                NSError *sizeError;
                unsigned long long int fileSize = [Utility fileSizeWithAbsolutePath:absolutePath error:&sizeError];

                if (sizeError || fileSize > fileSizeLimit) {
                    isSizeSmallerThanLimit = NO;
                }
            } else {
                // file not found

                isSizeSmallerThanLimit = NO;
            }
        } else {
            // file not found

            isSizeSmallerThanLimit = NO;
        }
    } else {
        // File not found.

        isSizeSmallerThanLimit = NO;

        NSLog(@"File not found: %@, source type: %@", assetFileWithoutManaged.assetURL, assetFileWithoutManaged.sourceType);
    }

    return isSizeSmallerThanLimit;
}

- (BOOL)canUploadFileWithPHAssetLocalIdentfier:(NSString *)localIdentifier fileSizeLimit:(long long int)fileSizeLimit {
    __block BOOL canUpload = YES;

    PHFetchResult *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[localIdentifier] options:nil];

    if ([fetchResult count] < 1) {
        canUpload = NO;

        NSLog(@"File not found: %@", localIdentifier);
    } else {
        PHAsset *phAsset = [fetchResult firstObject];

        [self.directoryService findFileSizeWithPHAsset:phAsset completionHandler:^(NSUInteger fileSize, NSError *sizeError) {
            if (sizeError || fileSize > fileSizeLimit) {
                canUpload = NO;
            }
        }];
    }
    return canUpload;
}

- (void)requestConnectWithAuthService:(AuthService *)authService userDefaults:(NSUserDefaults *)userDefaults assetFileWithoutManaged:(AssetFileWithoutManaged *)assetFileWithoutManaged shouldCheckIfLocalFileChanged:(BOOL)shouldCheckIfLocalFileChanged fileUploadStatusModel:(FileUploadStatusModel *)fileUploadStatusModel {
    self.processing = @YES;

    [authService requestConnectWithSession:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] successHandler:^(NSURLResponse *rcresponse, NSData *rcdata) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self internalUploadWithAssetFileWithoutManaged:assetFileWithoutManaged shouldCheckIfLocalFileChanged:shouldCheckIfLocalFileChanged fileUploadStatusModel:fileUploadStatusModel tryAgainIfFailed:NO];
        });
    } failureHandler:^(NSData *rcdata, NSURLResponse *rcresponse, NSError *rcerror) {
        self.processing = @NO;

        [self alertToTryUploadAgainWithMessagePrefix:nil response:rcresponse data:rcdata error:rcerror assetFileWithoutManaged:assetFileWithoutManaged shouldCheckIfLocalFileChanged:shouldCheckIfLocalFileChanged fileUploadStatusModel:fileUploadStatusModel];
    }];
}

- (void)alertToTryUploadAgainWithMessagePrefix:(NSString *)messagePrefix response:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error assetFileWithoutManaged:(AssetFileWithoutManaged *)assetFileWithoutManaged shouldCheckIfLocalFileChanged:(BOOL)shouldCheckIfLocalFileChanged fileUploadStatusModel:(FileUploadStatusModel *)fileUploadStatusModel {
    UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Upload Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self internalUploadWithAssetFileWithoutManaged:assetFileWithoutManaged shouldCheckIfLocalFileChanged:shouldCheckIfLocalFileChanged fileUploadStatusModel:fileUploadStatusModel tryAgainIfFailed:YES];
        });
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self internalUploadWithAssetFileWithoutManaged:assetFileWithoutManaged shouldCheckIfLocalFileChanged:shouldCheckIfLocalFileChanged fileUploadStatusModel:fileUploadStatusModel tryAgainIfFailed:NO];
        });
    }];
}

- (BOOL)fileExistsWithAssetFileWithoutManaged:(AssetFileWithoutManaged *)assetFileWithoutManaged {
    __block BOOL fileExists = NO;

    if (assetFileWithoutManaged && assetFileWithoutManaged.sourceType) {
        NSUInteger sourceTypeInteger = [assetFileWithoutManaged.sourceType unsignedIntegerValue];

        if (ASSET_FILE_SOURCE_TYPE_PHASSET == sourceTypeInteger) {
            // assetURL is a PHAsset local identifier

            PHFetchResult *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[assetFileWithoutManaged.assetURL] options:nil];

            fileExists = ([fetchResult count] > 0);
        } else if (ASSET_FILE_SOURCE_TYPE_SHARED_FILE == sourceTypeInteger) {
            // assetURL is a relative path under shared folder

            NSString *downloadedFileTransferKey = assetFileWithoutManaged.downloadedFileTransferKey;

            if (downloadedFileTransferKey) {
                FileTransferWithoutManaged *fileTransferWithoutManaged = [self.fileTransferDao findFileTransferForTransferKey:downloadedFileTransferKey error:NULL];

                if (fileTransferWithoutManaged) {
                    NSString *absolutePath = [DirectoryService absoluteFilePathFromLocalPath:fileTransferWithoutManaged.localPath userComputerId:fileTransferWithoutManaged.userComputerId];

                    BOOL isDirectory;
                    fileExists = [[NSFileManager defaultManager] fileExistsAtPath:absolutePath isDirectory:&isDirectory];

                    if (fileExists && isDirectory) {
                        // file can't be a directory
                        fileExists = NO;
                    }
                }
            }
        } else if (ASSET_FILE_SOURCE_TYPE_EXTERNAL_FILE == sourceTypeInteger) {
            // assetURL is a relative path under external folder

            NSString *absolutePath = [[DirectoryService directoryForExternalFilesWithCreatedIfNotExists:YES] stringByAppendingPathComponent:assetFileWithoutManaged.assetURL];

            BOOL isDirectory;
            fileExists = [[NSFileManager defaultManager] fileExistsAtPath:absolutePath isDirectory:&isDirectory];

            if (fileExists && isDirectory) {
                fileExists = NO;
            }
        }
    }

    return fileExists;
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
                [self prepareTableViewWhenFetchedResultsChangeUpdateWithIndexPath:indexPath];

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

- (void)prepareTableViewWhenFetchedResultsChangeUpdateWithIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];

    [self configureCell:cell atIndexPath:indexPath];
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    if (cell && indexPath) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            AssetFileWithoutManaged *assetFileWithoutManaged = [self.assetFileDao fetchedResultsController:self.fetchedResultsController objectAtIndexPath:indexPath];

            if (assetFileWithoutManaged) {
                // The cell may comes from pool and the values in the cell may totally irrelevant to this new one.
                // So all the values of the cell should be replaced.

                dispatch_queue_t mainQueue = dispatch_get_main_queue();

                dispatch_async(mainQueue, ^{
                    [cell.imageView setContentMode:UIViewContentModeScaleAspectFill];
                });

                // prepare thumbnail

                [self prepareCellImageForCell:cell withAssetFileWithoutManaged:assetFileWithoutManaged queue:mainQueue];

                // filename

                NSString *filename = assetFileWithoutManaged.serverFilename;

                dispatch_async(mainQueue, ^{
                    [cell.textLabel setText:filename ? filename : @""];

                    // prepare status string and its color

                    NSString *detailTextLabelText = cell.detailTextLabel.text ? cell.detailTextLabel.text : @"";
                    UIColor *detailTextLableTextColor = cell.detailTextLabel.textColor;

                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        [self.assetFileDao prepareUploadStatusWithAssetFileWithoutManaged:assetFileWithoutManaged
                                                                      currentStatusString:detailTextLabelText
                                                                       currentStatusColor:detailTextLableTextColor
                                                                        completionHandler:^(NSString *statusString, UIColor *statusColor) {
                                                                            NSNumber *totalSize = assetFileWithoutManaged.totalSize;

                                                                            NSString *displaySize;

                                                                            NSString *detailLabelText;

                                                                            if (totalSize) {
                                                                                displaySize = [Utility byteCountToDisplaySize:[totalSize longLongValue]];

                                                                                detailLabelText = [NSString stringWithFormat:@"%@, %@", statusString, displaySize];
                                                                            } else {
                                                                                detailLabelText = [NSString stringWithFormat:@"%@", statusString];
                                                                            }

                                                                            NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:detailLabelText];
                                                                            [attributedString setText:statusString withColor:statusColor];

                                                                            if (displaySize) {
                                                                                [attributedString setText:displaySize withColor:[UIColor darkGrayColor]];
                                                                            }

                                                                            dispatch_async(mainQueue, ^{
                                                                                [cell.detailTextLabel setAttributedText:attributedString];

                                                                                // To resolve the width of the detail text not correctly updated
                                                                                [cell layoutSubviews];
                                                                            });
                                                                        }];
                    });
                });
            }
        });
    }
}

- (void)prepareCellImageForCell:(UITableViewCell *)cell withAssetFileWithoutManaged:(AssetFileWithoutManaged *)assetFileWithoutManaged queue:(dispatch_queue_t)queue {
    UIImage *thumbnail = assetFileWithoutManaged.thumbnail;

    if (thumbnail) {
        dispatch_async(queue, ^{
            [cell.imageView setImage:thumbnail];
        });
    } else {
        NSString *urlString = assetFileWithoutManaged.assetURL;
        
        if (urlString) {
            NSUInteger sourceTypeInteger = [assetFileWithoutManaged.sourceType unsignedIntegerValue];
                
            if (ASSET_FILE_SOURCE_TYPE_PHASSET == sourceTypeInteger) {
                [self findThumbnailFromPhAssetLocalIdentifier:urlString withSetToCellImageInCell:cell queue:queue];
            } else {
                dispatch_async(queue, ^{
                    [cell.imageView setImage:[DirectoryService imageForFileExtension:[urlString pathExtension]]];
                });
            }
        }
    }
}

- (void)findThumbnailFromPhAssetLocalIdentifier:(NSString *)phAssetLocalIdentifier withSetToCellImageInCell:(UITableViewCell *)cell queue:(dispatch_queue_t)queue {
    PHFetchResult *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[phAssetLocalIdentifier] options:nil];
    
    if ([fetchResult count] > 0) {
        // a file path from PHAsset
        
        PHAsset *phAsset = fetchResult.firstObject;

        [Utility requestAssetThumbnailWithAsset:phAsset
                                  resizedToSize:[Utility thumbnailSizeWithHeight:MAX_IMAGE_HEIGHT_FOR_FILE_UPLOAD_TABLE_VIEW_CELL]
                                  resultHandler:^(UIImage *result) {
                                      // DO NOT try save back to AssetFile. The later file may not be the former one.

                                      dispatch_async(queue, ^{
                                          [cell.imageView setImage:result];
                                      });
         }];
    } else {
        dispatch_async(queue, ^{
            [cell.imageView setImage:[UIImage imageNamed:@"ic_file2"] ];
        });
    }
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"UploadFileToAssetsLibrary"]) {
        FileUploadProcessService *uploadProcessService = [[FilelugUtility applicationDelegate] fileUploadProcessService];
        
        [uploadProcessService reset];
        
        uploadProcessService.fromViewController = self;
    }
}

@end
