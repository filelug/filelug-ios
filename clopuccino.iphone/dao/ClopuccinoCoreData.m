#import "ClopuccinoCoreData.h"
#import "Utility.h"
#import "FolderWatcher.h"

@interface ClopuccinoCoreData ()

@property(nonatomic, strong) NSManagedObjectModel *managedObjectModel;

@property(nonatomic, strong) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property(nonatomic, strong) NSManagedObjectContext *mainManagedObjectContext;

@property (nonatomic, strong) FolderWatcher *folderWatcher;

@end

@implementation ClopuccinoCoreData {

}

static ClopuccinoCoreData *defaultCoreData = nil;

+ (ClopuccinoCoreData *)defaultCoreData {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultCoreData = [[ClopuccinoCoreData alloc] init];

        // Setup managed object model
        // Bundle identifier of FilelugKit is 'com.filelug.FilelugKit'
        NSURL *modelURL = [[NSBundle bundleWithIdentifier:@"com.filelug.FilelugKit"] URLForResource:@"Clopuccino" withExtension:@"momd"];

        NSManagedObjectModel *managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];

        NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:managedObjectModel];

        NSFileManager *fileManager = [NSFileManager defaultManager];

        NSString *applicationSupportPath = [Utility applicationSupportDirectoryWithFileManager:fileManager];
        NSURL *oldStoreURL = [NSURL fileURLWithPath:[applicationSupportPath stringByAppendingPathComponent:DATA_BASE_NAME] isDirectory:YES];

        NSPersistentStore *destinationStore;

        NSString *oldStoreFilePath = [oldStoreURL path];

        if ([fileManager fileExistsAtPath:oldStoreFilePath]) {
            // migrate from existing persistent store

            // DEBUG
//            NSLog(@"Old database found. Go migration.");

            // enable light-weight migration to core data
            // Set @"journal_mode" is to ensure that if the default options are changed in the future the code will still work.
            NSDictionary *options = @{
                    NSInferMappingModelAutomaticallyOption : @YES,
                    NSMigratePersistentStoresAutomaticallyOption : @YES,
                    NSSQLitePragmasOption : @{@"journal_mode" : @"WAL"}
            };

            NSError *error;
            if (![coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:oldStoreURL options:options error:&error]) {
                NSLog(@"Error on adding a persistent store at %@.\n%@", [oldStoreURL absoluteString], [error userInfo]);

                // Must not delete db storage files using nsfilemanaged but use nsfilecorodinate instead.
            } else {
                // DEBUG
//                NSLog(@"Persistent coordinator added the old database. Try to migrate to the new one.");

                NSPersistentStore *sourceStore = [coordinator persistentStoreForURL:oldStoreURL];

                if (sourceStore){
                    // Perform the migration

                    NSURL *sharedStoreURL = [[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:APP_GROUP_NAME] URLByAppendingPathComponent:SHARED_DATA_BASE_NAME];

                    destinationStore = [coordinator migratePersistentStore:sourceStore toURL:sharedStoreURL options:options withType:NSSQLiteStoreType error:&error];

                    if (destinationStore == nil){
                        // Handle the migration error

                        NSLog(@"DB migration error.\n%@", [error userInfo]);
                    } else {
                        // DEBUG
//                        NSLog(@"Successfully migrate old database to the new one. Try deleting the old database.");

                        // You can now remove the old data at oldStoreURL
                        // Note that you should do this using the NSFileCoordinator/NSFilePresenter APIs, and you should remove the other files
                        // described in QA1809 as well.

                        NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];

                        NSError *coordinateError;
                        [fileCoordinator coordinateWritingItemAtURL:oldStoreURL options:NSFileCoordinatorWritingForDeleting error:&coordinateError byAccessor:^(NSURL *coordinatedURL) {
//                            NSError *deleteError;
                            [[NSFileManager defaultManager] removeItemAtURL:coordinatedURL error:NULL];

//                            if (deleteError) {
//                                // DEBUG
//                                NSLog(@"Error on deleting old database with store url.\n%@\n%@", [coordinatedURL absoluteString], [deleteError userInfo]);
//                            } else {
//                                // DEBUG
//                                NSLog(@"It seems that the old database deleted successfully.");
//                            }
                        }];

                        if (coordinateError) {
                            NSLog(@"Error on coordinating writing url: %@\n%@", [oldStoreURL absoluteString], [coordinateError userInfo]);
                        }
                    }
                }
            }
        }

        // If failed to migrate, create an empty one directly.

        if (!destinationStore) {
            // DEBUG
//            NSLog(@"No old database found.");

            // create new persistent store

            NSURL *sharedStoreURL = [[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:APP_GROUP_NAME] URLByAppendingPathComponent:SHARED_DATA_BASE_NAME];

            // enable light-weight migration to core data
            NSDictionary *options = @{
                    NSInferMappingModelAutomaticallyOption : @YES,
                    NSMigratePersistentStoresAutomaticallyOption : @YES
            };

//            NSError *error;

            [coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:sharedStoreURL options:options error:NULL];

//            // DEBUG
//            if (!destinationStore) {
//                NSLog(@"Error on adding a persistent store at %@.\n%@", [sharedStoreURL absoluteString], [error userInfo]);
//            } else {
//                NSLog(@"New database created with url: %@", [sharedStoreURL absoluteString]);
//            }
        }

        defaultCoreData.managedObjectModel = managedObjectModel;
        defaultCoreData.persistentStoreCoordinator = coordinator;

        // main context: as the middle
        // therefore we always have the latest data available on the main thread.
        // No need for listening to change notifications and merging changes manually.
        defaultCoreData.mainManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [defaultCoreData.mainManagedObjectContext setPersistentStoreCoordinator:defaultCoreData.persistentStoreCoordinator];

        // To solve NSManagedObjectMergeError = 133020, Core Data is unable to comple merging.
        [defaultCoreData.mainManagedObjectContext setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];

