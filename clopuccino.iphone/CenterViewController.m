#import "CenterViewController.h"
#import "FileInfoViewController.h"
#import "AppService.h"
#import "FilelugUtility.h"
#import "FilePreviewController.h"
#import "FilelugFileDownloadService.h"

@interface CenterViewController ()

@property(nonatomic, strong) HierarchicalModelDao *hierarchicalModelDao;

@property(nonatomic, strong) NSFetchedResultsController *fetchedResultsController;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) AppService *appService;

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

@property(nonatomic, strong) FileTransferDao *fileTransferDao;

// Keep the reference to prevent error like: 'UIDocumentInteractionController/QLPreviewController has gone away prematurely!'
@property(nonatomic, strong) id keptController;

@property(nonatomic, strong) DirectoryService *directoryService;

@property(nonatomic, strong) FileDownloadGroupDao *fileDownloadGroupDao;

@property(nonatomic, strong) FilelugFileDownloadService *fileDownloadService;

@property(nonatomic, strong) RecentDirectoryService *recentDirectoryService;

@end

@implementation CenterViewController

@synthesize processing;
    
@synthesize progressView;

- (void)viewDidLoad {
    [super viewDidLoad];

    self.processing = @NO;

    [Utility viewController:self useNavigationLargeTitles:YES];

    _preferredContentSizeCategoryService = [[PreferredContentSizeCategoryService alloc] init];

    // refresh control
    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];

    [refresh setAttributedTitle:[[NSAttributedString alloc] initWithString:NSLocalizedString(@"Pull to refresh", @"")]];

    self.refreshControl = refresh;

    // Change the back button for the next view controller
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Back", @"") style:UIBarButtonItemStylePlain target:nil action:nil];

    [self.navigationItem setBackBarButtonItem:backButton];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // Set the title
    if (self.parentPath) {
        [self.navigationItem setTitle:[DirectoryService directoryNameFromServerDirectoryPath:self.parentPath]];
    }

    [self.hierarchicalModelDao fetchedResultsController:self.fetchedResultsController performFetch:NULL];

    // adding observers

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangePreferredContentSize:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];

    [self addObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];

    [self.refreshControl addTarget:self action:@selector(resyncHierarchicalModels:) forControlEvents:UIControlEventValueChanged];

//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onFileDownloadDidCompleteNotification:) name:NOTIFICATION_NAME_FILE_DOWNLOAD_DID_COMPLETE object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onFileDownloadDidResumeNotification:) name:NOTIFICATION_NAME_FILE_DOWNLOAD_DID_RESUME object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.refreshControl) {
            [self.refreshControl endRefreshing];
        }
    });

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *userComputerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];
    if (!userComputerId) {
        if (self.navigationController) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.navigationController popToRootViewControllerAnimated:YES];
            });
        }
    } else {
        // do only when NOT back from its sub CenterViewController
        if ([self isMovingToParentViewController]) {
            [self syncHierarchicalModels];
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_NAME_FILE_DOWNLOAD_DID_RESUME object:nil];

//    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_NAME_FILE_DOWNLOAD_DID_COMPLETE object:nil];

    [self.refreshControl removeTarget:self action:@selector(resyncHierarchicalModels:) forControlEvents:UIControlEventValueChanged];

    [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) context:NULL];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (HierarchicalModelDao *)hierarchicalModelDao {
    if (!_hierarchicalModelDao) {
        _hierarchicalModelDao = [[HierarchicalModelDao alloc] init];
    }

    return _hierarchicalModelDao;
}

- (NSFetchedResultsController *)fetchedResultsController {
    if (!_fetchedResultsController) {
        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSString *userComputerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

        _fetchedResultsController = [self.hierarchicalModelDao createHierarchicalModelsFetchedResultsControllerForUserComputer:userComputerId parent:self.parentPath directoryOnly:self.directoryOnly delegate:self];
    }

    return _fetchedResultsController;
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

- (FileTransferDao *)fileTransferDao {
    if (!_fileTransferDao) {
        _fileTransferDao = [[FileTransferDao alloc] init];
    }

    return _fileTransferDao;
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

- (RecentDirectoryService *)recentDirectoryService {
    if (!_recentDirectoryService) {
        _recentDirectoryService = [[RecentDirectoryService alloc] init];
    }

    return _recentDirectoryService;
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

                    if (self.refreshControl) {
                        [self.refreshControl endRefreshing];
                    }
                }
            });
        }
    }
}

- (void)resyncHierarchicalModels:(id)sender {
    [self syncHierarchicalModels];
}

- (void)syncHierarchicalModels {
    /* keep the current parent path,
     * in case the value changed when getting data back and
     * try to synchronized with the existing ones.
     */
    NSString *targetParentPath = [NSString stringWithString:self.parentPath];

    // fetch from server, save to DB, then retrieve from DB
    [self internalSyncHierarchicalModelsWithTargetParentPath:targetParentPath tryAgainIfFailed:YES];
}

