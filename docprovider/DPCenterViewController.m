#import <MobileCoreServices/MobileCoreServices.h>
#import "DPCenterViewController.h"
#import "FilelugDocProviderUtility.h"
#import "DocumentPickerViewController.h"

@interface DPCenterViewController ()

@property(nonatomic, strong) HierarchicalModelDao *hierarchicalModelDao;

@property(nonatomic, strong) NSFetchedResultsController *fetchedResultsController;

@property(nonatomic, strong) NSNumber *downloading;

@property(nonatomic, strong) MBProgressHUD *downloadProgressView;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) FileTransferDao *fileTransferDao;

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

@property(nonatomic, strong) DirectoryService *directoryService;

@property(nonatomic, strong) FileDownloadGroupDao *fileDownloadGroupDao;

@property(nonatomic, strong) DPFileDownloadService *fileDownloadService;

@end

@implementation DPCenterViewController

@synthesize documentPickerExtensionViewController;

@synthesize processing;

@synthesize progressView;

- (void)viewDidLoad {
    [super viewDidLoad];

    self.processing = @NO;
    self.downloading = @NO;

    [Utility viewController:self useNavigationLargeTitles:YES];

    _preferredContentSizeCategoryService = [[PreferredContentSizeCategoryService alloc] init];

    // refresh control
    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];

    [refresh setAttributedTitle:[[NSAttributedString alloc] initWithString:NSLocalizedString(@"Pull to refresh", @"")]];

    self.refreshControl = refresh;

    // Change the back button for the next view controller
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel", @"") style:UIBarButtonItemStylePlain target:self action:@selector(didCanceled:)];

    [self.navigationItem setRightBarButtonItem:cancelButton];

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

    [self addObserver:self forKeyPath:NSStringFromSelector(@selector(downloading)) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];

    [self.refreshControl addTarget:self action:@selector(resyncHierarchicalModels:) forControlEvents:UIControlEventValueChanged];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onFileDownloadDidCompleteNotification:) name:NOTIFICATION_NAME_FILE_DOWNLOAD_DID_COMPLETE object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onFileDownloadDidResumeNotification:) name:NOTIFICATION_NAME_FILE_DOWNLOAD_DID_RESUME object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onFileDownloadDidWriteDataNotification:) name:NOTIFICATION_NAME_FILE_DOWNLOAD_DID_WRITE_DATA object:nil];
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

    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_NAME_FILE_DOWNLOAD_DID_WRITE_DATA object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_NAME_FILE_DOWNLOAD_DID_RESUME object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_NAME_FILE_DOWNLOAD_DID_COMPLETE object:nil];

    [self.refreshControl removeTarget:self action:@selector(resyncHierarchicalModels:) forControlEvents:UIControlEventValueChanged];

    [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(downloading)) context:NULL];

    [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) context:NULL];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];

//    if (self.progressView) {
//        self.progressView = nil;
//    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (BOOL)isLoading {
    return (self.processing && [self.processing boolValue]);
}

- (void)stopLoading {
    self.processing = @NO;
}

- (void)didCanceled:(id)sender {
    if (self.documentPickerExtensionViewController) {
        [self.documentPickerExtensionViewController dismissGrantingAccessToURL:nil];
    }
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

        _fetchedResultsController = [self.hierarchicalModelDao createHierarchicalModelsFetchedResultsControllerForUserComputer:userComputerId parent:self.parentPath directoryOnly:NO delegate:self];
    }

    return _fetchedResultsController;
}

- (AuthService *)authService {
    if (!_authService) {
        _authService = [[AuthService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];
    }

    return _authService;
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

- (DPFileDownloadService *)fileDownloadService {
    if (!_fileDownloadService) {
        _fileDownloadService = [[DPFileDownloadService alloc] init];
    }

    return _fileDownloadService;
}

- (void)didChangePreferredContentSize:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

#pragma mark - NSKeyValueObserving

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(processing))]) {
        if (self.downloading && [self.downloading boolValue]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.progressView) {
                    [self.progressView hide:YES];
                }
            });
        } else {
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

                        if (self.refreshControl) {
                            [self.refreshControl endRefreshing];
                        }
                    }
                });
            }
        }
    } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(downloading))]) {
        NSNumber *newValue = change[NSKeyValueChangeNewKey];
        NSNumber *oldValue = change[NSKeyValueChangeOldKey];

        if (![newValue isEqualToNumber:oldValue]) {
            if ([newValue boolValue]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (self.progressView) {
                        [self.progressView hide:YES];
                    }

                    [self.tableView setScrollEnabled:NO];

                    if (!self.downloadProgressView) {
                        MBProgressHUD *progressHUD = [Utility prepareAnnularDeterminateProgressViewWithSuperview:self.view labelText:NSLocalizedString(@"File is downloading", @"")];

                        self.downloadProgressView = progressHUD;
                    } else {
                        [self.downloadProgressView show:YES];
                    }
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.tableView setScrollEnabled:YES];

                    if (self.downloadProgressView) {
                        [self.downloadProgressView hide:YES];
                    }
                });

