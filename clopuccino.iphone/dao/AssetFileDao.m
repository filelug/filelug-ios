#import <CoreData/CoreData.h>
#import "AssetFileDao.h"
#import "AssetFileWithoutManaged.h"
#import "ClopuccinoCoreData.h"
#import "AssetFile+CoreDataClass.h"
#import "Utility.h"
#import "UserComputer+CoreDataClass.h"
#import "UserComputerDao.h"
#import "FileUploadGroup+CoreDataClass.h"
#import "FileUploadGroupDao.h"
#import "UIColor+Filelug.h"

@interface AssetFileDao ()

@property(nonatomic, strong) ClopuccinoCoreData *coreData;

@property(nonatomic, strong) UserComputerDao *userComputerDao;

@property(nonatomic, strong) FileUploadGroupDao *fileUploadGroupDao;

@end

@implementation AssetFileDao {
}

+ (NSString *)assetFileFetchedResultsControllerCacheNameWithUserComputerId:(NSString *)userComputerId {
    return [NSString stringWithFormat:@"assetFile+%@", userComputerId];
}

- (id)init {
    self = [super init];
    if (self) {
        _coreData = [ClopuccinoCoreData defaultCoreData];
        _userComputerDao = [[UserComputerDao alloc] init];
        _fileUploadGroupDao = [[FileUploadGroupDao alloc] init];
    }
    
    return self;
}

- (void)createAssetFileFromAssetFileWithoutManaged:(AssetFileWithoutManaged *)assetFileWithoutManaged completionHandler:(void (^ _Nullable)(void))completionHandler {
    /* DEBUG */
    //    NSLog(@"AssetFileWithoutManaged created: %@", [assetFileWithoutManaged description]);
    
    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];
    
    [moc performBlock:^() {
        UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:assetFileWithoutManaged.userComputerId managedObjectContext:moc];
        
        if (userComputer) {
            AssetFile *assetFile = (AssetFile *) [NSEntityDescription insertNewObjectForEntityForName:@"AssetFile" inManagedObjectContext:moc];
            
            assetFile.userComputer = userComputer;
            assetFile.assetURL = assetFileWithoutManaged.assetURL;
            assetFile.downloadedFileTransferKey = assetFileWithoutManaged.downloadedFileTransferKey;
            assetFile.startTimestamp = assetFileWithoutManaged.startTimestamp;
            assetFile.endTimestamp = assetFileWithoutManaged.endTimestamp;
            assetFile.serverDirectory = assetFileWithoutManaged.serverDirectory;
            assetFile.serverFilename = assetFileWithoutManaged.serverFilename;
            assetFile.status = assetFileWithoutManaged.status;
            assetFile.totalSize = assetFileWithoutManaged.totalSize;
            assetFile.transferredSize = assetFileWithoutManaged.transferredSize;
            assetFile.waitToConfirm = assetFileWithoutManaged.waitToConfirm;
            assetFile.transferKey = assetFileWithoutManaged.transferKey;

            assetFile.sourceType = assetFileWithoutManaged.sourceType;
            
            UIImage *thumbnail = assetFileWithoutManaged.thumbnail;

            // no thumbnail for shared files or external files
            if (thumbnail) {
                NSData *thumbnailData = [Utility dataFromImage:thumbnail];

                if (!thumbnailData) {
                    NSLog(@"Failed to convert image to data for file: %@", assetFileWithoutManaged.assetURL);
                } else {
                    assetFile.thumbnail = thumbnailData;
                }
            }

            NSString *fileUploadGroupId = assetFileWithoutManaged.fileUploadGroupId;
            
            if (fileUploadGroupId && [fileUploadGroupId stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
                FileUploadGroup *fileUploadGroup = [self.fileUploadGroupDao findFileUploadGroupByUploadGroupId:fileUploadGroupId managedObjectContext:moc];
                
                if (fileUploadGroup) {
                    assetFile.fileUploadGroup = fileUploadGroup;
                }
            }
            
            if (completionHandler) {
                [self.coreData saveContext:moc completionHandler:completionHandler];
            } else {
                [self.coreData saveContext:moc];
            }
        }
    }];
}

- (NSNumber *)countForTransferKey:(NSString *)transferKey error:(NSError * __autoreleasing *)error {
    __block NSNumber *fileCount;
    __block NSError *countError;
    
    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];
    
    [moc performBlockAndWait:^() {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"transferKey == %@", transferKey];
        [request setPredicate:predicate];
        
        [request setIncludesSubentities:NO];
        
        NSUInteger count = [moc countForFetchRequest:request error:&countError];
        fileCount = (count == NSNotFound) ? @0 : @(count);
    }];

    if (error && countError) {
        *error = countError;
    }
    
    return fileCount;
}

- (AssetFileWithoutManaged *)findAssetFileForFetchedResultsController:(NSFetchedResultsController *)fetchedResultsController objectAtIndexPath:(NSIndexPath *)indexPath {
    __block AssetFileWithoutManaged *assetFileWithoutManaged;
    
    @autoreleasepool {
        NSManagedObjectContext *moc = [fetchedResultsController managedObjectContext];
        
        [moc performBlockAndWait:^() {
            id assetFile = [fetchedResultsController objectAtIndexPath:indexPath];

            if (assetFile && [assetFile isKindOfClass:[AssetFile class]]) {
                AssetFile *fetchedAssetFile = (AssetFile *) assetFile;

                NSString *transferKey = fetchedAssetFile.transferKey;

                if (transferKey) {
                    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];

                    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"transferKey == %@", transferKey];
                    [request setPredicate:predicate];

                    [request setIncludesSubentities:NO];

                    NSError *fetchError;
                    NSArray *results = [moc executeFetchRequest:request error:&fetchError];

                    if (!fetchError && results && [results count] > 0) {
                        assetFileWithoutManaged = [self assetFileWithoutManagedFromAssetFile:results[0]];
                    }
                }
            }
        }];
    }
    
    return assetFileWithoutManaged;
}