- (void)internalSyncHierarchicalModelsWithTargetParentPath:(NSString *)targetParentPath tryAgainIfFailed:(BOOL)tryAgainIfFailed {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

        NSString *tempLugServerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID];

        if (sessionId == nil || sessionId.length < 1) {
            [FilelugUtility alertEmptyUserSessionFromViewController:self];
        } else if (tempLugServerId == nil || tempLugServerId.length < 1) {
            [self requestConnectForSyncHierarchicalModelsWithAuthService:self.authService userDefaults:userDefaults targetParentPath:targetParentPath];
        } else {
            if (targetParentPath) {
                self.processing = @YES;

                DirectoryService *directoryService = [[DirectoryService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];

                [directoryService listDirectoryChildrenWithParent:targetParentPath session:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                    self.processing = @NO;

                    NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

                    if (statusCode == 200) {
                        NSString *userComputerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

                        [self.hierarchicalModelDao parseJsonAndSyncWithCurrentHierarchicalModels:data userComputer:userComputerId parentPath:targetParentPath completionHandler:^{
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self.tableView reloadData];
                            });
                        }];
                    } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
                        self.processing = @YES;

                        [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                            if ([userDefaults objectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID]) {
                                [self internalSyncHierarchicalModelsWithTargetParentPath:targetParentPath tryAgainIfFailed:NO];
                            } else {
                                [self requestConnectForSyncHierarchicalModelsWithAuthService:self.authService userDefaults:userDefaults targetParentPath:targetParentPath];
                            }
                        } failureHandler:^(NSData *loginData, NSURLResponse *loginResponse, NSError *loginError) {
                            self.processing = @NO;

                            NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                            [self alertToTryAgainWithMessagePrefix:messagePrefix response:loginResponse data:loginData error:loginError];
                        }];
                    } else if (tryAgainIfFailed && statusCode == 503) {
                        // server not connected, so request connection
                        [self requestConnectForSyncHierarchicalModelsWithAuthService:self.authService userDefaults:userDefaults targetParentPath:targetParentPath];
                    } else {
                        self.processing = @NO;

                        NSString *messagePrefix = NSLocalizedString(@"Error on finding directory children.", @"");

                        [self alertToTryAgainWithMessagePrefix:messagePrefix response:response data:data error:error];
                    }
                }];
            } else {
                self.processing = @NO;

                NSLog(@"No directory selected.");
            }
        }
    });
}

- (void)requestConnectForSyncHierarchicalModelsWithAuthService:(AuthService *)authService userDefaults:(NSUserDefaults *)userDefaults targetParentPath:(NSString *)targetParentPath {
    self.processing = @YES;

    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    [authService requestConnectWithSession:sessionId successHandler:^(NSURLResponse *rcresponse, NSData *rcdata) {
        [self internalSyncHierarchicalModelsWithTargetParentPath:targetParentPath tryAgainIfFailed:NO];
    } failureHandler:^(NSData *rcdata, NSURLResponse *rcresponse, NSError *rcerror) {
        self.processing = @NO;

        [self alertToTryAgainWithMessagePrefix:nil response:rcresponse data:rcdata error:rcerror];
    }];
}

- (BOOL)isLoading {
    return (self.processing && [self.processing boolValue]);
}

- (void)stopLoading {
    self.processing = @NO;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    HierarchicalModelWithoutManaged *selectedModel = [self.hierarchicalModelDao fetchedResultsController:self.fetchedResultsController objectAtIndexPath:indexPath];

    if (selectedModel) {
        if ([selectedModel isDirectory]) {
            CenterViewController *subViewController = [Utility instantiateViewControllerWithIdentifier:@"Center"];
            subViewController.parentPath = [DirectoryService serverPathFromParent:selectedModel.realParent name:selectedModel.realName];
            subViewController.directoryOnly = self.directoryOnly;

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.navigationController pushViewController:subViewController animated:YES];
            });
        } else {
            [self showActionSheetWithTableView:tableView hierarachicalModelWithoutManaged:selectedModel selectedRowAtIndexPath:indexPath];
        }
    }
}

- (void)showActionSheetWithTableView:(UITableView *)tableView hierarachicalModelWithoutManaged:(HierarchicalModelWithoutManaged *)hierarchicalModelWithoutManaged selectedRowAtIndexPath:(NSIndexPath *)indexPath {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *realServerPath = [DirectoryService serverPathFromParent:hierarchicalModelWithoutManaged.realParent name:hierarchicalModelWithoutManaged.realName];

        NSUserDefaults *userDefaults = [Utility groupUserDefaults];
        NSString *userComputerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

        FileTransferWithoutManaged *fileTransferWithoutManaged = [self.fileTransferDao findFileTransferForUserComputer:userComputerId realServerPath:realServerPath error:NULL];

        NSString *title = hierarchicalModelWithoutManaged.name;
//        NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Download status %@", @""), [self actionSheetTitleWithFileTransferWithoutManaged:fileTransferWithoutManaged]];

        UIAlertController *actionSheetController = [UIAlertController alertControllerWithTitle:title message:@"" preferredStyle:UIAlertControllerStyleActionSheet];

        if (fileTransferWithoutManaged) {
            NSString *status = fileTransferWithoutManaged.status;

            // The actions should be different based on the downloading status

            NSString *firstAlertActionTitle;

            NSString *transferKey = fileTransferWithoutManaged.transferKey;

//            NSString *localPath = fileTransferWithoutManaged.localPath;

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

            UIAlertAction *downloadOrCancelAction = [self downloadOrCancelActionWithTitle:firstAlertActionTitle fileTransferWithoutManaged:fileTransferWithoutManaged hierarchicalModelWithoutManaged:hierarchicalModelWithoutManaged];

            [actionSheetController addAction:downloadOrCancelAction];

            // 3. File Information

            UIAlertAction *fileInfoAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"File Information", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                BOOL isHiddenFile = fileTransferWithoutManaged.hidden && [fileTransferWithoutManaged.hidden boolValue];

                [self navigateToFileInfoViewControllerWithServerPath:fileTransferWithoutManaged.serverPath
                                                      realServerPath:fileTransferWithoutManaged.realServerPath
                                                            filename:[fileTransferWithoutManaged.localPath lastPathComponent]
                                                         displaySize:fileTransferWithoutManaged.displaySize
                                                         contentType:[Utility contentTypeFromFilenameExtension:[fileTransferWithoutManaged.realServerPath pathExtension]]
                                                    lastModifiedDate:fileTransferWithoutManaged.lastModified
                                                            isHidden:isHiddenFile];
            }];

            [actionSheetController addAction:fileInfoAction];