//                // process after 2 seconds to prevent the self.downloadProgressView hangs
//                
//                double delayInSeconds = 2.0;
//                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));
//                dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
//                    dispatch_async(dispatch_get_main_queue(), ^{
//                        [self.tableView setScrollEnabled:YES];
//
//                        if (self.downloadProgressView) {
//                            [self.downloadProgressView hide:YES];
//                        }
//                    });
//                });
            }
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

    /* fetch from server, save to DB, then retrieve from DB */
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self internalSyncHierarchicalModelsWithTargetParentPath:targetParentPath tryAgainIfFailed:NO];
    });
}

- (void)internalSyncHierarchicalModelsWithTargetParentPath:(NSString *)targetParentPath tryAgainIfFailed:(BOOL)tryAgainIfFailed {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    NSString *userComputerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

    NSString *tempLugServerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID];

    if (sessionId == nil || sessionId.length < 1) {
        [Utility alertInExtensionEmptyUserSessionFromViewController:self completion:^{
            self.processing = @NO;
        }];
    } else if (tempLugServerId == nil || tempLugServerId.length < 1) {
        [self requestConnectWithAuthService:self.authService userDefaults:userDefaults targetParentPath:targetParentPath];
    } else {
        if (targetParentPath) {
            self.processing = @YES;

            [self.directoryService listDirectoryChildrenWithParent:targetParentPath session:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

                if (statusCode == 200) {
                    self.processing = @NO;

                    [self.hierarchicalModelDao parseJsonAndSyncWithCurrentHierarchicalModels:data userComputer:userComputerId parentPath:targetParentPath completionHandler:^{
                    }];
                } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
                    [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                        if ([userDefaults objectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID]) {
                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                [self internalSyncHierarchicalModelsWithTargetParentPath:targetParentPath tryAgainIfFailed:NO];
                            });
                        } else {
                            [self requestConnectWithAuthService:self.authService userDefaults:userDefaults targetParentPath:targetParentPath];
                        }
                    }                            failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
                        self.processing = @NO;

                        NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                        [self alertToSyncHierarchicalModelsAgainWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror targetParentPath:targetParentPath];
                    }];
                } else if (tryAgainIfFailed && statusCode == 503) {
                    // server not connected, so request connection
                    [self requestConnectWithAuthService:self.authService userDefaults:userDefaults targetParentPath:targetParentPath];
                } else {
                    self.processing = @NO;

                    NSString *messagePrefix = NSLocalizedString(@"Error on finding directory children.", @"");

                    [self alertToSyncHierarchicalModelsAgainWithMessagePrefix:messagePrefix response:response data:data error:error targetParentPath:targetParentPath];
                }
            }];
        } else {
            self.processing = @NO;

            NSLog(@"No directory selected.");
        }
    }
}

- (void)requestConnectWithAuthService:(AuthService *)authService userDefaults:(NSUserDefaults *)userDefaults targetParentPath:(NSString *)targetParentPath {
    self.processing = @YES;

    [authService requestConnectWithSession:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] successHandler:^(NSURLResponse *rcresponse, NSData *rcdata) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self internalSyncHierarchicalModelsWithTargetParentPath:targetParentPath tryAgainIfFailed:NO];
        });
    }                       failureHandler:^(NSData *rcdata, NSURLResponse *rcresponse, NSError *rcerror) {
        self.processing = @NO;

        [self alertToSyncHierarchicalModelsAgainWithMessagePrefix:nil response:rcresponse data:rcdata error:rcerror targetParentPath:targetParentPath];
    }];
}

