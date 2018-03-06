#import "RootDirectoryViewController.h"
#import "ChooseFileViewController.h"
#import "CenterViewController.h"
#import "DownloadFileViewController.h"
#import "ChooseMultipleFileViewController.h"
#import "UploadExternalFileViewController.h"
#import "FileUploadSummaryViewController.h"
#import "AppService.h"
#import "FilelugUtility.h"
#import "AppDelegate.h"
#import "FileDownloadProcessService.h"
#import "ManageComputerViewController.h"

#define kRootDirectorySectionIndexOfRootDirectories     0
#define kRootDirectorySectionIndexOfRecentDirectories   1


@interface RootDirectoryViewController ()

// elements of RootDirectoryModel
@property(nonatomic, strong) NSMutableArray *rootDirectories;

@property(nonatomic, strong) NSMutableArray<RootDirectoryModel *> *recentDirectories;

@property(nonatomic, strong) HierarchicalModelDao *hierarchicalModelDao;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) AppService *appService;

@property(nonatomic, strong) RecentDirectoryService *recentDirectoryService;

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

@property(nonatomic, strong) UserComputerDao *userComputerDao;

@end

@implementation RootDirectoryViewController

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
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Back", @"") style:UIBarButtonItemStylePlain target:self action:@selector(backward:)];
    
    [self.navigationItem setBackBarButtonItem:backButton];
}

- (void)backward:(id)sender {
    if (self.fromViewController && [self.fromViewController isKindOfClass:[DownloadFileViewController class]]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [[[FilelugUtility applicationDelegate] fileDownloadProcessService] reset];

            // DEBUG
            NSLog(@"Selected files reset.");
        });
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (!self.fromViewController) {
        self.navigationItem.rightBarButtonItems = nil;
    }
    
    // set when it's the root view controller
    if (self == self.navigationController.viewControllers[0]) {
        _fromViewController = nil;
        _directoryOnly = NO;
    }

    // adding observers

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangePreferredContentSize:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];

    [self addObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];

    [self.refreshControl addTarget:self action:@selector(reloadRootDirectories:) forControlEvents:UIControlEventValueChanged];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.refreshControl) {
            [self.refreshControl endRefreshing];
        }
    });

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    if ([userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self prepareDirectoriesWithTryAgainIfFailed:YES];

            // Ask only once if allowed notification
            [FilelugUtility promptToAllowNotificationWithViewController:self];
        });
    } else {
        [FilelugUtility alertNoComputerEverConnectedWithViewController:self delayInSeconds:0.3 completionHandler:^{
            [self.rootDirectories removeAllObjects];

            [self.recentDirectories removeAllObjects];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
        }];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    // removing observers

    [self.refreshControl removeTarget:self action:@selector(reloadRootDirectories:) forControlEvents:UIControlEventValueChanged];

    [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) context:NULL];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];
    
    if (self.progressView) {
        self.progressView = nil;
    }
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

// Can only used by refresh controller
- (void)reloadRootDirectories:(id)sender {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    if (![userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID]) {
        [FilelugUtility alertNoComputerEverConnectedWithViewController:self delayInSeconds:0.3 completionHandler:^{
            self.processing = @NO;
            
            [self.rootDirectories removeAllObjects];

            [self.recentDirectories removeAllObjects];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.refreshControl) {
                    [self.refreshControl endRefreshing];
                }
                
                [self.tableView reloadData];
            });
        }];
    } else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self prepareDirectoriesWithTryAgainIfFailed:YES];
        });
    }
}

