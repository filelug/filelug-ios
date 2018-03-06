#import "ChangeEmailViewController.h"
#import "FilelugUtility.h"

#define kTagOfChangeToEmailTextField        1   // set in storyboard
#define kTagOfEnterSecurityCodeTextField    2   // set in the code when UIAlertController appears to let user enter security code
#define kTagOfSendSecurityCodeButton        3   // set in storyboard

@interface ChangeEmailViewController ()

@property(nonatomic, strong) NSNumber *disabledChangedToEmail;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

@end

@implementation ChangeEmailViewController
    
@synthesize processing;
    
@synthesize progressView;

- (void)viewDidLoad {
    [super viewDidLoad];

    _disabledChangedToEmail = @NO;

    self.processing = @NO;

    [Utility viewController:self useNavigationLargeTitles:YES];

    _preferredContentSizeCategoryService = [[PreferredContentSizeCategoryService alloc] init];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // adding observers

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangePreferredContentSize:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];

    [self addObserver:self forKeyPath:NSStringFromSelector(@selector(disabledChangedToEmail)) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];

    [self addObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    self.disabledChangedToEmail = @NO;

    [self refreshViewData];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) context:NULL];

    [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(disabledChangedToEmail)) context:NULL];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];

    if (self.progressView) {
        self.progressView = nil;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
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

- (void)refreshViewData {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *currentEmail = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_EMAIL];

    if (!self.email || [self.email stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length < 1) {
        if (currentEmail) {
            self.email = currentEmail;
        } else {
            self.email = NSLocalizedString(@"(Not Set)", @"");
        }
    }

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

                        MBProgressHUD *progressHUD = [Utility prepareProgressViewWithSuperview:self.view inTabWithTabName:selectedTabName refreshControl:nil];

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
    } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(disabledChangedToEmail))]) {
        NSNumber *newValue = change[NSKeyValueChangeNewKey];
        NSNumber *oldValue = change[NSKeyValueChangeOldKey];

        if (![newValue isEqualToNumber:oldValue]) {
            // Enabled/Disabled user interaction of changeToPhoneNumberTextField

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
        }
    }
}

- (void)sendSecurityCode:(id)sender {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self endEditingEmailTextField];

        if (!self.email || [self.email stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length < 1) {
            self.disabledChangedToEmail = @NO;

            NSString *message = NSLocalizedString(@"Email address can not be empty", @"");

            [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
        } else if (![Utility isEmailFormat:self.email]) {
            self.disabledChangedToEmail = @NO;

            NSString *message = [NSString stringWithFormat:NSLocalizedString(@"%@ is not a valid email address.", @""), self.email];

            [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
        } else {
            NSUserDefaults *userDefaults = [Utility groupUserDefaults];

            NSString *currentEmail = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_EMAIL];

            NSNumber *emailVerified = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_EMAIL_IS_VERIFIED];

            if (currentEmail && [[self.email lowercaseString] isEqualToString:[currentEmail lowercaseString]] && emailVerified && [emailVerified boolValue]) {
                self.disabledChangedToEmail = @NO;

                [self refreshViewData];

                NSString *message = NSLocalizedString(@"The email is verified.", @"");

                [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
            } else {
                NSString *newEmail = self.email;

                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

                    if (sessionId == nil || sessionId.length < 1) {
                        [FilelugUtility alertEmptyUserSessionFromViewController:self];
                    } else {
                        [self internalSendSecurityCodeWithSession:sessionId newEmail:newEmail tryAgainIfFailed:YES];
                    }
                });
            }
        }
    });
}

