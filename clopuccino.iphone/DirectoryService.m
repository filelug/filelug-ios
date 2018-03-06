#import <Photos/Photos.h>
#import "Utility.h"
#import "DirectoryService.h"
#import "HierarchicalModelWithoutManaged.h"
#import "FileRenameModel.h"
#import "TransferHistoryModel.h"
#import "NSString+Utlities.h"
#import "AuthService.h"
#import "AssetFileDao.h"
#import "TmpUploadFileService.h"
#import "AssetFileWithoutManaged.h"
#import "FileTransferWithoutManaged.h"
#import "FileTransferDao.h"
#import "UserComputerDao.h"
#import "FileUploadStatusModel.h"
#import "HierarchicalModelDao.h"

@implementation DirectoryService {
}

static NSString *fileSharingRootPath;

//static NSString *externalFileRootPath;

+ (HierarchicalModelWithoutManaged *)parseJsonAsHierarchicalModel:(NSData *)data userComputerId:(NSString *)userComputerId error:(NSError * __autoreleasing *)error {
    NSError *jsonError = nil;
    NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];
    
    if (jsonError) {
        if (error) {
            *error = jsonError;
        } else {
            NSLog(@"Failed to parsing hierarchical model data.\n%@", [jsonError userInfo]);
        }

        return nil;
    } else {
        /* mandatory */
        NSString *type = jsonObject[@"type"];
        NSString *name = jsonObject[@"name"];
        NSString *parent = jsonObject[@"parent"];
        NSString *realName = jsonObject[@"realName"];
        NSString *realParent = jsonObject[@"realParent"];
        NSString *contentType = jsonObject[@"contentType"];
        NSString *displaySize = jsonObject[@"displaySize"];
        NSNumber *sizeInBytes = jsonObject[@"sizeInBytes"];
        NSNumber *symlink = jsonObject[@"symlink"];
        NSNumber *hidden = jsonObject[@"hidden"];
        NSNumber *readable = jsonObject[@"readable"];
        NSNumber *writable = jsonObject[@"writable"];
        NSNumber *executable = jsonObject[@"executable"];
        NSString *lastModified = jsonObject[@"lastModified"];

        NSString *sectionName = (type && [type hasSuffix:HIERARCHICAL_MODEL_TYPE_SUFFIX_DIRECTORY]) ? HIERARCHICAL_MODEL_SECTION_NAME_DIRECTORY : HIERARCHICAL_MODEL_SECTION_NAME_FILE;

        // use default values for download information
        return [[HierarchicalModelWithoutManaged alloc] initWithUserComputerId:userComputerId
                                                                          name:name
                                                                        parent:parent
                                                                      realName:realName
                                                                    realParent:realParent
                                                                   contentType:contentType
                                                                        hidden:hidden
                                                                       symlink:symlink
                                                                          type:type
                                                                   sectionName:sectionName
                                                                   displaySize:displaySize
                                                                   sizeInBytes:sizeInBytes
                                                                      readable:readable
                                                                      writable:writable
                                                                    executable:executable
                                                                  lastModified:lastModified];
    }
}

+ (FileRenameModel *)parseJsonAsFileRenameModel:(NSData *)data error:(NSError * __autoreleasing *)error {
    NSError *jsonError = nil;
    NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];
    
    if (jsonError) {
        if (error) {
            *error = jsonError;
        } else {
            NSLog(@"Failed to parse data for file rename.\n%@", [jsonError userInfo]);
        }

        return nil;
    } else {
        /* mandatory */
        NSString *oldPath = jsonObject[@"oldPath"];
        NSString *newPath = jsonObject[@"newPath"];
        NSString *oldFilename = jsonObject[@"oldFilename"];
        NSString *newFilename = jsonObject[@"newFilename"];
        
        return [[FileRenameModel alloc] initWithOldPath:oldPath newPath:newPath oldFilename:oldFilename newFilename:newFilename];
    }
}

+ (NSMutableArray *)parseJsonAsTransferHistoryModelArray:(NSData *)data error:(NSError * __autoreleasing *)error {
    NSError *jsonError = nil;
    NSArray *jsonArray = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];
    
    if (jsonError) {
        if (error) {
            *error = jsonError;
        } else {
            NSLog(@"Failed to parse download/upload history data.\n%@", [jsonError userInfo]);
        }

        return nil;
    } else {
        NSMutableArray *histories = [[NSMutableArray alloc] init];
        
        for (NSDictionary *jsonObject in jsonArray) {
            NSString *computerGroup = jsonObject[@"computer-group"];
            NSString *computerName = jsonObject[@"computer-name"];
            NSNumber *fileSize = jsonObject[@"fileSize"];
            NSNumber *endTimestamp = jsonObject[@"endTimestamp"];
            NSString *filename = jsonObject[@"filename"];
            
            TransferHistoryModel *model = [[TransferHistoryModel alloc] initWithComputerGroup:computerGroup computerName:computerName fileSize:fileSize endTimestamp:endTimestamp filename:filename];
            
            [histories addObject:model];
        }
        
        return histories;
    }
}

+ (UIImage *)imageForServerFilePath:(NSString *)serverFilePath fileSeparator:(NSString *)fileSeparator isDirectory:(BOOL)isDirectory {
    UIImage *image;
    
    if (isDirectory) {
        image = [UIImage imageNamed:@"ic_folder"];
    } else {
        NSString *localPath = [DirectoryService localPathFromRealServerPath:serverFilePath fileSeparator:fileSeparator];
        
        image = [DirectoryService imageForLocalFilePath:localPath isDirectory:NO];
    }
    
    return image;
}

+ (UIImage *)imageForLocalFilePath:(NSString *)localFilePath isDirectory:(BOOL)isDirectory {
    UIImage *image;
    
    if (isDirectory) {
        image = [UIImage imageNamed:@"ic_folder"];
    } else {
        NSString *extension = [localFilePath pathExtension];
        
        if (extension && extension.length > 0) {
            NSString *imageFileName = [NSString stringWithFormat:@"%@%@", @"ic_file_", [extension lowercaseString]];
            
            image = [UIImage imageNamed:imageFileName];
            
            if (!image) {
                image = [UIImage imageNamed:@"ic_file"];
            }
        } else {
            image = [UIImage imageNamed:@"ic_file"];
        }
    }
    
    return image;
}

