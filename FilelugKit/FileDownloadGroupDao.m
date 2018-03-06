#import "FileDownloadGroupDao.h"
#import "FileDownloadGroup+CoreDataClass.h"
#import "ClopuccinoCoreData.h"
#import "UserComputerDao.h"
#import "Utility.h"
#import "FileTransfer+CoreDataClass.h"
#import "UserComputer+CoreDataClass.h"
#import "FileDownloadGroupWithoutManaged.h"

@interface FileDownloadGroupDao ()

@property(nonatomic, strong) ClopuccinoCoreData *coreData;

@property(nonatomic, strong) UserComputerDao *userComputerDao;

@end

@implementation FileDownloadGroupDao

- (id)init {
    self = [super init];
    if (self) {
        _coreData = [ClopuccinoCoreData defaultCoreData];
        _userComputerDao = [[UserComputerDao alloc] init];
    }

    return self;
}

- (void)createFileDownloadGroupWithDownloadGroupId:(NSString *)downloadGroupId notificationType:(NSInteger)notificationType userComputerId:(NSString *)userComputerId completionHandler:(void (^)(void))completionHandler {
    NSNumber *createTimestamp = [Utility currentJavaTimeMilliseconds];

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlock:^() {
        UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

        if (userComputer) {
            FileDownloadGroup *fileDownloadGroup = (FileDownloadGroup *) [NSEntityDescription insertNewObjectForEntityForName:@"FileDownloadGroup" inManagedObjectContext:moc];

            fileDownloadGroup.userComputer = userComputer;
            fileDownloadGroup.downloadGroupId = downloadGroupId;
            fileDownloadGroup.notificationType = @(notificationType);
            fileDownloadGroup.createTimestamp = createTimestamp;

            if (completionHandler) {
                [self.coreData saveContext:moc completionHandler:completionHandler];
            } else {
                [self.coreData saveContext:moc];
            }
        }
    }];
}

// The method must invoke in the specified managedObjectContext block
- (void)createFileDownloadGroupButNotSaveInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext downloadGroupId:(NSString *)downloadGroupId notificationType:(NSInteger)notificationType userComputer:(UserComputer *)userComputer fileTransfers:(NSSet<FileTransfer *> *)fileTransfers {
    FileDownloadGroup *fileDownloadGroup = [NSEntityDescription insertNewObjectForEntityForName:@"FileDownloadGroup" inManagedObjectContext:managedObjectContext];

    NSNumber *createTimestamp = [Utility currentJavaTimeMilliseconds];

    fileDownloadGroup.userComputer = userComputer;
    fileDownloadGroup.downloadGroupId = downloadGroupId;
    fileDownloadGroup.notificationType = @(notificationType);
    fileDownloadGroup.createTimestamp = createTimestamp;
    fileDownloadGroup.fileTransfers = fileTransfers;
}

- (FileDownloadGroup *)findFileDownloadGroupByDownloadGroupId:(NSString *)downloadGroupId managedObjectContext:(NSManagedObjectContext *)managedObjectContext {
    __block FileDownloadGroup *fileDownloadGroup;

    if (downloadGroupId && [downloadGroupId stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
        [managedObjectContext performBlockAndWait:^() {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileDownloadGroup"];

            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"downloadGroupId == %@", downloadGroupId];
            [request setPredicate:predicate];

            NSError *fetchError;
            NSArray *fileDownloadGroups = [managedObjectContext executeFetchRequest:request error:&fetchError];

            if (fetchError) {
                NSLog(@"Error on fetching file download group by id: %@\n%@", downloadGroupId, [fetchError userInfo]);
            }

            if (fileDownloadGroups && [fileDownloadGroups count] > 0) {
                fileDownloadGroup = fileDownloadGroups[0];
            }
        }];
    }

    return fileDownloadGroup;
}

- (FileDownloadGroupWithoutManaged *)findFileDownloadGroupByTransferKey:(NSString *)transferKey {
    __block FileDownloadGroupWithoutManaged *fileDownloadGroupWithoutManaged;

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlockAndWait:^() {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileTransfer"];

        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"transferKey == %@", transferKey];
        [request setPredicate:predicate];

        NSError *findError;
        NSArray *results = [moc executeFetchRequest:request error:&findError];

        if (results && [results count] > 0) {
            FileTransfer *fileTransfer = results[0];

            FileDownloadGroup *fileDownloadGroup = fileTransfer.fileDownloadGroup;

            NSString *downloadGroupId = [fileDownloadGroup.downloadGroupId copy];

            NSNumber *notificationType = [fileDownloadGroup.notificationType copy];

            NSNumber *createTimestamp = [fileDownloadGroup.createTimestamp copy];

            NSMutableSet<NSString *> *fileTransferKeys;

            NSSet<FileTransfer *> *fileTransfers = fileDownloadGroup.fileTransfers;

            if (fileTransfers && [fileTransfers count] > 0) {
                fileTransferKeys = [NSMutableSet set];

                for (FileTransfer *foundFileTransfer in fileTransfers) {
                    [fileTransferKeys addObject:[foundFileTransfer.transferKey copy]];
                }
            }

            NSString *userComputerId = fileDownloadGroup.userComputer.userComputerId;

            fileDownloadGroupWithoutManaged = [[FileDownloadGroupWithoutManaged alloc] initWithDownloadGroupId:downloadGroupId
                                                                                              notificationType:notificationType
                                                                                               createTimestamp:createTimestamp
                                                                                              fileTransferKeys:fileTransferKeys
                                                                                                userComputerId:userComputerId];
        } else {
            if (findError) {
                NSLog(@"Error on finding file download group.\n%@", [findError userInfo]);
            }
        }
    }];

    return fileDownloadGroupWithoutManaged;
}

@end