//            // 4. Move to iTunes sharing folder
//
//            if ([status isEqualToString:FILE_TRANSFER_STATUS_SUCCESS]) {
//                UIAlertAction *moveToSharingFolder = [UIAlertAction actionWithTitle:NSLocalizedString(@"Move to Device Sharing Folder", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
//                    [self.appService moveFileToITunesSharingFolderWithTableView:tableView localRelPath:localPath deleteFileTransferWithTransferKey:transferKey fileTransferDao:self.fileTransferDao successHandler:^(){
//                        // deselect row
//
//                        NSIndexPath *selectedIndexPath = [tableView indexPathForSelectedRow];
//
//                        if (selectedIndexPath) {
//                            dispatch_async(dispatch_get_main_queue(), ^{
//                                [tableView deselectRowAtIndexPath:selectedIndexPath animated:YES];
//                            });
//                        }
//                    }];
//                }];
//
//                [actionSheetController addAction:moveToSharingFolder];
//            }

            // 5. Copy File Path

            UIAlertAction *copyPathAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Copy Path", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [self copyFilePathWithFileRealServerPath:realServerPath];
            }];

            [actionSheetController addAction:copyPathAction];

            // 6. Options (download_status == success)

            if ([status isEqualToString:FILE_TRANSFER_STATUS_SUCCESS]) {
                UIAlertAction *showOptionAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Options", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    [self tableView:tableView showOptionMenuViewControllerWithFileTransferKey:transferKey];
                }];

                [actionSheetController addAction:showOptionAction];
            }
        } else {
            // file not downloaded yet

            // 1. Download File

            UIAlertAction *downloadFileAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Download File", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [self downloadFileFromStartWithRealServerPath:realServerPath hierarchicalModel:hierarchicalModelWithoutManaged tryAgainIfFailed:YES];
            }];

            [actionSheetController addAction:downloadFileAction];

            // 2. File Information

            UIAlertAction *fileInfoAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"File Information", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                NSString *serverPath = [DirectoryService serverPathFromParent:hierarchicalModelWithoutManaged.parent name:hierarchicalModelWithoutManaged.name];

                BOOL isHiddenFile = hierarchicalModelWithoutManaged.hidden && [hierarchicalModelWithoutManaged.hidden boolValue];

                [self navigateToFileInfoViewControllerWithServerPath:serverPath
                                                      realServerPath:realServerPath
                                                            filename:hierarchicalModelWithoutManaged.realName
                                                         displaySize:hierarchicalModelWithoutManaged.displaySize
                                                         contentType:[Utility contentTypeFromFilenameExtension:[hierarchicalModelWithoutManaged.realName pathExtension]]
                                                    lastModifiedDate:hierarchicalModelWithoutManaged.lastModified
                                                            isHidden:isHiddenFile];
            }];

            [actionSheetController addAction:fileInfoAction];

            // 3. Copy Path

            UIAlertAction *copyPathAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Copy Path", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [self copyFilePathWithFileRealServerPath:realServerPath];
            }];

            [actionSheetController addAction:copyPathAction];
        }

        if ([hierarchicalModelWithoutManaged.type isEqualToString:HIERARCHICAL_MODEL_TYPE_BUNDLE_DIRECTORY_FILE]) {
            // change back to directory
            // re-fetch data from local db, but not get data from server

            UIAlertAction *reloadAsDirectoryAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Reload it as a directory", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                NSString *name = hierarchicalModelWithoutManaged.name;
                NSString *parent = hierarchicalModelWithoutManaged.parent;

                NSError *findError;
                HierarchicalModelWithoutManaged *foundHierarchicalModelWithoutManaged = [self.hierarchicalModelDao findHierarchicalModelForUserComputer:userComputerId parent:parent name:name error:&findError];

                if (foundHierarchicalModelWithoutManaged) {
                    foundHierarchicalModelWithoutManaged.type = HIERARCHICAL_MODEL_TYPE_DIRECTORY;

                    [self.hierarchicalModelDao updateHierarchicalModel:foundHierarchicalModelWithoutManaged completionHandler:^(NSError *updateError) {
                        if (!updateError) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self.tableView reloadData];
                            });
                        }
                    }];
                }
            }];

            [actionSheetController addAction:reloadAsDirectoryAction];
        }

        // Cancel action

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

- (NSString *)actionSheetTitleWithFileTransferWithoutManaged:(FileTransferWithoutManaged *)fileTransferWithoutManaged {
    NSString *title;

    if (fileTransferWithoutManaged) {
        NSString *status = fileTransferWithoutManaged.status;

        if ([status isEqualToString:FILE_TRANSFER_STATUS_SUCCESS]) {
            title = NSLocalizedString(@"File downloaded", @"");
        } else if ([status isEqualToString:FILE_TRANSFER_STATUS_PROCESSING]) {
            NSNumber *transferredSize = fileTransferWithoutManaged.transferredSize;
            NSNumber *totalSize = fileTransferWithoutManaged.totalSize;

            if (totalSize && [totalSize doubleValue] > 0) {
                float percentage = [Utility divideDenominator:totalSize byNumerator:transferredSize];

                title = [NSString stringWithFormat:NSLocalizedString(@"Downloading (%.0f%%)", @""), percentage * 100];
            } else {
                title = [NSString stringWithFormat:NSLocalizedString(@"Downloading (%.0f%%)", @""), 0];
            }
        } else if ([status isEqualToString:FILE_TRANSFER_STATUS_CANCELING]) {
            title = NSLocalizedString(@"Canceling", @"");
        } else if ([status isEqualToString:FILE_TRANSFER_STATUS_FAILED]) {
            title = NSLocalizedString(@"Downloaded failed", @"");
        } else {
            title = NSLocalizedString(@"Not downloaded yet", @"");
        }
    }

    return title ? title : NSLocalizedString(@"Not downloaded yet", @"");
}

