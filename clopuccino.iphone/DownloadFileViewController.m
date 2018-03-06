#import "DownloadFileViewController.h"
#import "FileInfoViewController.h"
#import "RootDirectoryViewController.h"
#import "FilelugUtility.h"
#import "AppService.h"
#import "FilePreviewController.h"
#import "FileDownloadProcessService.h"
#import "AppDelegate.h"
#import "FilelugFileDownloadService.h"

@interface DownloadFileViewController ()

@property(nonatomic, strong) FileTransferDao *fileTransferDao;

@property(nonatomic, nonnull, strong) AssetFileDao *assetFileDao;

@property(nonatomic, strong) UserComputerDao *userComputerDao;

@property(nonatomic, strong) UserDao *userDao;

@property(nonatomic, strong) HierarchicalModelDao *hierarchicalModelDao;

@property(nonatomic, strong) NSFetchedResultsController *fetchedResultsController;

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) AppService *appService;

// Keep the reference to prevent error like: 'UIDocumentInteractionController has gone away prematurely!'
@property(nonatomic, strong) id keptController;

@property(nonatomic, strong) DirectoryService *directoryService;

@property(nonatomic, strong) FileDownloadGroupDao *fileDownloadGroupDao;

@property(nonatomic, strong) FilelugFileDownloadService *fileDownloadService;

@end

@implementation DownloadFileViewController

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

    // When entering foreground from background, neither viewWillAppear nor viewDidAppear invokes.
    // To change the view when user computer changed in extensions, listen to UIApplicationWillEnterForegroundNotification.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onWillEnterForegroundNotification) name:UIApplicationWillEnterForegroundNotification object:nil];

    [self addObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];

    [self.refreshControl addTarget:self action:@selector(reloadDownloadFiles:) forControlEvents:UIControlEventValueChanged];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onFileDownloadDidResumeNotification:) name:NOTIFICATION_NAME_FILE_DOWNLOAD_DID_RESUME object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // Ask only once if allowed notification
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [FilelugUtility promptToAllowNotificationWithViewController:self];
    });

    [self reloadDownloadFilesWithCompletionHandler:^(){
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSUserDefaults *userDefaults = [Utility groupUserDefaults];
            NSString *userComputerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

            [self downloadButtonItemReactWithValueChangedToUserComputerId:userComputerId];

            [self scrollAndPreviewFile];

        });
    }];
}

- (void)scrollAndPreviewFile {
    if (self.transferKeyToScrollTo) {
        NSString *transferKeyCopy = [self.transferKeyToScrollTo copy];

        self.transferKeyToScrollTo = nil;

        [self scrollViewToCellWithTransferKey:transferKeyCopy];
    }

    if (self.transferKeyToPressOn) {
        NSString *transferKeyCopy = [self.transferKeyToPressOn copy];

        self.transferKeyToPressOn = nil;

        [self previewFileFromDownloadTransferKey:transferKeyCopy];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    // removing observers

    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_NAME_FILE_DOWNLOAD_DID_RESUME object:nil];

//    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_NAME_FILE_DOWNLOAD_DID_COMPLETE object:nil];

    [self.refreshControl removeTarget:self action:@selector(reloadDownloadFiles:) forControlEvents:UIControlEventValueChanged];

    [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) context:NULL];

//    [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(transferKeyToPressOn)) context:NULL];
//
//    [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(transferKeyToScrollTo)) context:NULL];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];

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

- (AssetFileDao *)assetFileDao {
    if (!_assetFileDao) {
        _assetFileDao = [[AssetFileDao alloc] init];
    }

    return _assetFileDao;
}

- (UserComputerDao *)userComputerDao {
    if (!_userComputerDao) {
        _userComputerDao = [[UserComputerDao alloc] init];
    }

    return _userComputerDao;
}

- (UserDao *)userDao {
    if (!_userDao) {
        _userDao = [[UserDao alloc] init];
    }

    return _userDao;
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

- (FilelugFileDownloadService *)fileDownloadService {
    if (!_fileDownloadService) {
        _fileDownloadService = [[FilelugFileDownloadService alloc] init];
    }

    return _fileDownloadService;
}

- (NSFetchedResultsController *)fetchedResultsController {
    if (!_fetchedResultsController) {
        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSString *userComputerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

        _fetchedResultsController = [self.fileTransferDao createFileDownloadFetchedResultsControllerForUserComputerId:userComputerId delegate:self];
    }

    return _fetchedResultsController;
}

- (void)didChangePreferredContentSize:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (void)onWillEnterForegroundNotification {
    [self reloadDownloadFilesWithCompletionHandler:^(){
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSUserDefaults *userDefaults = [Utility groupUserDefaults];
            NSString *userComputerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

            [self downloadButtonItemReactWithValueChangedToUserComputerId:userComputerId];

            [self scrollAndPreviewFile];
        });
    }];
}

- (void)downloadButtonItemReactWithValueChangedToUserComputerId:(NSString *)userComputerId {
    BOOL enabledNewDownload = (userComputerId != nil);

    UIBarButtonItem *addDownloadButtonItem = self.navigationItem.rightBarButtonItem;

    if (addDownloadButtonItem) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [addDownloadButtonItem setEnabled:enabledNewDownload];
        });
    }
}

#pragma mark - NSKeyValueObserving

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
//    if ([keyPath isEqualToString:NSStringFromSelector(@selector(transferKeyToScrollTo))]) {
//        [self logChangeTypeWithChange:change];
//
//        id newValue = change[NSKeyValueChangeNewKey];
//        id oldValue = change[NSKeyValueChangeOldKey];
//
//        // For the first time the value was set, the newValue is null and only oldValue is not null
//
//        if ([self isInitialValueOrValueChangedWithOldValue:oldValue newValue:newValue]) {
//            NSString *transferKey;
//
//            if (newValue && newValue != [NSNull null]) {
//                transferKey = newValue;
//            } else {
//                transferKey = oldValue;
//            }
//
//            [self scrollViewToCellWithTransferKey:transferKey];
//        }
////        if (newValue && (newValue != [NSNull null]) && (oldValue == [NSNull null] || ![newValue isEqualToString:oldValue])) {
////            [self scrollViewToCellWithTransferKey:newValue];
////        }
//    } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(transferKeyToPressOn))]) {
//        [self logChangeTypeWithChange:change];
//
//        id newValue = change[NSKeyValueChangeNewKey];
//        id oldValue = change[NSKeyValueChangeOldKey];
//
//        if ([self isInitialValueOrValueChangedWithOldValue:oldValue newValue:newValue]) {
//            NSString *transferKey;
//
//            if (newValue && newValue != [NSNull null]) {
//                transferKey = newValue;
//            } else {
//                transferKey = oldValue;
//            }
//
//            [self previewFileFromDownloadTransferKey:transferKey];
//        }
////        if (newValue && (newValue != [NSNull null]) && (oldValue == [NSNull null] || ![newValue isEqualToString:oldValue])) {
////            [self previewFileFromDownloadTransferKey:newValue];
////        }
//    } else
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

- (void)logChangeTypeWithChange:(NSDictionary *)change {
    // DEBUG

    NSUInteger changeKind = [change[NSKeyValueChangeKindKey] unsignedIntegerValue];

    NSString *changeKindString;

    switch (changeKind) {
        case NSKeyValueChangeSetting:
            changeKindString = @"NSKeyValueChangeSetting";
            break;
        case NSKeyValueChangeInsertion:
            changeKindString = @"NSKeyValueChangeInsertion";
            break;
        case NSKeyValueChangeRemoval:
            changeKindString = @"NSKeyValueChangeRemoval";
            break;
        case NSKeyValueChangeReplacement:
            changeKindString = @"NSKeyValueChangeReplacement";
            break;
        default:
            changeKindString = @"Unknown";
    }

    NSLog(@"Change type: %@", changeKindString);
}

