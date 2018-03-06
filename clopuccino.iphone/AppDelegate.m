#import "AppDelegate.h"
#import "UploadExternalFileViewController.h"
#import "DownloadFileViewController.h"
#import "FileUploadViewController.h"
#import "MenuTabBarController.h"
#import "FilelugUtility.h"
#import "FileUploadProcessService.h"
#import "FileDownloadProcessService.h"
#import "FilelugFileDownloadService.h"
#import "FilelugFileUploadService.h"


@interface AppDelegate ()

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

// Elements of pairs of key(the identifier of the NSURLSession) and value(NSURLSession used for background transfer)
@property(nonatomic, strong) NSMutableDictionary *backgroundSessions;

@property(nonatomic, strong) FileDownloadGroupDao *fileDownloadGroupDao;

@property(nonatomic, strong) UserComputerDao *userComputerDao;

@property(nonatomic, strong) UserComputerService *userComputerService;

@end


@implementation AppDelegate {
}

- (NSMutableDictionary *)backgroundSessions {
    if (!_backgroundSessions) {
        _backgroundSessions = [NSMutableDictionary dictionary];
    }

    return _backgroundSessions;
}

- (AuthService *)authService {
    if (!_authService) {
        _authService = [[AuthService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];
    }
    
    return _authService;
}

- (DirectoryService *)directoryService {
    if (!_directoryService) {
        _directoryService = [[DirectoryService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];
    }
    
    return _directoryService;
}

- (FileUploadProcessService *)fileUploadProcessService {
    if (!_fileUploadProcessService) {
        _fileUploadProcessService = [FileUploadProcessService defaultService];
    }

    return _fileUploadProcessService;
}

- (FileDownloadProcessService *)fileDownloadProcessService {
    if (!_fileDownloadProcessService) {
        _fileDownloadProcessService = [FileDownloadProcessService defaultService];
    }

    return _fileDownloadProcessService;
}


- (AssetFileDao *)assetFileDao {
    if (!_assetFileDao) {
        _assetFileDao = [[AssetFileDao alloc] init];
    }

    return _assetFileDao;
}

- (FileUploadGroupDao *)fileUploadGroupDao {
    if (!_fileUploadGroupDao) {
        _fileUploadGroupDao = [[FileUploadGroupDao alloc] init];
    }

    return _fileUploadGroupDao;
}

- (FileTransferDao *)fileTransferDao {
    if (!_fileTransferDao) {
        _fileTransferDao = [[FileTransferDao alloc] init];
    }

    return _fileTransferDao;
}

- (FileDownloadGroupDao *)fileDownloadGroupDao {
    if (!_fileDownloadGroupDao) {
        _fileDownloadGroupDao = [[FileDownloadGroupDao alloc] init];
    }

    return _fileDownloadGroupDao;
}

- (UserComputerDao *)userComputerDao {
    if (!_userComputerDao) {
        _userComputerDao = [[UserComputerDao alloc] init];
    }

    return _userComputerDao;
}

- (UserComputerService *)userComputerService {
    if (!_userComputerService) {
        _userComputerService = [[UserComputerService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];
    }

    return _userComputerService;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // DEBUG
//    NSLog(@"Invoked [AppDelegate application:didFinishLaunchingWithOptions:] with launch options: %@", launchOptions ? [launchOptions description] : @"No value");

    NSUserDefaults *groupUserDefaults = [Utility groupUserDefaults];

    // Starting with version 2.0.3, AssetFile with source type of ASSET_FILE_SOURCE_TYPE_SHARED_FILE
    // must have value in column downloadedFileTransferKey.
    [Utility deleteAssetFilesWithSharedFileSourceTypeButNoDownloadedTransferKeyWithUserDefaults:groupUserDefaults];

    [FilelugUtility prepareInitialPreferencesRelatedToMainAppWithUserDefaults:groupUserDefaults];
    
    [Utility prepareInitialPreferencesWithUserDefaults:groupUserDefaults];
    
    // load/migrate local db
    ClopuccinoCoreData *coreData = [ClopuccinoCoreData defaultCoreData];

    // Receiving data writing in another managed object context from extensions
    coreData.receivesUpdates = YES;

    // Always assign your delegate object to the shared user notification center's delegate property before using the object.

    if ([Utility isDeviceVersion10OrLater]) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        center.delegate = self;
    }

    [FilelugUtility promptToAllowNotificationWithViewController:nil];

    // Initiate the registration process with Apple Push Notification service, must run under main thread
    // If registration succeeds,
    // the app calls your app delegate's "application:didRegisterForRemoteNotificationsWithDeviceToken:",
    // and you should pass this token along to the server you use to generate remote notifications for the device.
    // If registration fails,
    // the app calls its app delegate’s "application:didFailToRegisterForRemoteNotificationsWithError:".
    dispatch_async(dispatch_get_main_queue(), ^{
        [application registerForRemoteNotifications];

        // DEBUG
//        NSLog(@"Invoked registerForRemoteNotifications");
    });
    
    // process on local notification received
    if (![Utility isDeviceVersion10OrLater] && launchOptions) {
        UILocalNotification *localNotification = launchOptions[UIApplicationLaunchOptionsLocalNotificationKey];
        
        if (localNotification) {
    //        NSLog(@"didFinishLaunchingWithOptions with local notification: %@", localNotification);
            
            [self processReceivedLocalNotification:localNotification application:application];
        }
    }

    // move external folder from share directory of the containing app to share directory of the app group.
    [Utility moveExternalDirectoryToAppGroupDirectory];

    // update the value of FileTransfer.localPath from absolute to relative path
    [Utility updateFileTransferLocalPathToRelativePath];

    // move download files from application support directory to app group directory
    [Utility moveDownloadFileToAppGroupDirectory];

    if (launchOptions) {
        // Detect if notification received
        NSDictionary *userInfo = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];

        if (userInfo) {
//        NSLog(@"Notification in didFinishLaunchingWithOptions:\n%@", userInfo);

            id apsMessages = userInfo[NOTIFICATION_MESSAGE_KEY_APS];

            if (apsMessages && [apsMessages isKindOfClass:[NSDictionary class]]) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [self processReceivedRemoteNotification:userInfo application:application];
                });
            }
        }
    }

    // In version 1.5.0 and after, there will be no more USER_DEFAULTS_KEY_UPLOAD_SUBDIRECTORIES and USER_DEFAULTS_KEY_UPLOAD_DESCRIPTIONS
    // Use USER_DEFAULTS_KEY_UPLOAD_SUBDIRECTORY_VALUE and USER_DEFAULTS_KEY_UPLOAD_DESCRIPTION_VALUE to replace them

    [Utility moveUploadSettingsFromArrayToStringWithUserDefaults:groupUserDefaults];

    [Utility copyHierarchicalModelTypeToSectionNameWithUserDefaults:groupUserDefaults];

    [Utility createFileDownloadGroupToNonAssignedFileTransfersWithEachUserComputerWithUserDefaults:groupUserDefaults];

    // Since v 1.5.5, both tables: FileDownloadGroup & FileUploadGroup add column 'StartTimestamp' and it is used as the section title to DownloaFileViewController and FileUploadViewController,
    // so if the value to the existing records will be updated to the current timestamp
    [Utility updateFileDownloadAndUploadGroupsCreateTimestampToCurrentTimestamp];

    _preferredContentSizeCategoryService = [[PreferredContentSizeCategoryService alloc] init];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangePreferredContentSize:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];

    // get the ref of MenuTabBarController, the initial view controller
    self.menuTabBarController = (MenuTabBarController *) self.window.rootViewController;

    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    __block UIBackgroundTaskIdentifier bgTask;

    bgTask = [application beginBackgroundTaskWithName:@"FLTask" expirationHandler:^{

        // Clean up any unfinished task business by marking where you
        // stopped or ending the task outright.

        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];

    // Start the long-running task and return immediately.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        // Do the work associated with the task, preferably in chunks.

        // Sending a test local notification
//        FilelugFileDownloadService *fileDownloadService = [[FilelugFileDownloadService alloc] init];
//
//        NSString *transferKey = @"C988FF8436C975065351B54AEFF9CF77F4936120D9F8C14FD2C12C4A00B91E3598069CC97889395DA61D10F3471B24EEEA2EB24CDF869A9DB8425351D07A2F14+fcd16da9a24dd629de2470de17590f46+down+DC757408-F5BE-41D0-BDA0-A6330A5E4425";
//        NSString *filename = @"20161108-02-和勤精機(股)公司105年度現金增資公開說明書_170120032331.pdf";
//        [fileDownloadService sendSingleSuccessLocalNotificationWithTransferKey:transferKey filename:filename];

        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    });
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    // refresh application locale every time back to application
    NSString *appLocale = [[NSBundle mainBundle] preferredLocalizations][0];
    
    [userDefaults setObject:appLocale forKey:USER_DEFAULTS_KEY_MAIN_APP_LOCALE];
    
    [Utility clearCachedNotificationBadgeNumber];
    
    application.applicationIconBadgeNumber = 0;

    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];
    
    if (sessionId) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // Process wait to confirm for uploaded and downloaded files
            [self processUnfinishedUploadsAndDownloads];
        });
    }
}

