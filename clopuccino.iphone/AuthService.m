#import "AuthService.h"
#import "UIViewController+Visibility.h"
#import "Utility.h"
#import "UserDao.h"
#import "UserWithoutManaged.h"
#import "NSString+Utlities.h"
#import "UserComputerDao.h"
#import "AssetFileWithoutManaged.h"
#import "FileTransferWithoutManaged.h"
#import "DirectoryService.h"
#import "FileTransferDao.h"
#import "AssetFileDao.h"
#import "ProcessableViewController.h"
#import "UIAlertController+ShowWithoutViewController.h"

#define DEVICE_VERSION ([[UIDevice currentDevice] systemVersion])

@interface AuthService ()

@end

@implementation AuthService {
    
}

+ (NSString *)prepareFailedConnectToComputerMessageWithResponse:(NSURLResponse *)response error:(NSError *)error data:(NSData *)data {
    // alert with error or response status/message

    NSString *responseString = @"";

    if (error) {
        NSLog(@"Error on connecting to computer: %@\n%@", error, [error userInfo]);

        responseString = [responseString stringByAppendingFormat:@"\n%@", error.localizedDescription];
    }

    if (data) {
        responseString = [responseString stringByAppendingFormat:@"\n%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];

        NSLog(@"Response data: %@", responseString);
    }

    NSInteger responseStatusCode = [(NSHTTPURLResponse *) response statusCode];

    return [NSString stringWithFormat:NSLocalizedString(@"Failed to connect to computer. %@ Status:%d", @""), responseString, responseStatusCode];
}

+ (NSString *)prepareFailedLoginMessageWithResponse:(NSURLResponse *)response error:(NSError *)error data:(NSData *)data {
    // alert with error or response status/message
    NSString *responseString = @"";

    if (error) {
        NSLog(@"Error on login: %@, %@", error, [error userInfo]);

        responseString = [responseString stringByAppendingFormat:@"\n%@", error.localizedDescription];
    }

    if (data) {
        responseString = [responseString stringByAppendingFormat:@"\n%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];

        NSLog(@"Response data: %@", responseString);
    }

    if (response) {
        NSInteger responseStatusCode = [(NSHTTPURLResponse *) response statusCode];

        responseString = [NSString stringWithFormat:NSLocalizedString(@"Login failed. %@ Status:%d", @""), responseString, responseStatusCode];
    } else {
        responseString = [NSString stringWithFormat:NSLocalizedString(@"Login failed. %@", @""), responseString];
    }

    return responseString;
}

- (id)initWithCachePolicy:(NSURLRequestCachePolicy)policy timeInterval:(NSTimeInterval)interval {
    if (self = [super init]) {
        _cachePolicy = policy;
        _timeInterval = interval;
    }
    
    return self;
}

- (UserDao *)userDao {
    if (!_userDao) {
        _userDao = [[UserDao alloc] init];
    }
    
    return _userDao;
}

- (UserComputerDao *)userComputerDao {
    if (!_userComputerDao) {
        _userComputerDao = [[UserComputerDao alloc] init];
    }
    
    return _userComputerDao;
}

- (void)requestConnectWithSession:(NSString *)sessionId successHandler:(void (^)(NSURLResponse *, NSData *))successHandler failureHandler:(void (^)(NSData *, NSURLResponse *, NSError *))failureHandler {
    // try get connection info from NSUserDefaults
    NSString *urlString = [Utility composeAAServerURLStringWithPath:@"user/reconnect"];

    // Use REQUEST_CONNECT_TIME_INTERVAL insteaad of default time interval, which is usually 60 sec.

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:REQUEST_CONNECT_TIME_INTERVAL];
    [request setHTTPMethod:@"POST"];
    
    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];
        
        if (statusCode == 200) {
            // save response data
            
            NSError *parseError;
            [self saveRequestConnectData:data error:&parseError];
            
            if (!parseError) {
                // customized process
                
                NSLog(@"Successfully request reconnect.");
                
                if (successHandler) {
                    successHandler(response, data);
                }
            } else {
                // customized process
                
                if (failureHandler) {
                    failureHandler(data, response, parseError);
                }
            }
        } else {
            // customized process
            
            if (failureHandler) {
                failureHandler(data, response, error);
            }
        }
    }] resume];
}

- (void)loginWithUserWithoutManaged:(UserWithoutManaged *)userWithoutManaged successHandler:(void (^)(NSURLResponse *, NSData *))successHandler failureHandler:(void (^)(NSData *, NSURLResponse *, NSError *))failureHandler {
    NSString *sessionId = userWithoutManaged.sessionId;
    NSString *userId = userWithoutManaged.userId;
    NSString *countryId = userWithoutManaged.countryId;
    NSString *phoneNumber = userWithoutManaged.phoneNumber;

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *domainURLScheme = [userDefaults stringForKey:USER_DEFAULTS_KEY_DOMAIN_URL_SCHEME];
    NSString *domainName = [userDefaults stringForKey:USER_DEFAULTS_KEY_DOMAIN_NAME];
    NSInteger port = [userDefaults integerForKey:USER_DEFAULTS_KEY_PORT];
    NSString *contextPath = [userDefaults stringForKey:USER_DEFAULTS_KEY_CONTEXT_PATH];

    [self loginWithSession:sessionId userId:userId countryId:countryId phoneNumber:phoneNumber domainURLScheme:domainURLScheme domainName:domainName port:port contextPath:contextPath successHandler:successHandler failureHandler:failureHandler];
}

- (void)reloginWithSuccessHandler:(void (^ _Nullable)(NSURLResponse *, NSData *))successHandler failureHandler:(void (^ _Nullable)(NSData *, NSURLResponse *, NSError *))failureHandler {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];
    NSString *userId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_ID];
    NSString *countryId = [userDefaults stringForKey:USER_DEFAULTS_KEY_COUNTRY_ID];
    NSString *phoneNumber = [userDefaults stringForKey:USER_DEFAULTS_KEY_PHONE_NUMBER];

    NSString *domainURLScheme = [userDefaults stringForKey:USER_DEFAULTS_KEY_DOMAIN_URL_SCHEME];
    NSString *domainName = [userDefaults stringForKey:USER_DEFAULTS_KEY_DOMAIN_NAME];
    NSInteger port = [userDefaults integerForKey:USER_DEFAULTS_KEY_PORT];
    NSString *contextPath = [userDefaults stringForKey:USER_DEFAULTS_KEY_CONTEXT_PATH];

    [self loginWithSession:sessionId userId:userId countryId:countryId phoneNumber:phoneNumber domainURLScheme:domainURLScheme domainName:domainName port:port contextPath:contextPath successHandler:successHandler failureHandler:failureHandler];
}

- (void)createOrUpdateDemoAccountWithSuccessHandler:(void (^ _Nullable)(NSURLResponse *, NSData *))successHandler failureHandler:(void (^ _Nullable)(NSData *_Nullable , NSURLResponse *_Nullable , NSError *_Nullable ))failureHandler {
    NSString *sessionId = [self demoeSessionIdWithApplicationLocale];
//    NSString *sessionId = DEMO_ACCOUNT_SESSION_ID;
    NSString *userId = DEMO_ACCOUNT_USER_ID;
    NSString *countryId = DEMO_ACCOUNT_COUNTRY_ID;
    NSString *phoneNumber = DEMO_ACCOUNT_PHONE_NUMBER;
    NSString *nickname = DEMO_ACCOUNT_NICKNAME;
    NSString *email = DEMO_ACCOUNT_EMAIL;

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *applicationLocale = [userDefaults stringForKey:USER_DEFAULTS_KEY_MAIN_APP_LOCALE];

    // insert into local db

    UserWithoutManaged *userWithoutManaged = [[UserWithoutManaged alloc] initWithUserId:userId
                                                                              countryId:countryId
                                                                            phoneNumber:phoneNumber
                                                                              sessionId:sessionId
                                                                               nickname:nickname
                                                                                  email:email
                                                                                 active:@YES
                                                                                 locale:applicationLocale];

    [self.userDao createOrUpdateUserWithUserWithoutManaged:userWithoutManaged completionHandler:^(NSError *error) {
        if (error) {
            if (failureHandler) {
                failureHandler(nil, nil, error);
            }
        } else {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self loginWithUserWithoutManaged:userWithoutManaged successHandler:successHandler failureHandler:failureHandler];
            });
        }
    }];
}