- (UIAlertAction *)downloadOrCancelActionWithTitle:(NSString *)title fileTransferWithoutManaged:(FileTransferWithoutManaged *)fileTransferWithoutManaged hierarchicalModelWithoutManaged:(HierarchicalModelWithoutManaged *)hierarchicalModelWithoutManaged {
    UIAlertAction *alertAction = [UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        NSString *actionTitle = action.title;

        if (fileTransferWithoutManaged) {
            if ([actionTitle isEqualToString:NSLocalizedString(@"Cancel Download", @"")] && ![fileTransferWithoutManaged.status isEqualToString:FILE_TRANSFER_STATUS_SUCCESS]) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [self.fileDownloadService cancelDownloadWithTransferKey:fileTransferWithoutManaged.transferKey completionHandler:nil];
                });
            } else if ([actionTitle isEqualToString:NSLocalizedString(@"Download Again", @"")]) {
                if ([fileTransferWithoutManaged.status isEqualToString:FILE_TRANSFER_STATUS_SUCCESS]) {
                    // download from start

                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        [self downloadFileFromStartWithRealServerPath:fileTransferWithoutManaged.realServerPath hierarchicalModel:hierarchicalModelWithoutManaged tryAgainIfFailed:YES];
                    });
                } else if ([fileTransferWithoutManaged.status isEqualToString:FILE_TRANSFER_STATUS_FAILED]) {
                    // Use resumeData if any

                    NSError *findError;
                    NSData *resumeData = [self.fileDownloadService resumeDataFromFileTransferWithTransferKey:fileTransferWithoutManaged.transferKey error:&findError];

                    if (resumeData) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            [self.fileDownloadService resumeDownloadWithRealFilePath:fileTransferWithoutManaged.realServerPath resumeData:resumeData completionHandler:^{
                                double delayInSeconds = 3.0;
                                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));
                                dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
                                    self.processing = @NO;
                                });
                            }];
                        });
                    } else {
                        // replace transfer key and then download from start use the new transfer key

                        // DEBUG
                        NSLog(@"Resume data not found. Download from start with file: '%@'", fileTransferWithoutManaged.realServerPath);

                        if (fileTransferWithoutManaged.downloadGroupId) {
                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                [self downloadFileWithFailedFileTransfer:fileTransferWithoutManaged tryAgainIfFailed:YES];
                            });
                        } else {
                            // If download group id not found, meaning that the FileTransfer is downloaded before supporting download group,
                            // all re-downloaded files must delete the current FileTransfer fist.

                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                [self downloadFileFromStartWithRealServerPath:fileTransferWithoutManaged.realServerPath hierarchicalModel:hierarchicalModelWithoutManaged tryAgainIfFailed:YES];
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

// failedFileTransfer.status must be 'failure' and failedFileTransfer.downloadGroupId can't be nil.
// If failedFileTransfer.downloadGroupId is nil, use [self downloadFileWithFileTransfer:] instead
- (void)downloadFileWithFailedFileTransfer:(FileTransferWithoutManaged *)failedFileTransfer tryAgainIfFailed:(BOOL)tryAgainIfFailed {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    NSString *tempLugServerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID];

    if (sessionId == nil || sessionId.length < 1) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [FilelugUtility alertEmptyUserSessionFromViewController:self];
//            [FilelugUtility alertUserNeverConnectedWithViewController:self loginSuccessHandler:^(NSURLResponse *response, NSData *data) {
//                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                    self.processing = @NO;
//
//                    [self downloadFileWithFailedFileTransfer:failedFileTransfer];
//                });
//            }];
        });
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
                } failureHandler:^(NSData *loginData, NSURLResponse *loginResponse, NSError *loginError) {
                    self.processing = @NO;

                    NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                    [self alertToTryDownloadAgainWithFailedFileTransfer:failedFileTransfer messagePrefix:messagePrefix response:loginResponse data:loginData error:loginError];
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

- (void)downloadFileFromStartWithRealServerPath:(NSString *)realServerPath hierarchicalModel:(HierarchicalModelWithoutManaged *)hierarchicalModel tryAgainIfFailed:(BOOL)tryAgainIfFailed {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    NSString *tempLugServerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID];

    if (sessionId == nil || sessionId.length < 1) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            self.processing = @NO;

            [FilelugUtility alertEmptyUserSessionFromViewController:self];
        });
    } else if (tempLugServerId == nil || tempLugServerId.length < 1) {
        [self requestConnectForDownloadFileFromStartWithAuthService:self.authService userDefaults:userDefaults realServerPath:realServerPath hierarchicalModel:hierarchicalModel];
    } else {
        self.processing = @YES;

        // save recent directory before downloading file

        if (hierarchicalModel && hierarchicalModel.name && hierarchicalModel.parent) {
            NSString *directoryPath = hierarchicalModel.parent;

            NSString *directoryRealPath = hierarchicalModel.realParent;

            [self.recentDirectoryService createOrUpdateRecentDirectoryWithDirectoryPath:directoryPath directoryRealPath:directoryRealPath completionHandler:nil];
        }

        // ping if computer connected

        SystemService *systemService = [[SystemService alloc] initWithCachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeInterval:CONNECTION_TIME_INTERVAL];

        [systemService pingDesktop:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            self.processing = @NO;

            NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

            if (statusCode == 200) {
                [SystemService parsePingDesktopResponseJson:data completionHandler:^(NSDictionary *dictionary) {
                    BOOL canDownload = YES;

                    if (dictionary) {
                        NSNumber *downloadSizeLimit = dictionary[@"download-size-limit"];

                        if (downloadSizeLimit && hierarchicalModel) {
                            if ([downloadSizeLimit unsignedLongLongValue] < [hierarchicalModel.sizeInBytes doubleValue]) {
                                canDownload = NO;
                                
                                NSString *message = [NSString stringWithFormat:NSLocalizedString(@"exceed.download.size.limit", @""), hierarchicalModel.displaySize];
                                
                                [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                            }
                        } else {
                            NSLog(@"Skip check download size limit. download size limit=%qu, file=%@",
                                    downloadSizeLimit ? [downloadSizeLimit unsignedLongLongValue] : 0,
                                    hierarchicalModel ? [hierarchicalModel description] : @"NIL");
                        }
                    }

                    if (canDownload) {
                        self.processing = @YES;

                        // create download summary in server

                        NSString *fileSeparator = [userDefaults stringForKey:USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR];

                        NSMutableDictionary *transferKeyAndRealFilePaths = [NSMutableDictionary dictionary];

                        NSMutableArray *filenames = [NSMutableArray array];

                        NSMutableArray *transferKeys = [NSMutableArray array];

                        [filenames addObject:hierarchicalModel.realName];

                        // generate new transfer key - unique for all users
                        NSString *transferKey = [Utility generateDownloadKeyWithSessionId:sessionId realFilePath:realServerPath];

                        [transferKeys addObject:transferKey];

                        transferKeyAndRealFilePaths[transferKey] = realServerPath;

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

                                              NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];

                                              if (selectedIndexPath) {
                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                      [self.tableView deselectRowAtIndexPath:selectedIndexPath animated:YES];
                                                  });
                                              }
                                          }];
                                      } @finally {
                                          self.processing = @NO;
                                      }
                                  }];
                              } else {
                                  self.processing = @NO;

                                  NSString *messagePrefix = NSLocalizedString(@"Error on download file.", @"");

                                  [self alertToTryDownloadAgainWithRealServerPath:realServerPath hierarchicalModel:hierarchicalModel messagePrefix:messagePrefix response:responseFromCreate data:dataFromCreate error:errorFromCreate];
                              }
                          }];
                    }
                }];
            } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
                self.processing = @YES;

                [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                    if ([userDefaults objectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID]) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            [self downloadFileFromStartWithRealServerPath:realServerPath hierarchicalModel:hierarchicalModel tryAgainIfFailed:NO];
                        });
                    } else {
                        [self requestConnectForDownloadFileFromStartWithAuthService:self.authService userDefaults:userDefaults realServerPath:realServerPath hierarchicalModel:hierarchicalModel];
                    }
                } failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
                    self.processing = @NO;

                    NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                    [self alertToTryDownloadAgainWithRealServerPath:realServerPath hierarchicalModel:hierarchicalModel messagePrefix:messagePrefix response:lresponse data:ldata error:lerror];
                }];