- (BOOL)isInitialValueOrValueChangedWithOldValue:(id)oldValue newValue:(id)newValue {
    // initial value: ((!newValue || [NSNull null] == newValue) && oldValue && [NSNull null] != oldValue)
    // value changed: (newValue && [NSNull null] != newValue && oldValue && [NSNull null] != oldValue && ![newValue isEqual:oldValue])

    BOOL isNewValueEmpty = !newValue || [NSNull null] == newValue;
    BOOL isOldValueEmpty = !oldValue || [NSNull null] == oldValue;
    BOOL isTheSame = [newValue isEqual:oldValue];

    return (!isNewValueEmpty && isOldValueEmpty) || (!isNewValueEmpty && !isTheSame);

//    return ((!newValue || [NSNull null] == newValue) && oldValue && [NSNull null] != oldValue)
//            || (newValue && [NSNull null] != newValue && oldValue && [NSNull null] != oldValue && ![newValue isEqual:oldValue]);
}

- (void)scrollViewToCellWithTransferKey:(NSString *)transferKey {
    if (transferKey) {
        NSIndexPath *indexPath = [self.fileTransferDao fetchedResultsController:self.fetchedResultsController indexPathForTransferKey:transferKey];
        
        if (indexPath) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
            });
        }
    }
}

- (void)reloadDownloadFiles:(id)sender {
    [self reloadDownloadFilesWithCompletionHandler:nil];
}

// The completionHandler runs under main queue, so use the background queue if needed.
- (void)reloadDownloadFilesWithCompletionHandler:(void (^)(void))completionHandler {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSNumber *needReload = [userDefaults objectForKey:USER_DEFAULTS_KEY_NEED_RELOAD_DOWNLOAD_LIST];

    if (needReload && [needReload boolValue]) {
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_NEED_RELOAD_DOWNLOAD_LIST];

        if (self.transferKeyToScrollTo) {
            self.transferKeyToScrollTo = nil;
        }

        if (self.transferKeyToPressOn) {
            self.transferKeyToPressOn = nil;

            NSLog(@"Cancelled to pressing on the cell with specified transfer key because user computer changed.");
        }

        // set to nil so self.fetchedResultsController will re-assign the value based on the current user computer
        _fetchedResultsController = nil;
    }

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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    FileTransferWithoutManaged *fileTransferWithoutManaged = [self.fileTransferDao fetchedResultsController:self.fetchedResultsController objectAtIndexPath:indexPath];

    if (fileTransferWithoutManaged) {
        UIAlertAction *deleteFileAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Delete File", @"") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [self deleteRowAtIndexPath:indexPath];
        }];

        [self showActionSheetWithTableView:tableView fileTransferWithoutManaged:fileTransferWithoutManaged alertActionToDeleteFile:deleteFileAction selectedRowAtIndexPath:indexPath];
    }
}

- (void)showActionSheetWithTableView:(UITableView *)tableView fileTransferWithoutManaged:(FileTransferWithoutManaged *)fileTransferWithoutManaged alertActionToDeleteFile:(UIAlertAction *)deleteFileAction selectedRowAtIndexPath:(NSIndexPath *)indexPath {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *title = [fileTransferWithoutManaged.localPath lastPathComponent];

        UIAlertController *actionSheetController = [UIAlertController alertControllerWithTitle:title message:@"" preferredStyle:UIAlertControllerStyleActionSheet];

        // The actions should be different based on the downloading status

        NSString *firstAlertActionTitle;

        NSString *transferKey = fileTransferWithoutManaged.transferKey;

        NSString *realServerPath = fileTransferWithoutManaged.realServerPath;

//        NSString *localPath = fileTransferWithoutManaged.localPath;

        NSString *status = fileTransferWithoutManaged.status;

        if ([status isEqualToString:FILE_TRANSFER_STATUS_PROCESSING] || [status isEqualToString:FILE_TRANSFER_STATUS_PREPARING]) {
            firstAlertActionTitle = NSLocalizedString(@"Cancel Download", @"");
        } else {
            firstAlertActionTitle = NSLocalizedString(@"Download Again", @"");
        }

        // 1. Preview File (shows up only if file downloaded successfully)

        if ([status isEqualToString:FILE_TRANSFER_STATUS_SUCCESS]) {
            UIAlertAction *previewAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Preview File", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                // preview file

                [self doPreviewFileWithFileTransferKey:transferKey];
            }];

            [actionSheetController addAction:previewAction];
        }

        // 2. Download Again/Cancel Download

        UIAlertAction *openAction = [self downloadOrCancelActionWithTitle:firstAlertActionTitle realServerPath:realServerPath];

        [actionSheetController addAction:openAction];

        // 3. File Information

        UIAlertAction *fileInfoAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"File Information", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self navigateToFileInfoViewControllerWithFileTransferKey:transferKey];
        }];

        [actionSheetController addAction:fileInfoAction];

//        // 4 Move to iTunes sharing folder
//
//        if ([status isEqualToString:FILE_TRANSFER_STATUS_SUCCESS]) {
//            UIAlertAction *moveToSharingFolder = [UIAlertAction actionWithTitle:NSLocalizedString(@"Move to Device Sharing Folder", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
//                [self.appService moveFileToITunesSharingFolderWithTableView:tableView localRelPath:localPath deleteFileTransferWithTransferKey:transferKey fileTransferDao:self.fileTransferDao successHandler:nil];
//            }];
//
//            [actionSheetController addAction:moveToSharingFolder];
//        }

        // 5. Copy File Path

        UIAlertAction *copyPathAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Copy Path", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self copyFilePathWithFileTransferKey:transferKey];
        }];

        [actionSheetController addAction:copyPathAction];

        // 6. Options (download_status == success)

        if ([status isEqualToString:FILE_TRANSFER_STATUS_SUCCESS]) {
            UIAlertAction *showOptionAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Options", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [self tableView:tableView showOptionMenuViewControllerWithFileTransferKey:transferKey];
            }];

            [actionSheetController addAction:showOptionAction];
        }

        // 7. Delete (local file)

        if (deleteFileAction) {
            [actionSheetController addAction:deleteFileAction];
        }

        // 8. Cancel action

        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            // deselect row

            NSIndexPath *selectedIndexPath = [tableView indexPathForSelectedRow];

            if (selectedIndexPath) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [tableView deselectRowAtIndexPath:selectedIndexPath animated:YES];
                });
            }
        }];

        [actionSheetController addAction:cancelAction];

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
                
                [actionSheetController presentWithViewController:self sourceView:sourceView sourceRect:sourceRect barButtonItem:nil animated:YES completion:nil];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [actionSheetController presentWithAnimated:YES];
            });
        }
    });
}

//- (NSString *)actionSheetTitleWithFileTransferWithoutManaged:(FileTransferWithoutManaged *)fileTransferWithoutManaged {
//    NSString *title;
//
//    if (fileTransferWithoutManaged) {
//        NSString *status = fileTransferWithoutManaged.status;
//
//        if ([status isEqualToString:FILE_TRANSFER_STATUS_SUCCESS]) {
//            title = NSLocalizedString(@"File downloaded", @"");
//        } else if ([status isEqualToString:FILE_TRANSFER_STATUS_PROCESSING]) {
//            NSNumber *transferredSize = fileTransferWithoutManaged.transferredSize;
//            NSNumber *totalSize = fileTransferWithoutManaged.totalSize;
//
//            if (totalSize && [totalSize doubleValue] > 0) {
//                float percentage = [Utility divideDenominator:totalSize byNumerator:transferredSize];
//
//                title = [NSString stringWithFormat:NSLocalizedString(@"Downloading (%.0f%%)", @""), percentage * 100];
//            } else {
//                title = [NSString stringWithFormat:NSLocalizedString(@"Downloading (%.0f%%)", @""), 0];
//            }
//        } else if ([status isEqualToString:FILE_TRANSFER_STATUS_CANCELING]) {
//            title = NSLocalizedString(@"Canceling", @"");
//        } else if ([status isEqualToString:FILE_TRANSFER_STATUS_FAILED]) {
//            title = NSLocalizedString(@"Downloaded failed", @"");
//        } else {
//            title = NSLocalizedString(@"Not downloaded yet", @"");
//        }
//    }
//
//    return title ? title : NSLocalizedString(@"Not downloaded yet", @"");
//}

