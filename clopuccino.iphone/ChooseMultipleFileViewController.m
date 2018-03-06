#import "ChooseMultipleFileViewController.h"
#import "DownloadFileViewController.h"
#import "AppService.h"
#import "FilelugUtility.h"
#import "FileDownloadProcessService.h"
#import "AppDelegate.h"

@interface ChooseMultipleFileViewController ()

@property(nonatomic, strong) BBBadgeBarButtonItem *downloadItem;

@property(nonatomic, strong) FileTransferDao *fileTransferDao;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) AppService *appService;

@property(nonatomic, strong) UIButton *downloadButton;

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

@property(nonatomic, strong) FileDownloadProcessService *downloadProcessService;

@end

@implementation ChooseMultipleFileViewController
    
@synthesize processing;
    
@synthesize progressView;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.processing = @NO;

    [Utility viewController:self useNavigationLargeTitles:YES];

    _preferredContentSizeCategoryService = [[PreferredContentSizeCategoryService alloc] init];

    _downloadProcessService = [[FilelugUtility applicationDelegate] fileDownloadProcessService];
    
    // Download bar button item with badge
    
    _downloadButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
    [_downloadButton setImage:[UIImage imageNamed:@"download"] forState:UIControlStateNormal];
    
    BBBadgeBarButtonItem *badgeBarButtonItem = [[BBBadgeBarButtonItem alloc] initWithCustomUIButton:_downloadButton];
    
    badgeBarButtonItem.badgeOriginX = 22;
    badgeBarButtonItem.badgeOriginY = 0;
    badgeBarButtonItem.badgeBGColor = [Utility colorFromHexString:@"#007AFF" alpha:1.0];
    badgeBarButtonItem.badgeTextColor = [UIColor whiteColor];
    
    self.downloadItem = badgeBarButtonItem;

    self.navigationItem.rightBarButtonItems = @[self.downloadItem];

    // refresh control
    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    
    [refresh setAttributedTitle:[[NSAttributedString alloc] initWithString:NSLocalizedString(@"Pull to refresh", @"")]];

    self.refreshControl = refresh;
    
    // Change the back button for the next view controller
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Back", @"") style:UIBarButtonItemStylePlain target:nil action:nil];
    
    [self.navigationItem setBackBarButtonItem:backButton];
    
    // Set the title
    if (_parentPath) {
        [self.navigationItem setTitle:[DirectoryService directoryNameFromServerDirectoryPath:_parentPath]];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // update download with or without badge

    NSUInteger count = [self.downloadProcessService.selectedHierarchicalModels count];

    self.downloadItem.badgeValue = [NSString stringWithFormat:@"%ld", (unsigned long)count];
    
    self.downloadItem.shouldHideBadgeAtZero = YES;
    
    [self.downloadItem setEnabled:(count > 0)];

    [self.hierarchicalModelDao fetchedResultsController:self.fetchedResultsController performFetch:NULL];

    // adding observers

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangePreferredContentSize:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];

    [self addObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];

    [self.downloadButton addTarget:self action:@selector(doneSelectionFiles:) forControlEvents:UIControlEventTouchUpInside];

    [self.refreshControl addTarget:self action:@selector(prepareDirectories:) forControlEvents:UIControlEventValueChanged];
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
            [self prepareDirectories];
        } else {
            // When files removed in FileDownloadSummaryViewController and back to this view controller,
            // the selected states are changed and must be updated.
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self.refreshControl removeTarget:self action:@selector(prepareDirectories:) forControlEvents:UIControlEventValueChanged];

    [self.downloadButton removeTarget:self action:@selector(doneSelectionFiles:) forControlEvents:UIControlEventTouchUpInside];

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

- (AppService *)appService {
    if (!_appService) {
        _appService = [[AppService alloc] init];
    }
    
    return _appService;
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

- (void)doneSelectionFiles:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.downloadProcessService pushToDownloadSummaryViewControllerFromViewController:self];
    });
}