- (nonnull NSString *)demoeSessionIdWithApplicationLocale {
/*
 * -- zh-Hant: D9C3FC9ECFACEF9D9C381814AA3FE8A1BEBED2A7E9D5E8851AB917186DCBEA275182FD0B4879C7EAA34A0D449E8C5A8B80D308AEF30681FE56224E4CC8EC7064
 * -- zh-Hans: 47CB9C665E769D95C76B448EE9BB4149A12A270B1D5EE3B27FEA20A249C52099525460856B616675431923269E8341E7491D7AE2AF4D018960131675A537CCDA
 * -- en: 05520AE6C02211AC4279CA4B84C3A7634F1051A1F6E5B5825185FAF2593DF57BB5359A09306D2D4AFCE1CBCC8BB45EEA777B95B1BD8378F4F613E9791C4BD997
 */

    NSString *demoSessionId;

    NSString *deviceLocale = [Utility deviceLocale];

    if ([deviceLocale hasPrefix:@"zh-Hant"]) {
        demoSessionId = @"D9C3FC9ECFACEF9D9C381814AA3FE8A1BEBED2A7E9D5E8851AB917186DCBEA275182FD0B4879C7EAA34A0D449E8C5A8B80D308AEF30681FE56224E4CC8EC7064";
    } else if ([deviceLocale hasPrefix:@"zh"]) {
        demoSessionId = @"47CB9C665E769D95C76B448EE9BB4149A12A270B1D5EE3B27FEA20A249C52099525460856B616675431923269E8341E7491D7AE2AF4D018960131675A537CCDA";
    } else {
        demoSessionId = @"05520AE6C02211AC4279CA4B84C3A7634F1051A1F6E5B5825185FAF2593DF57BB5359A09306D2D4AFCE1CBCC8BB45EEA777B95B1BD8378F4F613E9791C4BD997";
    }

    return demoSessionId;
}

- (void)loginWithSession:(NSString *)sessionId userId:(NSString *)userId countryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber domainURLScheme:(NSString *)domainURLScheme domainName:(NSString *)domainName port:(NSInteger)port contextPath:(NSString *)contextPath successHandler:(void (^ _Nullable)(NSURLResponse *, NSData *))successHandler failureHandler:(void (^ _Nullable)(NSData *, NSURLResponse *, NSError *))failureHandler {
    NSString *urlString = [Utility composeAAServerURLStringWithScheme:domainURLScheme domainName:domainName port:port context:contextPath path:@"user/loginse"];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];

    [request setHTTPMethod:@"POST"];

    NSString *phoneNumberWithoutZeroPrefix;

    if ([phoneNumber hasPrefix:@"0"]) {
        phoneNumberWithoutZeroPrefix = [phoneNumber substringFromIndex:1];
    } else {
        phoneNumberWithoutZeroPrefix = [phoneNumber copy];
    }

    NSString *verification = [UserWithoutManaged generateVerificationFromUserId:userId countryId:countryId phoneNumber:phoneNumberWithoutZeroPrefix];

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *deviceTokenJsonString = [Utility prepareDeviceTokenJsonWithUserDefaults:userDefaults];

    NSString *bodyString;

    // device token

    NSString *applicationLocale = [userDefaults stringForKey:USER_DEFAULTS_KEY_MAIN_APP_LOCALE];

    if (deviceTokenJsonString) {
        bodyString = [NSString stringWithFormat:@"{\"sessionId\" : \"%@\", \"verification\" : \"%@\", \"locale\" : \"%@\", \"device-token\" : %@}", sessionId, verification, applicationLocale, deviceTokenJsonString];
    } else {
        bodyString = [NSString stringWithFormat:@"{\"sessionId\" : \"%@\", \"verification\" : \"%@\", \"locale\" : \"%@\"}", sessionId, verification, applicationLocale];
    }

    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

        if (statusCode == 200) {
            // save response data

            NSError *parseError;
            [self saveLoginWithSessionIdResponseData:data encryptedPassword:countryId error:&parseError];

            // no need to reload other tab bar view controllers

            if (!parseError) {
                // customized process

                if (successHandler) {
                    successHandler(response, data);
                }
            } else {
                // customized process

                if (failureHandler) {
                    failureHandler(data, response, parseError);
                }
            }
        } else {
            // customized process

            if (failureHandler) {
                failureHandler(data, response, error);
            }
        }
    }] resume];
}

//- (void)loginOnlyWithDomainURLScheme:(NSString *)domainURLScheme domainName:(NSString *)domainName port:(NSInteger)port contextPath:(NSString *)contextPath userId:(NSString *)userId password:(NSString *)password nickname:(NSString *)nickname successHandler:(void (^)(NSURLResponse *, NSData *))successHandler failureHandler:(void (^)(NSData *, NSURLResponse *, NSError *))failureHandler {
//    NSString *urlString = [Utility composeAAServerURLStringWithScheme:domainURLScheme domainName:domainName port:port context:contextPath path:@"user/login"];
//
//    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
//    [request setHTTPMethod:@"POST"];
//
//    NSString *escapedUserId = [userId escapeIllegalJsonCharacter];
//
//    if (!nickname || [nickname stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length < 1) {
//        nickname = [Utility uuid];
//    }
//
//    NSString *escapedNickname = [nickname escapeIllegalJsonCharacter];
//
//    NSString *verification = [UserWithoutManaged generateVerificationFromUserId:userId password:password nickname:nickname];
//
//    NSUserDefaults *userDefaults = [Utility groupUserDefaults];
//
//    NSString *deviceTokenJsonString = [Utility prepareDeviceTokenJsonWithUserDefaults:userDefaults];
//
//    NSString *bodyString;
//
//    // device token
//
//    NSString *applicationLocale = [userDefaults stringForKey:USER_DEFAULTS_KEY_MAIN_APP_LOCALE];
//
//    if (deviceTokenJsonString) {
//        bodyString = [NSString stringWithFormat:@"{\"account\" : \"%@\", \"passwd\" : \"%@\", \"nickname\" : \"%@\", \"verification\" : \"%@\", \"locale\" : \"%@\", \"device-token\" : %@}", escapedUserId, password, escapedNickname, verification, applicationLocale, deviceTokenJsonString];
//    } else {
//        bodyString = [NSString stringWithFormat:@"{\"account\" : \"%@\", \"passwd\" : \"%@\", \"nickname\" : \"%@\", \"verification\" : \"%@\", \"locale\" : \"%@\"}", escapedUserId, password, escapedNickname, verification, applicationLocale];
//    }
//
//    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
//    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
//
//    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
//        NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];
//
//        if (statusCode == 200) {
//            // save response data
//
//            NSError *parseError;
//            [self saveLoginOnlyData:data encryptedPassword:password error:&parseError];
//
//            // notify that other tab bar view controllers need to reload
//            [userDefaults setBool:YES forKey:USER_DEFAULTS_KEY_RELOAD_MENU];
//            [userDefaults setObject:@YES forKey:USER_DEFAULTS_KEY_NEED_RELOAD_DOWNLOAD_LIST];
//            [userDefaults setObject:@YES forKey:USER_DEFAULTS_KEY_NEED_RELOAD_UPLOAD_LIST];
//
//            if (!parseError) {
//                // customized process
//
//                successHandler(response, data);
//            } else {
//                // customized process
//
//                failureHandler(data, response, parseError);
//            }
//        } else {
//            // customized process
//
//            failureHandler(data, response, error);
//        }
//    }] resume];
//}

//- (void)loginWithDomainURLScheme:(NSString *)domainURLScheme domainName:(NSString *)domainName port:(NSInteger)port contextPath:(NSString *)contextPath userId:(NSString *)userId password:(NSString *)password nickname:(NSString *)nickname showHidden:(BOOL)showHidden computerId:(NSNumber *)computerId successHandler:(void (^)(NSURLResponse *, NSData *))successHandler failureHandler:(void (^)(NSURLResponse *, NSData *, NSError *))failureHandler {
//    NSString *urlString = [Utility composeAAServerURLStringWithScheme:domainURLScheme domainName:domainName port:port context:contextPath path:@"user/login"];
//
//    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
//    [request setHTTPMethod:@"POST"];
//
//    NSString *escapedUserId = [userId escapeIllegalJsonCharacter];
//
//    if (!nickname || [nickname stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length < 1) {
//        nickname = [Utility uuid];
//    }
//
//    NSString *escapedNickname = [nickname escapeIllegalJsonCharacter];
//
//    NSString *verification = [UserWithoutManaged generateVerificationFromUserId:userId password:password nickname:nickname];
//
//    NSUserDefaults *userDefaults = [Utility groupUserDefaults];
//
//    NSString *deviceTokenJsonString = [Utility prepareDeviceTokenJsonWithUserDefaults:userDefaults];
//
//    NSString *bodyString;
//
//    // device token
//
//    NSString *applicationLocale = [userDefaults stringForKey:USER_DEFAULTS_KEY_MAIN_APP_LOCALE];
//
//    if (deviceTokenJsonString) {
//        bodyString = [NSString stringWithFormat:@"{\"account\" : \"%@\", \"passwd\" : \"%@\", \"nickname\" : \"%@\", \"verification\" : \"%@\", \"showHidden\" : %@, \"locale\" : \"%@\", \"computer-id\" : %lld, \"device-token\" : %@}", escapedUserId, password, escapedNickname, verification, showHidden ? @"true" : @"false", applicationLocale, [computerId longLongValue], deviceTokenJsonString];
//    } else {
//        bodyString = [NSString stringWithFormat:@"{\"account\" : \"%@\", \"passwd\" : \"%@\", \"nickname\" : \"%@\", \"verification\" : \"%@\", \"showHidden\" : %@, \"locale\" : \"%@\", \"computer-id\" : %lld}", escapedUserId, password, escapedNickname, verification, showHidden ? @"true" : @"false", applicationLocale, [computerId longLongValue]];
//    }
//
//    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
//    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
//
//    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
//        NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];
//
//        if (statusCode == 200) {
//            // save response data
//
//            NSError *parseError;
//            [self saveLoginData:data encryptedPassword:password showHidden:@(showHidden) error:&parseError];
//
//            // notify that other tab bar view controllers need to reload
//            [userDefaults setBool:YES forKey:USER_DEFAULTS_KEY_RELOAD_MENU];
//            [userDefaults setObject:@YES forKey:USER_DEFAULTS_KEY_NEED_RELOAD_DOWNLOAD_LIST];
//            [userDefaults setObject:@YES forKey:USER_DEFAULTS_KEY_NEED_RELOAD_UPLOAD_LIST];
//
//            if (!parseError) {
//                // customized process
//
//                if (successHandler) {
//                    successHandler(response, data);
//                }
//            } else {
//                // customized process
//
//                if (failureHandler) {
//                    failureHandler(response, data, parseError);
//                }
//            }
//        } else {
//            // customized process
//
//            if (failureHandler) {
//                failureHandler(response, data, error);
//            }
//        }
//    }] resume];
//}