- (UIAlertAction *)downloadOrCancelActionWithTitle:(NSString *)title realServerPath:(NSString *)realServerPath {
    UIAlertAction *alertAction = [UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        NSString *actionTitle = action.title;

        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSString *userComputerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

        FileTransferWithoutManaged *fileTransferWithoutManaged = [self.fileTransferDao findFileTransferForUserComputer:userComputerId realServerPath:realServerPath error:NULL];

        if (fileTransferWithoutManaged) {
            if ([actionTitle isEqualToString:NSLocalizedString(@"Cancel Download", @"")] && ![fileTransferWithoutManaged.status isEqualToString:FILE_TRANSFER_STATUS_SUCCESS]) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [self.fileDownloadService cancelDownloadWithTransferKey:fileTransferWithoutManaged.transferKey completionHandler:nil];
                });
            } else if ([actionTitle isEqualToString:NSLocalizedString(@"Download Again", @"")]) {
                if ([fileTransferWithoutManaged.status isEqualToString:FILE_TRANSFER_STATUS_SUCCESS]) {
                    // download from start

                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        [self downloadFileFromStartWithFileTransfer:fileTransferWithoutManaged tryAgainIfFailed:YES];
                    });
                } else if ([fileTransferWithoutManaged.status isEqualToString:FILE_TRANSFER_STATUS_FAILED]) {
                    // Use resumeData if any

                    NSError *findError;
                    NSData *resumeData = [self.fileDownloadService resumeDataFromFileTransferWithTransferKey:fileTransferWithoutManaged.transferKey error:&findError];

                    if (resumeData) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            [self resumeDownloadFileWithResumeData:resumeData fileTransfer:fileTransferWithoutManaged tryAgainIfFailed:YES];
                        });
                    } else {
                        // replace transfer key and then download from start use the new transfer key

                        // DEBUG
//                        NSLog(@"Resume data not found. Download from start with file: '%@'", fileTransferWithoutManaged.realServerPath);

                        if (fileTransferWithoutManaged.downloadGroupId) {
                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                [self downloadFileWithFailedFileTransfer:fileTransferWithoutManaged tryAgainIfFailed:YES];
                            });
                        } else {
                            // If download group id not found, meaning that the FileTransfer is downloaded before supporting download group,
                            // all re-downloaded files must delete the current FileTransfer fist.

                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                [self downloadFileFromStartWithFileTransfer:fileTransferWithoutManaged tryAgainIfFailed:YES];
                            });
                        }
                    }
                }
            }
        } else {
            [Utility viewController:self alertWithMessageTitle:@"" messageBody:NSLocalizedString(@"File not found. Try again later.", @"") actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
        }
    }];

    return alertAction;
}

- (void)resumeDownloadFileWithResumeData:(NSData *_Nonnull)resumeData fileTransfer:(FileTransferWithoutManaged *_Nonnull)fileTransfer tryAgainIfFailed:(BOOL)tryAgainIfFailed {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    NSString *tempLugServerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID];

    if (sessionId == nil || sessionId.length < 1) {
        [FilelugUtility alertEmptyUserSessionFromViewController:self];
//        [FilelugUtility alertUserNeverConnectedWithViewController:self loginSuccessHandler:^(NSURLResponse *response, NSData *data) {
//            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                self.processing = @NO;
//
//                [self resumeDownloadFileWithResumeData:resumeData fileTransfer:fileTransfer];
//            });
//        }];
    } else if (tempLugServerId == nil || tempLugServerId.length < 1) {
        [self requestConnectWithResumeData:resumeData fileTransfer:fileTransfer authService:self.authService userDefaults:userDefaults];
    } else {
        self.processing = @YES;

        SystemService *systemService = [[SystemService alloc] initWithCachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeInterval:CONNECTION_TIME_INTERVAL];

        [systemService pingDesktop:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            self.processing = @NO;

            NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

            if (statusCode == 200) {
                [SystemService parsePingDesktopResponseJson:data completionHandler:^(NSDictionary *dictionary) {
                    BOOL canDownload = YES;

                    if (dictionary) {
                        NSNumber *downloadSizeLimit = dictionary[@"download-size-limit"];

                        if (downloadSizeLimit) {
                            // 舊資料中有一些 FileTransferWithoutManaged.totalSize 的值為 0，這些都不用先比較檔案大小。

                            if (fileTransfer.totalSize && [fileTransfer.totalSize doubleValue] > 0 && [downloadSizeLimit unsignedLongLongValue] < [fileTransfer.totalSize doubleValue]) {
                                canDownload = NO;

                                NSString *message = [NSString stringWithFormat:NSLocalizedString(@"exceed.download.size.limit", @""), fileTransfer.displaySize];

                                [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                            }
                        } else {
                            canDownload = NO;

                            NSLog(@"Stop downloading file for download size limit not found. File= '%@'", fileTransfer.realServerPath);
                        }
                    }

                    // check desktop version before downloading bundle directory file
                    if (canDownload && [Utility desktopVersionLessThanOrEqualTo:@"1.1.5"]) {
                        canDownload = NO;

                        NSString *computerName = [userDefaults objectForKey:USER_DEFAULTS_KEY_COMPUTER_NAME];

                        NSString *filename = [DirectoryService filenameFromServerFilePath:fileTransfer.serverPath];

                        NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Upgrade desktop %@ before download file %@", @""), computerName, filename];

                        [Utility viewController:self alertWithMessageTitle:NSLocalizedString(@"Version Too Old", @"") messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0.1 actionHandler:nil];
                    }

                    if (canDownload) {
                        self.processing = @YES;

                        [self.fileDownloadService resumeDownloadWithRealFilePath:fileTransfer.realServerPath resumeData:resumeData completionHandler:^{
                            double delayInSeconds = 3.0;
                            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));
                            dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
                                self.processing = @NO;
                            });
                        }];
                    }
                }];
            } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
                self.processing = @YES;

                [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                    if ([userDefaults objectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID]) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            [self resumeDownloadFileWithResumeData:resumeData fileTransfer:fileTransfer tryAgainIfFailed:NO];
                        });
                    } else {
                        [self requestConnectWithResumeData:resumeData fileTransfer:fileTransfer authService:self.authService userDefaults:userDefaults];
                    }
                } failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
                    self.processing = @NO;

                    NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                    [self alertToTryDownloadAgainWithResumeData:resumeData fileTransfer:fileTransfer messagePrefix:messagePrefix response:lresponse data:ldata error:lerror];
                }];
//                [self.appService authService:self.authService reloginCurrentUserComputerFromViewController:self successHandler:^(NSURLResponse *lresponse, NSData *ldata) {
//                    self.processing = @NO;
//
//                    if ([userDefaults objectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID]) {
//                        [self resumeDownloadFileWithResumeData:resumeData fileTransfer:fileTransfer];
//                    } else {
//                        [self requestConnectWithResumeData:resumeData fileTransfer:fileTransfer authService:self.authService userDefaults:userDefaults];
//                    }
//                } failureHandler:^(NSURLResponse *lresponse, NSData *ldata, NSError *lerror) {
//                    self.processing = @NO;
//
//                    NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");
//
//                    [self alertToTryDownloadAgainWithResumeData:resumeData fileTransfer:fileTransfer messagePrefix:messagePrefix response:lresponse data:ldata error:lerror];
//                }];
            } else if (tryAgainIfFailed && statusCode == 503) {
                // server not connected, so request connection
                [self requestConnectWithResumeData:resumeData fileTransfer:fileTransfer authService:self.authService userDefaults:userDefaults];
            } else {
                self.processing = @NO;

                NSString *messagePrefix = NSLocalizedString(@"Error on download file.", @"");

                [self alertToTryDownloadAgainWithResumeData:resumeData fileTransfer:fileTransfer messagePrefix:messagePrefix response:response data:data error:error];
            }
        }];
    }
}