//                [self.appService authService:self.authService reloginCurrentUserComputerFromViewController:self successHandler:^(NSURLResponse *lresponse, NSData *ldata) {
//                    if ([userDefaults objectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID]) {
//                        [self downloadFileFromStartWithRealServerPath:realServerPath hierarchicalModel:hierarchicalModel];
//                    } else {
//                        [self requestConnectForDownloadFileFromStartWithAuthService:self.authService userDefaults:userDefaults realServerPath:realServerPath hierarchicalModel:hierarchicalModel];
//                    }
//                } failureHandler:^(NSURLResponse *lresponse, NSData *ldata, NSError *lerror) {
//                    self.processing = @NO;
//
//                    NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");
//
//                    [self alertToTryDownloadAgainWithRealServerPath:realServerPath hierarchicalModel:hierarchicalModel messagePrefix:messagePrefix response:lresponse data:ldata error:lerror];
//                }];
            } else if (tryAgainIfFailed && statusCode == 503) {
                // server not connected, so request connection
                [self requestConnectForDownloadFileFromStartWithAuthService:self.authService userDefaults:userDefaults realServerPath:realServerPath hierarchicalModel:hierarchicalModel];
            } else {
                self.processing = @NO;

                NSString *messagePrefix = NSLocalizedString(@"Error on download file.", @"");

                [self alertToTryDownloadAgainWithRealServerPath:realServerPath hierarchicalModel:hierarchicalModel messagePrefix:messagePrefix response:response data:data error:error];
            }
        }];
    }
}

- (void)requestConnectForDownloadFileFromStartWithAuthService:(AuthService *)authService userDefaults:(NSUserDefaults *)userDefaults realServerPath:(NSString *)realServerPath hierarchicalModel:(HierarchicalModelWithoutManaged *)hierarchicalModelWithoutManaged {
    self.processing = @YES;

    [authService requestConnectWithSession:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] successHandler:^(NSURLResponse *rcresponse, NSData *rcdata) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self downloadFileFromStartWithRealServerPath:realServerPath hierarchicalModel:hierarchicalModelWithoutManaged tryAgainIfFailed:NO];
        });
    } failureHandler:^(NSData *rcdata, NSURLResponse *rcresponse, NSError *rcerror) {
        self.processing = @NO;

        [self alertToTryDownloadAgainWithRealServerPath:realServerPath hierarchicalModel:hierarchicalModelWithoutManaged messagePrefix:nil response:rcresponse data:rcdata error:rcerror];
    }];
}