/*!
 process common failures of requests for the following response status code:
 0: prompt error
 401: invalid Session -- loginWithSessionId and retry with the afterGetNewSessionHandler
 403: Session Not Found -- sessionNotFoundHandler (such as Facebook Account Kit Login)
 501: computer not found -- computerNotFoundHandler (such as invoking findAvailableComputer3)
 465: desktop application needs upgrade -- promt error
 466: device APP needs upgrade -- promt error
 others -- prompt error
 */
- (void)processCommonRequestFailuresWithMessagePrefix:(nullable NSString *)messagePrefix response:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error tryAgainAction:(UIAlertAction *)tryAgainAction inViewController:(UIViewController *)viewController reloginSuccessHandler:(void (^)(NSURLResponse *, NSData *))reloginSuccessHandler {
    if ([viewController isVisible]) {
        NSInteger responseStatusCode = [(NSHTTPURLResponse *) response statusCode];

        // 不論 login 或 request connect，若因為desktop連線失敗，回傳值不會包括 lug-server-id。
        // 系統儲存時會把目前 user defaults 的 lug_server_id，值刪除。
        // 因此只要 user defaults 不存在 lug_server_id，就可以推斷是因為desktop連線失敗造成的錯誤

        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        // for error code 465, the computer name may not be the current one in preferences
//        NSString *computerName = [userDefaults stringForKey:USER_DEFAULTS_KEY_COMPUTER_NAME];

        NSString *lugServerId = [userDefaults objectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID];

        // 先判斷錯誤碼 NSURLErrorUserCancelledAuthentication(-1012) 與 status code == 401 的情況，
        // 因為 session id 可能已經過期或者密碼錯誤。
        if (responseStatusCode == 0) {
            NSString *computerName = [userDefaults stringForKey:USER_DEFAULTS_KEY_COMPUTER_NAME];

            NSString *subMessage;

            if (computerName && [computerName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
                subMessage = [NSString stringWithFormat:NSLocalizedString(@"Network Inaccessible", @""), computerName, computerName];
            } else {
                subMessage = [NSString stringWithFormat:NSLocalizedString(@"Network Inaccessible2", @"")];
            }

            NSString *message;

            if (messagePrefix && messagePrefix.length > 0) {
                message = [NSString stringWithFormat:@"%@\n%@", messagePrefix, subMessage];
            } else {
                message = subMessage;
            }

            NSString *messageTitle = NSLocalizedString(@"Network Inaccessible Title", @"");

            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:messageTitle message:message preferredStyle:UIAlertControllerStyleAlert];

            if (tryAgainAction) {
                [alertController addAction:tryAgainAction];
            }

            UIAlertAction *tryLaterAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Later", @"") style:UIAlertActionStyleCancel handler:nil];
            [alertController addAction:tryLaterAction];

            if ([viewController isVisible]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [alertController presentWithViewController:viewController sourceView:nil sourceRect:CGRectNull barButtonItem:nil animated:YES completion:nil];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [alertController presentWithAnimated:YES];
                });
            }
//            [Utility viewController:viewController alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
        } else if (responseStatusCode == 401 || (error && (error.code == NSURLErrorUserCancelledAuthentication || error.code == NSURLErrorSecureConnectionFailed))) {
            NSString *errorMessage;

            if (messagePrefix && messagePrefix.length > 0) {
                errorMessage = [messagePrefix stringByAppendingFormat:@"\n%@", NSLocalizedString(@"Your session has timed out. Please sign in again.", @"")];
            } else {
                errorMessage = NSLocalizedString(@"Your session has timed out. Please sign in again.", @"");
            }

            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:errorMessage preferredStyle:UIAlertControllerStyleAlert];

            UIAlertAction *sessionTimeoutAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Login Now", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
                // sign in again using loginWithSessionId

                [self reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                    if (reloginSuccessHandler) {
                        reloginSuccessHandler(loginResponse, loginData);
                    }
                } failureHandler:^(NSData *loginData, NSURLResponse *loginResponse, NSError *loginError) {
                    if ([viewController conformsToProtocol:@protocol(ProcessableViewController)]) {
                        ((id <ProcessableViewController>) viewController).processing = @NO;
                    }

                    NSInteger loginStatusCode = [(NSHTTPURLResponse *) loginResponse statusCode];
                    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Login failed. %@ Status:%d", @""), [loginError localizedDescription], loginStatusCode];

                    [Utility viewController:viewController alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                }];
            }];

            [alertController addAction:sessionTimeoutAction];

            UIAlertAction *tryLaterAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Later", @"") style:UIAlertActionStyleCancel handler:nil];
            [alertController addAction:tryLaterAction];

            if ([viewController isVisible]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [alertController presentWithViewController:viewController sourceView:nil sourceRect:CGRectNull barButtonItem:nil animated:YES completion:nil];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [alertController presentWithAnimated:YES];
                });
            }
        } else if (responseStatusCode == 403) {
            // Session not found, or even the user of the session not exists

            // delete the current session id so the Settings > 'Sign In' shows

            [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

            NSString *errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Session not found. Go login", @""), NSLocalizedString(@"Settings", @""), NSLocalizedString(@"Login", @"")];

            [Utility viewController:viewController alertWithMessageTitle:@"" messageBody:errorMessage actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
        } else if (responseStatusCode == 501 || responseStatusCode == 460) {
            // no such connect computer. the computer can't be found by the computer id.

            NSString *errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Computer not exits. Go to find other computers", @""), NSLocalizedString(@"Settings", @""), NSLocalizedString(@"Current Computer", @"")];

            [Utility viewController:viewController alertWithMessageTitle:@"" messageBody:errorMessage actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
        } else if (responseStatusCode == 465) {
            // the version of device is newer than of desktop

            NSString *errorMessage = NSLocalizedString(@"desktop.need.upgrade2", @"");

            [Utility viewController:viewController alertWithMessageTitle:@"" messageBody:errorMessage actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
        } else if (responseStatusCode == 466) {
            // the version of desktop is newer than of device

            NSString *errorMessage = [NSString stringWithFormat:NSLocalizedString(@"device.need.update2", @"")];

            [Utility viewController:viewController alertWithMessageTitle:@"" messageBody:errorMessage actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
        } else if (!lugServerId || responseStatusCode == 504 || responseStatusCode == 503 || [error code] == NSURLErrorTimedOut) {
            // NSURLErrorTimeOut 是因為網路太慢，連線到 server 前或者 server 回覆前就 timeout
            // 504 原因是 socket connection 存在也未過期，但是就是無法從 server 連到 desktop 導致 timeout。
            // 例如：desktop 程式有錯誤導致無限迴圈，使得 server 一直收不到 desktop 的回應。
            // 由於 server 回傳 504 前會先要求 desktop 重新建立連線，因此 client 收到 504 後也應該提供重試的選項。
            // 至於 503 的錯誤，由於調用此 method 前通常已經針對 503 的情況處理，只有少數會在這裡才處理，因此不再 request connect，
            // 而是簡單詢問是否重試即可。
            // 由於之前幾個 status 回傳時，lugServerId 也可能不存在，為避免顯示不出實際錯誤，將此區至於倒數第二。

            NSString *computerName = [userDefaults stringForKey:USER_DEFAULTS_KEY_COMPUTER_NAME];

            NSString *messageSuffix;
            if (computerName && [computerName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
                messageSuffix = [NSString stringWithFormat:NSLocalizedString(@"Connection Busy", @""), computerName];
            } else {
                messageSuffix = NSLocalizedString(@"Connection Busy2", @"");
            }

            NSString *errorMessage;

            if (messagePrefix && messagePrefix.length > 0) {
                errorMessage = [messagePrefix stringByAppendingFormat:@"\n%@", messageSuffix];
            } else {
                errorMessage = messageSuffix;
            }

            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:errorMessage preferredStyle:UIAlertControllerStyleAlert];

            if (tryAgainAction) {
                [alertController addAction:tryAgainAction];
            }

            UIAlertAction *tryLaterAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Later", @"") style:UIAlertActionStyleCancel handler:nil];
            [alertController addAction:tryLaterAction];

            if ([viewController isVisible]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [alertController presentWithViewController:viewController sourceView:nil sourceRect:CGRectNull barButtonItem:nil animated:YES completion:nil];
//                    [viewController presentViewController:alertController animated:YES completion:nil];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [alertController presentWithAnimated:YES];
                });
            }
        } else {
            NSString *errorMessage = [Utility messageWithMessagePrefix:messagePrefix statusCode:responseStatusCode error:error data:data];

            [Utility viewController:viewController alertWithMessageTitle:@"" messageBody:errorMessage actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
        }
    }
}

///**
// * UserWithoutManaged is used to take countryId, phoneNumber, password and maybe others in the future,
// * and combined with nickname and email in the received response data to create or update in the local db.
// *
// * If UserWithoutManaged is not nil, create or update user before user-computer.
// * If response message without lug-server-id, the current lug_server_id in userdefaults will be removed.
// */
//- (void)saveLoginData:(NSData *)data encryptedPassword:(NSString *)encryptedPassword showHidden:(NSNumber *)showHidden error:(NSError * __autoreleasing *)error {
//    if (data) {
//        NSError *parseError;
//        NSDictionary *responseDictionary = [Utility parseJsonAsDictionaryFromData:data error:&parseError];
//
//        if (!parseError) {
//            NSString *responseUserId = responseDictionary[@"account"];
//            NSString *responseNickname = responseDictionary[@"nickname"];
//            NSString *responseCountryId = responseDictionary[@"country-id"];
//            NSString *responsePhoneNumber = responseDictionary[@"phone"];
//
//            // Saved showHidden to UserComputer
//            // Save userShowHidden to User
////            NSNumber *userShowHidden = responseDictionary[@"showHidden"];
//
//            NSString *responseEmail = responseDictionary[@"email"];
//            NSString *responseSessionId = responseDictionary[@"sessionId"];
//
//            NSNumber *responseComputerId = responseDictionary[@"computer-id"];
//            NSString *responseComputerAdminId = responseDictionary[@"computer-admin-id"];
//            NSString *responseComputerGroup = responseDictionary[@"computer-group"];
//            NSString *responseComputerName = responseDictionary[@"computer-name"];
//            NSString *responseLugServerId = responseDictionary[@"lug-server-id"];
//
//            //* upload summary
//
//            NSString *responseUploadDirectory = responseDictionary[@"upload-directory"];
//            NSNumber *responseUploadSubdirectoryType = responseDictionary[@"upload-subdirectory-type"];
//            NSString *responseUploadSubdirectoryValue = responseDictionary[@"upload-subdirectory-value"];
//            NSNumber *responseUploadDescriptionType = responseDictionary[@"upload-description-type"];
//            NSString *responseUploadDescriptionValue = responseDictionary[@"upload-description-value"];
//            NSNumber *responseUploadNotificationType = responseDictionary[@"upload-notification-type"];
//
//            //* download summary: only notification type is useful for Filelug iOS, the rest of these are for Filelug Android
//
////            NSString *responseDownloadDirectory = responseDictionary[@"download-directory"];
////            NSNumber *responseDownloadSubdirectoryType = responseDictionary[@"download-subdirectory-type"];
////            NSString *responseDownloadSubdirectoryValue = responseDictionary[@"download-subdirectory-value"];
////            NSNumber *responseDownloadDescriptionType = responseDictionary[@"download-description-type"];
////            NSString *responseDownloadDescriptionValue = responseDictionary[@"download-description-value"];
//
//            NSNumber *responseDownloadNotificationType = responseDictionary[@"download-notification-type"];
//
//            // replace nil with default, not current one because the current one may come from another user computer.
//
//            NSUserDefaults *userDefaults = [Utility groupUserDefaults];
//
//            if (!responseUploadSubdirectoryType) {
//                responseUploadSubdirectoryType = @([UploadSubdirectoryService defaultType]);
//            }
//
//            if (!responseUploadDescriptionType) {
//                responseUploadDescriptionType = @([UploadDescriptionService defaultType]);
//            }
//
//            if (!responseUploadNotificationType) {
//                responseUploadNotificationType = @([UploadNotificationService defaultType]);
//            }
//
//            if (!responseDownloadNotificationType) {
//                responseDownloadNotificationType = @([DownloadNotificationService defaultType]);
//            }
//
//            NSString *userComputerId = [UserComputerWithoutManaged userComputerIdFromUserId:responseUserId computerId:responseComputerId];
//
//            /* create or update user and then user-computer in local db,
//             * NOTE: user first, then user-computer
//             */
//
//            [self createOrUpdateUserWithUserId:responseUserId nickname:responseNickname countryId:responseCountryId phoneNumber:responsePhoneNumber sessionId:responseSessionId email:responseEmail error:error];
//
//            UserComputerWithoutManaged *userComputerWithoutManaged = [[UserComputerWithoutManaged alloc] initWithUserId:responseUserId
//                                                                                                         userComputerId:userComputerId
//                                                                                                             computerId:responseComputerId
//                                                                                                        computerAdminId:responseComputerAdminId
//                                                                                                          computerGroup:responseComputerGroup
//                                                                                                           computerName:responseComputerName
//                                                                                                             showHidden:showHidden
//                                                                                                        uploadDirectory:responseUploadDirectory
//                                                                                                 uploadSubdirectoryType:responseUploadSubdirectoryType
//                                                                                                uploadSubdirectoryValue:responseUploadSubdirectoryValue
//                                                                                                  uploadDescriptionType:responseUploadDescriptionType
//                                                                                                 uploadDescriptionValue:responseUploadDescriptionValue
//                                                                                                 uploadNotificationType:responseUploadNotificationType
//                                                                                                      downloadDirectory:nil
//                                                                                               downloadSubdirectoryType:nil
//                                                                                              downloadSubdirectoryValue:nil
//                                                                                                downloadDescriptionType:nil
//                                                                                               downloadDescriptionValue:nil
//                                                                                               downloadNotificationType:responseDownloadNotificationType];
//
//            [self.userComputerDao createOrUpdateUserComputerFromUserComputerWithoutManaged:userComputerWithoutManaged completionHandler:^(NSError *updateError) {
//                if (updateError) {
//                    if (error) {
//                        *error = updateError;
//                    } else {
//                        NSLog(@"Failed to create/update user computer.\n%@", [updateError userInfo]);
//                    }
//
//                    NSLog(@"Error on updating the computer admin id: %@, computer group: %@, and computer name: %@ of the user computer with id: %@\n%@", responseComputerAdminId, responseComputerGroup, responseComputerName, userComputerId, [updateError userInfo]);
//                }
//            }];
//
//            /* save to preferences */
//
//            [userDefaults setObject:responseUserId forKey:USER_DEFAULTS_KEY_USER_ID];
//            [userDefaults setObject:responseCountryId forKey:USER_DEFAULTS_KEY_COUNTRY_ID];
//            [userDefaults setObject:responsePhoneNumber forKey:USER_DEFAULTS_KEY_PHONE_NUMBER];
//            [userDefaults setObject:responseNickname forKey:USER_DEFAULTS_KEY_NICKNAME];
//            [userDefaults setObject:responseSessionId forKey:USER_DEFAULTS_KEY_USER_SESSION_ID];
//
////            // ALSO save session id to USER_DEFAULTS_KEY_USER_SESSION_ID2
////            [userDefaults setObject:responseSessionId forKey:USER_DEFAULTS_KEY_USER_SESSION_ID2];
//
////            // remain the password in preferences if encryptedPassword is nil or empty
////            if (encryptedPassword && [encryptedPassword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
////                [userDefaults setObject:encryptedPassword forKey:USER_DEFAULTS_KEY_PASSWORD];
////            }
//
//            // if email is nil, remove it in the preference
//            if (responseEmail && [responseEmail stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
//                [userDefaults setObject:responseEmail forKey:USER_DEFAULTS_KEY_USER_EMAIL];
//            } else {
//                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_USER_EMAIL];
//            }
//
//            // computer-related
//            [userDefaults setObject:responseComputerId forKey:USER_DEFAULTS_KEY_COMPUTER_ID];
//            [userDefaults setObject:responseComputerAdminId forKey:USER_DEFAULTS_KEY_COMPUTER_ADMIN_ID];
//            [userDefaults setObject:responseComputerGroup forKey:USER_DEFAULTS_KEY_COMPUTER_GROUP];
//            [userDefaults setObject:responseComputerName forKey:USER_DEFAULTS_KEY_COMPUTER_NAME];
//            [userDefaults setObject:userComputerId forKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];
//            [userDefaults setBool:[showHidden boolValue] forKey:USER_DEFAULTS_KEY_SHOW_HIDDEN];
//
//            /* leave the old value if no updated lug-server-id received. */
//            if (responseLugServerId) {
//                [userDefaults setObject:responseLugServerId forKey:USER_DEFAULTS_KEY_LUG_SERVER_ID];
//            }
//
//            [userDefaults setObject:responseDictionary[@"file.encoding"] forKey:USER_DEFAULTS_KEY_SERVER_FILE_ENCODING];
//            [userDefaults setObject:responseDictionary[@"file.separator"] forKey:USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR];
//            [userDefaults setObject:responseDictionary[@"path.separator"] forKey:USER_DEFAULTS_KEY_SERVER_PATH_SEPARATOR];
//            [userDefaults setObject:responseDictionary[@"line.separator"] forKey:USER_DEFAULTS_KEY_SERVER_LINE_SEPARATOR];
//            [userDefaults setObject:responseDictionary[@"java.io.tmpdir"] forKey:USER_DEFAULTS_KEY_SERVER_TEMP_DIRECTORY];
//            [userDefaults setObject:responseDictionary[@"user.country"] forKey:USER_DEFAULTS_KEY_SERVER_USER_COUNTRY];
//            [userDefaults setObject:responseDictionary[@"user.dir"] forKey:USER_DEFAULTS_KEY_SERVER_USER_DIRECTORY];
//            [userDefaults setObject:responseDictionary[@"user.home"] forKey:USER_DEFAULTS_KEY_SERVER_USER_HOME];
//            [userDefaults setObject:responseDictionary[@"user.language"] forKey:USER_DEFAULTS_KEY_SERVER_USER_LANGUAGE];
//            [userDefaults setObject:responseDictionary[@"desktop.version"] forKey:USER_DEFAULTS_KEY_DESKTOP_VERSION];
//
//            // Upload Summary - save to preference for current user-computer
//
//            [userDefaults setObject:responseUploadDirectory forKey:USER_DEFAULTS_KEY_UPLOAD_DIRECTORY];
//            [userDefaults setObject:responseUploadSubdirectoryType forKey:USER_DEFAULTS_KEY_UPLOAD_SUBDIRECTORY_TYPE];
//            [userDefaults setObject:responseUploadSubdirectoryValue forKey:USER_DEFAULTS_KEY_UPLOAD_SUBDIRECTORY_VALUE];
//            [userDefaults setObject:responseUploadDescriptionType forKey:USER_DEFAULTS_KEY_UPLOAD_DESCRIPTION_TYPE];
//            [userDefaults setObject:responseUploadDescriptionValue forKey:USER_DEFAULTS_KEY_UPLOAD_DESCRIPTION_VALUE];
//            [userDefaults setObject:responseUploadNotificationType forKey:USER_DEFAULTS_KEY_UPLOAD_NOTIFICATION_TYPE];
//
//            // remove first root directory real path
//            [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_FIRST_ROOT_DIRECTORY];
//
//            // Download Summary - save to preference as temp values for current user-computer
//            // only notification type is useful for Filelug iOS, the rest of these are for Filelug Android
//
//            [userDefaults setObject:responseDownloadNotificationType forKey:USER_DEFAULTS_KEY_DOWNLOAD_NOTIFICATION_TYPE];
//
//            [userDefaults synchronize];
//        } else {
//            if (error) {
//                *error = parseError;
//            } else {
//                NSLog(@"Failed to save login data.\n%@", [parseError userInfo]);
//            }
//        }
//    } else {
//        NSLog(@"[saveLoginData] Error: Data is nil.");
//    }
//}

- (void)saveLoginWithSessionIdResponseData:(NSData *)data encryptedPassword:(NSString *)encryptedPassword error:(NSError * __autoreleasing *)error {
    if (data) {
        NSError *parseError;
        NSDictionary *dictionary = [Utility parseJsonAsDictionaryFromData:data error:&parseError];

        if (parseError == nil) {
            /*
            { 
                "country-id" : "TW", 
                "country-code" : 886, 
                "phone" : "975009123", // 號碼不在前面加上 '0' 
                "phone-with-country" : "+886975009123", 
                "account" : "9aaa3acb5b3f905b994ea16783fc340", 
                "oldSessionId": "3420CD377BAAF4BD59BCB6B3668C81", 
                "newSessionId": “3420CD377BAAF4BD59BCB6B3668C82", 
                "need-create-or-update-user-profile" : true, 
                "nickname" : "Wickie", 
                "email" : "wickie@example.com" ,
                "email-is-verified" : false
            }
             */

            NSUserDefaults *userDefaults = [Utility groupUserDefaults];

            NSNumber *needCreateOrUpdateUserProfile = dictionary[@"need-create-or-update-user-profile"];

            NSString *countryId = dictionary[@"country-id"];
            NSNumber *countryCode = dictionary[@"country-code"];
            NSString *phoneNumber = dictionary[@"phone"];
            NSString *phoneNumberWithCountry = dictionary[@"phone-with-country"];
            NSString *userId = dictionary[@"account"];
//            NSString *oldSessionId = dictionary[@"oldSessionId"];
            NSString *newSessionId = dictionary[@"newSessionId"];
            NSString *nickname = dictionary[@"nickname"];
            NSString *email = dictionary[@"email"];
            NSNumber *emailIsVerified = dictionary[@"email-is-verified"];

            // create or update user in local db

            [self createOrUpdateUserWithUserId:userId nickname:nickname countryId:countryId phoneNumber:phoneNumber sessionId:newSessionId email:email error:error];

            NSString *oldUserId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_ID];

            // If user account changed to another one and the new user account has no computer ever connected,
            // delete the computer-related preferences and the session(1) preference.

            if (oldUserId && ![oldUserId isEqualToString:userId]) {
                // computer-related
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_COMPUTER_ID];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_COMPUTER_ADMIN_ID];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_COMPUTER_GROUP];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_COMPUTER_NAME];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SHOW_HIDDEN];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID];

                // desktop-related
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_FILE_ENCODING];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_PATH_SEPARATOR];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_LINE_SEPARATOR];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_TEMP_DIRECTORY];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_USER_COUNTRY];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_USER_DIRECTORY];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_USER_HOME];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_USER_LANGUAGE];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_DESKTOP_VERSION];
            }

            // Update preferences with this user

            [userDefaults setObject:userId forKey:USER_DEFAULTS_KEY_USER_ID];
            [userDefaults setObject:countryId forKey:USER_DEFAULTS_KEY_COUNTRY_ID];
            [userDefaults setObject:countryCode forKey:USER_DEFAULTS_KEY_COUNTRY_CODE];
            [userDefaults setObject:phoneNumber forKey:USER_DEFAULTS_KEY_PHONE_NUMBER];
            [userDefaults setObject:phoneNumberWithCountry forKey:USER_DEFAULTS_KEY_PHONE_NUMBER_WITH_COUNTRY];
            [userDefaults setObject:newSessionId forKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

            // for optional returned values, set new one if not nil or remove the old one

            if (nickname && [nickname stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
                [userDefaults setObject:nickname forKey:USER_DEFAULTS_KEY_NICKNAME];
            } else {
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_NICKNAME];
            }

            if (email && [email stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
                [userDefaults setObject:email forKey:USER_DEFAULTS_KEY_USER_EMAIL];
            } else {
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_USER_EMAIL];
            }

            if (emailIsVerified) {
                [userDefaults setObject:emailIsVerified forKey:USER_DEFAULTS_KEY_USER_EMAIL_IS_VERIFIED];
            } else {
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_USER_EMAIL_IS_VERIFIED];
            }

            [userDefaults setObject:@(needCreateOrUpdateUserProfile && [needCreateOrUpdateUserProfile boolValue]) forKey:USER_DEFAULTS_KEY_NEED_CREATE_OR_UPDATE_USER_PROFILE];

            [userDefaults synchronize];
        } else {
            if (error) {
                *error = parseError;
            } else {
                NSLog(@"Failed to save login data.\n%@", [parseError userInfo]);
            }
        }
    } else {
        NSLog(@"Error on invoking [saveLoginWithSessionIdResponseData]: data is nil.");
    }
}

