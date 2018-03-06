#import "DocumentPickerViewController.h"
#import "DPRootDirectoryViewController.h"
#import "FilelugDocProviderUtility.h"
#import "DPChooseDownloadedFileViewController.h"

#define kDPSectionIndexOfAvailableComputers     0
#define kDPSectionIndexOfOthers                 1

@interface DocumentPickerViewController ()

// Elements of UserComputerWithoutManaged
@property(nonatomic, strong) NSArray *availableUserComputers;

@property(nonatomic, strong) UserDao *userDao;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) UserComputerService *userComputerService;

@property(nonatomic, strong) UserComputerDao *userComputerDao;

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

@end

@implementation DocumentPickerViewController

@synthesize processing;

@synthesize progressView;

// The method invoked before [self prepareForPresentationInMode:]
- (void)viewDidLoad {
    [super viewDidLoad];

    self.processing = @NO;

    [Utility viewController:self useNavigationLargeTitles:YES];

    _tableView.delegate = self;
    _tableView.dataSource = self;

    _preferredContentSizeCategoryService = [[PreferredContentSizeCategoryService alloc] init];

    // For import, NSFileProviderExtension will not be called and there will be nil for self.documentStorageURL

    // DEBUG:
//    NSFileManager *fileManager = [NSFileManager defaultManager];
//
//    if (![fileManager fileExistsAtPath:[self.documentStorageURL path]]) {
//        NSError *error;
//        BOOL documentStorageURLCreated = [fileManager createDirectoryAtURL:[self documentStorageURL] withIntermediateDirectories:YES attributes:nil error:&error];
//
//        if (!documentStorageURLCreated) {
//            NSLog(@"Failed to create documentStorageURL\n%@", [error userInfo]);
//        }
//    }

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // adding observers

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangePreferredContentSize:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];

    [self addObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) context:NULL];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];
}

- (BOOL)isLoading {
    return (self.processing && [self.processing boolValue]);
}

- (void)stopLoading {
    self.processing = @NO;
}

#pragma mark - providerIdentifier

- (NSString *)providerIdentifier {
    return APP_GROUP_NAME;
}

#pragma mark - documentStorageURL

// This method returns <container URL>/File Provider Storage.
// Where container URL is the value returned by the containerURLForSecurityApplicationGroupIdentifier: method.
- (NSURL *)documentStorageURL {
    return [DirectoryService documentStorageURLForDocumentProvider];
}


- (UserDao *)userDao {
    if (!_userDao) {
        _userDao = [[UserDao alloc] init];
    }

    return _userDao;
}

- (AuthService *)authService {
    if (!_authService) {
        _authService = [[AuthService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];
    }

    return _authService;
}

- (UserComputerService *)userComputerService {
    if (!_userComputerService) {
        _userComputerService = [[UserComputerService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];
    }

    return _userComputerService;
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
                        MBProgressHUD *progressHUD = [Utility prepareProgressViewWithSuperview:self.view inTabWithTabName:nil refreshControl:nil];

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

-(void)prepareForPresentationInMode:(UIDocumentPickerMode)mode {
    // DEBUG
    NSString *modeString;

    switch (mode) {
        case UIDocumentPickerModeImport:
            modeString = @"Import";
            break;
        case UIDocumentPickerModeOpen:
            modeString = @"Open";
            break;
        case UIDocumentPickerModeExportToService:
            modeString = @"Export";
            break;
        case UIDocumentPickerModeMoveToService:
            modeString = @"Move";
            break;
        default:
            modeString = @"Unknown";
    }

    NSLog(@"Presentation in mode: %@", modeString);

    if (mode == UIDocumentPickerModeImport || mode == UIDocumentPickerModeOpen) {
        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSString *userId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_ID];

        if (!userId) {
            // prompt to connect first

            [Utility alertInExtensionEmptyUserSessionFromViewController:self completion:^{
                [self dismissGrantingAccessToURL:nil];
            }];
        } else {
            // show available computers

            [self findAvailableComputers];
        }
    }
}

- (void)presentRootDirectoryViewController {
    DPRootDirectoryViewController *rootDirectoryViewController = [FilelugDocProviderUtility instantiateViewControllerWithIdentifier:@"DPRootDirectory"];

    rootDirectoryViewController.documentPickerExtensionViewController = self;

    UINavigationController *filelugNavigationController = [[UINavigationController alloc] initWithRootViewController:rootDirectoryViewController];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:filelugNavigationController animated:NO completion:nil];
    });
}