+ (UIImage *)imageForFileExtension:(NSString *)fileExtension {
    UIImage *image;
    
    if (fileExtension && fileExtension.length > 0) {
        NSString *imageFileName = [NSString stringWithFormat:@"%@%@", @"ic_file_", [fileExtension lowercaseString]];
        
        image = [UIImage imageNamed:imageFileName];
        
        if (!image) {
            image = [UIImage imageNamed:@"ic_file"];
        }
    } else {
        image = [UIImage imageNamed:@"ic_file"];
    }
    
    return image;
}

+ (UIImage *)imageForParentPath:(NSString *)parentPath fileName:(NSString *)fileName fileSeparator:(NSString *)fileSeparator isDirectory:(BOOL)isDirectory {
    NSString *fullPath = [[parentPath stringByAppendingString:fileSeparator] stringByAppendingString:fileName];
    
    return [DirectoryService imageForServerFilePath:fullPath fileSeparator:fileSeparator isDirectory:isDirectory];
}

+ (UIImage *)imageForFile:(HierarchicalModelWithoutManaged *)model fileSeparator:(NSString *)fileSeparator bundleDirectoryAsFile:(BOOL)bundleDirectoryAsFile {
    BOOL showAsDirectory;

    if (bundleDirectoryAsFile && [model isBundleDirectory]) {
        showAsDirectory = NO;
    } else {
        showAsDirectory = [model isDirectory];
    }

    return [DirectoryService imageForParentPath:model.realParent fileName:model.realName fileSeparator:fileSeparator isDirectory:showAsDirectory];
}

+ (UIImage *)imageForFile:(HierarchicalModelWithoutManaged *)model fileSeparator:(NSString *)fileSeparator {
    return [self imageForFile:model fileSeparator:fileSeparator bundleDirectoryAsFile:NO];

//    return [DirectoryService imageForParentPath:model.realParent fileName:model.realName fileSeparator:fileSeparator isDirectory:[model isDirectory]];
}

+ (NSString *)localPathFromRealServerPath:(NSString *)realServerPath fileSeparator:(NSString *)separator {
    return [realServerPath stringByReplacingOccurrencesOfString:separator withString:@"/"];
}

+ (NSString *)filenameFromServerFilePath:(NSString *)serverFilePath {
    NSString *name;

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *separator = [userDefaults stringForKey:USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR];

    if (serverFilePath && separator) {
        NSArray *components = [serverFilePath componentsSeparatedByString:separator];
        
        if ([components count] > 0) {
            name = components[[components count] - 1];
        }
    }
    
    return name ? name : @"";
}

+ (NSString *)parentPathFromServerFilePath:(NSString *)serverFilePath separator:(NSString *)separator {
    NSString* parentPath;

    if (serverFilePath && separator) {
        NSArray *components = [serverFilePath componentsSeparatedByString:separator];

        if (components && [components count] > 1) {
            NSMutableString *mutableParentPath = [NSMutableString string];

            for (NSInteger index = 0; index < [components count] - 1; index++) {
                [mutableParentPath appendFormat:@"%@%@", components[index], separator];
            }

            parentPath = [mutableParentPath substringToIndex:(mutableParentPath.length - 1)];
        }
    }

    return parentPath;
}

+ (NSString *)directoryNameFromServerDirectoryPath:(NSString *)serverFilePath {
    return [DirectoryService filenameFromServerFilePath:serverFilePath];
}

// The method is used only for transfer old data and should be replaced with appGroupDirectoryPathWithUserComputerId:
+ (NSString *)localFileDirectoryPathWithUserComputerId:(NSString *)userComputerId {
    NSString *directoryPath;

    if (userComputerId) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *applicationSupportPath = [Utility applicationSupportDirectoryWithFileManager:fileManager];

        // stringByStandardizingPath is not url-encoded, see the following for more information:
        // https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSString_Class/#//apple_ref/occ/instp/NSString/stringByStandardizingPath
        NSString *standardizePathFromUserComputerId = [userComputerId stringByStandardizingPath];

        directoryPath = [applicationSupportPath stringByAppendingPathComponent:standardizePathFromUserComputerId];
    }

    return directoryPath;
}

+ (NSString *)appGroupRootDirectory {
    return [[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:APP_GROUP_NAME] path];
}

+ (NSString *)appGroupDirectoryPathWithCurrentUserComputerId {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    return [self appGroupDirectoryPathWithUserComputerId:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID]];
}

+ (NSString *)appGroupDirectoryPathWithUserComputerId:(NSString *)userComputerId {
    NSString *directoryPath;

    if (userComputerId) {
        NSString *appGroupDirectoryPath = [self appGroupRootDirectory];

        // stringByStandardizingPath is not url-encoded, see the following for more information:
        // https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSString_Class/#//apple_ref/occ/instp/NSString/stringByStandardizingPath
        NSString *standardizePathFromUserComputerId = [userComputerId stringByStandardizingPath];

        directoryPath = [appGroupDirectoryPath stringByAppendingPathComponent:standardizePathFromUserComputerId];
    }

    return directoryPath;
}

+ (NSString *)absoluteFilePathFromLocalPath:(NSString *)localPath userComputerId:(NSString *)userComputerId {
    NSString *absolutePath;

    if (localPath) {
        NSString *parentDirectoryPath = [self appGroupDirectoryPathWithUserComputerId:userComputerId];

        if (parentDirectoryPath) {
            absolutePath = [parentDirectoryPath stringByAppendingPathComponent:localPath];
        }
    }

    return absolutePath;
}

+ (void)deleteLocalCachedDataWithUserComputerId:(NSString *)userComputerId error:(NSError * __autoreleasing *)error {
    NSString *localFileRootDirectoryPath = [DirectoryService appGroupDirectoryPathWithUserComputerId:userComputerId];

    NSFileManager *fileManager = [NSFileManager defaultManager];

    [fileManager removeItemAtPath:localFileRootDirectoryPath error:error];
}