// failedFileTransfer.status must be 'failure' and failedFileTransfer.downloadGroupId can't be nil.
// If failedFileTransfer.downloadGroupId is nil, use [self downloadFileFromStartWithHierarchicalModel:] instead
- (void)downloadFileWithFailedFileTransfer:(FileTransferWithoutManaged *)failedFileTransfer tryAgainIfFailed:(BOOL)tryAgainIfFailed {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    NSString *tempLugServerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID];

    if (sessionId == nil || sessionId.length < 1) {
        [Utility alertInExtensionEmptyUserSessionFromViewController:self completion:^{
            self.downloading = @NO;
        }];
    } else if (tempLugServerId == nil || tempLugServerId.length < 1) {
        [self requestConnectWithFailedFileTransfer:failedFileTransfer authService:self.authService userDefaults:userDefaults];
    } else {
        self.downloading = @YES;

        SystemService *systemService = [[SystemService alloc] initWithCachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeInterval:CONNECTION_TIME_INTERVAL];

        [systemService pingDesktop:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
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

                    // check desktop version before downloading bundle directory file
                    if (canDownload && [Utility desktopVersionLessThanOrEqualTo:@"1.1.2"] && [failedFileTransfer.type isEqualToString:HIERARCHICAL_MODEL_TYPE_BUNDLE_DIRECTORY_FILE]) {
                        canDownload = NO;

                        NSString *computerName = [userDefaults objectForKey:USER_DEFAULTS_KEY_COMPUTER_NAME];

                        NSString *filename = [DirectoryService filenameFromServerFilePath:failedFileTransfer.serverPath];

                        NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Upgrade desktop %@ before download file %@", @""), computerName, filename];

                        [Utility viewController:self alertWithMessageTitle:NSLocalizedString(@"Version Too Old", @"") messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0.1 actionHandler:nil];
                    }

                    if (canDownload) {
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

                                [self.fileDownloadService downloadFromStartWithTransferKey:transferKey realServerPath:realServerPath fileSeparator:fileSeparator downloadGroupId:downloadGroupId userComputerId:userComputerId sessionId:sessionId actionsAfterDownload:actionsAfterDownload addToStartTimestampWithMilliseconds:0 completionHandler:^() {
                                    // Use NSNotification from FileTransferService to handle the processing result, so the downloading status can displayed SYNCHRONIZED
                                }];
                            } else {
                                self.downloading = @NO;

                                NSString *messagePrefix = NSLocalizedString(@"Error on download file.", @"");

                                [self alertToTryDownloadAgainWithFailedFileTransfer:failedFileTransfer messagePrefix:messagePrefix response:responseFromReplace data:dataFromReplace error:errorFromReplace];
                            }
                        }];
                    } else {
                        self.downloading = @NO;
                    }
                }];
            } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
                [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                    if ([userDefaults objectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID]) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            [self downloadFileWithFailedFileTransfer:failedFileTransfer tryAgainIfFailed:NO];
                        });
                    } else {
                        [self requestConnectWithFailedFileTransfer:failedFileTransfer authService:self.authService userDefaults:userDefaults];
                    }
                } failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
                    self.downloading = @NO;

                    NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                    [self alertToTryDownloadAgainWithFailedFileTransfer:failedFileTransfer messagePrefix:messagePrefix response:lresponse data:ldata error:lerror];
                }];
            } else if (tryAgainIfFailed && statusCode == 503) {
                // server not connected, so request connection
                [self requestConnectWithFailedFileTransfer:failedFileTransfer authService:self.authService userDefaults:userDefaults];
            } else {
                self.downloading = @NO;

                NSString *messagePrefix = NSLocalizedString(@"Error on download file.", @"");

                [self alertToTryDownloadAgainWithFailedFileTransfer:failedFileTransfer messagePrefix:messagePrefix response:response data:data error:error];
            }
        }];
    }
}

