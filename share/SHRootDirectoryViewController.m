#import "SHRootDirectoryViewController.h"
#import "ShareUtility.h"
#import "ShareViewController.h"
#import "SHChooseFileViewController.h"

#define kSHRootDirectorySectionIndexOfRootDirectories     0
#define kSHRootDirectorySectionIndexOfRecentDirectories   1

@interface SHRootDirectoryViewController ()

// elements of RootDirectoryModel
@property(nonatomic, strong) NSMutableArray *rootDirectories;

@property(nonatomic, strong) NSMutableArray<RootDirectoryModel *> *recentDirectories;

@property(nonatomic, strong) HierarchicalModelDao *hierarchicalModelDao;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) RecentDirectoryService *recentDirectoryService;

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

@end

@implementation SHRootDirectoryViewController

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

    if (!self.fromViewController) {
        self.navigationItem.rightBarButtonItems = nil;
    }

    // set when it's the root view controller
    if (self == self.navigationController.viewControllers[0]) {
        _fromViewController = nil;
    }

    self.navigationItem.title = NSLocalizedString(@"Browse File", @"");

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
        });
    } else {
        [self.rootDirectories removeAllObjects];

        [self.recentDirectories removeAllObjects];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });

        [Utility alertInExtensionEmptyUserSessionFromViewController:self completion:nil];
//        [Utility alertInExtensionUserNeverConnectedFromViewController:self completion:nil];
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

- (RecentDirectoryService *)recentDirectoryService {
    if (!_recentDirectoryService) {
        _recentDirectoryService = [[RecentDirectoryService alloc] init];
    }

    return _recentDirectoryService;
}

- (BOOL)isLoading {
    return (self.processing && [self.processing boolValue]);
}

- (void)stopLoading {
    self.processing = @NO;
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
        self.processing = @NO;

        [self.rootDirectories removeAllObjects];

        [self.recentDirectories removeAllObjects];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.refreshControl) {
                [self.refreshControl endRefreshing];
            }

            [self.tableView reloadData];
        });

        [Utility alertInExtensionEmptyUserSessionFromViewController:self completion:nil];
//        [Utility alertInExtensionUserNeverConnectedFromViewController:self completion:nil];
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
                [Utility alertInExtensionEmptyUserSessionFromViewController:self completion:nil];
            });
        });
    } else if (tempLugServerId == nil || tempLugServerId.length < 1) {
        [self requestConnectWithAuthService:self.authService userDefaults:userDefaults];
    } else {
        self.processing = @YES;

        NSNumber *showHidden = [userDefaults objectForKey:USER_DEFAULTS_KEY_SHOW_HIDDEN];

        // prepare for root directories
        RootDirectoryService *rootDirectoryService = [[RootDirectoryService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];

        [rootDirectoryService findRootsAndHomeDirectoryWithSession:sessionId showHidden:(showHidden ? [showHidden boolValue] : NO) completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
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

- (void)requestConnectWithAuthService:(AuthService *)authService userDefaults:(NSUserDefaults *)userDefaults {
    self.processing = @YES;

    [authService requestConnectWithSession:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] successHandler:^(NSURLResponse *rcresponse, NSData *rcdata) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self prepareDirectoriesWithTryAgainIfFailed:NO];
        });
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
        if ([self.fromViewController isKindOfClass:[ShareViewController class]]) {
            ShareViewController *shareViewController = (ShareViewController *) self.fromViewController;

            RootDirectoryModel *selectedRootDirectory;

            NSInteger section = indexPath.section;

            if (section == kSHRootDirectorySectionIndexOfRootDirectories) {
                selectedRootDirectory = (self.rootDirectories)[(NSUInteger) [indexPath row]];
            } else {
                selectedRootDirectory = (self.recentDirectories)[(NSUInteger) [indexPath row]];
            }

            if (selectedRootDirectory) {
                NSString *directory = selectedRootDirectory.directoryPath;

                shareViewController.directory = directory;
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.navigationController popToViewController:shareViewController animated:YES];
            });
        }
    }
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    RootDirectoryModel *selectedRootDirectory;

    NSInteger section = indexPath.section;

    if (section == kSHRootDirectorySectionIndexOfRootDirectories) {
        selectedRootDirectory = (self.rootDirectories)[(NSUInteger) [indexPath row]];
    } else {
        selectedRootDirectory = (self.recentDirectories)[(NSUInteger) [indexPath row]];
    }

    if (selectedRootDirectory) {
        if (self.fromViewController) {
            if ([self.fromViewController isKindOfClass:[ShareViewController class]]) {
                SHChooseFileViewController *fileViewController = [ShareUtility instantiateViewControllerWithIdentifier:@"SHChooseFile"];

                fileViewController.triggeredViewController = self.fromViewController;

                fileViewController.parentPath = selectedRootDirectory.directoryPath;

                [self.navigationController pushViewController:fileViewController animated:YES];
            }
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

    if (section == kSHRootDirectorySectionIndexOfRootDirectories) {
        rowCount = self.rootDirectories ? [self.rootDirectories count] : 0;
    } else if (section == kSHRootDirectorySectionIndexOfRecentDirectories) {
        rowCount = self.recentDirectories ? [self.recentDirectories count] : 0;
    } else {
        rowCount = 0;
    }

    return rowCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *title;

    if (section == kSHRootDirectorySectionIndexOfRootDirectories) {
        title = NSLocalizedString(@"Select to browse. Pull to refresh", @"");
    } else if (section == kSHRootDirectorySectionIndexOfRecentDirectories && self.recentDirectories && [self.recentDirectories count] > 0) {
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
    static NSString *AddIconCellIdentifier = @"RootDirectoryAddingCell";

    UITableViewCell *cell;

    if (self.fromViewController && [self.fromViewController isKindOfClass:[ShareViewController class]]) {
        cell = [tableView dequeueReusableCellWithIdentifier:AddIconCellIdentifier forIndexPath:indexPath];

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

        cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        cell.detailTextLabel.textColor = [UIColor aquaColor];
        cell.detailTextLabel.numberOfLines = 0;
        cell.detailTextLabel.adjustsFontSizeToFitWidth = NO;
        cell.detailTextLabel.lineBreakMode = NSLineBreakByCharWrapping;
        cell.detailTextLabel.textAlignment = NSTextAlignmentNatural;

        RootDirectoryModel *rootDirectory;

        NSInteger section = indexPath.section;

        if (section == kSHRootDirectorySectionIndexOfRootDirectories) {
            rootDirectory = self.rootDirectories[(NSUInteger) indexPath.row];
        } else if (section == kSHRootDirectorySectionIndexOfRecentDirectories) {
            rootDirectory = self.recentDirectories[(NSUInteger) indexPath.row];
        }

        if (rootDirectory) {
            // Title
            [cell.textLabel setText:[rootDirectory displayNameForCellLabelText]];

            // Detail
            [cell.detailTextLabel setText:rootDirectory.directoryPath];
        }
    }

    return cell;
}

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

@end
