#import "FileTransferDao.h"
#import "FileTransfer+CoreDataClass.h"
#import "FileTransferWithoutManaged.h"
#import "ClopuccinoCoreData.h"
#import "Utility.h"
#import "UserComputerDao.h"
#import "UserComputer+CoreDataClass.h"
#import "FileDownloadGroup+CoreDataClass.h"
#import "FileDownloadGroupDao.h"

@interface FileTransferDao ()

@property(nonatomic, strong) ClopuccinoCoreData *coreData;

@property(nonatomic, strong) UserComputerDao *userComputerDao;

@property(nonatomic, strong) FileDownloadGroupDao *fileDownloadGroupDao;

@end

@implementation FileTransferDao {
}

- (id)init {
    self = [super init];
    if (self) {
        _coreData = [ClopuccinoCoreData defaultCoreData];

        _userComputerDao = [[UserComputerDao alloc] init];

        _fileDownloadGroupDao = [[FileDownloadGroupDao alloc] init];
    }

    return self;
}

- (void)createOrUpdateFileTransferFromFileTransferWithoutManaged:(FileTransferWithoutManaged *)fileTransferWithoutManaged {
    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlock:^() {
        UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:fileTransferWithoutManaged.userComputerId managedObjectContext:moc];

        if (userComputer) {
            NSString *realServerPath = fileTransferWithoutManaged.realServerPath;

            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND realServerPath == %@", userComputer, realServerPath];
            [request setPredicate:predicate];

            NSArray *results = [moc executeFetchRequest:request error:NULL];

            if (results && [results count] > 0) {
                // update

                [self updateWithoutCommitFileTransfer:results[0] withFileTransferWithoutManaged:fileTransferWithoutManaged];
            } else {
                // create

                FileTransfer *fileTransfer = [NSEntityDescription insertNewObjectForEntityForName:@"FileTransfer" inManagedObjectContext:moc];

                fileTransfer.userComputer = userComputer;
                fileTransfer.serverPath = fileTransferWithoutManaged.serverPath;
                fileTransfer.realServerPath = fileTransferWithoutManaged.realServerPath;
                fileTransfer.localPath = fileTransferWithoutManaged.localPath;
                fileTransfer.contentType = fileTransferWithoutManaged.contentType;
                fileTransfer.displaySize = fileTransferWithoutManaged.displaySize;
                fileTransfer.type = fileTransferWithoutManaged.type;
                fileTransfer.lastModified = fileTransferWithoutManaged.lastModified;
                fileTransfer.status = fileTransferWithoutManaged.status;
                fileTransfer.totalSize = fileTransferWithoutManaged.totalSize;
                fileTransfer.transferredSize = fileTransferWithoutManaged.transferredSize;
                fileTransfer.startTimestamp = fileTransferWithoutManaged.startTimestamp;
                fileTransfer.endTimestamp = fileTransferWithoutManaged.endTimestamp;
                fileTransfer.actionsAfterDownload = fileTransferWithoutManaged.actionsAfterDownload;
                fileTransfer.transferKey = fileTransferWithoutManaged.transferKey;
                fileTransfer.hidden = fileTransferWithoutManaged.hidden;
                fileTransfer.waitToConfirm = fileTransferWithoutManaged.waitToConfirm;

                NSString *downloadGroupId = fileTransferWithoutManaged.downloadGroupId;

                if (downloadGroupId) {
                    FileDownloadGroup *fileDownloadGroup = [self.fileDownloadGroupDao findFileDownloadGroupByDownloadGroupId:fileTransferWithoutManaged.downloadGroupId managedObjectContext:moc];

                    if (fileDownloadGroup) {
                        fileTransfer.fileDownloadGroup = fileDownloadGroup;
                    }
                }

            }

            [self.coreData saveContext:moc];
        }
    }];
}


- (void)createFileTransferFromFileTransferWithoutManaged:(FileTransferWithoutManaged *)fileTransferWithoutManaged {
    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlock:^() {
        UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:fileTransferWithoutManaged.userComputerId managedObjectContext:moc];

        if (userComputer) {
            FileTransfer *fileTransfer = [NSEntityDescription insertNewObjectForEntityForName:@"FileTransfer" inManagedObjectContext:moc];

            fileTransfer.userComputer = userComputer;
            fileTransfer.serverPath = fileTransferWithoutManaged.serverPath;
            fileTransfer.realServerPath = fileTransferWithoutManaged.realServerPath;
            fileTransfer.localPath = fileTransferWithoutManaged.localPath;
            fileTransfer.contentType = fileTransferWithoutManaged.contentType;
            fileTransfer.displaySize = fileTransferWithoutManaged.displaySize;
            fileTransfer.type = fileTransferWithoutManaged.type;
            fileTransfer.lastModified = fileTransferWithoutManaged.lastModified;
            fileTransfer.status = fileTransferWithoutManaged.status;
            fileTransfer.totalSize = fileTransferWithoutManaged.totalSize;
            fileTransfer.transferredSize = fileTransferWithoutManaged.transferredSize;
            fileTransfer.startTimestamp = fileTransferWithoutManaged.startTimestamp;
            fileTransfer.endTimestamp = fileTransferWithoutManaged.endTimestamp;
            fileTransfer.actionsAfterDownload = fileTransferWithoutManaged.actionsAfterDownload;
            fileTransfer.transferKey = fileTransferWithoutManaged.transferKey;
            fileTransfer.hidden = fileTransferWithoutManaged.hidden;
            fileTransfer.waitToConfirm = fileTransferWithoutManaged.waitToConfirm;

            [self.coreData saveContext:moc];
        }
    }];
}

