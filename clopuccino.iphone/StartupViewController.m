#import "StartupViewController.h"
#import "TutorialViewController.h"
#import "AccountKitService.h"
#import "AccountKitServiceDelegate.h"
#import "AppService.h"

// -------------- section 0 -----------------
#define kStartupSectionIndexOfDescription       0

#define kStartupRowIndexOfDescription           0

// -------------- section 1 -----------------
#define kStartupSectionIndexOfLogin             1

#define kStartupRowIndexOfLogin                 0

// -------------- section 2 -----------------
#define kStartupSectionIndexOfTutorial          2

#define kStartupRowIndexOfTutorial              0

// -------------- section 3 -----------------
#define kStartupSectionIndexOfDemo              3

#define kStartupRowIndexOfDemo                  0

@interface StartupViewController () <AccountKitServiceDelegate>

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

@property(nonatomic, strong) UserDao *userDao;

@property(nonatomic, strong) AccountKitService *accountKitService;

//@property(nonatomic, strong) UIViewController<AKFViewController> *pendingLoginViewController;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) AppService *appService;

@property(nonatomic, assign) NSInteger lastSectionIndex;

@end

@implementation StartupViewController

@synthesize processing;

@synthesize progressView;

- (void)viewDidLoad {
    [super viewDidLoad];

    self.processing = @NO;

    _preferredContentSizeCategoryService = [[PreferredContentSizeCategoryService alloc] init];

    if (!_accountKitService) {
        _accountKitService = [[AccountKitService alloc] initWithServiceDelegate:self];
    }

//    _pendingLoginViewController = [_accountKitService viewControllerForLoginResume];

    if ([Utility shouldHideLoginToDemoAccount]) {
        _lastSectionIndex = kStartupSectionIndexOfTutorial;
    } else {
        _lastSectionIndex = kStartupSectionIndexOfDemo;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangePreferredContentSize:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];

    [self addObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (![Utility needShowStartupViewController]) {
        // It helps StartupViewController to dismiss itself when it comes back from UserProfileViewController.
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dismissViewControllerAnimated:YES completion:^{
                self.accountKitService = nil;
//                self.pendingLoginViewController = nil;
            }];
        });
    } else {
        NSIndexPath *lastSectionIndexPath = [NSIndexPath indexPathForRow:0 inSection:self.lastSectionIndex];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView scrollToRowAtIndexPath:lastSectionIndexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
        });
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) context:NULL];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];

    if (self.progressView) {
        self.progressView = nil;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
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

- (BOOL)isLoading {
    return (self.processing && [self.processing boolValue]);
}

- (void)stopLoading {
    self.processing = @NO;
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
                }
            });
        }
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.lastSectionIndex + 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 0 ? 100 : 60;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat height;

    if (indexPath.section == 0) {
        if ([self.preferredContentSizeCategoryService isLargeContentSizeCategory]) {
            height = 100;
        } else {
            height = 80;
        }
    } else {
        height = 60;
    }

    return height;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *descriptionCellIdentifier = @"DescriptionCell";
    static NSString *loginCellIdentifier = @"LoginCell";
    static NSString *tutorialCellIdentifier = @"TutorialCell";
    static NSString *demoCellIdentifier = @"DemoCell";

    NSInteger section = indexPath.section;

    UITableViewCell *cell;

    if (section == kStartupSectionIndexOfDescription) {
        // description label

        cell = [Utility tableView:tableView createOrDequeueCellWithStyle:UITableViewCellStyleDefault reuseIdentifier:descriptionCellIdentifier forIndexPath:indexPath];

        cell.imageView.image = nil;
        cell.accessoryType = UITableViewCellAccessoryNone;

        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        cell.textLabel.textColor = [UIColor lightGrayColor];
        cell.textLabel.numberOfLines = 4;
        cell.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        cell.textLabel.adjustsFontSizeToFitWidth = YES;
        cell.textLabel.minimumScaleFactor = 0.5;

        cell.textLabel.text = NSLocalizedString(@"Filelug is a rapid and secure system to transfer files between devices and computers.", @"");
    } else if (section ==  kStartupSectionIndexOfLogin) {
        // User Login

        cell = [Utility tableView:tableView createOrDequeueCellWithStyle:UITableViewCellStyleDefault reuseIdentifier:loginCellIdentifier forIndexPath:indexPath];

        cell.imageView.image = [UIImage imageNamed:@"add-new-account"];
        cell.accessoryType = UITableViewCellAccessoryNone;

        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        cell.textLabel.textColor = [UIColor darkTextColor];
        cell.textLabel.numberOfLines = 2;
        cell.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        cell.textLabel.adjustsFontSizeToFitWidth = YES;
        cell.textLabel.minimumScaleFactor = 0.5;

        cell.textLabel.text = NSLocalizedString(@"Login Account", @"");
    } else if (section == kStartupSectionIndexOfTutorial) {
        // Tutorial

        cell = [Utility tableView:tableView createOrDequeueCellWithStyle:UITableViewCellStyleDefault reuseIdentifier:tutorialCellIdentifier forIndexPath:indexPath];

        cell.imageView.image = [UIImage imageNamed:@"book-flip"];
        cell.accessoryType = UITableViewCellAccessoryNone;

        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        cell.textLabel.textColor = [UIColor darkTextColor];
        cell.textLabel.numberOfLines = 2;
        cell.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        cell.textLabel.adjustsFontSizeToFitWidth = YES;
        cell.textLabel.minimumScaleFactor = 0.5;

        cell.textLabel.text = NSLocalizedString(@"Getting Started with Filelug", @"");
    } else if (section == kStartupSectionIndexOfDemo) {
        // Login to Demo Account

        cell = [Utility tableView:tableView createOrDequeueCellWithStyle:UITableViewCellStyleDefault reuseIdentifier:demoCellIdentifier forIndexPath:indexPath];

        cell.imageView.image = [UIImage imageNamed:@"demo-computer"];
        cell.accessoryType = UITableViewCellAccessoryNone;

        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        cell.textLabel.textColor = [UIColor darkTextColor];
        cell.textLabel.numberOfLines = 2;
        cell.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        cell.textLabel.adjustsFontSizeToFitWidth = YES;
        cell.textLabel.minimumScaleFactor = 0.5;

        cell.textLabel.text = NSLocalizedString(@"Connect to the demonstration computer", @"");

        // TODO: Hide it after May 21, 2017
    }

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;

    if (section == kStartupSectionIndexOfLogin && row == kStartupRowIndexOfLogin) {
        // Login with Facebook Account Kit

        NSString *inputState = [[NSUUID UUID] UUIDString];

        [self.accountKitService startCurrentUserLoginProcessWithState:inputState];
    } else if (section == kStartupSectionIndexOfTutorial && row == kStartupRowIndexOfTutorial) {
        TutorialViewController *tutorialViewController = [Utility instantiateViewControllerWithIdentifier:@"Tutorial"];

        // start from page 2
        [tutorialViewController setStartViewControllerIndex:@(0)];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentViewController:tutorialViewController animated:YES completion:nil];
        });
    } else if (section == kStartupSectionIndexOfDemo && row == kStartupRowIndexOfDemo) {
        // warn user before connect to demo computer:
        // The files on this demo computer could be downloaded by anyone. Please do not upload piracy-sensitive files
        // or upload files that contains inappropriate content.

        NSString *warnMessage = NSLocalizedString(@"Demo computer upload rule.", @"");
        NSString *connectToComputer = NSLocalizedString(@"Connect Now", @"");
        NSString *doNotConnectToComputer = NSLocalizedString(@"Cancel", @"");

        [Utility viewController:self alertWithMessageTitle:@"" messageBody:warnMessage actionTitle:connectToComputer containsCancelAction:YES cancelTitle:doNotConnectToComputer delayInSeconds:0 actionHandler:^(UIAlertAction *action) {
            // Add or update demo account to local db

            self.processing = @YES;

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self.authService createOrUpdateDemoAccountWithSuccessHandler:^(NSURLResponse *response, NSData *data) {
                    self.processing = @NO;

                    // dismiss to show Menu
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self dismissViewControllerAnimated:YES completion:nil];
                    });
                } failureHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                    self.processing = @NO;

                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        NSString *message = [AuthService prepareFailedLoginMessageWithResponse:response error:error data:data];

                        [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                    });
                }];
            });
        } cancelHandler:^(UIAlertAction *action) {
            // deselect row
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
        }];
    }
}