+ (void)deleteLocalFileWithRealServerPath:(NSString *)realServerPath completionHandler:(void (^)(NSError *))completionHandler {
    if (realServerPath) {
        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSString *userComputerId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];
        NSString *fileSeparator = [userDefaults objectForKey:USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR];

        if (userComputerId && fileSeparator) {
            NSString *localFilePath = [self localPathFromRealServerPath:realServerPath fileSeparator:fileSeparator];

            NSString *absolutePath = [DirectoryService absoluteFilePathFromLocalPath:localFilePath userComputerId:userComputerId];

            if ([[NSFileManager defaultManager] fileExistsAtPath:absolutePath]) {
                NSError *deleteError;
                [[NSFileManager defaultManager] removeItemAtPath:absolutePath error:&deleteError];

                if (completionHandler) {
                    completionHandler(deleteError);
                }
            } else {
                if (completionHandler) {
                    completionHandler(nil);
                }
            }
        } else {
            // user computer or file separator not found -- connect to the computer first.

            if (completionHandler) {
                NSError *error = [Utility errorWithErrorCode:ERROR_CODE_CONNECT_TO_COMPUTER_FIRST_KEY localizedDescription:NSLocalizedString(@"User never connected in extension", @"")];

                completionHandler(error);
            }
        }
    }
}

+ (NSString *)iTunesFileSharingRootPath {
    if (!fileSharingRootPath) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        
        fileSharingRootPath = paths[0];
    }
    
    return fileSharingRootPath;
}

//+ (NSString *)devicdSharingFolderPath {
//    NSString *folderPath = [self deviceSharingFolderPathWithoutCreatingIfNotExists];
//
//    // Make sure the device sharing folder exists
//
//    // If directory exists, sometimes error occurred even if intermediateDirectories set to YES (maybe it is because the permission owner is different)
//    // So we have to test it first anyway.
//
//    NSFileManager *fileManager = [NSFileManager defaultManager];
//
//    BOOL isDirectory;
//    BOOL pathExists = [fileManager fileExistsAtPath:folderPath isDirectory:&isDirectory];
//
//    if (!pathExists || !isDirectory) {
//        NSError *createError;
//        [fileManager createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:&createError];
//
//        if (createError) {
//            NSLog(@"Failed to create directory: '%@'\n%@", folderPath, [createError userInfo]);
//        }
//    }
//
//    return folderPath;
//}

+ (NSString *)deviceSharingFolderPathWithoutCreatingIfNotExists {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);

    NSString *folderPath = [paths[0] stringByAppendingPathComponent:DEVICE_SHARING_FOLDER_NAME];

    return folderPath;
}

+ (void)deleteDeviceSharingFolderIfExists {
    NSString *folderPath = [self deviceSharingFolderPathWithoutCreatingIfNotExists];

    NSFileManager *fileManager = [NSFileManager defaultManager];

    BOOL isDirectory;
    BOOL pathExists = [fileManager fileExistsAtPath:folderPath isDirectory:&isDirectory];

    if (pathExists && isDirectory) {
        [fileManager removeItemAtPath:folderPath error:NULL];
    }
}

//// If absolutePath is not prefix with file sharing directory path, return nil.
//// If absolutePath is prefix with file sharing directory path, the return value is not prefix with '/'
//+ (NSString *)extractRelativePathFromFileInSharingDirectory:(NSString *)absolutePath {
//    NSString *fileRelativePath;
//
//    NSString *prefix = [self devicdSharingFolderPath];
//
//    if ([absolutePath hasPrefix:prefix]) {
//        NSUInteger fileSharingDirectoryPathLength = prefix.length + 1; // including the suffix path separator '/'
//
//        fileRelativePath = [absolutePath substringWithRange:NSMakeRange(fileSharingDirectoryPathLength, (absolutePath.length - fileSharingDirectoryPathLength))];
//    } else {
//        NSLog(@"[WARNING]File path '%@' is not prefix with: '%@'", absolutePath, prefix);
//    }
//
//    return fileRelativePath;
//}

+ (NSURL *)documentStorageURLForDocumentProvider {
    NSString *path = [[self appGroupRootDirectory] stringByAppendingPathComponent:@"File Provider Storage"];

    NSURL *pathURL = [NSURL fileURLWithPath:path];

    return pathURL;
}

+ (NSString *)directoryForExternalFilesWithCreatedIfNotExists:(BOOL)createdIfNotExists {
    NSString *externalFileRootPath = [[self appGroupRootDirectory] stringByAppendingPathComponent:EXTERNAL_FILE_DIRECTORY_NAME];

    NSFileManager *fileManager = [NSFileManager defaultManager];

    // If directory exists, sometimes error occurred even if intermediateDirectories set to YES (maybe it is because the permission owner is different)
    // So we have to test it first anyway.

    BOOL isDirectory;
    BOOL pathExists = [fileManager fileExistsAtPath:externalFileRootPath isDirectory:&isDirectory];

    if (createdIfNotExists && (!pathExists || !isDirectory)) {
        NSError *createError;
        [fileManager createDirectoryAtPath:externalFileRootPath withIntermediateDirectories:YES attributes:nil error:&createError];

        if (createError) {
            NSLog(@"Error on creating directory: '%@'\n%@", externalFileRootPath, [createError userInfo]);
        }
    }

    return externalFileRootPath;
}

// Either fromFilePath or toFilePath must be a file, instead of a directory
+ (void)moveFilePath:(NSString *)fromFilePath toPath:(NSString *)toFilePath replaceIfExists:(BOOL)replace error:(NSError * __autoreleasing *)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];

    // Test if fromFile exists

    BOOL isFromPathDirectory;
    BOOL fromFilePathExists = [fileManager fileExistsAtPath:fromFilePath isDirectory:&isFromPathDirectory];

    if (!fromFilePathExists || isFromPathDirectory) {
        NSString *errorMessage = [NSString stringWithFormat:@"Error on moving file. Source file '%@' not exists or is a directory.", fromFilePath];

        if (error) {
            *error = [Utility errorWithErrorCode:NSFileNoSuchFileError localizedDescription:errorMessage];
        } else {
            NSLog(@"%@", errorMessage);
        }
    } else {
        // Test if toFile exists

        BOOL isToPathDirectory;
        BOOL toFilePathExists = [fileManager fileExistsAtPath:toFilePath isDirectory:&isToPathDirectory];

        BOOL shouldMoveFile = YES;

        if (toFilePathExists && replace) {
            NSError *removeError;
            [fileManager removeItemAtPath:toFilePath error:&removeError];

            if (removeError) {
                if (error) {
                    *error = removeError;
                } else {
                    NSLog(@"Error on removing file: '%@'\n%@", toFilePath, [removeError userInfo]);
                }
            }
        } else if (toFilePathExists) {
            shouldMoveFile = NO;
        }

        if (shouldMoveFile) {
            // create directory of toFilePath, if not exists

            NSString *destinationParent = [toFilePath stringByDeletingLastPathComponent];

            NSError *createError;
            [fileManager createDirectoryAtPath:destinationParent withIntermediateDirectories:YES attributes:nil error:&createError];

            if (createError) {
                if (error) {
                    *error = createError;
                } else {
                    NSLog(@"Error creating directory '%@'\n%@", destinationParent, [createError userInfo]);
                }
            }

            // move file

            NSError *moveError;
            [fileManager moveItemAtPath:fromFilePath toPath:toFilePath error:&moveError];

            if (moveError) {
                if (error) {
                    *error = moveError;
                } else {
                    NSLog(@"Error on moving file from '%@' to '%@'\n%@", fromFilePath, toFilePath, [moveError userInfo]);
                }
            }
        }
    }
}

