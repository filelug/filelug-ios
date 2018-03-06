#import "ChangeNicknameViewController.h"
#import "FilelugUtility.h"
#import "AppService.h"

#define kTagOfChangeToNicknameTextField        1

@interface ChangeNicknameViewController ()

@property(nonatomic, strong) UIBarButtonItem *changeNicknameItem;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) AppService *appService;

@end

@implementation ChangeNicknameViewController
    
@synthesize processing;
    
@synthesize progressView;


- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.processing = @NO;

    [Utility viewController:self useNavigationLargeTitles:YES];
    
    // right button items
    _changeNicknameItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Change", @"") style:UIBarButtonItemStyleDone target:self action:@selector(changeNickname:)];
    
    self.navigationItem.rightBarButtonItem = _changeNicknameItem;

    [self prepareCurrentNickname];
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

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];

    [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) context:NULL];
    
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

- (AppService *)appService {
    if (!_appService) {
        _appService = [[AppService alloc] init];
    }
    
    return _appService;
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

- (void)prepareCurrentNickname {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *currentNickname = [userDefaults stringForKey:USER_DEFAULTS_KEY_NICKNAME];

    _currentNickname = currentNickname;
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
    }
}

- (void)endEditingAllTextFields {
    // change to nickname cell

    UITableViewCell *changeToNicknameCell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1]];

    UITextField *changeToNicknameTextField = [changeToNicknameCell viewWithTag:kTagOfChangeToNicknameTextField];

    if (changeToNicknameTextField) {
        [changeToNicknameTextField endEditing:YES];
    }
}

- (void)changeNickname:(id)sender {
    [self endEditingAllTextFields];
    
    NSString *newNickname = self.changeToNickname;
    
    if (!newNickname || [newNickname stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length < 1) {
        NSString *message = NSLocalizedString(@"Invalid nickname", @"");
        
        [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
    } else if ([newNickname isEqualToString:self.currentNickname]) {
        NSString *message = NSLocalizedString(@"Same nickname", @"");
        
        [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
    } else {
        if (![self.processing boolValue]) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                self.processing = @YES;
                
                NSUserDefaults *userDefaults = [Utility groupUserDefaults];

                NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];
                
                if (!sessionId || sessionId.length < 1) {
                    [FilelugUtility alertEmptyUserSessionFromViewController:self];
//                    [FilelugUtility alertUserNeverConnectedWithViewController:self loginSuccessHandler:^(NSURLResponse *response, NSData *data) {
//                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                            self.processing = @NO;
//
//                            [self changeNickname:sender];
//                        });
//                    }];
                } else {
                    [self internalChangeNicknameWithSession:sessionId newNickname:newNickname tryAgainIfFailed:YES];
                }
            });
        }
    }
}

- (void)internalChangeNicknameWithSession:(NSString *)sessionId newNickname:(NSString *)newNickname tryAgainIfFailed:(BOOL)tryAgainIfFailed {
    self.processing = @YES;

    [self.authService changeNickname:newNickname session:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        self.processing = @NO;
        
        NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];
        
        if (statusCode == 200) {
            NSUserDefaults *userDefaults = [Utility groupUserDefaults];

            /* update user in db */
            NSString *userId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_ID];
            
            UserDao *userDao = [[UserDao alloc] init];
            
            [userDao updateNicknameTo:newNickname forUserId:userId];
            
            /* update nickname in user defaults */
            [userDefaults setValue:newNickname forKey:USER_DEFAULTS_KEY_NICKNAME];
            
            /* go back to SettingsViewController */
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.navigationController popViewControllerAnimated:YES];
            });
        } else if (statusCode == 400) {
            // User not exists or nickName not provided
            
            NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            
            NSString *message;
            if (responseString && responseString.length > 0) {
                message = [NSString stringWithFormat:NSLocalizedString(@"Failed to change nickname", @""), responseString];
            } else {
                message = NSLocalizedString(@"Failed to change nickname2", @"");
            }
            
            [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
        } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
            self.processing = @YES;

            [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

                    [self internalChangeNicknameWithSession:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] newNickname:newNickname tryAgainIfFailed:NO];
                });
            } failureHandler:^(NSData *loginData, NSURLResponse *loginResponse, NSError *loginError) {
                self.processing = @NO;

                NSInteger loginStatusCode = [(NSHTTPURLResponse *) loginResponse statusCode];
                NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Login failed. %@ Status:%d", @""), [loginError localizedDescription], loginStatusCode];

                NSLog(@"%@", message);
                [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
            }];
