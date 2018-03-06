#import "HierarchicalModelWithoutManaged.h"
#import "HierarchicalModel+CoreDataClass.h"
#import "ClopuccinoCoreData.h"
#import "DirectoryService.h"
#import "UserComputer+CoreDataClass.h"
#import "UserComputerDao.h"
#import "FileTransferWithoutManaged.h"
#import "HierarchicalModelDao.h"
#import "Utility.h"


@interface HierarchicalModelDao ()

@property(nonatomic, strong) ClopuccinoCoreData *coreData;

@property(nonatomic, strong) UserComputerDao *userComputerDao;

@end


@implementation HierarchicalModelDao {
}

- (id)init {
    self = [super init];
    if (self) {
        _coreData = [ClopuccinoCoreData defaultCoreData];

        _userComputerDao = [[UserComputerDao alloc] init];
    }

    return self;
}

- (void)createHierarchicalModelFromHierarchicalModelWithoutManaged:(HierarchicalModelWithoutManaged *)hierarchicalModelWithoutManaged {
    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlock:^() {
        UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:hierarchicalModelWithoutManaged.userComputerId managedObjectContext:moc];

        if (userComputer) {
            HierarchicalModel *hierarchicalModel = [NSEntityDescription insertNewObjectForEntityForName:@"HierarchicalModel" inManagedObjectContext:moc];

            hierarchicalModel.parent = hierarchicalModelWithoutManaged.parent;
            hierarchicalModel.name = hierarchicalModelWithoutManaged.name;
            hierarchicalModel.realParent = hierarchicalModelWithoutManaged.realParent;
            hierarchicalModel.realName = hierarchicalModelWithoutManaged.realName;
            hierarchicalModel.symlink = hierarchicalModelWithoutManaged.symlink;
            hierarchicalModel.readable = hierarchicalModelWithoutManaged.readable;
            hierarchicalModel.writable = hierarchicalModelWithoutManaged.writable;
            hierarchicalModel.executable = hierarchicalModelWithoutManaged.executable;
            hierarchicalModel.hidden = hierarchicalModelWithoutManaged.hidden;
            hierarchicalModel.type = [hierarchicalModelWithoutManaged isDirectory] ? HIERARCHICAL_MODEL_TYPE_DIRECTORY : HIERARCHICAL_MODEL_TYPE_FILE;
            hierarchicalModel.sectionName = [hierarchicalModelWithoutManaged isDirectory] ? HIERARCHICAL_MODEL_SECTION_NAME_DIRECTORY : HIERARCHICAL_MODEL_SECTION_NAME_FILE;
            hierarchicalModel.displaySize = hierarchicalModelWithoutManaged.displaySize;
            hierarchicalModel.sizeInBytes = hierarchicalModelWithoutManaged.sizeInBytes;
            hierarchicalModel.lastModified = hierarchicalModelWithoutManaged.lastModified;
            hierarchicalModel.contentType = hierarchicalModelWithoutManaged.contentType;
            hierarchicalModel.userComputer = userComputer;

            // download information
            hierarchicalModel.realServerPath = hierarchicalModelWithoutManaged.realServerPath;
            hierarchicalModel.status = hierarchicalModelWithoutManaged.status;
            hierarchicalModel.totalSize = hierarchicalModelWithoutManaged.totalSize;
            hierarchicalModel.transferredSize = hierarchicalModelWithoutManaged.transferredSize;
            hierarchicalModel.startTimestamp = hierarchicalModelWithoutManaged.startTimestamp;
            hierarchicalModel.endTimestamp = hierarchicalModelWithoutManaged.endTimestamp;
            hierarchicalModel.actionsAfterDownload = hierarchicalModelWithoutManaged.actionsAfterDownload;
            hierarchicalModel.transferKey = hierarchicalModelWithoutManaged.transferKey;
            hierarchicalModel.waitToConfirm = hierarchicalModelWithoutManaged.waitToConfirm;

            [self.coreData saveContext:moc];
        }
    }];
}

- (void)enumerateHierarchicalModelWithCompletionHandler:(void (^)(HierarchicalModel *hierarchicalModel))completionHandler saveContextAfterFinishedAllCompletionHandler:(BOOL)saveContextAfterFinishedAllCompletionHandler {
    if (completionHandler) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlockAndWait:^() {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"HierarchicalModel"];

            NSArray *hierarchicalModels = [moc executeFetchRequest:request error:NULL];

            if (hierarchicalModels && [hierarchicalModels count] > 0) {
                for (HierarchicalModel *hierarchicalModel in hierarchicalModels) {
                    completionHandler(hierarchicalModel);
                }

                if (saveContextAfterFinishedAllCompletionHandler) {
                    [self.coreData saveContext:moc];
                }
            }
        }];
    }
}

