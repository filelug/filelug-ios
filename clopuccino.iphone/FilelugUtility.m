#import "FilelugUtility.h"
#import "TutorialViewController.h"
#import "SettingsViewController.h"
#import "AppDelegate.h"
#import "FilePreviewControllerDelegate.h"
#import "MenuTabBarController.h"
#import "ManageComputerViewController.h"
#import "FilelugFileDownloadService.h"

@implementation FilelugUtility

//// The method will executed in main queue with 1.0 second of delay,
//// to prevent method viewDidLoad not finished,
//// if the method is invoked directly/indirectly in method viewDidLoad
//+ (void)showConnectionViewControllerFromParent:(UIViewController *)fromViewController {
//    /* show Connection scene */
//    /* alert with delay of 1 sec to prevent method viewDidLoad not finished */
//
//    if (fromViewController) {
//        ConnectionViewController *connectionViewController = [Utility instantiateViewControllerWithIdentifier:@"Connection"];
//
//        NSUserDefaults *userDefaults = [Utility groupUserDefaults];
//
//        connectionViewController.phoneNumber = [userDefaults stringForKey:USER_DEFAULTS_KEY_PHONE_NUMBER];
//        connectionViewController.encryptedPassword = [userDefaults stringForKey:USER_DEFAULTS_KEY_PASSWORD];
//        connectionViewController.showHidden = [userDefaults objectForKey:USER_DEFAULTS_KEY_SHOW_HIDDEN];
//
//        NSString *countryId = [userDefaults stringForKey:USER_DEFAULTS_KEY_COUNTRY_ID];
//        CountryDao *countryDao = [[CountryDao alloc] init];
//        connectionViewController.countryWithoutManaged = [countryDao findCountryByCountryId:countryId error:NULL];
//
//        connectionViewController.fromViewController = fromViewController;
//
//        double delayInSeconds = 1.0;
//        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));
//
//        if (fromViewController.navigationController) {
//            dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
//                [fromViewController.navigationController pushViewController:connectionViewController animated:YES];
//            });
//        } else {
//            UINavigationController *connectionNavigation = [[UINavigationController alloc] initWithRootViewController:fromViewController];
//
//            dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
//                [connectionNavigation pushViewController:connectionViewController animated:YES];
//            });
//        }
//    }
//}

//+ (void)showChangePhoneNumberViewControllerFromParent:(UIViewController *)fromViewController delayedInSeconds:(double)seconds {
//    /* show ChangePhoneNumber scene */
//
//    UserDao *userDao = [[UserDao alloc] init];
//
//    NSError *foundError;
//    NSArray *usersWithoutManaged = [userDao findAllUsersWithSortByActive:YES error:&foundError];
//
//    if (!usersWithoutManaged || [usersWithoutManaged count] < 1) {
//        [Utility viewController:fromViewController alertWithMessageTitle:@"" messageBody:NSLocalizedString(@"Never connected successfully", @"") actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
//    } else {
//        /* alert with delay of 1 sec to prevent method viewDidLoad not finished */
//
//        double delayInSeconds;
//
//        if (seconds < 0) {
//            delayInSeconds = 0;
//        } else {
//            delayInSeconds = seconds;
//        }
//
//        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));
//        dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
//            if (fromViewController && fromViewController.navigationController) {
//                ChangePhoneNumberViewController *changePhoneNumberViewController = [Utility instantiateViewControllerWithIdentifier:@"ChangePhoneNumber"];
//
//                changePhoneNumberViewController.userWithoutManaged = usersWithoutManaged[0];
//
//                [fromViewController.navigationController pushViewController:changePhoneNumberViewController animated:YES];
//            }
//        });
//    }
//}

+ (AppDelegate *)applicationDelegate {
    AppDelegate *delegate = (AppDelegate *) [[UIApplication sharedApplication] delegate];
    
    return delegate;
}