- (void)alertToTryDownloadAgainWithRealServerPath:(NSString *)realServerPath hierarchicalModel:(HierarchicalModelWithoutManaged *)hierarchicalModelWithoutManaged messagePrefix:(NSString *)messagePrefix response:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error {
    UIAlertAction *tryDownloadAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Download Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        // Request download file again
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self downloadFileFromStartWithRealServerPath:realServerPath hierarchicalModel:hierarchicalModelWithoutManaged tryAgainIfFailed:YES];
        });
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryDownloadAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        // Request download file again
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self downloadFileFromStartWithRealServerPath:realServerPath hierarchicalModel:hierarchicalModelWithoutManaged tryAgainIfFailed:NO];
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

- (void)navigateToFileInfoViewControllerWithServerPath:(NSString *)serverPath realServerPath:(NSString *)realServerPath filename:(NSString *)filename displaySize:(NSString *)displaySize contentType:(NSString *)contentType lastModifiedDate:(NSString *)lastModifiedDate isHidden:(BOOL)isHidden {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        FileInfoViewController *fileInfoViewController = [Utility instantiateViewControllerWithIdentifier:@"FileInfo"];

        fileInfoViewController.filePath = serverPath;
        fileInfoViewController.realFilePath = realServerPath;
        fileInfoViewController.filename = filename;

        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSString *separator = [userDefaults stringForKey:USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR];

        if (separator) {
            fileInfoViewController.fileParent = [DirectoryService parentPathFromServerFilePath:serverPath separator:separator];
        }

        fileInfoViewController.fileSize = displaySize;
        fileInfoViewController.fileMimetype = contentType;
        fileInfoViewController.fileLastModifiedDate = lastModifiedDate;

        if (isHidden) {
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

            NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];

            if (selectedIndexPath) {
                UITableViewCell *selectedCell = [self.tableView cellForRowAtIndexPath:selectedIndexPath];

                if (selectedCell) {
                    inView = selectedCell;
                    fromRect = selectedCell.bounds;

                    foundSelectedCell = YES;
                }
            }

            if (!foundSelectedCell) {
                NSArray *indexPaths = [self.tableView indexPathsForVisibleRows];

                if (indexPaths && [indexPaths count] > 0) {
                    UITableViewCell *firstCell = [self.tableView cellForRowAtIndexPath:indexPaths[0]];

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

- (void)copyFilePathWithFileRealServerPath:(NSString *)realServerPath {
    if (realServerPath) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        [pasteboard setString:realServerPath];

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

    @try {
        count = [self.hierarchicalModelDao numberOfSectionsForFetchedResultsController:self.fetchedResultsController];
    } @catch (NSException *e) {
        [self handleFetchedResultsControllerErrorWithMethodName:@"numberOfSectionsInTableView" exception:e directoryPath:self.parentPath reloadTableView:YES];
    }

    return count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *title;

    @try {
        NSString *type = [self.hierarchicalModelDao fetchedResultsController:self.fetchedResultsController sectionName:section];
        title = NSLocalizedString([type lowercaseString], @"");
    } @catch (NSException *e) {
        [self handleFetchedResultsControllerErrorWithMethodName:@"tableView: titleForHeaderInSection:" exception:e directoryPath:self.parentPath reloadTableView:YES];
    }

    return title;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger count;

    @try {
        count = [self.hierarchicalModelDao fetchedResultsController:self.fetchedResultsController numberOfRowsInSection:section];
    } @catch (NSException *e) {
        [self handleFetchedResultsControllerErrorWithMethodName:@"tableView: numberOfRowsInSection:" exception:e directoryPath:self.parentPath reloadTableView:YES];
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
    static NSString *DirectoryCellIdentifier = @"CenterDirectoryCell";
    static NSString *FileCellIdentifier = @"CenterFileCell";

    UITableViewCell *cell;

    @try {
        BOOL isDirectory = [self.hierarchicalModelDao fetchedResultsController:self.fetchedResultsController isDirectoryAtIndexPath:indexPath];

        if (isDirectory) {
            cell = [tableView dequeueReusableCellWithIdentifier:DirectoryCellIdentifier forIndexPath:indexPath];
        } else {
            cell = [tableView dequeueReusableCellWithIdentifier:FileCellIdentifier forIndexPath:indexPath];

            // configure the preferred font for detail text label

            cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
            cell.detailTextLabel.textColor = [UIColor lightGrayColor];
            cell.detailTextLabel.numberOfLines = 1;
            cell.detailTextLabel.adjustsFontSizeToFitWidth = NO;
            cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingTail;
            cell.detailTextLabel.textAlignment = NSTextAlignmentNatural;
        }

        // configure the preferred font for text label

        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        cell.textLabel.textColor = [UIColor darkTextColor];
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.adjustsFontSizeToFitWidth = NO;
        cell.textLabel.lineBreakMode = NSLineBreakByCharWrapping;
        cell.textLabel.textAlignment = NSTextAlignmentNatural;

        [self configureCell:cell atIndexPath:indexPath];
    } @catch (NSException *e) {
        [self handleFetchedResultsControllerErrorWithMethodName:@"tableView: cellForRowAtIndexPath:" exception:e directoryPath:self.parentPath reloadTableView:YES];
    }

    return cell;
}

#pragma mark - UIDocumentInteractionControllerDelegate

- (UIViewController *)documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *)controller {
    return self;
}

- (UIView *)documentInteractionControllerViewForPreview:(UIDocumentInteractionController *)controller {
    return self.view;
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
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
        [self handleFetchedResultsControllerErrorWithMethodName:@"controller:didChangeSection:atIndex:forChangeType:" exception:e directoryPath:self.parentPath reloadTableView:YES];
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    // DEBUG
//    NSLog(@"Changed Object:\n%@", anObject);

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
//                [self configureWithTableView:self.tableView atIndexPath:indexPath cell:&cell];
                break;

            case NSFetchedResultsChangeMove:
                [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];

                [self.tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];

                break;
        }
    } @catch (NSException *e) {
        [self handleFetchedResultsControllerErrorWithMethodName:@"controller:didChangeObject:atIndexPath:forChangeType:newIndexPath:" exception:e directoryPath:self.parentPath reloadTableView:YES];
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView endUpdates];
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    HierarchicalModelWithoutManaged *hierarchicalModel = [self.hierarchicalModelDao fetchedResultsController:self.fetchedResultsController objectAtIndexPath:indexPath];

    if (hierarchicalModel) {
        cell.textLabel.text = hierarchicalModel.name;

        BOOL isDirectory = hierarchicalModel.isDirectory;

        if (!isDirectory) {
            NSString *displaySize = hierarchicalModel.displaySize;

            NSString *lastModified;

            NSString *lastModifiedFromServer = hierarchicalModel.lastModified;

            if (lastModifiedFromServer) {
                NSDate *lastModifiedDate = [Utility dateFromString:lastModifiedFromServer format:DATE_FORMAT_FOR_SERVER];

                if (lastModifiedDate) {
                    lastModified = [Utility dateStringFromDate:lastModifiedDate];
                }
            }

            // deal with download status

            NSString *downloadStatusDescription;

            UIColor *downloadStatusColor;

            if (hierarchicalModel.transferKey && [hierarchicalModel.transferKey length] > 0) {
                NSString *downloadStatus = hierarchicalModel.status;

                if ([downloadStatus isEqualToString:FILE_TRANSFER_STATUS_PROCESSING]) {
                    NSNumber *transferredSize = hierarchicalModel.transferredSize;
                    NSNumber *totalSize = hierarchicalModel.totalSize;

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
            }

//            NSLog(@"downloadStatusDescription: %@", downloadStatusDescription);

            NSString *detailLabelText;

            if (downloadStatusDescription) {
                if (lastModified) {
                    detailLabelText = [NSString stringWithFormat:@"%@, %@, %@", downloadStatusDescription, displaySize, lastModified];
                } else {
                    detailLabelText = [NSString stringWithFormat:@"%@, %@", downloadStatusDescription, displaySize];
                }
            } else {
                if (lastModified) {
                    detailLabelText = [NSString stringWithFormat:@"%@, %@", displaySize, lastModified];
                } else {
                    detailLabelText = [NSString stringWithFormat:@"%@", displaySize];
                }
            }

            cell.detailTextLabel.text = detailLabelText;

            NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:detailLabelText];

            if (downloadStatusDescription) {
                [attributedString setText:downloadStatusDescription withColor:downloadStatusColor];
            }

            [attributedString setText:displaySize withColor:[UIColor lightGrayColor]];
            [attributedString setText:lastModified withColor:[UIColor lightGrayColor]];

            [cell.detailTextLabel setAttributedText:attributedString];
        }

        // image

        UIImage *image;

        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSString *separator = [userDefaults stringForKey:USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR];

        if (separator) {
            image = [DirectoryService imageForFile:hierarchicalModel fileSeparator:separator bundleDirectoryAsFile:YES];
        } else {
            if (isDirectory) {
                image = [UIImage imageNamed:@"ic_folder"];
            } else {
                image = [UIImage imageNamed:@"ic_file"];
            }
        }

        if (isDirectory) {
            [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        } else {
            [cell setAccessoryType:UITableViewCellAccessoryNone];
        }

        cell.imageView.image = image;

        // To resolve the width of the detail text not correctly updated
        [cell layoutSubviews];
    }
}

//- (void)configureWithTableView:(UITableView *)tableView atIndexPath:(NSIndexPath *)indexPath cell:(UITableViewCell **)cellPointer {
//    HierarchicalModelWithoutManaged *hierarchicalModel = [self.hierarchicalModelDao fetchedResultsController:self.fetchedResultsController objectAtIndexPath:indexPath];
//
//    if (hierarchicalModel) {
//        static NSString *DirectoryCellIdentifier = @"CenterDirectoryCell";
//        static NSString *FileCellIdentifier = @"CenterFileCell";
//
//        BOOL isDirectory = hierarchicalModel.isDirectory;
//
//        UITableViewCell *cell;
//
//        if (isDirectory) {
//            cell = [tableView dequeueReusableCellWithIdentifier:DirectoryCellIdentifier forIndexPath:indexPath];
//        } else {
//            cell = [tableView dequeueReusableCellWithIdentifier:FileCellIdentifier forIndexPath:indexPath];
//        }
//
//        *cellPointer = cell;
//
//        // configure the preferred font
//
//        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
//        cell.textLabel.textColor = [UIColor darkTextColor];
//        cell.textLabel.numberOfLines = 0;
//        cell.textLabel.adjustsFontSizeToFitWidth = NO;
//        cell.textLabel.lineBreakMode = NSLineBreakByCharWrapping;
//        cell.textLabel.textAlignment = NSTextAlignmentNatural;
//
//        cell.textLabel.text = hierarchicalModel.name;
//
//        if (!isDirectory) {
//            cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
//            cell.detailTextLabel.textColor = [UIColor lightGrayColor];
//            cell.detailTextLabel.numberOfLines = 1;
//            cell.detailTextLabel.adjustsFontSizeToFitWidth = NO;
//            cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingTail;
//            cell.detailTextLabel.textAlignment = NSTextAlignmentNatural;
//
//            NSString *displaySize = hierarchicalModel.displaySize;
//
//            NSString *lastModified;
//
//            NSString *lastModifiedFromServer = hierarchicalModel.lastModified;
//
//            if (lastModifiedFromServer) {
//                NSDate *lastModifiedDate = [Utility dateFromString:lastModifiedFromServer format:DATE_FORMAT_FOR_SERVER];
//
//                if (lastModifiedDate) {
//                    lastModified = [Utility dateStringFromDate:lastModifiedDate];
//                }
//            }
//
//            // deal with download status
//
//            NSString *downloadStatusDescription;
//
//            UIColor *downloadStatusColor;
//
//            if (hierarchicalModel.transferKey && [hierarchicalModel.transferKey length] > 0) {
//                NSString *downloadStatus = hierarchicalModel.status;
//
//                if ([downloadStatus isEqualToString:FILE_TRANSFER_STATUS_PROCESSING]) {
//                    NSNumber *transferredSize = hierarchicalModel.transferredSize;
//                    NSNumber *totalSize = hierarchicalModel.totalSize;
//
//                    float percentage = [Utility divideDenominator:totalSize byNumerator:transferredSize];
//
//                    downloadStatusDescription = [NSString stringWithFormat:@"%@(%.0f%%)", NSLocalizedString(@"File is downloading", @""), percentage * 100];
//
//                    downloadStatusColor = [UIColor aquaColor];
//                } else if ([downloadStatus isEqualToString:FILE_TRANSFER_STATUS_SUCCESS]) {
//                    downloadStatusDescription = NSLocalizedString(@"File downloaded", @"");
//
//                    downloadStatusColor = [UIColor darkGrayColor];
//                } else if ([downloadStatus isEqualToString:FILE_TRANSFER_STATUS_CANCELING]) {
//                    downloadStatusDescription = NSLocalizedString(@"Download canceling", @"");
//
//                    downloadStatusColor = [UIColor redColor];
//                } else if ([downloadStatus isEqualToString:FILE_TRANSFER_STATUS_FAILED]) {
//                    downloadStatusDescription = NSLocalizedString(@"Downloaded failed", @"");
//
//                    downloadStatusColor = [UIColor redColor];
//                } else {
//                    downloadStatusDescription = NSLocalizedString(@"Download Preparing", @"");
//
//                    downloadStatusColor = [UIColor aquaColor];
//                }
//            }
//
//            NSLog(@"downloadStatusDescription: %@", downloadStatusDescription);
//
//            NSString *detailLabelText;
//
//            if (downloadStatusDescription) {
//                if (lastModified) {
//                    detailLabelText = [NSString stringWithFormat:@"%@, %@, %@", downloadStatusDescription, displaySize, lastModified];
//                } else {
//                    detailLabelText = [NSString stringWithFormat:@"%@, %@", downloadStatusDescription, displaySize];
//                }
//            } else {
//                if (lastModified) {
//                    detailLabelText = [NSString stringWithFormat:@"%@, %@", displaySize, lastModified];
//                } else {
//                    detailLabelText = [NSString stringWithFormat:@"%@", displaySize];
//                }
//            }
//
//            cell.detailTextLabel.text = detailLabelText;
//
//            NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:detailLabelText];
//
//            if (downloadStatusDescription) {
//                [attributedString setText:downloadStatusDescription withColor:downloadStatusColor];
//            }
//
//            [attributedString setText:displaySize withColor:[UIColor lightGrayColor]];
//            [attributedString setText:lastModified withColor:[UIColor lightGrayColor]];
//
//            [cell.detailTextLabel setAttributedText:attributedString];
//        }
//
//        UIImage *image;
//
//        NSUserDefaults *userDefaults = [Utility groupUserDefaults];
//
//        NSString *separator = [userDefaults stringForKey:USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR];
//
//        if (separator) {
//            image = [DirectoryService imageForFile:hierarchicalModel fileSeparator:separator bundleDirectoryAsFile:YES];
//        } else {
//            if (isDirectory) {
//                image = [UIImage imageNamed:@"ic_folder"];
//            } else {
//                image = [UIImage imageNamed:@"ic_file"];
//            }
//        }
//
//        if (isDirectory) {
//            [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
//        } else {
//            [cell setAccessoryType:UITableViewCellAccessoryNone];
//        }
//
//        cell.imageView.image = image;
//
//        // To resolve the width of the detail text not correctly updated
//        [cell layoutSubviews];
//    }
//}

- (void)handleFetchedResultsControllerErrorWithMethodName:(NSString *)methodNameForLogging exception:(NSException *)e directoryPath:(NSString *)directoryPath reloadTableView:(BOOL)reloadTableView {
    NSLog(@"Error on %@.\n%@", methodNameForLogging, e);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSString *userComputerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];
        [self.hierarchicalModelDao deleteHierarchicalModelForUserComputer:userComputerId parent:directoryPath hierarchically:YES];

        if (reloadTableView) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
        }
    });
}

- (void)alertToTryAgainWithMessagePrefix:(NSString *)messagePrefix response:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error {
    UIAlertAction *tryUpdateAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        NSString *targetParentPath = [NSString stringWithString:self.parentPath];

        [self internalSyncHierarchicalModelsWithTargetParentPath:targetParentPath tryAgainIfFailed:YES];
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryUpdateAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        NSString *targetParentPath = [NSString stringWithString:self.parentPath];

        [self internalSyncHierarchicalModelsWithTargetParentPath:targetParentPath tryAgainIfFailed:NO];
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