- (NSArray *)findAllHierarchicalModelsForUserComputer:(NSString *)userComputerId parent:(NSString *)parent error:(NSError * __autoreleasing *)error {
    __block NSMutableArray *hierarchicalModelsWithoutManaged = [NSMutableArray array];
    __block NSError *findError;

    if (userComputerId && parent) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlockAndWait:^() {
            UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

            if (userComputer) {
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"HierarchicalModel"];

                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ and parent == %@", userComputer, parent];
                [request setPredicate:predicate];

                NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES];
                [request setSortDescriptors:@[sortDescriptor]];

                NSArray *hierarchicalModels = [moc executeFetchRequest:request error:&findError];

                if (hierarchicalModels && [hierarchicalModels count] > 0) {
                    for (HierarchicalModel *hierarchicalModel in hierarchicalModels) {
                        [hierarchicalModelsWithoutManaged addObject:[self hierarchicalModelWithoutManagedFromHierarchicalModel:hierarchicalModel]];
                    }
                }
            }
        }];

        if (error && findError) {
            *error = findError;
        }
    }

    return hierarchicalModelsWithoutManaged;
}

// make sure it is wrapped under performBlock: or performBlockAndWait:
- (HierarchicalModelWithoutManaged *)hierarchicalModelWithoutManagedFromHierarchicalModel:(HierarchicalModel *)hierarchicalModel {
    HierarchicalModelWithoutManaged *hierarchicalModelWithoutManaged;

    if (hierarchicalModel) {
        hierarchicalModelWithoutManaged =
                [[HierarchicalModelWithoutManaged alloc] initWithUserComputerId:hierarchicalModel.userComputer.userComputerId
                                                                           name:hierarchicalModel.name
                                                                         parent:hierarchicalModel.parent
                                                                       realName:hierarchicalModel.realName
                                                                     realParent:hierarchicalModel.realParent
                                                                    contentType:hierarchicalModel.contentType
                                                                         hidden:hierarchicalModel.hidden
                                                                        symlink:hierarchicalModel.symlink
                                                                           type:hierarchicalModel.type
                                                                    sectionName:hierarchicalModel.sectionName
                                                                    displaySize:hierarchicalModel.displaySize
                                                                    sizeInBytes:hierarchicalModel.sizeInBytes
                                                                       readable:hierarchicalModel.readable
                                                                       writable:hierarchicalModel.writable
                                                                     executable:hierarchicalModel.executable
                                                                   lastModified:hierarchicalModel.lastModified
                                                                 realServerPath:hierarchicalModel.realServerPath
                                                                         status:hierarchicalModel.status
                                                                      totalSize:hierarchicalModel.totalSize
                                                                transferredSize:hierarchicalModel.transferredSize
                                                                 startTimestamp:hierarchicalModel.startTimestamp
                                                                   endTimestamp:hierarchicalModel.endTimestamp
                                                           actionsAfterDownload:hierarchicalModel.actionsAfterDownload
                                                                    transferKey:hierarchicalModel.transferKey
                                                                  waitToConfirm:hierarchicalModel.waitToConfirm];
    }

    return hierarchicalModelWithoutManaged;
}

- (HierarchicalModelWithoutManaged *)findHierarchicalModelForUserComputer:(NSString *)userComputerId realServerPath:(NSString *)realServerPath fileSeparator:(id)fileSeparator error:(NSError * __autoreleasing *)error {
    __block HierarchicalModelWithoutManaged *hierarchicalModelWithoutManaged;
    __block NSError *findError;

    if (userComputerId && realServerPath && fileSeparator) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlockAndWait:^() {
            UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

            if (userComputer) {
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"HierarchicalModel"];

                NSArray *components = [realServerPath componentsSeparatedByString:fileSeparator];

                if (components && [components count] > 0) {
                    NSString *realName = components[[components count] - 1];

                    NSString *realParent;

                    if ([components count] < 2) {
                        realParent = @"/";
                    } else {
                        NSString *realNamePrefixSeparator = [fileSeparator stringByAppendingString:realName];
                        NSRange range = [realServerPath rangeOfString:realNamePrefixSeparator options:NSBackwardsSearch];

                        realParent = [realServerPath substringToIndex:range.location];
                    }

                    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND realParent == %@ AND realName == %@", userComputer, realParent, realName];
                    [request setPredicate:predicate];

                    NSArray *foundHierarchicalModels = [moc executeFetchRequest:request error:&findError];

                    if (foundHierarchicalModels && [foundHierarchicalModels count] > 0) {
                        hierarchicalModelWithoutManaged = [self hierarchicalModelWithoutManagedFromHierarchicalModel:foundHierarchicalModels[0]];
                    }
                }
            } else {
                NSLog(@"User computer '%@' not found.", userComputerId);
            }
        }];

        if (error && findError) {
            *error = findError;
        }
    }

    return hierarchicalModelWithoutManaged;
}


