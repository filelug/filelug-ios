#import "UserComputerService.h"
#import "UserComputerWithoutManaged.h"
#import "Utility.h"
#import "NSString+Utlities.h"
#import "UploadSubdirectoryService.h"
#import "UploadDescriptionService.h"
#import "UploadNotificationService.h"
#import "DownloadNotificationService.h"
#import "UserComputerDao.h"
#import "UserWithoutManaged.h"
#import "FileTransferDao.h"
#import "FileTransferWithoutManaged.h"

@interface UserComputerService ()

@property(nonatomic, strong) UserComputerDao *userComputerDao;

@property(nonatomic, strong) FileTransferDao *fileTransferDao;

@end

@implementation UserComputerService {
}

- (id)initWithCachePolicy:(NSURLRequestCachePolicy)policy timeInterval:(NSTimeInterval)interval {
    if (self = [super init]) {
        _cachePolicy = policy;
        _timeInterval = interval;
    }

    return self;
}

- (UserComputerDao *)userComputerDao {
    if (!_userComputerDao) {
        _userComputerDao = [[UserComputerDao alloc] init];
    }

    return _userComputerDao;
}

- (FileTransferDao *)fileTransferDao {
    if (!_fileTransferDao) {
        _fileTransferDao = [[FileTransferDao alloc] init];
    }

    return _fileTransferDao;
}

- (void)findAvailableComputersWithSession:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    NSString *urlString = [Utility composeAAServerURLStringWithPath:@"computer/available3"];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
    [request setHTTPMethod:@"POST"];

    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
}

//- (void)findAvailableComputersWithCountryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber password:(NSString *)password nickname:(NSString *)nickname completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
//    NSString *urlString = [Utility composeAAServerURLStringWithPath:@"computer/available2"];
//
//    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
//    [request setHTTPMethod:@"POST"];
//
//    if (!nickname || [nickname stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length < 1) {
//        nickname = [Utility uuid];
//    }
//
//    NSString *escapedNickname = [nickname escapeIllegalJsonCharacter];
//
//    NSString *verification = [UserWithoutManaged generateVerificationFromCountryId:countryId phoneNumber:phoneNumber password:password nickname:nickname];
//
//    NSUserDefaults *userDefaults = [Utility groupUserDefaults];
//    NSString *applicationLocale = [userDefaults stringForKey:USER_DEFAULTS_KEY_MAIN_APP_LOCALE];
//
//    NSString *bodyString = [NSString stringWithFormat:@"{\"country-id\" : \"%@\", \"phone\" : \"%@\", \"passwd\" : \"%@\", \"nickname\" : \"%@\", \"verification\" : \"%@\", \"locale\" : \"%@\"}", countryId, phoneNumber, password, escapedNickname, verification, applicationLocale];
//    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
//    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
//
//    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
//}

- (void)deleteComputerDataInUserDefautsIfComputerIdNotFoundInUserComputers:(NSArray<UserComputerWithoutManaged *> *)userComputers didDeletedHandler:(void (^)(void))handler {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSNumber *computerIdInPreferences = [userDefaults objectForKey:USER_DEFAULTS_KEY_COMPUTER_ID];

    if (userComputers && [userComputers count] > 0 && userComputers[0].computerId) {
        BOOL computerIdFound = NO;

        for (UserComputerWithoutManaged *currentUserComputer in userComputers) {
            if ([computerIdInPreferences isEqualToNumber:currentUserComputer.computerId]) {
                computerIdFound = YES;

                break;
            }
        }

        if (!computerIdFound) {
            [Utility deleteComputerDataWithUserDefaults:userDefaults];

            if (handler) {
                handler();
            }
        }
    } else if (!userComputers || [userComputers count] < 1 || ([userComputers count] == 1 && !userComputers[0].computerId)) {
        [Utility deleteComputerDataWithUserDefaults:userDefaults];

        if (handler) {
            handler();
        }
    }
}

