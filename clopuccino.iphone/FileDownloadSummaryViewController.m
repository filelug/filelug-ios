#import "FileDownloadSummaryViewController.h"
#import "AppService.h"
#import "FileDownloadProcessService.h"
#import "FilelugUtility.h"
#import "FilelugFileDownloadService.h"

@interface FileDownloadSummaryViewController ()

@property(nonatomic, strong) UIBarButtonItem *downloadBarButtonItem;

@property(nonatomic, strong) DirectoryService *directoryService;

@property(nonatomic, strong) FileDownloadGroupDao *fileDownloadGroupDao;

@property(nonatomic, strong) UserComputerDao *userComputerDao;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) AppService *appService;

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

@property(nonatomic, strong) DownloadNotificationService *downloadNotificationService;

@property(nonatomic, strong) FileDownloadProcessService *downloadProcessService;

// Used to count how many files already go into uploading process
// When the value equals to the total files to be uploaded, pop to FileUploadViewController
// atomic(the default value if not provided) is used to make sure thread-safe
@property(atomic) NSUInteger downloadedCount;

@property(nonatomic, strong) FilelugFileDownloadService *fileDownloadService;

@end

const NSInteger TABLE_VIEW_SECTION_TO_LIST_DOWNLOAD_FILES = 2;

@implementation FileDownloadSummaryViewController
    
@synthesize processing;
    
@synthesize progressView;

- (void)viewDidLoad {
    [super viewDidLoad];

    self.processing = @NO;

    [Utility viewController:self useNavigationLargeTitles:YES];

    _downloadProcessService = [FileDownloadProcessService defaultService];

    _preferredContentSizeCategoryService = [[PreferredContentSizeCategoryService alloc] init];

    [self.navigationItem setTitle:NSLocalizedString(@"Download Summary", @"")];

    _downloadBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"download2", @"") style:UIBarButtonItemStylePlain target:self action:@selector(downloadSelectedFiles:)];

    [self.navigationItem setRightBarButtonItems:@[_downloadBarButtonItem] animated:YES];

    // Change the back button for the next view controller
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel", @"") style:UIBarButtonItemStylePlain target:nil action:nil];

    [self.navigationItem setBackBarButtonItem:backButton];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if ([self isMovingToParentViewController]) {
        // get download-related settings from db only when being pushed into, not back from other view controller
        // because any change to download-related profiles won't be persisted into db nor preferences
        self.downloadNotificationService = [[DownloadNotificationService alloc] initWithPersistedType];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });

    // adding observers

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangePreferredContentSize:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];

    [self addObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];

//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onFileDownloadDidCompleteNotification:) name:NOTIFICATION_NAME_FILE_DOWNLOAD_DID_COMPLETE object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // So the download button refreshed after updated
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];

        BOOL atLeastOneFileToDownload = [self tableView:self.tableView numberOfRowsInSection:TABLE_VIEW_SECTION_TO_LIST_DOWNLOAD_FILES] > 0;

        [self.downloadBarButtonItem setEnabled:atLeastOneFileToDownload];
    });
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

//    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_NAME_FILE_DOWNLOAD_DID_COMPLETE object:nil];

    [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) context:NULL];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
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

- (UserComputerDao *)userComputerDao {
    if (!_userComputerDao) {
        _userComputerDao = [[UserComputerDao alloc] init];
    }

    return _userComputerDao;
}

- (FilelugFileDownloadService *)fileDownloadService {
    if (!_fileDownloadService) {
        _fileDownloadService = [[FilelugFileDownloadService alloc] init];
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

- (void)downloadSelectedFiles:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self internalDoDownloadFileWithTryAgainIfFailed:YES];
    });
}