+ (void)registerNotificationForWithApplication:(UIApplication *)application fromViewController:(UIViewController *_Nullable)fromViewController {
    if ([Utility isDeviceVersion10OrLater]){
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];

        // Alert user before system message prompt to ask for notification

        [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *notificationSettings) {
            UNAuthorizationStatus authorizationStatus = notificationSettings.authorizationStatus;

            if (authorizationStatus == UNAuthorizationStatusNotDetermined) {
                NSString *messageTitle = NSLocalizedString(@"Allow Notifications", @"");
                NSString *messageBody = NSLocalizedString(@"Turn on Notifications", @"");

                [Utility viewController:fromViewController alertWithMessageTitle:messageTitle messageBody:messageBody actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0.0 actionHandler:^(UIAlertAction *action) {
                    // You may use the shared user notification center object from any thread of your app.
                    // However, you should use this object from only one thread at a time.
                    // Do not try to use it from multiple threads simultaneously.
                    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge) completionHandler:^(BOOL granted, NSError * _Nullable error) {
                        [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
                            NSLog(@"Notification settings:\n%@", settings);
                        }];

                        // prompt only when first time user choose not to receive remote and local notifications.
                        // If fromViewController is nil, it may be invoked by AppDelegate and should not promot user.
                        if(!error && !granted && fromViewController) {
                            // Notifiy user to setup notification later, only once
                            static dispatch_once_t notificationPermissionOnceToken;
                            dispatch_once(&notificationPermissionOnceToken, ^{
                                NSString *message = NSLocalizedString(@"Want to allow notification later", @"");

                                [Utility viewController:fromViewController alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                            });
                        }
                    }];
                }];

            }
        }];
    } else {
        // category NOTIFICATION_CATEGORY_FILE_UPLOAD

        UIMutableUserNotificationCategory *categoryUpload = [[UIMutableUserNotificationCategory alloc] init];
        categoryUpload.identifier = NOTIFICATION_CATEGORY_FILE_UPLOAD;

        UIMutableUserNotificationAction *actionUploadView = [[UIMutableUserNotificationAction alloc] init];
        actionUploadView.identifier = NOTIFICATION_ACTION_UPLOAD_VIEW;
        actionUploadView.title = NSLocalizedString(@"View", @"");
        actionUploadView.activationMode = UIUserNotificationActivationModeForeground;
        actionUploadView.destructive = NO;
        actionUploadView.authenticationRequired = YES;

        [categoryUpload setActions:@[actionUploadView] forContext:UIUserNotificationActionContextDefault];
        [categoryUpload setActions:@[actionUploadView] forContext:UIUserNotificationActionContextMinimal];

        // category NOTIFICATION_CATEGORY_APPLY_ACCEPTED

        UIMutableUserNotificationCategory *categoryApplyAccepted = [[UIMutableUserNotificationCategory alloc] init];
        categoryApplyAccepted.identifier = NOTIFICATION_CATEGORY_APPLY_ACCEPTED;

        UIMutableUserNotificationAction *actionConnect = [[UIMutableUserNotificationAction alloc] init];
        actionConnect.identifier = NOTIFICATION_ACTION_APPLIED_ACCEPTED_CONNECT;
        actionConnect.title = NSLocalizedString(@"CONNECT", @"");
        actionConnect.activationMode = UIUserNotificationActivationModeForeground;
        actionConnect.destructive = NO;
        actionConnect.authenticationRequired = YES;

        [categoryApplyAccepted setActions:@[actionConnect] forContext:UIUserNotificationActionContextDefault];
        [categoryApplyAccepted setActions:@[actionConnect] forContext:UIUserNotificationActionContextMinimal];

        // category NOTIFICATION_CATEGORY_APPLY_TO_ADMIN

        UIMutableUserNotificationCategory *categoryApplyToAdmin = [[UIMutableUserNotificationCategory alloc] init];
        categoryApplyToAdmin.identifier = NOTIFICATION_CATEGORY_APPLY_TO_ADMIN;

        UIMutableUserNotificationAction *actionAdminAccept = [[UIMutableUserNotificationAction alloc] init];
        actionAdminAccept.identifier = NOTIFICATION_ACTION_ADMIN_ACCEPT;
        actionAdminAccept.title = NSLocalizedString(@"Accept", @"");
        actionAdminAccept.activationMode = UIUserNotificationActivationModeForeground;
        actionAdminAccept.destructive = NO;
        actionAdminAccept.authenticationRequired = YES;

        UIMutableUserNotificationAction *actionAdminView = [[UIMutableUserNotificationAction alloc] init];
        actionAdminView.identifier = NOTIFICATION_ACTION_ADMIN_VIEW_DETAIL;
        actionAdminView.title = NSLocalizedString(@"View", @"");
        actionAdminView.activationMode = UIUserNotificationActivationModeForeground;
        actionAdminView.destructive = NO;
        actionAdminView.authenticationRequired = YES;

        [categoryApplyToAdmin setActions:@[actionAdminAccept, actionAdminView] forContext:UIUserNotificationActionContextDefault];
        [categoryApplyToAdmin setActions:@[actionAdminAccept, actionAdminView] forContext:UIUserNotificationActionContextMinimal];

        // set types for categories

        UIUserNotificationType types = UIUserNotificationTypeBadge | UIUserNotificationTypeAlert | UIUserNotificationTypeSound;

        NSSet *categories = [NSSet setWithObjects:categoryUpload, categoryApplyAccepted, categoryApplyToAdmin, nil];

        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:types categories:categories];

        dispatch_async(dispatch_get_main_queue(), ^{
            [application registerUserNotificationSettings:settings];
        });
    }
}