- (void)requestConnectWithFailedFileTransfer:(FileTransferWithoutManaged *)failedFileTransfer authService:(AuthService *)authService userDefaults:(NSUserDefaults *)userDefaults {
    self.downloading = @YES;

    [authService requestConnectWithSession:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] successHandler:^(NSURLResponse *rcresponse, NSData *rcdata) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self downloadFileWithFailedFileTransfer:failedFileTransfer tryAgainIfFailed:NO];
        });
    }                       failureHandler:^(NSData *rcdata, NSURLResponse *rcresponse, NSError *rcerror) {
        self.downloading = @NO;

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

- (void)downloadFileFromStartWithHierarchicalModel:(HierarchicalModelWithoutManaged *)hierarchicalModel tryAgainIfFailed:(BOOL)tryAgainIfFailed {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    NSString *tempLugServerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID];

    if (sessionId == nil || sessionId.length < 1) {
        [Utility alertInExtensionEmptyUserSessionFromViewController:self completion:^{
            self.downloading = @NO;
        }];
    } else if (tempLugServerId == nil || tempLugServerId.length < 1) {
        [self requestConnectForDownloadWithHierarchicalModel:hierarchicalModel authService:self.authService userDefaults:userDefaults];
    } else {
        self.downloading = @YES;

        SystemService *systemService = [[SystemService alloc] initWithCachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeInterval:CONNECTION_TIME_INTERVAL];

        [systemService pingDesktop:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

            if (statusCode == 200) {
                [SystemService parsePingDesktopResponseJson:data completionHandler:^(NSDictionary *dictionary) {
                    if (dictionary) {
                        NSNumber *downloadSizeLimit = dictionary[@"download-size-limit"];

                        if (!downloadSizeLimit || !hierarchicalModel) {
                            self.downloading = @NO;

                            NSLog(@"No size limit or hierarchical model found!");
                        } else if ([downloadSizeLimit unsignedLongLongValue] < [hierarchicalModel.sizeInBytes unsignedLongLongValue]) {
                            self.downloading = @NO;

                            NSString *message = [NSString stringWithFormat:NSLocalizedString(@"exceed.download.size.limit2", @""), hierarchicalModel.name];

                            [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                        } else {
                            // create download summary in server

                            NSString *fileSeparator = [userDefaults stringForKey:USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR];

                            NSMutableDictionary *transferKeyAndRealFilePaths = [NSMutableDictionary dictionary];

                            NSMutableArray *filenames = [NSMutableArray array];

                            NSMutableArray *transferKeys = [NSMutableArray array];

                            NSString *realFilePath = [DirectoryService serverPathFromParent:hierarchicalModel.realParent name:hierarchicalModel.realName fileSeparator:fileSeparator];

                            [filenames addObject:hierarchicalModel.realName];

                            // generate new transfer key - unique for all users
                            NSString *transferKey = [Utility generateDownloadKeyWithSessionId:sessionId realFilePath:realFilePath];

                            [transferKeys addObject:transferKey];

                            transferKeyAndRealFilePaths[transferKey] = realFilePath;

                            // Always disabled notification for downloading files in Document Provider.
                            NSInteger notificationType = 0;

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

                                          // set actions after download
                                          NSString *actionsAfterDownload = [FileTransferWithoutManaged prepareActionsAfterDownloadWithOpen:NO share:NO];

                                          [self.fileDownloadService downloadFromStartWithTransferKey:transferKey realServerPath:realFilePath fileSeparator:fileSeparator downloadGroupId:downloadGroupId userComputerId:userComputerId sessionId:sessionId actionsAfterDownload:actionsAfterDownload addToStartTimestampWithMilliseconds:0 completionHandler:^{
                                              // Use NSNotification from FileTransferService to handle the processing result, so the downloading status can displayed SYNCHRONIZED
                                          }];
                                      }];
                                  } else {
                                      self.downloading = @NO;

                                      NSString *messagePrefix = NSLocalizedString(@"Error on download file.", @"");

                                      [self alertToDownloadFileFromStartAgainWithHierarchicalModel:hierarchicalModel messagePrefix:messagePrefix response:responseFromCreate data:dataFromCreate error:errorFromCreate];
                                  }
                              }];
                        }
                    } else {
                        self.downloading = @NO;
                    }
                }];
            } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
                [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                    if ([userDefaults objectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID]) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            [self downloadFileFromStartWithHierarchicalModel:hierarchicalModel tryAgainIfFailed:NO];
                        });
                    } else {
                        [self requestConnectForDownloadWithHierarchicalModel:hierarchicalModel authService:self.authService userDefaults:userDefaults];
                    }
                }                            failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
                    self.downloading = @NO;

                    NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                    [self alertToDownloadFileFromStartAgainWithHierarchicalModel:hierarchicalModel messagePrefix:messagePrefix response:lresponse data:ldata error:lerror];
                }];
            } else if (tryAgainIfFailed && statusCode == 503) {
                // server not connected, so request connection
                [self requestConnectForDownloadWithHierarchicalModel:hierarchicalModel authService:self.authService userDefaults:userDefaults];
            } else {
                self.downloading = @NO;

                NSString *messagePrefix = NSLocalizedString(@"Error on download file.", @"");

                [self alertToDownloadFileFromStartAgainWithHierarchicalModel:hierarchicalModel messagePrefix:messagePrefix response:response data:data error:error];
            }
        }];
    }
}