// fetch from server, save to DB, then retrieve from DB
- (void)prepareDirectoriesWithTryAgainIfFailed:(BOOL)tryAgainIfFailed {
    if ([self presentedViewController]) {
        self.processing = @NO;

        return;
    }

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];
    
    NSString *tempLugServerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID];
    
    if (sessionId == nil || sessionId.length < 1) {
        self.processing = @NO;

        [self.rootDirectories removeAllObjects];

        [self.recentDirectories removeAllObjects];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [FilelugUtility alertEmptyUserSessionFromViewController:self];
            });
        });
    } else if (tempLugServerId == nil || tempLugServerId.length < 1) {
        [self requestConnectWithAuthService:self.authService userDefaults:userDefaults];
    } else {
        self.processing = @YES;

        NSNumber *showHidden = [userDefaults objectForKey:USER_DEFAULTS_KEY_SHOW_HIDDEN];
        
        // prepare for root directories
        RootDirectoryService *rootDirectoryService = [[RootDirectoryService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];

        [rootDirectoryService findRootsAndHomeDirectoryWithSession:sessionId showHidden: (showHidden ? [showHidden boolValue] : NO) completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

            if (statusCode == 200) {
                self.processing = @NO;

                NSError *parseError;
                self.rootDirectories = [RootDirectoryService parseJsonAsRootDirectoryModelArray:data error:&parseError];

                if (parseError) {
                    [self.rootDirectories removeAllObjects];

                    NSString *dataContent;

                    if (data && [data length] > 0) {
                        dataContent = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    } else {
                        dataContent = @"";
                    }

                    NSLog(@"Error on parsing json data as root directory array. JSON data=%@. %@, %@", dataContent, parseError, [parseError userInfo]);
                }

                self.recentDirectories = [self.recentDirectoryService recentDirectoriesForCurrentUserComputer];

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.tableView reloadData];
                });
            } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
                // Device connect to lug server via ssl, so NSURLErrorSecureConnectionFailed means lug server is probably down.

                [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                    if ([userDefaults objectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID]) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            [self prepareDirectoriesWithTryAgainIfFailed:NO];
                        });
                    } else {
                        // server not connected, so request connection

                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            [self requestConnectWithAuthService:self.authService userDefaults:userDefaults];
                        });
                    }
                } failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
                    self.processing = @NO;

                    NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                    [self alertToTryAgainWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror];
                }];
            } else if (tryAgainIfFailed && statusCode == 503) {
                // server not connected, so request connection

                [self requestConnectWithAuthService:self.authService userDefaults:userDefaults];
            } else {
                self.processing = @NO;

                if (statusCode == 465 || statusCode == 466) {
                    // version of desktop too old(465) or version of device too old(466) --> remove cached root directories

                    [self.rootDirectories removeAllObjects];

                    [self.recentDirectories removeAllObjects];

                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.tableView reloadData];
                    });
                }

                NSString *messagePrefix = NSLocalizedString(@"Error on finding all root directories.", @"");

                [self alertToTryAgainWithMessagePrefix:messagePrefix response:response data:data error:error];
            }
        }];
    }
}

- (BOOL)isLoading {
    return (self.processing && [self.processing boolValue]);
}

- (void)stopLoading {
    self.processing = @NO;
}

- (void)requestConnectWithAuthService:(AuthService *)authService userDefaults:(NSUserDefaults *)userDefaults {
    self.processing = @YES;
    
    [authService requestConnectWithSession:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] successHandler:^(NSURLResponse *rcresponse, NSData *rcdata) {
        [self prepareDirectoriesWithTryAgainIfFailed:NO];
    } failureHandler:^(NSData *rcdata, NSURLResponse *rcresponse, NSError *rcerror) {
        self.processing = @NO;
        
        [self alertToTryAgainWithMessagePrefix:nil response:rcresponse data:rcdata error:rcerror];
    }];
}

- (void)addDirectory:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        CGPoint touchPosition = [sender locationInView:self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:touchPosition];

        [self pressCellAtIndexPath:indexPath];
    }
}