- (HierarchicalModelWithoutManaged *)findHierarchicalModelForUserComputer:(NSString *)userComputerId parent:(NSString *)parent name:(NSString *)name error:(NSError * __autoreleasing *)error {
    __block HierarchicalModelWithoutManaged *hierarchicalModelWithoutManaged;
    __block NSError *findError;

    if (userComputerId && parent) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlockAndWait:^() {
            UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

            if (userComputer) {
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"HierarchicalModel"];

                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND parent == %@ AND name == %@", userComputer, parent, name];
                [request setPredicate:predicate];

                NSArray *foundHierarchicalModels = [moc executeFetchRequest:request error:&findError];

                if (foundHierarchicalModels && [foundHierarchicalModels count] > 0) {
                    hierarchicalModelWithoutManaged = [self hierarchicalModelWithoutManagedFromHierarchicalModel:foundHierarchicalModels[0]];
                }
            } else {
                NSLog(@"User computer '%@' not found.", userComputerId);
            }
        }];

        if (error && findError) {
            *error = findError;
        }
    }

    return hierarchicalModelWithoutManaged;
}

- (void)updateHierarchicalModel:(HierarchicalModelWithoutManaged *)hierarchicalModelWithoutManaged completionHandler:(void (^)(NSError *error))completionHandler {
    if (hierarchicalModelWithoutManaged
            && hierarchicalModelWithoutManaged.userComputerId
            && hierarchicalModelWithoutManaged.parent
            && hierarchicalModelWithoutManaged.name
            && hierarchicalModelWithoutManaged.realParent
            && hierarchicalModelWithoutManaged.realName) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlock:^() {
            UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:hierarchicalModelWithoutManaged.userComputerId managedObjectContext:moc];

            if (userComputer) {
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"HierarchicalModel"];

                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND parent == %@ AND name == %@", userComputer, hierarchicalModelWithoutManaged.parent, hierarchicalModelWithoutManaged.name];
                [request setPredicate:predicate];

                NSError *fetchError;
                NSArray *foundHierarchicalModels = [moc executeFetchRequest:request error:&fetchError];

                if (fetchError) {
                    NSLog(@"Error on finding hierarchical model for user computer: %@, parent: %@, name: %@\n%@", hierarchicalModelWithoutManaged.userComputerId, hierarchicalModelWithoutManaged.parent, hierarchicalModelWithoutManaged.name, fetchError);

                    if (completionHandler) {
                        completionHandler(fetchError);
                    }
                } else if (foundHierarchicalModels && [foundHierarchicalModels count] > 0) {
                    HierarchicalModel *hierarchicalModel = foundHierarchicalModels[0];

                    hierarchicalModel.realParent = hierarchicalModelWithoutManaged.realParent;
                    hierarchicalModel.realName = hierarchicalModelWithoutManaged.realName;
                    hierarchicalModel.symlink = hierarchicalModelWithoutManaged.symlink;
                    hierarchicalModel.readable = hierarchicalModelWithoutManaged.readable;
                    hierarchicalModel.writable = hierarchicalModelWithoutManaged.writable;
                    hierarchicalModel.executable = hierarchicalModelWithoutManaged.executable;
                    hierarchicalModel.hidden = hierarchicalModelWithoutManaged.hidden;
                    hierarchicalModel.type = hierarchicalModelWithoutManaged.type;
                    hierarchicalModel.sectionName = hierarchicalModelWithoutManaged.sectionName;
                    hierarchicalModel.displaySize = hierarchicalModelWithoutManaged.displaySize;
                    hierarchicalModel.sizeInBytes = hierarchicalModelWithoutManaged.sizeInBytes;
                    hierarchicalModel.lastModified = hierarchicalModelWithoutManaged.lastModified;
                    hierarchicalModel.contentType = hierarchicalModelWithoutManaged.contentType;

                    // download information
                    hierarchicalModel.realServerPath = hierarchicalModelWithoutManaged.realServerPath;
                    hierarchicalModel.status = hierarchicalModelWithoutManaged.status;
                    hierarchicalModel.totalSize = hierarchicalModelWithoutManaged.totalSize;
                    hierarchicalModel.transferredSize = hierarchicalModelWithoutManaged.transferredSize;
                    hierarchicalModel.startTimestamp = hierarchicalModelWithoutManaged.startTimestamp;
                    hierarchicalModel.endTimestamp = hierarchicalModelWithoutManaged.endTimestamp;
                    hierarchicalModel.actionsAfterDownload = hierarchicalModelWithoutManaged.actionsAfterDownload;
                    hierarchicalModel.transferKey = hierarchicalModelWithoutManaged.transferKey;
                    hierarchicalModel.waitToConfirm = hierarchicalModelWithoutManaged.waitToConfirm;

                    if (completionHandler) {
                        [self.coreData saveContext:moc completionHandler:^() {
                            if (completionHandler) {
                                completionHandler(nil);
                            }
                        }];
                    } else {
                        [self.coreData saveContext:moc];
                    }
                }
            }
        }];
    }
}