- (NSArray *)findFileTransfersForUserComputer:(NSString *)userComputerId error:(NSError *_Nullable __autoreleasing *_Nullable)error {
    __block NSMutableArray *fileTransfersWithoutManaged = [NSMutableArray array];
    __block NSError *findError;

    if (userComputerId) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlockAndWait:^() {
            UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

            if (userComputer) {
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@", userComputer];
                [request setPredicate:predicate];

                NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"startTimestamp" ascending:NO];
                [request setSortDescriptors:@[sortDescriptor]];

                NSArray *fileTransfers = [moc executeFetchRequest:request error:&findError];

                if (fileTransfers && [fileTransfers count] > 0) {
                    for (FileTransfer *fileTransfer in fileTransfers) {
                        [fileTransfersWithoutManaged addObject:[self fileTransferWithoutManagedFromFileTransfer:fileTransfer]];
                    }
                }
            }
        }];
    }

    if (error && findError) {
        *error = findError;
    }

    return fileTransfersWithoutManaged;
}

- (FileTransferWithoutManaged *)findFileTransferForFetchedResultsController:(NSFetchedResultsController *)fetchedResultsController objectAtIndexPath:(NSIndexPath *)indexPath {
    __block FileTransferWithoutManaged *fileTransferWithoutManaged;

    @autoreleasepool {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlockAndWait:^() {
            FileTransfer *fileTransfer = (FileTransfer *) [fetchedResultsController objectAtIndexPath:indexPath];

            if (fileTransfer && fileTransfer.transferKey) {
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"transferKey == %@", fileTransfer.transferKey];
                [request setPredicate:predicate];

                NSArray *results = [moc executeFetchRequest:request error:NULL];

                if (results && [results count] > 0) {
                    fileTransferWithoutManaged = [self fileTransferWithoutManagedFromFileTransfer:results[0]];
                }
            }
        }];
    }

    return fileTransferWithoutManaged;
}

- (FileTransferWithoutManaged *)findFileTransferForTransferKey:(NSString *)transferKey error:(NSError *_Nullable __autoreleasing *_Nullable)error {
    __block FileTransferWithoutManaged *fileTransferWithoutManaged;
    __block NSError *findError;

    if (transferKey) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlockAndWait:^() {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"transferKey == %@", transferKey];
            [request setPredicate:predicate];

            NSArray *results = [moc executeFetchRequest:request error:&findError];

            if (!findError) {
                if (results && [results count] > 0) {
                    FileTransfer *fileTransfer = results[0];

                    fileTransferWithoutManaged = [self fileTransferWithoutManagedFromFileTransfer:fileTransfer];
                } else {
                    findError = [Utility errorWithErrorCode:NSFileNoSuchFileError localizedDescription:NSLocalizedString(@"No such file.", @"")];
                }
            }
        }];
    }

    if (error && findError) {
        *error = findError;
    } else if (findError) {
        NSLog(@"Failed to find download data.\n%@", [findError userInfo]);
    }

    return fileTransferWithoutManaged;
}

- (void)deleteFileTransferForTransferKey:(NSString *)transferKey
                          successHandler:(void (^ _Nullable)(void))successHandler
                            errorHandler:(void (^ _Nullable)(NSError *_Nullable error))errorHandler {
    if (transferKey) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlock:^() {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"transferKey == %@", transferKey];
            [request setPredicate:predicate];

            NSError *findError;

            NSArray *results = [moc executeFetchRequest:request error:&findError];

            if (!findError) {
                if (results && [results count] > 0) {
                    FileTransfer *fileTransfer = results[0];

                    [moc deleteObject:fileTransfer];

                    if (successHandler) {
                        [self.coreData saveContext:moc completionHandler:successHandler];
                    } else {
                        [self.coreData saveContext:moc];
                    }
                } else {
                    // Regards as success if the FileTransfer with the transfer key not found.

                    if (successHandler) {
                        successHandler();
                    }
                }
            } else {
                if (errorHandler) {
                    errorHandler(findError);
                }
            }
        }];
    }
}

- (void)hideFileTransferForTransferKey:(NSString *)transferKey error:(NSError *_Nullable __autoreleasing *)error {
    if (transferKey) {
        __block NSError *hideError;

        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlock:^() {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"transferKey == %@", transferKey];
            [request setPredicate:predicate];

            NSArray *results = [moc executeFetchRequest:request error:&hideError];

            if (!hideError) {
                if (results && [results count] > 0) {
                    FileTransfer *fileTransfer = results[0];

                    fileTransfer.hidden = @YES;

                    [self.coreData saveContext:moc];
                } else {
                    NSMutableDictionary *details = [NSMutableDictionary dictionary];
                    [details setValue:NSLocalizedString(@"No such file.", @"") forKey:NSLocalizedDescriptionKey];
                    hideError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:details];
                }
            }
        }];

        if (error && hideError) {
            *error = hideError;
        } else if (hideError) {
            NSLog(@"Failed to hide file.\n%@", [hideError userInfo]);
        }
    }
}

- (nullable FileTransferWithoutManaged *)findFileTransferForUserComputer:(NSString *)userComputerId
                                                          realServerPath:(NSString *)realServerPath
                                                                   error:(NSError *_Nullable __autoreleasing *_Nullable)error {
    __block FileTransferWithoutManaged *fileTransferWithoutManaged;
    __block NSError *findError;

    if (userComputerId && realServerPath) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlockAndWait:^() {
            UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

            if (userComputer) {
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND realServerPath == %@", userComputer, realServerPath];
                [request setPredicate:predicate];

                NSArray *results = [moc executeFetchRequest:request error:&findError];

                if (results && [results count] > 0) {
                    fileTransferWithoutManaged = [self fileTransferWithoutManagedFromFileTransfer:results[0]];
                }
            } else {
                NSLog(@"User computer '%@' not found.", userComputerId);
            }
        }];
    }

    if (error && findError) {
        *error = findError;
    }

    return fileTransferWithoutManaged;
}

