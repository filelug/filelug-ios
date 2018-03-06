#import "FileTransferService.h"
#import "DirectoryService.h"
#import "HierarchicalModelWithoutManaged.h"
#import "Utility.h"
#import "FileTransferDao.h"
#import "HierarchicalModelDao.h"
#import "FileDownloadGroupDao.h"

@interface FileTransferService ()

@property(nonatomic, strong) DirectoryService *directoryService;

@property(nonatomic, strong) FileTransferDao *fileTransferDao;

@property(nonatomic, strong) HierarchicalModelDao *hierarchicalModelDao;

@property(nonatomic, strong) FileDownloadGroupDao *fileDownloadGroupDao;

@end

@implementation FileTransferService {
}

- (NSString *)taskDescriptionFromTransferKey:(NSString *)transferKey realFilename:(NSString *)realFilename {
    return [NSString stringWithFormat:@"%@\t%@", transferKey, realFilename];
}

- (void)separateTaskDescription:(NSString *)taskDescription toTransferKey:(NSString **)transferKey andRealFilename:(NSString **)realFilename {
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

- (void)findDownloadTaskWithURLSession:(NSURLSession *)urlSession transferKey:(NSString *)transferKey completionHandler:(void (^)(NSURLSessionDownloadTask *downloadTask))completionHandler {
    [urlSession getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
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

- (void)downloadFromStartWithURLSession:(NSURLSession *)urlSession
                            transferKey:(NSString *)transferKey
                         realServerPath:(NSString *)realServerPath
                          fileSeparator:(NSString *)fileSeparator
                        downloadGroupId:(NSString *_Nullable)downloadGroupId
                         userComputerId:(NSString *)userComputerId
                              sessionId:(NSString *)sessionId
                   actionsAfterDownload:(NSString *_Nullable)actionsAfterDownload
    addToStartTimestampWithMilliseconds:(unsigned long)millisecondsToAdd
                      completionHandler:(void (^ _Nullable)(void))completionHandler {
    // delete FileTransfer with the same realServerPath and the local file, if any

    FileTransferWithoutManaged *foundFileTransferWithoutManaged = [self.fileTransferDao findFileTransferForUserComputer:userComputerId realServerPath:realServerPath error:NULL];

    if (foundFileTransferWithoutManaged) {
        NSString *foundTransferKey = foundFileTransferWithoutManaged.transferKey;

        [self.fileTransferDao deleteFileTransferForTransferKey:foundTransferKey successHandler:^(){
            [DirectoryService deleteLocalFileWithRealServerPath:realServerPath completionHandler:^(NSError *deleteError){
                if (deleteError) {
                    NSLog(@"Failed to delete file: %@\n%@", realServerPath, [deleteError userInfo]);
                }
            }];

            // clear download information in correspondent HierarchicalModels
            [self.hierarchicalModelDao removeDownloadInformationInHierarchicalModelsWithTransferKey:foundTransferKey completionHandler:nil];
        } errorHandler:^(NSError *error){
            [DirectoryService deleteLocalFileWithRealServerPath:realServerPath completionHandler:^(NSError *deleteError){
                if (deleteError) {
                    NSLog(@"Failed to delete file: %@\n%@", realServerPath, [deleteError userInfo]);
                }
            }];
        }];

        double delayInSeconds = 1.0;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
            [self internalDownlaodFileWithURLSession:urlSession transferKey:transferKey realServerPath:realServerPath fileSeparator:fileSeparator downloadGroupId:downloadGroupId userComputerId:userComputerId sessionId:sessionId actionsAfterDownload:actionsAfterDownload addToStartTimestampWithMilliseconds:millisecondsToAdd completionHandler:completionHandler];
        });

    } else {
        [self internalDownlaodFileWithURLSession:urlSession transferKey:transferKey realServerPath:realServerPath fileSeparator:fileSeparator downloadGroupId:downloadGroupId userComputerId:userComputerId sessionId:sessionId actionsAfterDownload:actionsAfterDownload addToStartTimestampWithMilliseconds:millisecondsToAdd completionHandler:completionHandler];
    }
}

// The method separates from downloadWithTransferKey:realServerPath:fileSeparator:downloadGroupId:userComputerId:sessionId:actionsAfterDownload:completionHandler:
// in order to delay 1.0 second to invoke after canceling existing download task.
- (void)internalDownlaodFileWithURLSession:(NSURLSession *)urlSession
                               transferKey:(NSString *)transferKey
                            realServerPath:(NSString *)realServerPath
                             fileSeparator:(NSString *)fileSeparator
                           downloadGroupId:(NSString *)downloadGroupId
                            userComputerId:(NSString *)userComputerId
                                 sessionId:(NSString *)sessionId
                      actionsAfterDownload:(NSString *_Nullable)actionsAfterDownload
       addToStartTimestampWithMilliseconds:(unsigned long)millisecondsToAdd
                         completionHandler:(void (^ _Nullable)(void))completionHandler {
    NSError *findError;
    HierarchicalModelDao *hierarchicalModelDao = [[HierarchicalModelDao alloc] init];
    HierarchicalModelWithoutManaged *hierarchicalModel = [hierarchicalModelDao findHierarchicalModelForUserComputer:userComputerId realServerPath:realServerPath fileSeparator:fileSeparator error:&findError];

    if (hierarchicalModel) {
        NSString *localPath = [DirectoryService localPathFromRealServerPath:realServerPath fileSeparator:fileSeparator];

        FileTransferWithoutManaged *fileTransferWithoutManaged = [[FileTransferWithoutManaged alloc] initWithUserComputerId:userComputerId
                                                                                                            downloadGroupId:downloadGroupId
                                                                                                                 serverPath:[DirectoryService serverPathFromParent:hierarchicalModel.parent name:hierarchicalModel.name fileSeparator:fileSeparator]
                                                                                                             realServerPath:realServerPath
                                                                                                                  localPath:localPath
                                                                                                                contentType:hierarchicalModel.contentType
                                                                                                                displaySize:hierarchicalModel.displaySize
                                                                                                                       type:hierarchicalModel.type
                                                                                                               lastModified:hierarchicalModel.lastModified
                                                                                                                     status:FILE_TRANSFER_STATUS_PROCESSING
                                                                                                                  totalSize:hierarchicalModel.sizeInBytes
                                                                                                            transferredSize:@0
                                                                                                             startTimestamp:[Utility currentJavaTimeMillisecondsWithMillisecondsToAdd:millisecondsToAdd]
                                                                                                               endTimestamp:@0
                                                                                                       actionsAfterDownload:actionsAfterDownload
                                                                                                                transferKey:transferKey
                                                                                                                     hidden:@NO
                                                                                                              waitToConfirm:@NO];

        // becasue the FileTransfer with the same realServerPath already deleted before invoking this method,
        // it can only 'create' ,instead of 'update' FileTransfer
        [self.fileTransferDao createOrUpdateFileTransferFromFileTransferWithoutManaged:fileTransferWithoutManaged];

        // update correspondent HierarchicalModels
        // the realServerPath in HierarchicalModels may nil now, so we found them by using realParent and realName, instead of realServerPath
        [self.hierarchicalModelDao updateDownloadInformationToHierarchicalModelsFromFileTransferWithoutManaged:fileTransferWithoutManaged findHierarchicalModelsByRealServerPath:NO fileSeparator:fileSeparator];

//        // DEBUG: Make sure the HierarchicalModel updated with download information
//        HierarchicalModelWithoutManaged *hierarchicalModelWithoutManaged = [self.hierarchicalModelDao findHierarchicalModelForUserComputer:userComputerId realServerPath:realServerPath fileSeparator:fileSeparator error:NULL];
//        NSLog(@"Updated to %@", hierarchicalModelWithoutManaged);

        // new download task

        NSString *encodedTransferKey = [transferKey stringByReplacingOccurrencesOfString:@"+" withString:@"%2B"];

        NSDictionary *parameters = @{@"t" : encodedTransferKey};

        NSString *urlString = [Utility composeLugServerURLStringWithPath:@"directory/ddownload3" parameters:parameters];

        NSURLRequestCachePolicy cachePolicy = NSURLRequestUseProtocolCachePolicy;

        NSTimeInterval timeInterval = CONNECTION_TIME_INTERVAL_FOR_BACKGROUND_DOWNLOAD;

        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:cachePolicy timeoutInterval:timeInterval];

        [request setHTTPMethod:@"GET"];

        [request setValue:@"gzip, deflate" forHTTPHeaderField:@"Accept-Encoding"];

        [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];

        NSURLSessionDownloadTask *newDownloadTask = [urlSession downloadTaskWithRequest:request];

        NSString *taskDescription = [self taskDescriptionFromTransferKey:transferKey realFilename:[localPath lastPathComponent]];

        [newDownloadTask setTaskDescription:taskDescription];

        [newDownloadTask resume];

        if (completionHandler) {
            completionHandler();
        }
    } else {
        NSLog(@"Download failed for hierarchical model not found for real server path: %@", realServerPath);
    }
}