// this method may be called in situations where the application is running in the background (not suspended) and the system needs to terminate it for some reason
- (void)applicationWillTerminate:(UIApplication *)application {
    // cancel files downloading and save resumeData, if any

    [[Utility groupUserDefaults] synchronize];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];

    ClopuccinoCoreData *coreData = [ClopuccinoCoreData defaultCoreData];

    // stop receiving data writing notification from extensions
    coreData.receivesUpdates = NO;
    
    // DO NOT REMOVE THIS FOR FUTURE IN-APP PURCHASE
    //    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self.productService];
}

// When all of the tasks associated with a background session are complete, the system relaunches a terminated app
// (assuming that the sessionSendsLaunchEvents property was set to YES and that the user did not force quit the app)
// and invoke this method:
- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)(void))completionHandler {
//    NSLog(@"handleEventsForBackgroundURLSession: %@", identifier);

    // Do the followings by order:
    // 1. store that completion handler
    // 2. create background session with the same identifier,
    //    so the system reconnects your new session object to the previous tasks and reports their status to the session object’s delegate.

    id <BackgroundTransferService> backgroundTransferService;

    if ([identifier hasPrefix:BACKGROUND_UPLOAD_ID_FOR_FILELUG_PREFIX]) {
        backgroundTransferService = [[FilelugFileUploadService alloc] initWithBackgroundCompletionHandler:completionHandler];
    } else if ([identifier hasPrefix:BACKGROUND_UPLOAD_ID_FOR_SHARE_EXTENSION_PREFIX]) {
        backgroundTransferService = [[SHFileUploadService alloc] initWithBackgroundCompletionHandler:completionHandler];
    } else if ([identifier hasPrefix:BACKGROUND_DOWNLOAD_ID_FOR_FILELUG_PREFIX]) {
        backgroundTransferService = [[FilelugFileDownloadService alloc] initWithBackgroundCompletionHandler:completionHandler];
    } else if ([identifier hasPrefix:BACKGROUND_DOWNLOAD_ID_FOR_DOCUMENT_PROVIDER_EXTENSION_PREFIX]) {
        backgroundTransferService = [[DPFileDownloadService alloc] initWithBackgroundCompletionHandler:completionHandler];
    }

    if (backgroundTransferService) {
        NSURLSession *backgroundSession = [backgroundTransferService backgroundSession];

        [self.backgroundSessions setValue:backgroundSession forKey:identifier];
    }
}