- (void)requestConnectForDownloadWithHierarchicalModel:(HierarchicalModelWithoutManaged *)hierarchicalModel authService:(AuthService *)authService userDefaults:(NSUserDefaults *)userDefaults {
    self.downloading = @YES;

    [authService requestConnectWithSession:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] successHandler:^(NSURLResponse *rcresponse, NSData *rcdata) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self downloadFileFromStartWithHierarchicalModel:hierarchicalModel tryAgainIfFailed:NO];
        });
    }                       failureHandler:^(NSData *rcdata, NSURLResponse *rcresponse, NSError *rcerror) {
        self.downloading = @NO;

        [self alertToDownloadFileFromStartAgainWithHierarchicalModel:hierarchicalModel messagePrefix:nil response:rcresponse data:rcdata error:rcerror];
    }];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    HierarchicalModelWithoutManaged *selectedModel = [self.hierarchicalModelDao fetchedResultsController:self.fetchedResultsController objectAtIndexPath:indexPath];

    if (selectedModel) {
        if ([selectedModel isDirectory]) {
            DPCenterViewController *subViewController = [FilelugDocProviderUtility instantiateViewControllerWithIdentifier:@"DPCenter"];

            subViewController.parentPath = [DirectoryService serverPathFromParent:selectedModel.realParent name:selectedModel.realName];
            subViewController.documentPickerExtensionViewController = self.documentPickerExtensionViewController;

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.navigationController pushViewController:subViewController animated:YES];
            });
        } else {
            // Check if file already exists in two places, first under the document storage url, second the permanet path under Filelug

            NSUserDefaults *userDefaults = [Utility groupUserDefaults];

            NSString *userComputerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

            if (userComputerId) {
                NSString *fileSeparator = [userDefaults stringForKey:USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR];

                NSString *realServerPath = [DirectoryService serverPathFromParent:selectedModel.realParent name:selectedModel.realName fileSeparator:fileSeparator];

                NSString *localPath = [DirectoryService localPathFromRealServerPath:realServerPath fileSeparator:fileSeparator];

                // Either Import or Open, the file URL must be under documentStorageURL,
                // so for both Import and Open, check first if docProviderFilePath exists, then check if absolutePath exists.

                NSURL *documentStorageURL = self.documentPickerExtensionViewController.documentStorageURL;

                NSString *docProviderFilePath = [FilelugDocProviderUtility docProviderFilePathWithDocumentStorageURL:documentStorageURL
                                                                                                      userComputerId:userComputerId
                                                                                             downloadedFileLocalPath:localPath];

                NSFileManager *fileManager = [NSFileManager defaultManager];

                BOOL isDirectory;
                BOOL fileExists = [fileManager fileExistsAtPath:docProviderFilePath isDirectory:&isDirectory];

                if (fileExists || isDirectory) {
                    // must be old path if the path is a directory --> delete the cached resumeData, if any and download from the start.
                    // The FileTransfer and the directory will be deleted in [FileTransferService downloadFromStartWithTransferKey:...]

                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        [self.fileDownloadService removeResumeDataWithRealServerPath:realServerPath userComputerId:userComputerId completionHandler:^(NSError *error) {
                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                [self downloadFileFromStartWithHierarchicalModel:selectedModel tryAgainIfFailed:YES];
                            });
                        }];
                    });
                } else {
                    // no matter if local file found (and is not a directory) or not

                    [self processOnUserSelectAFileWithUserComputerId:userComputerId realServerPath:realServerPath selectedHierarchicalModel:selectedModel];
                }
            } else {
                [Utility alertInExtensionEmptyUserSessionFromViewController:self completion:nil];
            }
        }
    }
}

