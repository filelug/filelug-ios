#import <Photos/Photos.h>
#import "AssetUploadService.h"
#import "DirectoryService.h"
#import "AssetFileWithoutManaged.h"
#import "Utility.h"
#import "TmpUploadFileService.h"
#import "AssetFileDao.h"
#import "FileUploadStatusModel.h"
#import "FileTransferWithoutManaged.h"

@interface AssetUploadService ()

@property(nonatomic, nonnull, strong) AssetFileDao *assetFileDao;

@property(nonatomic, nonnull, strong) DirectoryService *directoryService;

@end

@implementation AssetUploadService {
}

+ (nonnull NSString *)taskDescriptionFromTransferKey:(NSString *)transferKey {
    return transferKey;
}

+ (nonnull NSString *)transferKeyFromTaskDescription:(NSString *)taskDescription {
    return taskDescription;
}

- (AssetFileDao *)assetFileDao {
    if (!_assetFileDao) {
        _assetFileDao = [[AssetFileDao alloc] init];
    }
    
    return _assetFileDao;
}

- (DirectoryService *)directoryService {
    if (!_directoryService) {
        _directoryService = [[DirectoryService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];
    }
    
    return _directoryService;
}

- (void)findUploadTaskWithTransferKey:(nonnull NSString *)transferKey urlSession:(NSURLSession *)urlSession completionHandler:(nonnull void (^)(NSURLSessionUploadTask *_Nullable uploadTask))completionHandler {
    [urlSession getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        NSURLSessionUploadTask *foundTask;

        if (uploadTasks && [uploadTasks count] > 0) {
            NSString *taskDescription = [AssetUploadService taskDescriptionFromTransferKey:transferKey];

            for (NSURLSessionUploadTask *task in uploadTasks) {
                if ([task.taskDescription isEqualToString:taskDescription]) {
                    foundTask = task;

                    break;
                }
            }
        }

        completionHandler(foundTask);
    }];
}