- (AssetFileWithoutManaged *)findAssetFileForTransferKey:(NSString *)transferKey error:(NSError * __autoreleasing *)error {
    __block AssetFileWithoutManaged *assetFileWithoutManaged;
    __block NSError *findError;
    
    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];
    
    [moc performBlockAndWait:^() {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"transferKey == %@", transferKey];
        [request setPredicate:predicate];
        
        [request setIncludesSubentities:NO];
        
        NSArray *results = [moc executeFetchRequest:request error:&findError];
        
        if (results && [results count] > 0) {
            assetFileWithoutManaged = [self assetFileWithoutManagedFromAssetFile:results[0]];
        }
    }];

    if (error && findError) {
        *error = findError;
    }
    
    return assetFileWithoutManaged;
}

- (void)findAssetFileForTransferKey:(NSString *)transferKey completionHandler:(void (^ _Nullable)(AssetFileWithoutManaged *, NSError *))completionHandler {
    if (completionHandler) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlock:^() {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];

            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"transferKey == %@", transferKey];
            [request setPredicate:predicate];

            [request setIncludesSubentities:NO];

            NSError *findError;
            NSArray *results = [moc executeFetchRequest:request error:&findError];

            AssetFileWithoutManaged *assetFileWithoutManaged;

            if (results && [results count] > 0) {
                assetFileWithoutManaged = [self assetFileWithoutManagedFromAssetFile:results[0]];
            }

            completionHandler(assetFileWithoutManaged, findError);
        }];
    }
}

- (void)findAssetFileForDownloadedFileTransferKey:(NSString *)downloadedFileTransferKey completionHandler:(void (^ _Nullable)(NSArray<AssetFileWithoutManaged *> *, NSError *))completionHandler {
    if (completionHandler) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlock:^() {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];

            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"downloadedFileTransferKey == %@", downloadedFileTransferKey];
            [request setPredicate:predicate];

            [request setIncludesSubentities:NO];

            NSError *findError;
            NSArray *results = [moc executeFetchRequest:request error:&findError];

            NSMutableArray<AssetFileWithoutManaged *> *assetFileWithoutManageds = [NSMutableArray array];

            if (results && [results count] > 0) {
                for (AssetFile *assetFile in results) {
                    [assetFileWithoutManageds addObject:[self assetFileWithoutManagedFromAssetFile:assetFile]];
                }
            }

            completionHandler(assetFileWithoutManageds, findError);
        }];
    }
}

- (NSString *)findComputerNameForTransferKey:(NSString *)transferKey {
    __block NSString *computerName;
    
    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];
    
    [moc performBlockAndWait:^() {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"transferKey == %@", transferKey];
        [request setPredicate:predicate];
        
        [request setIncludesSubentities:NO];
        
        NSArray *results = [moc executeFetchRequest:request error:NULL];
        
        if (results && [results count] > 0) {
            computerName = ((AssetFile *) results[0]).userComputer.computerName;
        }
    }];
    
    return computerName;
}

- (NSString *)findFileUploadStatusForTransferKey:(NSString *)transferKey {
    if (transferKey) {
        __block NSString *status;

        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlockAndWait:^() {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];

            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"transferKey == %@", transferKey];
            [request setPredicate:predicate];

            [request setIncludesSubentities:NO];

            NSArray *results = [moc executeFetchRequest:request error:NULL];

            if (results && [results count] > 0) {
                status = ((AssetFile *) results[0]).status;
            }
        }];

        return status;
    } else {
        return nil;
    }
}

- (void)deleteAssetFileForTransferKey:(NSString *)transferKey successHandler:(void (^)(void))successHandler errorHandler:(void (^)(NSError *error))errorHandler {
    if (transferKey) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlock:^() {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];

            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"transferKey == %@", transferKey];
            [request setPredicate:predicate];

            [request setIncludesSubentities:NO];

            NSError *findError;

            NSArray *results = [moc executeFetchRequest:request error:&findError];

            if (!findError) {
                if (results && [results count] > 0) {
                    [moc deleteObject:results[0]];

                    if (successHandler) {
                        [self.coreData saveContext:moc completionHandler:successHandler];
                    } else {
                        [self.coreData saveContext:moc];
                    }
                } else {
                    NSError *deleteError = [Utility errorWithErrorCode:NSFileNoSuchFileError localizedDescription:NSLocalizedString(@"No such file.", @"")];

                    errorHandler(deleteError);
                }
            } else {
                errorHandler(findError);
            }
        }];
    }
}