- (void)updateUserComputerProfilesWithProfiles:(NSDictionary *)profiles session:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    NSString *urlString = [Utility composeAAServerURLStringWithPath:@"computer/ucprofiles"];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
    [request setHTTPMethod:@"POST"];

    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];

    /* e.g.
    {
    "upload-directory" : "C:\Users\Administrator\Documents",
    "upload-subdirectory-type" : 4,
    "upload-subdirectory-value" : "西藏之旅",
    "upload-description-type" : 3,
    "upload-description-value" : "西藏布達拉宮",
    "upload-notification-type" : 2,
    "download-directory" : "/Storage/Emulated/0/Download",
    "download-subdirectory-type" : 4,
    "download-subdirectory-value" : "西藏之旅",
    "download-description-type" : 3,
    "download-description-value" : "西藏布達拉宮",
    "download-notification-type" : 2
    }
     */

    NSMutableString *bodyString = [NSMutableString string];

    [bodyString appendString:@"{"];

    if ([profiles count] > 0) {
        [profiles enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            if (value) {
                NSString *escapedKey = [key escapeIllegalJsonCharacter];

                if ([value isKindOfClass:[NSString class]]) {
                    NSString *escapeValue = [(NSString *) value escapeIllegalJsonCharacter];

                    [bodyString appendFormat:@"\"%@\":\"%@\",", escapedKey, escapeValue];
                } else if ([value isKindOfClass:[NSNumber class]]) {
                    [bodyString appendFormat:@"\"%@\":%@,", escapedKey, (NSNumber *) value];
                }
            }
        }];

        // delete the last ','
        [bodyString deleteCharactersInRange:NSMakeRange([bodyString length] - 1, 1)];
    }

    [bodyString appendString:@"}"];

    // DEBUG
//    NSLog(@"user computer profiles: %@", bodyString);

    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
}