- (void)resumeDownloadWithURLSession:(NSURLSession *)urlSession
                        realFilePath:(NSString *)realServerPath
                          resumeData:(NSData *_Nullable)resumeData
                   completionHandler:(void (^ _Nullable)(void))completionHandler {
    if (realServerPath) {
        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSString *userComputerId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

        if (userComputerId) {
            FileTransferWithoutManaged *foundFileTransferWithoutManaged = [self.fileTransferDao findFileTransferForUserComputer:userComputerId realServerPath:realServerPath error:NULL];

            if (foundFileTransferWithoutManaged) {
                if (resumeData) {
                    foundFileTransferWithoutManaged.status = FILE_TRANSFER_STATUS_PROCESSING;

                    [self.fileTransferDao updateFileTransfer:foundFileTransferWithoutManaged completionHandler:^{
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            // update correspondent HierarchicalModels with the specified realServerPath
                            // the value of realServerPath in HierarchicalModels should exist now, so we found them by using realServerPath
                            // no need to provide fileSeparator if found by realServerPath
                            [self.hierarchicalModelDao updateDownloadInformationToHierarchicalModelsFromFileTransferWithoutManaged:foundFileTransferWithoutManaged findHierarchicalModelsByRealServerPath:YES fileSeparator:nil];

                            NSURLSessionDownloadTask *newDownloadTask = [urlSession downloadTaskWithResumeData:resumeData];

                            NSString *transferKey = foundFileTransferWithoutManaged.transferKey;
                            NSString *localPath = foundFileTransferWithoutManaged.localPath;
                            NSString *taskDescription = [self taskDescriptionFromTransferKey:transferKey realFilename:[localPath lastPathComponent]];

                            [newDownloadTask setTaskDescription:taskDescription];

                            [newDownloadTask resume];

                            if (completionHandler) {
                                completionHandler();
                            }
                        });
                    }];
                } else {
                    NSLog(@"resumeData can't be nil.");
                }
            }
        }
    }
}

