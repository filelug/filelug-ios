#import "UserProfileViewController.h"
#import "FilelugUtility.h"
#import "AppDelegate.h"

#define kTagOfEmailTextField        1
#define kTagOfNicknameTextField     2

#define kSectionIndexOfCellEmail    1
#define kRowIndexOfCellEmail        0

#define kSectionIndexOfCellNickname 2
#define kRowIndexOfCellNickname     0

@interface UserProfileViewController ()

@property(nonatomic, strong) UIBarButtonItem *updateUserProfileButtonItem;

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) UserComputerService *userComputerService;

@end

@implementation UserProfileViewController

@synthesize processing;

@synthesize progressView;

- (void)viewDidLoad {
    [super viewDidLoad];

    self.processing = @NO;

    [Utility viewController:self useNavigationLargeTitles:YES];

    _preferredContentSizeCategoryService = [[PreferredContentSizeCategoryService alloc] init];

    [self.navigationItem setTitle:NSLocalizedString(@"User Profiles", @"")];

    _updateUserProfileButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Send", @"") style:UIBarButtonItemStyleDone target:self action:@selector(updateUserProfile:)];

    self.navigationItem.rightBarButtonItem = _updateUserProfileButtonItem;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (self.showCancelButton && [self.showCancelButton boolValue]) {
        UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel", @"") style:UIBarButtonItemStyleDone target:self action:@selector(dismiss:)];

        self.navigationItem.leftBarButtonItem = cancelButton;
    } else {
        self.navigationItem.leftBarButtonItem = nil;
    }

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

    if (self.progressView) {
        self.progressView = nil;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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

- (void)dismiss:(id)sender {
    [self dismissSelfWithCompletionHandler:nil];
}

- (void)updateUserProfile:(id)sender {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self endEditingAllTextFields];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if (!self.email || self.email.length < 1) {
                NSString *message = NSLocalizedString(@"Email address can not be empty", @"");

                [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
            } else if (![Utility isEmailFormat:self.email]) {
                NSString *message = [NSString stringWithFormat:NSLocalizedString(@"%@ is not a valid email address.", @""), self.email];

                [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
            } else if (!self.nickname || [self.nickname stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length < 1) {
                NSString *message = NSLocalizedString(@"Invalid nickname", @"");

                [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
            } else {
                self.processing = @YES;

                NSUserDefaults *userDefaults = [Utility groupUserDefaults];

                NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

                if (sessionId == nil || sessionId.length < 1) {
                    [FilelugUtility alertEmptyUserSessionFromViewController:self];
//                    [FilelugUtility alertUserNeverConnectedWithViewController:self loginSuccessHandler:^(NSURLResponse *response, NSData *data) {
//                        self.processing = @NO;
//
//                        [self internalCreateOrUpdateUserProfileWithEmail:self.email nickname:self.nickname session:sessionId tryAgainIfConnectionFailed:YES];
//                    }];
                } else {
                    [self internalCreateOrUpdateUserProfileWithEmail:self.email nickname:self.nickname session:sessionId tryAgainIfFailed:YES];
                }
            }
        });
    });
}

- (void)internalCreateOrUpdateUserProfileWithEmail:(NSString *)email nickname:(NSString *)nickname session:(NSString *)sessionId tryAgainIfFailed:(BOOL)tryAgainIfFailed {
    self.processing = @YES;

    [self.authService createOrUpdateUserProfileWithEmail:self.email nickname:self.nickname session:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

        if (statusCode == 200) {
            self.processing = @NO;

            NSUserDefaults *userDefaults = [Utility groupUserDefaults];

            // update user data and user defaults for email

            [userDefaults setObject:email forKey:USER_DEFAULTS_KEY_USER_EMAIL];

            [userDefaults setObject:nickname forKey:USER_DEFAULTS_KEY_NICKNAME];

            NSString *userId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_ID];

            UserDao *userDao = [[UserDao alloc] init];

            [userDao updateEmail:email nickname:nickname forUserId:userId];

            // So it won't show up again next time StartupViewController finished runing Facebook Account Kit
            [userDefaults setObject:@NO forKey:USER_DEFAULTS_KEY_NEED_CREATE_OR_UPDATE_USER_PROFILE];

            // connect to computer, if any, before dismiss itself

            [self dismissSelfWithCompletionHandler:^{
                [self connectToCurrentComputerWithTryAgainIfFailed:YES];
            }];
        } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
            [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

                    [self internalCreateOrUpdateUserProfileWithEmail:email nickname:nickname session:[userDefaults objectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] tryAgainIfFailed:NO];
                });
            } failureHandler:^(NSData *loginData, NSURLResponse *loginResponse, NSError *loginError) {
                self.processing = @NO;

                NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                [self alertToCreateOrUpdateUserProfileAgainWithMessagePrefix:messagePrefix response:loginResponse data:loginData error:loginError email:email nickname:nickname];
            }];
        } else if (tryAgainIfFailed && (statusCode == 403)) {
            self.processing = @NO;

            // delete the current session id so the Settings > 'Sign In' shows

            NSUserDefaults *userDefaults = [Utility groupUserDefaults];

            [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

            // dismiss to create or update user profile later

            [Utility viewController:self alertWithMessageTitle:@"" messageBody:NSLocalizedString(@"Session not found try later", @"") actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:^(UIAlertAction *action) {
                [self dismissSelfWithCompletionHandler:nil];
            }];
        } else {
            self.processing = @NO;

            NSString *messagePrefix = NSLocalizedString(@"Failed to change user profiles.", @"");

            [self alertToCreateOrUpdateUserProfileAgainWithMessagePrefix:messagePrefix response:response data:data error:error email:email nickname:nickname];
        }
    }];
}