- (void)didChangePreferredContentSize:(NSNotification *)notification {
    [self.preferredContentSizeCategoryService didChangePreferredContentSizeWithNotification:notification];
}

- (void)processUnfinishedUploadsAndDownloads {
    // confirm downloads
    [self.fileTransferDao findWaitToConfirmFileTransferWithCompletionHandler:^(FileTransferWithoutManaged *fileTransferWithoutManaged) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self.directoryService confirmDownloadWithFileTransfer:fileTransferWithoutManaged tryAgainIfFailed:YES completionHandler:nil];
        });
    }];
    
    // confirm uploads with status of wait-to-confirm
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.directoryService confirmUploadsWithCompletionHandler:nil];
    });
    
    // change state canceling to failure
    [self.fileTransferDao findAllCancelingDownloadsAndChangeToFailure];
}

// for iOS 10 or later
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString*, id> *)options {
    return [self application:app openURL:url sourceApplication:nil annotation:nil options:options];
}

//// for iOS 9 only
//- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
//    return [self application:application openURL:url sourceApplication:sourceApplication annotation:annotation options:nil];
//}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation options:(NSDictionary<NSString*, id> *)options {
//    // DEBUG
//    NSURL *aURL = url;
//    NSString *aSourceApplication = sourceApplication;
//    id aAnnotation = annotation;
//    NSDictionary<NSString*, id> *aOptions = options;
//
//    NSLog(@"URL:%@\nSource application:%@\nAnnotation:%@\nOptions:\n%@", url, aSourceApplication, annotation, aOptions);

    UploadExternalFileViewController *uploadExternalFileViewController = [Utility instantiateViewControllerWithIdentifier:@"UploadExternalFile"];

    // Do not use NSURL to take this parameter because the object will be nil after the  APP starts!
    //    uploadExternalFileViewController.filePath = [url path];

    NSMutableArray *filePaths = [NSMutableArray array];
    [filePaths addObject:[url path]];

    uploadExternalFileViewController.absolutePaths =  filePaths;

    UINavigationController *uploadExternalFileNavigationController = [[UINavigationController alloc] initWithRootViewController:uploadExternalFileViewController];

    [[self topViewController] presentViewController:uploadExternalFileNavigationController animated:YES completion:nil];

    return YES;
}