//// The password is not in the resposne data, so the encryptedPassword is updated to local db and preferences.
//// Skip updating password if encryptedPassword is nil or empty.
//- (void)saveLoginOnlyData:(NSData *)data encryptedPassword:(NSString *)encryptedPassword error:(NSError * __autoreleasing *)error {
//    if (data) {
//        NSError *parseError;
//        NSDictionary *responseDictionary = [Utility parseJsonAsDictionaryFromData:data error:&parseError];
//
//        if (parseError == nil) {
//            NSString *responseUserId = responseDictionary[@"account"];
//            NSString *responseNickname = responseDictionary[@"nickname"];
//            NSString *responseCountryId = responseDictionary[@"country-id"];
//            NSString *responsePhoneNumber = responseDictionary[@"phone"];
//            NSString *responseEmail = responseDictionary[@"email"];
//            NSString *responseSessionId = responseDictionary[@"sessionId"];
//
//            // create or update user in local db
//
//            [self createOrUpdateUserWithUserId:responseUserId nickname:responseNickname countryId:responseCountryId phoneNumber:responsePhoneNumber sessionId:responseSessionId email:responseEmail error:error];
//
//            NSUserDefaults *userDefaults = [Utility groupUserDefaults];
//
//            // Update preferences with this user
//
//            // session(1)
//            [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];
//
//            // if the original user id not nil and not the same with the new one,
//            // delete user-computer related user defaults keys
//
//            NSString *oldUserId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_ID];
//
//            // If user account changed to another one and the new user account has no computer ever connected,
//            // delete the computer-related preferences and the session(1) preference.
//
//            if (oldUserId && ![oldUserId isEqualToString:responseUserId]) {
//                // computer-related
//                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_COMPUTER_ID];
//                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_COMPUTER_ADMIN_ID];
//                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_COMPUTER_GROUP];
//                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_COMPUTER_NAME];
//                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];
//                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SHOW_HIDDEN];
//                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID];
//
//                // desktop-related
//                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_FILE_ENCODING];
//                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR];
//                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_PATH_SEPARATOR];
//                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_LINE_SEPARATOR];
//                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_TEMP_DIRECTORY];
//                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_USER_COUNTRY];
//                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_USER_DIRECTORY];
//                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_USER_HOME];
//                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_USER_LANGUAGE];
//                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_DESKTOP_VERSION];
//            }
//
//            [userDefaults setObject:responseUserId forKey:USER_DEFAULTS_KEY_USER_ID];
//            [userDefaults setObject:responseCountryId forKey:USER_DEFAULTS_KEY_COUNTRY_ID];
//            [userDefaults setObject:responsePhoneNumber forKey:USER_DEFAULTS_KEY_PHONE_NUMBER];
//            [userDefaults setObject:responseNickname forKey:USER_DEFAULTS_KEY_NICKNAME];
//
//            [userDefaults setObject:responseSessionId forKey:USER_DEFAULTS_KEY_USER_SESSION_ID];
//
////            // remain the password in preferences if encryptedPassword is nil or empty
////            if (encryptedPassword && [encryptedPassword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
////                [userDefaults setObject:encryptedPassword forKey:USER_DEFAULTS_KEY_PASSWORD];
////            }
//
//            // if email is nil, remove it in the preference
//            if (responseEmail && [responseEmail stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
//                [userDefaults setObject:responseEmail forKey:USER_DEFAULTS_KEY_USER_EMAIL];
//            } else {
//                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_USER_EMAIL];
//            }
//
//            [userDefaults synchronize];
//        } else {
//            if (error) {
//                *error = parseError;
//            } else {
//                NSLog(@"Failed to save login data.\n%@", [parseError userInfo]);
//            }
//        }
//    } else {
//        NSLog(@"[saveLoginOnlyData] Error: Data is nil.");
//    }
//}