- (void)requestConnectWithResumeData:(NSData *_Nonnull)resumeData fileTransfer:(FileTransferWithoutManaged *)fileTransfer authService:(AuthService *)authService userDefaults:(NSUserDefaults *)userDefaults  {
    self.processing = @YES;

    [authService requestConnectWithSession:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] successHandler:^(NSURLResponse *rcresponse, NSData *rcdata) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self resumeDownloadFileWithResumeData:resumeData fileTransfer:fileTransfer tryAgainIfFailed:NO];
        });
    } failureHandler:^(NSData *rcdata, NSURLResponse *rcresponse, NSError *rcerror) {
        self.processing = @NO;

        [self alertToTryDownloadAgainWithResumeData:resumeData fileTransfer:fileTransfer messagePrefix:nil response:rcresponse data:rcdata error:rcerror];
    }];
}

- (void)alertToTryDownloadAgainWithResumeData:(NSData *_Nonnull)resumeData fileTransfer:(FileTransferWithoutManaged *)fileTransfer messagePrefix:(NSString *)messagePrefix response:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error {
    UIAlertAction *tryDownloadAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Download Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        // Request download file again
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self resumeDownloadFileWithResumeData:resumeData fileTransfer:fileTransfer tryAgainIfFailed:YES];
        });
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryDownloadAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        // Request download file again
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self resumeDownloadFileWithResumeData:resumeData fileTransfer:fileTransfer tryAgainIfFailed:NO];
        });
    }];
}

// failedFileTransfer.status must be 'failure' and failedFileTransfer.downloadGroupId can't be nil.
// If failedFileTransfer.downloadGroupId is nil, use [self downloadFileWithFileTransfer:] instead
- (void)downloadFileWithFailedFileTransfer:(FileTransferWithoutManaged *)failedFileTransfer tryAgainIfFailed:(BOOL)tryAgainIfFailed {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    NSString *tempLugServerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID];

    if (sessionId == nil || sessionId.length < 1) {
        [FilelugUtility alertEmptyUserSessionFromViewController:self];
//        [FilelugUtility alertUserNeverConnectedWithViewController:self loginSuccessHandler:^(NSURLResponse *response, NSData *data) {
//            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                self.processing = @NO;
//
//                [self downloadFileWithFailedFileTransfer:failedFileTransfer];
//            });
//        }];
    } else if (tempLugServerId == nil || tempLugServerId.length < 1) {
        [self requestConnectWithFailedFileTransfer:failedFileTransfer authService:self.authService userDefaults:userDefaults];
    } else {
        self.processing = @YES;

        SystemService *systemService = [[SystemService alloc] initWithCachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeInterval:CONNECTION_TIME_INTERVAL];

        [systemService pingDesktop:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            self.processing = @NO;

            NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

            if (statusCode == 200) {
                [SystemService parsePingDesktopResponseJson:data completionHandler:^(NSDictionary *dictionary) {
                    BOOL canDownload = YES;

                    if (dictionary) {
                        NSNumber *downloadSizeLimit = dictionary[@"download-size-limit"];

                        if (downloadSizeLimit) {
                            if ([downloadSizeLimit doubleValue] < [failedFileTransfer.totalSize doubleValue]) {
                                canDownload = NO;

                                NSString *message = [NSString stringWithFormat:NSLocalizedString(@"exceed.download.size.limit", @""), failedFileTransfer.displaySize];
                                
                                [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                            }
                        } else {
                            canDownload = NO;

                            NSLog(@"Stop downloading file for download size limit not found. File= '%@'", failedFileTransfer.realServerPath);
                        }
                    }

                    if (canDownload) {
                        self.processing = @YES;

                        // replace transfer key with new one in server

                        NSString *realServerPath = failedFileTransfer.realServerPath;

                        NSString *oldTransferKey = failedFileTransfer.transferKey;

                        NSString *transferKey = [Utility generateDownloadKeyWithSessionId:sessionId realFilePath:realServerPath];

                        NSString *downloadGroupId = failedFileTransfer.downloadGroupId;

                        [self.directoryService replaceFileDownloadTransferKey:oldTransferKey withNewTransferKey:transferKey session:sessionId completionHandler:^(NSData *dataFromReplace, NSURLResponse *responseFromReplace, NSError *errorFromReplace) {
                            NSInteger statusCodeFromCreate = [(NSHTTPURLResponse *) responseFromReplace statusCode];

                            if (!errorFromReplace && statusCodeFromCreate == 200) {
                                // download with new transfer key

                                NSString *fileSeparator = [userDefaults stringForKey:USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR];

                                NSString *actionsAfterDownload = failedFileTransfer.actionsAfterDownload;

                                NSString *userComputerId = failedFileTransfer.userComputerId;

                                @try {
                                    [self.fileDownloadService downloadFromStartWithTransferKey:transferKey realServerPath:realServerPath fileSeparator:fileSeparator downloadGroupId:downloadGroupId userComputerId:userComputerId sessionId:sessionId actionsAfterDownload:actionsAfterDownload addToStartTimestampWithMilliseconds:0 completionHandler:^() {
                                        self.processing = @NO;
                                    }];
                                } @finally {
                                    self.processing = @NO;
                                }
                            } else {
                                self.processing = @NO;

                                NSString *messagePrefix = NSLocalizedString(@"Error on download file.", @"");

                                [self alertToTryDownloadAgainWithFailedFileTransfer:failedFileTransfer messagePrefix:messagePrefix response:responseFromReplace data:dataFromReplace error:errorFromReplace];
                            }
                        }];
                    }
                }];
            } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
                self.processing = @YES;

                [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                    if ([userDefaults objectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID]) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            [self downloadFileWithFailedFileTransfer:failedFileTransfer tryAgainIfFailed:NO];
                        });
                    } else {
                        [self requestConnectWithFailedFileTransfer:failedFileTransfer authService:self.authService userDefaults:userDefaults];
                    }
                } failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
                    self.processing = @NO;

                    NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                    [self alertToTryDownloadAgainWithFailedFileTransfer:failedFileTransfer messagePrefix:messagePrefix response:lresponse data:ldata error:lerror];
                }];
//                [self.appService authService:self.authService reloginCurrentUserComputerFromViewController:self successHandler:^(NSURLResponse *lresponse, NSData *ldata) {
//                    self.processing = @NO;
//
//                    if ([userDefaults objectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID]) {
//                        [self downloadFileWithFailedFileTransfer:failedFileTransfer];
//                    } else {
//                        [self requestConnectWithFailedFileTransfer:failedFileTransfer authService:self.authService userDefaults:userDefaults];
//                    }
//                } failureHandler:^(NSURLResponse *lresponse, NSData *ldata, NSError *lerror) {
//                    self.processing = @NO;
//
//                    NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");
//
//                    [self alertToTryDownloadAgainWithFailedFileTransfer:failedFileTransfer messagePrefix:messagePrefix response:lresponse data:ldata error:lerror];
//                }];
            } else if (tryAgainIfFailed && statusCode == 503) {
                // server not connected, so request connection
                [self requestConnectWithFailedFileTransfer:failedFileTransfer authService:self.authService userDefaults:userDefaults];
            } else {
                self.processing = @NO;

                NSString *messagePrefix = NSLocalizedString(@"Error on download file.", @"");

                [self alertToTryDownloadAgainWithFailedFileTransfer:failedFileTransfer messagePrefix:messagePrefix response:response data:data error:error];
            }
        }];
    }
}

