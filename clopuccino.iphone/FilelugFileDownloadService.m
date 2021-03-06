#import <UserNotifications/UserNotifications.h>
#import "FilelugFileDownloadService.h"

@interface FilelugFileDownloadService ()

@property(nonatomic, strong) FileTransferService *fileTransferService;

@property(nonatomic, strong) DirectoryService *directoryService;

@property(nonatomic, strong) FileTransferDao *fileTransferDao;

@property(nonatomic, strong) HierarchicalModelDao *hierarchicalModelDao;

@property(nonatomic, strong) FileDownloadGroupDao *fileDownloadGroupDao;

@end

@implementation FilelugFileDownloadService {
}

//static NSURLSession *backgroundSession;

static void (^backgroundCompletionHandler)(void);

@synthesize backgroundSession;

- (instancetype)init {
    self = [super init];

    if (self) {
        [self initialConfigureWithBackgroundCompletionHandler:nil];
    }

    return self;
}

- (instancetype)initWithBackgroundCompletionHandler:(void (^ _Nullable)(void))completionHandler {
    self = [super init];

    if (self) {
        [self initialConfigureWithBackgroundCompletionHandler:completionHandler];
    }

    return self;
}

- (void)initialConfigureWithBackgroundCompletionHandler:(void (^ _Nullable)(void))completionHandler {
    @synchronized (self) {
        // The completionHandler must be added in before creating background session object
        // in order to following the description in [NSURLSessionDelegate URLSessionDidFinishEventsForBackgroundURLSession:]
        // see the url for more information: https://developer.apple.com/documentation/foundation/nsurlsessiondelegate/1617185-urlsessiondidfinisheventsforback
        // if completionHandler is nil, keep the old one, if any.
        if (completionHandler) {
            backgroundCompletionHandler = completionHandler;
        }

        if (!self.backgroundSession) {
            NSString *backgroundDownloadIdentifier = [Utility backgroundDownloadIdentifierForFilelug];

            _cachePolicy = NSURLRequestUseProtocolCachePolicy;
            _timeInterval = CONNECTION_TIME_INTERVAL_FOR_BACKGROUND_DOWNLOAD;

            NSURLSessionConfiguration *sessionConfiguration = [self sessionConfigureWithBackgroundSessionIdentifier:backgroundDownloadIdentifier cachePolicy:_cachePolicy timeInterval:_timeInterval];

            self.backgroundSession = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:[[NSOperationQueue alloc] init]];
        }
    }
}

- (FileTransferService *)fileTransferService {
    if (!_fileTransferService) {
        _fileTransferService = [[FileTransferService alloc] init];
    }
    
    return _fileTransferService;
}

- (void)separateTaskDescription:(NSString *)taskDescription
                  toTransferKey:(NSString *_Nullable *_Nullable)transferKey
                andRealFilename:(NSString *_Nullable *_Nullable)realFilename {
    NSArray *components = [taskDescription componentsSeparatedByString:@"\t"];
    
    if (components && [components count] == 2) {
        if (transferKey) {
            *transferKey = components[0];
        }
        
        if (realFilename) {
            *realFilename = components[1];
        }
    } else {
        NSLog(@"Incorrect format of task description: %@", taskDescription);
    }
}

- (NSURLSessionConfiguration *)sessionConfigureWithBackgroundSessionIdentifier:(NSString *)backgroundSessionIdentifier
                                                                   cachePolicy:(enum NSURLRequestCachePolicy)policy
                                                                  timeInterval:(NSTimeInterval)interval {
    NSURLSessionConfiguration *configuration;
    
    configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:backgroundSessionIdentifier];
    
    // in iOS 8 or later, user timeoutIntervalForResource to set timeout of background session, instead of using timeoutIntervalForRequest
    configuration.timeoutIntervalForResource = interval;

    configuration.timeoutIntervalForRequest = interval;

    configuration.requestCachePolicy = policy;
    
    // for app extensions, use share container identifier as the value
    configuration.sharedContainerIdentifier = APP_GROUP_NAME;
    
    configuration.requestCachePolicy = policy ? policy : NSURLRequestUseProtocolCachePolicy;
    
    // The value is default set to YES
    configuration.allowsCellularAccess = YES;
    
    // When the value of this property is YES, the system automatically wakes up or launches the iOS app in the background
    // when the session’s tasks finish or require authentication.
    // At that time, the system calls the app delegate’s application:handleEventsForBackgroundURLSession:completionHandler: method,
    // providing it with the identifier of the session that needs attention.
    // If your app had to be relaunched, you can use that identifier to create a new configuration and session object capable of servicing the tasks.
    configuration.sessionSendsLaunchEvents = YES;
    
    // To prevent the system delay transferring large files until the device is plugged in
    // or transferring files only when connected to the network via Wi-Fi,
    // MAKE SURE to set the value to NO
    configuration.discretionary = NO;
    
    return configuration;
}