- (NSNumber *)countForUserComputer:(NSString *)userComputerId fileUploadGroupId:(NSString *)fileUploadGroupId assetURL:(NSString *)assetURL directory:(NSString *)directory filename:(NSString *)filename error:(NSError * __autoreleasing *)error {
    __block NSNumber *uploadCount;
    __block NSError *countError;

    if (userComputerId && assetURL && directory && filename) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlockAndWait:^() {
            UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

            if (userComputer) {
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];

                NSPredicate *predicate;

                FileUploadGroup *fileUploadGroup = [self.fileUploadGroupDao findFileUploadGroupByUploadGroupId:fileUploadGroupId managedObjectContext:moc];

                if (fileUploadGroup) {
                    predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND fileUploadGroup == %@ AND assetURL == %@ AND serverDirectory == %@ AND serverFilename == %@", userComputer, fileUploadGroup, assetURL, directory, filename];
                } else {
                    predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND (fileUploadGroup == nil OR fileUploadGroup == %@) AND assetURL == %@ AND serverDirectory == %@ AND serverFilename == %@", userComputer, @"", assetURL, directory, filename];
                }

                [request setPredicate:predicate];

                [request setIncludesSubentities:NO];

                NSUInteger count = [moc countForFetchRequest:request error:&countError];
                uploadCount = (count == NSNotFound) ? @0 : @(count);
            }
        }];
    }

    if (error && countError) {
        *error = countError;
    }
    
    return uploadCount ? uploadCount : @0;
}

// return array with elements of AssetFileWithoutManaged
- (NSArray *)findAssetFileForUserComputer:(NSString *)userComputerId fileUploadGroupId:(NSString *)fileUploadGroupId directory:(NSString *)directory filename:(NSString *)filename error:(NSError * __autoreleasing *)error {
    __block NSMutableArray *assetFiles = [NSMutableArray array];
    __block NSError *findError;

    if (userComputerId && directory && filename) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlockAndWait:^() {
            UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

            if (userComputer) {
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];

                FileUploadGroup *fileUploadGroup = [self.fileUploadGroupDao findFileUploadGroupByUploadGroupId:fileUploadGroupId managedObjectContext:moc];

                NSPredicate *predicate;

                if (fileUploadGroup) {
                    predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND fileUploadGroup == %@ AND serverDirectory == %@ AND serverFilename == %@", userComputer, fileUploadGroup, directory, filename];
                } else {
                    predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND (fileUploadGroup == nil OR fileUploadGroup == %@) AND serverDirectory == %@ AND serverFilename == %@", userComputer, @"", directory, filename];
                }

                [request setPredicate:predicate];

                [request setIncludesSubentities:NO];

                NSArray *results = [moc executeFetchRequest:request error:&findError];

                if (results && [results count] > 0) {
                    for (AssetFile *assetFile in results) {
                        [assetFiles addObject:[self assetFileWithoutManagedFromAssetFile:assetFile]];
                    }
                }
            } else {
                NSLog(@"User computer '%@' not found.", userComputerId);
            }
        }];
    }

    if (error && findError) {
        *error = findError;
    }
    
    return assetFiles;
}

// completionHandler will be invoked on each found AssetFile
- (void)findAssetFilesWithFileUploadGroupId:(NSString *)fileUploadGroupId completionHandler:(void (^ _Nullable)(AssetFile *))completionHandler {
    if (completionHandler) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlockAndWait:^() {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];

            FileUploadGroup *fileUploadGroup = [self.fileUploadGroupDao findFileUploadGroupByUploadGroupId:fileUploadGroupId managedObjectContext:moc];

            if (fileUploadGroup) {
                NSPredicate *predicate;

                predicate = [NSPredicate predicateWithFormat:@"fileUploadGroup == %@", fileUploadGroup];

                [request setPredicate:predicate];

                [request setIncludesSubentities:NO];

                NSArray *results = [moc executeFetchRequest:request error:NULL];

                if (results && [results count] > 0) {
                    for (AssetFile *assetFile in results) {
                        completionHandler(assetFile);
                    }
                }
            }
        }];
    }
}

- (AssetFileWithoutManaged *)findAssetFileForUserComputer:(NSString *)userComputerId fileUploadGroupId:(NSString *)fileUploadGroupId assetURL:(NSString *)assetURL directory:(NSString *)directory filename:(NSString *)filename error:(NSError * __autoreleasing *)error {
    __block AssetFileWithoutManaged *assetFileWithoutManaged;
    __block NSError *findError;

    if (userComputerId && assetURL && directory && filename) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlockAndWait:^() {
            UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

            if (userComputer) {
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];

                FileUploadGroup *fileUploadGroup = [self.fileUploadGroupDao findFileUploadGroupByUploadGroupId:fileUploadGroupId managedObjectContext:moc];

                NSPredicate *predicate;

                if (fileUploadGroup) {
                    predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND fileUploadGroup == %@ AND assetURL == %@ AND serverDirectory == %@ AND serverFilename == %@", userComputer, fileUploadGroup, assetURL, directory, filename];
                } else {
                    predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND (fileUploadGroup == nil OR fileUploadGroup == %@) AND assetURL == %@ AND serverDirectory == %@ AND serverFilename == %@", userComputer, @"", assetURL, directory, filename];
                }

                [request setPredicate:predicate];

                [request setIncludesSubentities:NO];

                NSArray *results = [moc executeFetchRequest:request error:&findError];

                if (results && [results count] > 0) {
                    assetFileWithoutManaged = [self assetFileWithoutManagedFromAssetFile:results[0]];
                }
            } else {
                NSLog(@"User computer '%@' not found.", userComputerId);
            }
        }];
    }

    if (error && findError) {
        *error = findError;
    }
    
    return assetFileWithoutManaged;
}