//        // main context on a background thread
//        // therefore all the heavy lifting of persisting data to disk and reading data from disk is done
//        // without blocking the main thread.
//        defaultCoreData.writerManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
//        [defaultCoreData.writerManagedObjectContext setParentContext:defaultCoreData.mainManagedObjectContext];
//
//        // To solve NSManagedObjectMergeError = 133020, Core Data is unable to comple merging.
//        [defaultCoreData.writerManagedObjectContext setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
    });
    
    return defaultCoreData;
}

- (NSManagedObjectContext *)managedObjectContextFromThread:(NSThread *)thread {
        return self.mainManagedObjectContext;
}

//- (NSManagedObjectContext *)managedObjectContextFromThread:(NSThread *)thread {
//    if ([thread isMainThread]) {
//        // DEBUG
////        NSLog(@"MOC with MAIN thread: %@", [thread description]);
//
//        return self.mainManagedObjectContext;
//    } else {
//        // DEBUG
////        NSLog(@"MOC with non-main thread: %@", [thread description]);
//
//        NSManagedObjectContext *moc = [thread threadDictionary][@"MOC_WORKER"];
//
//        if (!moc) {
//            moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
//
//            [moc setParentContext:self.mainManagedObjectContext];
//
//            [thread threadDictionary][@"MOC_WORKER"] = moc;
//        }
//
//        return moc;
//    }
//}

- (void)saveContext:(NSManagedObjectContext *)moc completionHandler:(void (^)(void))completionHandler {
    if ([moc hasChanges]) {
        __block BOOL success = YES;

        NSManagedObjectContext *internalMoc = moc;

        while (internalMoc && success) {
            [internalMoc performBlockAndWait:^() {
                NSError *saveError;
                success = [internalMoc save:&saveError];

                if (!success) {
                    NSLog(@"Error on saving context.\n%@\n%@", [saveError userInfo], saveError);
                }
            }];

            internalMoc = internalMoc.parentContext;
        }
    }

    if (completionHandler) {
        completionHandler();
    }
}

- (void)saveContext:(NSManagedObjectContext *)context {
    [self saveContext:context completionHandler:nil];
}

