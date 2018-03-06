#import "AppService.h"
#import "UserProfileViewController.h"

@interface AppService()

@property(nonatomic, strong) UserDao *userDao;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) UserComputerService *userComputerService;

@property(nonatomic, strong) UserComputerDao *userComputerDao;

@property(nonatomic, strong) HierarchicalModelDao *hierarchicalModelDao;
    
@end

@implementation AppService

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

- (HierarchicalModelDao *)hierarchicalModelDao {
    if (!_hierarchicalModelDao) {
        _hierarchicalModelDao = [[HierarchicalModelDao alloc] init];
    }

    return _hierarchicalModelDao;
}

- (void)showToastAlertWithTableView:(UITableView *)tableView message:(NSString *)message completionHandler:(void (^ _Nullable)(void))completionHandler {
    UIView *toastParentView;
    
    NSIndexPath *selectedIndexPath = [tableView indexPathForSelectedRow];
    
    if (selectedIndexPath) {
        toastParentView = [tableView cellForRowAtIndexPath:selectedIndexPath];
    }
    
    if (!toastParentView) {
        toastParentView = tableView;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [toastParentView addSubview:[[ToastAlert alloc] initWithText:message fontSize:20 delay:0.6 duration:1.5 alignment:ToastAlertLocationAlignmentCenterMiddle completionHandler:^(){
            if (completionHandler) {
                completionHandler();
            }
        }]];
    });
}

- (void)showUserProfileViewControllerFromViewController:(UIViewController *)fromViewController showCancelButton:(NSNumber *)showCancelButton {
    UserProfileViewController *userProfileViewController = [Utility instantiateViewControllerWithIdentifier:@"UserProfile"];

    userProfileViewController.showCancelButton = showCancelButton;

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    userProfileViewController.email = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_EMAIL];
    userProfileViewController.nickname = [userDefaults objectForKey:USER_DEFAULTS_KEY_NICKNAME];

    UINavigationController *userProfileNavigationController = [[UINavigationController alloc] initWithRootViewController:userProfileViewController];

    dispatch_async(dispatch_get_main_queue(), ^{
        [fromViewController presentViewController:userProfileNavigationController animated:YES completion:nil];
    });
}

- (void)removeZeroPrefixPhoneNumberForAllUsers {
    NSError *error;
    NSArray<UserWithoutManaged *> *userWithoutManageds = [self.userDao findAllUsersWithSortByActive:NO error:&error];

    for (UserWithoutManaged *userWithoutManaged in userWithoutManageds) {
        NSString *phoneNumber = userWithoutManaged.phoneNumber;

        if ([phoneNumber hasPrefix:@"0"]) {
            NSString *phoneNumberWithoutZeroPrefix = [phoneNumber substringFromIndex:1];

            userWithoutManaged.phoneNumber = phoneNumberWithoutZeroPrefix;

            [self.userDao updateUserFromUserWithoutManaged:userWithoutManaged completionHandler:nil];
        }
    }
}

- (void)viewController:(UIViewController *)viewController findAvailableComputersWithTryAgainOnInvalidSession:(BOOL)tryAgainOnInvalidSession onSuccessHandler:(nullable void(^)(NSArray<UserComputerWithoutManaged *> *availableUserComputers))handler {
    id <ProcessableViewController> processableViewController;

    if ([viewController conformsToProtocol:@protocol(ProcessableViewController)]) {
        processableViewController = (id <ProcessableViewController>) viewController;
    }

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    // prepare indicator view
    if (processableViewController) {
        processableViewController.processing = @YES;
    }

    [self.userComputerService findAvailableComputersWithSession:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

        if (statusCode == 200) {
            if (processableViewController) {
                processableViewController.processing = @NO;
            }

            NSError *fetchError;
            NSArray *availableUserComputers = [self.userComputerDao userComputersFromFindAvailableComputersResponseData:data error:&fetchError];

            if (fetchError) {
                NSLog(@"Error on finding available computers\n%@", [fetchError userInfo]);

                NSString *message = NSLocalizedString(@"Error on fetching computer information. Try again later.", @"");

                [Utility viewController:viewController alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
            } else {
                if (handler) {
                    handler(availableUserComputers);
                }
            }
        } else if (tryAgainOnInvalidSession && (statusCode == 401 || (error && [error code] == NSURLErrorUserCancelledAuthentication))) {
            // invalid session id - re-login to get the new session id

            [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                [self viewController:viewController findAvailableComputersWithTryAgainOnInvalidSession:NO onSuccessHandler:handler];
            } failureHandler:^(NSData *loginData, NSURLResponse *loginResponse, NSError *loginError) {
                if (processableViewController) {
                    processableViewController.processing = @NO;
                }

                NSString *message = NSLocalizedString(@"Error on finding connected computers", @"");

                [Utility viewController:viewController alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
            }];
        } else {
            if (processableViewController) {
                processableViewController.processing = @NO;
            }

            NSString *errorMessage = [Utility messageWithMessagePrefix:NSLocalizedString(@"Error on finding connected computers", @"") error:error data:data];

            [Utility viewController:viewController alertWithMessageTitle:@"" messageBody:errorMessage actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
        }
    }];
}
@end