// Upload one file from the specified starting byte index
// The type of fileObject is different base on the sourceType:
// ASSET_FILE_SOURCE_TYPE_PHASSET       --> PHAsset (for iOS 8 or later)
// ASSET_FILE_SOURCE_TYPE_SHARED_FILE   --> FileTransferWithoutManaged, one of the downloaded file, may come from any user, and any computers of this device.
// ASSET_FILE_SOURCE_TYPE_EXTERNAL_FILE --> NSString, the absolute file path, e.g. {External_File_Folder}/IMG_7243.JPG
//
// For non-resume uploads, initiates and set an instance of FileUploadStatusModel with:
// FileUploadStatusModel *fileUploadStatusModel = [[FileUploadStatusModel alloc] initWithTransferKey:transferKey transferredSize:@0 fileSize:@0 fileLastModifiedDate:@0];
// if file not found, an error received in completionHandler
- (void)uploadFileWithURLSession:(NSURLSession *)urlSession
                      fileObject:(id)fileObject
                      sourceType:(NSNumber *)sourceType
                       sessionId:(NSString *)sessionId
               fileUploadGroupId:(NSString *)fileUploadGroupId
                       directory:(NSString *)directory
                        filename:(NSString *)filename
   shouldCheckIfLocalFileChanged:(BOOL)shouldCheckIfLocalFileChanged
           fileUploadStatusModel:(FileUploadStatusModel *)fileUploadStatusModel
 addToStartTimestampWithMillisec:(unsigned long)millisecondsToAdd
               completionHandler:(void (^ _Nullable)(NSError *_Nullable))completionHandler {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *userComputerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

    NSString *transferKey = fileUploadStatusModel.transferKey;

    NSNumber *transferredSize = fileUploadStatusModel.transferredSize;

    if ([transferredSize integerValue] < 0) {
        transferredSize = @0;
    }

    NSNumber *originalFileSize = fileUploadStatusModel.fileSize;

    NSNumber *originalLastModifiedInMillis = fileUploadStatusModel.fileLastModifiedDate;
    
    __block NSString *fileAbsolutePath;
    
    __block UIImage *thumbnail;
    
    __block NSString *fileContentType;

    __block NSNumber *fileNewTotalSize;

    __block NSDate *fileNewLastModifiedDate;
    
    // for insert data to db,
    // for file-sharing, it is relative path, not absolute path
    // for PHAsset, it is the local identifier
    // for ALAsset, it is the asset url absolute string
    __block NSString *assetURL;

    // For sourceType ASSET_FILE_SOURCE_TYPE_SHARED_FILE, the value is the FileTransfer.transferKey
    __block NSString *downloadedFileTransferKey;

    __block BOOL uploadWithoutFileContent = NO;
    
    __block BOOL dataPreparedToUpload = NO;
    
    NSUInteger sourceTypeInteger = [sourceType unsignedIntegerValue];

    // check if local file has been changed since last time uploaded for resume upload

    BOOL (^checkIfLocalFileChanged)(void) = ^BOOL() {
        return (!originalFileSize || !fileNewTotalSize  || ![originalFileSize isEqualToNumber:fileNewTotalSize]
                || !originalLastModifiedInMillis || !fileNewLastModifiedDate || ![originalLastModifiedInMillis isEqualToNumber:[Utility javaTimeMillisecondsFromDate:fileNewLastModifiedDate]]);
    };

    if (ASSET_FILE_SOURCE_TYPE_PHASSET == sourceTypeInteger) {
        PHAsset *phAsset = (PHAsset *) fileObject;
        
        assetURL = phAsset.localIdentifier;

        fileNewLastModifiedDate = phAsset.modificationDate;

        if (!fileNewLastModifiedDate) {
            fileNewLastModifiedDate = phAsset.creationDate;
        }
        
        // backgroound fetch do not allow upload file content directly,
        // so save to temp file and then upload using stream
        
        NSString *tmpFilename = [Utility tmpUploadFilenameWithFilename:filename];
        
        fileAbsolutePath = [[Utility parentPathToTmpUploadFile] stringByAppendingPathComponent:tmpFilename];

        // request options for thumbnail
        PHImageRequestOptions *thumbnailOptions = [Utility imageRequestOptionsWithAsset:phAsset];

        [[PHImageManager defaultManager] requestImageForAsset:phAsset
                                                   targetSize:[Utility thumbnailSizeForUploadFileTableViewCellImage]
                                                  contentMode:PHImageContentModeAspectFit
                                                      options:thumbnailOptions
                                                resultHandler:^(UIImage *result, NSDictionary *info) {
                                                    thumbnail = result;
                                                }];

        // Diff slow motion video from normal video, ref:
        // (1) http://stackoverflow.com/questions/26549938/how-can-i-determine-file-size-on-disk-of-a-video-phasset-in-ios8
        // (2) https://overflow.buffer.com/2016/02/29/slow-motion-video-ios/

        PHAssetMediaType phAssetMediaType = phAsset.mediaType;

        // For Slow-Mo video, phAsset.mediaSubtypes == PHAssetMediaSubtypeVideoHighFrameRate

        if (phAssetMediaType == PHAssetMediaTypeVideo || phAssetMediaType == PHAssetMediaTypeAudio) {

            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

            PHVideoRequestOptions *videoRequestOptions = [[PHVideoRequestOptions alloc] init];
            videoRequestOptions.networkAccessAllowed = YES;

            // Use AVComposition, instead of AVURLAsset to export a video that can play the slow-mo in Windows Media Play and VLC
            videoRequestOptions.version = PHVideoRequestOptionsVersionCurrent; // the type of the slow-mo video is AVComposition

            [[PHImageManager defaultManager] requestAVAssetForVideo:phAsset options:videoRequestOptions resultHandler:^(AVAsset *avAsset, AVAudioMix *audioMix, NSDictionary *info) {
                // For non-slow-mo video, avAsset is type of AVURLAsset,
                // for slow-mo video, asAsset is type of AVComposition

                if ([avAsset isKindOfClass:[AVComposition class]]) {
                    // slow-mo video

                    AVComposition *avComposition = (AVComposition *) avAsset;

                    NSArray<AVCompositionTrack *> *avCompositionTracks = avComposition.tracks;

                    for (AVCompositionTrack *avCompositionTrack in avCompositionTracks) {
                        NSString *avCompositionTrackMediaType = avCompositionTrack.mediaType;

                        if ([avCompositionTrackMediaType isEqualToString:AVMediaTypeVideo]) {
                            NSString *presetName;

                            if ([Utility isDeviceVersion9OrLater]) {
                                presetName = AVAssetExportPreset3840x2160;
                            } else {
                                presetName = AVAssetExportPresetHighestQuality;
                            }

                            AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:avComposition presetName:presetName];
                            exporter.outputURL = [NSURL fileURLWithPath:fileAbsolutePath];
                            exporter.outputFileType = AVFileTypeQuickTimeMovie;
                            exporter.shouldOptimizeForNetworkUse = YES;

                            dispatch_semaphore_t exportSemaphore = dispatch_semaphore_create(0);

                            [exporter exportAsynchronouslyWithCompletionHandler:^{
                                if (exporter.status == AVAssetExportSessionStatusCompleted) {
                                    NSURL *avCompositeOutputURL = exporter.outputURL;

                                    // file size

                                    NSNumber *size;

                                    [avCompositeOutputURL getResourceValue:&size forKey:NSURLFileSizeKey error:NULL];

                                    fileNewTotalSize = size;

                                    // data UTI

                                    NSString *dataUTI;

                                    [avCompositeOutputURL getResourceValue:&dataUTI forKey:NSURLTypeIdentifierKey error:NULL];

                                    if (dataUTI) {
                                        fileContentType = [Utility fileContentTypeWithFileDataUTI:dataUTI];
                                    }

                                    dataPreparedToUpload = YES;

                                    // Check if need partial copy

                                    if (transferredSize && [transferredSize longLongValue] > 0) {
                                        // Make sure local file not changed
                                        if (shouldCheckIfLocalFileChanged && checkIfLocalFileChanged()) {
                                            dataPreparedToUpload = NO;

                                            if (completionHandler) {
                                                NSString *errorMessage = [NSString stringWithFormat:NSLocalizedString(@"File %@ has been changed. Need delete and upload again.", @""), filename];
                                                NSError *notSupportedFileError = [Utility errorWithErrorCode:ERROR_CODE_DATA_INTEGRITY_KEY localizedDescription:errorMessage];

                                                completionHandler(notSupportedFileError);
                                            }
                                        } else {
                                            // Check if file already uploaded to server last time before resume uploading
                                            // so no file needs to include in the upload body

                                            if ([originalFileSize isEqualToNumber:transferredSize]) {
                                                uploadWithoutFileContent = YES;
                                            } else {
                                                NSString *tmpPartialFilename = [Utility tmpUploadFilenameWithFilename:filename];

                                                NSString *partialFileAbsolutePath = [[Utility parentPathToTmpUploadFile] stringByAppendingPathComponent:tmpPartialFilename];

                                                [Utility copyFileWithSourceFilePath:fileAbsolutePath startFromByteIndex:transferredSize toDestinationFilePath:partialFileAbsolutePath completionHandler:^(NSError *copyError) {
                                                    if (copyError) {
                                                        dataPreparedToUpload = NO;

                                                        if (completionHandler) {
                                                            completionHandler(copyError);
                                                        }
                                                    } else {
                                                        // add filename to tmpUploadFile dictionary with the transfer key
                                                        [[TmpUploadFileService defaultService] setTmpUploadFileAbsolutePath:partialFileAbsolutePath forTransferKey:transferKey];
                                                    }

                                                    [[NSFileManager defaultManager] removeItemAtPath:fileAbsolutePath error:NULL];
                                                }];
                                            }
                                        }
                                    } else {
                                        // add filename to tmpUploadFile dictionary with the transfer key
                                        [[TmpUploadFileService defaultService] setTmpUploadFileAbsolutePath:fileAbsolutePath forTransferKey:transferKey];
                                    }
                                }

                                dispatch_semaphore_signal(exportSemaphore);
                            }];

                            dispatch_semaphore_wait(exportSemaphore, DISPATCH_TIME_FOREVER);

                            break;
                        }
                    }
                } else if ([avAsset isKindOfClass:[AVURLAsset class]]) {
                    // normal video

                    AVURLAsset *avurlAsset = (AVURLAsset *) avAsset;

                    // file size

                    NSNumber *size;

                    [avurlAsset.URL getResourceValue:&size forKey:NSURLFileSizeKey error:NULL];

                    fileNewTotalSize = size;

                    // file UTI

                    NSString *dataUTI;

                    [avurlAsset.URL getResourceValue:&dataUTI forKey:NSURLTypeIdentifierKey error:NULL];

                    if (dataUTI) {
                        fileContentType = [Utility fileContentTypeWithFileDataUTI:dataUTI];
                    }

                    // file content

                    dataPreparedToUpload = YES;

                    // Check if need partial copy

                    if (transferredSize && [transferredSize longLongValue] > 0) {
                        // Make sure local file not changed
                        if (shouldCheckIfLocalFileChanged && checkIfLocalFileChanged()) {
                            dataPreparedToUpload = NO;

                            if (completionHandler) {
                                NSString *errorMessage = [NSString stringWithFormat:NSLocalizedString(@"File %@ has been changed. Need delete and upload again.", @""), filename];
                                NSError *notSupportedFileError = [Utility errorWithErrorCode:ERROR_CODE_DATA_INTEGRITY_KEY localizedDescription:errorMessage];

                                completionHandler(notSupportedFileError);
                            }
                        } else {

                            // Check if file already uploaded to server last time before resume uploading
                            // so no file needs to include in the upload body

                            if ([originalFileSize isEqualToNumber:transferredSize]) {
                                uploadWithoutFileContent = YES;
                            } else {
                                NSData *avData = [NSData dataWithContentsOfURL:avurlAsset.URL];

                                [Utility copyFileWithSourceData:avData startFromByteIndex:transferredSize toDestinationFilePath:fileAbsolutePath completionHandler:^(NSError *copyError) {
                                    if (copyError) {
                                        dataPreparedToUpload = NO;

                                        if (completionHandler) {
                                            completionHandler(copyError);
                                        }
                                    } else {
                                        // add filename to tmpUploadFile dictionary with the transfer key
                                        [[TmpUploadFileService defaultService] setTmpUploadFileAbsolutePath:fileAbsolutePath forTransferKey:transferKey];
                                    }
                                }];
                            }
                        }
                    } else {
                        NSData *avData = [NSData dataWithContentsOfURL:avurlAsset.URL];

                        [avData writeToFile:fileAbsolutePath atomically:NO];

                        // add filename to tmpUploadFile dictionary with the transfer key
                        [[TmpUploadFileService defaultService] setTmpUploadFileAbsolutePath:fileAbsolutePath forTransferKey:transferKey];
                    }
                } else {
                    // Unknown video
                    NSLog(@"Unkown video type of %@", [avAsset class]);
                }

                dispatch_semaphore_signal(semaphore);
            }];

            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        } else {
            // options that do not crop image to square
            PHImageRequestOptions *originalImageDataOptions = [[PHImageRequestOptions alloc] init];
            originalImageDataOptions.resizeMode = PHImageRequestOptionsResizeModeExact;
            originalImageDataOptions.synchronous = YES;
            originalImageDataOptions.networkAccessAllowed = YES;

            [[PHImageManager defaultManager] requestImageDataForAsset:phAsset options:originalImageDataOptions resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
                NSError *requestError = info[PHImageErrorKey];

                if (requestError) {
                    NSLog(@"Error on requesting image data.\n%@", [requestError userInfo]);
                } else {
                    // file size

                    fileNewTotalSize = @(imageData.length);

                    // file UTI

                    fileContentType = [Utility fileContentTypeWithFileDataUTI:dataUTI];

                    // file content

                    dataPreparedToUpload = YES;

                    // Check if need partial copy

                    if (transferredSize && [transferredSize longLongValue] > 0) {
                        // Make sure local file not changed
                        if (shouldCheckIfLocalFileChanged && checkIfLocalFileChanged()) {
                            dataPreparedToUpload = NO;

                            if (completionHandler) {
                                NSString *errorMessage = [NSString stringWithFormat:NSLocalizedString(@"File %@ has been changed. Need delete and upload again.", @""), filename];
                                NSError *notSupportedFileError = [Utility errorWithErrorCode:ERROR_CODE_DATA_INTEGRITY_KEY localizedDescription:errorMessage];

                                completionHandler(notSupportedFileError);
                            }
                        } else {
                            // Check if file already uploaded to server last time before resume uploading
                            // so no file needs to include in the upload body

                            if ([originalFileSize isEqualToNumber:transferredSize]) {
                                uploadWithoutFileContent = YES;
                            } else {
                                [Utility copyFileWithSourceData:imageData startFromByteIndex:transferredSize toDestinationFilePath:fileAbsolutePath completionHandler:^(NSError *copyError) {
                                    if (copyError) {
                                        dataPreparedToUpload = NO;

                                        if (completionHandler) {
                                            completionHandler(copyError);
                                        }
                                    } else {
                                        // add filename to tmpUploadFile dictionary with the transfer key
                                        [[TmpUploadFileService defaultService] setTmpUploadFileAbsolutePath:fileAbsolutePath forTransferKey:transferKey];
                                    }
                                }];
                            }
                        }
                    } else {
                        [imageData writeToFile:fileAbsolutePath atomically:NO];

                        // add filename to tmpUploadFile dictionary with the transfer key
                        [[TmpUploadFileService defaultService] setTmpUploadFileAbsolutePath:fileAbsolutePath forTransferKey:transferKey];
                    }
                }
            }];
        }
    }  else if (ASSET_FILE_SOURCE_TYPE_SHARED_FILE == sourceTypeInteger) {
        // file from file-sharing
        
        // thumbnail is nil for files from file-sharing and external files
        
        FileTransferWithoutManaged *fileTransferWithoutManaged = (FileTransferWithoutManaged *) fileObject;

        NSString *absolutePath = [DirectoryService absoluteFilePathFromLocalPath:fileTransferWithoutManaged.localPath userComputerId:fileTransferWithoutManaged.userComputerId];

        fileNewTotalSize = @([Utility fileSizeWithAbsolutePath:absolutePath error:NULL]);

        fileNewLastModifiedDate = [Utility lastModifiedDateOfFilePath:absolutePath error:NULL];

        NSString *unescapedFileAbsolutePath = [absolutePath stringByRemovingPercentEncoding];
        
        if (!unescapedFileAbsolutePath) {
            unescapedFileAbsolutePath = [NSString stringWithString:absolutePath];
        }
        
        assetURL = fileTransferWithoutManaged.localPath;

        downloadedFileTransferKey = fileTransferWithoutManaged.transferKey;
        
        fileAbsolutePath = unescapedFileAbsolutePath;
        
        fileContentType = [Utility fileContentTypeWithFilePath:fileAbsolutePath];
        
        dataPreparedToUpload = YES;

        // Check if need partial copy

        if (transferredSize && [transferredSize longLongValue] > 0) {
            // Make sure local file not changed
            if (shouldCheckIfLocalFileChanged && checkIfLocalFileChanged()) {
                dataPreparedToUpload = NO;

                if (completionHandler) {
                    NSString *errorMessage = [NSString stringWithFormat:NSLocalizedString(@"File %@ has been changed. Need delete and upload again.", @""), filename];
                    NSError *notSupportedFileError = [Utility errorWithErrorCode:ERROR_CODE_DATA_INTEGRITY_KEY localizedDescription:errorMessage];

                    completionHandler(notSupportedFileError);
                }
            } else {
                // Check if file already uploaded to server last time before resume uploading
                // so no file needs to include in the upload body

                if ([originalFileSize isEqualToNumber:transferredSize]) {
                    uploadWithoutFileContent = YES;
                } else {
                    NSString *tmpPartialFilename = [Utility tmpUploadFilenameWithFilename:filename];

                    NSString *partialFileAbsolutePath = [[Utility parentPathToTmpUploadFile] stringByAppendingPathComponent:tmpPartialFilename];

                    [Utility copyFileWithSourceFilePath:fileAbsolutePath startFromByteIndex:transferredSize toDestinationFilePath:partialFileAbsolutePath completionHandler:^(NSError *copyError) {
                        if (copyError) {
                            dataPreparedToUpload = NO;

                            if (completionHandler) {
                                completionHandler(copyError);
                            }
                        } else {
                            fileAbsolutePath = partialFileAbsolutePath;

                            // add filename to tmpUploadFile dictionary with the transfer key
                            [[TmpUploadFileService defaultService] setTmpUploadFileAbsolutePath:fileAbsolutePath forTransferKey:transferKey];
                        }

                        // DON'T DELETE external files and shared files
                    }];
                }
            }
        }

        // DON'T DELETE external files and shared files
    } else if (ASSET_FILE_SOURCE_TYPE_EXTERNAL_FILE == sourceTypeInteger) {
        // file from external apps

        // thumbnail is nil for files from file-sharing and external files

        NSString *escapedfileAbsolutePath = (NSString *) fileObject;

        fileNewTotalSize = @([Utility fileSizeWithAbsolutePath:escapedfileAbsolutePath error:NULL]);

        fileNewLastModifiedDate = [Utility lastModifiedDateOfFilePath:escapedfileAbsolutePath error:NULL];

        NSString *unescapedFileAbsolutePath = [escapedfileAbsolutePath stringByRemovingPercentEncoding];

        if (!unescapedFileAbsolutePath) {
            unescapedFileAbsolutePath = [NSString stringWithString:escapedfileAbsolutePath];
        }

        assetURL = [unescapedFileAbsolutePath lastPathComponent];

        fileAbsolutePath = unescapedFileAbsolutePath;

        fileContentType = [Utility fileContentTypeWithFilePath:fileAbsolutePath];

        dataPreparedToUpload = YES;

        // Check if need partial copy

        if (transferredSize && [transferredSize longLongValue] > 0) {
            // Make sure local file not changed
            if (shouldCheckIfLocalFileChanged && checkIfLocalFileChanged()) {
                dataPreparedToUpload = NO;

                if (completionHandler) {
                    NSString *errorMessage = [NSString stringWithFormat:NSLocalizedString(@"File %@ has been changed. Need delete and upload again.", @""), filename];
                    NSError *notSupportedFileError = [Utility errorWithErrorCode:ERROR_CODE_DATA_INTEGRITY_KEY localizedDescription:errorMessage];

                    completionHandler(notSupportedFileError);
                }
            } else {
                // Check if file already uploaded to server last time before resume uploading
                // so no file needs to include in the upload body

                if ([originalFileSize isEqualToNumber:transferredSize]) {
                    uploadWithoutFileContent = YES;
                } else {
                    NSString *tmpPartialFilename = [Utility tmpUploadFilenameWithFilename:filename];

                    NSString *partialFileAbsolutePath = [[Utility parentPathToTmpUploadFile] stringByAppendingPathComponent:tmpPartialFilename];

                    [Utility copyFileWithSourceFilePath:fileAbsolutePath startFromByteIndex:transferredSize toDestinationFilePath:partialFileAbsolutePath completionHandler:^(NSError *copyError) {
                        if (copyError) {
                            dataPreparedToUpload = NO;

                            if (completionHandler) {
                                completionHandler(copyError);
                            }
                        } else {
                            fileAbsolutePath = partialFileAbsolutePath;

                            // add filename to tmpUploadFile dictionary with the transfer key
                            [[TmpUploadFileService defaultService] setTmpUploadFileAbsolutePath:fileAbsolutePath forTransferKey:transferKey];
                        }

                        // DON'T DELETE external files and shared files
                    }];
                }
            }
        }
    } else {
        NSLog(@"file identifier must be either type PHAsse, ALAsset, or NSString. The value of the NSString must be a file absolute path starting with '/'.\n%@", fileObject);

        if (completionHandler) {
            NSString *errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Unsupported file to upload with filename", @""), filename];
            NSError *notSupportedFileError = [Utility errorWithErrorCode:ERROR_CODE_UNSUPPORTED_FILE_TO_UPLOAD_KEY localizedDescription:errorMessage];

            completionHandler(notSupportedFileError);
        }
    }

    if (fileAbsolutePath) {
        if (uploadWithoutFileContent) {
            NSError *foundError;

            AssetFileWithoutManaged *currentUploadAssetFileWithoutManaged = [self.assetFileDao findAssetFileForTransferKey:transferKey error:&foundError];

            if (foundError) {
                NSLog(@"Error on finding current uploaing file with filename: '%@'\n%@", filename, [foundError userInfo]);
            }

            if (currentUploadAssetFileWithoutManaged) {
                currentUploadAssetFileWithoutManaged.endTimestamp = @0;
                currentUploadAssetFileWithoutManaged.status = FILE_TRANSFER_STATUS_PROCESSING;
                currentUploadAssetFileWithoutManaged.transferredSizeBeforeResume = transferredSize;

                NSUInteger startUploadingByteIndex = [transferredSize unsignedIntegerValue];

                [self.assetFileDao updateAssetFile:currentUploadAssetFileWithoutManaged completionHandler:^{
                    [self uploadFileWithURLSession:urlSession fileAbsolutePath:fileAbsolutePath uploadEmptyContent:YES toServerDirectory:directory filename:filename fileContentType:fileContentType transferKey:transferKey fileSize:fileNewTotalSize startUploadingByteIndex:startUploadingByteIndex fileLastModifiedDate:fileNewLastModifiedDate sessionId:sessionId completionHandler:completionHandler];
                }];
            }
        } else if (dataPreparedToUpload) {
            NSError *foundError;

            AssetFileWithoutManaged *currentUploadAssetFileWithoutManaged = [self.assetFileDao findAssetFileForTransferKey:transferKey error:&foundError];

            if (foundError) {
                NSLog(@"Error on finding current uploaing file with filename: '%@'\n%@", filename, [foundError userInfo]);
            }

            if (currentUploadAssetFileWithoutManaged) {
                currentUploadAssetFileWithoutManaged.endTimestamp = @0;
                currentUploadAssetFileWithoutManaged.status = FILE_TRANSFER_STATUS_PROCESSING;
                currentUploadAssetFileWithoutManaged.transferredSize = transferredSize;
                currentUploadAssetFileWithoutManaged.totalSize = fileNewTotalSize;
                currentUploadAssetFileWithoutManaged.transferredSizeBeforeResume = transferredSize;

                NSUInteger startUploadingByteIndex = [transferredSize unsignedIntegerValue];

                [self.assetFileDao updateAssetFile:currentUploadAssetFileWithoutManaged completionHandler:^{
                    [self uploadFileWithURLSession:urlSession fileAbsolutePath:fileAbsolutePath uploadEmptyContent:NO toServerDirectory:directory filename:filename fileContentType:fileContentType transferKey:transferKey fileSize:fileNewTotalSize startUploadingByteIndex:startUploadingByteIndex fileLastModifiedDate:fileNewLastModifiedDate sessionId:sessionId completionHandler:completionHandler];
                }];
            } else {
                AssetFileWithoutManaged *assetFileWithoutManaged =
                        [[AssetFileWithoutManaged alloc] initWithUserComputerId:userComputerId
                                                              fileUploadGroupId:fileUploadGroupId
                                                                    transferKey:transferKey
                                                                       assetURL:assetURL
                                                                     sourceType:[sourceType unsignedIntegerValue]
                                                                serverDirectory:directory
                                                                 serverFilename:filename
                                                                         status:FILE_TRANSFER_STATUS_PREPARING
                                                                      thumbnail:thumbnail
                                                                      totalSize:(fileNewTotalSize ? fileNewTotalSize : @0)
                                                                transferredSize:@0
                                                    transferredSizeBeforeResume:@0
                                                                 startTimestamp:[Utility currentJavaTimeMillisecondsWithMillisecondsToAdd:millisecondsToAdd]
                                                                   endTimestamp:@0
                                                                waitToConfirmed:@NO
                                                      downloadedFileTransferKey:downloadedFileTransferKey];

                [self.assetFileDao createAssetFileFromAssetFileWithoutManaged:assetFileWithoutManaged completionHandler:^{
                    [self uploadFileWithURLSession:urlSession fileAbsolutePath:fileAbsolutePath uploadEmptyContent:NO toServerDirectory:directory filename:filename fileContentType:fileContentType transferKey:transferKey fileSize:fileNewTotalSize startUploadingByteIndex:[transferredSize unsignedIntegerValue] fileLastModifiedDate:fileNewLastModifiedDate sessionId:sessionId completionHandler:completionHandler];
                }];
            }
        }
    }
}