- (void)internalSendSecurityCodeWithSession:(NSString *)sessionId newEmail:(NSString *)newEmail tryAgainIfFailed:(BOOL)tryAgainIfFailed {
    self.processing = @YES;

    self.disabledChangedToEmail = @YES;

    [self.authService sendChangeEmailCodeWithSession:sessionId newEmail:newEmail completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        self.disabledChangedToEmail = @NO;
        
        NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];
        
        if (statusCode == 200) {
            self.processing = @NO;

            // if contains nickname in preferences, set USER_DEFAULTS_KEY_NEED_CREATE_OR_UPDATE_USER_PROFILE to @NO,
            // even if the email is still not verified,
            // so the next time app starts up, it won't show up UserProfileViewController

            NSUserDefaults *userDefaults = [Utility groupUserDefaults];

            if ([userDefaults objectForKey:USER_DEFAULTS_KEY_NICKNAME]) {
                [userDefaults setObject:@NO forKey:USER_DEFAULTS_KEY_NEED_CREATE_OR_UPDATE_USER_PROFILE];
            }

            // prompt to enter security code
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self promptToEnterSecurityCodeWithNewEmail:newEmail];
            });
        } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
            [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

                    [self internalSendSecurityCodeWithSession:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] newEmail:newEmail tryAgainIfFailed:NO];
                });

                // when sending security code, we do not care if desktop connected. So we don't care if value of lug-server-id exits.
            } failureHandler:^(NSData *loginData, NSURLResponse *loginResponse, NSError *loginError) {
                self.processing = @NO;

                NSInteger loginStatusCode = [(NSHTTPURLResponse *) loginResponse statusCode];
                NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Login failed. %@ Status:%d", @""), [loginError localizedDescription], loginStatusCode];

                NSLog(@"%@", message);
                [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
            }];
        } else if (statusCode == 409) {
            self.processing = @NO;

            // email is verified successfully (maybe already verified in another device with the same email)
            // change the email (with lower case) to the preferences and set the USER_DEFAULTS_KEY_USER_EMAIL_IS_VERIFIED to @YES
            // and then reload the table

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSUserDefaults *userDefaults = [Utility groupUserDefaults];

                [userDefaults setObject:[newEmail lowercaseString] forKey:USER_DEFAULTS_KEY_USER_EMAIL];
                [userDefaults setObject:@YES forKey:USER_DEFAULTS_KEY_USER_EMAIL_IS_VERIFIED];

                NSString *message = NSLocalizedString(@"The email is verified and applied.", @"");
                [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:^(UIAlertAction *action) {
                    [self refreshViewData];
                }];
            });
        } else {
            self.processing = @NO;

            UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

                    [self internalSendSecurityCodeWithSession:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] newEmail:newEmail tryAgainIfFailed:YES];
                });
            }];

            NSString *messagePrefix = NSLocalizedString(@"Failed to send security code.", @"");

            [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

                    [self internalSendSecurityCodeWithSession:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] newEmail:newEmail tryAgainIfFailed:NO];
                });
            }];
        }
    }];
}

- (void)promptToEnterSecurityCodeWithNewEmail:(NSString *)newEmail {
    NSString *messageTitle = NSLocalizedString(@"Enter Security Code", @"");

    NSString *buttonTitle = NSLocalizedString(@"Verify", @"");

    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Enter email security code", @""), newEmail, buttonTitle];

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:messageTitle message:message preferredStyle:UIAlertControllerStyleAlert];

    [alertController addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [textField setKeyboardType:UIKeyboardTypeNumberPad];
            [textField setTag:kTagOfEnterSecurityCodeTextField];
            [textField setDelegate:self];
        });
    }];

    UIAlertAction *okAction = [UIAlertAction actionWithTitle:buttonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *_Nonnull action) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UITextField *textField = alertController.textFields[0];

            if (textField) {
                [textField endEditing:YES];

                NSString *securityCode = [[textField text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

                // change email with security code

                [self changeEmailWithNewEmail:newEmail securityCode:securityCode];
            }
        });
    }];

    [alertController addAction:okAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        self.processing = @NO;
        self.disabledChangedToEmail = @NO;

        [self refreshViewData];
    }];

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
}

- (void)endEditingEmailTextField {
    UITableViewCell *emailCell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1]];

    UITextField *emailTextField = [emailCell viewWithTag:kTagOfChangeToEmailTextField];

    if (emailTextField) {
        [emailTextField endEditing:YES];
    }

}