- (id)initWithCachePolicy:(NSURLRequestCachePolicy)policy timeInterval:(NSTimeInterval)interval {
    if (self = [super init]) {
        _cachePolicy = policy;
        _timeInterval = interval;
    }
    
    return self;
}

- (AssetFileDao *)assetFileDao {
    if (!_assetFileDao) {
        _assetFileDao = [[AssetFileDao alloc] init];
    }
    
    return _assetFileDao;
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

- (AuthService *)authService {
    if (!_authService) {
        _authService = [[AuthService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];
    }
    
    return _authService;
}

- (void)listDirectoryChildrenWithParent:(NSString *)path session:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    NSString *urlString = [Utility composeLugServerURLStringWithPath:@"directory/list"];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
    
    [request setHTTPMethod:@"POST"];
    
    NSString *escapedPath = [path escapeIllegalJsonCharacter];

    NSString *bodyString = [NSString stringWithFormat:@"{\"path\" : \"%@\"}", escapedPath];
    
    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];
    
    [request setValue:@"gzip, deflate" forHTTPHeaderField:HTTP_HEADER_NAME_ACCEPT_ENCODING];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
}

+ (NSString *)serverPathFromParent:(NSString *)parentPath name:(NSString *)filename {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *separator = [userDefaults stringForKey:USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR];

    NSString *serverPath;

    if (separator) {
        serverPath = [DirectoryService serverPathFromParent:parentPath name:filename fileSeparator:separator];
    }

    return serverPath;
}

+ (NSString *)serverPathFromParent:(NSString *)parentPath name:(NSString *)filename fileSeparator:(NSString *)separator {
    NSString *serverPath;

    if (separator) {
        if (!parentPath) {
            parentPath = @"";
        }

        // Be careful that for root directory '/', the real path is empty and the filename is '/'
        if ([parentPath hasSuffix:separator] || [parentPath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length < 1) {
            serverPath = [parentPath stringByAppendingString:filename];
        } else {
            serverPath = [parentPath stringByAppendingFormat:@"%@%@", separator, filename];
        }
    }

    return serverPath;
}

- (void)findFileWithPath:(NSString *)path calculateSize:(BOOL)calculateSize session:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    NSString *urlString = [Utility composeLugServerURLStringWithPath:@"directory/find"];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
    
    [request setHTTPMethod:@"POST"];
    
    NSString *escapedPath = [path escapeIllegalJsonCharacter];
    
    NSString *bodyString = [NSString stringWithFormat:@"{\"path\" : \"%@\", \"calculateSize\" : %@}", escapedPath, (calculateSize ? @"true" : @"false")];
    
    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
}

- (void)renameFileWithPath:(NSString *)path newFilename:(NSString *)filename session:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    NSString *urlString = [Utility composeLugServerURLStringWithPath:@"directory/rename"];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
    
    [request setHTTPMethod:@"POST"];
    
    NSString *escapedPath = [path escapeIllegalJsonCharacter];
    NSString *escapedFilename = [filename escapeIllegalJsonCharacter];
    
    NSString *bodyString = [NSString stringWithFormat:@"{\"path\" : \"%@\", \"filename\" : \"%@\"}", escapedPath, escapedFilename];
    
    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
}

- (void)confirmUploadsWithCompletionHandler:(void (^)(void))completionHandler {
    [self.assetFileDao findWaitToConfirmAssetFileTransferKeyAndStatusDictionaryWithCompletionHandler:^(NSDictionary *transferKeyAndStatusDictionary) {
        if (transferKeyAndStatusDictionary && [transferKeyAndStatusDictionary count] > 0) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                //  login again and try confirm again if connection/network failure.
                [self confirmUploadWithTransferKeyAndStatusDictionary:transferKeyAndStatusDictionary tryAgainIfFailed:YES completionHandler:^{
                    if (completionHandler) {
                        completionHandler();
                    }
                }];
            });
        } else {
            // No matter if wait-to-confirm upload files found or not, do completionHandler
            if (completionHandler) {
                completionHandler();
            }
        }
    }];
}

- (void)confirmUploadWithTransferKeyAndStatusDictionary:(NSDictionary *)dictionary tryAgainIfFailed:(BOOL)tryAgainIfFailed completionHandler:(void (^)(void))completionHandler {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];
    
    if (sessionId && sessionId.length > 0) {
        [self confirmUploadWithTransferKeyAndStatusDictionary:dictionary session:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];
                
                if (statusCode == 200) {
                    // Parse the JSON to get transfer key and status,
                    // update the AssetFile in db,
                    // and delete the temp file.
                    
                    NSError *saveError;
                    [self saveConfirmUploadResponseData:data error:&saveError];
                    
                    if (saveError) {
                        NSLog(@"Error on parsing response of confirm-upload\n%@", saveError);
                    } else if (completionHandler) {
                        completionHandler();
                    }
                } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
                    // sender set to nil for we do not want to show connection view controller if login failed

                    [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            [self confirmUploadWithTransferKeyAndStatusDictionary:dictionary tryAgainIfFailed:NO completionHandler:completionHandler];
                        });
                    } failureHandler:^(NSData *loginData, NSURLResponse *loginResponse, NSError *loginError) {
                        NSInteger loginStatusCode = [(NSHTTPURLResponse *) loginResponse statusCode];
                        NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Login failed. %@ Status:%d", @""), [loginError localizedDescription], loginStatusCode];
                        NSLog(@"%@", message);
                    }];
                    
                    // The service invoke from AA Server and don't care error code 503.
                } else {
                    NSString *message = [Utility messageWithMessagePrefix:NSLocalizedString(@"Failed to confirm the status of upload.", @"") error:error data:data];
                    NSLog(@"%@", message);
//                    NSLog(@"%@", [AuthService prepareFailedLoginMessageWithResponse:response error:error data:data]);
                    
                    // leave the status and wait for next time to confirm again (by system or user click)
                }
            });
        }];
    }
}