- (void)deleteHierarchicalModelForUserComputer:(NSString *)userComputerId parent:(NSString *)parent hierarchically:(BOOL)hierarchically {
    if (userComputerId && parent) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlock:^() {
            UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

            if (userComputer) {
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"HierarchicalModel"];

                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND parent == %@", userComputer, parent];
                [request setPredicate:predicate];

                NSError *fetchError;
                NSArray *foundHierarchicalModels = [moc executeFetchRequest:request error:&fetchError];

                if (foundHierarchicalModels && [foundHierarchicalModels count] > 0) {
                    for (HierarchicalModel *hierarchicalModel in foundHierarchicalModels) {
                        if (hierarchically && [HierarchicalModelWithoutManaged isTypeOfDirectory:hierarchicalModel.type]) {
                            NSString *subDirectory = [DirectoryService serverPathFromParent:hierarchicalModel.realParent name:hierarchicalModel.realName];

                            if (subDirectory) {
                                [self deleteHierarchicalModelForUserComputer:userComputerId parent:subDirectory hierarchically:hierarchically];
                            }
                        }

                        @autoreleasepool {
                            [moc deleteObject:hierarchicalModel];
                        }
                    }

                    [self.coreData saveContext:moc];
                } else if (fetchError) {
                    NSLog(@"Error on finding hierarchical model for user computer: %@, parent: %@\n%@", userComputerId, parent, [fetchError userInfo]);
                }
            }
        }];
    }
}

// make sure it was wrapped in  performBlock: or  performBlockAndWait:
// elements of NSString containing the name of the file/directory
//- (NSMutableArray *)findAllNamesForUserComputer:(UserComputer *)userComputer parent:(NSString *)parentPath managedObjectContext:(NSManagedObjectContext *)managedObjectContext error:(NSError * __autoreleasing *)error {
//    NSMutableArray *names = [NSMutableArray array];
//
//    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"HierarchicalModel"];
//
//    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ and parent == %@", userComputer, parentPath];
//    [request setPredicate:predicate];
//
//    NSArray *hierarchicalModels = [managedObjectContext executeFetchRequest:request error:error];
//
//    if (hierarchicalModels && [hierarchicalModels count] > 0) {
//        for (HierarchicalModel *hierarchicalModel in hierarchicalModels) {
//            [names addObject:hierarchicalModel.name];
//        }
//    }
//
//    return names;
//}

// make sure it was wrapped in  performBlock: or  performBlockAndWait:
// elements of NSManagedObjectID, the objectID of the HierarchicalModels in the parent path, instead of real path path.
- (NSMutableArray *)findAllObjectIDsForUserComputer:(UserComputer *)userComputer parent:(NSString *)parentPath managedObjectContext:(NSManagedObjectContext *)managedObjectContext error:(NSError * __autoreleasing *)error {
    NSMutableArray *objectIDs = [NSMutableArray array];

    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"HierarchicalModel"];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ and parent == %@", userComputer, parentPath];
    [request setPredicate:predicate];

    NSArray *hierarchicalModels = [managedObjectContext executeFetchRequest:request error:error];

    if (hierarchicalModels && [hierarchicalModels count] > 0) {
        for (HierarchicalModel *hierarchicalModel in hierarchicalModels) {
            [objectIDs addObject:hierarchicalModel.objectID];
        }
    }

    return objectIDs;
}

// make sure it was wrapped in  performBlock: or  performBlockAndWait:
//- (void)deleteHierarchicalModelForUserComputer:(UserComputer *)userComputer parent:(NSString *)parentPath names:(NSArray *)names managedObjectContext:(NSManagedObjectContext *)managedObjectContext {
//    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"HierarchicalModel"];
//
//    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND realParent == %@ AND name IN %@", userComputer, parentPath, names];
//    [request setPredicate:predicate];
//
//    NSError *fetchError;
//    NSArray *foundHierarchicalModels = [managedObjectContext executeFetchRequest:request error:&fetchError];
//
//    if (fetchError) {
//        NSString *userComputerId = userComputer.userComputerId;
//        NSLog(@"Error on finding hierarchical models for user: %@, parent: %@, names in %@\n%@", userComputerId, parentPath, names, fetchError);
//    } else if (foundHierarchicalModels && [foundHierarchicalModels count] > 0) {
//        for (HierarchicalModel *hierarchicalModel in foundHierarchicalModels) {
//            @autoreleasepool {
//                [managedObjectContext deleteObject:hierarchicalModel];
//            }
//        }
//    }
//}