- (void)changeEmailWithNewEmail:(NSString *)newEmail securityCode:(NSString *)securityCode {
    if (!newEmail || newEmail.length < 1) {
        NSString *message = NSLocalizedString(@"Email address can not be empty", @"");

        [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
    } else if (![Utility isEmailFormat:newEmail]) {
        NSString *message = [NSString stringWithFormat:NSLocalizedString(@"%@ is not a valid email address.", @""), newEmail];

        [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
    } else if (!securityCode || [securityCode stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length < 1) {
        NSString *message = NSLocalizedString(@"Security code can not be empty", @"");

        [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
    } else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSUserDefaults *userDefaults = [Utility groupUserDefaults];

            NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

            if (sessionId == nil || sessionId.length < 1) {
                [FilelugUtility alertEmptyUserSessionFromViewController:self];
            } else {
                [self internalChangeEmailWithSession:sessionId newEmail:newEmail securityCode:securityCode tryAgainIfFailed:YES];
            }
        });
    }
}

- (void)internalChangeEmailWithSession:(NSString *)sessionId newEmail:(NSString *)newEmail securityCode:(NSString *)securityCode tryAgainIfFailed:(BOOL)tryAgainIfFailed {
    self.processing = @YES;
    
    NSString *encryptedSecurityCode = [Utility encryptSecurityCode:securityCode];

    [self.authService changeEmailWithSession:sessionId newEmail:newEmail encryptedSecurityCode:encryptedSecurityCode completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];
        
        if (statusCode == 200) {
            self.processing = @NO;

            // update user data and user defaults for email
            
            NSUserDefaults *userDefaults = [Utility groupUserDefaults];

            [userDefaults setObject:newEmail forKey:USER_DEFAULTS_KEY_USER_EMAIL];
            [userDefaults setObject:@YES forKey:USER_DEFAULTS_KEY_USER_EMAIL_IS_VERIFIED];

            NSString *userId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_ID];
            
            UserDao *userDao = [[UserDao alloc] init];
            
            [userDao updateEmailTo:newEmail forUserId:userId];

            [self refreshViewData];
            
            NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Successfully change email to %@", @""), newEmail];
            
            [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:^(UIAlertAction * _Nonnull action) {
                if (self.navigationController) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.navigationController popViewControllerAnimated:YES];
                    });
                }
            }];
        } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
            [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

                    [self internalChangeEmailWithSession:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] newEmail:newEmail securityCode:securityCode tryAgainIfFailed:NO];
                });

                // when changing email, we do not care if desktop connected. So we don't care if value of lug-server-id exits.
            } failureHandler:^(NSData *loginData, NSURLResponse *loginResponse, NSError *loginError) {
                self.processing = @NO;

                [self refreshViewData];

                NSInteger loginStatusCode = [(NSHTTPURLResponse *) loginResponse statusCode];
                NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Login failed. %@ Status:%d", @""), [loginError localizedDescription], loginStatusCode];

                NSLog(@"%@", message);
                [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
            }];
        } else if (statusCode == 431) {
            self.processing = @NO;

            // incorrect security code, re-enter again

            NSString *message = NSLocalizedString(@"Incorrect security code and try again", @"");

            [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"Try Again", @"") containsCancelAction:YES delayInSeconds:0 actionHandler:^(UIAlertAction *action) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self promptToEnterSecurityCodeWithNewEmail:newEmail];
                });
            }];
        } else {
            self.processing = @NO;

            [self refreshViewData];

            UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

                    [self internalChangeEmailWithSession:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] newEmail:newEmail securityCode:securityCode tryAgainIfFailed:YES];
                });
            }];

            NSString *messagePrefix = NSLocalizedString(@"Failed to change email.", @"");

            [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

                    [self internalChangeEmailWithSession:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] newEmail:newEmail securityCode:securityCode tryAgainIfFailed:NO];
                });
            }];
        }
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section > 0) {
        return 1;
    } else {
        return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *title;

    switch (section) {
        case 1:
            title = NSLocalizedString(@"Email Address", @"");

            break;
        default:
            title = @"";
    }

    return title;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    NSString *title;

    switch (section) {
        case 0:
            title = NSLocalizedString(@"Change email description", @"");

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
    static NSString *sendSecurityCodeCellIdentifier = @"SendSecurityCodeCell";

    UITableViewCell *cell;

    NSInteger section = indexPath.section;

    if (section == 1) {
        // email

        cell = [tableView dequeueReusableCellWithIdentifier:emailCellIdentifier forIndexPath:indexPath];

        [cell setAccessoryType:UITableViewCellAccessoryNone];

        // configure the preferred font
        UITextField *emailTextField = [cell viewWithTag:kTagOfChangeToEmailTextField];

        emailTextField.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        emailTextField.textColor = [UIColor darkTextColor];
        emailTextField.textAlignment = NSTextAlignmentNatural;

        emailTextField.placeholder = NSLocalizedString(@"Enter email address here", @"");
        emailTextField.text = self.email;

        emailTextField.enabled = !(self.disabledChangedToEmail && [self.disabledChangedToEmail boolValue]);

        emailTextField.delegate = self;
    } else if (section == 2) {
        // send security code

        cell = [tableView dequeueReusableCellWithIdentifier:sendSecurityCodeCellIdentifier forIndexPath:indexPath];

        [cell setAccessoryType:UITableViewCellAccessoryNone];

        // configure the preferred font

        UIButton *sendSecurityCodeButton = [cell viewWithTag:kTagOfSendSecurityCodeButton];

        sendSecurityCodeButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        sendSecurityCodeButton.titleLabel.adjustsFontSizeToFitWidth = YES;
        sendSecurityCodeButton.titleLabel.minimumScaleFactor = 0.5;
        sendSecurityCodeButton.titleLabel.textAlignment = NSTextAlignmentNatural;

        // state: Normal
        [sendSecurityCodeButton setTitleColor:[UIColor aquaColor] forState:UIControlStateNormal];
        [sendSecurityCodeButton setTitle:NSLocalizedString(@"Send me security code", @"") forState:UIControlStateNormal];

        // state: Disabled
        [sendSecurityCodeButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
        [sendSecurityCodeButton setTitle:NSLocalizedString(@"The email is verified.", @"") forState:UIControlStateDisabled];

        [sendSecurityCodeButton addTarget:self action:@selector(sendSecurityCode:) forControlEvents:UIControlEventTouchUpInside];

        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSNumber *ifEmailVerified = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_EMAIL_IS_VERIFIED];

        NSString *emailInPreference = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_EMAIL];

        BOOL buttonShouldDisabled = self.email && emailInPreference && [[self.email lowercaseString] isEqualToString:[emailInPreference lowercaseString]] && ifEmailVerified && [ifEmailVerified boolValue];

        [sendSecurityCodeButton setEnabled:!buttonShouldDisabled];
    }

    return cell;
}