- (void)confirmUploadWithTransferKeyAndStatusDictionary:(NSDictionary *)dictionary tryAgainIfConnectionFailed:(BOOL)tryAgainIfConnectionFailed {
    [self confirmUploadWithTransferKeyAndStatusDictionary:dictionary tryAgainIfFailed:tryAgainIfConnectionFailed completionHandler:nil];
}

- (void)saveConfirmUploadResponseData:(NSData *)data error:(NSError * __autoreleasing *)error {
    NSError *jsonError = nil;
    NSArray *jsonArray = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];
    
    if (jsonError) {
        if (error) {
            *error = jsonError;
        } else {
            NSLog(@"Failed to save upload-confirmation data.\n%@", [jsonError userInfo]);
        }
    } else {
        for (NSDictionary *jsonObject in jsonArray) {
            // convert transferKey to transfer-key, and convert status to transfer-status

            NSString *transferKey = jsonObject[FILELUG_SERVICE_CONTENT_KEY_TRANSFER_KEY];
            NSString *status = jsonObject[FILELUG_SERVICE_CONTENT_KEY_STATUS];

            if (transferKey && status) {
                NSDictionary *convertedJson = @{NOTIFICATION_MESSAGE_KEY_TRANSFER_KEY : transferKey, NOTIFICATION_MESSAGE_KEY_TRANSFER_STATUS : status};

                [self updateFileUploadStatusToSuccessOrFailureWithTransferKeyAndStatusDictionary:convertedJson];
            }
        }
    }
}

// the specified dictionary contains only one transfer key and transfer status
// status will be updated only if status is either success or failure
// tmp file path will be deleted only if status is either success or failure and AssetFile found.
- (void)updateFileUploadStatusToSuccessOrFailureWithTransferKeyAndStatusDictionary:(NSDictionary *)transferKeyAndStatusDictionary {
    NSString *transferKey = transferKeyAndStatusDictionary[NOTIFICATION_MESSAGE_KEY_TRANSFER_KEY];
    NSString *transferStatus = transferKeyAndStatusDictionary[NOTIFICATION_MESSAGE_KEY_TRANSFER_STATUS];

    if (transferStatus && ([transferStatus isEqualToString:FILE_TRANSFER_STATUS_SUCCESS] || [transferStatus isEqualToString:FILE_TRANSFER_STATUS_FAILED])) {
        NSError *fetchError;
        AssetFileWithoutManaged *assetFileWithoutManaged = [self.assetFileDao findAssetFileForTransferKey:transferKey error:&fetchError];

        if (assetFileWithoutManaged) {
            assetFileWithoutManaged.status = transferStatus;
            assetFileWithoutManaged.waitToConfirm = @NO;

            [self.assetFileDao updateAssetFile:assetFileWithoutManaged];

            // find tmp filename in tmpUploadFile dictionary, remove the file and remove the value in the dictionary
            NSError *deleteError;
            [[TmpUploadFileService defaultService] removeTmpUploadFileAbsoluePathWithTransferKey:transferKey removeTmpUploadFile:YES deleteError:&deleteError];

            if (deleteError) {
                NSLog(@"[Save Confirm Upload]Error on deleting tmp file for transferKey: %@\nError:\n%@", transferKey, [deleteError userInfo]);
            }
        } else if (fetchError) {
            NSLog(@"Error on finding asset file using transfer key: %@\n%@", transferKey, fetchError);
        }
    }
}