- (void)findWaitToConfirmAssetFileTransferKeyAndStatusDictionaryWithCompletionHandler:(void (^)(NSDictionary *transferKeyAndStatusDictionary))completionHandler {
    if (completionHandler) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];
        
        [moc performBlock:^() {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];
            
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"waitToConfirm == %@", @YES];
            [request setPredicate:predicate];
            
            NSSortDescriptor *startTimestampSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"startTimestamp" ascending:NO];
            [request setSortDescriptors:@[startTimestampSortDescriptor]];
            
            NSArray *assetFiles = [moc executeFetchRequest:request error:NULL];
            
            NSMutableDictionary *mutableDictionary = [NSMutableDictionary dictionary];
            
            if (assetFiles && [assetFiles count] > 0) {
                for (AssetFile *assetFile in assetFiles) {
                    mutableDictionary[assetFile.transferKey] = assetFile.status;
                }
            }
            
            // no matter found or not
            completionHandler(mutableDictionary);
        }];
    }
}

- (NSDictionary *)findWaitToConfirmAssetFileTransferKeyAndStatusDictionary {
    __block NSDictionary *dictionary;
    
    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];
    
    [moc performBlockAndWait:^() {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"waitToConfirm == %@", @YES];
        [request setPredicate:predicate];
        
        NSSortDescriptor *startTimestampSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"startTimestamp" ascending:NO];
        [request setSortDescriptors:@[startTimestampSortDescriptor]];
        
        NSArray *assetFiles = [moc executeFetchRequest:request error:NULL];
        
        NSMutableDictionary *mutableDictionary = [NSMutableDictionary dictionary];
        
        if (assetFiles && [assetFiles count] > 0) {
            for (AssetFile *assetFile in assetFiles) {
                mutableDictionary[assetFile.transferKey] = assetFile.status;
            }
        }
        
        dictionary = mutableDictionary;
    }];
    
    return dictionary;
}

- (void)findWaitToConfirmAssetFileWithCompletionHandler:(void (^)(AssetFileWithoutManaged *assetFileWithoutManaged))completionHandler {
    if (completionHandler) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];
        
        [moc performBlock:^() {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];
            
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"waitToConfirm == %@", @YES];
            [request setPredicate:predicate];
            
            NSSortDescriptor *startTimestampSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"startTimestamp" ascending:NO];
            [request setSortDescriptors:@[startTimestampSortDescriptor]];
            
            NSArray *assetFiles = [moc executeFetchRequest:request error:NULL];
            
            if (assetFiles && [assetFiles count] > 0) {
                for (AssetFile *assetFile in assetFiles) {
                    AssetFileWithoutManaged *waitToConfirmAssetFileWithoutManaged = [self assetFileWithoutManagedFromAssetFile:assetFile];
                    
                    completionHandler(waitToConfirmAssetFileWithoutManaged);
                }
            }
        }];
    }
}

// make sure it is wrapped under performBlock: or performBlockAndWait:
- (AssetFileWithoutManaged *)assetFileWithoutManagedFromAssetFile:(AssetFile *)assetFile {
    AssetFileWithoutManaged *assetFileWithoutManaged;
    
    if (assetFile) {
        NSData *imageData = assetFile.thumbnail;
        
        UIImage *thumbnail;
        if (imageData) {
            thumbnail = [UIImage imageWithData:imageData];
        }
        
        assetFileWithoutManaged =
                [[AssetFileWithoutManaged alloc] initWithUserComputerId:assetFile.userComputer.userComputerId
                                                      fileUploadGroupId:assetFile.fileUploadGroup.uploadGroupId
                                                            transferKey:assetFile.transferKey
                                                               assetURL:assetFile.assetURL
                                                             sourceType:[assetFile.sourceType unsignedIntegerValue]
                                                        serverDirectory:assetFile.serverDirectory
                                                         serverFilename:assetFile.serverFilename
                                                                 status:assetFile.status
                                                              thumbnail:thumbnail
                                                              totalSize:assetFile.totalSize
                                                        transferredSize:assetFile.transferredSize
                                            transferredSizeBeforeResume:assetFile.transferredSizeBeforeResume
                                                         startTimestamp:assetFile.startTimestamp
                                                           endTimestamp:assetFile.endTimestamp
                                                        waitToConfirmed:assetFile.waitToConfirm
                                              downloadedFileTransferKey:assetFile.downloadedFileTransferKey];
//        assetFileWithoutManaged =
//                [[AssetFileWithoutManaged alloc] initWithUserComputerId:assetFile.userComputer.userComputerId
//                                                      fileUploadGroupId:assetFile.fileUploadGroup.uploadGroupId
//                                                            transferKey:assetFile.transferKey
//                                                               assetURL:assetFile.assetURL
//                                                             sourceType:[assetFile.sourceType unsignedIntegerValue]
//                                                        serverDirectory:assetFile.serverDirectory
//                                                         serverFilename:assetFile.serverFilename
//                                                                 status:assetFile.status
//                                                              thumbnail:thumbnail
//                                                              totalSize:assetFile.totalSize
//                                                        transferredSize:assetFile.transferredSize
//                                            transferredSizeBeforeResume:assetFile.transferredSizeBeforeResume
//                                                         startTimestamp:assetFile.startTimestamp
//                                                           endTimestamp:assetFile.endTimestamp
//                                                        waitToConfirmed:assetFile.waitToConfirm];
    }
    
    return assetFileWithoutManaged;
}