//            [self.authService reloginOnlyWithNewPassword:nil onNoActiveUserHandler:^() {
//                [FilelugUtility showConnectionViewControllerFromParent:self];
//            } successHandler:^(NSURLResponse *lresponse, NSData *ldata) {
//                self.processing = @NO;
//
//                NSUserDefaults *userDefaults = [Utility groupUserDefaults];
//
//                [self internalChangeNicknameWithSession:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] newNickname:newNickname tryAgainIfConnectionFailed:NO];
//
//                // when changing nickname, we do not care if desktop connected. So we don't care if value of lug-server-id exits.
//            } failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
//                self.processing = @NO;
//
//                NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");
//
//                [self alertToTryAgainWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror];
//            }];
        } else {
            // no possible for error 503 because the service do not care about desktop socket connection
            
            self.processing = @NO;

            NSUserDefaults *userDefaults = [Utility groupUserDefaults];

            UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [self internalChangeNicknameWithSession:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] newNickname:newNickname tryAgainIfFailed:YES];
                });
            }];

            NSString *messagePrefix = NSLocalizedString(@"Failed to change nickname2", @"");

            [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [self internalChangeNicknameWithSession:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] newNickname:newNickname tryAgainIfFailed:NO];
                });
            }];
        }
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *title;

    switch (section) {
        case 0:
            title = NSLocalizedString(@"Current Nickname", @"");

            break;
        case 1:
            title = self.currentNickname ? NSLocalizedString(@"Change To", @"") : NSLocalizedString(@"New Nickname", @"");

            break;
        default:
            title = @"";
    }

    return title;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *currentNicknameCellIdentifier = @"CurrentNicknameCell";
    static NSString *changeToNicknameCellIdentifier = @"ChangeToNicknameCell";

    UITableViewCell *cell;

    NSInteger section = indexPath.section;

    if (section == 0) {
        // current nickname

        cell = [tableView dequeueReusableCellWithIdentifier:currentNicknameCellIdentifier forIndexPath:indexPath];

        [cell setAccessoryType:UITableViewCellAccessoryNone];

        // configure the preferred font

        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        cell.textLabel.textColor = [UIColor lightGrayColor];

        cell.textLabel.text = self.currentNickname ? self.currentNickname : NSLocalizedString(@"(Not Set)", @"");
    } else if (section == 1) {
        // change to nickname

        cell = [tableView dequeueReusableCellWithIdentifier:changeToNicknameCellIdentifier forIndexPath:indexPath];

        [cell setAccessoryType:UITableViewCellAccessoryNone];

        // configure the preferred font
        UITextField *changeToNicknameTextField = [cell viewWithTag:kTagOfChangeToNicknameTextField];

        changeToNicknameTextField.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        changeToNicknameTextField.textColor = [UIColor darkTextColor];
        changeToNicknameTextField.textAlignment = NSTextAlignmentLeft;

        changeToNicknameTextField.placeholder = NSLocalizedString(@"Enter new nickname here", @"");
        changeToNicknameTextField.text = self.changeToNickname;

        changeToNicknameTextField.delegate = self;
    }

    return cell;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    self.changeToNickname = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)alertToTryAgainWithMessagePrefix:messagePrefix response:response data:data error:error {
    UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        [self changeNickname:nil];
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        [self changeNickname:nil];
    }];
}

@end