- (DirectoryService *)directoryService {
    if (!_directoryService) {
        _directoryService = [[DirectoryService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];
    }
    
    return _directoryService;
}

- (FileTransferDao *)fileTransferDao {
    if (!_fileTransferDao) {
        _fileTransferDao = [[FileTransferDao alloc] init];
    }
    
    return _fileTransferDao;
}

- (HierarchicalModelDao *)hierarchicalModelDao {
    if (!_hierarchicalModelDao) {
        _hierarchicalModelDao = [[HierarchicalModelDao alloc] init];
    }
    
    return _hierarchicalModelDao;
}

- (FileDownloadGroupDao *)fileDownloadGroupDao {
    if (!_fileDownloadGroupDao) {
        _fileDownloadGroupDao = [[FileDownloadGroupDao alloc] init];
    }
    
    return _fileDownloadGroupDao;
}

- (void)findDownloadTaskByTransferKey:(NSString *)transferKey
                    completionHandler:(void (^ _Nullable)(NSURLSessionDownloadTask *_Nullable downloadTask))completionHandler {
    [self.backgroundSession getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        NSURLSessionDownloadTask *foundTask;
        
        if (downloadTasks && [downloadTasks count] > 0) {
            for (NSURLSessionDownloadTask *task in downloadTasks) {
                NSString *foundTransferKey;
                NSString *foundRealFilename;
                
                [self separateTaskDescription:[task taskDescription] toTransferKey:&foundTransferKey andRealFilename:&foundRealFilename];
                
                if (foundTransferKey && [foundTransferKey isEqualToString:transferKey]) {
                    foundTask = task;
                    
                    break;
                }
            }
        }
        
        if (completionHandler) {
            completionHandler(foundTask);
        }
    }];
}

- (void)downloadFromStartWithTransferKey:(NSString *)transferKey
                          realServerPath:(NSString *)realServerPath
                           fileSeparator:(NSString *)fileSeparator
                         downloadGroupId:(NSString *_Nullable)downloadGroupId
                          userComputerId:(NSString *)userComputerId
                               sessionId:(NSString *)sessionId
                    actionsAfterDownload:(NSString *_Nullable)actionsAfterDownload
     addToStartTimestampWithMilliseconds:(unsigned long)millisecondsToAdd
                       completionHandler:(void (^ _Nullable)(void))completionHandler {
    [self.fileTransferService downloadFromStartWithURLSession:self.backgroundSession
                                                  transferKey:transferKey
                                               realServerPath:realServerPath
                                                fileSeparator:fileSeparator
                                              downloadGroupId:downloadGroupId
                                               userComputerId:userComputerId
                                                    sessionId:sessionId
                                         actionsAfterDownload:actionsAfterDownload
                          addToStartTimestampWithMilliseconds:millisecondsToAdd
                                            completionHandler:completionHandler];
}

- (void)resumeDownloadWithRealFilePath:(NSString *)realServerPath
                            resumeData:(NSData *_Nullable)resumeData
                     completionHandler:(void (^ _Nullable)(void))completionHandler {
    [self.fileTransferService resumeDownloadWithURLSession:self.backgroundSession
                                              realFilePath:realServerPath
                                                resumeData:resumeData
                                         completionHandler:completionHandler];
}

- (void)cancelDownloadWithTransferKey:(NSString *)transferKey
                    completionHandler:(void (^ _Nullable)(void))completionHandler {
    [self.fileTransferService cancelDownloadWithURLSession:self.backgroundSession
                                               transferKey:transferKey
                                         completionHandler:completionHandler];
}