- (void)parseJsonAndSyncWithCurrentHierarchicalModels:(NSData *)data userComputer:(NSString *)userComputerId parentPath:(NSString *)parentPath completionHandler:(void (^)(void))completionHandler {
    NSError *jsonError = nil;
    NSArray *jsonArray = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];

    if (jsonError) {
        NSString *dataContent;

        if (data && [data length] > 0) {
            dataContent = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        } else {
            dataContent = @"";
        }

        NSLog(@"Error on parsing hierarchical models json data. JSON data=%@.\n%@", dataContent, jsonError);
    } else {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlock:^() {
            UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

            if (userComputer) {
                NSMutableArray *toBeRemoved = [self findAllObjectIDsForUserComputer:userComputer parent:parentPath managedObjectContext:moc error:NULL];

                for (NSDictionary *jsonObject in jsonArray) {
                    @autoreleasepool {
                        NSString *name = jsonObject[@"name"];
                        NSString *parent = jsonObject[@"parent"];
                        NSString *realName = jsonObject[@"realName"];
                        NSString *realParent = jsonObject[@"realParent"];
                        NSString *type = jsonObject[@"type"];

                        // DEBUG:
//                        NSLog(@"Received file/directory:\nname: %@\nparent: %@\nreal name: %@\nreal parent: %@", name, parent, realName, realParent);

                        // skip and remain in the to-be-removed list if one of the necessary value is [NSNull null]
                        if (!type
                                || ([type hasSuffix:HIERARCHICAL_MODEL_TYPE_SUFFIX_FILE]
                                && (!name || [name isKindOfClass:[NSNull class]] || [[name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] < 1
                                || !realName || [realName isKindOfClass:[NSNull class]] || [[realName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] < 1
                                || !parent || [parent isKindOfClass:[NSNull class]] || [[parent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] < 1
                                || !realParent || [realParent isKindOfClass:[NSNull class]] || [[realParent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] < 1))
                                || ([type hasSuffix:HIERARCHICAL_MODEL_TYPE_DIRECTORY]
                                && (!name || [name isKindOfClass:[NSNull class]] || [[name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] < 1
                                || !realName || [realName isKindOfClass:[NSNull class]] || [[realName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] < 1))) {
                            NSLog(@"Skip received file/directory:\nname: %@\nparent: %@\nreal name: %@\nreal parent: %@", name, parent, realName, realParent);

                            continue;
                        }

                        // Not working for '/': the real name is '/' and the real parent is empty ('')
//                        if (realParent  && expectedRealParentPath && ![[realParent lowercaseString] isEqualToString:[expectedRealParentPath lowercaseString]]) {
//                            NSLog(@"Skip save file/directory because the real parent: %@ not expected to %@", realParent, expectedRealParentPath);
//
//                            continue;
//                        }

                        /* remove .lnk for windows shortcut -- do not use because bookmark will not find it. */
//                        NSString *savedName = [HierarchicalModelWithoutManaged rename:name forShortcutType:type];

                        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"HierarchicalModel"];

                        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND parent == %@ AND name == %@", userComputer, parentPath, name];

                        // Do not use real parent path, use parent path instead
//                        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND realParent == %@ AND name == %@", userComputer, parentPath, name];

                        [request setPredicate:predicate];

                        NSError *fetchError;
                        NSArray *foundHierarchicalModels = [moc executeFetchRequest:request error:&fetchError];

                        if (fetchError) {
                            NSLog(@"Error on fetching hierarchical model for user computer: %@, parent: %@, name: %@", userComputerId, parentPath, name);
                            continue;
                        }

                        NSString *savedType = [HierarchicalModelWithoutManaged isTypeOfDirectory:type] ? HIERARCHICAL_MODEL_TYPE_DIRECTORY : HIERARCHICAL_MODEL_TYPE_FILE;
                        NSString *contentType = jsonObject[@"contentType"];
                        NSString *displaySize = jsonObject[@"displaySize"];
                        NSNumber *sizeInBytes = jsonObject[@"sizeInBytes"];
                        NSNumber *symlink = jsonObject[@"symlink"];
                        NSNumber *hidden = jsonObject[@"hidden"];
                        NSNumber *readable = jsonObject[@"readable"];
                        NSNumber *writable = jsonObject[@"writable"];
                        NSNumber *executable = jsonObject[@"executable"];
                        NSString *lastModified = jsonObject[@"lastModified"];

                        // Changed type for bundle directory

                        if ([savedType isEqualToString:HIERARCHICAL_MODEL_TYPE_DIRECTORY]) {
                            if ([HierarchicalModelWithoutManaged isBundleDirectoryWithRealFilename:realName]) {
                                savedType = HIERARCHICAL_MODEL_TYPE_BUNDLE_DIRECTORY_FILE;
                            }
                        }

                        NSString *sectionName = (savedType && [savedType hasSuffix:HIERARCHICAL_MODEL_TYPE_SUFFIX_FILE]) ? HIERARCHICAL_MODEL_SECTION_NAME_FILE : HIERARCHICAL_MODEL_SECTION_NAME_DIRECTORY;

                        HierarchicalModel *hierarchicalModel;
                        if (!foundHierarchicalModels || [foundHierarchicalModels count] == 0) {
                            /* create */
                            hierarchicalModel = [NSEntityDescription insertNewObjectForEntityForName:@"HierarchicalModel" inManagedObjectContext:moc];

                            hierarchicalModel.parent = parent;
                            hierarchicalModel.name = name;
                            hierarchicalModel.realParent = realParent;
                            hierarchicalModel.realName = realName;
                            hierarchicalModel.userComputer = userComputer;
                            hierarchicalModel.symlink = symlink;
                            hierarchicalModel.readable = readable;
                            hierarchicalModel.writable = writable;
                            hierarchicalModel.executable = executable;
                            hierarchicalModel.hidden = hidden;
                            hierarchicalModel.type = savedType;
                            hierarchicalModel.sectionName = sectionName;
                            hierarchicalModel.displaySize = displaySize;
                            hierarchicalModel.sizeInBytes = sizeInBytes;
                            hierarchicalModel.lastModified = lastModified;
                            hierarchicalModel.contentType = contentType;
                        } else {
                            // update properties, excluding the download information

                            hierarchicalModel = foundHierarchicalModels[0];

                            if (!hierarchicalModel.parent || ![hierarchicalModel.parent isEqualToString:parent]) {
                                hierarchicalModel.parent = parent;
                            }

                            if (!hierarchicalModel.name || ![hierarchicalModel.name isEqualToString:name]) {
                                hierarchicalModel.name = name;
                            }

                            if (!hierarchicalModel.realParent || ![hierarchicalModel.realParent isEqualToString:realParent]) {
                                hierarchicalModel.realParent = realParent;
                            }

                            if (!hierarchicalModel.realName || ![hierarchicalModel.realName isEqualToString:realName]) {
                                hierarchicalModel.realName = realName;
                            }

                            if (!hierarchicalModel.symlink || ![hierarchicalModel.symlink isEqualToNumber:symlink]) {
                                hierarchicalModel.symlink = symlink;
                            }

                            if (!hierarchicalModel.readable || ![hierarchicalModel.readable isEqualToNumber:readable]) {
                                hierarchicalModel.readable = readable;
                            }

                            if (!hierarchicalModel.writable || ![hierarchicalModel.writable isEqualToNumber:writable]) {
                                hierarchicalModel.writable = writable;
                            }

                            if (!hierarchicalModel.executable || ![hierarchicalModel.executable isEqualToNumber:executable]) {
                                hierarchicalModel.executable = executable;
                            }

                            if (!hierarchicalModel.hidden || ![hierarchicalModel.hidden isEqualToNumber:hidden]) {
                                hierarchicalModel.hidden = hidden;
                            }

                            if (!hierarchicalModel.type || ![hierarchicalModel.type isEqualToString:savedType]) {
                                hierarchicalModel.type = savedType;
                            }

                            if (!hierarchicalModel.sectionName || ![hierarchicalModel.sectionName isEqualToString:sectionName]) {
                                hierarchicalModel.sectionName = sectionName;
                            }

                            if (!hierarchicalModel.displaySize || ![hierarchicalModel.displaySize isEqualToString:displaySize]) {
                                hierarchicalModel.displaySize = displaySize;
                            }

                            if (!hierarchicalModel.sizeInBytes || ![hierarchicalModel.sizeInBytes isEqualToNumber:sizeInBytes]) {
                                hierarchicalModel.sizeInBytes = sizeInBytes;
                            }

                            if (!hierarchicalModel.lastModified || ![hierarchicalModel.lastModified isEqualToString:lastModified]) {
                                hierarchicalModel.lastModified = lastModified;
                            }

                            if (!hierarchicalModel.contentType || ![hierarchicalModel.contentType isEqualToString:contentType]) {
                                hierarchicalModel.contentType = contentType;
                            }

                            /* exclude it from to be removed list */
                            [toBeRemoved removeObject:hierarchicalModel.objectID];
                        }

                        // DEBUG:
//                        NSLog(@"HierarchicalModel to be saved: %@", hierarchicalModel);
                    }
                }

                if ([toBeRemoved count] > 0) {
                    for (NSManagedObjectID *objectID in toBeRemoved) {
                        // DEBUG
//                        NSLog(@"Try removing object with id  : %@", objectID);

                        NSError *foundError;
                        NSManagedObject *mangedObject = [moc existingObjectWithID:objectID error:&foundError];

                        if (mangedObject) {
                            [moc deleteObject:mangedObject];
                        }
                    }
                }

                [self.coreData saveContext:moc completionHandler:completionHandler];
            }
        }];
    }
}

#pragma mark - For delegates of UITableView

- (NSFetchedResultsController *)createHierarchicalModelsFetchedResultsControllerForUserComputer:(NSString *)userComputerId parent:(NSString *)parent directoryOnly:(BOOL)directoryOnly delegate:(id <NSFetchedResultsControllerDelegate>)delegate {
    __block NSFetchedResultsController *controller;

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlockAndWait:^() {
        UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

        if (userComputer) {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"HierarchicalModel"];

            NSPredicate *predicate;
//            NSString *cacheName;
//
            if (directoryOnly) {
                predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ and parent == %@ and type == %@", userComputer, parent, HIERARCHICAL_MODEL_TYPE_DIRECTORY];
//                cacheName = [NSString stringWithFormat:@"HierarchicalModel+%@+%@+YES", userComputerId, parent];
            } else {
                predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ and parent == %@", userComputer, parent];
//                cacheName = [NSString stringWithFormat:@"HierarchicalModel+%@+%@+NO", userComputerId, parent];
            }

            [request setPredicate:predicate];

            NSSortDescriptor *sectionNameSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"sectionName" ascending:YES];
//            NSSortDescriptor *typeSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"type" ascending:YES];

            NSSortDescriptor *nameSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(caseInsensitiveCompare:)];

            [request setSortDescriptors:@[sectionNameSortDescriptor, nameSortDescriptor]];
//            [request setSortDescriptors:@[typeSortDescriptor, nameSortDescriptor]];

            // Stop using cache to prevent the following error to crash APP:
            // uncaught exception 'NSInternalInconsistencyException', reason: 'CoreData: FATAL ERROR:
            // The persistent cache of section information does not match the current configuration.
            // You have illegally mutated the NSFetchedResultsController's fetch request, its predicate,
            // or its sort descriptor without either disabling caching or using +deleteCacheWithName:'
            controller = [[NSFetchedResultsController alloc] initWithFetchRequest:request managedObjectContext:moc sectionNameKeyPath:@"sectionName" cacheName:nil];
//            controller = [[NSFetchedResultsController alloc] initWithFetchRequest:request managedObjectContext:moc sectionNameKeyPath:@"type" cacheName:cacheName];
            controller.delegate = delegate;
        }
    }];

    return controller;
}