- (void)cancelDownloadWithURLSession:(NSURLSession *)urlSession
                         transferKey:(NSString *)transferKey
                   completionHandler:(void (^ _Nullable)(void))completionHandler {
    if (transferKey) {
        FileTransferWithoutManaged *fileTransferWithoutManaged = [self.fileTransferDao findFileTransferForTransferKey:transferKey error:NULL];

        if (fileTransferWithoutManaged) {
            // Change download status
            // do nothing if download status is failure, success or canceling

            NSString *downloadStatus = fileTransferWithoutManaged.status;

            if (!downloadStatus || (![downloadStatus isEqualToString:FILE_TRANSFER_STATUS_SUCCESS] && ![downloadStatus isEqualToString:FILE_TRANSFER_STATUS_FAILED])) {
                fileTransferWithoutManaged.status = FILE_TRANSFER_STATUS_FAILED;

                [self.fileTransferDao updateFileTransfer:fileTransferWithoutManaged];

                HierarchicalModelWithoutManaged *hierarchicalModelWithoutManaged = [self.hierarchicalModelDao findHierarchicalModelForTransferKey:transferKey error:NULL];

                if (hierarchicalModelWithoutManaged) {
                    NSString *downloadStatus2 = hierarchicalModelWithoutManaged.status;

                    if (!downloadStatus2 || (![downloadStatus2 isEqualToString:FILE_TRANSFER_STATUS_SUCCESS] && ![downloadStatus2 isEqualToString:FILE_TRANSFER_STATUS_FAILED])) {
                        // update correspondent HierarchicalModels with the specified realServerPath
                        // the value of realServerPath in HierarchicalModels should exist now, so we found them by using realServerPath
                        // no need to provide fileSeparator if found by realServerPath
                        [self.hierarchicalModelDao updateDownloadInformationToHierarchicalModelsFromFileTransferWithoutManaged:fileTransferWithoutManaged findHierarchicalModelsByRealServerPath:YES fileSeparator:nil];
                    }
                }
            }
        }

        [self findDownloadTaskWithURLSession:urlSession transferKey:transferKey completionHandler:^(NSURLSessionDownloadTask *downloadTask) {
            if (downloadTask) {
                // DO NOT empty task description here for
                // [self URLSession: task: didCompleteWithError:] will get no transfer key from here.

                // it's possible that fileTransferWithoutManaged may be nil because new transfer key is updated for a new download

                if (fileTransferWithoutManaged) {
                    [downloadTask cancelByProducingResumeData:^(NSData *resumeData){
                        if (resumeData) {
                            [self addResumeData:resumeData toFileTransferWithTransferKey:transferKey completionHandler:nil];
                        }
                    }];
                } else {
                    [downloadTask cancel];
                }
            } else {
                // DEBUG
                NSLog(@"Download task NOT FOUND");
            }
            
            if (completionHandler) {
                completionHandler();
            }
        }];
    } else {
        if (completionHandler) {
            completionHandler();
        }
    }
}