- (BOOL)existsTransferForUserComputer:(NSString *)userComputerId
                       realServerPath:(NSString *)realServerPath
                                error:(NSError *_Nullable __autoreleasing *_Nullable)error {
    __block BOOL exists = NO;
    __block NSError *findError;

    if (userComputerId && realServerPath) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlockAndWait:^() {
            UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

            if (userComputer) {
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND realServerPath == %@", userComputer, realServerPath];
                [request setPredicate:predicate];

                NSArray *results = [moc executeFetchRequest:request error:&findError];

                exists = results && [results count] > 0;
            } else {
                NSLog(@"User computer '%@' not found.", userComputerId);
            }
        }];
    }

    if (error && findError) {
        *error = findError;
    }

    return exists;
}

// make sure it is wrapped under performBlock: or performBlockAndWait:
- (FileTransferWithoutManaged *)fileTransferWithoutManagedFromFileTransfer:(FileTransfer *)fileTransfer {
    FileTransferWithoutManaged *fileTransferWithoutManaged;

    if (fileTransfer) {
        fileTransferWithoutManaged = [[FileTransferWithoutManaged alloc] initWithUserComputerId:fileTransfer.userComputer.userComputerId
                                                                                downloadGroupId:fileTransfer.fileDownloadGroup.downloadGroupId
                                                                                     serverPath:fileTransfer.serverPath
                                                                                 realServerPath:fileTransfer.realServerPath
                                                                                      localPath:fileTransfer.localPath
                                                                                    contentType:fileTransfer.contentType
                                                                                    displaySize:fileTransfer.displaySize
                                                                                           type:fileTransfer.type
                                                                                   lastModified:fileTransfer.lastModified
                                                                                         status:fileTransfer.status
                                                                                      totalSize:fileTransfer.totalSize
                                                                                transferredSize:fileTransfer.transferredSize
                                                                                 startTimestamp:fileTransfer.startTimestamp
                                                                                   endTimestamp:fileTransfer.endTimestamp
                                                                           actionsAfterDownload:fileTransfer.actionsAfterDownload
                                                                                    transferKey:fileTransfer.transferKey
                                                                                         hidden:fileTransfer.hidden
                                                                                  waitToConfirm:fileTransfer.waitToConfirm];
    }

    return fileTransferWithoutManaged;
}

- (NSNumber *)countForUserComputer:(NSString *)userComputerId
                    realServerPath:(NSString *)realServerPath
                             error:(NSError *_Nullable __autoreleasing *_Nullable)error {
    __block NSNumber *fileTransferCount;
    __block NSError *countError;

    if (userComputerId && realServerPath) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlockAndWait:^() {
            UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

            if (userComputer) {
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND realServerPath == %@", userComputer, realServerPath];
                [request setPredicate:predicate];

                [request setIncludesSubentities:NO];

                NSUInteger count = [moc countForFetchRequest:request error:&countError];
                fileTransferCount = (count == NSNotFound) ? @0 : @(count);
            }
        }];
    }

    if (error && countError) {
        *error = countError;
    }

    return fileTransferCount ? fileTransferCount : @0;
}

- (BOOL)fileSuccessfullyDownloadedForUserComputer:(NSString *)userComputerId
                                   realServerPath:(NSString *)realServerPath
                                            error:(NSError *_Nullable __autoreleasing *_Nullable)error {
    __block BOOL success = NO;
    __block NSError *findError;

    if (userComputerId && realServerPath) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlockAndWait:^() {
            UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

            if (userComputer) {
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND realServerPath == %@ AND status == %@", userComputer, realServerPath, FILE_TRANSFER_STATUS_SUCCESS];
                [request setPredicate:predicate];

                [request setIncludesSubentities:NO];

                NSUInteger count = [moc countForFetchRequest:request error:&findError];
                success = count != NSNotFound;
            }
        }];

        if (error && findError) {
            *error = findError;
        }
    }

    return success;
}

- (void)updateFileTransferWithSameTransferKey:(FileTransferWithoutManaged *)fileTransferWithoutManaged {
    if (fileTransferWithoutManaged && fileTransferWithoutManaged.transferKey && fileTransferWithoutManaged.userComputerId) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlock:^() {
            UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:fileTransferWithoutManaged.userComputerId managedObjectContext:moc];

            if (userComputer) {
                NSString *transferKey = fileTransferWithoutManaged.transferKey;

                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND transferKey == %@", userComputer, transferKey];

                [request setPredicate:predicate];

                NSError *fetchError;
                NSArray *fileTransfers = [moc executeFetchRequest:request error:&fetchError];

                if (fileTransfers && [fileTransfers count] > 0) {
                    [self updateWithoutCommitFileTransfer:fileTransfers[0] withFileTransferWithoutManaged:fileTransferWithoutManaged];

                    [self.coreData saveContext:moc];
                } else if (fetchError) {
                    NSLog(@"Error on finding FileTransfer by transferKey: %@\n%@", transferKey, [fetchError userInfo]);
                }
            }
        }];
    }
}

- (void)updateFileTransfer:(FileTransferWithoutManaged *)fileTransferWithoutManaged {
    [self updateFileTransfer:fileTransferWithoutManaged completionHandler:nil];
}

- (void)updateFileTransfer:(FileTransferWithoutManaged *)fileTransferWithoutManaged completionHandler:(void (^ _Nullable)(void))completionHandler {
    if (fileTransferWithoutManaged && fileTransferWithoutManaged.userComputerId && fileTransferWithoutManaged.serverPath && fileTransferWithoutManaged.realServerPath) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlock:^() {
            UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:fileTransferWithoutManaged.userComputerId managedObjectContext:moc];

            if (userComputer) {
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND realServerPath == %@", userComputer, fileTransferWithoutManaged.realServerPath];
                [request setPredicate:predicate];

                NSError *fetchError;
                NSArray *fileTransfers = [moc executeFetchRequest:request error:&fetchError];

                if (fileTransfers && [fileTransfers count] > 0) {
                    FileTransfer *fileTransfer = fileTransfers[0];

                    [self updateWithoutCommitFileTransfer:fileTransfer withFileTransferWithoutManaged:fileTransferWithoutManaged];

                    if (completionHandler) {
                        [self.coreData saveContext:moc completionHandler:completionHandler];
                    } else {
                        [self.coreData saveContext:moc];
                    }
                } else if (fetchError) {
                    NSLog(@"Error on finding FileTransfer by user computer: %@, server path: %@\n%@", fileTransferWithoutManaged.userComputerId, fileTransferWithoutManaged.serverPath, [fetchError userInfo]);
                }
            }
        }];
    }
}