- (void)createOrUpdateUserWithUserId:(NSString *)userId nickname:(NSString *)nickname countryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber sessionId:(NSString *)sessionId email:(NSString *)email error:(NSError * __autoreleasing *)error {
    NSError *foundError;
    UserWithoutManaged *userWithoutManaged = [self.userDao findUserWithoutManagedById:userId error:&foundError];
    
    if (userWithoutManaged) {
        // Nickname, country id, phone number and email should be replaced with the value from reponse data.
        userWithoutManaged.nickname = nickname;
        userWithoutManaged.countryId = countryId;
        userWithoutManaged.phoneNumber = phoneNumber;
        userWithoutManaged.sessionId = sessionId;
        userWithoutManaged.email = email;
        userWithoutManaged.active = @YES;
    } else {
        userWithoutManaged = [[UserWithoutManaged alloc] initWithUserId:userId countryId:countryId phoneNumber:phoneNumber sessionId:sessionId nickname:nickname email:email active:@YES locale:nil];
    }
    
    [self.userDao createOrUpdateUserWithUserWithoutManaged:userWithoutManaged completionHandler:^(NSError *userError) {
        if (userError) {
            if (error) {
                *error = userError;
            }
            
            NSLog(@"Error on creating/updating the user: %@\n%@", [userWithoutManaged description], [userError userInfo]);
        }
    }];
}