- (void)updateAssetFile:(AssetFileWithoutManaged *)assetFileWithoutManaged {
    [self updateAssetFile:assetFileWithoutManaged completionHandler:nil];
}

- (void)updateAssetFile:(AssetFile *)assetFile managedObjectContext:(NSManagedObjectContext *)moc {
    if (assetFile) {
        [self.coreData saveContext:moc];
    }
}

- (void)updateAssetFile:(AssetFileWithoutManaged *)assetFileWithoutManaged completionHandler:(void (^)(void))completionHandler {
    if (assetFileWithoutManaged && assetFileWithoutManaged.userComputerId && assetFileWithoutManaged.assetURL && assetFileWithoutManaged.serverDirectory && assetFileWithoutManaged.serverFilename) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlock:^() {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];

            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"transferKey == %@", assetFileWithoutManaged.transferKey];
            [request setPredicate:predicate];

            NSError *fetchError;
            NSArray *assetFiles = [moc executeFetchRequest:request error:&fetchError];

            if (assetFiles && [assetFiles count] > 0) {
                AssetFile *assetFile = assetFiles[0];

                [self updateWithoutCommitAssetFile:assetFile withAssetFileWithoutManaged:assetFileWithoutManaged];

                if (completionHandler) {
                    [self.coreData saveContext:moc completionHandler:completionHandler];
                } else {
                    [self.coreData saveContext:moc];
                }
            } else if (fetchError) {
                NSLog(@"Error on finding AssetFile by transfer key: %@\n%@", assetFileWithoutManaged.transferKey, [fetchError userInfo]);
            }
        }];
    }
}

- (void)updateWithoutCommitAssetFile:(AssetFile *)assetFile withAssetFileWithoutManaged:(AssetFileWithoutManaged *)assetFileWithoutManaged {
    // No update to both user computer and file upload group
    
    NSString *newStatus = assetFileWithoutManaged.status;
    NSString *oldStatus = assetFile.status;
    
    // 排除狀態從 success/failed 改成 canceling
    if (!([newStatus isEqualToString:FILE_TRANSFER_STATUS_CANCELING] && ([oldStatus isEqualToString:FILE_TRANSFER_STATUS_SUCCESS] || [oldStatus isEqualToString:FILE_TRANSFER_STATUS_FAILED]))) {
        assetFile.status = assetFileWithoutManaged.status;
    }
    
    assetFile.totalSize = assetFileWithoutManaged.totalSize;
    assetFile.transferredSize = assetFileWithoutManaged.transferredSize;
    assetFile.startTimestamp = assetFileWithoutManaged.startTimestamp;
    assetFile.endTimestamp = assetFileWithoutManaged.endTimestamp;
    assetFile.waitToConfirm = assetFileWithoutManaged.waitToConfirm;
    
    assetFile.assetURL = assetFileWithoutManaged.assetURL;
    assetFile.downloadedFileTransferKey = assetFileWithoutManaged.downloadedFileTransferKey;
    assetFile.serverDirectory = assetFileWithoutManaged.serverDirectory;
    assetFile.serverFilename = assetFileWithoutManaged.serverFilename;

    NSNumber *transferredSizeBeforeResume = assetFileWithoutManaged.transferredSizeBeforeResume;

    if (transferredSizeBeforeResume) {
        assetFile.transferredSizeBeforeResume = transferredSizeBeforeResume;
    } else {
        assetFile.transferredSizeBeforeResume = @0;
    }
}

- (NSFetchedResultsController *)createFileUploadFetchedResultsControllerForUserComputerId:(NSString *)userComputerId delegate:(id <NSFetchedResultsControllerDelegate>)delegate {
    __block NSFetchedResultsController *controller;
    
    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlockAndWait:^() {
        UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];
        
        if (userComputer) {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];
            
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@", userComputer];
            [request setPredicate:predicate];
            
            // Make sure after sorting, the sequence is constants all the time
            // Sort by fileUploadGroup.createTimestamp so different upload group get together

            NSString *createTimestampKeyPath = @"fileUploadGroup.createTimestamp";

            NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:createTimestampKeyPath ascending:NO];
            // separate ALAssets/PHAssets from Shared files
            NSSortDescriptor *sortDescriptor2 = [NSSortDescriptor sortDescriptorWithKey:@"sourceType" ascending:YES];
            NSSortDescriptor *sortDescriptor3 = [NSSortDescriptor sortDescriptorWithKey:@"serverFilename" ascending:YES];
            [request setSortDescriptors:@[sortDescriptor1, sortDescriptor2, sortDescriptor3]];

            // Stop using cache to prevent the following error to crash APP:
            // uncaught exception 'NSInternalInconsistencyException', reason: 'CoreData: FATAL ERROR:
            // The persistent cache of section information does not match the current configuration.
            // You have illegally mutated the NSFetchedResultsController's fetch request, its predicate,
            // or its sort descriptor without either disabling caching or using +deleteCacheWithName:'
            controller = [[NSFetchedResultsController alloc] initWithFetchRequest:request managedObjectContext:moc sectionNameKeyPath:createTimestampKeyPath cacheName:nil];

            controller.delegate = delegate;
        }
    }];
    
    return controller;
}