- (void)prepareDirectories:(id)sender {
    [self prepareDirectories];
}

- (void)prepareDirectories {
    /* keep the current parent path,
     * in case the value changed when getting data back and
     * try to synchronized with the existing ones.
     */
    NSString *targetParentPath = [NSString stringWithString:self.parentPath];
    
    /* fetch from server, save to DB, then retrieve from DB */
    [self internalPrepareDirectoriesWithTargetParentPath:targetParentPath tryAgainIfFailed:YES];
}

- (void)internalPrepareDirectoriesWithTargetParentPath:(NSString *)targetParentPath tryAgainIfFailed:(BOOL)tryAgainIfFailed {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

        NSString *tempLugServerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID];

        if (sessionId == nil || sessionId.length < 1) {
            [FilelugUtility alertEmptyUserSessionFromViewController:self];
//        [FilelugUtility alertUserNeverConnectedWithViewController:self loginSuccessHandler:^(NSURLResponse *response, NSData *data) {
//            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                self.processing = @NO;
//
//                [self internalPrepareDirectoriesWithUserComputer:userComputerId targetParentPath:targetParentPath];
//            });
//        }];
        } else if (tempLugServerId == nil || tempLugServerId.length < 1) {
            [self requestConnectForPreparingDirectoriesWithAuthService:self.authService userDefaults:userDefaults targetParentPath:targetParentPath];
        } else {
            // prepare for hierarchical model
            if (targetParentPath) {
                self.processing = @YES;

                DirectoryService *directoryService = [[DirectoryService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];

                [directoryService listDirectoryChildrenWithParent:targetParentPath session:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                    self.processing = @NO;

                    NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

                    if (statusCode == 200) {
                        NSString *userComputerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

                        [self.hierarchicalModelDao parseJsonAndSyncWithCurrentHierarchicalModels:data userComputer:userComputerId parentPath:targetParentPath completionHandler:^{
                        }];
                    } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
                        self.processing = @YES;

                        [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                            if ([userDefaults objectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID]) {
                                [self internalPrepareDirectoriesWithTargetParentPath:targetParentPath tryAgainIfFailed:NO];
                            } else {
                                [self requestConnectForPreparingDirectoriesWithAuthService:self.authService userDefaults:userDefaults targetParentPath:targetParentPath];
                            }
                        } failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
                            self.processing = @NO;

                            NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                            [self alertToTryAgainWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror];
                        }];
//                    [self.appService authService:self.authService reloginCurrentUserComputerFromViewController:self successHandler:^(NSURLResponse *lresponse, NSData *ldata) {
//                        self.processing = @NO;
//
//                        if ([userDefaults objectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID]) {
//                            NSString *userComputerId2 = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];
//
//                            [self internalPrepareDirectoriesWithUserComputer:userComputerId2 targetParentPath:targetParentPath];
//                        } else {
//                            [self requestConnectForPreparingDirectoriesWithAuthService:self.authService userDefaults:userDefaults targetParentPath:targetParentPath];
//                        }
//                    } failureHandler:^(NSURLResponse *lresponse, NSData *ldata, NSError *lerror) {
//                        self.processing = @NO;
//
//                        NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");
//
//                        [self alertToTryAgainWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror];
//                    }];
                    } else if (tryAgainIfFailed && statusCode == 503) {
                        // server not connected, so request connection
                        [self requestConnectForPreparingDirectoriesWithAuthService:self.authService userDefaults:userDefaults targetParentPath:targetParentPath];
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

- (void)requestConnectForPreparingDirectoriesWithAuthService:(AuthService *)authService userDefaults:(NSUserDefaults *)userDefaults targetParentPath:(NSString *)targetParentPath {
    self.processing = @YES;
    
    [authService requestConnectWithSession:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] successHandler:^(NSURLResponse *rcresponse, NSData *rcdata) {
        self.processing = @NO;

        [self internalPrepareDirectoriesWithTargetParentPath:targetParentPath tryAgainIfFailed:NO];
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

#pragma mark - Table view delegate

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    return [self tableView:tableView beforeSelectRowAtIndexPath:indexPath];
}

- (NSIndexPath *)tableView:(UITableView *)tableView willDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    return [self tableView:tableView beforeSelectRowAtIndexPath:indexPath];
}

- (NSIndexPath *)tableView:(UITableView *)tableView beforeSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    
    BOOL shouldContinue = YES;
    
    // Make sure the file is not downloaded, processing, or cancelling
    
    HierarchicalModelWithoutManaged *selectedModel = [self.hierarchicalModelDao fetchedResultsController:self.fetchedResultsController objectAtIndexPath:indexPath];

    if (selectedModel) {
        NSString *realFilePath = [DirectoryService serverPathFromParent:selectedModel.realParent name:selectedModel.realName];

        NSUserDefaults *userDefaults = [Utility groupUserDefaults];
        NSString *userComputerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

        NSError *findError;
        FileTransferWithoutManaged *fileTransfer = [self.fileTransferDao findFileTransferForUserComputer:userComputerId realServerPath:realFilePath error:&findError];

        if (fileTransfer) {
            NSString *status = fileTransfer.status;

            if ([status isEqualToString:FILE_TRANSFER_STATUS_SUCCESS]) {
                shouldContinue = NO;

                NSString *message = [NSString stringWithFormat:NSLocalizedString(@"File '%@' downloaded. Find the file information in Menu > Download File", @""), selectedModel.name];

                [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
            } else if ([status isEqualToString:FILE_TRANSFER_STATUS_PROCESSING]) {
                shouldContinue = NO;

                NSString *message = [NSString stringWithFormat:NSLocalizedString(@"File '%@' is downloading and can't be selected now.", @""), selectedModel.name];

                [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
            } else if ([status isEqualToString:FILE_TRANSFER_STATUS_CANCELING]) {
                shouldContinue = NO;

                NSString *message = [NSString stringWithFormat:NSLocalizedString(@"File '%@' is canceling download and can't be selected now.", @""), selectedModel.name];

                [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
            }
        }
    }
    
    if (shouldContinue) {
        if (selectedModel && ![selectedModel isDirectory]) {
            if ([self selectedHierarchicalModelsContains:selectedModel]) {
                // deselect it
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self removeFromSelectedHierarchicalModelsWithHierarchicalModel:selectedModel];
                    
                    [cell setAccessoryType:UITableViewCellAccessoryNone];

                    NSUInteger count = [self.downloadProcessService.selectedHierarchicalModels count];

                    self.downloadItem.badgeValue = [NSString stringWithFormat:@"%ld", (unsigned long)count];
                    
                    [self.downloadItem setEnabled:(count > 0)];
                });
            } else {
                // select it - change to checked style and add it to selected list

                [self.downloadProcessService.selectedHierarchicalModels addObject:selectedModel];

                // update download badge

                NSUInteger count = [self.downloadProcessService.selectedHierarchicalModels count];

                dispatch_async(dispatch_get_main_queue(), ^{
                    self.downloadItem.badgeValue = [NSString stringWithFormat:@"%ld", (unsigned long)count];
                    
                    [self.downloadItem setEnabled:(count > 0)];
                    
                    [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
                });
            }
        }
    } else {
        return nil;
    }
    
    return indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    HierarchicalModelWithoutManaged *selectedModel = [self.hierarchicalModelDao fetchedResultsController:self.fetchedResultsController objectAtIndexPath:indexPath];
    
    if (selectedModel && [selectedModel isDirectory]) {
        // Deselect the row to prevent invoking 'tableView: willDeselectRowAtIndexPath:'
        // when pressing the same row after going back from child view controller.
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView deselectRowAtIndexPath:indexPath animated:NO];
        });
        
        ChooseMultipleFileViewController *childViewController = [Utility instantiateViewControllerWithIdentifier:@"ChooseMultipleFile"];
        
        childViewController.parentPath = [DirectoryService serverPathFromParent:selectedModel.realParent name:selectedModel.realName];
        
        childViewController.triggeredViewController = self.triggeredViewController;

        [self.navigationController pushViewController:childViewController animated:YES];
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

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger count;
    
    @try {
        count = [self.hierarchicalModelDao fetchedResultsController:self.fetchedResultsController numberOfRowsInSection:section];
    } @catch (NSException *e) {
        [self handleFetchedResultsControllerErrorWithMethodName:@"tableView: numberOfRowsInSection:" exception:e directoryPath:self.parentPath reloadTableView:YES];
    }
    
    return count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *title;
    
    @try {
        if (self.triggeredViewController) {
            NSString *type = [self.hierarchicalModelDao fetchedResultsController:self.fetchedResultsController sectionName:section];
            
            if ([self.triggeredViewController isKindOfClass:[DownloadFileViewController class]]) {
                if ([type isEqualToString:HIERARCHICAL_MODEL_TYPE_DIRECTORY]) {
                    title = [NSLocalizedString([type lowercaseString], @"") stringByAppendingFormat:@": %@", NSLocalizedString(@"Select to browse", @"")];
                } else {
                    title = [NSLocalizedString([type lowercaseString], @"") stringByAppendingFormat:@": %@", NSLocalizedString(@"Select multiple files to download", @"")];
                }
            }
        }
    } @catch (NSException *e) {
        [self handleFetchedResultsControllerErrorWithMethodName:@"tableView: titleForHeaderInSection:" exception:e directoryPath:self.parentPath reloadTableView:YES];
    }
    
    return title;
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
    static NSString *FolderIconCellIdentifier = @"ChooseFileFolderIconCell";
    static NSString *CheckedStyleCellIdentifier = @"ChooseFileCheckedStyleCell";
    UITableViewCell *cell;
    
    @try {
        BOOL isDirectory = [self.hierarchicalModelDao fetchedResultsController:self.fetchedResultsController isDirectoryAtIndexPath:indexPath];

        if (isDirectory) {
            cell = [Utility tableView:tableView createOrDequeueCellWithStyle:UITableViewCellStyleDefault reuseIdentifier:FolderIconCellIdentifier forIndexPath:indexPath];

            [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        } else {
            cell = [Utility tableView:tableView createOrDequeueCellWithStyle:UITableViewCellStyleDefault reuseIdentifier:CheckedStyleCellIdentifier forIndexPath:indexPath];

            // configure the preferred font for detailed text label

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

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    HierarchicalModelWithoutManaged *hierarchicalModel = [self.hierarchicalModelDao fetchedResultsController:self.fetchedResultsController objectAtIndexPath:indexPath];

    if (hierarchicalModel) {
        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        cell.textLabel.text = hierarchicalModel.name;

        BOOL isDirectory = hierarchicalModel.isDirectory;

        if (!isDirectory) {
            BOOL alreadySelected = [self selectedHierarchicalModelsContains:hierarchicalModel];

            // Check if exists in FileTransfer to decide if the cell should disabled or not

            NSString *realFilePath = [DirectoryService serverPathFromParent:hierarchicalModel.realParent name:hierarchicalModel.realName];

            NSString *userComputerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

            BOOL fileTransferExists = [self.fileTransferDao existsTransferForUserComputer:userComputerId realServerPath:realFilePath error:NULL];

            if (fileTransferExists) {
                [cell setUserInteractionEnabled:NO];

                [cell setAccessoryType:UITableViewCellAccessoryNone];

                if (alreadySelected) {
                    // remove selection
                    [self.downloadProcessService.selectedHierarchicalModels removeObject:hierarchicalModel];
                }

                [cell.textLabel setEnabled:NO];
            } else {
                [cell setUserInteractionEnabled:YES];

                if (alreadySelected) {
                    [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
                } else {
                    [cell setAccessoryType:UITableViewCellAccessoryNone];
                }

                [cell.textLabel setEnabled:YES];
            }

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

        NSString *separator = [userDefaults stringForKey:USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR];

        if (separator) {
            image = [DirectoryService imageForFile:hierarchicalModel fileSeparator:separator];
        } else {
            if ([hierarchicalModel isDirectory]) {
                image = [UIImage imageNamed:@"ic_folder"];
            } else {
                image = [UIImage imageNamed:@"ic_file"];
            }
        }

        cell.imageView.image = image;

        // To resolve the width of the detail text not correctly updated
        [cell layoutSubviews];
    }
}

// Before introducing download status for detailed text label
//- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
//    static NSString *FolderIconCellIdentifier = @"ChooseFileFolderIconCell";
//    static NSString *CheckedStyleCellIdentifier = @"ChooseFileCheckedStyleCell";
//    UITableViewCell *cell;
//
//    @try {
//        HierarchicalModelWithoutManaged *hierarchicalModel = [self.hierarchicalModelDao fetchedResultsController:self.fetchedResultsController objectAtIndexPath:indexPath];
//
//        if (hierarchicalModel) {
//            if ([hierarchicalModel isDirectory]) {
//                cell = [Utility tableView:tableView createOrDequeueCellWithStyle:UITableViewCellStyleDefault reuseIdentifier:FolderIconCellIdentifier forIndexPath:indexPath];
//
//                [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
//
//                // configure the preferred font
//                cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
//                cell.textLabel.textColor = [UIColor darkTextColor];
//                cell.textLabel.numberOfLines = 0;
//                cell.textLabel.adjustsFontSizeToFitWidth = NO;
//                cell.textLabel.lineBreakMode = NSLineBreakByCharWrapping;
//                cell.textLabel.textAlignment = NSTextAlignmentNatural;
//
//                [cell.textLabel setText:hierarchicalModel.name];
//            } else {
//                cell = [Utility tableView:tableView createOrDequeueCellWithStyle:UITableViewCellStyleDefault reuseIdentifier:CheckedStyleCellIdentifier forIndexPath:indexPath];
//
//                BOOL alreadySelected = [self selectedHierarchicalModelsContains:hierarchicalModel];
//
//                // Check if exists in FileTransfer to decide if the cell should disabled or not
//
//                NSString *realFilePath = [DirectoryService serverPathFromParent:hierarchicalModel.realParent name:hierarchicalModel.realName];
//
//                NSUserDefaults *userDefaults = [Utility groupUserDefaults];
//
//                NSString *userComputerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];
//
//                BOOL fileTransferExists = [self.fileTransferDao existsTransferForUserComputer:userComputerId realServerPath:realFilePath error:NULL];
//
//                if (fileTransferExists) {
//                    [cell setUserInteractionEnabled:NO];
//
//                    [cell setAccessoryType:UITableViewCellAccessoryNone];
//
//                    if (alreadySelected) {
//                        // remove selection
//                        [self.downloadProcessService.selectedHierarchicalModels removeObject:hierarchicalModel];
//                    }
//
//                    [cell.textLabel setEnabled:NO];
//                } else {
//                    [cell setUserInteractionEnabled:YES];
//
//                    if (alreadySelected) {
//                        [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
//                    } else {
//                        [cell setAccessoryType:UITableViewCellAccessoryNone];
//                    }
//
//                    [cell.textLabel setEnabled:YES];
//                }
//
//                // configure the preferred font
//                cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
//                cell.textLabel.textColor = [UIColor darkTextColor];
//                cell.textLabel.numberOfLines = 0;
//                cell.textLabel.adjustsFontSizeToFitWidth = NO;
//                cell.textLabel.lineBreakMode = NSLineBreakByCharWrapping;
//                cell.textLabel.textAlignment = NSTextAlignmentNatural;
//
//                [cell.textLabel setText:hierarchicalModel.name];
//
//                cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
//                cell.detailTextLabel.textColor = [UIColor lightGrayColor];
//                cell.detailTextLabel.numberOfLines = 1;
//                cell.detailTextLabel.adjustsFontSizeToFitWidth = NO;
//                cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingTail;
//                cell.detailTextLabel.textAlignment = NSTextAlignmentNatural;
//
//                NSString *displaySize = hierarchicalModel.displaySize;
//
//                NSString *lastModified;
//
//                NSString *lastModifiedFromServer = hierarchicalModel.lastModified;
//
//                if (lastModifiedFromServer) {
//                    NSDate *lastModifiedDate = [Utility dateFromString:lastModifiedFromServer format:DATE_FORMAT_FOR_SERVER];
//
//                    if (lastModifiedDate) {
//                        lastModified = [Utility dateStringFromDate:lastModifiedDate];
//                    }
//                }
//
//                NSString *detailLabelText;
//
//                if (lastModified) {
//                    detailLabelText = [NSString stringWithFormat:@"%@, %@", displaySize, lastModified];
//                } else {
//                    detailLabelText = [NSString stringWithFormat:@"%@", displaySize];
//                }
//
//                cell.detailTextLabel.text = detailLabelText;
//
//                UIImage *image;
//
//                NSString *separator = [userDefaults stringForKey:USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR];
//
//                if (separator) {
//                    image = [DirectoryService imageForFile:hierarchicalModel fileSeparator:separator];
//                } else {
//                    if ([hierarchicalModel isDirectory]) {
//                        image = [UIImage imageNamed:@"ic_folder"];
//                    } else {
//                        image = [UIImage imageNamed:@"ic_file"];
//                    }
//                }
//
//                cell.imageView.image = image;
//            }
//
//            // To resolve the width of the detail text not correctly updated
//            [cell layoutSubviews];
//        }
//    } @catch (NSException *e) {
//        [self handleFetchedResultsControllerErrorWithMethodName:@"tableView: cellForRowAtIndexPath:" exception:e directoryPath:self.parentPath reloadTableView:YES];
//    }
//
//    return cell;
//}

- (BOOL)selectedHierarchicalModelsContains:(HierarchicalModelWithoutManaged *)hierarchicalModel {
    NSMutableArray *selectedHierarchicalModels = self.downloadProcessService.selectedHierarchicalModels;

    if (selectedHierarchicalModels) {
        for (HierarchicalModelWithoutManaged *currentHierarchicalModel in selectedHierarchicalModels) {
            if ([currentHierarchicalModel.realParent isEqualToString:hierarchicalModel.realParent] && [currentHierarchicalModel.realName isEqualToString:hierarchicalModel.realName]) {
                return YES;
            }
        }
    }

    return NO;
}

- (void)removeFromSelectedHierarchicalModelsWithHierarchicalModel:(HierarchicalModelWithoutManaged *)hierarchicalModel {
    NSMutableArray *selectedHierarchicalModels = self.downloadProcessService.selectedHierarchicalModels;

    if (selectedHierarchicalModels) {
        for (HierarchicalModelWithoutManaged *currentHierarchicalModel in selectedHierarchicalModels) {
            if ([currentHierarchicalModel.realParent isEqualToString:hierarchicalModel.realParent] && [currentHierarchicalModel.realName isEqualToString:hierarchicalModel.realName]) {
                [selectedHierarchicalModels removeObject:currentHierarchicalModel];
                
                break;
            }
        }
    }
}

#pragma mark - Fetched results controller delegate

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
//                [self.tableView cellForRowAtIndexPath:indexPath];
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

- (void)alertToTryAgainWithMessagePrefix:messagePrefix response:response data:data error:error {
    UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        NSString *targetParentPath = [NSString stringWithString:self.parentPath];

        [self internalPrepareDirectoriesWithTargetParentPath:targetParentPath tryAgainIfFailed:YES];
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        NSString *targetParentPath = [NSString stringWithString:self.parentPath];

        [self internalPrepareDirectoriesWithTargetParentPath:targetParentPath tryAgainIfFailed:NO];
    }];
}

@end