- (void)updateWithoutCommitFileTransfer:(FileTransfer *)fileTransfer withFileTransferWithoutManaged:(FileTransferWithoutManaged *)fileTransferWithoutManaged {
    fileTransfer.serverPath = fileTransferWithoutManaged.serverPath;
    fileTransfer.realServerPath = fileTransferWithoutManaged.realServerPath;
    fileTransfer.localPath = fileTransferWithoutManaged.localPath;
    fileTransfer.contentType = fileTransferWithoutManaged.contentType;
    fileTransfer.displaySize = fileTransferWithoutManaged.displaySize;
    fileTransfer.type = fileTransferWithoutManaged.type;
    fileTransfer.lastModified = fileTransferWithoutManaged.lastModified;

    NSString *newStatus = fileTransferWithoutManaged.status;
    NSString *oldStatus = fileTransfer.status;

    // 排除狀態從 success/failed 改成 canceling
    if (!([newStatus isEqualToString:FILE_TRANSFER_STATUS_CANCELING] && ([oldStatus isEqualToString:FILE_TRANSFER_STATUS_SUCCESS] || [oldStatus isEqualToString:FILE_TRANSFER_STATUS_FAILED]))) {
        fileTransfer.status = fileTransferWithoutManaged.status;
    }

    fileTransfer.totalSize = fileTransferWithoutManaged.totalSize;
    fileTransfer.transferredSize = fileTransferWithoutManaged.transferredSize;
    fileTransfer.startTimestamp = fileTransferWithoutManaged.startTimestamp;
    fileTransfer.endTimestamp = fileTransferWithoutManaged.endTimestamp;
    fileTransfer.actionsAfterDownload = fileTransferWithoutManaged.actionsAfterDownload;
    fileTransfer.transferKey = fileTransferWithoutManaged.transferKey;
    fileTransfer.hidden = fileTransferWithoutManaged.hidden;
    fileTransfer.waitToConfirm = fileTransferWithoutManaged.waitToConfirm;
}

- (NSString *)actionsAfterDownloadForUserComputer:(NSString *)userComputerId
                                   realServerPath:(NSString *)realServerPath
                                            error:(NSError *_Nullable __autoreleasing *_Nullable)error {
    __block NSString *actionsAfterDownload;
    __block NSError *findError;

    @autoreleasepool {
        if (userComputerId && realServerPath) {
            NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

            [moc performBlockAndWait:^() {
                UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

                if (userComputer) {
                    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

                    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND realServerPath == %@", userComputer, realServerPath];
                    [request setPredicate:predicate];

                    [request setIncludesSubentities:NO];

                    NSArray *results = [moc executeFetchRequest:request error:&findError];

                    if (results && [results count] > 0) {
                        actionsAfterDownload = ((FileTransfer *) results[0]).actionsAfterDownload;
                    }
                }
            }];
        }
    }

    if (error && findError) {
        *error = findError;
    }

    return actionsAfterDownload;
}

- (BOOL)shouldShareAfterDownloadForUserComputer:(NSString *)userComputerId
                                 realServerPath:(NSString *)realServerPath
                                          error:(NSError *_Nullable __autoreleasing *_Nullable)error {
    NSString *actionsAfterDownload = [self actionsAfterDownloadForUserComputer:userComputerId realServerPath:realServerPath error:error];

    if (actionsAfterDownload) {
        return [FileTransferWithoutManaged shareInActionsAfterDownload:actionsAfterDownload];
    } else {
        return NO;
    }
}

- (BOOL)shouldOpenAfterDownloadForUserComputer:(NSString *)userComputerId
                                realServerPath:(NSString *)realServerPath
                                         error:(NSError *_Nullable __autoreleasing *_Nullable)error {
    NSString *actionsAfterDownload = [self actionsAfterDownloadForUserComputer:userComputerId realServerPath:realServerPath error:error];

    if (actionsAfterDownload) {
        return [FileTransferWithoutManaged openInActionsAfterDownload:actionsAfterDownload];
    } else {
        return NO;
    }
}

// handler runs even if the value of actionsAfterDownload is the same with the current value.
- (void)updateShareValueInActionsAfterDownloadForUserComputer:(NSString *)userComputerId
                                               realServerPath:(NSString *)realServerPath
                                              toNewShareValue:(BOOL)newShareValue
                                            completionHandler:(void (^ _Nullable)(NSString *_Nullable, BOOL))handler {
    [self updateNewValue:newShareValue atIndex:1 inActionsAfterDownloadForUserComputer:userComputerId realServerPath:realServerPath completionHandler:handler];
}

// handler runs even if the value of actionsAfterDownload is the same with the current value.
- (void)updateOpenValueInActionsAfterDownloadForUserComputer:(NSString *)userComputerId
                                              realServerPath:(NSString *)realServerPath
                                              toNewOpenValue:(BOOL)newOpenValue
                                           completionHandler:(void (^ _Nullable)(NSString *_Nullable, BOOL))handler {
    [self updateNewValue:newOpenValue atIndex:0 inActionsAfterDownloadForUserComputer:userComputerId realServerPath:realServerPath completionHandler:handler];
}