- (UIViewController *)topViewController {
    return [self topViewControllerWithRootViewController:[UIApplication sharedApplication].keyWindow.rootViewController];
}

- (UIViewController *)topViewControllerWithRootViewController:(UIViewController *)rootViewController {
    if ([rootViewController isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tabBarController = (UITabBarController *) rootViewController;
        return [self topViewControllerWithRootViewController:tabBarController.selectedViewController];
    } else if ([rootViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navigationController = (UINavigationController *) rootViewController;
        return [self topViewControllerWithRootViewController:navigationController.visibleViewController];
    } else if (rootViewController.presentedViewController) {
        UIViewController *presentedViewController = rootViewController.presentedViewController;
        return [self topViewControllerWithRootViewController:presentedViewController];
    } else {
        return rootViewController;
    }
}

// On receiving local notification when APP is in foreground, backgroud, or inactive
// Works for iOS 9 here only.
// In iOS 10 or later, use methods of UNUserNotificationCenterDelegate
- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
//    NSLog(@"didReceiveLocalNotification with local notification: %@", notification);

    [self processReceivedLocalNotification:notification application:application];
}

- (void)processReceivedLocalNotification:(UILocalNotification *)notification application:(UIApplication *)application {
    NSDictionary *userInfo = [notification userInfo];
    
    if (userInfo) {
        [self processReceivedLocalNotificationWithMessage:userInfo application:application];
    }
}

- (void)processReceivedLocalNotificationWithMessage:(NSDictionary *)message application:(UIApplication *)application {
    if (application && application.applicationState != UIApplicationStateActive) {
        MenuTabBarController *tabBarController = [self menuTabBarController];

        DownloadFileViewController *downloadFileViewController = tabBarController.downloadFileViewController;

        if (downloadFileViewController) {
            if (message) {
                // for notification type of "On each file"
                NSString *transferKey = message[NOTIFICATION_MESSAGE_KEY_TRANSFER_KEY];

                if (!transferKey) {
                    // for notification type of "On all files"

                    NSString *downloadGroupId = message[NOTIFICATION_MESSAGE_KEY_DOWNLOAD_GROUP_ID];

                    if (downloadGroupId) {
                        transferKey = [self.fileTransferDao findTransferKeyOfFirstFileWithFileDownloadGroupId:downloadGroupId];
                    }
                }

                if (transferKey) {
                    // scroll to the file cell
                    downloadFileViewController.transferKeyToScrollTo = transferKey;

                    if ([self shouldSimulatePressingOnDownloadedFileCellWithFileDownloadedKey:transferKey]) {
                        downloadFileViewController.transferKeyToPressOn = transferKey;
                    }
                }
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                [tabBarController setSelectedIndex:INDEX_OF_TAB_BAR_DOWNLOAD];

                [[tabBarController navigationControllerAtTabBarIndex:INDEX_OF_TAB_BAR_DOWNLOAD] popToRootViewControllerAnimated:YES];
            });
        }
    }
}