- (UIButton *)sendSecurityCodeButtonInTableView:(UITableView *)tableView {
    UIButton *sendSecurityCodeButton;

    if (tableView) {
        UITableViewCell *sendSecurityCodeButtonCell = [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:2]];

        if (sendSecurityCodeButtonCell) {
            sendSecurityCodeButton = [sendSecurityCodeButtonCell viewWithTag:kTagOfSendSecurityCodeButton];
        }
    }

    return sendSecurityCodeButton;
}


#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    if (textField.tag == kTagOfChangeToEmailTextField) {
        // unlock send security code button, if any

        UIButton *sendSecurityCodeButton = [self sendSecurityCodeButtonInTableView:self.tableView];

        if (sendSecurityCodeButton) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [sendSecurityCodeButton setEnabled:YES];
            });
        }
    } else if (textField.tag == kTagOfEnterSecurityCodeTextField) {
        // clear security code

        dispatch_async(dispatch_get_main_queue(), ^{
            textField.text = @"";
        });
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    NSInteger tag = textField.tag;

    if (tag == kTagOfChangeToEmailTextField) { // change to email
        self.email = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    } else if (tag == kTagOfEnterSecurityCodeTextField) { // enter security code
        NSString *trimmedSecurityCode = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        dispatch_async(dispatch_get_main_queue(), ^{
            textField.text = trimmedSecurityCode;
        });
    }
}

@end