- (void)dismissSelfWithCompletionHandler:(void (^)(void))handler {
    // dismiss itself
    // To show the navigation item title and the 'send' bar button item, it needs a UINavigationController to hold UserProfileViewController as it root view controller,
    // so dismiss this UINavigationController, if any, instead of UserProfileViewController

    if (self.navigationController) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.navigationController dismissViewControllerAnimated:YES completion:^{
                if (handler) {
                    handler();
                }
            }];
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dismissViewControllerAnimated:YES completion:^{
                if (handler) {
                    handler();
                }
            }];
        });
    }
}

- (void)alertToCreateOrUpdateUserProfileAgainWithMessagePrefix:messagePrefix response:response data:data error:error email:(NSString *)email nickname:(NSString *)nickname {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self internalCreateOrUpdateUserProfileWithEmail:email nickname:nickname session:[userDefaults objectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] tryAgainIfFailed:YES];
        });
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self internalCreateOrUpdateUserProfileWithEmail:email nickname:nickname session:[userDefaults objectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] tryAgainIfFailed:NO];
        });
    }];
}

- (void)connectToCurrentComputerWithTryAgainIfFailed:(BOOL)tryAgainIfFailed {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *userId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_ID];

    NSNumber *computerId = [userDefaults objectForKey:USER_DEFAULTS_KEY_COMPUTER_ID];

    NSString *sessionId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    if (userId && computerId && sessionId) {
        NSNumber *showHidden = [userDefaults objectForKey:USER_DEFAULTS_KEY_SHOW_HIDDEN];

        if (!showHidden) {
            showHidden = @NO;
        }

        [self.userComputerService connectToComputerWithUserId:userId computerId:computerId showHidden:showHidden session:sessionId successHandler:^(NSURLResponse *response, NSData *data) {
            self.processing = @NO;

//            // delay to find the correct top view controller
//
//            double delayInSeconds = 1.0;
//            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));
//            dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
//                NSString *computerName = [userDefaults objectForKey:USER_DEFAULTS_KEY_COMPUTER_NAME];
//
//                NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Connected to the computer %@ successfully", @""), computerName];
//
//                UIViewController *topViewController = [[FilelugUtility applicationDelegate] topViewController];
//
//                [Utility viewController:topViewController alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
//            });
        } failureHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

            if (tryAgainIfFailed && (statusCode == 401 || (error && [error code] == NSURLErrorUserCancelledAuthentication))) {
                // invalid session -- re-login to get the new session id

                [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        [self connectToCurrentComputerWithTryAgainIfFailed:NO];
                    });
                } failureHandler:^(NSData *loginData, NSURLResponse *loginResponse, NSError *loginError) {
                    self.processing = @NO;

                    // delay to find the correct top view controller
                    double delayInSeconds = 1.0;
                    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));
                    dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
                        UIViewController *topViewController = [[FilelugUtility applicationDelegate] topViewController];

                        [Utility viewController:topViewController alertWithMessageTitle:@"" messageBody:NSLocalizedString(@"Login failed. Try later.", @"") actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                    });
                }];
            } else if (statusCode == 501 || statusCode == 460) {
                // computer not found -- ask user go to Settings > Connected Computer to connect to another computer

                // delay to find the correct top view controller
                double delayInSeconds = 1.0;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
                    NSString *errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Computer not exits. Go to find other computers", @""), NSLocalizedString(@"Settings", @""), NSLocalizedString(@"Current Computer", @"")];

                    UIViewController *topViewController = [[FilelugUtility applicationDelegate] topViewController];

                    [Utility viewController:topViewController alertWithMessageTitle:@"" messageBody:errorMessage actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                });
            } else {
                // delay to find the correct top view controller
                double delayInSeconds = 1.0;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
                    UIViewController *topViewController = [[FilelugUtility applicationDelegate] topViewController];

                    NSString *computerName = [userDefaults objectForKey:USER_DEFAULTS_KEY_COMPUTER_NAME];

                    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Error on connecting to computer %@", @""), computerName];

                    UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            [self connectToCurrentComputerWithTryAgainIfFailed:YES];
                        });
                    }];

                    [self.authService processCommonRequestFailuresWithMessagePrefix:message response:response data:data error:error tryAgainAction:tryAgainAction inViewController:topViewController reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            [self connectToCurrentComputerWithTryAgainIfFailed:NO];
                        });
                    }];
                });
            }
        }];
    }
}