- (void)cancelAllFilesDownloadingWithURLSession:(NSURLSession *)urlSession {
    [urlSession getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        if (downloadTasks && [downloadTasks count] > 0) {

            // downloadTasks contain any download tasks that you have created within the session,
            // not including any download tasks that have been invalidated after completing, failing, or being cancelled.

            for (NSURLSessionDownloadTask *task in downloadTasks) {
                NSString *foundTransferKey;
                NSString *foundRealFilename;

                [self separateTaskDescription:[task taskDescription] toTransferKey:&foundTransferKey andRealFilename:&foundRealFilename];

                if (foundTransferKey && foundRealFilename) {
                    FileTransferWithoutManaged *fileTransferWithoutManaged = [self.fileTransferDao findFileTransferForTransferKey:foundTransferKey error:NULL];

                    if (fileTransferWithoutManaged && ([fileTransferWithoutManaged.status isEqualToString:FILE_TRANSFER_STATUS_PREPARING] || [fileTransferWithoutManaged.status isEqualToString:FILE_TRANSFER_STATUS_PROCESSING])) {
                        NSURLSessionTaskState taskState = task.state;

                        if (taskState == NSURLSessionTaskStateRunning || taskState == NSURLSessionTaskStateSuspended) {
                            [task cancelByProducingResumeData:^(NSData *resumeData){
                                if (resumeData) {
                                    [self addResumeData:resumeData toFileTransferWithTransferKey:foundTransferKey completionHandler:nil];
                                }

                                // don't have to change the download status to canceling for URLSession:task:didCompleteWithError: will take over to change the status to failure.
                            }];
                        }
                    }
                }
            }
        }
    }];
}

#pragma mark - Manage resumeData

// append

- (void)addResumeData:(NSData *_Nullable)resumeData toFileTransferWithTransferKey:(NSString *)transferKey completionHandler:(void (^ _Nullable)(NSError *error))completionHandler {
    [self.fileTransferDao addResumeData:resumeData toFileTransferWithTransferKey:transferKey completionHandler:completionHandler];
}

// find

- (NSData *)resumeDataFromFileTransferWithTransferKey:(NSString *)transferKey error:(NSError *_Nullable __autoreleasing *_Nullable)error {
    return [self.fileTransferDao resumeDataFromFileTransferWithTransferKey:transferKey error:error];
}

// remove single record

- (void)removeResumeDataFromFileTransferWithTransferKey:(NSString *)transferKey completionHandler:(void (^ _Nullable)(NSError *_Nullable))completionHandler {
    [self.fileTransferDao removeResumeDataFromFileTransferWithTransferKey:transferKey completionHandler:completionHandler];
}

- (void)removeResumeDataWithRealServerPath:(NSString *)realServerPath userComputerId:(NSString *)userComputerId completionHandler:(void (^ _Nullable)(NSError *_Nullable))completionHandler {
    [self.fileTransferDao removeResumeDataWithRealServerPath:realServerPath userComputerId:userComputerId completionHandler:completionHandler];
}

