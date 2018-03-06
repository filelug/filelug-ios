#import "ChooseFileViewController.h"
#import "objc/runtime.h"
#import "UploadExternalFileViewController.h"
#import "SettingsViewController.h"
#import "FileUploadSummaryViewController.h"
#import "AppService.h"
#import "FilelugUtility.h"
#import "ManageComputerViewController.h"

@interface ChooseFileViewController ()

@property(nonatomic, strong) UIBarButtonItem *cancelItem;

@property(nonatomic, strong) FileTransferDao *fileTransferDao;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) AppService *appService;

@property(nonatomic, strong) RecentDirectoryService *recentDirectoryService;

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

@property(nonatomic, strong) UserComputerDao *userComputerDao;

@end

@implementation ChooseFileViewController
    
@synthesize processing;
    
@synthesize progressView;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.processing = @NO;

    [Utility viewController:self useNavigationLargeTitles:YES];

    _preferredContentSizeCategoryService = [[PreferredContentSizeCategoryService alloc] init];

    self.cancelItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelChoose:)];
    
    self.navigationItem.rightBarButtonItems = @[self.cancelItem];

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

    [self.hierarchicalModelDao fetchedResultsController:self.fetchedResultsController performFetch:NULL];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangePreferredContentSize:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];

    [self addObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];

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
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self.refreshControl removeTarget:self action:@selector(prepareDirectories:) forControlEvents:UIControlEventValueChanged];

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

- (RecentDirectoryService *)recentDirectoryService {
    if (!_recentDirectoryService) {
        _recentDirectoryService = [[RecentDirectoryService alloc] init];
    }

    return _recentDirectoryService;
}

- (UserComputerDao *)userComputerDao {
    if (!_userComputerDao) {
        _userComputerDao = [[UserComputerDao alloc] init];
    }

    return _userComputerDao;
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

- (void)cancelChoose:(id)sender {
    [self.navigationController popToViewController:self.triggeredViewController animated:YES];
}

- (void)addDirectory:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        CGPoint touchPosition = [sender locationInView:self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:touchPosition];

        [self pressCellAtIndexPath:indexPath];
    }
}

- (void)createOrUpdateRecentDirectoryWithHierarchicalModel:(HierarchicalModelWithoutManaged *)hierarchicalModel {
    NSString *directoryPath = [DirectoryService serverPathFromParent:hierarchicalModel.parent name:hierarchicalModel.name];;
    NSString *directoryRealPath = [DirectoryService serverPathFromParent:hierarchicalModel.realParent name:hierarchicalModel.realName];

    [self.recentDirectoryService createOrUpdateRecentDirectoryWithDirectoryPath:directoryPath directoryRealPath:directoryRealPath completionHandler:nil];
}

- (void)pressCellAtIndexPath:(NSIndexPath *)indexPath {
    if (self.triggeredViewController && indexPath) {
        if ([self.triggeredViewController isKindOfClass:[FileUploadSummaryViewController class]]) {
            FileUploadSummaryViewController *fileUploadSummaryViewController = (FileUploadSummaryViewController *) self.triggeredViewController;
            
            HierarchicalModelWithoutManaged *selectedHierarchicalModel = [self.hierarchicalModelDao fetchedResultsController:self.fetchedResultsController objectAtIndexPath:indexPath];
            
            if (selectedHierarchicalModel) {
                // create/update recent directories
                [self createOrUpdateRecentDirectoryWithHierarchicalModel:selectedHierarchicalModel];

                fileUploadSummaryViewController.directory = [DirectoryService serverPathFromParent:selectedHierarchicalModel.realParent name:selectedHierarchicalModel.realName];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.navigationController popToViewController:fileUploadSummaryViewController animated:YES];
            });
        } else if ([self.triggeredViewController isKindOfClass:[ManageComputerViewController class]]) {
            // Update the upload directory

            ManageComputerViewController *manageComputerViewController = (ManageComputerViewController *) self.triggeredViewController;
            
            HierarchicalModelWithoutManaged *selectedHierarchicalModel = [self.hierarchicalModelDao fetchedResultsController:self.fetchedResultsController objectAtIndexPath:indexPath];
            
            if (selectedHierarchicalModel) {
                NSString *directory = [DirectoryService serverPathFromParent:selectedHierarchicalModel.realParent name:selectedHierarchicalModel.realName];
                
                if (![self.processing boolValue]) {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        self.processing = @YES;
                        
                        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

                        NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];
                        
                        if (!sessionId || sessionId.length < 1) {
                            [FilelugUtility alertEmptyUserSessionFromViewController:self];
                        } else {
                            // create/update recent directories
                            [self createOrUpdateRecentDirectoryWithHierarchicalModel:selectedHierarchicalModel];

                            // Save permanently to the server and update local db and preferences in local

                            [self updateUploadDirectoryWithDirectoryPath:directory session:sessionId tryAgainIfFailed:YES completionHandler:^() {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [self.navigationController popToViewController:manageComputerViewController animated:YES];
                                });
                            }];
                        }
                    });
                }
            }
        } else if ([self.triggeredViewController isKindOfClass:[UploadExternalFileViewController class]]) {
            UploadExternalFileViewController *uploadViewController = (UploadExternalFileViewController *) self.triggeredViewController;
            
            HierarchicalModelWithoutManaged *selectedHierarchicalModel = [self.hierarchicalModelDao fetchedResultsController:self.fetchedResultsController objectAtIndexPath:indexPath];
            
            if (selectedHierarchicalModel) {
                // create/update recent directories
                [self createOrUpdateRecentDirectoryWithHierarchicalModel:selectedHierarchicalModel];

                NSString *directory = [DirectoryService serverPathFromParent:selectedHierarchicalModel.realParent name:selectedHierarchicalModel.realName];
                uploadViewController.directory = directory;
            }
            
            [self.navigationController popToViewController:uploadViewController animated:YES];
        }
    }
}