- (void)saveRequestConnectData:(NSData *)data error:(NSError * __autoreleasing *)error {
    if (data) {
        NSError *jsonError = nil;
        NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];

        if (jsonError) {
            if (error) {
                *error = jsonError;
            } else {
                NSLog(@"Failed to save request connect data.\n%@", [jsonError userInfo]);
            }
        } else {
            // Update the computerid, computer group, computer name and lug server id in user defatuls
            
            NSUserDefaults *userDefaults = [Utility groupUserDefaults];

            NSString *userComputerId = jsonObject[@"user-computer-id"];
            NSString *userId = jsonObject[@"user-id"];
            NSNumber *computerId = jsonObject[@"computer-id"];
            NSString *computerAdminId = jsonObject[@"computer-admin-id"];
            NSString *computerGroup = jsonObject[@"computer-group"];
            NSString *computerName = jsonObject[@"computer-name"];
            NSString *lugServerId = jsonObject[@"lug-server-id"];
            
            if (userComputerId && userId && computerId && computerAdminId && computerGroup && computerName) {
                [userDefaults setObject:userComputerId forKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];
                [userDefaults setObject:userId forKey:USER_DEFAULTS_KEY_USER_ID];
                [userDefaults setObject:computerId forKey:USER_DEFAULTS_KEY_COMPUTER_ID];
                [userDefaults setObject:computerAdminId forKey:USER_DEFAULTS_KEY_COMPUTER_ADMIN_ID];
                [userDefaults setObject:computerGroup forKey:USER_DEFAULTS_KEY_COMPUTER_GROUP];
                [userDefaults setObject:computerName forKey:USER_DEFAULTS_KEY_COMPUTER_NAME];
                
                // optional
                if (lugServerId) {
                    [userDefaults setObject:lugServerId forKey:USER_DEFAULTS_KEY_LUG_SERVER_ID];
                }
                
                // get showHidden from preferences
                NSNumber *showHidden = [userDefaults objectForKey:USER_DEFAULTS_KEY_SHOW_HIDDEN];
                
                if (!showHidden) {
                    showHidden = @(NO);
                }
                
                // Update the computer group, computer name with the user computer id in local db
                
                UserComputerWithoutManaged *userComputerWithoutManaged = [[UserComputerWithoutManaged alloc] initWithUserId:userId userComputerId:userComputerId computerId:computerId computerAdminId:computerAdminId computerGroup:computerGroup computerName:computerName showHidden:showHidden];
                
                [self.userComputerDao updateUserComputerWithUserComputerWithoutManaged:userComputerWithoutManaged completionHandler:nil];
            } else {
                // prompt data integrity

                NSError *dataIntegrityError = [Utility errorWithErrorCode:ERROR_CODE_DATA_INTEGRITY_KEY localizedDescription:NSLocalizedString(@"Incorrect response data", @"")];

                if (error) {
                    *error = dataIntegrityError;
                } else {
                    NSLog(@"Failed to save request connect data.\n%@", [dataIntegrityError userInfo]);
                }
                
                NSLog(@"[saveRequestConnectData]: Data integrity. userComputerId: %@, userId: %@, computerId: %@, computerAdminId: %@, computerGroup: %@, computerName: %@", userComputerId, userId, computerId, computerAdminId, computerGroup, computerName);
            }
        }
    } else {
        NSLog(@"[saveRequestConnectData]: Nil data.");
    }
}

- (void)findAvailableTransmissionCapacityWithSession:(NSString *)sessionId completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))handler {
    NSString *urlString = [Utility composeAAServerURLStringWithPath:@"user/tcapacity"];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
    
    [request setHTTPMethod:@"POST"];
    
    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
}

- (void)changeNickname:(NSString *)newNickname session:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    NSString *urlString = [Utility composeAAServerURLStringWithPath:@"user/nickname"];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
    
    [request setHTTPMethod:@"POST"];
    
    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];
    
    NSString *bodyString = [NSString stringWithFormat:@"{\"new-nickname\" : \"%@\"}", newNickname];
    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
}

- (void)changeEmailWithSession:(NSString *)sessionId newEmail:(NSString *)newEmail encryptedSecurityCode:(NSString *)encryptedSecurityCode completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    NSString *urlString = [Utility composeAAServerURLStringWithPath:@"user/change-email"];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
    
    [request setHTTPMethod:@"POST"];
    
    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];
    
    NSString *bodyString = [NSString stringWithFormat:@"{\"code\" : \"%@\", \"new-email\" : \"%@\"}", encryptedSecurityCode, newEmail];
    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
}