- (void)confirmUploadWithTransferKeyAndStatusDictionary:(NSDictionary *)transferKeyAndStatusDictionary session:(NSString *)sessionId completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *connectionError))handler {
    NSString *confirmUploadUrlPath = @"directory/dcupload2";
    
    NSString *urlString = [Utility composeAAServerURLStringWithPath:confirmUploadUrlPath];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
    
    [request setHTTPMethod:@"POST"];
    
    NSArray *keys = [transferKeyAndStatusDictionary allKeys];
    
    NSMutableString *bodyString = [NSMutableString string];
    
    [bodyString appendString:@"["];
    
    if (keys) {
        NSUInteger keyCount = [keys count];
        
        for (NSUInteger index = 0; index < keyCount; index++) {
            NSString *key = keys[index];
            
            NSString *transferStatus = transferKeyAndStatusDictionary[key];
            
            if (transferStatus && [transferStatus stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
                [bodyString appendFormat:@"{\"transferKey\" : \"%@\", \"status\" : \"%@\"}", key, transferStatus];
            } else {
                [bodyString appendFormat:@"{\"transferKey\" : \"%@\"}", key];
            }
            
            if (keyCount - 1 > index) {
                // not loop end
                [bodyString appendString:@", "];
            }
        }
    }
    
    [bodyString appendString:@"]"];
    
    //    NSString *bodyString = [NSString stringWithFormat:@"{\"transferKey\" : \"%@\", \"status\" : \"%@\"}", transferKey, transferStatus];
    
    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
}

- (void)confirmDownloadWithFileTransfer:(FileTransferWithoutManaged *)fileTransferWithoutManaged tryAgainIfFailed:(BOOL)tryAgainIfFailed completionHandler:(void (^)(void))completionHandler {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    if (sessionId && sessionId.length > 0) {
        NSString *transferKey = fileTransferWithoutManaged.transferKey;
        NSString *transferStatus = fileTransferWithoutManaged.status;

        if ([transferStatus isEqualToString:FILE_TRANSFER_STATUS_SUCCESS] || [transferStatus isEqualToString:FILE_TRANSFER_STATUS_FAILED]) {
            DirectoryService *directoryService = [[DirectoryService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];

            [directoryService confirmDownloadForTransferKey:transferKey status:transferStatus realReceivedBytes:fileTransferWithoutManaged.transferredSize session:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];
                    if (statusCode == 200) {
                        // update waitToConfirm to NO (no need to wait confirming)
                        fileTransferWithoutManaged.waitToConfirm = @NO;

                        [self.fileTransferDao updateFileTransferWithSameTransferKey:fileTransferWithoutManaged];

                        HierarchicalModelWithoutManaged *hierarchicalModelWithoutManaged = [self.hierarchicalModelDao findHierarchicalModelForTransferKey:transferKey error:NULL];

                        if (hierarchicalModelWithoutManaged) {
                            NSString *transferStatus2 = hierarchicalModelWithoutManaged.status;

                            if ([transferStatus2 isEqualToString:FILE_TRANSFER_STATUS_SUCCESS] || [transferStatus2 isEqualToString:FILE_TRANSFER_STATUS_FAILED]) {
                                // update correspondent HierarchicalModels with the specified realServerPath
                                // the value of realServerPath in HierarchicalModels should exist now, so we found them by using realServerPath
                                // no need to provide fileSeparator if found by realServerPath
                                [self.hierarchicalModelDao updateDownloadInformationToHierarchicalModelsFromFileTransferWithoutManaged:fileTransferWithoutManaged findHierarchicalModelsByRealServerPath:YES fileSeparator:nil];
                            }
                        }

                        if (completionHandler) {
                            completionHandler();
                        }
                    } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
                        // sender set to nil for we do not want to show connection view controller if login failed

                        [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                            // The service invoke from AA Server and don't care if socket connected.
                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                [self confirmDownloadWithFileTransfer:fileTransferWithoutManaged tryAgainIfFailed:NO completionHandler:completionHandler];
                            });
                        } failureHandler:^(NSData *loginData, NSURLResponse *loginResponse, NSError *loginError) {
                            NSInteger loginStatusCode = [(NSHTTPURLResponse *) loginResponse statusCode];
                            NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Login failed. %@ Status:%d", @""), [loginError localizedDescription], loginStatusCode];
                            NSLog(@"%@", message);
                        }];

                        // The service invoke from AA Server and don't care error code 503.
                    } else {
                        NSString *message = [Utility messageWithMessagePrefix:NSLocalizedString(@"Failed to confirm the status of download.", @"") error:error data:data];
                        NSLog(@"%@", message);
//                        NSLog(@"%@", [AuthService prepareFailedLoginMessageWithResponse:response error:error data:data]);

                        // leave the status and wait for next time to confirm again (by system or user click)
                    }
                });
            }];
        } else {
            NSLog(@"Can't confirm download because the status of the file: '%@' is '%@'", fileTransferWithoutManaged.realServerPath, transferStatus);
        }
    }
}

- (void)confirmDownloadForTransferKey:(NSString *)transferKey status:(NSString *)transferStatus realReceivedBytes:(NSNumber *)realReceivedBytes session:(NSString *)sessionId completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *connectionError))handler {
    NSString *urlString = [Utility composeAAServerURLStringWithPath:@"directory/dcdownload"];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
    
    [request setHTTPMethod:@"POST"];
    
    NSString *bodyString = [NSString stringWithFormat:@"{\"transferKey\" : \"%@\", \"status\" : \"%@\", \"fileSize\" : %f}", transferKey, transferStatus, [realReceivedBytes doubleValue]];
    
    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
}

- (void)findDownloadHistoryWithTransferHistoryType:(NSInteger)transferHistoryType session:(NSString *)sessionId completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))handler {
    NSString *urlString = [Utility composeAAServerURLStringWithPath:@"directory/dhis"];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
    
    [request setHTTPMethod:@"POST"];
    
    NSString *bodyString = [NSString stringWithFormat:@"{\"type\" : %ld}", (long)transferHistoryType];
    
    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];
    
    [request setValue:@"gzip, deflate" forHTTPHeaderField:HTTP_HEADER_NAME_ACCEPT_ENCODING];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
}

- (void)findUploadHistoryWithTransferHistoryType:(NSInteger)transferHistoryType session:(NSString *)sessionId completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))handler {
    NSString *urlString = [Utility composeAAServerURLStringWithPath:@"directory/uhis"];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
    
    [request setHTTPMethod:@"POST"];
    
    NSString *bodyString = [NSString stringWithFormat:@"{\"type\" : %ld}", (long) transferHistoryType];
    
    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];
    
    [request setValue:@"gzip, deflate" forHTTPHeaderField:HTTP_HEADER_NAME_ACCEPT_ENCODING];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
}

- (void)createFileUploadSummaryWithUploadGroupId:(NSString *)uploadGroupId targetDirectory:(NSString *)targetDirectory transferKeys:(NSArray *)transferKeys subdirectoryType:(NSInteger)subdirectoryType subdirectoryValue:(NSString *)subdirectoryValue descriptionType:(NSInteger)descriptionType descriptionValue:(NSString *)descriptionValue notificationType:(NSInteger)notificationType session:(NSString *)sessionId completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))handler {
    NSString *urlString = [Utility composeLugServerURLStringWithPath:@"directory/dupload-sum2"];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
    
    [request setHTTPMethod:@"POST"];
    
    /* Sample
     {
     "upload-group-id" : "OTFDRjUxNzjglQUMlRTglQTklQTYuUE5HKzEzOTI2MjEwMjQzNDc=",
     "upload-keys" :[
     "b330111b8bcca57800361349e+up+0F7B6FAD-5297-41DC-87B0-BE14856DDC11",
     "1329C8D721F6E09E7936954B212B6407CA07545D1C1696B53FE164E8B199553BE",
     "212B6407CA72145D1C1696B53FE297-41DC-87B0075AD-5BE14856DDC111329C8",
     "2BFD9B37AFFCF0C337545D1C1696B53FE164E8B1329C8D721F6E09E793695DD7B",
     "36865697BA828003613495D1C1696B53FE16433907407CA0754F9E8FBC19D7721"
     ],
     "upload-dir" : "C:\Users\Administrator\Pictures\Travel\西藏之旅+2015-06-22Z20-10-19+0800",   // 此路徑包含子目錄（如果有設定子目錄時）
     "subdirectory-type" : 4,                                                                    // Customized name + Current timestamp
     "subdirectory-value" : "西藏之旅+2015-06-22Z20-10-19+0800",
     "description-type" : 3,                                                                     // Customized description + Filename list
     "description-value" : "西藏布達拉宮\n\n檔案名稱列表：\nIMG-2837.JPG,\nIMG-2838.JPG,\nIMG-2839.JPG\nMOV-2840.MP4,\nIMG-2841.JPG",
     "notification-type" : 2
     }
     */
    
    NSString *escapedTargetDirectory = [targetDirectory escapeIllegalJsonCharacter];
    
    NSString *transferKeyArrayString = [Utility stringFromStringArray:transferKeys separator:@"," quotedCharacter:@"\""];
    
    NSString *escapedSubdirectoryValue = [subdirectoryValue escapeIllegalJsonCharacter];
    
    NSString *escapedDescriptionValue = [descriptionValue escapeIllegalJsonCharacter];
    
    NSString *bodyString = [NSString stringWithFormat:@"{\"upload-group-id\":\"%@\",\"upload-keys\":[%@],\"upload-dir\":\"%@\",\"subdirectory-type\":%ld,\"subdirectory-value\":\"%@\",\"description-type\":%ld,\"description-value\":\"%@\",\"notification-type\":%ld}", uploadGroupId, transferKeyArrayString, escapedTargetDirectory, (long) subdirectoryType, escapedSubdirectoryValue, (long) descriptionType, escapedDescriptionValue, (long) notificationType];
    
    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
}