// For UIDocumentPickerModeOpen and UIDocumentPickerModeImport,
// make sure the file not exists in self.documentPickerExtensionViewController.documentStorageURL before invoking this method.
- (void)processOnUserSelectAFileWithUserComputerId:(NSString *)userComputerId
                                    realServerPath:(NSString *)realServerPath
                         selectedHierarchicalModel:(HierarchicalModelWithoutManaged *)selectedHierarchicalModel {
    NSError *findError;
    FileTransferWithoutManaged *fileTransferWithoutManaged = [self.fileTransferDao findFileTransferForUserComputer:userComputerId realServerPath:realServerPath error:&findError];

    if (fileTransferWithoutManaged) {
        NSFileManager *fileManager = [NSFileManager defaultManager];

        NSString *localPath = fileTransferWithoutManaged.localPath;

        NSString *status = fileTransferWithoutManaged.status;

        if ([status isEqualToString:FILE_TRANSFER_STATUS_SUCCESS]) {
            // prompt if open directly or downloading again

            NSURL *documentStorageURL = self.documentPickerExtensionViewController.documentStorageURL;

            NSString *docProviderFilePath = [FilelugDocProviderUtility docProviderFilePathWithDocumentStorageURL:documentStorageURL
                                                                                                  userComputerId:userComputerId
                                                                                         downloadedFileLocalPath:localPath];

            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"File downloaded", @"") message:NSLocalizedString(@"File already exists. if download again?", @"") preferredStyle:UIAlertControllerStyleAlert];

            // use existing file
            UIAlertAction *openExistingAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Use Existing File", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                // use existing file in local path and copy to document storage url

                // create intermediate directory of the target if not exists
                // If directory exists, sometimes error occurred even if intermediateDirectories set to YES (maybe it is because the permission owner is different)
                // So we have to test it first anyway.

                NSString *directoryOfTargetFilePath = [docProviderFilePath stringByDeletingLastPathComponent];

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
            }];

            [alertController addAction:openExistingAction];

            // download again
            UIAlertAction *downloadAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Download Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                // No need to delete old file here. Old file will be replaced when new file downloaded

                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [self downloadFileFromStartWithHierarchicalModel:selectedHierarchicalModel tryAgainIfFailed:YES];
                });
            }];

            [alertController addAction:downloadAgainAction];

            // cancel
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:nil];

            [alertController addAction:cancelAction];

            if ([self isVisible]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [alertController presentWithViewController:self sourceView:nil sourceRect:CGRectNull barButtonItem:nil animated:YES completion:nil];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [alertController presentWithAnimated:YES];
                });
            }
        } else if ([status isEqualToString:FILE_TRANSFER_STATUS_PROCESSING] || [status isEqualToString:FILE_TRANSFER_STATUS_PREPARING]) {
            // prompt to download again or keep waiting

            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"File is downloading", @"") message:NSLocalizedString(@"File is downloading. Keep waiting?", @"") preferredStyle:UIAlertControllerStyleAlert];

            // keep waiting
            UIAlertAction *tryLaterAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Keep Waiting", @"") style:UIAlertActionStyleCancel handler:nil];

            [alertController addAction:tryLaterAction];

            // download again
            UIAlertAction *downloadAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Download Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                dispatch_queue_t gQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

                dispatch_async(gQueue, ^{
                    [self.fileDownloadService cancelDownloadWithTransferKey:fileTransferWithoutManaged.transferKey completionHandler:^{
                        // try to wait for the file cancelled
                        double delayInSeconds = 1.0;

                        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));
                        dispatch_after(popTime, gQueue, ^(void) {
                            // the status now should be failure anyway

                            NSData *resumeData = [self.fileDownloadService resumeDataFromFileTransferWithTransferKey:fileTransferWithoutManaged.transferKey error:NULL];

                            if (resumeData) {
                                [self.fileDownloadService resumeDownloadWithRealFilePath:fileTransferWithoutManaged.realServerPath resumeData:resumeData completionHandler:^() {
                                    // Use NSNotification from FileTransferService to handle the processing result, so the downloading status can displayed SYNCHRONIZED
                                }];
                            } else {
                                // replace transfer key and then download from start use the new transfer key

                                // DEBUG
                                NSLog(@"Resume data not found. Download from start with file: '%@'", fileTransferWithoutManaged.realServerPath);

                                if (fileTransferWithoutManaged.downloadGroupId) {
                                    [self downloadFileWithFailedFileTransfer:fileTransferWithoutManaged tryAgainIfFailed:YES];
                                } else {
                                    // If download group id not found, meaning that the FileTransfer is downloaded before supporting download group,
                                    // all re-downloaded files must delete the current FileTransfer fist.

                                    [self downloadFileFromStartWithHierarchicalModel:selectedHierarchicalModel tryAgainIfFailed:YES];
                                }
                            }
                        });
                    }];
                });
            }];

            [alertController addAction:downloadAgainAction];

            if ([self isVisible]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [alertController presentWithViewController:self sourceView:nil sourceRect:CGRectNull barButtonItem:nil animated:YES completion:nil];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [alertController presentWithAnimated:YES];
                });
            }
        } else {
            // for download status is either failure or canceling

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSError *findError2;
                NSData *resumeData = [self.fileDownloadService resumeDataFromFileTransferWithTransferKey:fileTransferWithoutManaged.transferKey error:&findError2];

                if (resumeData) {
                    [self.fileDownloadService resumeDownloadWithRealFilePath:fileTransferWithoutManaged.realServerPath resumeData:resumeData completionHandler:^() {
                        // Use NSNotification from FileTransferService to handle the processing result, so the downloading status can displayed SYNCHRONIZED
                    }];
                } else {
                    // replace transfer key and then download from start use the new transfer key

                    // DEBUG
                    NSLog(@"Resume data not found. Download from start with file: '%@'", fileTransferWithoutManaged.realServerPath);

                    if (fileTransferWithoutManaged.downloadGroupId) {
                        [self downloadFileWithFailedFileTransfer:fileTransferWithoutManaged tryAgainIfFailed:NO];
                    } else {
                        // If download group id not found, meaning that the FileTransfer is downloaded before supporting download group,
                        // all re-downloaded files must delete the current FileTransfer fist.

                        [self downloadFileFromStartWithHierarchicalModel:selectedHierarchicalModel tryAgainIfFailed:YES];
                    }
                }
            });
        }
    } else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self downloadFileFromStartWithHierarchicalModel:selectedHierarchicalModel tryAgainIfFailed:YES];
        });
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
    return 60;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat height;

    if ([self.preferredContentSizeCategoryService isLargeContentSizeCategory]) {
        height = 80;
    } else {
        height = 60;
    }

    return height;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CenterCellIdentifier = @"CenterCell";
    static NSString *CenterDetailCellIdentifier = @"CenterDetailCell";

    UITableViewCell *cell;

    @try {
        BOOL isDirectory = [self.hierarchicalModelDao fetchedResultsController:self.fetchedResultsController isDirectoryAtIndexPath:indexPath];

        if (isDirectory) {
            cell = [tableView dequeueReusableCellWithIdentifier:CenterCellIdentifier forIndexPath:indexPath];
        } else {
            cell = [tableView dequeueReusableCellWithIdentifier:CenterDetailCellIdentifier forIndexPath:indexPath];

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
//- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
//    static NSString *CellIdentifier = @"CenterCell";
//
//    UITableViewCell *cell;
//
//    @try {
//        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
//
//        // configure the preferred font
//
//        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
//        cell.textLabel.numberOfLines = 0;
//        cell.textLabel.adjustsFontSizeToFitWidth = NO;
//        cell.textLabel.lineBreakMode = NSLineBreakByCharWrapping;
//        cell.textLabel.textAlignment = NSTextAlignmentNatural;
//
//        // Configure the cell
//        [self configureCell:cell atIndexPath:indexPath];
//    } @catch (NSException *e) {
//        [self handleFetchedResultsControllerErrorWithMethodName:@"tableView: cellForRowAtIndexPath:" exception:e directoryPath:self.parentPath reloadTableView:YES];
//    }
//
//    return cell;
//}

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
        [self handleFetchedResultsControllerErrorWithMethodName:@"controller:didChangeObject:atIndexPath:forChangeType:newIndexPath:" exception:e directoryPath:self.parentPath reloadTableView:YES];
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView endUpdates];
}