- (void)requestConnectWithFailedFileTransfer:(FileTransferWithoutManaged *)failedFileTransfer authService:(AuthService *)authService userDefaults:(NSUserDefaults *)userDefaults  {
    self.processing = @YES;

    [authService requestConnectWithSession:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] successHandler:^(NSURLResponse *rcresponse, NSData *rcdata) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self downloadFileWithFailedFileTransfer:failedFileTransfer tryAgainIfFailed:NO];
        });
    } failureHandler:^(NSData *rcdata, NSURLResponse *rcresponse, NSError *rcerror) {
        self.processing = @NO;

        [self alertToTryDownloadAgainWithFailedFileTransfer:failedFileTransfer messagePrefix:nil response:rcresponse data:rcdata error:rcerror];
    }];
}

- (void)alertToTryDownloadAgainWithFailedFileTransfer:(FileTransferWithoutManaged *)failedFileTransfer messagePrefix:(NSString *)messagePrefix response:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error {
    UIAlertAction *tryDownloadAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Download Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        // Request download file again
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self downloadFileWithFailedFileTransfer:failedFileTransfer tryAgainIfFailed:YES];
        });
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryDownloadAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        // Request download file again
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self downloadFileWithFailedFileTransfer:failedFileTransfer tryAgainIfFailed:NO];
        });
    }];
}

- (void)downloadFileFromStartWithFileTransfer:(FileTransferWithoutManaged *)fileTransfer tryAgainIfFailed:(BOOL)tryAgainIfFailed {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    NSString *tempLugServerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID];

    if (sessionId == nil || sessionId.length < 1) {
        [FilelugUtility alertEmptyUserSessionFromViewController:self];
//        [FilelugUtility alertUserNeverConnectedWithViewController:self loginSuccessHandler:^(NSURLResponse *response, NSData *data) {
//            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                self.processing = @NO;
//
//                [self downloadFileFromStartWithFileTransfer:fileTransfer];
//            });
//        }];
    } else if (tempLugServerId == nil || tempLugServerId.length < 1) {
        [self requestConnectForDownloadFromStartWithAuthService:self.authService userDefaults:userDefaults fileTransfer:fileTransfer];
    } else {
        self.processing = @YES;

        SystemService *systemService = [[SystemService alloc] initWithCachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeInterval:CONNECTION_TIME_INTERVAL];

        [systemService pingDesktop:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            self.processing = @NO;

            NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

            if (statusCode == 200) {
                [SystemService parsePingDesktopResponseJson:data completionHandler:^(NSDictionary *dictionary) {
                    BOOL canDownload = YES;

                    if (dictionary) {
                        NSNumber *downloadSizeLimit = dictionary[@"download-size-limit"];

                        if (downloadSizeLimit) {
                            if ([downloadSizeLimit unsignedLongLongValue] < [fileTransfer.totalSize doubleValue]) {
                                canDownload = NO;

                                NSString *message = [NSString stringWithFormat:NSLocalizedString(@"exceed.download.size.limit", @""), fileTransfer.displaySize];
                                
                                [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                            }
                        } else {
                            canDownload = NO;

                            NSLog(@"Stop downloading file for download size limit not found. File= '%@'", fileTransfer.realServerPath);
                        }
                    }

                    if (canDownload) {
                        self.processing = @YES;

                        // create download summary in server

                        NSString *fileSeparator = [userDefaults stringForKey:USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR];

                        NSMutableDictionary *transferKeyAndRealFilePaths = [NSMutableDictionary dictionary];

                        NSMutableArray *filenames = [NSMutableArray array];

                        NSMutableArray *transferKeys = [NSMutableArray array];

                        NSString *realServerPath = fileTransfer.realServerPath;

                        NSString *realFilename = [DirectoryService filenameFromServerFilePath:realServerPath];

                        [filenames addObject:realFilename];

                        // generate new transfer key - unique for all users
                        NSString *transferKey = [Utility generateDownloadKeyWithSessionId:sessionId realFilePath:realServerPath];

                        [transferKeys addObject:transferKey];

                        transferKeyAndRealFilePaths[transferKey] = fileTransfer.realServerPath;

                        NSInteger notificationType = [[[DownloadNotificationService alloc] initWithPersistedType].type integerValue];

                        NSString *downloadGroupId = [Utility generateDownloadGroupIdWithFilenames:filenames];

                        [self.directoryService createFileDownloadSummaryWithDownloadGroupId:downloadGroupId
                                                                transferKeyAndRealFilePaths:transferKeyAndRealFilePaths
                                                                           notificationType:notificationType
                                                                                    session:sessionId
                                                                          completionHandler:^(NSData *dataFromCreate, NSURLResponse *responseFromCreate, NSError *errorFromCreate) {
                              NSInteger statusCodeFromCreate = [(NSHTTPURLResponse *) responseFromCreate statusCode];

                              if (!errorFromCreate && statusCodeFromCreate == 200) {
                                  // Save file-download-group to local db before download each files

                                  NSString *userComputerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

                                  [self.fileDownloadGroupDao createFileDownloadGroupWithDownloadGroupId:downloadGroupId
                                                                                       notificationType:notificationType
                                                                                         userComputerId:userComputerId
                                                                                      completionHandler:^() {
                                      // download file

                                      @try {
                                          // set actions after download
                                          NSString *actionsAfterDownload = [FileTransferWithoutManaged prepareActionsAfterDownloadWithOpen:NO share:NO];

                                          [self.fileDownloadService downloadFromStartWithTransferKey:transferKey realServerPath:realServerPath fileSeparator:fileSeparator downloadGroupId:downloadGroupId userComputerId:userComputerId sessionId:sessionId actionsAfterDownload:actionsAfterDownload addToStartTimestampWithMilliseconds:0 completionHandler:^() {
                                              self.processing = @NO;
                                          }];
                                      } @finally {
                                          self.processing = @NO;
                                      }
                                  }];
                              } else {
                                  self.processing = @NO;

                                  NSString *messagePrefix = NSLocalizedString(@"Error on download file.", @"");

                                  [self alertToTryDownloadAgainWithFileTransfer:fileTransfer messagePrefix:messagePrefix response:responseFromCreate data:dataFromCreate error:errorFromCreate];
                              }
                          }];
                    }
                }];
            } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
                self.processing = @YES;

                [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                    if ([userDefaults objectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID]) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            [self downloadFileFromStartWithFileTransfer:fileTransfer tryAgainIfFailed:NO];
                        });
                    } else {
                        [self requestConnectForDownloadFromStartWithAuthService:self.authService userDefaults:userDefaults fileTransfer:fileTransfer];
                    }
                } failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
                    self.processing = @NO;

                    NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                    [self alertToTryDownloadAgainWithFileTransfer:fileTransfer messagePrefix:messagePrefix response:lresponse data:ldata error:lerror];
                }];
//                [self.appService authService:self.authService reloginCurrentUserComputerFromViewController:self successHandler:^(NSURLResponse *lresponse, NSData *ldata) {
//                    self.processing = @NO;
//
//                    if ([userDefaults objectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID]) {
//                        [self downloadFileFromStartWithFileTransfer:fileTransfer];
//                    } else {
//                        [self requestConnectForDownloadFromStartWithAuthService:self.authService userDefaults:userDefaults fileTransfer:fileTransfer];
//                    }
//                } failureHandler:^(NSURLResponse *lresponse, NSData *ldata, NSError *lerror) {
//                    self.processing = @NO;
//
//                    NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");
//
//                    [self alertToTryDownloadAgainWithFileTransfer:fileTransfer messagePrefix:messagePrefix response:lresponse data:ldata error:lerror];
//                }];
            } else if (tryAgainIfFailed && statusCode == 503) {
                // server not connected, so request connection
                [self requestConnectForDownloadFromStartWithAuthService:self.authService userDefaults:userDefaults fileTransfer:fileTransfer];
            } else {
                self.processing = @NO;

                NSString *messagePrefix = NSLocalizedString(@"Error on download file.", @"");

                [self alertToTryDownloadAgainWithFileTransfer:fileTransfer messagePrefix:messagePrefix response:response data:data error:error];
            }
        }];
    }
}