- (void)createFileDownloadSummaryWithDownloadGroupId:(NSString *)downloadGroupId transferKeyAndRealFilePaths:(NSDictionary *)transferKeyAndRealFilePaths notificationType:(NSInteger)notificationType session:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    NSString *urlString = [Utility composeLugServerURLStringWithPath:@"directory/ddownload-sum2"];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];

    [request setHTTPMethod:@"POST"];

    NSError *dictionaryToJsonError;
    NSData *transferKeyAndPathsData = [NSJSONSerialization dataWithJSONObject:transferKeyAndRealFilePaths options:0 error:&dictionaryToJsonError];

    NSString *downloadKeyPathsValue;

    if (dictionaryToJsonError) {
        NSLog(@"Error on generate JSON from dictionary: %@\n%@", transferKeyAndRealFilePaths, [dictionaryToJsonError userInfo]);
    } else {
        downloadKeyPathsValue = [[NSString alloc] initWithData:transferKeyAndPathsData encoding:NSUTF8StringEncoding];
    }

    NSString *bodyString = [NSString stringWithFormat:@"{\"download-group-id\":\"%@\",\"download-key-paths\":%@,\"notification-type\":%ld}", downloadGroupId, downloadKeyPathsValue, (long) notificationType];

    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];

    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
}

- (void)replaceFileUploadTransferKey:(NSString *)oldTransferKey withNewTransferKey:(NSString *)transferKey session:(NSString *)sessionId completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))handler {
    NSString *urlString = [Utility composeLugServerURLStringWithPath:@"directory/replace-upload"];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
    
    [request setHTTPMethod:@"POST"];
    
    NSString *bodyString = [NSString stringWithFormat:@"{\"old-transferKey\":\"%@\",\"new-transferKey\":\"%@\"}", oldTransferKey, transferKey];
    
    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
}

- (void)replaceFileDownloadTransferKey:(NSString *)oldTransferKey withNewTransferKey:(NSString *)transferKey session:(NSString *)sessionId completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))handler {
    NSString *urlString = [Utility composeLugServerURLStringWithPath:@"directory/replace-download"];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];

    [request setHTTPMethod:@"POST"];

    NSString *bodyString = [NSString stringWithFormat:@"{\"old-transferKey\":\"%@\",\"new-transferKey\":\"%@\"}", oldTransferKey, transferKey];

    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];

    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
}

+ (id)assetWithAssetFileWithoutManaged:(AssetFileWithoutManaged *)assetFileWithoutManaged {
    __block id asset;

    NSUInteger sourceTypeInteger = [assetFileWithoutManaged.sourceType unsignedIntegerValue];

    if (ASSET_FILE_SOURCE_TYPE_PHASSET == sourceTypeInteger) {
        PHFetchResult *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[assetFileWithoutManaged.assetURL] options:nil];

        if ([fetchResult count] > 0) {
            asset = [fetchResult firstObject];
        }
    } else if (ASSET_FILE_SOURCE_TYPE_SHARED_FILE == sourceTypeInteger) {
        NSString *downloadedFileTransferKey = assetFileWithoutManaged.downloadedFileTransferKey;

        FileTransferWithoutManaged *fileTransferWithoutManaged = [[[FileTransferDao alloc] init] findFileTransferForTransferKey:downloadedFileTransferKey error:NULL];

        if (fileTransferWithoutManaged) {
            NSString *absolutePath = [DirectoryService absoluteFilePathFromLocalPath:fileTransferWithoutManaged.localPath userComputerId:fileTransferWithoutManaged.userComputerId];

            BOOL isDirectory;
            BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:absolutePath isDirectory:&isDirectory];

            if (fileExists && !isDirectory) {
                asset = [fileTransferWithoutManaged copy];
            }
        }
    } else if (ASSET_FILE_SOURCE_TYPE_EXTERNAL_FILE == sourceTypeInteger) {
        NSString *absolutePath = [[DirectoryService directoryForExternalFilesWithCreatedIfNotExists:YES] stringByAppendingPathComponent:assetFileWithoutManaged.assetURL];

        BOOL isDirectory;
        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:absolutePath isDirectory:&isDirectory];

        if (fileExists && !isDirectory) {
            asset = absolutePath;
        }
    }

    return asset;
}