- (void)cancelAllFilesDownloading {
    [self.fileTransferService cancelAllFilesDownloadingWithURLSession:self.backgroundSession];
}

#pragma mark - Manage resumeData

// append

- (void)addResumeData:(NSData *_Nullable)resumeData toFileTransferWithTransferKey:(NSString *)transferKey completionHandler:(void (^ _Nullable)(NSError *_Nullable error))completionHandler {
    [self.fileTransferDao addResumeData:resumeData toFileTransferWithTransferKey:transferKey completionHandler:completionHandler];
}

// find

- (nullable NSData *)resumeDataFromFileTransferWithTransferKey:(NSString *)transferKey error:(NSError *_Nullable __autoreleasing *_Nullable)error {
    return [self.fileTransferDao resumeDataFromFileTransferWithTransferKey:transferKey error:error];
}

// remove single record

- (void)removeResumeDataFromFileTransferWithTransferKey:(NSString *)transferKey
                                      completionHandler:(void (^ _Nullable)(NSError *_Nullable))completionHandler {
    [self.fileTransferDao removeResumeDataFromFileTransferWithTransferKey:transferKey completionHandler:completionHandler];
}

- (void)removeResumeDataWithRealServerPath:(NSString *)realServerPath
                            userComputerId:(NSString *)userComputerId
                         completionHandler:(void (^ _Nullable)(NSError *_Nullable))completionHandler {
    [self.fileTransferDao removeResumeDataWithRealServerPath:realServerPath
                                              userComputerId:userComputerId
                                           completionHandler:completionHandler];
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    [self.fileTransferService URLSession:session downloadTask:downloadTask didWriteData:bytesWritten totalBytesWritten:totalBytesWritten totalBytesExpectedToWrite:totalBytesExpectedToWrite completionHandler:^(NSString *realFilename, float downloadPercentage, FileTransferWithoutManaged *fileTransferWithoutManaged) {
        if (fileTransferWithoutManaged) {
            // success to receive data from server
            
            NSDictionary *notificationDictionary = @{
                                                     NOTIFICATION_KEY_DOWNLOAD_TRANSFER_KEY: fileTransferWithoutManaged.transferKey,
                                                     NOTIFICATION_KEY_DOWNLOAD_REAL_FILENAME: realFilename,
                                                     NOTIFICATION_KEY_DOWNLOAD_TRANSFERRED_SIZE: fileTransferWithoutManaged.transferredSize,
                                                     NOTIFICATION_KEY_DOWNLOAD_TOTAL_SIZE: fileTransferWithoutManaged.totalSize,
                                                     NOTIFICATION_KEY_DOWNLOAD_PERCENTAGE: @(downloadPercentage)
                                                     };
            
            [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_NAME_FILE_DOWNLOAD_DID_WRITE_DATA object:nil userInfo:notificationDictionary];
        }
    }];
}

// Invoked after calling downloadTaskWithResumeData: or downloadTaskWithResumeData:completionHandler:
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes {
    [self.fileTransferService URLSession:session downloadTask:downloadTask didResumeAtOffset:fileOffset expectedTotalBytes:expectedTotalBytes completionHandler:^(NSString *realFilename, FileTransferWithoutManaged *fileTransferWithoutManaged) {
        if (fileTransferWithoutManaged) {
            NSDictionary *notificationDictionary = @{
                                                     NOTIFICATION_KEY_DOWNLOAD_TRANSFER_KEY : fileTransferWithoutManaged.transferKey,
                                                     NOTIFICATION_KEY_DOWNLOAD_REAL_FILENAME : realFilename,
                                                     NOTIFICATION_KEY_DOWNLOAD_TRANSFERRED_SIZE : fileTransferWithoutManaged.transferredSize,
                                                     NOTIFICATION_KEY_DOWNLOAD_TOTAL_SIZE :fileTransferWithoutManaged.totalSize
                                                     };
            
            [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_NAME_FILE_DOWNLOAD_DID_RESUME object:nil userInfo:notificationDictionary];
            
        }
    }];
}