- (void)requestConnectForDownloadFromStartWithAuthService:(AuthService *)authService userDefaults:(NSUserDefaults *)userDefaults fileTransfer:(FileTransferWithoutManaged *)fileTransfer {
    self.processing = @YES;

    [authService requestConnectWithSession:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] successHandler:^(NSURLResponse *rcresponse, NSData *rcdata) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self downloadFileFromStartWithFileTransfer:fileTransfer tryAgainIfFailed:NO];
        });
    } failureHandler:^(NSData *rcdata, NSURLResponse *rcresponse, NSError *rcerror) {
        self.processing = @NO;

        [self alertToTryDownloadAgainWithFileTransfer:fileTransfer messagePrefix:nil response:rcresponse data:rcdata error:rcerror];
    }];
}

- (void)alertToTryDownloadAgainWithFileTransfer:(FileTransferWithoutManaged *)fileTransfer messagePrefix:(NSString *)messagePrefix response:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error {
    UIAlertAction *tryDownloadAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Download Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        // Request download file again
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self downloadFileFromStartWithFileTransfer:fileTransfer tryAgainIfFailed:YES];
        });
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryDownloadAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        // Request download file again
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self downloadFileFromStartWithFileTransfer:fileTransfer tryAgainIfFailed:NO];
        });
    }];
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

- (void)tableView:(UITableView *)tableView showOptionMenuViewControllerWithFileTransferKey:(NSString *)transferKey {
    FileTransferWithoutManaged *fileTransferWithoutManaged = [self.fileTransferDao findFileTransferForTransferKey:transferKey error:NULL];

    if (fileTransferWithoutManaged && fileTransferWithoutManaged.localPath) {
        NSString *localRelPath = fileTransferWithoutManaged.localPath;

        NSUserDefaults *userDefaults = [Utility groupUserDefaults];
        NSString *userComputerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];
        NSString *absoluteFilePath = [DirectoryService absoluteFilePathFromLocalPath:localRelPath userComputerId:userComputerId];
        NSURL *fileURL = [NSURL fileURLWithPath:absoluteFilePath];

        UIDocumentInteractionController *documentInteractionController = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
        documentInteractionController.delegate = self;

        self.keptController = documentInteractionController;

        CGRect fromRect = self.view.frame;
        UIView *inView = self.view;

        if ([Utility isIPad]) {
            BOOL foundSelectedCell = NO;

            NSIndexPath *selectedIndexPath = [tableView indexPathForSelectedRow];

            if (selectedIndexPath) {
                UITableViewCell *selectedCell = [tableView cellForRowAtIndexPath:selectedIndexPath];

                if (selectedCell) {
                    inView = selectedCell;
                    fromRect = selectedCell.bounds;

                    foundSelectedCell = YES;
                }
            }

            if (!foundSelectedCell) {
                NSArray *indexPaths = [tableView indexPathsForVisibleRows];

                if (indexPaths && [indexPaths count] > 0) {
                    UITableViewCell *firstCell = [tableView cellForRowAtIndexPath:indexPaths[0]];

                    if (firstCell) {
                        inView = firstCell;
                        fromRect = firstCell.bounds;
                    }
                }
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [documentInteractionController presentOptionsMenuFromRect:fromRect inView:inView animated:YES];
        });
    } else {
        [Utility viewController:self alertWithMessageTitle:@"" messageBody:NSLocalizedString(@"File not found. Try again later.", @"") actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
    }
}

- (void)copyFilePathWithFileTransferKey:(NSString *)transferKey {
    FileTransferWithoutManaged *fileTransferWithoutManaged = [self.fileTransferDao findFileTransferForTransferKey:transferKey error:NULL];

    if (fileTransferWithoutManaged && fileTransferWithoutManaged.realServerPath) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        [pasteboard setString:fileTransferWithoutManaged.realServerPath];

        [self.appService showToastAlertWithTableView:self.tableView message:NSLocalizedString(@"Path Copied", @"") completionHandler:^{
            // deselect row

            NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];

            if (selectedIndexPath) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.tableView deselectRowAtIndexPath:selectedIndexPath animated:YES];
                });
            }
        }];
    } else {
        [Utility viewController:self alertWithMessageTitle:@"" messageBody:NSLocalizedString(@"File not found. Try again later.", @"") actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
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
        title = [self.fileTransferDao fetchedResultsController:self.fetchedResultsController titleForHeaderInSection:section includingComputerName:NO];
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
    static NSString *CellIdentifier = @"DownloadFileCell";
    UITableViewCell *cell;

    // To prevent app terminated due to uncaught exception 'NSInternalInconsistencyException':
    // An exception was caught from the delegate of NSFetchedResultsController during a call to -controllerDidChangeContent: ...
    @try {
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];

        // configure the preferred font

        cell.imageView.image = [UIImage imageNamed:@"ic_folder"];

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
    return YES;
}

//#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
//// for iOS 11 or above only
//
//// Return the swipe actions to display next to the leading edge of the row. Return nil if you want the table to display the default set of actions.
//- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
//    return nil;
//}
//
//// Return the swipe actions to display next to the trailing edge of the row. Return nil if you want the table to display the default set of actions.
//- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
//    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:NSLocalizedString(@"Delete", @"") handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
//        [self deleteRowAtIndexPath:indexPath];
//    }];
//
//    return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
//}
//
//#else

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self deleteRowAtIndexPath:indexPath];
    }
}

//#endif

- (void)deleteRowAtIndexPath:(NSIndexPath *)indexPath {
    dispatch_queue_t gQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    dispatch_async(gQueue, ^{
        /* Use this instead of another one to get the real status, not the cached one.
         *
         * The method combines two methods to prevent error:
         * NSInternalInconsistencyException, reason: statement is still active
         * for using the same moc.
         */
        FileTransferWithoutManaged *fileTransferWithoutManaged = [self.fileTransferDao findFileTransferForFetchedResultsController:self.fetchedResultsController objectAtIndexPath:indexPath];

        if (fileTransferWithoutManaged) {
            NSString *status = fileTransferWithoutManaged.status;
            NSString *realServerPath = fileTransferWithoutManaged.realServerPath;

            if (status && [status isEqualToString:FILE_TRANSFER_STATUS_SUCCESS]) {
                // make sure there's no upload for this downloaded file before deleting
                [self deleteSuccessfullyDownloadedFileWithFileTransferWithoutManaged:fileTransferWithoutManaged
                                                                      delayInSeconds:0.5
                                                                    dispatch_queue_t:gQueue
                                                                        alertIfError:YES
                                                                 cancelDeleteHandler:^{
                                                                     [self performSelector:@selector(cancelTableViewCellDelete:) withObject:nil afterDelay:0.1];
                                                                 }];
            } else {
                [self.fileDownloadService cancelDownloadWithTransferKey:fileTransferWithoutManaged.transferKey completionHandler:^() {
                    [self deleteDownloadedFileWithFileTransferKey:fileTransferWithoutManaged.transferKey realServerPath:realServerPath delayInSeconds:0.5 dispatch_queue_t:gQueue alertIfError:YES];
                }];
            }
        }
    });
}

- (void)cancelTableViewCellDelete:(id)sender {
    [self.tableView setEditing:NO animated:YES];

    [self deselectTableViewCell:nil];
}