//// Returns the value with the type:
//// Type of PHAsset -> if sourceType is ASSET_FILE_SOURCE_TYPE_PHASSET
//// Type of NSString with absolute file path -> if sourceType is ASSET_FILE_SOURCE_TYPE_SHARED_FILE or ASSET_FILE_SOURCE_TYPE_EXTERNAL_FILE
//// Return nil if asset not found or file not found with the file path
////
//// The content of assetURL is different base on sourceType:
//// ASSET_FILE_SOURCE_TYPE_SHARED_FILE   --> any_subfolder/IMG_7243.JPG (without parent path: /var/mobile/Containers/Data/Application/07522D8F-0537-4A90-90A7-75B171E9AC89/Documents)
//// ASSET_FILE_SOURCE_TYPE_PHASSET       --> 4CBE5A4F-90BD-438B-954E-6FF1B14538CD/L0/001
//// ASSET_FILE_SOURCE_TYPE_EXTERNAL_FILE --> any_external_filename.jpg (only filename)
//+ (id)assetWithAssetURL:(NSString *)assetURL sourceType:(NSNumber *)sourceType {
//    __block id asset;
//
//    NSUInteger sourceTypeInteger = [sourceType unsignedIntegerValue];
//
//    if (ASSET_FILE_SOURCE_TYPE_PHASSET == sourceTypeInteger) {
//        PHFetchResult *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[assetURL] options:nil];
//
//        if ([fetchResult count] > 0) {
//            asset = [fetchResult firstObject];
//        }
//    } else if (ASSET_FILE_SOURCE_TYPE_SHARED_FILE == sourceTypeInteger) {
//        NSString *absolutePath = [[DirectoryService devicdSharingFolderPath] stringByAppendingPathComponent:assetURL];
//
//        BOOL isDirectory;
//        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:absolutePath isDirectory:&isDirectory];
//
//        if (fileExists && !isDirectory) {
//            asset = absolutePath;
//        }
//    } else if (ASSET_FILE_SOURCE_TYPE_EXTERNAL_FILE == sourceTypeInteger) {
//        NSString *absolutePath = [[DirectoryService directoryForExternalFilesWithCreatedIfNotExists:YES] stringByAppendingPathComponent:assetURL];
//
//        BOOL isDirectory;
//        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:absolutePath isDirectory:&isDirectory];
//
//        if (fileExists && !isDirectory) {
//            asset = absolutePath;
//        }
//    }
//
//    return asset;
//}

+ (void)updateFileTransferLocalPathToRelativePath {
    FileTransferDao *fileTransferDao1 = [[FileTransferDao alloc] init];
    [fileTransferDao1 updateFileTransferLocalPathToRelativePath];
}

+ (void)moveDownloadFileToAppGroupDirectory {
    NSFileManager *fileManager = [NSFileManager defaultManager];

    UserComputerDao *userComputerDao = [[UserComputerDao alloc] init];

    NSError *foundError;
    NSArray *allUserComputerIds = [userComputerDao findAllUserComputerIdsWithError:&foundError];

    if (allUserComputerIds && [allUserComputerIds count] > 0) {
        for (NSString *userComputerId in allUserComputerIds) {
            NSString *fromDirectoryPath = [DirectoryService localFileDirectoryPathWithUserComputerId:userComputerId];

            NSString *toDirectoryPath = [DirectoryService appGroupDirectoryPathWithUserComputerId:userComputerId];

            [fileManager moveItemAtPath:fromDirectoryPath toPath:toDirectoryPath error:NULL];

            // DEBUG
//            if (pathDeleteError) {
//                NSLog(@"Error on moving directory");
//                NSLog(@"Error on moving directory from: '%@' to '%@'", fromDirectoryPath, toDirectoryPath);
//            } else {
//                NSLog(@"Directory moved from '%@' to '%@'", fromDirectoryPath, toDirectoryPath);
//            }
        }
    }
}

- (void)findFileSizeWithPHAsset:(PHAsset *)asset completionHandler:(void (^)(NSUInteger fileSize, NSError *error))completionHandler {
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];

    options.synchronous = YES;
    options.networkAccessAllowed = YES;

    [[PHImageManager defaultManager] requestImageDataForAsset:asset options:options resultHandler:^(NSData * imageData, NSString * dataUTI, UIImageOrientation orientation, NSDictionary * info) {
        if (completionHandler) {
            NSError *requestError = info[PHImageErrorKey];

            if (requestError) {
                completionHandler(0, requestError);
            } else {
                completionHandler(imageData.length, nil);
            }
        }
    }];
}

- (void)findFileUploadStatusWithTransferKey:(NSString *)transferKey session:(NSString *)sessionId completionHandler:(void (^)(FileUploadStatusModel *, NSInteger statusCode, NSError *))completionHandler {
    if (completionHandler) {
        NSString *urlString = [Utility composeLugServerURLStringWithPath:@"directory/find-dupload"];

        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];

        [request setHTTPMethod:@"POST"];

        NSString *bodyString = [NSString stringWithFormat:@"{\"transferKey\":\"%@\"}", transferKey];

        [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];

        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

        [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];

        [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

            if (error) {
                completionHandler(nil, statusCode, error);
            } else {
                if (statusCode == 200) {
                    // save response data

                    if (data) {
                        NSError *jsonError = nil;
                        NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];

                        if (jsonError) {
                            NSError *incorrectResponseDataFormatError = [Utility generateIncorrectDataFormatError];

                            completionHandler(nil, statusCode, incorrectResponseDataFormatError);
                        } else {
                            NSString *foundTransferKey = jsonObject[@"transferKey"];
                            NSNumber *transferredSize = jsonObject[@"transferredSize"];
                            NSNumber *fileSize = jsonObject[@"fileSize"];
                            NSNumber *fileLastModifiedDate = jsonObject[@"fileLastModifiedDate"];

                            if (!foundTransferKey || !transferredSize || !fileSize || !fileLastModifiedDate || ![foundTransferKey isEqualToString:transferKey]) {
                                NSError *incorrectResponseDataFormatError = [Utility generateIncorrectDataFormatError];

                                completionHandler(nil, statusCode, incorrectResponseDataFormatError);
                            } else {
                                FileUploadStatusModel *fileUploadStatusModel = [[FileUploadStatusModel alloc] initWithTransferKey:foundTransferKey transferredSize:transferredSize fileSize:fileSize fileLastModifiedDate:fileLastModifiedDate];

                                completionHandler(fileUploadStatusModel, statusCode, nil);
                            }
                        }
                    } else {
                        NSLog(@"[saveRequestConnectData]: Nil data.");
                    }
                } else {
                    NSString *errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Error on finding uploading status with status code", @""), statusCode];

                    NSError *unknownError = [Utility errorWithErrorCode:ERROR_CODE_UNKNOW_KEY localizedDescription:errorMessage];

                    completionHandler(nil, statusCode, unknownError);
                }
            }
        }] resume];
    }
}

@end