// Invoked only if the file download successfully, so don't have to consider partial content
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    [self.fileTransferService URLSession:session downloadTask:downloadTask didFinishDownloadingToURL:location completionHandler:^(NSString *realFilename, NSString *savedFilePath, FileTransferWithoutManaged *fileTransferWithoutManaged) {
        NSDictionary *notificationDictionary;
        
        if (savedFilePath) {
//            NSLog(@"File \"%@\" did finished downloading to path: \"%@\"", realFilename, savedFilePath);
            
            notificationDictionary = @{
                                       NOTIFICATION_KEY_DOWNLOAD_TRANSFER_KEY : fileTransferWithoutManaged.transferKey,
                                       NOTIFICATION_KEY_DOWNLOAD_REAL_FILENAME : realFilename,
                                       NOTIFICATION_KEY_DOWNLOAD_PERMANENT_FILE_PATH : savedFilePath
                                       };
        } else {
            notificationDictionary = @{
                                       NOTIFICATION_KEY_DOWNLOAD_TRANSFER_KEY : fileTransferWithoutManaged.transferKey,
                                       NOTIFICATION_KEY_DOWNLOAD_REAL_FILENAME : realFilename
                                       };
        }
        
        // This notification works only when the application is active. It won't work if the application is in the background.
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_NAME_FILE_DOWNLOAD_DID_FINISH object:nil userInfo:notificationDictionary];
    }];
}

#pragma mark - NSURLSessionTaskDelegate

// If file downloaded successfully, invoked after URLSession:downloadTask:didFinishDownloadingToURL:.
// If file downloaded failed, invoked after error responsed.
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *_Nullable)error {
//    NSLog(@"Task: \"%lu\" didCompleteWithError: \"%@\"", (unsigned long)[task taskIdentifier], error);
    
    [self.fileTransferService URLSession:session task:task didCompleteWithError:error completionHandler:^(NSString *realFilename, FileTransferWithoutManaged *fileTransferWithoutManaged) {
        NSDictionary *notificationDictionary = @{
                                                 NOTIFICATION_KEY_DOWNLOAD_TRANSFER_KEY : fileTransferWithoutManaged.transferKey,
                                                 NOTIFICATION_KEY_DOWNLOAD_REAL_FILENAME : realFilename,
                                                 NOTIFICATION_KEY_DOWNLOAD_TRANSFERRED_SIZE :fileTransferWithoutManaged.transferredSize,
                                                 NOTIFICATION_KEY_DOWNLOAD_TOTAL_SIZE : fileTransferWithoutManaged.totalSize,
                                                 NOTIFICATION_KEY_DOWNLOAD_STATUS : fileTransferWithoutManaged.status,
                                                 NOTIFICATION_KEY_DOWNLOAD_FILE_LOCAL_PATH : fileTransferWithoutManaged.localPath
                                                 };
        
        // send local notification -
        // The object should be alive even if the app is in the background to make sure the local notification works.
        [self onFileDownloadDidCompleteWithUserInfo:notificationDictionary];
    }];
}

#pragma mark - NSURLSessionDelegate

// invoked when all downloads success or failured.
- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
    if (backgroundCompletionHandler) {
        void (^completionHandler)(void) = backgroundCompletionHandler;
        backgroundCompletionHandler = nil;

        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler();
        });
    }

    if (self.backgroundSession && [session.configuration.identifier isEqualToString:self.backgroundSession.configuration.identifier]) {
        [self.backgroundSession invalidateAndCancel];

        self.backgroundSession = nil;
    }

//    [self.fileTransferService URLSessionDidFinishEventsForBackgroundURLSession:session];
//
//    // DEBUG
//    NSLog(@"Invoked [FilelugFileTransferService URLSessionDidFinishEventsForBackgroundURLSession:] with session identifier: %@", session.configuration.identifier);
}

#pragma mark - Send local notifications