#pragma mark - mimic NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite completionHandler:(void (^ _Nullable)(NSString *_Nullable, float, FileTransferWithoutManaged *_Nullable))completionHandler {
    NSString *transferKey;
    NSString *realFilename;

    [self separateTaskDescription:[downloadTask taskDescription] toTransferKey:&transferKey andRealFilename:&realFilename];

    if (transferKey) {
        FileTransferWithoutManaged *fileTransferWithoutManaged = [self.fileTransferDao findFileTransferForTransferKey:transferKey error:NULL];

        // 由於寫入DB的Queue允許執行緒，為避免在前面發生的下載進度比較後面才寫入，因此要控制寫入條件：
        // 1. 下載狀態在第一次執行此method前就已經被改為「處理中」，因此非「處理中」狀態時不處理。
        // 2. 下載檔案第一次被調用時，oldTransferredSize與oldTotalSize都是0
        // 3. 當已經記錄到100%，就不再記錄
        // 4. oldTransferredSize不可以大於或等於即將記錄的值
        // 5. 新下載百分比要比之前多 1% 以上才寫入DB，以降低與實際上傳情況的時間差
        if (fileTransferWithoutManaged.status && [fileTransferWithoutManaged.status isEqualToString:FILE_TRANSFER_STATUS_PROCESSING]) {
            NSNumber *oldTransferredSize = fileTransferWithoutManaged.transferredSize;
            NSNumber *oldTotalSize = fileTransferWithoutManaged.totalSize;

            if (oldTransferredSize && oldTotalSize
                    && ([oldTotalSize doubleValue] == 0 || [oldTransferredSize doubleValue] != [oldTotalSize doubleValue])
                    && [oldTransferredSize doubleValue] < totalBytesWritten) {
                float oldPercentage = [Utility divideDenominator:oldTotalSize byNumerator:oldTransferredSize];

                NSNumber *newTransferredSize = @(totalBytesWritten);
                NSNumber *newTotalSize = @(totalBytesExpectedToWrite);

                float newPercentage = [Utility divideDenominator:newTotalSize byNumerator:newTransferredSize];

                // when 'oldPercentage - newPercentage > 5.0f', it means downloading is restarted automatically

                if (newPercentage == 1.0f || newPercentage - oldPercentage > 0.01 || oldPercentage - newPercentage > 5.0f) {
                    fileTransferWithoutManaged.transferredSize = newTransferredSize;

                    fileTransferWithoutManaged.totalSize = newTotalSize;

                    if (![fileTransferWithoutManaged.status isEqualToString:FILE_TRANSFER_STATUS_CANCELING]) {
                        fileTransferWithoutManaged.status = FILE_TRANSFER_STATUS_PROCESSING;
                    }

                    [self.fileTransferDao updateFileTransfer:fileTransferWithoutManaged];

                    // skip update if already downloaded success, failed, canceling or the percentage is larger than the current value

                    HierarchicalModelWithoutManaged *hierarchicalModelWithoutManaged = [self.hierarchicalModelDao findHierarchicalModelForTransferKey:transferKey error:NULL];

                    if (hierarchicalModelWithoutManaged && [hierarchicalModelWithoutManaged.status isEqualToString:FILE_TRANSFER_STATUS_PROCESSING]) {
                        NSNumber *oldTransferredSize2 = hierarchicalModelWithoutManaged.transferredSize;
                        NSNumber *oldTotalSize2 = hierarchicalModelWithoutManaged.totalSize;

                        if (oldTransferredSize2 && oldTotalSize2
                                && ([oldTotalSize2 doubleValue] == 0 || [oldTransferredSize2 doubleValue] != [oldTotalSize2 doubleValue])
                                && [oldTransferredSize2 doubleValue] < totalBytesWritten) {
                            float oldPercentage2 = [Utility divideDenominator:oldTotalSize2 byNumerator:oldTransferredSize2];

                            if (newPercentage - oldPercentage2 > 0.01 || oldPercentage2 - newPercentage > 5.0f) {
                                // update correspondent HierarchicalModels with the specified realServerPath
                                // the value of realServerPath in HierarchicalModels should exist now, so we found them by using realServerPath
                                // no need to provide fileSeparator if found by realServerPath
                                [self.hierarchicalModelDao updateDownloadInformationToHierarchicalModelsFromFileTransferWithoutManaged:fileTransferWithoutManaged findHierarchicalModelsByRealServerPath:YES fileSeparator:nil];
                            }
                        }
                    }

                    if (completionHandler) {
                        completionHandler(realFilename, newPercentage, [fileTransferWithoutManaged copy]);
                    }

//                    NSDictionary *notificationDictionary = @{
//                            NOTIFICATION_KEY_DOWNLOAD_TRANSFER_KEY : transferKey,
//                            NOTIFICATION_KEY_DOWNLOAD_REAL_FILENAME : realFilename,
//                            NOTIFICATION_KEY_DOWNLOAD_TRANSFERRED_SIZE : newTransferredSize,
//                            NOTIFICATION_KEY_DOWNLOAD_TOTAL_SIZE : newTotalSize,
//                            NOTIFICATION_KEY_DOWNLOAD_PERCENTAGE : @(newPercentage)
//                    };
//
//                    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_NAME_FILE_DOWNLOAD_DID_WRITE_DATA object:nil userInfo:notificationDictionary];
                }

                // do nothing if the increase of percentage is less than 1 (except that it's a re-download)
            }
        } // do nothing if the status is not processing.
    } else {
        NSLog(@"Writing Downloaded data process error for no transfer key found");

        if (completionHandler) {
            completionHandler(nil, 0, nil);
        }
    }
}