- (void)internalDoDownloadFileWithTryAgainIfFailed:(BOOL)tryAgainIfFailed {
    if ([self.downloadProcessService.selectedHierarchicalModels count] > 0) {
        [self setDownloadedCount:0];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSArray *selectedModels = [self.downloadProcessService.selectedHierarchicalModels copy];

            if (selectedModels && [selectedModels count] > 0) {
                NSUserDefaults *userDefaults = [Utility groupUserDefaults];

                NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

                NSString *tempLugServerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID];

                if (sessionId == nil || sessionId.length < 1) {
                    [FilelugUtility alertEmptyUserSessionFromViewController:self];
                } else if (tempLugServerId == nil || tempLugServerId.length < 1) {
                    [self requestConnectForDownloadWithAuthService:self.authService userDefaults:userDefaults];
                } else {
                    self.processing = @YES;

                    SystemService *systemService = [[SystemService alloc] initWithCachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeInterval:CONNECTION_TIME_INTERVAL];

                    dispatch_queue_t globalConcurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

                    [systemService pingDesktop:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                        dispatch_async(globalConcurrentQueue, ^{
                            self.processing = @NO;

                            NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

                            if (statusCode == 200) {
                                [SystemService parsePingDesktopResponseJson:data completionHandler:^(NSDictionary *dictionary) {
                                    BOOL canDownload = YES;

                                    if (dictionary) {
                                        NSNumber *downloadSizeLimit = dictionary[@"download-size-limit"];

                                        if (!downloadSizeLimit || !selectedModels) {
                                            canDownload = NO;
                                        } else {
                                            for (HierarchicalModelWithoutManaged *hierarchicalModel in selectedModels) {
                                                if ([downloadSizeLimit unsignedLongLongValue] < [hierarchicalModel.sizeInBytes doubleValue]) {
                                                    canDownload = NO;

                                                    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"exceed.download.size.limit2", @""), hierarchicalModel.name];

                                                    [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];

                                                    break;
                                                }
                                            }
                                        }
                                    }

                                    // create download summary in server

                                    if (canDownload) {
                                        // The queue will be used in dispatch_barrier_async, so it must an concurrent queue and created by dispatch_queue_create
                                        dispatch_queue_t concurrentQueueForBarrier = dispatch_queue_create(DISPATCH_QUEUE_DOWNLOAD_CONCURRENT, DISPATCH_QUEUE_CONCURRENT);

                                        dispatch_async(concurrentQueueForBarrier, ^{
                                            self.processing = @YES;

                                            NSString *fileSeparator = [userDefaults stringForKey:USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR];

                                            NSMutableDictionary *transferKeyAndRealFilePaths = [NSMutableDictionary dictionary];

                                            NSMutableArray *filenames = [NSMutableArray array];

                                            NSMutableArray *transferKeys = [NSMutableArray array];

                                            for (HierarchicalModelWithoutManaged *hierarchicalModel in selectedModels) {
                                                NSString *realFilePath = [DirectoryService serverPathFromParent:hierarchicalModel.realParent name:hierarchicalModel.realName fileSeparator:fileSeparator];

                                                [filenames addObject:hierarchicalModel.realName];

                                                // generate new transfer key - unique for all users
                                                NSString *transferKey = [Utility generateDownloadKeyWithSessionId:sessionId realFilePath:realFilePath];

                                                [transferKeys addObject:transferKey];

                                                transferKeyAndRealFilePaths[transferKey] = realFilePath;
                                            }

                                            NSInteger notificationType = self.downloadNotificationService.type ? [self.downloadNotificationService.type integerValue] : [DownloadNotificationService defaultType];

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
                                                          // download file one by one

                                                          dispatch_async(concurrentQueueForBarrier, ^{
                                                              @try {
                                                                  // set actions after download
                                                                  NSString *actionsAfterDownload = [FileTransferWithoutManaged prepareActionsAfterDownloadWithOpen:NO share:NO];

                                                                  const NSUInteger fileCount = [selectedModels count];

                                                                  for (NSUInteger index = 0; index < fileCount; index++) {
                                                                      NSString *transferKey = transferKeys[index];

                                                                      NSString *realServerPath = transferKeyAndRealFilePaths[transferKey];

                                                                      [self.fileDownloadService downloadFromStartWithTransferKey:transferKey realServerPath:realServerPath fileSeparator:fileSeparator downloadGroupId:downloadGroupId userComputerId:userComputerId sessionId:sessionId actionsAfterDownload:actionsAfterDownload addToStartTimestampWithMilliseconds:index completionHandler:^() {
                                                                          // When all files started to download, pop to fromViewController

                                                                          // Use dispatch_barrier_async to make sure the block in it will be serialized processed by the queue.
                                                                          // Be sure that the queue is an concurrent queue and created by dispatch_queue_create

                                                                          dispatch_barrier_async(concurrentQueueForBarrier, ^{
                                                                              self.downloadedCount += 1;

                                                                              if (fileCount == self.downloadedCount) {
                                                                                  // delay to prevent it won't pop to fromViewController because of the download speeds too fast

                                                                                  double delayInSeconds = 1.0;
                                                                                  dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));
                                                                                  dispatch_after(popTime, globalConcurrentQueue, ^(void) {
                                                                                      [self popToFromViewController];
                                                                                  });
                                                                              }
                                                                          });
                                                                      }];
                                                                  }
                                                              } @finally {
                                                                  self.processing = @NO;
                                                              }
                                                          });
                                                      }];
                                                  } else {
                                                      self.processing = @NO;

                                                      NSString *messagePrefix = NSLocalizedString(@"Error on download file.", @"");

                                                      [self alertToTryDownloadAgainWithMessagePrefix:messagePrefix response:responseFromCreate data:dataFromCreate error:errorFromCreate];
                                                  }
                                              }];
                                        });
                                    }
                                }];
                            } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
                                self.processing = @YES;

                                [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                                    if ([userDefaults objectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID]) {
                                        dispatch_async(globalConcurrentQueue, ^{
                                            [self internalDoDownloadFileWithTryAgainIfFailed:NO];
                                        });
                                    } else {
                                        [self requestConnectForDownloadWithAuthService:self.authService userDefaults:userDefaults];
                                    }
                                } failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
                                    self.processing = @NO;

                                    NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                                    [self alertToTryDownloadAgainWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror];
                                }];
                            } else if (tryAgainIfFailed && statusCode == 503) {
                                // server not connected, so request connection
                                [self requestConnectForDownloadWithAuthService:self.authService userDefaults:userDefaults];
                            } else {
                                self.processing = @NO;

                                NSString *messagePrefix = NSLocalizedString(@"Error on download file.", @"");

                                [self alertToTryDownloadAgainWithMessagePrefix:messagePrefix response:response data:data error:error];
                            }
                        });
                    }];
                }
            }
        });
    }
}