- (void)onFileDownloadDidCompleteWithUserInfo:(NSDictionary *)userInfo {
    // DEBUG
//    NSLog(@"onFileDownloadDidCompleteWithUserInfo:\n%@", userInfo);

    if (userInfo) {
        NSString *fileTransferStatus = userInfo[NOTIFICATION_KEY_DOWNLOAD_STATUS];
        NSString *transferKey = userInfo[NOTIFICATION_KEY_DOWNLOAD_TRANSFER_KEY];
        NSString *localPath = userInfo[NOTIFICATION_KEY_DOWNLOAD_FILE_LOCAL_PATH];
        NSString *filename = userInfo[NOTIFICATION_KEY_DOWNLOAD_REAL_FILENAME];
        
        if (fileTransferStatus && transferKey && localPath && filename) {
            if ([fileTransferStatus isEqualToString:FILE_TRANSFER_STATUS_SUCCESS]) {
                FileDownloadGroupWithoutManaged *downloadGroupWithoutManaged = [self.fileDownloadGroupDao findFileDownloadGroupByTransferKey:transferKey];

                if (!downloadGroupWithoutManaged) {
                    // always notify user if no download group relates to this file downloaded.

                    [self sendSingleSuccessLocalNotificationWithTransferKey:transferKey filename:filename];
                } else {
                    if (downloadGroupWithoutManaged.notificationType) {
                        NSInteger notificationTypeInteger = [downloadGroupWithoutManaged.notificationType integerValue];

                        if (notificationTypeInteger == FILE_TRANSFER_NOTIFICATION_TYPE_ON_EACH_FILE) {
                            // notify on each file
                            [self sendSingleSuccessLocalNotificationWithTransferKey:transferKey filename:filename];
                        } else if (notificationTypeInteger == FILE_TRANSFER_NOTIFICATION_TYPE_ON_ALL_FILES) {
                            // notify on all files download successfully

                            NSSet<NSString *> *fileTransferKeys = downloadGroupWithoutManaged.fileTransferKeys;

                            if (fileTransferKeys && [fileTransferKeys count] > 0) {
                                BOOL allSuccess = YES;

                                NSUInteger fileCount = [fileTransferKeys count];

                                for (NSString *fileTransferKey in fileTransferKeys) {
                                    if ([fileTransferKey isEqualToString:transferKey]) {
                                        // do not check the current download because the download status in local db may not updated to success yet.

                                        continue;
                                    } else {
                                        FileTransferWithoutManaged *fileTransferWithoutManaged = [self.fileTransferDao findFileTransferForTransferKey:fileTransferKey error:NULL];

                                        if (!fileTransferWithoutManaged || ![fileTransferWithoutManaged.status isEqualToString:FILE_TRANSFER_STATUS_SUCCESS]) {
                                            allSuccess = NO;

                                            break;
                                        }
                                    }
                                }

                                if (allSuccess) {
                                    NSString *downloadGroupId = downloadGroupWithoutManaged.downloadGroupId;

                                    [self sendAllSuccessLocalNotificationWithDownloadGroupId:downloadGroupId latestSuccessFilename:filename filesCount:fileCount];
                                }
                            }
                        }
//                    } else {
//                        NSLog(@"Notification type not found for file: %@", filename);
                    }
                }
            } else {
                // If download failed, always notify user.
                
                [self sendTransferFailedLocalNotificationWithTransferKey:transferKey filename:filename];
            }
        }
    }
}

- (void)sendSingleSuccessLocalNotificationWithTransferKey:(NSString *)transferKey filename:(NSString *)filename {
    NSString *title = NSLocalizedString(@"File downloaded successfully", @"");
    
    NSString *message;
    
    if (filename) {
        message = [NSString stringWithFormat:NSLocalizedString(@"File %@ downloaded successfully", @""), filename];
    } else {
        message = title;
    }
    
    NSDictionary *userInfo = @{NOTIFICATION_MESSAGE_KEY_TRANSFER_KEY : transferKey, @"filename" : filename, NOTIFICATION_MESSAGE_KEY_TRANSFER_STATUS : FILE_TRANSFER_STATUS_SUCCESS};

    dispatch_async(dispatch_get_main_queue(), ^{
        [self sendImmediateLocalNotificationWithMessage:message title:title userInfo:userInfo];
    });
}

- (void)sendAllSuccessLocalNotificationWithDownloadGroupId:(NSString *)downloadGroupId
                                     latestSuccessFilename:(NSString *_Nullable)latestSuccessFilename
                                                filesCount:(NSUInteger)filesCount {
    NSString *title = NSLocalizedString(@"All files downloaded successfully", @"");
    
    NSString *message;
    
    if (filesCount > 0 && latestSuccessFilename) {
        message = [NSString stringWithFormat:NSLocalizedString(@"All files downloaded successfully2", @""), filesCount, latestSuccessFilename];
    } else {
        message = title;
    }
    
    NSDictionary *userInfo = @{
                               NOTIFICATION_MESSAGE_KEY_TYPE : NOTIFICATION_MESSAGE_TYPE_ALL_FILES_DOWNLOADED_SUCCESSFULLY,
                               NOTIFICATION_MESSAGE_KEY_DOWNLOAD_GROUP_ID : downloadGroupId
                               };

    dispatch_async(dispatch_get_main_queue(), ^{
        [self sendImmediateLocalNotificationWithMessage:message title:title userInfo:userInfo];
    });
}