- (void)rollbackContext:(NSManagedObjectContext *)moc {
    if ([moc hasChanges]) {
        NSManagedObjectContext *internalMoc = moc;

        while (internalMoc) {
            [internalMoc performBlockAndWait:^() {
                [internalMoc rollback];
            }];

            internalMoc = internalMoc.parentContext;
        }
    }
}

- (BOOL)containsEntityWithEntityName:(NSString *)entityName {
    NSEnumerator *keyEnum = [[self.managedObjectModel entitiesByName] keyEnumerator];
    
    NSString *key;
    
    while ((key = [keyEnum nextObject])) {
        if ([key isEqualToString:entityName]) {
            return YES;
        }
    }
    
    return NO;
}

- (void)truncateEntityWithEntityName:(NSString *)entityName error:(NSError * __autoreleasing *)error {
    if ([self containsEntityWithEntityName:entityName]) {
        NSManagedObjectContext *moc = [self managedObjectContextFromThread:[NSThread currentThread]];

        if ([Utility isDeviceVersion9OrLater]) {
            NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:entityName];
            NSBatchDeleteRequest *delete = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];
            
            [self.persistentStoreCoordinator executeRequest:delete withContext:moc error:error];
        } else {
            __block NSError *truncateError;

            [moc performBlock:^() {
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
                
                [request setIncludesSubentities:NO];
                
                NSArray *results = [moc executeFetchRequest:request error:&truncateError];
                
                if (results && [results count] > 0) {
                    for (NSManagedObject *entityObject in results) {
                        [moc deleteObject:entityObject];
                    }

                    truncateError = nil;
                    
                    [moc save:&truncateError];
                }
            }];

            if (error && truncateError) {
                *error = truncateError;
            }
        }
    }
}

#pragma mark - Sending updates to other apps in the app group
// see: http://martiancraft.com/blog/2015/06/shared-core-data/ for more information

- (NSURL *)tickleURL {
    NSURL *tickleURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:APP_GROUP_NAME];
    tickleURL = [tickleURL URLByAppendingPathComponent:DATA_TICKLE_DIRECTORY_NAME isDirectory:YES];

    return tickleURL;
}

- (void)setSendsUpdates:(BOOL)sendsUpdates {
    if (sendsUpdates == _sendsUpdates) return;

    if (sendsUpdates) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sendUpdatesFromContextSaved:) name:NSManagedObjectContextDidSaveNotification object:self.mainManagedObjectContext];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextDidSaveNotification object:self.mainManagedObjectContext];
    }

    _sendsUpdates = sendsUpdates;
}

- (void)sendUpdatesFromContextSaved:(NSNotification *)saveNotification {
    NSURL *tickleURL = [self tickleURL];
    [[NSFileManager defaultManager] createDirectoryAtURL:tickleURL withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *filename = [[NSUUID UUID] UUIDString];
    tickleURL = [tickleURL URLByAppendingPathComponent:filename];

    NSDictionary *saveInfo = [self serializableDictionaryFromSaveNotification:saveNotification];

    [saveInfo writeToURL:tickleURL atomically:YES];
}

- (NSDictionary *)serializableDictionaryFromSaveNotification:(NSNotification *)saveNotification {
    NSMutableDictionary *saveInfo = [NSMutableDictionary dictionary];
    for (NSString *key in @[NSInsertedObjectsKey, NSDeletedObjectsKey, NSUpdatedObjectsKey]) {
        NSArray *managedObjects = saveNotification.userInfo[key];
        if (!managedObjects) continue;
        NSMutableArray *objectIDRepresentations = [NSMutableArray array];
        for (NSManagedObject *object in managedObjects) {
            NSManagedObjectID *objectID = [object objectID];
            NSURL *URIRepresentation = [objectID URIRepresentation];
            NSString *objectIDValue = [URIRepresentation absoluteString];
            [objectIDRepresentations addObject:objectIDValue];
        }
        saveInfo[key] = [objectIDRepresentations copy];
    }
    return [saveInfo copy];
}

#pragma mark - Receiving updates
// see: http://martiancraft.com/blog/2015/06/shared-core-data/ for more information

- (void)setReceivesUpdates:(BOOL)receivesUpdates {
    if (receivesUpdates == _receivesUpdates) return;

    if (receivesUpdates) {
        [self clearTickleFolder];
        NSURL *tickleURL = [self tickleURL];
        [[NSFileManager defaultManager] createDirectoryAtURL:tickleURL withIntermediateDirectories:YES attributes:nil error:NULL];
        __weak typeof(self) weakSelf = self;
        self.folderWatcher = [[FolderWatcher alloc] initWithFolderURL:tickleURL writeAction:^{
            [weakSelf updateWrittenToURL:tickleURL];
        }];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clearTickleFolder) name:UIApplicationWillEnterForegroundNotification object:nil];
    } else {
        self.folderWatcher = nil;
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    }

    _receivesUpdates = receivesUpdates;
}