#pragma mark - Actions To Notifications From FileTransferService

// The method can work only when the extension of the application is not in the background.
// If you need something done even when the application is the background, do it in the FileTransferService
- (void)onFileDownloadDidWriteDataNotification:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;

    if (userInfo) {
        NSNumber *percentage = userInfo[NOTIFICATION_KEY_DOWNLOAD_PERCENTAGE];

        if (percentage && [percentage floatValue] > 0 && [percentage floatValue] < 1) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.downloadProgressView.progress = [percentage floatValue];
            });
        }
    }
}

// The method can work only when the extension of the application is not in the background.
// If you need something done even when the application is the background, do it in the FileTransferService
- (void)onFileDownloadDidResumeNotification:(NSNotification *)notification {
    self.downloading = @YES;

    NSDictionary *userInfo = notification.userInfo;

    if (userInfo) {
        NSNumber *transferredBytes = userInfo[NOTIFICATION_KEY_DOWNLOAD_TRANSFERRED_SIZE];
        NSNumber *totalBytes = userInfo[NOTIFICATION_KEY_DOWNLOAD_TOTAL_SIZE];

        if (transferredBytes && totalBytes) {
            float percentage = [Utility divideDenominatorDouble:[totalBytes doubleValue] byNumeratorDouble:[transferredBytes doubleValue]];

            percentage = (percentage > 1.0f) ? 1.0f : percentage;

            dispatch_async(dispatch_get_main_queue(), ^{
                self.downloadProgressView.progress = percentage;
            });
        }
    }
}