- (NSFetchedResultsController *)createFileUploadFetchedResultsControllerForTransferKey:(NSString *)transferKey delegate:(id <NSFetchedResultsControllerDelegate>)delegate {
    __block NSFetchedResultsController *controller;

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlockAndWait:^() {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];

        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"transferKey == %@", transferKey];
        [request setPredicate:predicate];

        NSSortDescriptor *startTimestampSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"startTimestamp" ascending:NO];
        [request setSortDescriptors:@[startTimestampSortDescriptor]];

        controller = [[NSFetchedResultsController alloc] initWithFetchRequest:request managedObjectContext:moc sectionNameKeyPath:nil cacheName:nil];
        controller.delegate = delegate;
    }];

    return controller;
}

- (BOOL)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController performFetch:(NSError * __autoreleasing *)error {
    __block BOOL success = NO;
    __block NSError *fetchError;
    
    NSManagedObjectContext *moc = fetchedResultsController.managedObjectContext;
    
    [moc performBlockAndWait:^() {
        if (fetchedResultsController) {
            success = [fetchedResultsController performFetch:&fetchError];
        }
    }];

    if (error && fetchError) {
        *error = fetchError;
    }
    
    return success;
}

- (AssetFileWithoutManaged *)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController objectAtIndexPath:(NSIndexPath *)indexPath {
    __block AssetFileWithoutManaged *assetFileWithoutManaged;

    NSManagedObjectContext *moc = fetchedResultsController.managedObjectContext;

    [moc performBlockAndWait:^() {
        id assetFile = [fetchedResultsController objectAtIndexPath:indexPath];

        if (assetFile && [assetFile isKindOfClass:[AssetFile class]]) {
            assetFileWithoutManaged = [self assetFileWithoutManagedFromAssetFile:(AssetFile *) assetFile];
        }
    }];

    return assetFileWithoutManaged;
}

- (NSInteger)numberOfSectionsForFetchedResultsController:(NSFetchedResultsController *)fetchedResultsController {
    __block NSInteger count = 0;
    
    NSManagedObjectContext *moc = fetchedResultsController.managedObjectContext;
    
    [moc performBlockAndWait:^() {
        count = [[fetchedResultsController sections] count];
    }];
    
    return count;
}

- (NSString *)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController titleForHeaderInSection:(NSInteger)section {
    __block NSString *title = @"";
    
    NSManagedObjectContext *moc = fetchedResultsController.managedObjectContext;
    
    [moc performBlockAndWait:^() {
        if ([[fetchedResultsController sections] count] > 0) {
            id <NSFetchedResultsSectionInfo> sectionInfo = [fetchedResultsController sections][(NSUInteger) section];

            NSUInteger count = [sectionInfo numberOfObjects];

            NSString *countDescription;
            if (count > 1) {
                countDescription = [NSString stringWithFormat:NSLocalizedString(@"(N Files)", @""), (long)count];
            } else {
                countDescription = NSLocalizedString(@"(1 File)", @"");
            }

            NSString *sectionPrefix;

            @try {
                NSString *javaTimeMillisInString = [sectionInfo name];

                NSDate *date = [Utility dateFromJavaTimeMillisecondsString:javaTimeMillisInString];

                sectionPrefix = [Utility dateStringFromDate:date];

                if (!sectionPrefix) {
                    sectionPrefix = @"";
                }
            } @catch (NSException *e) {
                sectionPrefix = @"";
            }

            title = [NSString stringWithFormat:@"%@%@", sectionPrefix, countDescription];
        }
    }];
    
    return title;
}

- (NSInteger)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController numberOfRowsInSection:(NSInteger)section {
    __block NSInteger count = 0;
    
    NSManagedObjectContext *moc = fetchedResultsController.managedObjectContext;
    
    [moc performBlockAndWait:^() {
        id <NSFetchedResultsSectionInfo> sectionInfo = [fetchedResultsController sections][(NSUInteger) section];
        
        if (sectionInfo) {
            count = [sectionInfo numberOfObjects];
        }
    }];
    
    return count;
}

- (NSIndexPath *)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController indexPathForTransferKey:(NSString *)transferKey {
    __block NSIndexPath *indexPath;

    NSManagedObjectContext *moc = fetchedResultsController.managedObjectContext;
    
    [moc performBlockAndWait:^() {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"transferKey == %@", transferKey];
        [request setPredicate:predicate];
        
        [request setIncludesSubentities:NO];
        
        NSArray *results = [moc executeFetchRequest:request error:NULL];
        
        if (results && [results count] > 0) {
            AssetFile *assetFile = results[0];
            
            indexPath = [fetchedResultsController indexPathForObject:assetFile];
        }
    }];
    
    return indexPath;
}

- (NSArray *)findAssetFilesForAssetURL:(NSString *)assetURL {
    __block NSMutableArray *assetFiles = [NSMutableArray array];

    if (assetURL) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlockAndWait:^() {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];

            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"assetURL == %@", assetURL];
            [request setPredicate:predicate];

            [request setIncludesSubentities:NO];

            NSArray *results = [moc executeFetchRequest:request error:NULL];

            if (results && [results count] > 0) {
                for (AssetFile *assetFile in results) {
                    [assetFiles addObject:[self assetFileWithoutManagedFromAssetFile:assetFile]];
                }
            }
        }];
    }
    
    return assetFiles;
}

- (BOOL)existsAssetFilesForAssetURL:(NSString *)assetURL {
    __block BOOL fileExists = NO;

    if (assetURL) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlockAndWait:^() {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];

            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"assetURL == %@", assetURL];
            [request setPredicate:predicate];

            [request setIncludesSubentities:NO];

            NSArray *results = [moc executeFetchRequest:request error:NULL];

            fileExists = results && ([results count] > 0);
        }];
    }
    
    return fileExists;
}