- (void)deleteUserWithSession:(NSString *)sessionId userId:(NSString *)userId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    NSError *foundError;
    UserWithoutManaged *userWithoutManaged = [self.userDao findUserWithoutManagedById:userId error:&foundError];
    
    if (userWithoutManaged) {
        NSString *verification = [UserWithoutManaged generateVerificationFromUserId:userId nickname:userWithoutManaged.nickname session:sessionId];
        
        NSString *urlString = [Utility composeAAServerURLStringWithPath:@"user/delete2"];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
        
        [request setHTTPMethod:@"POST"];
        
        [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];
        
        NSUserDefaults *userDefaults = [Utility groupUserDefaults];
        NSString *applicationLocale = [userDefaults stringForKey:USER_DEFAULTS_KEY_MAIN_APP_LOCALE];
        
        NSString *bodyString = [NSString stringWithFormat:@"{\"account\" : \"%@\", \"verification\" : \"%@\", \"locale\" : \"%@\"}", userId, verification, applicationLocale];
        [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        
        [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
    } else {
        NSLog(@"User not found for id: %@", userId);
    }
}

- (void)sendChangeEmailCodeWithSession:(NSString *)sessionId newEmail:(NSString *)newEmail completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    NSString *urlString = [Utility composeAAServerURLStringWithPath:@"user/change-email-code"];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
    
    [request setHTTPMethod:@"POST"];
    
    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];
    
    NSString *bodyString = [NSString stringWithFormat:@"{\"new-email\":\"%@\"}", newEmail];
    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/json; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
}

- (void)checkIfUserDeletableWithSession:(NSString *)sessionId userId:(NSString *)userId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    NSError *foundError;
    UserWithoutManaged *userWithoutManaged = [self.userDao findUserWithoutManagedById:userId error:&foundError];
    
    if (userWithoutManaged) {
        NSString *urlString = [Utility composeAAServerURLStringWithPath:@"user/check-deletable"];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
        
        [request setHTTPMethod:@"POST"];
        
        [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];
        
        NSUserDefaults *userDefaults = [Utility groupUserDefaults];
        NSString *applicationLocale = [userDefaults stringForKey:USER_DEFAULTS_KEY_MAIN_APP_LOCALE];
        
        NSString *bodyString = [NSString stringWithFormat:@"{\"account\" : \"%@\", \"locale\" : \"%@\"}", userId, applicationLocale];
        [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        
        [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
    } else {
        NSLog(@"User not found for id: %@", userId);
    }
}

- (void)updateAllUsersWithDeviceToken:(NSString *)deviceToken session:(NSString *)sessionId completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *connectionError))handler {
    NSError *foundError;
    NSArray *allUsers = [self.userDao findAllUsersWithSortByActive:YES error:&foundError];
    NSUInteger userCount = [allUsers count];
    
    if (!foundError && userCount > 0) {
        NSString *urlString = [Utility composeAAServerURLStringWithPath:@"user/device-token"];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
        
        [request setHTTPMethod:@"POST"];
        
        [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];
        
        // body
        
        /* sample
         
         {
         "sessions" :
         [
         "3420CD377BAAF1B7BEDC52C374DF4BD5F9699A0D5DFAD204BD59BCB6B3668C81",
         "ADC3420CD37C81D5F9699A4DFAF1B77B52C3768BE4BD204BD59BCB6B360D5DFA"
         ],
         
         "device-token":
         {
         "device-token" : "1e39b345af9b036a2fc1066f2689143746f7d1220c23ff1491619a544a167c61",
         "notification-type" : "APNS",
         "device-type" : "IOS",
         "device-version" : "8.3",
         "filelug-version" : "1.1.7",
         "filelug-build" : "2015.09.22.01",
         "badge-number" : 0
         }
         }
         */
        
        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSMutableString *bodyString = [NSMutableString stringWithString:@"{\"sessions\":["];
        
        [bodyString appendFormat:@"\"%@\"", sessionId];
        
        NSString *sessionId1 = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];
        
        if (sessionId1 && ![sessionId1 isEqualToString:sessionId]) {
            [bodyString appendFormat:@",\"%@\"", sessionId1];
        }

        NSString *filelugVersion = [userDefaults objectForKey:USER_DEFAULTS_KEY_MAIN_APP_VERSION];

        NSString *filelugBuild = [userDefaults objectForKey:USER_DEFAULTS_KEY_MAIN_APP_BUILD_NO];
        
        [bodyString appendFormat:@"], \"device-token\":{\"device-token\":\"%@\",\"notification-type\":\"%@\",\"device-type\":\"%@\",\"device-version\":\"%@\",\"filelug-version\":\"%@\",\"filelug-build\":\"%@\",\"badge-number\" : %d}}", deviceToken, DEVICE_TOKEN_NOTIFICATION_TYPE_APNS, DEVICE_TOKEN_DEVICE_TYPE_IOS, DEVICE_VERSION, filelugVersion, filelugBuild, 0];
        
        [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
        [request setValue:@"application/json; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
        
        [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
    } else {
        if (foundError) {
            NSLog(@"Error on finding users.\n%@", [foundError userInfo]);
        } else {
            NSLog(@"No saved user to update the device token.");
        }
    }
}

- (void)incrementBadgeNumber:(NSInteger)incrementBadgeNumber withSession:(NSString *)sessionId deviceToken:(NSString *)deviceToken userId:(NSString *)userId completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *connectionError))handler {
    NSString *urlString = [Utility composeAAServerURLStringWithPath:@"user/badge-number"];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
    
    [request setHTTPMethod:@"POST"];
    
    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];
    
    // body
    NSString *bodyString = [NSString stringWithFormat:@"[{\"device-token\" : \"%@\", \"increment-badge-number\" : %ld, \"account\" : \"%@\"}]", deviceToken, (long)incrementBadgeNumber, userId];
    
    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/json; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
}

- (void)clearBadgeNumberWithSession:(NSString *)sessionId deviceToken:(NSString *)deviceToken userId:(NSString *)userId completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *connectionError))handler {
    NSString *urlString = [Utility composeAAServerURLStringWithPath:@"user/clear-badge-number"];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
    
    [request setHTTPMethod:@"POST"];
    
    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];
    
    // body
    NSString *bodyString = [NSString stringWithFormat:@"[{\"device-token\" : \"%@\", \"account\" : \"%@\"}]", deviceToken, userId];
    
    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/json; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
}

- (void)exchangeAccessTokenWithAuthorizationCode:(NSString *)authorizationCode successHandler:(void (^)(NSString *countryId, NSString *phoneNumber))successHandler failureHandler:(void (^)(NSURLResponse *, NSData *, NSError *))failureHandler {
    NSString *urlString = [Utility composeAAServerURLStringWithPath:@"user/tokenac"];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];

    [request setHTTPMethod:@"POST"];

    // body
    /*
     {
        "code" : "JFOEINFIUGFEKFHIOJDN1O9UW9027984758409U589I43NJTRUFIE7YFH3I4U7TREOWIR09IWEKML",
        "locale" : "zh_TW",
        "verification" : "bf94b4d1c5305b5b3f96abdab89eba05b994ea10a249aaa3acb28aa13533040cc4b24"
     }
     */

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];
    NSString *applicationLocale = [userDefaults stringForKey:USER_DEFAULTS_KEY_MAIN_APP_LOCALE];
    NSString *verification = [Utility generateVerificationWithAuthorizationCode:authorizationCode locale:applicationLocale];

    NSString *bodyString = [NSString stringWithFormat:@"{\"code\" : \"%@\", \"locale\" : \"%@\", \"verification\" : \"%@\"}", authorizationCode, applicationLocale, verification];

    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/json; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];

    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

        if (statusCode == 200) {
            /*
             {
                "country-id" : "TW", 
                "country-code" : 886, 
                "phone" : "975009123", 
                "phone-with-country" : "+886975009123",
                "verification" : "QWR98B4UBNNMKODQGHJ3O92MFHG6DPQMUFTHSBVMJUYGG7SNMKS1JCNYE5JME4D8S9O7V2M0"
             }
             */

            NSError *parseError;
            NSDictionary *dictionary = [Utility parseJsonAsDictionaryFromData:data error:&parseError];

            if (parseError) {
                failureHandler(response, data, parseError);
            } else {
                NSString *countryId = dictionary[@"country-id"];
                NSString *phoneNumber = dictionary[@"phone"];
                NSString *responsVerification = dictionary[@"verification"];

                NSString *expectedResponseVerification = [Utility generateVerificationWithCountryId:countryId phoneNumber:phoneNumber];

                if (![expectedResponseVerification isEqualToString:responsVerification]) {
                    NSError *verificationError = [Utility errorWithErrorCode:ERROR_CODE_INCORRECT_VERIFICATION_KEY localizedDescription:NSLocalizedString(@"Incorrect value of verification", @"")];

                    failureHandler(response, data, verificationError);
                } else {
                    successHandler(countryId, phoneNumber);
                }
            }
        } else {
            // customized process

            failureHandler(response, data, error);
        }
    }] resume];
}