#pragma mark - AccountKitServiceDelegate

- (void)accountKitService:(AccountKitService *)accountKitService didSuccessfullyGetCountryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber authorizationCode:(NSString *)authorizationCode state:(NSString *)state {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.authService loginWithAuthorizationCode:authorizationCode successHandler:^(NSURLResponse *response, NSData *data) {
            NSUserDefaults *userDefaults = [Utility groupUserDefaults];

            NSNumber *needCreateOrUpdateUserProfile = [userDefaults objectForKey:USER_DEFAULTS_KEY_NEED_CREATE_OR_UPDATE_USER_PROFILE];

            if (needCreateOrUpdateUserProfile && [needCreateOrUpdateUserProfile boolValue]) {
                [self.appService showUserProfileViewControllerFromViewController:self showCancelButton:@NO];
            } else if (![Utility needShowStartupViewController]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self dismissViewControllerAnimated:YES completion:^{
                        self.accountKitService = nil;
//                        self.pendingLoginViewController = nil;
                    }];
                });
            }
        } failureHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
            NSString *message = [AuthService prepareFailedLoginMessageWithResponse:response error:error data:data];

            [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
        }];
    });
}

- (void)accountKitService:(AccountKitService *)accountKitService didFailedGetCountryIdAndPhoneNumberWithResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error authorizationCode:(NSString *)authorizationCode state:(NSString *)state {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *message = [AuthService prepareFailedLoginMessageWithResponse:response error:error data:data];

        [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
    });
}

- (void)accountKitService:(AccountKitService *)accountKitService didFailWithError:(NSError *)error {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *message;

        if (error) {
            message = [NSString stringWithFormat:@"%@\n%@", NSLocalizedString(@"Login failed. Try later.", @""), [error localizedDescription]];
        } else {
            message = NSLocalizedString(@"Login failed. Try later.", @"");
        }

        [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
    });
}

- (void)accountKitServiceDidCanceled:(AccountKitService *)accountKitService {
    NSLog(@"User canceled login with account kit.");
}

@end