- (void)endEditingAllTextFields {
    // email cell

    UITableViewCell *emailCell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:kRowIndexOfCellEmail inSection:kSectionIndexOfCellEmail]];

    UITextField *emailTextField = [emailCell viewWithTag:kTagOfEmailTextField];

    if (emailTextField) {
        [emailTextField endEditing:YES];
    }

    // nickname cell

    UITableViewCell *nicknameCell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:kRowIndexOfCellNickname inSection:kSectionIndexOfCellNickname]];

    UITextField *nicknameTextField = [nicknameCell viewWithTag:kTagOfNicknameTextField];

    if (nicknameTextField) {
        [nicknameTextField endEditing:YES];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section > 0 ? 1 : 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *title;

    switch (section) {
        case 0:
            title = (self.email && self.nickname)
                    ? NSLocalizedString(@"Confirm your email and nickname to complete login process", @"")
                    : NSLocalizedString(@"Enter your email and nickname to complete your registration", @"");

            break;
        case kSectionIndexOfCellEmail:
            title = NSLocalizedString(@"Email", @"");

            break;
        case kSectionIndexOfCellNickname:
            title = NSLocalizedString(@"Nickname", @"");

            break;
        default:
            title = @"";
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
    static NSString *emailCellIdentifier = @"EmailCell";
    static NSString *nicknameCellIdentifier = @"NicknameCell";

    UITableViewCell *cell;

    NSInteger section = indexPath.section;

    if (section == kSectionIndexOfCellEmail) {
        // email

        cell = [tableView dequeueReusableCellWithIdentifier:emailCellIdentifier forIndexPath:indexPath];

        [cell setAccessoryType:UITableViewCellAccessoryNone];

        // configure the preferred font

        UITextField *emailTextField = [cell viewWithTag:kTagOfEmailTextField];

        emailTextField.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        emailTextField.textColor = [UIColor darkTextColor];
        emailTextField.textAlignment = NSTextAlignmentNatural;

        emailTextField.placeholder = [NSString stringWithFormat:NSLocalizedString(@"e.g. %@", @""), @"abc@example.com"];
        emailTextField.text = self.email;

        emailTextField.delegate = self;
    } else if (section == kSectionIndexOfCellNickname) {
        // nickname

        cell = [tableView dequeueReusableCellWithIdentifier:nicknameCellIdentifier forIndexPath:indexPath];

        [cell setAccessoryType:UITableViewCellAccessoryNone];

        // configure the preferred font

        UITextField *nicknameTextField = [cell viewWithTag:kTagOfNicknameTextField];

        nicknameTextField.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        nicknameTextField.textColor = [UIColor darkTextColor];
        nicknameTextField.textAlignment = NSTextAlignmentNatural;

        nicknameTextField.placeholder = NSLocalizedString(@"Enter nickname here", @"");
        nicknameTextField.text = self.nickname;

        nicknameTextField.delegate = self;
    }

    return cell;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    NSInteger tag = textField.tag;

    if (tag == kTagOfEmailTextField) {
        UITableViewCell *nicknameCell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:kRowIndexOfCellNickname inSection:kSectionIndexOfCellNickname]];

        UITextField *nicknameTextField = [nicknameCell viewWithTag:kTagOfNicknameTextField];

        [nicknameTextField becomeFirstResponder];
    } else if (tag == kTagOfNicknameTextField) {
        [textField resignFirstResponder];

        self.nickname = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        [self updateUserProfile:nil];
    }

    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    NSInteger tag = textField.tag;

    if (tag == kTagOfEmailTextField) {
        self.email = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    } else if (tag == kTagOfNicknameTextField) {
        self.nickname = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
}

@end