- (void)loginWithAuthorizationCode:(NSString *)code successHandler:(void (^)(NSURLResponse *, NSData *))successHandler failureHandler:(void (^)(NSURLResponse *, NSData *, NSError *))failureHandler {
    NSString *urlString = [Utility composeAAServerURLStringWithPath:@"user/loginac"];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];

    [request setHTTPMethod:@"POST"];

    // body

    NSString *encryptedAuthorizationCode = [code SHA256];

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];
    NSString *applicationLocale = [userDefaults stringForKey:USER_DEFAULTS_KEY_MAIN_APP_LOCALE];

    NSString *bodyString = [NSString stringWithFormat:@"{\"code\" : \"%@\", \"locale\" : \"%@\"}", encryptedAuthorizationCode, applicationLocale];

    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/json; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];

    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

        if (statusCode == 200) {
            // save response data

            NSError *parseError;
            [self saveLoginWithAuthorizationCodeWithData:data error:&parseError];

            // notify that other tab bar view controllers need to reload
            [userDefaults setBool:YES forKey:USER_DEFAULTS_KEY_RELOAD_MENU];
            [userDefaults setObject:@YES forKey:USER_DEFAULTS_KEY_NEED_RELOAD_DOWNLOAD_LIST];
            [userDefaults setObject:@YES forKey:USER_DEFAULTS_KEY_NEED_RELOAD_UPLOAD_LIST];

            if (!parseError) {
                // customized process

                successHandler(response, data);
            } else {
                // customized process

                failureHandler(response, data, parseError);
            }
        } else {
            // customized process

            failureHandler(response, data, error);
        }
    }] resume];
}

- (void)saveLoginWithAuthorizationCodeWithData:(NSData *)data error:(NSError * __autoreleasing *)error {
    if (data) {
        NSError *parseError;
        NSDictionary *dictionary = [Utility parseJsonAsDictionaryFromData:data error:&parseError];

        if (!parseError) {
            /*
            { 
                "country-id" : "TW", 
                "country-code" : 886, 
                "phone" : "975009123", // 號碼不在前面加上 '0' 
                "phone-with-country" : "+886975009123", 
                "account" : "9aaa3acb5b3f905b994ea16783fc340", 
                "sessionId": "3420CD377BAAF4BD59BCB6B3668C81", 
                "need-create-or-update-user-profile" : true, 
                "nickname" : "Wickie", 
                "email" : "wickie@example.com",
                "email-is-verified" : false
             }
             */

            NSNumber *needCreateOrUpdateUserProfile = dictionary[@"need-create-or-update-user-profile"];

            NSString *countryId = dictionary[@"country-id"];
            NSNumber *countryCode = dictionary[@"country-code"];
            NSString *phoneNumber = dictionary[@"phone"];
            NSString *phoneNumberWithCountry = dictionary[@"phone-with-country"];
            NSString *userId = dictionary[@"account"];
            NSString *sessionId = dictionary[@"sessionId"];

            NSString *nickname = dictionary[@"nickname"];
            NSString *email = dictionary[@"email"];
            NSNumber *emailIsVerified = dictionary[@"email-is-verified"];

            // create or update user in local db

            [self createOrUpdateUserWithUserId:userId nickname:nickname countryId:countryId phoneNumber:phoneNumber sessionId:sessionId email:email error:error];

            NSUserDefaults *userDefaults = [Utility groupUserDefaults];

            // Update preferences with this user

            // session(1)
            [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

            // if the original user id not nil and not the same with the new one,
            // delete user-computer related user defaults keys

            NSString *oldUserId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_ID];

            // If user account changed to another one and the new user account has no computer ever connected,
            // delete the computer-related preferences and the session(1) preference.

            if (oldUserId && ![oldUserId isEqualToString:userId]) {
                // computer-related
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_COMPUTER_ID];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_COMPUTER_ADMIN_ID];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_COMPUTER_GROUP];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_COMPUTER_NAME];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SHOW_HIDDEN];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID];

                // desktop-related
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_FILE_ENCODING];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_PATH_SEPARATOR];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_LINE_SEPARATOR];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_TEMP_DIRECTORY];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_USER_COUNTRY];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_USER_DIRECTORY];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_USER_HOME];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_USER_LANGUAGE];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_DESKTOP_VERSION];
            }

            [userDefaults setObject:userId forKey:USER_DEFAULTS_KEY_USER_ID];
            [userDefaults setObject:countryId forKey:USER_DEFAULTS_KEY_COUNTRY_ID];
            [userDefaults setObject:countryCode forKey:USER_DEFAULTS_KEY_COUNTRY_CODE];
            [userDefaults setObject:phoneNumber forKey:USER_DEFAULTS_KEY_PHONE_NUMBER];
            [userDefaults setObject:phoneNumberWithCountry forKey:USER_DEFAULTS_KEY_PHONE_NUMBER_WITH_COUNTRY];
            [userDefaults setObject:sessionId forKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

            // for optional returned values, set new one if not nil or remove the old one

            if (nickname && [nickname stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
                [userDefaults setObject:nickname forKey:USER_DEFAULTS_KEY_NICKNAME];
            } else {
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_NICKNAME];
            }

            if (email && [email stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
                [userDefaults setObject:email forKey:USER_DEFAULTS_KEY_USER_EMAIL];
            } else {
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_USER_EMAIL];
            }

            if (emailIsVerified) {
                [userDefaults setObject:emailIsVerified forKey:USER_DEFAULTS_KEY_USER_EMAIL_IS_VERIFIED];
            } else {
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_USER_EMAIL_IS_VERIFIED];
            }

            [userDefaults setObject:@(needCreateOrUpdateUserProfile && [needCreateOrUpdateUserProfile boolValue]) forKey:USER_DEFAULTS_KEY_NEED_CREATE_OR_UPDATE_USER_PROFILE];

            [userDefaults synchronize];
        } else {
            if (error) {
                *error = parseError;
            } else {
                NSLog(@"Failed to save login data:\n%@", [parseError userInfo]);
            }
        }
    } else {
        NSLog(@"Parameter data is nil for method: \"saveLoginWithAuthorizationCodeWithData:needCreateOrUpdateUserProfile:\"");
    }
}

- (void)createOrUpdateUserProfileWithEmail:(NSString *)email nickname:(NSString *)nickname session:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    NSString *urlString = [Utility composeAAServerURLStringWithPath:@"user/uprofile"];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];

    [request setHTTPMethod:@"POST"];

    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];

    NSString *bodyString = [NSString stringWithFormat:@"{\"email\" : \"%@\", \"nickname\" : \"%@\"}", email, nickname];
    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
}

- (void)checkNoRunningFileTransfersWithActionDisplayName:(NSString *)actionDisplayName inViewController:(UIViewController *)viewController completedHandler:(void(^)(void))handler {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *userComputerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

    if (userComputerId) {
        [self findUnfinishedFileTransferForUserComputer:userComputerId completionHandler:^(NSObject *file) {
            if (!file) {
                if (handler){
                    handler();
                }
            } else {
                [self viewController:viewController alertShouldNotChangeCurrentUserComputerWithFileObject:file titleSuffix:actionDisplayName];
            }
        }];
    } else {
        if (handler){
            handler();
        }
    }
}

- (void)viewController:(UIViewController *)viewController alertShouldNotChangeCurrentUserComputerWithFileObject:(id)fileObject titleSuffix:(nonnull NSString *)titleSuffix {
    NSString *title;
    NSString *message;

    if (fileObject) {
        if ([fileObject isKindOfClass:[FileTransferWithoutManaged class]]) {
            title = [NSString stringWithFormat:NSLocalizedString(@"Can't %@", @""), titleSuffix];

            NSString *filename = [DirectoryService filenameFromServerFilePath:((FileTransferWithoutManaged *) fileObject).serverPath];

            NSString *downloadingText = NSLocalizedString(@"downloading", @"");

            message = [NSString stringWithFormat:NSLocalizedString(@"File %@ not finished %@, try later", @""), filename, downloadingText, downloadingText, downloadingText];
        } else if ([fileObject isKindOfClass:[AssetFileWithoutManaged class]]) {
            title = [NSString stringWithFormat:NSLocalizedString(@"Can't %@", @""), titleSuffix];

            NSString *filename = ((AssetFileWithoutManaged *) fileObject).serverFilename;

            NSString *uploadingText = NSLocalizedString(@"uploading", @"");

            message = [NSString stringWithFormat:NSLocalizedString(@"File %@ not finished %@, try later", @""), filename, uploadingText, uploadingText, uploadingText];
        }

        if (title && message) {
            [Utility viewController:viewController alertWithMessageTitle:title messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
        }
    }
}

// file must be nil, type of FileTransferWithoutManaged, or AssetFileWithoutManaged
- (void)findUnfinishedFileTransferForUserComputer:(NSString *)userComputerId completionHandler:(void (^)(NSObject *))completionHandler {
    // find unfinished uploads and downloads

    FileTransferDao *fileTransferDao = [[FileTransferDao alloc] init];

    FileTransferWithoutManaged *unfinishedDownload = [fileTransferDao findOneUnfinishedDownloadForUserComputer:userComputerId error:NULL];

    if (!unfinishedDownload) {
        AssetFileDao *assetFileDao = [[AssetFileDao alloc] init];

        AssetFileWithoutManaged *unfinishedUpload = [assetFileDao findOneUnfinishedUploadForUserComputer:userComputerId error:NULL];

        // don't care if unfinishedFile exists
        completionHandler(unfinishedUpload);
    } else {
        completionHandler(unfinishedDownload);
    }
}

@end