- (BOOL)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController performFetch:(NSError * __autoreleasing *)error {
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

- (HierarchicalModelWithoutManaged *)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController objectAtIndexPath:(NSIndexPath *)indexPath {
    __block HierarchicalModelWithoutManaged *hierarchicalModelWithoutManaged;

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlockAndWait:^() {
        HierarchicalModel *hierarchicalModel;

        if ([[fetchedResultsController sections] count] > [indexPath section]) {
            id <NSFetchedResultsSectionInfo> sectionInfo = [fetchedResultsController sections][(NSUInteger) [indexPath section]];

            if ([sectionInfo numberOfObjects] > [indexPath row]) {
                hierarchicalModel = (HierarchicalModel *) [fetchedResultsController objectAtIndexPath:indexPath];
            }
        }

        if (hierarchicalModel) {
            hierarchicalModelWithoutManaged = [self hierarchicalModelWithoutManagedFromHierarchicalModel:hierarchicalModel];
        }
    }];

    return hierarchicalModelWithoutManaged;
}

- (BOOL)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController isDirectoryAtIndexPath:(NSIndexPath *)indexPath {
    __block BOOL isDirectory = NO;

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlockAndWait:^() {
        HierarchicalModel *hierarchicalModel;

        if ([[fetchedResultsController sections] count] > [indexPath section]) {
            id <NSFetchedResultsSectionInfo> sectionInfo = [fetchedResultsController sections][(NSUInteger) [indexPath section]];

            if ([sectionInfo numberOfObjects] > [indexPath row]) {
                hierarchicalModel = (HierarchicalModel *) [fetchedResultsController objectAtIndexPath:indexPath];
            }
        }

        if (hierarchicalModel) {
            isDirectory = [HierarchicalModelWithoutManaged isDirectoryWithType:hierarchicalModel.type];
        }
    }];

    return isDirectory;
}