- (void)uploadFileWithURLSession:(NSURLSession *)urlSession
                fileAbsolutePath:(NSString *)fileAbsolutePath
              uploadEmptyContent:(BOOL)uploadEmptyContent
               toServerDirectory:(NSString *)directory
                        filename:(NSString *)filename
                 fileContentType:(NSString *)fileContentType
                     transferKey:(NSString *)transferKey
                        fileSize:(NSNumber *)fileSize
         startUploadingByteIndex:(NSUInteger)startIndex
            fileLastModifiedDate:(NSDate *)fileLastModifiedDate
                       sessionId:(NSString *)sessionId
               completionHandler:(void (^)(NSError *))completionHandler {
    // fileAbsolutePath may not exists when uploadEmptyContent is YES

    if (uploadEmptyContent || [Utility fileExistsAtPath:fileAbsolutePath]) {
        NSString *uploadFileUrlPath = @"directory/dupload4";
        
        NSString *urlString = [Utility composeLugServerURLStringWithPath:uploadFileUrlPath];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:urlSession.configuration.requestCachePolicy timeoutInterval:urlSession.configuration.timeoutIntervalForRequest];
        
        [request setHTTPMethod:@"POST"];
        
        [request setValue:@"gzip, deflate" forHTTPHeaderField:@"Accept-Encoding"];
        
        // content-type
        
        if (fileContentType) {
            [request setValue:fileContentType forHTTPHeaderField:@"Content-Type"];
        }

        /*
         * Authorization
         * upkey
         * updir
         * upname
         * upsize
         * File-Last-Modified: timestamp (in milli-second)
         * File-Range: "bytes=32768-"
         * uploaded_but_uncomfirmed
         */

        // encode directory and filename using Base64 Using charset UTF-8
        [request setValue:[Utility encodeUsingBase64:directory] forHTTPHeaderField:HTTP_HEADER_NAME_UPLOAD_DIRECTORY];
        [request setValue:[Utility encodeUsingBase64:filename] forHTTPHeaderField:HTTP_HEADER_NAME_UPLOAD_FILE_NAME];

        [request setValue:[fileSize stringValue] forHTTPHeaderField:HTTP_HEADER_NAME_UPLOAD_FILE_SIZE];
        
        // upload key already a base64 string, encoded using UTF-8
        [request setValue:transferKey forHTTPHeaderField:HTTP_HEADER_NAME_UPLOAD_KEY];
        
        [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];

        if (startIndex > 0) {
            NSString *fileRangeValue = [NSString stringWithFormat:@"bytes=%lu-", (unsigned long) startIndex];

            [request setValue:fileRangeValue forHTTPHeaderField:HTTP_HEADER_NAME_FILE_RANGE];
        }

        if (fileLastModifiedDate) {
            // the value of last modified date should be type of timestamp

            NSString *fileLastModifiedInMillis = [Utility javaTimeMillisecondsStringFromDate:fileLastModifiedDate];

            [request setValue:fileLastModifiedInMillis forHTTPHeaderField:HTTP_HEADER_NAME_FILE_LAST_MODIFIED_DATE];
        } else {
            NSLog(@"last modified date must exist for file uploading!");
        }

        NSURLSessionUploadTask *newUploadTask;

        if (uploadEmptyContent) {
            [request setValue:[@1 stringValue] forHTTPHeaderField:HTTP_HEADER_NAME_UPLOADED_BUT_UNCONFIRMED];

            NSString *emptyFilePath = [Utility generateEmptyFilePathFromTmpUploadFilePath:fileAbsolutePath];

            [[NSFileManager defaultManager] createFileAtPath:emptyFilePath contents:[NSData new] attributes:nil];

            newUploadTask = [urlSession uploadTaskWithRequest:request fromFile:[NSURL fileURLWithPath:emptyFilePath isDirectory:NO]];
        } else {
            newUploadTask = [urlSession uploadTaskWithRequest:request fromFile:[NSURL fileURLWithPath:fileAbsolutePath isDirectory:NO]];
        }
        
        [newUploadTask setTaskDescription:[AssetUploadService taskDescriptionFromTransferKey:transferKey]];
        
        [newUploadTask resume];

        if (completionHandler) {
            completionHandler(nil);
        }
    } else {
        if (completionHandler) {
            NSString *message = [NSString stringWithFormat:NSLocalizedString(@"File %@ not exists and refresh", @""), [fileAbsolutePath lastPathComponent]];
            
            completionHandler([Utility errorWithErrorCode:NSFileNoSuchFileError localizedDescription:message]);
        }
    }
}