// The first time your app launches and calls this method,
// the system asks the user whether your app should be allowed to deliver notifications before it ask permission to Apple.
//+ (void)registerNotificationForWithApplication:(UIApplication *)application {
//    if ([Utility isDeviceVersion10OrLater]){
//        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
//
//        [center requestAuthorizationWithOptions:(UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionBadge) completionHandler:^(BOOL granted, NSError * _Nullable error) {
//            if(!error) {
//                // Set flag that "the user" allow this device to receive local and remote notifications.
//                // Set value of USER_DEFAULTS_KEY_ALLOW_RECEIVE_NOTIFICATION based on the value of granted.
//
//                NSUserDefaults *userDefaults = [Utility groupUserDefaults];
//
//                // Get current value
//                NSNumber *oldAllowReceiveNotification = [userDefaults valueForKey:USER_DEFAULTS_KEY_ALLOW_RECEIVE_NOTIFICATION];
//
//                [userDefaults setObject:@(granted) forKey:USER_DEFAULTS_KEY_ALLOW_RECEIVE_NOTIFICATION];
//
//                NSLog(@"The user %@ this device to receive local and remote notification.", granted ? @"allows" : @"rejects");
//
//                // prompt only when first time user choose not to receive remote and local notifications.
//
//                if (!oldAllowReceiveNotification && !granted) {
//                    // Notifiy user to setup notification later
//
//                    NSString *message = NSLocalizedString(@"Want to allow notification later", @"");
//
//                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:message preferredStyle:UIAlertControllerStyleAlert];
//
//                    dispatch_async(dispatch_get_main_queue(), ^{
//                        [alertController presentWithAnimated:YES];
//                    });
//                }
//            }
//        }];
//    } else {
//        // category NOTIFICATION_CATEGORY_FILE_UPLOAD
//
//        UIMutableUserNotificationCategory *categoryUpload = [[UIMutableUserNotificationCategory alloc] init];
//        categoryUpload.identifier = NOTIFICATION_CATEGORY_FILE_UPLOAD;
//
//        UIMutableUserNotificationAction *actionUploadView = [[UIMutableUserNotificationAction alloc] init];
//        actionUploadView.identifier = NOTIFICATION_ACTION_UPLOAD_VIEW;
//        actionUploadView.title = NSLocalizedString(@"View", @"");
//        actionUploadView.activationMode = UIUserNotificationActivationModeForeground;
//        actionUploadView.destructive = NO;
//        actionUploadView.authenticationRequired = YES;
//
//        [categoryUpload setActions:@[actionUploadView] forContext:UIUserNotificationActionContextDefault];
//        [categoryUpload setActions:@[actionUploadView] forContext:UIUserNotificationActionContextMinimal];
//
//        // category NOTIFICATION_CATEGORY_APPLY_ACCEPTED
//
//        UIMutableUserNotificationCategory *categoryApplyAccepted = [[UIMutableUserNotificationCategory alloc] init];
//        categoryApplyAccepted.identifier = NOTIFICATION_CATEGORY_APPLY_ACCEPTED;
//
//        UIMutableUserNotificationAction *actionConnect = [[UIMutableUserNotificationAction alloc] init];
//        actionConnect.identifier = NOTIFICATION_ACTION_APPLIED_ACCEPTED_CONNECT;
//        actionConnect.title = NSLocalizedString(@"CONNECT", @"");
//        actionConnect.activationMode = UIUserNotificationActivationModeForeground;
//        actionConnect.destructive = NO;
//        actionConnect.authenticationRequired = YES;
//
//        [categoryApplyAccepted setActions:@[actionConnect] forContext:UIUserNotificationActionContextDefault];
//        [categoryApplyAccepted setActions:@[actionConnect] forContext:UIUserNotificationActionContextMinimal];
//
//        // category NOTIFICATION_CATEGORY_APPLY_TO_ADMIN
//
//        UIMutableUserNotificationCategory *categoryApplyToAdmin = [[UIMutableUserNotificationCategory alloc] init];
//        categoryApplyToAdmin.identifier = NOTIFICATION_CATEGORY_APPLY_TO_ADMIN;
//
//        UIMutableUserNotificationAction *actionAdminAccept = [[UIMutableUserNotificationAction alloc] init];
//        actionAdminAccept.identifier = NOTIFICATION_ACTION_ADMIN_ACCEPT;
//        actionAdminAccept.title = NSLocalizedString(@"Accept", @"");
//        actionAdminAccept.activationMode = UIUserNotificationActivationModeForeground;
//        actionAdminAccept.destructive = NO;
//        actionAdminAccept.authenticationRequired = YES;
//
//        UIMutableUserNotificationAction *actionAdminView = [[UIMutableUserNotificationAction alloc] init];
//        actionAdminView.identifier = NOTIFICATION_ACTION_ADMIN_VIEW_DETAIL;
//        actionAdminView.title = NSLocalizedString(@"View", @"");
//        actionAdminView.activationMode = UIUserNotificationActivationModeForeground;
//        actionAdminView.destructive = NO;
//        actionAdminView.authenticationRequired = YES;
//
//        [categoryApplyToAdmin setActions:@[actionAdminAccept, actionAdminView] forContext:UIUserNotificationActionContextDefault];
//        [categoryApplyToAdmin setActions:@[actionAdminAccept, actionAdminView] forContext:UIUserNotificationActionContextMinimal];
//
//        // set types for categories
//
//        UIUserNotificationType types = UIUserNotificationTypeBadge | UIUserNotificationTypeAlert | UIUserNotificationTypeSound;
//
//        NSSet *categories = [NSSet setWithObjects:categoryUpload, categoryApplyAccepted, categoryApplyToAdmin, nil];
//
//        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:types categories:categories];
//
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [application registerUserNotificationSettings:settings];
//        });
//    }
//}
//
//+ (NSString *)generateNotificationIdWithUserInfo:(NSDictionary *)userInfo {
//    NSString *notificationId;
//
//    NSString *downloadGroupId = userInfo[NOTIFICATION_MESSAGE_KEY_DOWNLOAD_GROUP_ID];
//
//    if (downloadGroupId) {
//        notificationId = [downloadGroupId copy];
//    } else {
//        NSString *transferKey = userInfo[NOTIFICATION_MESSAGE_KEY_TRANSFER_KEY];
//
//        if (transferKey) {
//            notificationId = [transferKey copy];
//        } else {
//            notificationId = [Utility uuid];
//
//            NSLog(@"Use UUID as the notification id because neither of download group id nor transfer key found.");
//        }
//    }
//
//    return notificationId;
//}