- (BOOL)shouldSimulatePressingOnDownloadedFileCellWithFileDownloadedKey:(NSString *)fileDownloadedKey {
    // Simulate pressing the cell only when either one condition meets:
    // 1. the notification type of the downloaded group is each-file
    // 2. there's only one file for the download group of the downloaded file with the transfer key

    __block BOOL shouldPressingOnCell = NO;

    FileDownloadGroupWithoutManaged *downloadGroupWithoutManaged = [self.fileDownloadGroupDao findFileDownloadGroupByTransferKey:fileDownloadedKey];

    if (downloadGroupWithoutManaged) {
        if (downloadGroupWithoutManaged.notificationType && [downloadGroupWithoutManaged.notificationType integerValue] == FILE_TRANSFER_NOTIFICATION_TYPE_ON_EACH_FILE) {
            // the notification type of the downloaded group is each-file

            shouldPressingOnCell = YES;
        } else {
            // there's only one file for the download group of the downloaded file with the transfer key

            NSSet<NSString *> *fileTransferKeys = downloadGroupWithoutManaged.fileTransferKeys;

            shouldPressingOnCell = (fileTransferKeys && [fileTransferKeys count] == 1);
        }
    }

    return shouldPressingOnCell;
}

// On registered notifications successfully
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *tokenDescription = [deviceToken description];

        NSString *tokenString = [[tokenDescription stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]] stringByReplacingOccurrencesOfString:@" " withString:@""];

        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        [userDefaults setObject:tokenString forKey:USER_DEFAULTS_KEY_REMOTE_NOTIFICATION_DEVICE_TOKEN];

        // DEBUG:
//        NSLog(@"Device token description: '%@', token string: '%@'", tokenDescription, tokenString);

        // upload to repo
        [self updateDeviceTokenToAllUsersWithDeviceToken:tokenString userDefaults:userDefaults tryAgainIfFailed:YES];
    });
}

// On failure to register notifcations
- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    // The error might be an erroneous aps-environment value in the provisioning profile.
    // We should view the error as a transient state and not attempt to parse it.
    NSLog(@"Failed to register remote notification.\n%@", error ? [error userInfo] : @"");
}

// the system calls this method ONLY when your app is running in the foreground.
// Use the methods of UNUserNotificationCenterDelegate instead for iOS 10 or later
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    //    NSLog(@"didReceiveRemoteNotification with remote notification: %@", userInfo);

    [self processReceivedRemoteNotification:userInfo application:application];
}

// the system calls this method when your app is running in the foreground or background.
// In addition, if you enabled the remote notifications background mode, the system launches your app
// (or wakes it from the suspended state) and puts it in the background state when a remote notification arrives.
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
//    NSLog(@"didReceiveRemoteNotification with remote notification: %@", userInfo);

    [self processReceivedRemoteNotification:userInfo application:application];

    completionHandler(UIBackgroundFetchResultNoData);
}