// The method can work only when the extension of the application is not in the background.
// If you need something done even when the application is the background, do it in the FileTransferService
- (void)onFileDownloadDidCompleteNotification:(NSNotification *)notification {
    self.downloading = @NO;

    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *userComputerId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

    NSDictionary *userInfo = notification.userInfo;

    if (userInfo) {
        NSString *fileTransferStatus = userInfo[NOTIFICATION_KEY_DOWNLOAD_STATUS];
        NSString *localPath = userInfo[NOTIFICATION_KEY_DOWNLOAD_FILE_LOCAL_PATH];
        NSString *realFilename = userInfo[NOTIFICATION_KEY_DOWNLOAD_REAL_FILENAME];

        if (fileTransferStatus && localPath && realFilename) {
            if ([fileTransferStatus isEqualToString:FILE_TRANSFER_STATUS_SUCCESS]) {
                NSString *absolutePath = [DirectoryService absoluteFilePathFromLocalPath:localPath userComputerId:userComputerId];

                if ([fileManager fileExistsAtPath:absolutePath]) {

                    // Either Import or Open, the file URL must be under dovcumentStorageURL,
                    // so don't have to distinguish from Import and Open

                    // copy the file from absolutePath to directory of documentStorageURL

                    NSURL *documentStorageURL = self.documentPickerExtensionViewController.documentStorageURL;

                    NSString *targetFilePath = [FilelugDocProviderUtility docProviderFilePathWithDocumentStorageURL:documentStorageURL
                                                                                                     userComputerId:userComputerId
                                                                                            downloadedFileLocalPath:localPath];

                    if (targetFilePath) {
                        BOOL isDirectory;
                        BOOL fileExists = [fileManager fileExistsAtPath:targetFilePath isDirectory:&isDirectory];

                        if (fileExists) {
                            // FIXME: detect if the target file is newer than the source, if so, prompt to ask if replaced.

                            // remove existing file or directory
                            NSError *deleteError;
                            [fileManager removeItemAtPath:targetFilePath error:&deleteError];

                            if (deleteError) {
                                NSLog(@"Error on deleting old doc provider file: %@\n%@", targetFilePath, [deleteError userInfo]);
                            }
                        }

                        // create intermediate directory of the target if not exists
                        // If directory exists, sometimes error occurred even if intermediateDirectories set to YES (maybe it is because the permission owner is different)
                        // So we have to test it first anyway.

                        NSString *directoryOfTargetFilePath = [targetFilePath stringByDeletingLastPathComponent];

                        BOOL isTargetDirectory;
                        BOOL pathExists = [fileManager fileExistsAtPath:directoryOfTargetFilePath isDirectory:&isTargetDirectory];

                        if (!pathExists || !isTargetDirectory) {
                            NSError *createError;
                            [fileManager createDirectoryAtPath:directoryOfTargetFilePath withIntermediateDirectories:YES attributes:nil error:&createError];

                            if (createError) {
                                NSLog(@"Error on creating directory: '%@'\n%@", directoryOfTargetFilePath, [createError userInfo]);
                            }
                        }

                        NSError *copyError;
                        [fileManager copyItemAtPath:absolutePath toPath:targetFilePath error:&copyError];

                        if (copyError) {
                            NSLog(@"Error on copying file: '%@' to '%@'\n%@", absolutePath, targetFilePath, [copyError userInfo]);
                        }

                        NSURL *targetFileURL = [NSURL fileURLWithPath:targetFilePath];

                        [self.documentPickerExtensionViewController dismissGrantingAccessToURL:targetFileURL];
                    } else {
                        // prompt file not found.

                        [Utility viewController:self alertWithMessageTitle:@"" messageBody:NSLocalizedString(@"File not found. Try again later.", @"") actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                    }
                }
            } else {
                NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Failed to download file %@. Try again later", @""), realFilename];

                [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
            }
        }
    }
}

// Customize the appearance of table view cells.
- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    HierarchicalModelWithoutManaged *hierarchicalModel = [self.hierarchicalModelDao fetchedResultsController:self.fetchedResultsController objectAtIndexPath:indexPath];

    if (hierarchicalModel) {
        // filter to show only the UTI is conform to one of the values in validTypes

        cell.textLabel.text = hierarchicalModel.name;

        BOOL isDirectory = [hierarchicalModel isDirectory];

        if (isDirectory) {
            cell.userInteractionEnabled = YES;
        } else {
            // detailed text label

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

            // enabled/disabled

            BOOL disabledCell;

            if (self.documentPickerExtensionViewController) {
                NSArray *validTypes = self.documentPickerExtensionViewController.validTypes;

                disabledCell = [FilelugDocProviderUtility filename:hierarchicalModel.realName conformToValidTypes:validTypes];
            } else {
                disabledCell = NO;
            }

            cell.userInteractionEnabled = !disabledCell;

            // colors for text label and detail text label are based on value of disabledCell

            if (disabledCell) {
                cell.textLabel.textColor = [UIColor lightGrayColor];
            } else {
                cell.textLabel.textColor = [UIColor darkTextColor];
            }
            
            NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:detailLabelText];
            
            if (downloadStatusDescription) {
                if (disabledCell) {
                    [attributedString setText:downloadStatusDescription withColor:[UIColor lightGrayColor]];
                } else {
                    [attributedString setText:downloadStatusDescription withColor:downloadStatusColor];
                }
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

        cell.imageView.image = image;

        if (isDirectory) {
            [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        } else {
            [cell setAccessoryType:UITableViewCellAccessoryNone];
        }

        // To resolve the width of the detail text not correctly updated
        [cell layoutSubviews];
    }
}

//- (BOOL)filename:(NSString *)filename conformToValidTypes:(NSArray *)validTypes {
//    BOOL disabledCell = YES;
//
//    if (filename && validTypes && [validTypes count] > 0) {
//        NSString *extension = [filename pathExtension];
//
//        if (extension && [extension length] > 0) {
//            CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef) extension, NULL);
//
//            for (NSString *typeString in validTypes) {
//                if (UTTypeConformsTo(uti, (__bridge CFStringRef) typeString)) {
//                    disabledCell = NO;
//
//                    break;
//                }
//            }
//        } else {
//            disabledCell = NO;
//        }
//    } else {
//        disabledCell = NO;
//    }
//
//    return disabledCell;
//}

- (void)handleFetchedResultsControllerErrorWithMethodName:(NSString *)methodNameForLogging exception:(NSException *)e directoryPath:(NSString *)directoryPath reloadTableView:(BOOL)reloadTableView {
    NSLog(@"Error on FetchedResultsController.");

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

- (void)alertToSyncHierarchicalModelsAgainWithMessagePrefix:(NSString *)messagePrefix response:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error targetParentPath:(NSString *)targetParentPath {
    UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self internalSyncHierarchicalModelsWithTargetParentPath:targetParentPath tryAgainIfFailed:YES];
        });
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self internalSyncHierarchicalModelsWithTargetParentPath:targetParentPath tryAgainIfFailed:NO];
        });
    }];
}

- (void)alertToDownloadFileFromStartAgainWithHierarchicalModel:(HierarchicalModelWithoutManaged *)hierarchicalModelWithoutManaged messagePrefix:(NSString *)messagePrefix response:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error {
    UIAlertAction *tryDownloadAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Download Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self downloadFileFromStartWithHierarchicalModel:hierarchicalModelWithoutManaged tryAgainIfFailed:YES];
        });
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryDownloadAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self downloadFileFromStartWithHierarchicalModel:hierarchicalModelWithoutManaged tryAgainIfFailed:NO];
        });
    }];
}

@end