- (void)updateUploadDirectoryWithDirectoryPath:(NSString *)directory session:(NSString *)sessionId tryAgainIfFailed:(BOOL)tryAgainIfFailed completionHandler:(void (^)(void))completionHandler {
    self.processing = @YES;
    
    // prepare for root directories
    UserComputerService *userComputerService = [[UserComputerService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];

    NSDictionary *profiles = @{@"upload-directory" : directory};

    [userComputerService updateUserComputerProfilesWithProfiles:profiles session:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        self.processing = @NO;
        
        NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];
        
        if (statusCode == 200) {
            // Save to local db and update preferences

            NSUserDefaults *userDefaults = [Utility groupUserDefaults];

            NSString *userComputerId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

            if (userComputerId) {
                UserComputerWithoutManaged *userComputerWithoutManaged = [self.userComputerDao findUserComputerForUserComputerId:userComputerId];

                if (userComputerWithoutManaged) {
                    userComputerWithoutManaged.uploadDirectory = directory;

                    [self.userComputerDao updateUserComputerWithUserComputerWithoutManaged:userComputerWithoutManaged completionHandler:^(NSError *updateError){
                        if (updateError) {
                            NSLog(@"Error on updating upload directory with: '%@'\n%@", directory, [updateError userInfo]);
                        } else {
                            // update preference
                            [userDefaults setObject:directory forKey:USER_DEFAULTS_KEY_UPLOAD_DIRECTORY];
                        }
                    }];
                }
            }

            if (completionHandler) {
                completionHandler();
            }
        } else if (statusCode == 400) {
            // User not exists or profiles not provided
            
            NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            
            NSString *message;
            if (responseString && responseString.length > 0) {
                message = [NSString stringWithFormat:NSLocalizedString(@"Failed to change upload directory", @""), responseString];
            } else {
                message = NSLocalizedString(@"Failed to change upload directory2", @"");
            }
            
            [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
        } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
            self.processing = @YES;

            // Use login instead of login-only because we need to make sure the user-computer exists.
            // But we do not care if desktop connected. So we don't care if value of lug-server-id exits.

            [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                // Get the new session id, and the session should contain the user computer data
                // because it is from the login, not login-only.

                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

                    NSString *newSessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

                    [self updateUploadDirectoryWithDirectoryPath:directory session:newSessionId tryAgainIfFailed:NO completionHandler:completionHandler];
                });
            } failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
                self.processing = @NO;

                NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                [self alertToTryUpdateUploadDirectoryAgainWithDirectory:directory messagePrefix:messagePrefix response:lresponse data:ldata error:lerror tryAgainCompletionHandler:completionHandler];
            }];