// clear selected hierarchical models and pop to fromViewController
- (void)popToFromViewController {
    [self.downloadProcessService reset];

    UIViewController *fromViewController = (id) [self.downloadProcessService fromViewController];

    if (fromViewController) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[self navigationController] popToViewController:fromViewController animated:YES];
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[self navigationController] popToRootViewControllerAnimated:YES];
        });
    }
}

- (void)requestConnectForDownloadWithAuthService:(AuthService *)authService userDefaults:(NSUserDefaults *)userDefaults {
    self.processing = @YES;

    [authService requestConnectWithSession:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] successHandler:^(NSURLResponse *rcresponse, NSData *rcdata) {
        self.processing = @NO;

        [self internalDoDownloadFileWithTryAgainIfFailed:NO];
    } failureHandler:^(NSData *rcdata, NSURLResponse *rcresponse, NSError *rcerror) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self alertToTryDownloadAgainWithMessagePrefix:nil response:rcresponse data:rcdata error:rcerror];
        });
    }];
}

- (void)alertToTryDownloadAgainWithMessagePrefix:messagePrefix response:response data:data error:error {
    UIAlertAction *tryDownloadAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Download Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self internalDoDownloadFileWithTryAgainIfFailed:YES];
        });
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryDownloadAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self internalDoDownloadFileWithTryAgainIfFailed:NO];
        });
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
    [self tableView:tableView internalDidSelectRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    [self tableView:tableView internalDidSelectRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView internalDidSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSInteger section = indexPath.section;
        NSInteger row = indexPath.row;

        if (section == 0) {
            if (row == 0) {
                // notification

                NSArray *allNames = [DownloadNotificationService namesOfAllTypesWithOrder];
                
                if (allNames) {
                    NSString *actionSheetTitle = NSLocalizedString(@"Choose type of upload notification", @"");

                    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:actionSheetTitle message:@"" preferredStyle:UIAlertControllerStyleActionSheet];
                    
                    for (NSString *name in allNames) {
                        NSNumber *notificationType = [DownloadNotificationService downloadNotificationTypeWithDownloadNotificationName:name];
                        
                        if (notificationType) {
                            UIAlertAction *notificationNameAction = [UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                                self.downloadNotificationService = [[DownloadNotificationService alloc] initWithDownloadNotificationType:notificationType];

                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [self.tableView reloadData];
                                });
                            }];
                            
                            BOOL enabledAction = !self.downloadNotificationService.type || ![self.downloadNotificationService.name isEqualToString:name];
                            
                            [notificationNameAction setEnabled:enabledAction];
                            
                            [actionSheet addAction:notificationNameAction];
                        }
                    }

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
                }
            }
        }
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *title;

    if (section == 0) {
        title = NSLocalizedString(@"Settings", @"");
    } else if (section == 1) {
        NSString *totalDisplaySize = [self sizeOfAllFiles];

        title = [NSString stringWithFormat:NSLocalizedString(@"Files selected to download (Total)", @""), totalDisplaySize];
    }

    return title;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    NSString *title;

    if (section == 1) {
        title = NSLocalizedString(@"Slide to remove from selection.", @"");
    }

    return title;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger row;

    if (section == 0) {
        // notification

        row = 1;
    } else if (section == TABLE_VIEW_SECTION_TO_LIST_DOWNLOAD_FILES) {
        // hierarchical models

        row = self.downloadProcessService.selectedHierarchicalModels ? [self.downloadProcessService.selectedHierarchicalModels count] : 0;
    } else {
        row = 0;
    }

    return row;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat height;

    if (indexPath.section < 1) {
        if ([self.preferredContentSizeCategoryService isXXLargeContentSizeCategory]) {
            height = 100;
        } else if ([self.preferredContentSizeCategoryService isLargeContentSizeCategory]) {
            height = 80;
        } else {
            height = 60;
        }
    } else {
        if ([self.preferredContentSizeCategoryService isLargeContentSizeCategory]) {
            height = 80;
        } else {
            height = 60;
        }
    }

    return height;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *DownloadSummarySettingCell = @"DownloadSummarySettingCell";
    static NSString *DownloadSummaryFileCell = @"DownloadSummaryFileCell";

    UITableViewCell *cell;

    NSInteger section = [indexPath section];
    NSInteger row = [indexPath row];

    if (section == 0) {
        cell = [Utility tableView:tableView createOrDequeueCellWithStyle:UITableViewCellStyleDefault reuseIdentifier:DownloadSummarySettingCell forIndexPath:indexPath];

        // configure the preferred font

        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        cell.textLabel.textColor = [UIColor darkTextColor];
        cell.textLabel.numberOfLines = 1;
        cell.textLabel.adjustsFontSizeToFitWidth = NO;
        cell.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        cell.textLabel.textAlignment = NSTextAlignmentNatural;

        cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        cell.detailTextLabel.textColor = [UIColor aquaColor];
        cell.detailTextLabel.numberOfLines = 0;
        cell.detailTextLabel.adjustsFontSizeToFitWidth = NO;
        cell.detailTextLabel.lineBreakMode = NSLineBreakByCharWrapping;
        cell.detailTextLabel.textAlignment = NSTextAlignmentNatural;

        if (row == 0) {
            // notification

            [cell setAccessoryType:UITableViewCellAccessoryNone];

            [cell.imageView setImage:[UIImage imageNamed:@"bell"]];

            [cell.textLabel setText:NSLocalizedString(@"Upload Notification", @"")];

            [cell.detailTextLabel setText:[self.downloadNotificationService name]];
        } else {
            // for unknow rows

            [cell setAccessoryType:UITableViewCellAccessoryNone];

            [cell.imageView setImage:[UIImage imageNamed:@"ic_folder"]];

            [cell.textLabel setText:@""];

            [cell.detailTextLabel setText:@""];
        }
    } else if (section == TABLE_VIEW_SECTION_TO_LIST_DOWNLOAD_FILES) {
        cell = [Utility tableView:tableView createOrDequeueCellWithStyle:UITableViewCellStyleDefault reuseIdentifier:DownloadSummaryFileCell forIndexPath:indexPath];

        // configure the preferred font

        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        cell.textLabel.textColor = [UIColor darkTextColor];
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.adjustsFontSizeToFitWidth = NO;
        cell.textLabel.lineBreakMode = NSLineBreakByCharWrapping;
        cell.textLabel.textAlignment = NSTextAlignmentNatural;

        cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
        cell.detailTextLabel.textColor = [UIColor lightGrayColor];
        cell.detailTextLabel.numberOfLines = 0;
        cell.detailTextLabel.adjustsFontSizeToFitWidth = NO;
        cell.detailTextLabel.lineBreakMode = NSLineBreakByCharWrapping;
        cell.detailTextLabel.textAlignment = NSTextAlignmentNatural;

        [cell setAccessoryType:UITableViewCellAccessoryNone];

        HierarchicalModelWithoutManaged *hierarchicalModelWithoutManaged = self.downloadProcessService.selectedHierarchicalModels[(NSUInteger) row];

        NSString *realFilename = hierarchicalModelWithoutManaged.realName;

        [cell.imageView setImage:[DirectoryService imageForLocalFilePath:realFilename isDirectory:NO]];

        [cell.textLabel setText:realFilename];

        [cell.detailTextLabel setText:hierarchicalModelWithoutManaged.realParent];
    }

    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == TABLE_VIEW_SECTION_TO_LIST_DOWNLOAD_FILES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        @try {
            NSUInteger rowIndex = (NSUInteger) indexPath.row;

            [self.downloadProcessService.selectedHierarchicalModels removeObjectAtIndex:rowIndex];

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
        } @catch(NSException *e) {
            NSLog(@"Error on deleting row at: %ld\n%@", (long) indexPath.row, e.userInfo);
        }

        if ([self tableView:tableView numberOfRowsInSection:TABLE_VIEW_SECTION_TO_LIST_DOWNLOAD_FILES] < 1) {
            // no row to download --> disabled download bar button item

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.downloadBarButtonItem setEnabled:NO];
            });
        }
    }
}

- (NSString *)sizeOfAllFiles {
    NSString *totalDisplaySize;

    NSArray<HierarchicalModel *> *models = self.downloadProcessService.selectedHierarchicalModels;

    if (models && [models count] > 0) {
        double totalSizeLong = 0;

        for (HierarchicalModel *model in models) {
            NSNumber *sizeNumber = model.sizeInBytes;

            if (sizeNumber) {
                double size = [sizeNumber doubleValue];
                totalSizeLong += size;
            }
        }

        totalDisplaySize = [Utility byteCountToDisplaySize:(long long int) totalSizeLong];
    } else {
        totalDisplaySize = @"0";
    }

    return totalDisplaySize;
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