- (void)findAvailableComputers {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSString *sessionId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

        if (!sessionId || sessionId.length < 1) {
            self.processing = @NO;

            [Utility alertInExtensionEmptyUserSessionFromViewController:self completion:^{
                [self dismissGrantingAccessToURL:nil];
            }];
        } else {
            /* prepare indicator view */
            self.processing = @YES;

            [self.userComputerService findAvailableComputersWithSession:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                self.processing = @NO;

                NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

                if (statusCode == 200) {
                    /* DO NOT create or update user first FOR NOW */

                    NSError *fetchError;
                    NSArray *availableUserComputers = [self.userComputerDao userComputersFromFindAvailableComputersResponseData:data error:&fetchError];

                    if (fetchError) {
//                        NSLog(@"Error on finding user computers for country: %@, phone number: %@\n%@", countryId, phoneNumber, [fetchError userInfo]);

                        [Utility viewController:self alertWithMessageTitle:@"" messageBody:NSLocalizedString(@"Error on fetching computer information. Try again later.", @"") actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0.0 actionHandler:nil];
                    } else {
                        if (availableUserComputers
                                && [availableUserComputers count] > 0
                                && ((UserComputerWithoutManaged *) availableUserComputers[0]).computerId) {
                            self.availableUserComputers = availableUserComputers;

                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self.tableView reloadData];
                            });
                        } else {
                            self.availableUserComputers = [NSArray array];

                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self.tableView reloadData];
                            });

                            [Utility alertInExtensionEmptyUserSessionFromViewController:self completion:^{
                                // dismiss

                                [self dismissGrantingAccessToURL:nil];
                            }];
                        }
                    }
                } else {
                    UIAlertAction *tryUpdateAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
                        [self findAvailableComputers];
                    }];

                    [self.authService processCommonRequestFailuresWithMessagePrefix:nil response:response data:data error:error tryAgainAction:tryUpdateAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                        [self findAvailableComputers];
                    }];
                }
            }];
        }
    });
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger section = indexPath.section;

    if (section == kDPSectionIndexOfAvailableComputers) {
        [self presentRootDirectoryViewController];
    } else if (section == kDPSectionIndexOfOthers) {
        DPChooseDownloadedFileViewController *chooseDownloadedFileViewController = [FilelugDocProviderUtility instantiateViewControllerWithIdentifier:@"DPChooseDownloadedFile"];

        chooseDownloadedFileViewController.documentPickerExtensionViewController = self;

        UINavigationController *filelugNavigationController = [[UINavigationController alloc] initWithRootViewController:chooseDownloadedFileViewController];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentViewController:filelugNavigationController animated:NO completion:nil];
        });
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *title;

    if (section == kDPSectionIndexOfAvailableComputers) {
        title = NSLocalizedString(@"Choose Computer Name", "");
    } else if (section == kDPSectionIndexOfOthers) {
        title = NSLocalizedString(@"Others", @"");
    }

    return title;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger numberOfRows;

    if (section == kDPSectionIndexOfAvailableComputers) {
        numberOfRows = self.availableUserComputers ? [self.availableUserComputers count] : 0;
    } else if (section == kDPSectionIndexOfOthers) {
        numberOfRows = 1;
    } else {
        numberOfRows = 0;
    }

    return numberOfRows;
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
    static NSString *CellIdentifier = @"DPBasicCell";

    UITableViewCell *cell;

    cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];

    // configure the preferred font

    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    cell.textLabel.textColor = [UIColor darkTextColor];
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.adjustsFontSizeToFitWidth = NO;
    cell.textLabel.lineBreakMode = NSLineBreakByCharWrapping;
    cell.textLabel.textAlignment = NSTextAlignmentNatural;

    NSInteger section = indexPath.section;

    if (section == kDPSectionIndexOfAvailableComputers) {
        if (self.availableUserComputers && [self.availableUserComputers count] > 0) {
            UserComputerWithoutManaged *userComputerWithoutManaged = self.availableUserComputers[(NSUInteger) indexPath.row];

            if (userComputerWithoutManaged) {
                [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];

                cell.textLabel.text = userComputerWithoutManaged.computerName;
                cell.imageView.image = [UIImage imageNamed:@"computer"];
            }
        }
    } else if (section == kDPSectionIndexOfOthers) {
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        
        cell.imageView.image = [UIImage imageNamed:@"folder"];

        cell.textLabel.text = NSLocalizedString(@"Downloaded Files", @"");
    }

    return cell;
}

// request connect for file upload
- (void)requestConnectWithAuthService:(AuthService *)authService userDefaults:(NSUserDefaults *)userDefaults {
    self.processing = @YES;

    [authService requestConnectWithSession:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] successHandler:^(NSURLResponse *rcresponse, NSData *rcdata) {
        self.processing = @NO;

        [self presentRootDirectoryViewController];
    } failureHandler:^(NSData *rcdata, NSURLResponse *rcresponse, NSError *rcerror) {
        self.processing = @NO;

        [self alertToTryAgainWithResponse:rcresponse data:rcdata error:rcerror];
    }];
}

- (void)alertToTryAgainWithResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error {
    NSString *message = [AuthService prepareFailedLoginMessageWithResponse:response error:error data:data];

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:message preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        [self findAvailableComputers];
    }];
    [alertController addAction:tryAgainAction];

    UIAlertAction *tryLaterAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Later", @"") style:UIAlertActionStyleCancel handler:^(UIAlertAction *alertAction) {
        [self dismissGrantingAccessToURL:nil];
    }];
    [alertController addAction:tryLaterAction];

    if ([self isVisible]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [alertController presentWithViewController:self sourceView:nil sourceRect:CGRectNull barButtonItem:nil animated:YES completion:nil];
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [alertController presentWithAnimated:YES];
        });
    }
}

@end