//            [self.appService authService:self.authService reloginCurrentUserComputerFromViewController:self successHandler:^(NSURLResponse *lresponse, NSData *ldata) {
//                self.processing = @NO;
//
//                // Get the new session id, and the session should contain the user computer data
//                // because it is from the login, not login-only.
//
//                NSUserDefaults *userDefaults = [Utility groupUserDefaults];
//
//                NSString *newSessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];
//
//                [self updateUploadDirectoryWithDirectoryPath:directory session:newSessionId completionHandler:completionHandler];
//            } failureHandler:^(NSURLResponse *lresponse, NSData *ldata, NSError *lerror) {
//                self.processing = @NO;
//
//                NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");
//
//                [self alertToTryUpdateUploadDirectoryAgainWithDirectory:directory messagePrefix:messagePrefix response:lresponse data:ldata error:lerror tryAgainCompletionHandler:completionHandler];
//            }];
        } else {
            // no possible for error 503 because the service do not care about desktop socket connection
            
            self.processing = @NO;
            
            NSString *messagePrefix = NSLocalizedString(@"Failed to change upload directory2", @"");

            [self alertToTryUpdateUploadDirectoryAgainWithDirectory:directory messagePrefix:messagePrefix response:response data:data error:error tryAgainCompletionHandler:completionHandler];
        }
    }];
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
            [self requestConnectWithAuthService:self.authService userDefaults:userDefaults targetParentPath:targetParentPath];
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
                                [self requestConnectWithAuthService:self.authService userDefaults:userDefaults targetParentPath:targetParentPath];
                            }
                        } failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
                            self.processing = @NO;

                            NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                            [self alertToTryPrepareDirectoriesAgainWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror];
                        }];
//                    [self.appService authService:self.authService reloginCurrentUserComputerFromViewController:self successHandler:^(NSURLResponse *lresponse, NSData *ldata) {
//                        self.processing = @NO;
//
//                        if ([userDefaults objectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID]) {
//                            NSString *newUserComputerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];
//
//                            [self internalPrepareDirectoriesWithUserComputer:newUserComputerId targetParentPath:targetParentPath];
//                        } else {
//                            [self requestConnectWithAuthService:self.authService userDefaults:userDefaults targetParentPath:targetParentPath];
//                        }
//                    } failureHandler:^(NSURLResponse *lresponse, NSData *ldata, NSError *lerror) {
//                        self.processing = @NO;
//
//                        NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");
//
//                        [self alertToTryPrepareDirectoriesAgainWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror];
//                    }];
                    } else if (tryAgainIfFailed && statusCode == 503) {
                        // server not connected, so request connection
                        [self requestConnectWithAuthService:self.authService userDefaults:userDefaults targetParentPath:targetParentPath];
                    } else {
                        self.processing = @NO;

                        NSString *messagePrefix = NSLocalizedString(@"Error on finding directory children.", @"");

                        [self alertToTryPrepareDirectoriesAgainWithMessagePrefix:messagePrefix response:response data:data error:error];
                    }
                }];
            } else {
                self.processing = @NO;

                NSLog(@"No directory selected.");
            }
        }
    });
}

- (void)requestConnectWithAuthService:(AuthService *)authService userDefaults:(NSUserDefaults *)userDefaults targetParentPath:(NSString *)targetParentPath {
    self.processing = @YES;
    
    [authService requestConnectWithSession:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] successHandler:^(NSURLResponse *rcresponse, NSData *rcdata) {
        self.processing = @NO;

        [self internalPrepareDirectoriesWithTargetParentPath:targetParentPath tryAgainIfFailed:NO];
    } failureHandler:^(NSData *rcdata, NSURLResponse *rcresponse, NSError *rcerror) {
        self.processing = @NO;
        
        [self alertToTryPrepareDirectoriesAgainWithMessagePrefix:nil response:rcresponse data:rcdata error:rcerror];
    }];
}

- (BOOL)isLoading {
    return (self.processing && [self.processing boolValue]);
}