// handler runs even if the value of actionsAfterDownload is the same with the current value.
- (void)updateNewValue:(BOOL)newValue atIndex:(NSUInteger)index inActionsAfterDownloadForUserComputer:(NSString *)userComputerId realServerPath:(NSString *)realServerPath completionHandler:(void (^ _Nullable)(NSString *_Nullable, BOOL))handler {
    if (userComputerId && realServerPath) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlock:^() {
            @autoreleasepool {
                UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

                if (userComputer) {
                    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

                    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND realServerPath == %@", userComputer, realServerPath];
                    [request setPredicate:predicate];

                    NSError *fetchError;
                    NSArray *fileTransfers = [moc executeFetchRequest:request error:&fetchError];

                    if (fileTransfers && [fileTransfers count] > 0) {
                        FileTransfer *fileTransfer = fileTransfers[0];

                        NSMutableArray *actions = [FileTransferWithoutManaged actionArrayFromActionsAfterDownload:fileTransfer.actionsAfterDownload];

                        if (index < [actions count]) {
                            if (newValue) {
                                actions[index] = YES_ACTION;
                            } else {
                                actions[index] = NO_ACTION;
                            }

                            NSString *oldActionsAfterDownload = fileTransfer.actionsAfterDownload;
                            NSString *newActionsAfterDownload = [FileTransferWithoutManaged actionsAfterDownloadFromActionArray:actions];

                            if (!oldActionsAfterDownload || ![oldActionsAfterDownload isEqualToString:newActionsAfterDownload]) {
                                fileTransfer.actionsAfterDownload = newActionsAfterDownload;

                                [self.coreData saveContext:moc];
                            }
                        }
                    } else if (fetchError) {
                        NSLog(@"Error on finding FileTransfer for user computer: %@, server path: %@\n%@", userComputerId, realServerPath, [fetchError userInfo]);
                    }
                }

                if (handler) {
                    handler(realServerPath, newValue);
                }
            }
        }];
    }
}

- (void)downloadedPercentageForUserComputer:(NSString *)userComputerId realServerPath:(NSString *)realServerPath completionHandler:(void (^ _Nullable)(float percentage))completionHandler {
    if (userComputerId && realServerPath) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlock:^() {
            UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

            if (userComputer) {
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND realServerPath == %@", userComputer, realServerPath];
                [request setPredicate:predicate];

                NSArray *results = [moc executeFetchRequest:request error:NULL];

                if (results && [results count] > 0) {
                    FileTransfer *fileTransfer = results[0];

                    NSString *downloadStatus = fileTransfer.status;

                    if ([downloadStatus isEqualToString:FILE_TRANSFER_STATUS_PROCESSING]) {
                        NSNumber *transferredSize = fileTransfer.transferredSize;
                        NSNumber *totalSize = fileTransfer.totalSize;

                        float percentage = [Utility divideDenominator:totalSize byNumerator:transferredSize];

                        completionHandler(percentage);
                    } else if ([downloadStatus isEqualToString:FILE_TRANSFER_STATUS_SUCCESS]) {
                        completionHandler(1);
                    } else if ([downloadStatus isEqualToString:FILE_TRANSFER_STATUS_CANCELING]) {
                        completionHandler(2);
                    } else if ([downloadStatus isEqualToString:FILE_TRANSFER_STATUS_FAILED]) {
                        completionHandler(3);
                    } else {
                        completionHandler(-1);
                    }
                } else {
                    /* download not started */
                    completionHandler(-1);
                }
            } else {
                NSLog(@"User computer '%@' not found.", userComputerId);
            }
        }];
    }
}

- (void)changeDowloadStatusFromUnfinishedToFailed {
    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlock:^() {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"status IN %@", @[FILE_TRANSFER_STATUS_PROCESSING, FILE_TRANSFER_STATUS_CANCELING]];
        [request setPredicate:predicate];

        NSArray *fileTransfers = [moc executeFetchRequest:request error:NULL];

        if (fileTransfers && [fileTransfers count] > 0) {
            for (FileTransfer *fileTransfer in fileTransfers) {
                fileTransfer.status = FILE_TRANSFER_STATUS_FAILED;
            }

            [self.coreData saveContext:moc];
        }
    }];
}

- (void)findWaitToConfirmFileTransferWithCompletionHandler:(void (^ _Nullable)(FileTransferWithoutManaged *_Nullable fileTransferWithoutManaged))completionHandler {
    if (completionHandler) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlock:^() {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"waitToConfirm == %@ AND (status == %@ OR status == %@)", @YES, FILE_TRANSFER_STATUS_SUCCESS, FILE_TRANSFER_STATUS_FAILED];
            [request setPredicate:predicate];

            NSSortDescriptor *startTimestampSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"startTimestamp" ascending:NO];
            [request setSortDescriptors:@[startTimestampSortDescriptor]];

            NSArray *fileTransfers = [moc executeFetchRequest:request error:NULL];

            if (fileTransfers && [fileTransfers count] > 0) {
                for (FileTransfer *fileTransfer in fileTransfers) {
                    FileTransferWithoutManaged *waitToConfirmFileTransferWithoutManaged = [self fileTransferWithoutManagedFromFileTransfer:fileTransfer];

                    completionHandler(waitToConfirmFileTransferWithoutManaged);
                }
            }
        }];
    }
}

- (void)findAllCancelingDownloadsAndChangeToFailure {
    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlock:^() {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"status == %@", FILE_TRANSFER_STATUS_CANCELING];
        [request setPredicate:predicate];

        NSArray *fileTransfers = [moc executeFetchRequest:request error:NULL];

        if (fileTransfers && [fileTransfers count] > 0) {
            NSLog(@"There are %lu download(s) of status canceling.", (unsigned long) [fileTransfers count]);

            for (FileTransfer *fileTransfer in fileTransfers) {
                fileTransfer.status = FILE_TRANSFER_STATUS_FAILED;
            }

            [self.coreData saveContext:moc];
        }
    }];
}