// Invoked after calling downloadTaskWithResumeData: or downloadTaskWithResumeData:completionHandler:
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes completionHandler:(void (^ _Nullable)(NSString *_Nullable, FileTransferWithoutManaged *_Nullable))completionHandler {
//    NSLog(@"Download did resumed at: %qi/%qi", fileOffset, expectedTotalBytes);
    
    NSString *transferKey;
    NSString *realFilename;
    
    [self separateTaskDescription:[downloadTask taskDescription] toTransferKey:&transferKey andRealFilename:&realFilename];

    if (transferKey) {
        FileTransferWithoutManaged *fileTransferWithoutManaged = [self.fileTransferDao findFileTransferForTransferKey:transferKey error:NULL];

        /* change to permanent file path */
        fileTransferWithoutManaged.transferredSize = @(fileOffset);

        // expectedTotalBytes is the value of Content-Length, or 'NSURLSessionTransferSizeUnknown' if there's no Content-Length.
        // so it's not the length of whole file but the remaining length of the bytes to download
//            fileTransferWithoutManaged.totalSize = @(expectedTotalBytes);

        fileTransferWithoutManaged.status = FILE_TRANSFER_STATUS_PROCESSING;
        fileTransferWithoutManaged.waitToConfirm = @NO;

        [self.fileTransferDao updateFileTransfer:fileTransferWithoutManaged];

        // update correspondent HierarchicalModels with the specified realServerPath
        // the value of realServerPath in HierarchicalModels should exist now, so we found them by using realServerPath
        // no need to provide fileSeparator if found by realServerPath
        [self.hierarchicalModelDao updateDownloadInformationToHierarchicalModelsFromFileTransferWithoutManaged:fileTransferWithoutManaged findHierarchicalModelsByRealServerPath:YES fileSeparator:nil];

        if (completionHandler) {
            completionHandler(realFilename, [fileTransferWithoutManaged copy]);
        }

//        NSDictionary *notificationDictionary = @{
//                NOTIFICATION_KEY_DOWNLOAD_TRANSFER_KEY : transferKey,
//                NOTIFICATION_KEY_DOWNLOAD_REAL_FILENAME : realFilename,
//                NOTIFICATION_KEY_DOWNLOAD_TRANSFERRED_SIZE : @(fileOffset),
//                NOTIFICATION_KEY_DOWNLOAD_TOTAL_SIZE : @(expectedTotalBytes)
//        };
//
//        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_NAME_FILE_DOWNLOAD_DID_RESUME object:nil userInfo:notificationDictionary];
    } else {
        NSLog(@"Download resumed process error for no transfer key found");
    }
}