- (void)cancelUploadFileWithTransferKey:(NSString *)transferKey
                             urlSession:(NSURLSession *)urlSession
                      completionHandler:(void (^ _Nullable)(void))completionHandler {
    [self findUploadTaskWithTransferKey:transferKey urlSession:urlSession completionHandler:^(NSURLSessionUploadTask *uploadTask) {
        // find tmp filename in tmpUploadFile dictionary, remove the file and remove the value in the dictionary
        NSError *deleteError;
        [[TmpUploadFileService defaultService] removeTmpUploadFileAbsoluePathWithTransferKey:transferKey removeTmpUploadFile:YES deleteError:&deleteError];
        
        if (deleteError) {
            NSLog(@"[Cancel Upload]Error on deleting tmp file for transferKey: %@\nError:\n%@", transferKey, [deleteError userInfo]);
        }

        BOOL shouldInvokeCompletionHandler = YES;
        
        if (uploadTask) {
            [uploadTask cancel];
            
            /* clear transfer key from task description */
//            [Utility emptyTaskDescriptionForTask:uploadTask];
            
            NSError *fetchError;
            AssetFileWithoutManaged *assetFileWithoutManaged = [self.assetFileDao findAssetFileForTransferKey:transferKey error:&fetchError];
            
            if (assetFileWithoutManaged && (!assetFileWithoutManaged.status || [assetFileWithoutManaged.status isEqualToString:FILE_TRANSFER_STATUS_PROCESSING])) {
                assetFileWithoutManaged.status = FILE_TRANSFER_STATUS_CANCELING;

                shouldInvokeCompletionHandler = NO;

                if (completionHandler) {
                    [self.assetFileDao updateAssetFile:assetFileWithoutManaged completionHandler:completionHandler];
                } else {
                    [self.assetFileDao updateAssetFile:assetFileWithoutManaged];
                }
            } else if (fetchError) {
                NSLog(@"Error on finding asset file using transfer key: %@\n%@", transferKey, fetchError);
            }
        }
        
        if (shouldInvokeCompletionHandler && completionHandler) {
            completionHandler();
        }
    }];
}