- (nullable FileTransferWithoutManaged *)findOneUnfinishedDownloadForUserComputer:(NSString *)userComputerId
                                                                            error:(NSError *_Nullable __autoreleasing *_Nullable)error {
    __block FileTransferWithoutManaged *fileTransferWithoutManaged;
    __block NSError *findError;

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlockAndWait:^() {
        UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

        if (userComputer) {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND (waitToConfirm == %@ OR (status != %@ AND status != %@))", userComputer, @YES, FILE_TRANSFER_STATUS_SUCCESS, FILE_TRANSFER_STATUS_FAILED];

            [request setPredicate:predicate];

            [request setIncludesSubentities:NO];

            NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"startTimestamp" ascending:NO];
            [request setSortDescriptors:@[sortDescriptor]];

            NSArray *fileTransfers = [moc executeFetchRequest:request error:&findError];

            if (fileTransfers && [fileTransfers count] > 0) {
                fileTransferWithoutManaged = [self fileTransferWithoutManagedFromFileTransfer:fileTransfers[0]];
            }
        }
    }];

    if (error && findError) {
        *error = findError;
    }

    return fileTransferWithoutManaged;
}

- (nullable FileTransferWithoutManaged *)findOneSuccessfullyDownloadedForUserComputer:(NSString *)userComputerId
                                                                                error:(NSError *_Nullable __autoreleasing *_Nullable)error {
    __block FileTransferWithoutManaged *fileTransferWithoutManaged;
    __block NSError *findError;

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlockAndWait:^() {
        UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

        if (userComputer) {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND status == %@", userComputer, FILE_TRANSFER_STATUS_SUCCESS];

            [request setPredicate:predicate];

            [request setIncludesSubentities:NO];

            NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"startTimestamp" ascending:NO];
            [request setSortDescriptors:@[sortDescriptor]];

            NSArray *fileTransfers = [moc executeFetchRequest:request error:&findError];

            if (fileTransfers && [fileTransfers count] > 0) {
                fileTransferWithoutManaged = [self fileTransferWithoutManagedFromFileTransfer:fileTransfers[0]];
            }
        }
    }];

    if (error && findError) {
        *error = findError;
    }

    return fileTransferWithoutManaged;
}

- (void)updateFileTransferLocalPathToRelativePath {
    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlock:^() {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"startTimestamp" ascending:YES];
        [request setSortDescriptors:@[sortDescriptor]];

        NSError *error;
        NSArray *fileTransfers = [moc executeFetchRequest:request error:&error];

        if (fileTransfers && [fileTransfers count] > 0) {
            for (FileTransfer *fileTransfer in fileTransfers) {
                NSString *currentLocalPath = fileTransfer.localPath;
                NSString *userComputerId = fileTransfer.userComputer.userComputerId;
                NSString *newLocalPath = [Utility convertFileTransferLocalPath:currentLocalPath toRelativePathWithUserComputerId:userComputerId];

                if (newLocalPath) {
                    fileTransfer.localPath = newLocalPath;
                }
            }

            [self.coreData saveContext:moc];
        } else if (error) {
            NSLog(@"Error on finding all downloaded files.\n%@", [error userInfo]);
        }
    }];
}

- (NSString *)findTransferKeyOfFirstFileWithFileDownloadGroupId:(NSString *)fileDownloadGroupId {
    __block NSString *transferKey;

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlockAndWait:^() {
        FileDownloadGroup *fileDownloadGroup = [self.fileDownloadGroupDao findFileDownloadGroupByDownloadGroupId:fileDownloadGroupId managedObjectContext:moc];

        if (fileDownloadGroup) {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"fileDownloadGroup == %@", fileDownloadGroup];

            [request setPredicate:predicate];

            [request setIncludesSubentities:NO];

            NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"startTimestamp" ascending:NO];
            [request setSortDescriptors:@[sortDescriptor]];

            NSError *findError;
            NSArray<FileTransfer *> *fileTransfers = [moc executeFetchRequest:request error:&findError];

            if (fileTransfers && [fileTransfers count] > 0) {
                transferKey = fileTransfers[0].transferKey;
            }
        }
    }];

    return transferKey;

}

#pragma mark - NSFetchedResultsController, for delegates of UITableView

- (nullable NSFetchedResultsController *)createFileInfoFetchedResultsControllerForUserComputer:(NSString *)userComputerId
                                                                                realServerPath:(NSString *)realServerPath
                                                                                      delegate:(id <NSFetchedResultsControllerDelegate>)delegate {
    __block NSFetchedResultsController *controller;

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlockAndWait:^() {
        UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

        if (userComputer) {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND realServerPath == %@", userComputer, realServerPath];
            [request setPredicate:predicate];

            NSSortDescriptor *startTimestampSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"startTimestamp" ascending:NO];

            [request setSortDescriptors:@[startTimestampSortDescriptor]];

            // Stop using cache to prevent the following error to crash APP:
            // uncaught exception 'NSInternalInconsistencyException', reason: 'CoreData: FATAL ERROR:
            // The persistent cache of section information does not match the current configuration.
            // You have illegally mutated the NSFetchedResultsController's fetch request, its predicate,
            // or its sort descriptor without either disabling caching or using +deleteCacheWithName:'
            controller = [[NSFetchedResultsController alloc] initWithFetchRequest:request managedObjectContext:moc sectionNameKeyPath:nil cacheName:nil];

            controller.delegate = delegate;
        }
    }];

    return controller;
}