//+ (void)sendImmediateLocalNotificationWithMessage:(NSString *)message title:(NSString *)title userInfo:(NSDictionary *)userInfo {
//    if ([Utility isDeviceVersion10OrLater]) {
//        UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
//
//        content.title = title;
//        content.body = message;
//        content.userInfo = userInfo;
//        content.sound = [UNNotificationSound defaultSound];
//
//        // FIXME: Do not increase badge number until we know exactly how to make it right.
//
//        UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:NOTIFICATION_TRIGGER_TIME_INTERVAL repeats:NO];
//
//        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[self generateNotificationIdWithUserInfo:userInfo] content:content trigger:trigger];
//
//        [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:nil];
//    } else {
//        UIApplication *application = [UIApplication sharedApplication];
//
//        // FIXME: Do not increase badge number until we know exactly how to make it right.
//
////    if (application.applicationState != UIApplicationStateActive) {
////        [Utility incrementCachedNotificationBadgeNumber];
////    } else {
////        // DEBUG
////        NSLog(@"Application is active and cached local notification badge number not incremented.");
////    }
//
//        UILocalNotification *localNotification = [[UILocalNotification alloc] init];
//
//        localNotification.fireDate = [[NSDate date] dateByAddingTimeInterval:1.0];
//
//        // a proxy that will always act as if it is the current default time zone for the application, even if that default changes.
//        localNotification.timeZone = [NSTimeZone localTimeZone];
//
//        localNotification.alertBody = message;
//
//        localNotification.soundName = UILocalNotificationDefaultSoundName;
//
//        // FIXME: always set to 0 until we know exactly how to make it right.
//        localNotification.applicationIconBadgeNumber = 0;
////    if (application.applicationState != UIApplicationStateActive) {
////        localNotification.applicationIconBadgeNumber = [[Utility currentCachedLocalNotificationBadgeNumber] integerValue];
////    } else {
////        // DEBUG
////        NSLog(@"Application is active and local notification badge number will set to 0");
////
////        localNotification.applicationIconBadgeNumber = 0;
////    }
//
//        // this works because we renumbered badge number for pending notifications.
//        //    NSUInteger nextBadgeNumber = [[[UIApplication sharedApplication] scheduledLocalNotifications] count] + 1;
//        //    localNotification.applicationIconBadgeNumber = nextBadgeNumber;
//
//        localNotification.userInfo = userInfo;
//
//        if ([localNotification respondsToSelector:@selector(setAlertTitle:)]) {
//            localNotification.alertTitle = title;
//        }
//
//        [application scheduleLocalNotification:localNotification];
//    }
//}