- (NSArray *)findAssetFilesForAssetURLWithSuffix:(NSString *)suffix {
    __block NSMutableArray *assetFiles = [NSMutableArray array];

    if (suffix) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlockAndWait:^() {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];

            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"assetURL endswith %@", suffix];
            [request setPredicate:predicate];

            [request setIncludesSubentities:NO];

            NSArray *results = [moc executeFetchRequest:request error:NULL];

            if (results && [results count] > 0) {
                for (AssetFile *assetFile in results) {
                    [assetFiles addObject:[self assetFileWithoutManagedFromAssetFile:assetFile]];
                }
            }
        }];
    }
    
    return assetFiles;
}

- (NSDictionary *)findUnfinishedAssetFileTransferKeyAndStatusDictionary {
    __block NSDictionary *dictionary;
    
    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];
    
    [moc performBlockAndWait:^() {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"status != %@ AND status != %@ AND status != %@", FILE_TRANSFER_STATUS_SUCCESS, FILE_TRANSFER_STATUS_FAILED, FILE_TRANSFER_STATUS_CANCELING];
        [request setPredicate:predicate];
        
        NSSortDescriptor *startTimestampSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"startTimestamp" ascending:NO];
        [request setSortDescriptors:@[startTimestampSortDescriptor]];
        
        NSArray *assetFiles = [moc executeFetchRequest:request error:NULL];
        
        NSMutableDictionary *mutableDictionary = [NSMutableDictionary dictionary];
        
        if (assetFiles && [assetFiles count] > 0) {
            NSLog(@"There are %lu upload(s) not success nor failure.", (unsigned long) [assetFiles count]);
            
            for (AssetFile *assetFile in assetFiles) {
                mutableDictionary[assetFile.transferKey] = assetFile.status;
            }
        }
        
        dictionary = mutableDictionary;
    }];
    
    return dictionary;
}

- (BOOL)existingUnfinishedAssetFile {
    __block BOOL hasNotFinished;
    
    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];
    
    [moc performBlockAndWait:^() {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"status != %@ AND status != %@ AND status != %@", FILE_TRANSFER_STATUS_SUCCESS, FILE_TRANSFER_STATUS_FAILED, FILE_TRANSFER_STATUS_CANCELING];
        [request setPredicate:predicate];
        
        NSArray *assetFiles = [moc executeFetchRequest:request error:NULL];
        
        hasNotFinished = (assetFiles && [assetFiles count] > 0);
    }];
    
    return hasNotFinished;
}

- (AssetFileWithoutManaged *)findFirstAssetFileWithStatusPreparingOrderByStartTimestampASC {
    __block AssetFileWithoutManaged *assetFile;
    
    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];
    
    [moc performBlockAndWait:^() {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"status == %@", FILE_TRANSFER_STATUS_PREPARING];
        [request setPredicate:predicate];
        
        NSSortDescriptor *startTimestampSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"startTimestamp" ascending:YES];
        [request setSortDescriptors:@[startTimestampSortDescriptor]];
        
        [request setIncludesSubentities:NO];
        
        NSArray *results = [moc executeFetchRequest:request error:NULL];
        
        if (results && [results count] > 0) {
            assetFile = [self assetFileWithoutManagedFromAssetFile:results[0]];
        }
    }];
    
    return assetFile;
}

- (BOOL)existsAssetFileWithStatusPreparing {
    __block BOOL fileExists = NO;
    
    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];
    
    [moc performBlockAndWait:^() {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"status == %@", FILE_TRANSFER_STATUS_PREPARING];
        [request setPredicate:predicate];
        
        [request setIncludesSubentities:NO];
        
        NSArray *results = [moc executeFetchRequest:request error:NULL];
        
        fileExists = results && ([results count] > 0);
    }];
    
    return fileExists;
}

- (void)prepareUploadStatusWithAssetFileWithoutManaged:(AssetFileWithoutManaged *)assetFileWithoutManaged
                                   currentStatusString:(NSString *)currentStatusString
                                    currentStatusColor:(UIColor *)currentStatusColor
                                     completionHandler:(void (^)(NSString *statusString, UIColor *statusColor))completionHandler {
    NSString *statusString;
    UIColor *statusColor;

    NSString *uploadStatus = assetFileWithoutManaged.status;

    if ([uploadStatus isEqualToString:FILE_TRANSFER_STATUS_PROCESSING]) {
        NSNumber *transferredSize = assetFileWithoutManaged.transferredSize;
        NSNumber *totalSize = assetFileWithoutManaged.totalSize;

        float percentage = [Utility divideDenominator:totalSize byNumerator:transferredSize];

        // update text only when the percentage is larger than the old or the percentage is 1

        statusString = [NSString stringWithFormat:@"%@(%.0f%%)", NSLocalizedString(@"File is uploading", @""), percentage * 100];
        statusColor = [UIColor aquaColor];
    } else if ([uploadStatus isEqualToString:FILE_TRANSFER_STATUS_CONFIRMING]) {
        statusColor = [UIColor aquaColor];
        statusString = [NSString stringWithFormat:@"%@", NSLocalizedString(@"Confirming", @"")];
    } else if ([uploadStatus isEqualToString:FILE_TRANSFER_STATUS_SUCCESS]) {
        statusColor = [UIColor darkGrayColor];
        statusString = [NSString stringWithFormat:@"%@", NSLocalizedString(@"File uploaded", @"")];
    } else if ([uploadStatus isEqualToString:FILE_TRANSFER_STATUS_CANCELING]) {
        statusColor = [UIColor redColor];
        statusString = [NSString stringWithFormat:@"%@", NSLocalizedString(@"Upload canceling", @"")];
    } else if ([uploadStatus isEqualToString:FILE_TRANSFER_STATUS_FAILED]) {
        statusColor = [UIColor redColor];
        statusString = [NSString stringWithFormat:@"%@", NSLocalizedString(@"Uploaded failed", @"")];
    } else if ([uploadStatus isEqualToString:FILE_TRANSFER_STATUS_PREPARING]) {
        statusColor = [UIColor aquaColor];
        statusString = [NSString stringWithFormat:@"%@", NSLocalizedString(@"Upload Preparing", @"")];
    } else {
        statusColor = [UIColor aquaColor];
        statusString = [NSString stringWithFormat:@"%@", NSLocalizedString(@"Upload Preparing", @"")];
    }

    if (completionHandler) {
        completionHandler(statusString, statusColor);
    }
}