- (nullable NSFetchedResultsController *)createFileDownloadFetchedResultsControllerForUserComputerId:(NSString *)userComputerId
                                                                                            delegate:(id <NSFetchedResultsControllerDelegate>)delegate {
    __block NSFetchedResultsController *controller;

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlockAndWait:^() {
        UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

        if (userComputer) {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@", userComputer];
            [request setPredicate:predicate];

            // Sort by fileDownloadGroup.createTimestamp so different upload group get together
            NSString *createTimestampKeyPath = @"fileDownloadGroup.createTimestamp";

            NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:createTimestampKeyPath ascending:NO];

            NSSortDescriptor *sortDescriptor2 = [NSSortDescriptor sortDescriptorWithKey:@"startTimestamp" ascending:NO];

            [request setSortDescriptors:@[sortDescriptor1, sortDescriptor2]];

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

- (nullable NSFetchedResultsController *)createFileDownloadFetchedResultsControllerForAllUsersWithDelegate:(id <NSFetchedResultsControllerDelegate>)delegate {
    __block NSFetchedResultsController *controller;

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlockAndWait:^() {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"status == %@", FILE_TRANSFER_STATUS_SUCCESS];
        [request setPredicate:predicate];

        // Sort by fileDownloadGroup.createTimestamp so different upload group get together
        NSString *createTimestampKeyPath = @"fileDownloadGroup.createTimestamp";

        NSSortDescriptor *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:createTimestampKeyPath ascending:NO];

        NSSortDescriptor *sortDescriptor2 = [NSSortDescriptor sortDescriptorWithKey:@"startTimestamp" ascending:NO];

        [request setSortDescriptors:@[sortDescriptor1, sortDescriptor2]];

        // Stop using cache to prevent the following error to crash APP:
        // uncaught exception 'NSInternalInconsistencyException', reason: 'CoreData: FATAL ERROR:
        // The persistent cache of section information does not match the current configuration.
        // You have illegally mutated the NSFetchedResultsController's fetch request, its predicate,
        // or its sort descriptor without either disabling caching or using +deleteCacheWithName:'
        controller = [[NSFetchedResultsController alloc] initWithFetchRequest:request managedObjectContext:moc sectionNameKeyPath:createTimestampKeyPath cacheName:nil];

        controller.delegate = delegate;
    }];

    return controller;
}

- (BOOL)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController
                    performFetch:(NSError *_Nullable __autoreleasing *_Nullable)error {
    __block BOOL success = NO;
    __block NSError *fetchError;

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

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

- (nullable FileTransferWithoutManaged *)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController
                                                objectAtIndexPath:(NSIndexPath *)indexPath {
    __block FileTransferWithoutManaged *fileTransferWithoutManaged;

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlockAndWait:^() {
        id fileTransfer = [fetchedResultsController objectAtIndexPath:indexPath];

        if (fileTransfer && [fileTransfer isKindOfClass:[FileTransfer class]]) {
            fileTransferWithoutManaged = [self fileTransferWithoutManagedFromFileTransfer:fileTransfer];
        }
    }];

    return fileTransferWithoutManaged;
}

- (NSInteger)numberOfSectionsForFetchedResultsController:(NSFetchedResultsController *)fetchedResultsController {
    __block NSInteger count = 0;

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlockAndWait:^() {
        count = [[fetchedResultsController sections] count];
    }];

    return count;
}

- (NSString *)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController titleForHeaderInSection:(NSInteger)section includingComputerName:(BOOL)includingComputerName {
    __block NSString *title = @"";

    NSManagedObjectContext *moc = fetchedResultsController.managedObjectContext;

    [moc performBlockAndWait:^() {
        if ([[fetchedResultsController sections] count] > 0) {
            id <NSFetchedResultsSectionInfo> sectionInfo = [fetchedResultsController sections][(NSUInteger) section];

            // Get number of files

            NSUInteger count = [sectionInfo numberOfObjects];

            NSString *countDescription;
            if (count > 1) {
                countDescription = [NSString stringWithFormat:NSLocalizedString(@"(N Files)", @""), (long)count];
            } else {
                countDescription = NSLocalizedString(@"(1 File)", @"");
            }

            // Get computer name

            NSString *sectionSuffix;

            if (includingComputerName) {
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:section];
                id fileTransfer = [fetchedResultsController objectAtIndexPath:indexPath];

                if (fileTransfer && [fileTransfer isKindOfClass:[FileTransfer class]]) {
                    NSString *computerName = ((FileTransfer *) fileTransfer).userComputer.computerName;

                    if (computerName && [computerName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
                        sectionSuffix = [NSString stringWithFormat:NSLocalizedString(@"From Computer %@", @""), computerName];
                    }
                }
            }

            // Get timestamp

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

            if (includingComputerName && sectionSuffix) {
                title = [NSString stringWithFormat:@"%@%@%@", sectionPrefix, countDescription, sectionSuffix];
            } else {
                title = [NSString stringWithFormat:@"%@%@", sectionPrefix, countDescription];
            }
        }
    }];

    return title;
}

- (NSInteger)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController numberOfRowsInSection:(NSInteger)section {
    __block NSInteger count = 0;

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlockAndWait:^() {
        id <NSFetchedResultsSectionInfo> sectionInfo = [fetchedResultsController sections][(NSUInteger) section];

        if (sectionInfo) {
            count = [sectionInfo numberOfObjects];
        }
    }];

    return count;
}

- (nullable NSString *)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController sectionName:(NSInteger)section {
    __block NSString *name;

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlockAndWait:^() {
        id <NSFetchedResultsSectionInfo> sectionInfo = [fetchedResultsController sections][(NSUInteger) section];

        if (sectionInfo) {
            name = [sectionInfo name];
        }
    }];

    return name;
}

- (nullable NSArray *)sectionIndexTitlesForFetchedResultsController:(NSFetchedResultsController *)fetchedResultsController {
    __block NSArray *titles;

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlockAndWait:^() {
        titles = [fetchedResultsController sectionIndexTitles];
    }];

    return titles;
}

- (NSInteger)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    __block NSInteger section = 0;

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlockAndWait:^() {
        section = [fetchedResultsController sectionForSectionIndexTitle:title atIndex:index];
    }];

    return section;
}

- (nullable NSIndexPath *)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController
                           indexPathForTransferKey:(NSString *)transferKey {
    __block NSIndexPath *indexPath;
    
    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];
    
    [moc performBlockAndWait:^() {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"transferKey == %@", transferKey];
        [request setPredicate:predicate];

        NSArray *results = [moc executeFetchRequest:request error:NULL];
        
        if (results && [results count] > 0) {
            FileTransfer *fileTransfer = results[0];
            
            indexPath = [fetchedResultsController indexPathForObject:fileTransfer];
        }
    }];
    
    return indexPath;
}

#pragma mark - Manage resumeDataDictionary