//+ (void)alertUserNeverConnectedWithViewController:(UIViewController *_Nonnull)viewController loginSuccessHandler:(void (^ __nonnull)(NSURLResponse *, NSData *))loginSuccessHandler {
//    id <ProcessableViewController> processableViewController;
//
//    if ([viewController conformsToProtocol:@protocol(ProcessableViewController)]) {
//        processableViewController = (id <ProcessableViewController>) viewController;
//    }
//
//    [Utility alertUserNeverConnectedFromViewController:viewController connectNowHandler:^(UIAlertAction *connectNowAction) {
//        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//            [Utility loginCurrentUserComputerFromFindingAvailableComputers:NO
//                                                          inViewController:viewController
//                                                   noCurrentAccountHandler:^{
//                if (processableViewController) {
//                    processableViewController.processing = @NO;
//                }
//
//                // Go to ConnectionViewController
//
//                if ([viewController isVisible]) {
//                    [FilelugUtility showConnectionViewControllerFromParent:viewController];
//                }
//            } noAvailableComputerFoundHandler:^{
//                if (processableViewController) {
//                    processableViewController.processing = @NO;
//                }
//
//                if ([viewController isVisible]) {
//                    [FilelugUtility alertNoComputerEverConnectedWithViewController:viewController delayInSeconds:1.0 completionHandler:nil];
//                }
//            } loginSuccessHandler:^(NSURLResponse *response, NSData *data) {
//                loginSuccessHandler(response, data);
//            } loginFailureHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
//                if (processableViewController) {
//                    processableViewController.processing = @NO;
//                }
//
//                [Utility promptLoginFailureWithResponse:response responseData:data responseError:error inViewController:viewController];
//            }];
//        });
//    } connectLaterHandler:^(UIAlertAction *connectLaterAction) {
//        if (processableViewController) {
//            processableViewController.processing = @NO;
//        }
//    }];
//}