- (void)sendTransferFailedLocalNotificationWithTransferKey:(NSString *)transferKey filename:(NSString *_Nullable)filename {
    NSString *title = NSLocalizedString(@"Failed to download file", @"");
    
    NSString *message;
    
    if (filename) {
        message = [NSString stringWithFormat:NSLocalizedString(@"Failed to download file %@", @""), filename];
    } else {
        message = title;
    }
    
    NSDictionary *userInfo = @{NOTIFICATION_MESSAGE_KEY_TRANSFER_KEY : transferKey, @"filename" : filename, NOTIFICATION_MESSAGE_KEY_TRANSFER_STATUS : FILE_TRANSFER_STATUS_FAILED};

    dispatch_async(dispatch_get_main_queue(), ^{
        [self sendImmediateLocalNotificationWithMessage:message title:title userInfo:userInfo];
    });
}

- (void)sendImmediateLocalNotificationWithMessage:(NSString *)message title:(NSString *)title userInfo:(NSDictionary *)userInfo {
    if ([Utility isDeviceVersion10OrLater]) {
        UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
        
        content.title = title;
//        content.subtitle = title;
        content.body = message;
        content.userInfo = userInfo;
        content.sound = [UNNotificationSound defaultSound];
        
        // FIXME: Do not increase badge number until we know exactly how to make it right.
        content.badge = @0;

        // Specify nil to trigger to deliver the notification right away.
//        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[self generateNotificationIdWithUserInfo:userInfo] content:content trigger:nil];

        // Delay to deliver the notification with trigger
        UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:2 repeats:NO];
        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[self generateNotificationIdWithUserInfo:userInfo] content:content trigger:trigger];

        [[UNUserNotificationCenter currentNotificationCenter] removePendingNotificationRequestsWithIdentifiers:@[request.identifier]];

        // completionHandler without debug message
        [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:nil];

        // DEBUG: completionHandler with debug message
//        [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:^(NSError *error) {
//            if (error) {
//                NSLog(@"Error on adding notification request with request id: %@\n%@", request.identifier, [error userInfo]);
//            } else {
//                NSLog(@"Notification added with request id: %@", request.identifier);
//            }
//        }];
    } else {
        // FIXME: Set as an argument when the class initialized
        UIApplication *application = [UIApplication sharedApplication];
        
        UILocalNotification *localNotification = [[UILocalNotification alloc] init];
        
        localNotification.fireDate = [NSDate date];

        // a proxy that will always act as if it is the current default time zone for the application, even if that default changes.
        localNotification.timeZone = [NSTimeZone localTimeZone];
        
        localNotification.alertBody = message;
        
        localNotification.soundName = UILocalNotificationDefaultSoundName;
        
        // FIXME: always set to 0 until we know exactly how to make it right.
        localNotification.applicationIconBadgeNumber = 0;
        
        localNotification.userInfo = userInfo;
        
        if ([localNotification respondsToSelector:@selector(setAlertTitle:)]) {
            localNotification.alertTitle = title;
        }
        
        [application scheduleLocalNotification:localNotification];
    }
}

- (NSString *)generateNotificationIdWithUserInfo:(NSDictionary *)userInfo {
    NSString *notificationId;
    
    NSString *downloadGroupId = userInfo[NOTIFICATION_MESSAGE_KEY_DOWNLOAD_GROUP_ID];
    
    if (downloadGroupId) {
        notificationId = [downloadGroupId copy];
    } else {
        NSString *transferKey = userInfo[NOTIFICATION_MESSAGE_KEY_TRANSFER_KEY];
        
        if (transferKey) {
            notificationId = [transferKey copy];
        } else {
            notificationId = [Utility uuid];
            
            NSLog(@"Use UUID as the notification id because neither of download group id nor transfer key found.");
        }
    }
    
    return notificationId;
}

@end