- (void)connectToComputerWithUserId:(NSString *)userId computerId:(NSNumber *)computerId showHidden:(NSNumber *)showHidden session:(NSString *)sessionId successHandler:(void (^)(NSURLResponse *, NSData *))successHandler failureHandler:(void (^)(NSData *, NSURLResponse *, NSError *))failureHandler {
    NSString *urlString = [Utility composeAAServerURLStringWithPath:@"computer/connect-to-computer"];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
    [request setHTTPMethod:@"POST"];

    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];

    /* {
    "computer-id" : 89765,
    "showHidden" : false,
    "device-token":
                // 此值可不提供。若提供，則下面所有子項目除了「badge-number」可不提供之外，其他都要提供。
    {
        "device-token" : "1e39b345af9b036a2fc1066f2689143746f7d1220c23ff1491619a544a167c61",
        "notification-type" : "APNS",
        "device-type" : "IOS",
        "device-version" : "10.1.1",           // iOS/Android 作業系統版本
        "filelug-version" : "1.5.2",           // Filelug APP 大版號
        "filelug-build" : "2016.09.24.01",     // Filelug APP 小版號
        "badge-number" : 0                     // 此值可不提供
    }
} */

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *deviceTokenJsonString = [Utility prepareDeviceTokenJsonWithUserDefaults:userDefaults];

    NSString *bodyString;

    if (deviceTokenJsonString) {
        bodyString = [NSString stringWithFormat:@"{\"computer-id\" : %lld, \"showHidden\" : %@, \"device-token\" : %@}", [computerId longLongValue], (showHidden && [showHidden boolValue]) ? @"true" : @"false", deviceTokenJsonString];
    } else {
        bodyString = [NSString stringWithFormat:@"{\"computer-id\" : %lld, \"showHidden\" : %@}", [computerId longLongValue], (showHidden && [showHidden boolValue]) ? @"true" : @"false"];
    }

    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

        if (statusCode == 200) {
            // save response data

            NSError *parseError;
            [self saveConnectionToComputerResponseData:data userId:userId showHidden:showHidden error:&parseError];

            // notify that other tab bar view controllers need to reload
            [userDefaults setBool:YES forKey:USER_DEFAULTS_KEY_RELOAD_MENU];
            [userDefaults setObject:@YES forKey:USER_DEFAULTS_KEY_NEED_RELOAD_DOWNLOAD_LIST];
            [userDefaults setObject:@YES forKey:USER_DEFAULTS_KEY_NEED_RELOAD_UPLOAD_LIST];

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

- (void)saveConnectionToComputerResponseData:(NSData *)data userId:(NSString *)userId showHidden:(NSNumber *)showHidden error:(NSError * __autoreleasing *)error {
    if (data) {
        NSError *parseError;
        NSDictionary *responseDictionary = [Utility parseJsonAsDictionaryFromData:data error:&parseError];

        if (!parseError) {
            // DEBUG
//            NSLog(@"Response from connecting to computer:\n%@", [responseDictionary description]);

            NSNumber *responseComputerId = responseDictionary[@"computer-id"];
            NSString *responseComputerAdminId = responseDictionary[@"computer-admin-id"];
            NSString *responseComputerGroup = responseDictionary[@"computer-group"];
            NSString *responseComputerName = responseDictionary[@"computer-name"];
            NSString *responseLugServerId = responseDictionary[@"lug-server-id"];

            //* upload summary

            NSString *responseUploadDirectory = responseDictionary[@"upload-directory"];
            NSNumber *responseUploadSubdirectoryType = responseDictionary[@"upload-subdirectory-type"];
            NSString *responseUploadSubdirectoryValue = responseDictionary[@"upload-subdirectory-value"];
            NSNumber *responseUploadDescriptionType = responseDictionary[@"upload-description-type"];
            NSString *responseUploadDescriptionValue = responseDictionary[@"upload-description-value"];
            NSNumber *responseUploadNotificationType = responseDictionary[@"upload-notification-type"];

            //* download summary: only notification type is useful for Filelug iOS, the rest of these are for Filelug Android

//            NSString *responseDownloadDirectory = responseDictionary[@"download-directory"];
//            NSNumber *responseDownloadSubdirectoryType = responseDictionary[@"download-subdirectory-type"];
//            NSString *responseDownloadSubdirectoryValue = responseDictionary[@"download-subdirectory-value"];
//            NSNumber *responseDownloadDescriptionType = responseDictionary[@"download-description-type"];
//            NSString *responseDownloadDescriptionValue = responseDictionary[@"download-description-value"];

            NSNumber *responseDownloadNotificationType = responseDictionary[@"download-notification-type"];

            // DEBUG
//            NSLog(@"upload-directory : %@\nupload-subdirectory-type : %@\nupload-subdirectory-value : %@\nupload-description-type : %@\nupload-description-value : %@\nupload-notification-type : %@\ndownload-notification-type : %@", responseUploadDirectory, responseUploadSubdirectoryType, responseUploadSubdirectoryValue, responseUploadDescriptionType, responseUploadDescriptionValue, responseUploadNotificationType, responseDownloadNotificationType);

            // replace nil with default, not current one because the current one may come from another user computer.

            NSUserDefaults *userDefaults = [Utility groupUserDefaults];

            if (!responseUploadSubdirectoryType) {
                responseUploadSubdirectoryType = @([UploadSubdirectoryService defaultType]);
            }

            if (!responseUploadDescriptionType) {
                responseUploadDescriptionType = @([UploadDescriptionService defaultType]);
            }

            if (!responseUploadNotificationType) {
                responseUploadNotificationType = @([UploadNotificationService defaultType]);
            }

            if (!responseDownloadNotificationType) {
                responseDownloadNotificationType = @([DownloadNotificationService defaultType]);
            }

            NSString *userComputerId = [UserComputerWithoutManaged userComputerIdFromUserId:userId computerId:responseComputerId];

            // create or update user-computer in local db

            UserComputerWithoutManaged *userComputerWithoutManaged = [[UserComputerWithoutManaged alloc] initWithUserId:userId
                                                                                                         userComputerId:userComputerId
                                                                                                             computerId:responseComputerId
                                                                                                        computerAdminId:responseComputerAdminId
                                                                                                          computerGroup:responseComputerGroup
                                                                                                           computerName:responseComputerName
                                                                                                             showHidden:showHidden
                                                                                                        uploadDirectory:responseUploadDirectory
                                                                                                 uploadSubdirectoryType:responseUploadSubdirectoryType
                                                                                                uploadSubdirectoryValue:responseUploadSubdirectoryValue
                                                                                                  uploadDescriptionType:responseUploadDescriptionType
                                                                                                 uploadDescriptionValue:responseUploadDescriptionValue
                                                                                                 uploadNotificationType:responseUploadNotificationType
                                                                                                      downloadDirectory:nil
                                                                                               downloadSubdirectoryType:nil
                                                                                              downloadSubdirectoryValue:nil
                                                                                                downloadDescriptionType:nil
                                                                                               downloadDescriptionValue:nil
                                                                                               downloadNotificationType:responseDownloadNotificationType];

            [self.userComputerDao createOrUpdateUserComputerFromUserComputerWithoutManaged:userComputerWithoutManaged completionHandler:^(NSError *updateError) {
                if (updateError) {
                    if (error) {
                        *error = updateError;
                    } else {
                        NSLog(@"Failed to save connection data.\n%@", [updateError userInfo]);
                    }

                    NSLog(@"Error on updating the computer admin id: %@, computer group: %@, and computer name: %@ of the user computer with id: %@\n%@", responseComputerAdminId, responseComputerGroup, responseComputerName, userComputerId, [updateError userInfo]);
                }
            }];

            // save to preferences

            // computer-related
            [userDefaults setObject:responseComputerId forKey:USER_DEFAULTS_KEY_COMPUTER_ID];
            [userDefaults setObject:responseComputerAdminId forKey:USER_DEFAULTS_KEY_COMPUTER_ADMIN_ID];
            [userDefaults setObject:responseComputerGroup forKey:USER_DEFAULTS_KEY_COMPUTER_GROUP];
            [userDefaults setObject:responseComputerName forKey:USER_DEFAULTS_KEY_COMPUTER_NAME];
            [userDefaults setObject:userComputerId forKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];
            [userDefaults setBool:[showHidden boolValue] forKey:USER_DEFAULTS_KEY_SHOW_HIDDEN];

            /* leave the old value if no updated lug-server-id received. */
            if (responseLugServerId) {
                [userDefaults setObject:responseLugServerId forKey:USER_DEFAULTS_KEY_LUG_SERVER_ID];
            }

            [userDefaults setObject:responseDictionary[@"file.encoding"] forKey:USER_DEFAULTS_KEY_SERVER_FILE_ENCODING];
            [userDefaults setObject:responseDictionary[@"file.separator"] forKey:USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR];
            [userDefaults setObject:responseDictionary[@"path.separator"] forKey:USER_DEFAULTS_KEY_SERVER_PATH_SEPARATOR];
            [userDefaults setObject:responseDictionary[@"line.separator"] forKey:USER_DEFAULTS_KEY_SERVER_LINE_SEPARATOR];
            [userDefaults setObject:responseDictionary[@"java.io.tmpdir"] forKey:USER_DEFAULTS_KEY_SERVER_TEMP_DIRECTORY];
            [userDefaults setObject:responseDictionary[@"user.country"] forKey:USER_DEFAULTS_KEY_SERVER_USER_COUNTRY];
            [userDefaults setObject:responseDictionary[@"user.dir"] forKey:USER_DEFAULTS_KEY_SERVER_USER_DIRECTORY];
            [userDefaults setObject:responseDictionary[@"user.home"] forKey:USER_DEFAULTS_KEY_SERVER_USER_HOME];
            [userDefaults setObject:responseDictionary[@"user.language"] forKey:USER_DEFAULTS_KEY_SERVER_USER_LANGUAGE];
            [userDefaults setObject:responseDictionary[@"desktop.version"] forKey:USER_DEFAULTS_KEY_DESKTOP_VERSION];

            // Upload Summary - save to preference for current user-computer

            [userDefaults setObject:responseUploadDirectory forKey:USER_DEFAULTS_KEY_UPLOAD_DIRECTORY];
            [userDefaults setObject:responseUploadSubdirectoryType forKey:USER_DEFAULTS_KEY_UPLOAD_SUBDIRECTORY_TYPE];
            [userDefaults setObject:responseUploadSubdirectoryValue forKey:USER_DEFAULTS_KEY_UPLOAD_SUBDIRECTORY_VALUE];
            [userDefaults setObject:responseUploadDescriptionType forKey:USER_DEFAULTS_KEY_UPLOAD_DESCRIPTION_TYPE];
            [userDefaults setObject:responseUploadDescriptionValue forKey:USER_DEFAULTS_KEY_UPLOAD_DESCRIPTION_VALUE];
            [userDefaults setObject:responseUploadNotificationType forKey:USER_DEFAULTS_KEY_UPLOAD_NOTIFICATION_TYPE];

            // remove first root directory real path
            [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_FIRST_ROOT_DIRECTORY];

            // Download Summary - save to preference as temp values for current user-computer
            // only notification type is useful for Filelug iOS, the rest of these are for Filelug Android

            [userDefaults setObject:responseDownloadNotificationType forKey:USER_DEFAULTS_KEY_DOWNLOAD_NOTIFICATION_TYPE];

            [userDefaults synchronize];
        } else {
            if (error) {
                *error = parseError;
            } else {
                NSLog(@"Failed to save connection data.\n%@", [parseError userInfo]);
            }
        }
    } else {
        NSLog(@"[saveLoginData] Error: Data is nil.");
    }
}

- (void)changeShowHiddenForCurrentSessionWithShowHidden:(BOOL)showHidden completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *urlString = [Utility composeAAServerURLStringWithPath:@"computer/showHidden"];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
    [request setHTTPMethod:@"POST"];

    NSString *sessionId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    NSNumber *computerId = [userDefaults objectForKey:USER_DEFAULTS_KEY_COMPUTER_ID];

    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];

    NSString *bodyString = [NSString stringWithFormat:@"{\"computer-id\" : %lld, \"showHidden\" : %@}", [computerId longLongValue], (showHidden ? @"true" : @"false")];

    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
}