+ (void)alertEmptyUserSessionFromViewController:(UIViewController *_Nonnull)viewController {
    if ([viewController conformsToProtocol:@protocol(ProcessableViewController)]) {
        ((id <ProcessableViewController>) viewController).processing = @NO;
    }

    [Utility alertEmptyUserSessionFromViewController:viewController connectNowHandler:^(UIAlertAction *connectNowAction) {
        // Go to SettingsViewController and invoke 'Login with another account'

        MenuTabBarController *menuTabBarController = [[FilelugUtility applicationDelegate] menuTabBarController];

        [menuTabBarController setReloadSettingsTab:YES];
        dispatch_async(dispatch_get_main_queue(), ^{
            [menuTabBarController setSelectedIndex:INDEX_OF_TAB_BAR_SETTINGS];

            UINavigationController *settingsNavigationController = [menuTabBarController navigationControllerAtTabBarIndex:INDEX_OF_TAB_BAR_SETTINGS];

            if (settingsNavigationController) {
                [settingsNavigationController popToRootViewControllerAnimated:YES];

                SettingsViewController *settingViewController = menuTabBarController.settingsViewController;

                [settingViewController selectLoginWithAnotherAccountAndInvokeDelegateMethod];
            }

//            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                SettingsViewController *settingViewController = menuTabBarController.settingsViewController;
//
//                [settingViewController selectLoginWithAnotherAccountAndInvokeDelegateMethod];
//            });
        });
    } connectLaterHandler:nil];
}

+ (NSInteger)detechNetworkStatus {
    Reachability *reachability = [Reachability reachabilityForInternetConnection];
    [reachability startNotifier];
    
    return [reachability currentReachabilityStatus];
}

+ (void)requestNetworkActivityIndicatorVisible:(BOOL)setVisible {
    static NSInteger visibleRequestCount = 0;
    
    if (setVisible) {
        visibleRequestCount++;
    } else {
        visibleRequestCount--;
    }
    
    // The assertion helps to find programmer errors in activity indicator management.
    // Since a negative visibleRequestCount is not a fatal error,
    // it should probably be removed from production code.
//    NSAssert(visibleRequestCount >= 0, @"Network Activity Indicator was asked to hide more often than shown");
    
    // Display the indicator as long as our static counter is > 0.
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:(visibleRequestCount > 0)];
}

+ (void)prepareInitialPreferencesRelatedToMainAppWithUserDefaults:(NSUserDefaults *)userDefaults {
    NSBundle *mainBundle = [NSBundle mainBundle];
    
    // application version
    NSString *appVersion = [mainBundle infoDictionary][@"CFBundleShortVersionString"];
    
    [userDefaults setObject:appVersion forKey:USER_DEFAULTS_KEY_MAIN_APP_VERSION];
    
    // application build no
    NSString *appBuildNo = [mainBundle infoDictionary][(NSString *) kCFBundleVersionKey];
    
    [userDefaults setObject:appBuildNo forKey:USER_DEFAULTS_KEY_MAIN_APP_BUILD_NO];
    
    // application locale
    NSString *appLocale = [mainBundle preferredLocalizations][0];
    
    [userDefaults setObject:appLocale forKey:USER_DEFAULTS_KEY_MAIN_APP_LOCALE];

    // application content size category
    NSString *preferredContentSizeCategory = [[UIApplication sharedApplication] preferredContentSizeCategory];

    if (preferredContentSizeCategory) {
        [userDefaults setObject:preferredContentSizeCategory forKey:USER_DEFAULTS_KEY_PREFERRED_CONTENT_SIZE_CATEGORY];
    }
}