#pragma mark - mimic NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *transferKey = [AssetUploadService transferKeyFromTaskDescription:[task taskDescription]];
        
        if (transferKey) {
            NSError *fetchError;
            AssetFileWithoutManaged *assetFileWithoutManaged = [self.assetFileDao findAssetFileForTransferKey:transferKey error:&fetchError];
            
            // 由於寫入DB的Queue允許執行緒，為避免在前面發生的上傳進度比較後面才寫入，因此要控制寫入條件：
            // 1. 上傳狀態在第一次執行此method前為「FILE_TRANSFER_STATUS_PREPARING」，
            //    因此只在狀態為「FILE_TRANSFER_STATUS_PREPARING」或「FILE_TRANSFER_STATUS_PROCESSING」狀態時才處理。
            // 2. 上傳檔案第一次被調用時，oldTransferredSize與oldTotalSize都是0
            // 3. 當已經記錄到100%，就不再記錄
            // 4. oldTransferredSize不可以大於或等於即將記錄的值
            // 5. 新上傳百分比要比之前多 1% 以上才寫入DB，以降低與實際上傳情況的時間差
            if (assetFileWithoutManaged.status && ([assetFileWithoutManaged.status isEqualToString:FILE_TRANSFER_STATUS_PROCESSING] || [assetFileWithoutManaged.status isEqualToString:FILE_TRANSFER_STATUS_PREPARING])) {

                void (^updateAssetFile)(NSNumber *, NSNumber *, NSNumber *, NSNumber *) = ^void(NSNumber *originalTotalSize, NSNumber *originalTransferredSize, NSNumber *currentTotalSize, NSNumber *currentTransferredSize) {
                    float oldPercentage = [Utility divideDenominator:originalTotalSize byNumerator:originalTransferredSize];

                    float newPercentage = [Utility divideDenominator:currentTotalSize byNumerator:currentTransferredSize];

                    if (newPercentage == 1.0f || newPercentage - oldPercentage > 0.01 || oldPercentage - newPercentage > 0.04) {
                        assetFileWithoutManaged.transferredSize = currentTransferredSize;

                        assetFileWithoutManaged.totalSize = currentTotalSize;

                        if (![assetFileWithoutManaged.status isEqualToString:FILE_TRANSFER_STATUS_CANCELING]) {
                            assetFileWithoutManaged.status = FILE_TRANSFER_STATUS_PROCESSING;
                        }

                        [self.assetFileDao updateAssetFile:assetFileWithoutManaged];
                    }
                };

                NSNumber *oldTransferredSize = assetFileWithoutManaged.transferredSize;
                NSNumber *oldTotalSize = assetFileWithoutManaged.totalSize;

                NSNumber *transferredSizeBeforeResume = assetFileWithoutManaged.transferredSizeBeforeResume;

                if (transferredSizeBeforeResume && [transferredSizeBeforeResume unsignedIntegerValue] > 0) {
                    // for resume upload

                    if (oldTransferredSize && oldTotalSize
                            && ([oldTotalSize doubleValue] == 0 || [oldTransferredSize doubleValue] != [oldTotalSize doubleValue])
                            && [oldTransferredSize doubleValue] < [oldTotalSize doubleValue]) {
                        NSNumber *newTransferredSize = @(totalBytesSent + [transferredSizeBeforeResume unsignedIntegerValue]);
                        NSNumber *newTotalSize = oldTotalSize;

                        updateAssetFile(oldTotalSize, oldTransferredSize, newTotalSize, newTransferredSize);
                    }
                } else {
                    // for non-resume upload

                    if (oldTransferredSize && oldTotalSize
                            && ([oldTotalSize doubleValue] == 0 || [oldTransferredSize doubleValue] != [oldTotalSize doubleValue])
                            && [oldTransferredSize doubleValue] < totalBytesSent) {
                        NSNumber *newTransferredSize = @(totalBytesSent);
                        NSNumber *newTotalSize = @(totalBytesExpectedToSend);

                        updateAssetFile(oldTotalSize, oldTransferredSize, newTotalSize, newTransferredSize);
                    }
                }
            }
        }
    });
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *_Nullable)error {
    dispatch_queue_t gQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_async(gQueue, ^{
        NSString *transferKey = [AssetUploadService transferKeyFromTaskDescription:[task taskDescription]];
        
        // DEBUG
        // task state:
        // NSURLSessionTaskStateRunning = 0,
        // NSURLSessionTaskStateSuspended = 1,
        // NSURLSessionTaskStateCanceling = 2,
        // NSURLSessionTaskStateCompleted = 3,
//        NSLog(@"Transfer key: '%@', Task state: '%@', Response code: '%@'", transferKey, [@([task state]) stringValue], [@(((NSHTTPURLResponse *) [task response]).statusCode) stringValue]);
        
        /* clear task description */
//        [Utility emptyTaskDescriptionForTask:task];
        
        if (transferKey && transferKey.length > 0) {
            NSError *fetchError;
            AssetFileWithoutManaged *assetFileWithoutManaged = [self.assetFileDao findAssetFileForTransferKey:transferKey error:&fetchError];
            
            if (assetFileWithoutManaged) {
                NSInteger statusCode = ((NSHTTPURLResponse *) [task response]).statusCode;
                
                int64_t realSentBytes = [task countOfBytesSent];
                int64_t expectedSentBytes = [task countOfBytesExpectedToSend];

                NSNumber *transferredSizeBeforeResume = assetFileWithoutManaged.transferredSizeBeforeResume;
                
                // Sometimes when the file uploaded successfully, realSentBytes is not the same with expectedSentBytes.
                // It doesn't count to compare the two values to decide if it uploads successfully.
                // If realSentBytes is different than expectedSentBytes,
                // change the status to FILE_TRANSFER_STATUS_CONFIRMING and let the repository decides.
                
                if (statusCode != 200 || error) {
//                    if (error) {
//                        NSLog(@"Failed to upload file with upload key: %@, asset url: %@ to directory: %@, file name: %@, error: %@, ", transferKey, assetFileWithoutManaged.assetURL, assetFileWithoutManaged.serverDirectory, assetFileWithoutManaged.serverFilename, error);
//                    } else {
//                        NSLog(@"Failed to upload file with upload key: %@, asset url: %@ to directory: %@, file name: %@. Real bytes sent %lld; expected bytes sent %lld ", transferKey, assetFileWithoutManaged.assetURL, assetFileWithoutManaged.serverDirectory, assetFileWithoutManaged.serverFilename, realSentBytes, expectedSentBytes);
//                    }

                    // update upload status to db

                    if (!transferredSizeBeforeResume || [transferredSizeBeforeResume unsignedIntegerValue] == 0) {
                        // for non-resume upload

                        assetFileWithoutManaged.transferredSize = @(realSentBytes);
                        assetFileWithoutManaged.totalSize = @(expectedSentBytes);
                    } else {
                        // for resume upload

                        assetFileWithoutManaged.transferredSize = @(realSentBytes + [transferredSizeBeforeResume unsignedIntegerValue]);
                    }

                    assetFileWithoutManaged.status = FILE_TRANSFER_STATUS_FAILED;
                    assetFileWithoutManaged.endTimestamp = [Utility currentJavaTimeMilliseconds];
                    assetFileWithoutManaged.waitToConfirm = @NO;
                    
                    [self.assetFileDao updateAssetFile:assetFileWithoutManaged completionHandler:^(){
                        dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (DELAY_CONFIRM_UPLOAD_INTERVAL * NSEC_PER_SEC));
                        dispatch_after(delayTime, gQueue, ^(void) {
                            NSDictionary *dictionary = @{assetFileWithoutManaged.transferKey : assetFileWithoutManaged.status};

                            [self.directoryService confirmUploadWithTransferKeyAndStatusDictionary:dictionary tryAgainIfConnectionFailed:YES];
                        });
                    }];
                } else {
                    // upload successfully without error
                    // Sometimes when the file uploaded successfully, realSentBytes is not the same with expectedSentBytes.
                    
                    // update upload status to db

                    if (!transferredSizeBeforeResume || [transferredSizeBeforeResume unsignedIntegerValue] == 0) {
                        // for non-resume upload

                        assetFileWithoutManaged.transferredSize = @(realSentBytes);
                        assetFileWithoutManaged.totalSize = @(expectedSentBytes);
                    } else {
                        // for resume upload

                        assetFileWithoutManaged.transferredSize = @(realSentBytes + [transferredSizeBeforeResume unsignedIntegerValue]);
                    }

                    assetFileWithoutManaged.status = FILE_TRANSFER_STATUS_CONFIRMING;
                    assetFileWithoutManaged.endTimestamp = [Utility currentJavaTimeMilliseconds];
                    assetFileWithoutManaged.waitToConfirm = @YES;

                    [self.assetFileDao updateAssetFile:assetFileWithoutManaged completionHandler:^() {
                        // Delay for DELAY_CONFIRM_UPLOAD_INTERVAL seconds

                        dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (DELAY_CONFIRM_UPLOAD_INTERVAL * NSEC_PER_SEC));
                        dispatch_after(delayTime, gQueue, ^(void) {
                            NSDictionary *dictionary = @{assetFileWithoutManaged.transferKey : assetFileWithoutManaged.status};

                            [self.directoryService confirmUploadWithTransferKeyAndStatusDictionary:dictionary tryAgainIfConnectionFailed:YES];
                        });
                    }];
                }
                
                // find tmp filename in tmpUploadFile dictionary, remove the file and remove the value in the dictionary
                NSError *deleteError;
                [[TmpUploadFileService defaultService] removeTmpUploadFileAbsoluePathWithTransferKey:assetFileWithoutManaged.transferKey removeTmpUploadFile:YES deleteError:&deleteError];
                
                if (deleteError) {
                    NSLog(@"[Upload Completed]Error on deleting tmp file for transferKey: %@\nError:\n%@", assetFileWithoutManaged.transferKey, [deleteError userInfo]);
                }
            } else {
                /* FileTransfer in db has been removed for some reason, so skip it */
                
                NSLog(@"Can't upldate AssetFile because it it not found for upload key: %@. Error: %@", transferKey, fetchError ? [fetchError userInfo] : @"");
            }
        }
    });
}

#pragma mark - mimic NSURLSessionDelegate

// invoked when all upload completed with or without error.
- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
}
@end