// append

- (void)addResumeData:(NSData *_Nullable)resumeData toFileTransferWithTransferKey:(NSString *)transferKey completionHandler:(void (^ _Nullable)(NSError *_Nullable))completionHandler {
    if (transferKey) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlock:^() {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"transferKey == %@", transferKey];
            [request setPredicate:predicate];

            NSError *findError;
            NSArray *results = [moc executeFetchRequest:request error:&findError];

            if (!findError) {
                if (results && [results count] > 0) {
                    FileTransfer *fileTransfer = results[0];

                    fileTransfer.resumeData = resumeData;

                    if (completionHandler) {
                        [self.coreData saveContext:moc completionHandler:^() {
                            completionHandler(nil);
                        }];
                    } else {
                        [self.coreData saveContext:moc];
                    }
                } else {
                    if (completionHandler) {
                        NSString *message = [NSString stringWithFormat:@"Can not find File transfer with transfer key: %@.", transferKey];
                        NSError *error = [Utility errorWithErrorCode:ERROR_CODE_ENTITY_NOT_FOUND_KEY localizedDescription:message];

                        completionHandler(error);
                    }
                }
            } else {
                if (completionHandler) {
                    completionHandler(findError);
                }
            }
        }];
    }
}

- (nullable NSData *)resumeDataFromFileTransferWithTransferKey:(NSString *)transferKey error:(NSError * _Nullable __autoreleasing * _Nullable)error {
    __block NSData *resumeData;
    __block NSError *resumeError;

    if (transferKey) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlockAndWait:^() {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"transferKey == %@", transferKey];
            [request setPredicate:predicate];

            NSArray *results = [moc executeFetchRequest:request error:&resumeError];

            if (results && [results count] > 0) {
                FileTransfer *fileTransfer = results[0];

                resumeData = fileTransfer.resumeData;
            }
        }];

        if (error && resumeError) {
            *error = resumeError;
        }
    }

    return resumeData;
}

- (void)removeResumeDataFromFileTransferWithTransferKey:(NSString *)transferKey completionHandler:(void (^ _Nullable)(NSError * _Nullable))completionHandler {
    if (transferKey) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlock:^() {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"transferKey == %@", transferKey];
            [request setPredicate:predicate];

            NSError *findError;

            NSArray *results = [moc executeFetchRequest:request error:&findError];

            if (!findError) {
                if (results && [results count] > 0) {
                    FileTransfer *fileTransfer = results[0];

                    fileTransfer.resumeData = nil;

                    if (completionHandler) {
                        [self.coreData saveContext:moc completionHandler:^() {
                            completionHandler(nil);
                        }];
                    } else {
                        [self.coreData saveContext:moc];
                    }
                } else {
                    if (completionHandler) {
                        NSString *message = [NSString stringWithFormat:@"Can not find File transfer with transfer key: %@.", transferKey];
                        NSError *error = [Utility errorWithErrorCode:ERROR_CODE_ENTITY_NOT_FOUND_KEY localizedDescription:message];

                        completionHandler(error);
                    }
                }
            } else {
                if (completionHandler) {
                    completionHandler(findError);
                }
            }
        }];
    }
}

- (void)removeResumeDataWithRealServerPath:(NSString *)realServerPath
                            userComputerId:(NSString *)userComputerId
                         completionHandler:(void (^ _Nullable)(NSError *_Nullable))completionHandler {
    if (userComputerId && realServerPath) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlock:^() {
            UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

            if (userComputer) {
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND realServerPath == %@", userComputer, realServerPath];
                [request setPredicate:predicate];

                NSError *error;
                NSArray *results = [moc executeFetchRequest:request error:&error];

                if (results && [results count] > 0) {
                    FileTransfer *fileTransfer = results[0];

                    fileTransfer.resumeData = nil;

                    if (completionHandler) {
                        [self.coreData saveContext:moc completionHandler:^() {
                            completionHandler(nil);
                        }];
                    } else {
                        [self.coreData saveContext:moc];
                    }
                } else {
                    if (completionHandler) {
                        NSString *message = [NSString stringWithFormat:@"Can not find File transfer with realServerPath: %@, userComputerId: %@.\n%@", realServerPath, userComputerId, (error ? [error userInfo] : @"'")];
                        NSError *notFoundError = [Utility errorWithErrorCode:ERROR_CODE_ENTITY_NOT_FOUND_KEY localizedDescription:message];

                        completionHandler(notFoundError);
                    }
                }
            } else {
                if (completionHandler) {
                    NSString *message = [NSString stringWithFormat:@"User computer '%@' not found.", userComputerId];
                    NSError *notFoundError = [Utility errorWithErrorCode:ERROR_CODE_DATA_INTEGRITY_KEY localizedDescription:message];

                    completionHandler(notFoundError);
                }
            }
        }];
    }
}

- (void)removeResumeDataWithUserComputerId:(NSString *)userComputerId {
    if (userComputerId) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlock:^() {
            UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

            if (userComputer) {
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@", userComputer];
                [request setPredicate:predicate];

                NSArray *fileTransfers = [moc executeFetchRequest:request error:NULL];

                if (fileTransfers && [fileTransfers count] > 0) {
                    for (FileTransfer *fileTransfer in fileTransfers) {
                        fileTransfer.resumeData = nil;
                    }

                    [self.coreData saveContext:moc];
                }
            }
        }];
    }
}

- (void)deleteFileTransfersWithoutStatusOfSuccess {
    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlock:^() {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"status != %@", FILE_TRANSFER_STATUS_SUCCESS];
        [request setPredicate:predicate];

        [request setIncludesSubentities:NO];

        NSArray *fileTransfers = [moc executeFetchRequest:request error:NULL];

        if (fileTransfers && [fileTransfers count] > 0) {
            for (FileTransfer *fileTransfer in fileTransfers) {
                [moc deleteObject:fileTransfer];
            }

            [self.coreData saveContext:moc];
        }
    }];
}

@end