- (void)processReceivedRemoteNotification:(NSDictionary *)userInfo application:(UIApplication *)application {
//    NSLog(@"Received remote notification:\n%@", userInfo);
    // fl-type
    NSString *notificationType = userInfo[NOTIFICATION_MESSAGE_KEY_TYPE];

    if (notificationType && ([notificationType isEqualToString:NOTIFICATION_MESSAGE_TYPE_UPLOAD_FILE] || [notificationType isEqualToString:NOTIFICATION_MESSAGE_TYPE_ALL_FILES_UPLOADED_SUCCESSFULLY])) {
        // process notifications for upload-file

        // Confirm upload
        NSString *transferKey = userInfo[NOTIFICATION_MESSAGE_KEY_TRANSFER_KEY];

        if (transferKey) {
            // single upload notification - success or failure

            NSString *transferStatus = userInfo[NOTIFICATION_MESSAGE_KEY_TRANSFER_STATUS];

            if (transferStatus && ([transferStatus isEqualToString:FILE_TRANSFER_STATUS_SUCCESS] || [transferStatus isEqualToString:FILE_TRANSFER_STATUS_FAILED])) {
                NSDictionary *transferKeyAndStatusDictionary = @{NOTIFICATION_MESSAGE_KEY_TRANSFER_KEY : transferKey, NOTIFICATION_MESSAGE_KEY_TRANSFER_STATUS : transferStatus};

                [self.directoryService updateFileUploadStatusToSuccessOrFailureWithTransferKeyAndStatusDictionary:transferKeyAndStatusDictionary];
            }
        } else {
            NSString *uploadGroupId = userInfo[NOTIFICATION_MESSAGE_KEY_UPLOAD_GROUP_ID];

            if (uploadGroupId) {
                // group upload notification - success

                [self.assetFileDao findAssetFilesWithFileUploadGroupId:uploadGroupId completionHandler:^(AssetFile *assetFile) {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        NSString *foundTransferKey = assetFile.transferKey;
                        NSString *foundTransferStatus = assetFile.status;

                        if (![foundTransferStatus isEqualToString:FILE_TRANSFER_STATUS_SUCCESS]) {
                            NSDictionary *transferKeyAndStatusDictionary = @{NOTIFICATION_MESSAGE_KEY_TRANSFER_KEY : foundTransferKey, NOTIFICATION_MESSAGE_KEY_TRANSFER_STATUS : FILE_TRANSFER_STATUS_SUCCESS};

                            [self.directoryService updateFileUploadStatusToSuccessOrFailureWithTransferKeyAndStatusDictionary:transferKeyAndStatusDictionary];
                        }
                    });
                }];
            }
        }

        // if user tap notification and app invokeed from backgroud

        if (application && application.applicationState != UIApplicationStateActive) {
            MenuTabBarController *tabBarController = [self menuTabBarController];
            
            FileUploadViewController *fileUploadViewController = tabBarController.fileUploadViewController;

            dispatch_async(dispatch_get_main_queue(), ^{
                [tabBarController setSelectedIndex:INDEX_OF_TAB_BAR_UPLOAD];

                [[tabBarController navigationControllerAtTabBarIndex:INDEX_OF_TAB_BAR_UPLOAD] popToRootViewControllerAnimated:YES];

                if (fileUploadViewController) {
                    // scroll to the file cell
                    fileUploadViewController.transferKeyToScrollTo = transferKey;
                }
            });
        }
    }
}

- (void)updateDeviceTokenToAllUsersWithDeviceToken:(NSString *)deviceToken userDefaults:(NSUserDefaults *)userDefaults tryAgainIfFailed:(BOOL)tryAgainIfFailed {
    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];
    
    if (sessionId) {
        [self.authService updateAllUsersWithDeviceToken:deviceToken session:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];
                
                if (statusCode == 200) {
                    // DEBUG
//                    NSLog(@"Token '%@' updated to all users", deviceToken);

                    // Connect to current computer if the value of user computer id in user defaults exists
                    [self connectToCurrentComputerIfAvailableWithUserDefaults:userDefaults];
                } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
                    // sender set to nil for we do not want to show connection view controller if login failed
                    // try only twice

                    [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            [self updateDeviceTokenToAllUsersWithDeviceToken:deviceToken userDefaults:userDefaults tryAgainIfFailed:NO];
                        });
                    } failureHandler:^(NSData *loginData, NSURLResponse *loginResponse, NSError *loginError) {
                        NSInteger loginStatusCode = [(NSHTTPURLResponse *) loginResponse statusCode];
                        NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Login failed. %@ Status:%d", @""), [loginError localizedDescription], loginStatusCode];
                        NSLog(@"%@", message);
                    }];
                    
                    // The service invoke from AA Server and don't care error code 503.
                } else {
                    NSLog(@"Failed to update device token.");
                }
            });
        }];
    }
}