- (void)changeComputerNameForCurrentSessionWithNewComputerName:(NSString *)computerName completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *urlString = [Utility composeAAServerURLStringWithPath:@"computer/name"];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
    [request setHTTPMethod:@"POST"];

    NSString *sessionId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    NSNumber *computerId = [userDefaults objectForKey:USER_DEFAULTS_KEY_COMPUTER_ID];

    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];

    NSString *applicationLocale = [userDefaults stringForKey:USER_DEFAULTS_KEY_MAIN_APP_LOCALE];

    /*
     {
        "computer-id" : 3837763683939,
        "new-computer-group" : "GENERAL",
        "new-computer-name" : "ALBERT'S LAPTOP",
        "locale" : "zh_TW"
     }
     */

    NSString *bodyString = [NSString stringWithFormat:@"{\"computer-id\" : %lld, \"new-computer-group\" : \"%@\", \"new-computer-name\" : \"%@\", \"locale\" : \"%@\"}", [computerId longLongValue], DEFAULT_COMPUTER_GROUP, computerName, applicationLocale];

    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
}

- (void)createComputerWithQRCode:(NSString *)qrCode session:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    NSString *urlString = [Utility composeAAServerURLStringWithPath:@"computer/create-with-qrcode"];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
    [request setHTTPMethod:@"POST"];

    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];

    NSString *bodyString = [NSString stringWithFormat:@"{\"qr-code\" : \"%@\"}", qrCode];

    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
}