- (void)pressCellAtIndexPath:(NSIndexPath *)indexPath {
    if (self.fromViewController && indexPath) {
        if ([self.fromViewController isKindOfClass:[FileUploadSummaryViewController class]]) {
            FileUploadSummaryViewController *fileUploadSummaryViewController = (FileUploadSummaryViewController *) self.fromViewController;

            RootDirectoryModel *selectedRootDirectory;

            NSInteger section = indexPath.section;

            if (section == kRootDirectorySectionIndexOfRootDirectories) {
                selectedRootDirectory = self.rootDirectories[(NSUInteger) indexPath.row];
            } else {
                selectedRootDirectory = self.recentDirectories[(NSUInteger) indexPath.row];
            }

            if (selectedRootDirectory) {
                fileUploadSummaryViewController.directory = selectedRootDirectory.directoryRealPath;
            }
            
            [self.navigationController popToViewController:fileUploadSummaryViewController animated:YES];
        } else if ([self.fromViewController isKindOfClass:[ManageComputerViewController class]]) {
            // Update the upload directory

            ManageComputerViewController *manageComputerViewController = (ManageComputerViewController *) self.fromViewController;

            RootDirectoryModel *selectedRootDirectory;

            NSInteger section = indexPath.section;

            if (section == kRootDirectorySectionIndexOfRootDirectories) {
                selectedRootDirectory = self.rootDirectories[(NSUInteger) indexPath.row];
            } else {
                selectedRootDirectory = self.recentDirectories[(NSUInteger) indexPath.row];
            }

            if (selectedRootDirectory) {
                // FIXME: make sure the directory is not the parent of the selected directory
                NSString *directory = selectedRootDirectory.directoryRealPath;
                
                if (![self.processing boolValue]) {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        self.processing = @YES;

                        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

                        NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

                        if (!sessionId || sessionId.length < 1) {
                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                [FilelugUtility alertEmptyUserSessionFromViewController:self];
                            });
                        } else {
                            [self updateUploadDirectoryWithDirectoryPath:directory session:sessionId tryAgainIfFailed:YES completionHandler:^() {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [self.navigationController popToViewController:manageComputerViewController animated:YES];
                                });
                            }];
                        }
                    });
                }
            }
        } else if ([self.fromViewController isKindOfClass:[UploadExternalFileViewController class]]) {
            UploadExternalFileViewController *uploadViewController = (UploadExternalFileViewController *) self.fromViewController;

            RootDirectoryModel *selectedRootDirectory = self.rootDirectories[(NSUInteger) indexPath.row];

            if (selectedRootDirectory) {
                NSString *directory = selectedRootDirectory.directoryRealPath;
                
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
            // User not exists or directory not provided

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

            [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    // Get the new session id, and the session should contain the user computer data
                    // because it is from the login, not login-only.
                    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

                    NSString *newSessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

                    [self updateUploadDirectoryWithDirectoryPath:directory session:newSessionId tryAgainIfFailed:NO completionHandler:completionHandler];
                });
            } failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
                self.processing = @NO;

                NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                [self alertToUpdateUploadDirectoryWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror directoryPath:directory completionHandler:completionHandler];
            }];
        } else {
            // no possible for error 503 because the service do not care about desktop socket connection

            self.processing = @NO;

            NSString *messagePrefix = NSLocalizedString(@"Failed to change upload directory2", @"");

            [self alertToUpdateUploadDirectoryWithMessagePrefix:messagePrefix response:response data:data error:error directoryPath:directory completionHandler:completionHandler];
        }
    }];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    RootDirectoryModel *selectedRootDirectory;

    NSInteger section = indexPath.section;

    if (section == kRootDirectorySectionIndexOfRootDirectories) {
        selectedRootDirectory = (self.rootDirectories)[(NSUInteger) [indexPath row]];
    } else {
        selectedRootDirectory = (self.recentDirectories)[(NSUInteger) [indexPath row]];
    }

    if (selectedRootDirectory) {
        if (self.fromViewController) {
            if ([self.fromViewController isKindOfClass:[DownloadFileViewController class]]) {
                ChooseMultipleFileViewController *fileViewController = [Utility instantiateViewControllerWithIdentifier:@"ChooseMultipleFile"];

                fileViewController.triggeredViewController = self.fromViewController;

                fileViewController.parentPath = selectedRootDirectory.directoryPath;

                [self.navigationController pushViewController:fileViewController animated:YES];
            } else {
                ChooseFileViewController *fileViewController = [Utility instantiateViewControllerWithIdentifier:@"ChooseFile"];

                fileViewController.triggeredViewController = self.fromViewController;

                fileViewController.parentPath = selectedRootDirectory.directoryPath;

                fileViewController.directoryOnly = self.directoryOnly;

                [self.navigationController pushViewController:fileViewController animated:YES];
            }
        } else {
            // go to CenterViewController
            CenterViewController *centerViewController = [Utility instantiateViewControllerWithIdentifier:@"Center"];

            centerViewController.parentPath = selectedRootDirectory.directoryPath;

            centerViewController.directoryOnly = self.directoryOnly;

            [self.navigationController pushViewController:centerViewController animated:YES];
        }
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // The first is for system disk and home directory
    // The second is for latest accessed directories
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger rowCount;

    if (section == kRootDirectorySectionIndexOfRootDirectories) {
        rowCount = self.rootDirectories ? [self.rootDirectories count] : 0;
    } else if (section == kRootDirectorySectionIndexOfRecentDirectories) {
        rowCount = self.recentDirectories ? [self.recentDirectories count] : 0;
    } else {
        rowCount = 0;
    }

    return rowCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *title;

    if (section == kRootDirectorySectionIndexOfRootDirectories) {
        title = NSLocalizedString(@"Select to browse. Pull to refresh", @"");
    } else if (section == kRootDirectorySectionIndexOfRecentDirectories && self.recentDirectories && [self.recentDirectories count] > 0) {
        title = NSLocalizedString(@"Recently accessed folders", @"");
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
    static NSString *AddIconCellIdentifier = @"RootDirectoryAddIconCell";
    static NSString *FolderIconCellIdentifier = @"RootDirectoryFolderIconCell";

    UITableViewCell *cell;

    if (self.fromViewController
            && ([self.fromViewController isKindOfClass:[FileUploadSummaryViewController class]]
            || [self.fromViewController isKindOfClass:[ManageComputerViewController class]]
            || [self.fromViewController isKindOfClass:[UploadExternalFileViewController class]])) {
        // Adding directory

        cell = [tableView dequeueReusableCellWithIdentifier:AddIconCellIdentifier forIndexPath:indexPath];

        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

        if (cell.imageView && [cell.imageView.gestureRecognizers count] < 1) {
            [Utility addTapGestureRecognizerForImageView:cell.imageView withTarget:self action:@selector(addDirectory:)];
        }

        // configure the preferred font
        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        cell.textLabel.textColor = [UIColor darkTextColor];
        cell.textLabel.numberOfLines = 1;
        cell.textLabel.adjustsFontSizeToFitWidth = NO;
        cell.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        cell.textLabel.textAlignment = NSTextAlignmentNatural;

        cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
        cell.detailTextLabel.textColor = [UIColor aquaColor];
        cell.detailTextLabel.numberOfLines = 0;
        cell.detailTextLabel.adjustsFontSizeToFitWidth = NO;
        cell.detailTextLabel.lineBreakMode = NSLineBreakByCharWrapping;
        cell.detailTextLabel.textAlignment = NSTextAlignmentNatural;

        RootDirectoryModel *rootDirectory;

        NSInteger section = indexPath.section;

        if (section == kRootDirectorySectionIndexOfRootDirectories) {
            rootDirectory = self.rootDirectories[(NSUInteger) indexPath.row];
        } else if (section == kRootDirectorySectionIndexOfRecentDirectories) {
            rootDirectory = self.recentDirectories[(NSUInteger) indexPath.row];
        }

        if (rootDirectory) {
            // Title
            [cell.textLabel setText:[rootDirectory displayNameForCellLabelText]];

            // Detail
            [cell.detailTextLabel setText:rootDirectory.directoryPath];
        }
    } else {
        // Browse directory

        cell = [Utility tableView:tableView createOrDequeueCellWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:FolderIconCellIdentifier forIndexPath:indexPath];

        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

        // configure the preferred font
        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        cell.textLabel.textColor = [UIColor darkTextColor];
        cell.textLabel.numberOfLines = 1;
        cell.textLabel.adjustsFontSizeToFitWidth = NO;
        cell.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        cell.textLabel.textAlignment = NSTextAlignmentNatural;

        cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
        cell.detailTextLabel.textColor = [UIColor aquaColor];
        cell.detailTextLabel.numberOfLines = 0;
        cell.detailTextLabel.adjustsFontSizeToFitWidth = NO;
        cell.detailTextLabel.lineBreakMode = NSLineBreakByCharWrapping;
        cell.detailTextLabel.textAlignment = NSTextAlignmentNatural;

        RootDirectoryModel *rootDirectory;
        
        NSInteger section = indexPath.section;

        if (section == kRootDirectorySectionIndexOfRootDirectories) {
            rootDirectory = self.rootDirectories[(NSUInteger) indexPath.row];
        } else if (section == kRootDirectorySectionIndexOfRecentDirectories) {
            rootDirectory = self.recentDirectories[(NSUInteger) indexPath.row];
        }

        if (rootDirectory) {
            // Image
            cell.imageView.image = [UIImage imageNamed:[RootDirectoryService imageNameFromRootDirectoryType:rootDirectory.type]];
            // Title
            cell.textLabel.text = [rootDirectory displayNameForCellLabelText];
            // Detail
            cell.detailTextLabel.text = rootDirectory.directoryPath;
        }
    }
    
    return cell;
}

//- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
//    // only recent directory can be deleted
//    return indexPath.section > 0;
//}
//
//- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
//    if (editingStyle == UITableViewCellEditingStyleDelete) {
//        [self deleteRowAtIndexPath:indexPath];
//    }
//}
//
//- (void)deleteRowAtIndexPath:(NSIndexPath *)indexPath {
//    if (indexPath.section == kRootDirectorySectionIndexOfRecentDirectories) {
//        // delete the data of selected recent directory in local db and reload table
//
//        NSInteger rowIndex = indexPath.row;
//
//        if (self.recentDirectories && [self.recentDirectories count] >= rowIndex) {
//            RootDirectoryModel *rootDirectoryModel = self.recentDirectories[(NSUInteger) rowIndex];
//
//            if (rootDirectoryModel) {
//                NSString *directoryPath = rootDirectoryModel.directoryPath;
//
//                [self.recentDirectoryService deleteRecentDirectoryWithDirectoryPath:directoryPath successHandler:^() {
//                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                        self.recentDirectories = [self.recentDirectoryService recentDirectoriesForCurrentUserComputer];
//
//                        dispatch_async(dispatch_get_main_queue(), ^{
//                            [self.tableView reloadData];
//                        });
//                    });
//                }];
//            }
//        }
//    }
//}

- (void)alertToTryAgainWithMessagePrefix:messagePrefix response:response data:data error:error {
    UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self prepareDirectoriesWithTryAgainIfFailed:YES];
        });
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self prepareDirectoriesWithTryAgainIfFailed:NO];
        });
    }];
}

- (void)alertToUpdateUploadDirectoryWithMessagePrefix:(NSString *)messagePrefix response:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error directoryPath:(NSString *)directory completionHandler:(void (^)(void))completionHandler {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // Get the new session id, and the session should contain the user computer data
            // because it is from the login, not login-only.
            NSString *newSessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

            [self updateUploadDirectoryWithDirectoryPath:directory session:newSessionId tryAgainIfFailed:YES completionHandler:completionHandler];
        });
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // Get the new session id, and the session should contain the user computer data
            // because it is from the login, not login-only.
            NSString *newSessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

            [self updateUploadDirectoryWithDirectoryPath:directory session:newSessionId tryAgainIfFailed:NO completionHandler:completionHandler];
        });
    }];
}

@end