- (void)deleteDownloadedFileWithFileTransferKey:(NSString *)fileTransferKey realServerPath:(NSString *)realServerPath delayInSeconds:(double)delayInSeconds dispatch_queue_t:(dispatch_queue_t)t alertIfError:(BOOL)alertIfError {
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, t, ^(void) {
        [self.fileTransferDao deleteFileTransferForTransferKey:fileTransferKey successHandler:^() {
            // clear download information in correspondent HierarchicalModels
            [self.hierarchicalModelDao removeDownloadInformationInHierarchicalModelsWithTransferKey:fileTransferKey completionHandler:^{

                /* Delete file saved in local, if any.
                 * Usually the local file not exists if file downloaded not completed.
                 * In some cases, such as delete the FileTransfer of a successfully downloaded file A, but not delete the real file A.
                 * Later download the same file A and delete the FileTransfer while file A is downloading.
                 * In such case, the underline file A never be accessed because its FileTransfer is deleted.
                 */

                dispatch_async(t, ^{
                    [DirectoryService deleteLocalFileWithRealServerPath:realServerPath completionHandler:^(NSError *deleteError) {
                        if (deleteError && alertIfError) {
                            NSLog(@"Failed to delete file: %@\n%@", realServerPath, [deleteError userInfo]);

                            NSString *message = NSLocalizedString(@"Error on deleting file.", @"");

                            [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:^(UIAlertAction *action) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [self.tableView setEditing:NO animated:YES];

                                    [self.tableView reloadData];
                                });
                            }];
                        } else {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self.tableView setEditing:NO animated:YES];

                                [self.tableView reloadData];
                            });
                        }
                    }];
                });
            }];
        } errorHandler:^(NSError *error) {
            if (error && alertIfError) {
                NSString *message = (error.userInfo)[NSLocalizedDescriptionKey];

                [Utility viewController:self alertWithMessageTitle:@"" messageBody:(message ? message : NSLocalizedString(@"Error on deleting record.", @"")) actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
            }
        }];
    });
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

- (IBAction)addFile:(id)sender {
    FileDownloadProcessService *fileDownloadProcessService = [[FilelugUtility applicationDelegate] fileDownloadProcessService];

    [fileDownloadProcessService reset];

    RootDirectoryViewController *rootDirectoryViewController = [Utility instantiateViewControllerWithIdentifier:@"RootDirectory"];

    rootDirectoryViewController.fromViewController = self;
    rootDirectoryViewController.directoryOnly = NO;

    if (rootDirectoryViewController.navigationItem) {
        [rootDirectoryViewController.navigationItem setTitle:NSLocalizedString(@"Choose File", @"")];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.navigationController pushViewController:rootDirectoryViewController animated:YES];
    });
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
//        // DEBUG
//        NSLog(@"fileTransferWithoutManaged.localPath:\n%@", fileTransferWithoutManaged.localPath);

        cell.textLabel.text = [fileTransferWithoutManaged.localPath lastPathComponent];
        cell.imageView.image = [DirectoryService imageForLocalFilePath:fileTransferWithoutManaged.localPath isDirectory:NO];

        NSString *downloadStatus = fileTransferWithoutManaged.status;

        NSString *downloadStatusDescription;

        UIColor *downloadStatusColor;

        if ([downloadStatus isEqualToString:FILE_TRANSFER_STATUS_PROCESSING]) {
            NSNumber *transferredSize = fileTransferWithoutManaged.transferredSize;
            NSNumber *totalSize = fileTransferWithoutManaged.totalSize;

            float percentage = [Utility divideDenominator:totalSize byNumerator:transferredSize];

            downloadStatusDescription = [NSString stringWithFormat:@"%@(%.0f%%)", NSLocalizedString(@"File is downloading", @""), percentage * 100];

            downloadStatusColor = [UIColor aquaColor];
        } else if ([downloadStatus isEqualToString:FILE_TRANSFER_STATUS_SUCCESS]) {
            downloadStatusDescription = NSLocalizedString(@"File downloaded", @"");

            downloadStatusColor = [UIColor darkGrayColor];
        } else if ([downloadStatus isEqualToString:FILE_TRANSFER_STATUS_CANCELING]) {
            downloadStatusDescription = NSLocalizedString(@"Download canceling", @"");

            downloadStatusColor = [UIColor redColor];
        } else if ([downloadStatus isEqualToString:FILE_TRANSFER_STATUS_FAILED]) {
            downloadStatusDescription = NSLocalizedString(@"Downloaded failed", @"");

            downloadStatusColor = [UIColor redColor];
        } else {
            downloadStatusDescription = NSLocalizedString(@"Download Preparing", @"");

            downloadStatusColor = [UIColor aquaColor];
        }

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
            detailLabelText = [NSString stringWithFormat:@"%@, %@, %@", downloadStatusDescription, displaySize, lastModified];
        } else {
            detailLabelText = [NSString stringWithFormat:@"%@, %@", downloadStatusDescription, displaySize];
        }

        NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:detailLabelText];
        [attributedString setText:downloadStatusDescription withColor:downloadStatusColor];
        [attributedString setText:displaySize withColor:[UIColor darkGrayColor]];
        [attributedString setText:lastModified withColor:[UIColor lightGrayColor]];

        [cell.detailTextLabel setAttributedText:attributedString];
                
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

// Invoked when user click notification on file downloaded successfully
// Make sure the view of DownloadFileViewController shows before the method is invoked.
- (void)previewFileFromDownloadTransferKey:(nullable NSString *)transferKey {
    if (transferKey) {
        FileTransferWithoutManaged *fileTransferWithoutManaged = [self.fileTransferDao findFileTransferForTransferKey:transferKey error:NULL];
        
        if (fileTransferWithoutManaged) {
            UIAlertAction *deleteFileAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Delete File", @"") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
                dispatch_queue_t gQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

                dispatch_async(gQueue, ^{
                    NSString *status = fileTransferWithoutManaged.status;
                    NSString *realServerPath = fileTransferWithoutManaged.realServerPath;

                    if (status && [status isEqualToString:FILE_TRANSFER_STATUS_SUCCESS]) {
                        // make sure the downloaded file is not used for upload before deleting

                        [self deleteSuccessfullyDownloadedFileWithFileTransferWithoutManaged:fileTransferWithoutManaged
                                                                              delayInSeconds:0
                                                                            dispatch_queue_t:gQueue
                                                                                alertIfError:YES
                                                                         cancelDeleteHandler:^{
                                                                             // de-select the cell
                                                                             [self performSelector:@selector(deselectTableViewCell:) withObject:nil afterDelay:0.1];
                                                                         }];
                    } else {
                        [self.fileDownloadService cancelDownloadWithTransferKey:fileTransferWithoutManaged.transferKey completionHandler:^() {
                            [self deleteDownloadedFileWithFileTransferKey:fileTransferWithoutManaged.transferKey realServerPath:realServerPath delayInSeconds:0 dispatch_queue_t:gQueue alertIfError:YES];
                        }];
                    }
                });
            }];

            NSIndexPath *indexPath = [self.fileTransferDao fetchedResultsController:self.fetchedResultsController indexPathForTransferKey:transferKey];

            if (indexPath || [Utility isIPhone]) {
                [self showActionSheetWithTableView:self.tableView fileTransferWithoutManaged:fileTransferWithoutManaged alertActionToDeleteFile:deleteFileAction selectedRowAtIndexPath:indexPath];
            }
        }
    }
}

- (void)deselectTableViewCell:(id)sender {
    NSIndexPath *selectedRowIndexPath = [self.tableView indexPathForSelectedRow];

    if (selectedRowIndexPath) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView deselectRowAtIndexPath:selectedRowIndexPath animated:YES];
        });
    }
}