- (void)findAssetFileForZeroOrEmptySourceTypeWithCompletionHandler:(void (^)(AssetFile *, NSManagedObjectContext *))completionHandler {
    if (completionHandler) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlock:^() {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];

            NSPredicate *predicate;

            predicate = [NSPredicate predicateWithFormat:@"(sourceType == %d) || (sourceType = nil)", 0];

            [request setPredicate:predicate];

            [request setIncludesSubentities:NO];

            NSArray *results = [moc executeFetchRequest:request error:NULL];

            if (results && [results count] > 0) {
                for (AssetFile *assetFile in results) {
                    completionHandler(assetFile, moc);
                }
            }
        }];
    }
}

- (AssetFileWithoutManaged *)findOneUnfinishedUploadForUserComputer:(NSString *)userComputerId error:(NSError * __autoreleasing *)error {
    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    __block AssetFileWithoutManaged *assetFileWithoutManaged;
    __block NSError *findError;

    [moc performBlockAndWait:^() {
        UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

        if (userComputer) {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];

            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND (waitToConfirm == %@ OR (status != %@ AND status != %@))", userComputer, @YES, FILE_TRANSFER_STATUS_SUCCESS, FILE_TRANSFER_STATUS_FAILED];

            [request setPredicate:predicate];

            [request setIncludesSubentities:NO];

            NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"startTimestamp" ascending:NO];
            [request setSortDescriptors:@[sortDescriptor]];

            NSArray *assetFiles = [moc executeFetchRequest:request error:&findError];

            if (assetFiles && [assetFiles count] > 0) {
                assetFileWithoutManaged = [self assetFileWithoutManagedFromAssetFile:assetFiles[0]];
            }
        }
    }];

    if (error && findError) {
        *error = findError;
    }

    return assetFileWithoutManaged;
}

- (NSArray<NSString *> *)findAssetURLWithSourceType:(NSNumber *)sourceType {
    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    __block NSMutableArray *assetURLs = [NSMutableArray array];

    [moc performBlockAndWait:^() {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];

        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"sourceType == %@", sourceType];
        [request setPredicate:predicate];

        [request setIncludesSubentities:NO];

        NSArray *results = [moc executeFetchRequest:request error:NULL];

        if (results && [results count] > 0) {
            for (AssetFile *assetFile in results) {
                [assetURLs addObject:assetFile.assetURL];
            }
        }
    }];

    return assetURLs;
}

- (void)deleteAssetFilesWithSourceTypeOfSharedFileButNoDownloadedTransferKeyWithCompletionHandler:(void (^ _Nullable)(NSError *_Nullable))completionHandler {
    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlock:^() {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];

        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"sourceType == %@", @(ASSET_FILE_SOURCE_TYPE_SHARED_FILE)];
        [request setPredicate:predicate];

        [request setIncludesSubentities:NO];

        NSError *findError;

        NSArray<AssetFile *> *results = [moc executeFetchRequest:request error:&findError];

        if (!findError) {
            if (results && [results count] > 0) {
                for (AssetFile *assetFile in results) {
                    if (!assetFile.downloadedFileTransferKey) {
                        [moc deleteObject:assetFile];
                    }
                }

                if (completionHandler) {
                    [self.coreData saveContext:moc completionHandler:^() {
                        completionHandler(nil);
                    }];
                } else {
                    [self.coreData saveContext:moc];
                }
            } else {
                if (completionHandler) {
                    completionHandler(nil);
                }
            }
        } else {
            if (completionHandler) {
                completionHandler(findError);
            }
        }
    }];
}

- (void)deleteAssetFilesForUploadedSuccessfullyWithCompletionHandler:(void (^)(NSError *))completionHandler {
    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlock:^() {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AssetFile"];

        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"status == %@", FILE_TRANSFER_STATUS_SUCCESS];
        [request setPredicate:predicate];

        [request setIncludesSubentities:NO];

        NSError *findError;

        NSArray<AssetFile *> *results = [moc executeFetchRequest:request error:&findError];

        if (!findError) {
            if (results && [results count] > 0) {
                for (AssetFile *assetFile in results) {
                    [moc deleteObject:assetFile];
                }

                [self.coreData saveContext:moc completionHandler:^() {
                    completionHandler(nil);
                }];
            } else {
                completionHandler(nil);
            }
        } else {
            completionHandler(findError);
        }
    }];
}
@end