// Invoked only if the file download successfully, so don't have to consider partial content
// The second argument of the completionHandler will be nil if error on file moving.
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location completionHandler:(void (^ _Nullable)(NSString *_Nullable, NSString *_Nullable, FileTransferWithoutManaged *))completionHandler {
    double realReceivedBytes = [downloadTask countOfBytesReceived];
    double expectedReceivedBytes = [downloadTask countOfBytesExpectedToReceive];

    NSInteger statusCode = ((NSHTTPURLResponse *) [downloadTask response]).statusCode;

    if (realReceivedBytes == expectedReceivedBytes) {
        NSString *transferKey;
        NSString *realFilename;
        
        [self separateTaskDescription:[downloadTask taskDescription] toTransferKey:&transferKey andRealFilename:&realFilename];

        if (transferKey) {
            NSString *tempFilePath = [location path];

            FileTransferWithoutManaged *fileTransferWithoutManaged = [self.fileTransferDao findFileTransferForTransferKey:transferKey error:NULL];

            if (fileTransferWithoutManaged) {
                NSString *permanentFilePath = [DirectoryService absoluteFilePathFromLocalPath:fileTransferWithoutManaged.localPath userComputerId:fileTransferWithoutManaged.userComputerId];

                NSError *error;
                [DirectoryService moveFilePath:tempFilePath toPath:permanentFilePath replaceIfExists:YES error:&error];

                // There's no action needed to process when a file did finish downloading.
//                NSDictionary *notificationDictionary;

                if (!error) {
                    // set last modified date to file

                    NSDate *lastModifiedDate = [Utility dateFromString:fileTransferWithoutManaged.lastModified format:DATE_FORMAT_FOR_SERVER];

                    NSError *modifiedDateError;
                    [Utility updateLastModifiedDate:lastModifiedDate atPath:permanentFilePath error:&modifiedDateError];

                    if (modifiedDateError) {
                        NSLog(@"Error on updating last modified date.\n%@", modifiedDateError);
                    }

//                    notificationDictionary = @{
//                            NOTIFICATION_KEY_DOWNLOAD_TRANSFER_KEY : transferKey,
//                            NOTIFICATION_KEY_DOWNLOAD_REAL_FILENAME : realFilename,
//                            NOTIFICATION_KEY_DOWNLOAD_PERMANENT_FILE_PATH : permanentFilePath
//                    };
                } else {
                    NSLog(@"Error on moving file from temp file: %@ to permanent file: %@\n%@", tempFilePath, permanentFilePath, error);

                    /* save current status to db  */
                    fileTransferWithoutManaged.transferredSize = @([downloadTask countOfBytesReceived]);
                    fileTransferWithoutManaged.totalSize = @([downloadTask countOfBytesExpectedToReceive]);
                    fileTransferWithoutManaged.status = FILE_TRANSFER_STATUS_FAILED;
                    fileTransferWithoutManaged.endTimestamp = [Utility currentJavaTimeMilliseconds];

                    [self.fileTransferDao updateFileTransfer:fileTransferWithoutManaged];

                    // update correspondent HierarchicalModels with the specified realServerPath
                    // the value of realServerPath in HierarchicalModels should exist now, so we found them by using realServerPath
                    // no need to provide fileSeparator if found by realServerPath
                    [self.hierarchicalModelDao updateDownloadInformationToHierarchicalModelsFromFileTransferWithoutManaged:fileTransferWithoutManaged findHierarchicalModelsByRealServerPath:YES fileSeparator:nil];

//                    notificationDictionary = @{
//                            NOTIFICATION_KEY_DOWNLOAD_TRANSFER_KEY : transferKey,
//                            NOTIFICATION_KEY_DOWNLOAD_REAL_FILENAME : realFilename
//                    };
                }

                if (completionHandler) {
                    completionHandler(realFilename, permanentFilePath, [fileTransferWithoutManaged copy]);
                }

                // This notification works only when the application is active. It won't work if the application is in the background.
//                [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_NAME_FILE_DOWNLOAD_DID_FINISH object:nil userInfo:notificationDictionary];
            } else {
                // FileTransfer in db has been removed or updated its transfer key for some reason, so skip it
                NSLog(@"Failed to resume download task for Nil file object.");
//                NSLog(@"Nil FileTransfer for transfer key: %@", transferKey);
            }
        } else {
            NSLog(@"Download finished process error for no transfer key found");
        }
    } else {
        /* do not show alert view because the page contains multiple downloading.
         * If alert view shows, it may confuses user which download is failed because of this reason!
         */
//        NSLog(@"Failed to resume download for file size not expected.");
        NSString *errorReason = [NSString stringWithContentsOfURL:location encoding:NSUTF8StringEncoding error:NULL];

        NSString *errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Error Status:%ld%@", @""), statusCode, errorReason ? errorReason : @""];

        NSLog(@"%@:\n%@", NSLocalizedString(@"Downloaded failed", @""), errorMessage);
    }
}

#pragma mark - mimic NSURLSessionTaskDelegate