- (void)connectToCurrentComputerIfAvailableWithUserDefaults:(NSUserDefaults *)userDefaults {
    NSString *userComputerId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

    // Find the UserComputer in local db and use the value for showHidden and set to @(NO) if not found.
    // The UserComputerWithoutManaged is from server and there's no value to property showHidden.
    NSNumber *showHidden = [self.userComputerDao findShowHiddenForUserComputerId:userComputerId];

    if (!showHidden) {
        showHidden = @(NO);
    }

    NSString *userId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_ID];

    NSNumber *computerId = [userDefaults objectForKey:USER_DEFAULTS_KEY_COMPUTER_ID];

    NSString *sessionId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    if (sessionId && userComputerId && userId && computerId) {
        // connect to computer
        [self.userComputerService connectToComputerWithUserId:userId
                                                   computerId:computerId
                                                   showHidden:showHidden
                                                      session:sessionId
                                               successHandler:nil
                                               failureHandler:nil];
    }
}

#pragma mark - Received after invoking registerUserNotificationSettings:(iOS 9 only)

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {

    // if notificationSettings.types is UIUserNotificationTypeNone,
    // it means "the user" reject this device to receive local and remote notification.

    UIUserNotificationType notificationType = notificationSettings.types;

    // prompt only when first time user choose not to receive remote and local notifications.

    if (notificationType == UIUserNotificationTypeNone) {
        // Notifiy user to setup notification later, only once

        static dispatch_once_t notificationPermissionOnceToken;
        dispatch_once(&notificationPermissionOnceToken, ^{
            NSString *message = NSLocalizedString(@"Want to allow notification later", @"");

            [Utility viewController:nil alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
        });
    }
}

#pragma mark - UNUserNotifcationCenterDelegate(iOS 10 or later)

// The method will be called on the delegate only if the application is in the foreground.
// If the method is not implemented or the handler is not called in a timely manner then the notification will not be presented.
// The application can choose to have the notification presented as a sound, badge, alert and/or in the notification list.
// This decision should be based on whether the information in the notification is otherwise visible to the user.
- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
//    NSDictionary * userInfo = notification.request.content.userInfo;
//
//    UNNotificationRequest *request = notification.request;  // 收到推送的请求
//    UNNotificationContent *content = request.content;       // 收到推送的消息内容
//    NSNumber *badge = content.badge;                        // 推送消息的 badge
//    NSString *body = content.body;                          // 推送消息的訊息本體
//    UNNotificationSound *sound = content.sound;             // 推送消息的聲音
//    NSString *subtitle = content.subtitle;                  // 推送消息的副標題
//    NSString *title = content.title;                        // 推送消息的主標題

//    if([notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
//        // remote notification received
//
//        NSLog(@"[Remote notification] willPresentNotification:\n%@", userInfo);
//    } else {
//        // local notification received
//
//        NSLog(@"[Local notification] willPresentNotification:\n%@", userInfo);
//    }
    
//    completionHandler(UNNotificationPresentationOptionAlert | UNNotificationPresentationOptionSound);
    // Since it is in the foreground, no need to prompt.
    completionHandler(UNNotificationPresentationOptionNone);
}

// The method will be called on the delegate when the user responded to the notification by opening the application, dismissing the notification or choosing a UNNotificationAction.
// The delegate must be set before the application returns from applicationDidFinishLaunching:.
- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void(^)(void))completionHandler {
    NSDictionary * userInfo = response.notification.request.content.userInfo;

    NSLog(@"didReceiveNotificationResponse:\n%@", userInfo);

    if([response.notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
        // remote notification received

        [self processReceivedRemoteNotification:userInfo application:[UIApplication sharedApplication]];
    } else {
        // local notification received

        if (userInfo) {
            [self processReceivedLocalNotificationWithMessage:userInfo application:[UIApplication sharedApplication]];
        }
    }

    // If you don't call this, system alerts warning:
    // UNUserNotificationCenter delegate received call to -userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler: but the completion handler was never called.
    if (completionHandler) {
        completionHandler();
    }
}

@end