- (void)stopLoading {
    self.processing = @NO;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    HierarchicalModelWithoutManaged *selectedModel = [self.hierarchicalModelDao fetchedResultsController:self.fetchedResultsController objectAtIndexPath:indexPath];
    
    if (selectedModel) {
        if ([selectedModel isDirectory]) {
            ChooseFileViewController *childViewController = [Utility instantiateViewControllerWithIdentifier:@"ChooseFile"];
            
            childViewController.parentPath = [DirectoryService serverPathFromParent:selectedModel.realParent name:selectedModel.realName];
            
            childViewController.directoryOnly = self.directoryOnly;
            
            childViewController.triggeredViewController = self.triggeredViewController;
            
            [self.navigationController pushViewController:childViewController animated:YES];
        } else if (!self.directoryOnly) {
            [self pressCellAtIndexPath:indexPath];
        }
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
            
            if ([self.triggeredViewController isKindOfClass:[FileUploadSummaryViewController class]]) {
                title = [NSLocalizedString([type lowercaseString], @"") stringByAppendingFormat:@": %@", NSLocalizedString(@"Click add button to upload file to the directory", @"")];
            }
        }

        if (!title) {
            title = NSLocalizedString(@"Select to browse. Pull to refresh", @"");
        }
    } @catch (NSException *e) {
        [self handleFetchedResultsControllerErrorWithMethodName:@"tableView: titleForHeaderInSection:" exception:e directoryPath:self.parentPath reloadTableView:YES];
    }
    
    return title;
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
    static NSString *AddingCellIdentifier = @"ChooseFileAddingCell";
    static NSString *FolderIconCellIdentifier = @"ChooseFileFolderIconCell";
    UITableViewCell *cell;
    
    @try {
        HierarchicalModelWithoutManaged *hierarchicalModel = [self.hierarchicalModelDao fetchedResultsController:self.fetchedResultsController objectAtIndexPath:indexPath];
        
        if (hierarchicalModel) {
            if ([hierarchicalModel isDirectory]) {
                if (self.directoryOnly) {
                    cell = [tableView dequeueReusableCellWithIdentifier:AddingCellIdentifier forIndexPath:indexPath];
                    
                    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];

                    if (cell.imageView) {
                        [Utility addTapGestureRecognizerForImageView:cell.imageView withTarget:self action:@selector(addDirectory:)];
                    }

                    // configure the preferred font
                    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
                    cell.textLabel.textColor = [UIColor darkTextColor];
                    cell.textLabel.numberOfLines = 0;
                    cell.textLabel.adjustsFontSizeToFitWidth = NO;
                    cell.textLabel.lineBreakMode = NSLineBreakByCharWrapping;
                    cell.textLabel.textAlignment = NSTextAlignmentNatural;

                    cell.textLabel.text = hierarchicalModel.name;
                } else {
                    cell = [tableView dequeueReusableCellWithIdentifier:FolderIconCellIdentifier forIndexPath:indexPath];
                    
                    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];

                    // configure the preferred font
                    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
                    cell.textLabel.textColor = [UIColor darkTextColor];
                    cell.textLabel.numberOfLines = 0;
                    cell.textLabel.adjustsFontSizeToFitWidth = NO;
                    cell.textLabel.lineBreakMode = NSLineBreakByCharWrapping;
                    cell.textLabel.textAlignment = NSTextAlignmentNatural;
                    
                    [cell.textLabel setText:hierarchicalModel.name];
                }
            } else {
                if (!self.directoryOnly) {
                    cell = [tableView dequeueReusableCellWithIdentifier:AddingCellIdentifier forIndexPath:indexPath];
                    
                    [cell setAccessoryType:UITableViewCellAccessoryNone];

                    if (cell.imageView && [cell.imageView.gestureRecognizers count] < 1) {
                        [Utility addTapGestureRecognizerForImageView:cell.imageView withTarget:self action:@selector(addDirectory:)];
                    }

                    // configure the preferred font
                    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
                    cell.textLabel.textColor = [UIColor darkTextColor];
                    cell.textLabel.numberOfLines = 0;
                    cell.textLabel.adjustsFontSizeToFitWidth = NO;
                    cell.textLabel.lineBreakMode = NSLineBreakByCharWrapping;
                    cell.textLabel.textAlignment = NSTextAlignmentNatural;

                    cell.textLabel.text = hierarchicalModel.name;
                }
            }
        }
    } @catch (NSException *e) {
        [self handleFetchedResultsControllerErrorWithMethodName:@"tableView: cellForRowAtIndexPath:" exception:e directoryPath:self.parentPath reloadTableView:YES];
    }
    
    return cell;
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
                [self.tableView cellForRowAtIndexPath:indexPath];
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

- (void)alertToTryUpdateUploadDirectoryAgainWithDirectory:(NSString *)directory messagePrefix:messagePrefix response:response data:data error:error tryAgainCompletionHandler:(void(^)(void))completionHandler {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *newSessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

            [self updateUploadDirectoryWithDirectoryPath:directory session:newSessionId tryAgainIfFailed:YES completionHandler:completionHandler];
        });
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *newSessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

            [self updateUploadDirectoryWithDirectoryPath:directory session:newSessionId tryAgainIfFailed:NO completionHandler:completionHandler];
        });
    }];
}

- (void)alertToTryPrepareDirectoriesAgainWithMessagePrefix:messagePrefix response:response data:data error:error {
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