- (NSInteger)numberOfSectionsForFetchedResultsController:(NSFetchedResultsController *)fetchedResultsController {
    __block NSInteger count = 0;

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlockAndWait:^() {
        count = [[fetchedResultsController sections] count];
    }];

    return count;
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

- (NSString *)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController sectionName:(NSInteger)section {
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

- (NSArray *)sectionIndexTitlesForFetchedResultsController:(NSFetchedResultsController *)fetchedResultsController {
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

#pragma mark - Manage download-related information

- (void)removeDownloadInformationInHierarchicalModelsWithTransferKey:(NSString *)transferKey completionHandler:(void (^)(void))completionHandler {
//- (void)removeDownloadInformationInHierarchicalModelsWithTransferKey:(NSString *)transferKey {
    if (transferKey) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlock:^() {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"HierarchicalModel"];

            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"transferKey == %@", transferKey];
            [request setPredicate:predicate];

            NSArray *foundHierarchicalModels = [moc executeFetchRequest:request error:NULL];

            if (foundHierarchicalModels && [foundHierarchicalModels count] > 0) {
                for (HierarchicalModel *hierarchicalModel in foundHierarchicalModels) {
                    // clear the values to the download-related columns

                    [self hierarchicalModel:hierarchicalModel
updateDownloadInformationWithRealServerPath:@""
                                     status:@""
                                  totalSize:@0
                            transferredSize:@0
                             startTimestamp:@0
                               endTimestamp:@0
                       actionsAfterDownload:@"NO"
                                transferKey:@""
                              waitToConfirm:@NO];
                }

                [self.coreData saveContext:moc completionHandler:completionHandler];
            }
        }];
    }
}