// If file downloaded successfully, invoked after URLSession:downloadTask:didFinishDownloadingToURL:.
// If file downloaded failed, invoked after error responsed.
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error completionHandler:(void (^ _Nullable)(NSString *_Nullable, FileTransferWithoutManaged *))completionHandler {
    /* find file transfer from db by server file path */

    NSString *transferKey;
    NSString *realFilename;
    
    [self separateTaskDescription:[task taskDescription] toTransferKey:&transferKey andRealFilename:&realFilename];
    
    // Update resumeData in db
    // Resumable download not supported in ios 10.0x and 10.1x due to incorrect format of resume data.
    if (error && [error userInfo] && ![Utility isDeviceVersion10Or10_1]) {
        NSLog(@"Download failed with error:\n%@", error.localizedDescription);
        
        // Find resumeData in NSError, if any
        NSData *resumeData = [error userInfo][NSURLSessionDownloadTaskResumeData];

        if (resumeData) {
            [self addResumeData:resumeData toFileTransferWithTransferKey:transferKey completionHandler:nil];

            // Do not have to remove the resume data in db now.
//        } else {
//            [self removeResumeDataFromFileTransferWithTransferKey:transferKey completionHandler:nil];
        }
    } else {
        [self removeResumeDataFromFileTransferWithTransferKey:transferKey completionHandler:nil];
    }

    if (transferKey && transferKey.length > 0) {
        NSInteger statusCode = ((NSHTTPURLResponse *) [task response]).statusCode;
        
        // DEBUG
//        NSLog(@"Response status: %ld\nheader fields:\n%@", (long)statusCode, ((NSHTTPURLResponse *) [task response]).allHeaderFields);

        FileTransferWithoutManaged *fileTransferWithoutManaged = [self.fileTransferDao findFileTransferForTransferKey:transferKey error:NULL];
        
        /* cancel task here if download not succeed */
        
        double realReceivedBytes = [task countOfBytesReceived];
        double expectedReceivedBytes = [task countOfBytesExpectedToReceive];

        // DEBUG: Check if the expectedReceivedBytes is the total size of the file even if it downloaded via resume data
//        NSLog(@"expected received bytes:'%g', real received bytes:'%g'", expectedReceivedBytes, realReceivedBytes);

        if (fileTransferWithoutManaged) {
            // Sometimes when the file download successfully, realReceivedBytes is not the same with expectedReceivedBytes.
            // It doesn't count to compare the two values to decide if it downloads successfully.

//            NSString *localPath = fileTransferWithoutManaged.localPath;

            if ((statusCode != 200 && statusCode != 206) || error) {
                // save current status to db
                fileTransferWithoutManaged.transferredSize = @(realReceivedBytes);
                fileTransferWithoutManaged.totalSize = @(expectedReceivedBytes);
                fileTransferWithoutManaged.status = FILE_TRANSFER_STATUS_FAILED;
                fileTransferWithoutManaged.endTimestamp = [Utility currentJavaTimeMilliseconds];
                fileTransferWithoutManaged.waitToConfirm = @YES;
                
                [self.fileTransferDao updateFileTransfer:fileTransferWithoutManaged completionHandler:^{
                    // update correspondent HierarchicalModels with the specified realServerPath
                    // the value of realServerPath in HierarchicalModels should exist now, so we found them by using realServerPath
                    // no need to provide fileSeparator if found by realServerPath
                    [self.hierarchicalModelDao updateDownloadInformationToHierarchicalModelsFromFileTransferWithoutManaged:fileTransferWithoutManaged findHierarchicalModelsByRealServerPath:YES fileSeparator:nil];

                    // save status as failure to server
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        [self.directoryService confirmDownloadWithFileTransfer:fileTransferWithoutManaged tryAgainIfFailed:YES completionHandler:nil];
                    });

                    // TODO: Check if it prevents this invokation will be blocked by method "[self.fileTransferDao updateFileTransfer: completionHandler:]",
                    // this method is not invoked asynchronous with "[self.fileTransferDao updateFileTransfer: completionHandler:]"
                    if (completionHandler) {
                        completionHandler(realFilename, [fileTransferWithoutManaged copy]);
                    }
                }];
            } else {
                // download successfully without error
                // Sometimes when the file download successfully, realReceivedBytes is not the same with expectedReceivedBytes.
                
                /* save current status to db  */
                fileTransferWithoutManaged.transferredSize = @(realReceivedBytes);
                fileTransferWithoutManaged.totalSize = @(expectedReceivedBytes);
                fileTransferWithoutManaged.status = FILE_TRANSFER_STATUS_SUCCESS;
                fileTransferWithoutManaged.endTimestamp = [Utility currentJavaTimeMilliseconds];
                fileTransferWithoutManaged.waitToConfirm = @YES;
                
                [self.fileTransferDao updateFileTransfer:fileTransferWithoutManaged completionHandler:^{
                    // update correspondent HierarchicalModels with the specified realServerPath
                    // the value of realServerPath in HierarchicalModels should exist now, so we found them by using realServerPath
                    // no need to provide fileSeparator if found by realServerPath
                    [self.hierarchicalModelDao updateDownloadInformationToHierarchicalModelsFromFileTransferWithoutManaged:fileTransferWithoutManaged findHierarchicalModelsByRealServerPath:YES fileSeparator:nil];

                    // local notification, if any

                    // save status as success to server
                    
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        [self.directoryService confirmDownloadWithFileTransfer:fileTransferWithoutManaged tryAgainIfFailed:YES completionHandler:nil];
                    });

                    // TODO: Check if it prevents this invokation will be prevent this blocked by method "[self.fileTransferDao updateFileTransfer: completionHandler:]",
                    // this method is not invoked asynchronous with "[self.fileTransferDao updateFileTransfer: completionHandler:]"
                    if (completionHandler) {
                        completionHandler(realFilename, [fileTransferWithoutManaged copy]);
                    }
                }];

                // delete resumeData, if any
                [self removeResumeDataFromFileTransferWithTransferKey:transferKey completionHandler:nil];
            }
//        } else {
//            // FileTransfer in db has been removed or updated its transfer key for some reason, so skip it
//
//            NSLog(@"FileTransfer not found for transfer key: %@", transferKey);
        }
//    } else {
//        NSLog(@"Download completion process error for no transfer key found");
    }
}

@end
