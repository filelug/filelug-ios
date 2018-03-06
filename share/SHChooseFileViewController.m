#import "SHChooseFileViewController.h"
#import "ShareViewController.h"
#import "ShareUtility.h"

@interface SHChooseFileViewController ()

@property(nonatomic, strong) UIBarButtonItem *cancelItem;

@property(nonatomic, strong) FileTransferDao *fileTransferDao;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

@end

@implementation SHChooseFileViewController

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
            [self prepareDirectories:nil];
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self.refreshControl removeTarget:self action:@selector(prepareDirectories:) forControlEvents:UIControlEventValueChanged];

    [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) context:NULL];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];

    if (self.progressView) {
        self.progressView = nil;
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

        _fetchedResultsController = [self.hierarchicalModelDao createHierarchicalModelsFetchedResultsControllerForUserComputer:userComputerId parent:self.parentPath directoryOnly:YES delegate:self];
    }

    return _fetchedResultsController;
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

- (void)pressCellAtIndexPath:(NSIndexPath *)indexPath {
    if (self.triggeredViewController && indexPath) {
        if ([self.triggeredViewController isKindOfClass:[ShareViewController class]]) {
            ShareViewController *shareViewController = (ShareViewController *) self.triggeredViewController;

            HierarchicalModelWithoutManaged *selectedHierarchicalModel = [self.hierarchicalModelDao fetchedResultsController:self.fetchedResultsController objectAtIndexPath:indexPath];

            if (selectedHierarchicalModel) {
                NSString *directory = [DirectoryService serverPathFromParent:selectedHierarchicalModel.realParent name:selectedHierarchicalModel.realName];

                shareViewController.directory = directory;
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.navigationController popToViewController:shareViewController animated:YES];
            });
        }
    }
}

- (void)prepareDirectories:(id)sender {
    /* keep the current parent path,
     * in case the value changed when getting data back and
     * try to synchronized with the existing ones.
     */
    NSString *targetParentPath = [NSString stringWithString:self.parentPath];

    /* fetch from server, save to DB, then retrieve from DB */
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self internalPrepareDirectoriesWithTargetParentPath:targetParentPath tryAgainIfFailed:YES];
    });
}

- (void)internalPrepareDirectoriesWithTargetParentPath:(NSString *)targetParentPath tryAgainIfFailed:(BOOL)tryAgainIfFailed {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    NSString *userComputerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

    NSString *tempLugServerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID];

    if (sessionId == nil || sessionId.length < 1) {
        [Utility alertInExtensionEmptyUserSessionFromViewController:self completion:^{
            self.processing = @NO;
        }];
//        [Utility alertInExtensionUserNeverConnectedWithViewController:self loginSuccessHandler:^(NSURLResponse *response, NSData *data) {
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
                    [self.hierarchicalModelDao parseJsonAndSyncWithCurrentHierarchicalModels:data userComputer:userComputerId parentPath:targetParentPath completionHandler:^{
                    }];
                } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
                    self.processing = @YES;

                    [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                        if ([userDefaults objectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID]) {
                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                [self internalPrepareDirectoriesWithTargetParentPath:targetParentPath tryAgainIfFailed:NO];
                            });
                        } else {
                            [self requestConnectWithAuthService:self.authService userDefaults:userDefaults targetParentPath:targetParentPath];
                        }
                    } failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
                        self.processing = @NO;

                        NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                        [self alertToTryAgainWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror targetParentPath:targetParentPath];
                    }];
//                    [ShareUtility authService:self.authService reloginCurrentUserComputerFromViewController:self successHandler:^(NSURLResponse *lresponse, NSData *ldata) {
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
//                        [self alertToTryAgainWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror];
//                    }];
                } else if (tryAgainIfFailed && statusCode == 503) {
                    // server not connected, so request connection
                    [self requestConnectWithAuthService:self.authService userDefaults:userDefaults targetParentPath:targetParentPath];
                } else {
                    self.processing = @NO;

                    NSString *messagePrefix = NSLocalizedString(@"Error on finding directory children.", @"");

                    [self alertToTryAgainWithMessagePrefix:messagePrefix response:response data:data error:error targetParentPath:targetParentPath];
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
            [self internalPrepareDirectoriesWithTargetParentPath:targetParentPath tryAgainIfFailed:NO];
        });
    } failureHandler:^(NSData *rcdata, NSURLResponse *rcresponse, NSError *rcerror) {
        self.processing = @NO;

        [self alertToTryAgainWithMessagePrefix:nil response:rcresponse data:rcdata error:rcerror targetParentPath:targetParentPath];
    }];
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    HierarchicalModelWithoutManaged *selectedModel = [self.hierarchicalModelDao fetchedResultsController:self.fetchedResultsController objectAtIndexPath:indexPath];

    if (selectedModel) {
        if ([selectedModel isDirectory]) {
            SHChooseFileViewController *childViewController = [ShareUtility instantiateViewControllerWithIdentifier:@"SHChooseFile"];

            childViewController.parentPath = [DirectoryService serverPathFromParent:selectedModel.realParent name:selectedModel.realName];

            childViewController.triggeredViewController = self.triggeredViewController;

            [self.navigationController pushViewController:childViewController animated:YES];
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
    return NSLocalizedString(@"Select to browse. Pull to refresh", @"");
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
    static NSString *AddButtonCellIdentifier = @"ChooseFileAddingCell";
    UITableViewCell *cell;

    @try {
        HierarchicalModelWithoutManaged *hierarchicalModel = [self.hierarchicalModelDao fetchedResultsController:self.fetchedResultsController objectAtIndexPath:indexPath];

        if (hierarchicalModel && [hierarchicalModel isDirectory]) {
            cell = [tableView dequeueReusableCellWithIdentifier:AddButtonCellIdentifier forIndexPath:indexPath];

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

- (void)alertToTryAgainWithMessagePrefix:messagePrefix response:response data:data error:error targetParentPath:targetParentPath {
    UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self internalPrepareDirectoriesWithTargetParentPath:targetParentPath tryAgainIfFailed:YES];
        });
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self internalPrepareDirectoriesWithTargetParentPath:targetParentPath tryAgainIfFailed:NO];
        });
    }];
}

@end