- (void)updateDownloadInformationToHierarchicalModelsFromFileTransferWithoutManaged:(FileTransferWithoutManaged *)fileTransferWithoutManaged
                                             findHierarchicalModelsByRealServerPath:(BOOL)findHierarchicalModelsByRealServerPath
                                                                      fileSeparator:(NSString *)fileSeparator {
    if (fileTransferWithoutManaged) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlock:^() {
            UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:fileTransferWithoutManaged.userComputerId managedObjectContext:moc];

            if (userComputer) {
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"HierarchicalModel"];

                NSString *realServerPath = fileTransferWithoutManaged.realServerPath;

                if (realServerPath) {
                    NSPredicate *predicate;

                    // If findHierarchicalModelsByRealServerPath == YES, find the HierarchicalModel objects by fileTransferWithoutManaged.realServerPath (and fileTransferWithoutManaged.userComputerId) and fileSeparator can be nil.
                    // If findHierarchicalModelsByRealServerPath == NO, find the HierarchicalModel objects by realParent and realName (and fileTransferWithoutManaged.userComputerId) and fileSeparator cannot be nil.

                    if (findHierarchicalModelsByRealServerPath) {
                        predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND realServerPath == %@", userComputer, realServerPath];
                    } else {
                        NSArray *components = [realServerPath componentsSeparatedByString:fileSeparator];

                        if (components && [components count] > 0) {
                            NSString *realName = components[[components count] - 1];

                            NSString *realParent;

                            if ([components count] < 2) {
                                realParent = @"/";
                            } else {
                                NSString *realNamePrefixSeparator = [fileSeparator stringByAppendingString:realName];
                                NSRange range = [realServerPath rangeOfString:realNamePrefixSeparator options:NSBackwardsSearch];

                                realParent = [realServerPath substringToIndex:range.location];
                            }

                            predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND realParent == %@ AND realName == %@", userComputer, realParent, realName];
                        }
                    }

                    [request setPredicate:predicate];

                    NSArray *foundHierarchicalModels = [moc executeFetchRequest:request error:NULL];

                    if (foundHierarchicalModels && [foundHierarchicalModels count] > 0) {
                        for (HierarchicalModel *hierarchicalModel in foundHierarchicalModels) {
                            // update the download-related columns

                            [self hierarchicalModel:hierarchicalModel
        updateDownloadInformationWithRealServerPath:realServerPath
                                             status:fileTransferWithoutManaged.status
                                          totalSize:fileTransferWithoutManaged.totalSize
                                    transferredSize:fileTransferWithoutManaged.transferredSize
                                     startTimestamp:fileTransferWithoutManaged.startTimestamp
                                       endTimestamp:fileTransferWithoutManaged.endTimestamp
                               actionsAfterDownload:fileTransferWithoutManaged.actionsAfterDownload
                                        transferKey:fileTransferWithoutManaged.transferKey
                                      waitToConfirm:fileTransferWithoutManaged.waitToConfirm];
                        }

                        [self.coreData saveContext:moc];
                    }
                } else {
                    NSLog(@"Empty value for real server path for file transfer.");
                }
            } else {
                NSLog(@"User computer '%@' not found.", fileTransferWithoutManaged.userComputerId);
            }
        }];
    }
}

// just set the properties, not save to db
- (void)hierarchicalModel:(HierarchicalModel *)hierarchicalModel updateDownloadInformationWithRealServerPath:(NSString *)realServerPath
                   status:(NSString *)status
                totalSize:(NSNumber *)totalSize
          transferredSize:(NSNumber *)transferredSize
           startTimestamp:(NSNumber *)startTimestamp
             endTimestamp:(NSNumber *)endTimestamp
     actionsAfterDownload:(NSString *)actionsAfterDownload
              transferKey:(NSString *)transferKey
            waitToConfirm:(NSNumber *)waitToConfirm {
    hierarchicalModel.realServerPath = realServerPath;
    hierarchicalModel.status = status;
    hierarchicalModel.totalSize = totalSize;
    hierarchicalModel.transferredSize = transferredSize;
    hierarchicalModel.startTimestamp = startTimestamp;
    hierarchicalModel.endTimestamp = endTimestamp;
    hierarchicalModel.actionsAfterDownload = actionsAfterDownload;
    hierarchicalModel.transferKey = transferKey;
    hierarchicalModel.waitToConfirm = waitToConfirm;
}

- (HierarchicalModelWithoutManaged *)findHierarchicalModelForTransferKey:(NSString *)transferKey error:(NSError * __autoreleasing *)error {
    __block HierarchicalModelWithoutManaged *hierarchicalModelWithoutManaged;
    __block NSError *findError;

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlockAndWait:^() {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"HierarchicalModel"];

        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"transferKey == %@", transferKey];
        [request setPredicate:predicate];

        NSArray *results = [moc executeFetchRequest:request error:&findError];

        if (!findError) {
            if (results && [results count] > 0) {
                HierarchicalModel *hierarchicalModel = results[0];

                hierarchicalModelWithoutManaged = [self hierarchicalModelWithoutManagedFromHierarchicalModel:hierarchicalModel];
            } else {
                findError = [Utility errorWithErrorCode:NSFileNoSuchFileError localizedDescription:NSLocalizedString(@"No such file.", @"")];
            }
        }
    }];

    if (error && findError) {
        *error = findError;
    } else if (findError) {
        NSLog(@"Error on finding file/directory with error:\n%@", [findError userInfo]);
    }

    return hierarchicalModelWithoutManaged;
}

@end