- (void)deleteSuccessfullyDownloadedFileWithFileTransferWithoutManaged:(FileTransferWithoutManaged *)fileTransferWithoutManaged
                                                        delayInSeconds:(double)delayInSeconds
                                                      dispatch_queue_t:(dispatch_queue_t)queue
                                                          alertIfError:(BOOL)alertIfError
                                                   cancelDeleteHandler:(void (^)(void))cancelDeleteHandler {
    // make sure the downloaded file is not used for upload

    NSString *transferKey = fileTransferWithoutManaged.transferKey;
    NSString *realServerPath = fileTransferWithoutManaged.realServerPath;

    [self.assetFileDao findAssetFileForDownloadedFileTransferKey:transferKey completionHandler:^(NSArray<AssetFileWithoutManaged *> *assetFileWithoutManageds, NSError *error) {
        BOOL foundInAssetFile = NO;

        if (assetFileWithoutManageds && [assetFileWithoutManageds count] > 0) {
            // 1. check current user computer

            // 1-1 check if the file is uploading

            for (AssetFileWithoutManaged *assetFileWithoutManaged in assetFileWithoutManageds) {
                if ([assetFileWithoutManaged.userComputerId isEqualToString:fileTransferWithoutManaged.userComputerId]) {
                    if ([assetFileWithoutManaged.status isEqualToString:FILE_TRANSFER_STATUS_PREPARING]
                            || [assetFileWithoutManaged.status isEqualToString:FILE_TRANSFER_STATUS_PROCESSING]
                            || [assetFileWithoutManaged.status isEqualToString:FILE_TRANSFER_STATUS_CONFIRMING]
                            || [assetFileWithoutManaged.status isEqualToString:FILE_TRANSFER_STATUS_CANCELING]) {
                        foundInAssetFile = YES;

                        [Utility viewController:self alertWithMessageTitle:@"" messageBody:NSLocalizedString(@"File is uploading and cannot be deleted.", @"") actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:^(UIAlertAction *action) {
                            if (cancelDeleteHandler) {
                                cancelDeleteHandler();
                            }
                        }];

                        break;
                    }
                }
            }

            // 1-2 check if the file ever failed to upload

            if (!foundInAssetFile) {
                for (AssetFileWithoutManaged *assetFileWithoutManaged in assetFileWithoutManageds) {
                    if ([assetFileWithoutManaged.status isEqualToString:FILE_TRANSFER_STATUS_FAILED]) {
                        foundInAssetFile = YES;

                        NSString *uploadUserComputerId = assetFileWithoutManaged.userComputerId;
                        NSString *downloadUserComputerId = fileTransferWithoutManaged.userComputerId;

                        NSString *messageBody;

                        if (![uploadUserComputerId isEqualToString:downloadUserComputerId]) {
                            UserComputerWithoutManaged *uploadUserComputerWithoutManaged = [self.userComputerDao findUserComputerForUserComputerId:uploadUserComputerId];

                            UserComputerWithoutManaged *downloadUserComputerWithoutManaged = [self.userComputerDao findUserComputerForUserComputerId:downloadUserComputerId];

                            if (uploadUserComputerWithoutManaged
                                    && downloadUserComputerWithoutManaged
                                    && [uploadUserComputerWithoutManaged.userId isEqualToString:downloadUserComputerWithoutManaged.userId]) {
                                // same user, different computers

                                NSString *uploadComputerName = uploadUserComputerWithoutManaged.computerName;

                                messageBody = [NSString stringWithFormat:NSLocalizedString(@"File failed to upload to computer %@ and cannot upload it again if deleted.", @""), uploadComputerName];
                            } else if (uploadUserComputerWithoutManaged) {
                                // different users, different computers

                                NSString *userId = uploadUserComputerWithoutManaged.userId;

                                UserWithoutManaged *userWithoutManaged = [self.userDao findUserWithoutManagedById:userId error:NULL];

                                if (userWithoutManaged && userWithoutManaged.nickname && userWithoutManaged.nickname.length > 0) {
                                    NSString *uploadUserNickname = userWithoutManaged.nickname;
                                    NSString *uploadComputerName = uploadUserComputerWithoutManaged.computerName;

                                    messageBody = [NSString stringWithFormat:NSLocalizedString(@"%@ failed to upload file to computer %@ and cannot upload it again if deleted.", @""), uploadUserNickname, uploadComputerName];
                                }
                            }
                        }

                        if (!messageBody) {
                            messageBody = NSLocalizedString(@"File failed to upload and cannot upload it again if deleted.", @"");
                        }

                        [Utility viewController:self alertWithMessageTitle:@"" messageBody:messageBody actionTitle:NSLocalizedString(@"Delete File", @"") containsCancelAction:YES cancelTitle:NSLocalizedString(@"Cancel", @"") delayInSeconds:0 actionHandler:^(UIAlertAction *action) {
                            [self deleteDownloadedFileWithFileTransferKey:transferKey realServerPath:realServerPath delayInSeconds:delayInSeconds dispatch_queue_t:queue alertIfError:alertIfError];
                        } cancelHandler:^(UIAlertAction *action) {
                            if (cancelDeleteHandler) {
                                cancelDeleteHandler();
                            }
                        }];

                        break;
                    }
                }
            }

            // 1-3 check if the file ever uploaded successfully

            if (!foundInAssetFile) {
                for (AssetFileWithoutManaged *assetFileWithoutManaged in assetFileWithoutManageds) {
                    if ([assetFileWithoutManaged.status isEqualToString:FILE_TRANSFER_STATUS_SUCCESS]) {
                        foundInAssetFile = YES;

                        NSString *uploadUserComputerId = assetFileWithoutManaged.userComputerId;
                        NSString *downloadUserComputerId = fileTransferWithoutManaged.userComputerId;

                        NSString *messageBody;

                        if (![uploadUserComputerId isEqualToString:downloadUserComputerId]) {
                            UserComputerWithoutManaged *uploadUserComputerWithoutManaged = [self.userComputerDao findUserComputerForUserComputerId:uploadUserComputerId];

                            UserComputerWithoutManaged *downloadUserComputerWithoutManaged = [self.userComputerDao findUserComputerForUserComputerId:downloadUserComputerId];

                            if (uploadUserComputerWithoutManaged
                                    && downloadUserComputerWithoutManaged
                                    && [uploadUserComputerWithoutManaged.userId isEqualToString:downloadUserComputerWithoutManaged.userId]) {
                                // same user, different computers

                                NSString *uploadComputerName = uploadUserComputerWithoutManaged.computerName;

                                messageBody = [NSString stringWithFormat:NSLocalizedString(@"File ever uploaded to computer %@ and cannot preview it if deleted.", @""), uploadComputerName];
                            } else if (uploadUserComputerWithoutManaged) {
                                // different users, different computers

                                NSString *userId = uploadUserComputerWithoutManaged.userId;

                                UserWithoutManaged *userWithoutManaged = [self.userDao findUserWithoutManagedById:userId error:NULL];

                                if (userWithoutManaged && userWithoutManaged.nickname && userWithoutManaged.nickname.length > 0) {
                                    NSString *uploadUserNickname = userWithoutManaged.nickname;
                                    NSString *uploadComputerName = uploadUserComputerWithoutManaged.computerName;

                                    messageBody = [NSString stringWithFormat:NSLocalizedString(@"%@ uploaded the file to computer %@ and cannot preview it if deleted.", @""), uploadUserNickname, uploadComputerName];
                                }
                            }
                        }

                        if (!messageBody) {
                            messageBody = NSLocalizedString(@"File ever uploaded and cannot preview it if deleted.", @"");
                        }

                        [Utility viewController:self alertWithMessageTitle:@"" messageBody:messageBody actionTitle:NSLocalizedString(@"Delete File", @"") containsCancelAction:YES cancelTitle:NSLocalizedString(@"Cancel", @"'") delayInSeconds:0 actionHandler:^(UIAlertAction *action) {
                            [self deleteDownloadedFileWithFileTransferKey:transferKey realServerPath:realServerPath delayInSeconds:delayInSeconds dispatch_queue_t:queue alertIfError:alertIfError];
                        } cancelHandler:^(UIAlertAction *action) {
                            if (cancelDeleteHandler) {
                                cancelDeleteHandler();
                            }
                        }];

                        break;
                    }
                }
            }
        }

        if (!foundInAssetFile) {
            [self deleteDownloadedFileWithFileTransferKey:transferKey realServerPath:realServerPath delayInSeconds:delayInSeconds dispatch_queue_t:queue alertIfError:alertIfError];
        }
    }];
}

// The method can work only when the application is not in the background.
// If you need something done even when the application is the background, do it in the FileTransferService
- (void)onFileDownloadDidResumeNotification:(NSNotification *)notification {
    double delayInSeconds = 1.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        self.processing = @NO;
    });
}

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