- (void)updateWrittenToURL:(NSURL *)url {
    NSError *error = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *files = [fileManager contentsOfDirectoryAtURL:url includingPropertiesForKeys:@[NSURLAddedToDirectoryDateKey] options:0 error:&error];
    if (error) NSLog(@"Error getting directory contents %@", error);

    if ([files count] == 0) return;

    NSArray *sortedFiles = [files sortedArrayUsingComparator:^NSComparisonResult(NSURL *obj1, NSURL *obj2) {

        NSDate *added1 = nil, *added2 = nil;
        NSError *error1 = nil, *error2 = nil;

        BOOL extracted1 = [obj1 getResourceValue:&added1 forKey:NSURLAddedToDirectoryDateKey error:&error1];
        BOOL extracted2 = [obj2 getResourceValue:&added2 forKey:NSURLAddedToDirectoryDateKey error:&error2];
        if (extracted1 && extracted2) {
            return [added1 compare:added2];
        } else {
            NSLog(@"Error extracting: %@ and/or %@", error1, error2);
            return NSOrderedSame;
        }
    }];

    [self.mainManagedObjectContext performBlockAndWait:^{
        NSPersistentStoreCoordinator *coordinator = self.mainManagedObjectContext.persistentStoreCoordinator;

        dispatch_queue_t fileRemoveQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

        for (NSURL *fileURL in sortedFiles) {
            NSDictionary *updateDictionary = [[NSDictionary alloc] initWithContentsOfURL:fileURL];

            NSNotification *importNotification = [self importNotificationFromDictionary:updateDictionary coordinator:coordinator];
            [self.mainManagedObjectContext mergeChangesFromContextDidSaveNotification:importNotification];

            // to prevent take time for merging, use another queue

            dispatch_async(fileRemoveQueue, ^{
                // test if file exists
                if ([fileURL checkResourceIsReachableAndReturnError:NULL]) {
                    NSError *deleteError = nil;
                    [fileManager removeItemAtURL:fileURL error:&deleteError];
                    if (deleteError) NSLog(@"Error removing %@ : %@", fileURL, deleteError);
                }
            });


        }
    }];
}

- (NSNotification *)importNotificationFromDictionary:(NSDictionary *)updateDictionary coordinator:(NSPersistentStoreCoordinator *)coordinator {
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    for (NSString *key in [updateDictionary allKeys]) {
        NSMutableArray *newObjectIDs = [NSMutableArray array];
        for (NSString *objectID in updateDictionary[key]) {
            NSURL *URIRepresentation = [NSURL URLWithString:objectID];
            NSManagedObjectID *managedObjectID = [coordinator managedObjectIDForURIRepresentation:URIRepresentation];
            [newObjectIDs addObject:managedObjectID];
        }
        userInfo[key] = newObjectIDs;
    }

    NSNotification *importNotification = [NSNotification notificationWithName:NSPersistentStoreDidImportUbiquitousContentChangesNotification object:coordinator userInfo:userInfo];
    return importNotification;
}

- (void)clearTickleFolder {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *files = [fileManager contentsOfDirectoryAtURL:[self tickleURL] includingPropertiesForKeys:nil options:0 error:NULL];
    for (NSURL *fileURL in files) {
        NSError *deleteError = nil;
        [fileManager removeItemAtURL:fileURL error:&deleteError];
        if (deleteError) NSLog(@"Error when clearing folder %@: %@", fileURL, deleteError);
    }
}

@end