// use [self.applicationDelegate topViewController] to present alert controller
+ (void)alertNoComputerEverConnectedWithViewController:(UIViewController *_Nonnull)viewController delayInSeconds:(double)seconds completionHandler:(nullable void(^)(void))handler {
    // alert no computer connected to this account

    NSString *message;

    if ([viewController isKindOfClass:[ManageComputerViewController class]]) {
        message = [NSString stringWithFormat:NSLocalizedString(@"Install and setup Filelug on desktop or laptop2", @""), NSLocalizedString(@"Current Computer", @"")];
    } else {
        message = [NSString stringWithFormat:NSLocalizedString(@"Install and setup Filelug on desktop or laptop", @""), NSLocalizedString(@"Settings", @""), NSLocalizedString(@"Current Computer", @"")];
    }

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:message preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"") style:UIAlertActionStyleCancel handler:nil];
    [alertController addAction:okAction];

    UIAlertAction *tutorialAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Step-by-step descriptions", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        TutorialViewController *tutorialViewController = [Utility instantiateViewControllerWithIdentifier:@"Tutorial"];

        // start from page 2
        [tutorialViewController setStartViewControllerIndex:@(1)];

        dispatch_async(dispatch_get_main_queue(), ^{
            [viewController presentViewController:tutorialViewController animated:YES completion:nil];
        });
    }];
    [alertController addAction:tutorialAction];

    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (seconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
        [alertController presentWithAnimated:YES completion:handler];
    });
}

+ (void)promptToAllowUsePhotosWithViewController:(UIViewController *)viewController {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *userComputerId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

    if (userComputerId) {
        static dispatch_once_t photoPermissionOnceToken;
        dispatch_once(&photoPermissionOnceToken, ^{
            PHAuthorizationStatus authorizationStatus = [PHPhotoLibrary authorizationStatus];

            if (authorizationStatus != PHAuthorizationStatusAuthorized) {
                // This method always returns immediately. If the user has previously granted or denied photo library access permission,
                // it executes the handler block when called; otherwise, it displays an alert and executes the block only after the user has responded to the alert.

                [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                    if (status == PHAuthorizationStatusDenied) {
                        NSString *message = NSLocalizedString(@"Want to allow access photos later", @"");

                        [Utility viewController:viewController alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                    }
                }];
            }
        });
    }
}

+ (void)promptToAllowNotificationWithViewController:(UIViewController *_Nullable)viewController {
    // Ask user to allow local and remote notification only at least one computer ever connected.

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *userComputerId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

    if (userComputerId) {
        [FilelugUtility registerNotificationForWithApplication:[UIApplication sharedApplication] fromViewController:viewController];
    }
}
//+ (void)promptToAllowNotificationWithViewController:(UIViewController *) viewController {
//    NSUserDefaults *userDefaults = [Utility groupUserDefaults];
//
//    NSString *userComputerId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];
//
//    NSNumber *allowReceivingNotification = [userDefaults objectForKey:USER_DEFAULTS_KEY_ALLOW_RECEIVE_NOTIFICATION];
//
//    if (userComputerId && (!allowReceivingNotification || ![allowReceivingNotification boolValue])) {
//        static dispatch_once_t notificationPermissionOnceToken;
//        dispatch_once(&notificationPermissionOnceToken, ^{
//            // register notification with types, including local and remote notifications
//            [FilelugUtility registerNotificationForWithApplication:[UIApplication sharedApplication]];
//        });
//    }
//}

+ (NSString *)selectedTabName {
    // Get the current tab name from MenuTabViewController
    NSString *selectedTabName = [[self applicationDelegate].menuTabBarController selectedTabName];

    return selectedTabName;
}

@end