- (void)deleteComputerWithUserId:(NSString *)userId computerId:(NSNumber *)computerId session:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    NSString *urlString = [Utility composeAAServerURLStringWithPath:@"computer/delete2"];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
    [request setHTTPMethod:@"POST"];

    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];

    /*
        {
            "computer-id" : 3837763637383939,
            "verification" : "bf94b4d1c5305b5b3f96abdab89eba05b994ea10a249aaa3acb28aa13533040cc4b24cec2783fc3402011f3a52065c16",
            "locale" : "zh_TW"
        }
     */

    NSString *verification = [Utility generateVerificationWithUserId:userId computerId:computerId];

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];
    NSString *applicationLocale = [userDefaults stringForKey:USER_DEFAULTS_KEY_MAIN_APP_LOCALE];

    NSString *bodyString = [NSString stringWithFormat:@"{\"computer-id\" : %@, \"verification\" : \"%@\", \"locale\" : \"%@\"}", [computerId stringValue], verification, applicationLocale];

    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
}

- (void)findSuccessfullyDownloadedFileForUserComputer:(NSString *)userComputerId completionHandler:(void (^)(FileTransferWithoutManaged *))completionHandler {
    // find successfully downloads

    FileTransferWithoutManaged *successfullyDownloaded = [self.fileTransferDao findOneSuccessfullyDownloadedForUserComputer:userComputerId error:NULL];

    completionHandler(successfullyDownloaded);
}
@end
