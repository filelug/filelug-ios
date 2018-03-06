#import "FileUploadGroupDao.h"
#import "ClopuccinoCoreData.h"
#import "UserComputerDao.h"
#import "FileUploadGroup+CoreDataClass.h"
#import "Utility.h"


@interface FileUploadGroupDao ()

@property(nonatomic, strong) ClopuccinoCoreData *coreData;

@property(nonatomic, strong) UserComputerDao *userComputerDao;

@end

@implementation FileUploadGroupDao

- (id)init {
    self = [super init];
    if (self) {
        _coreData = [ClopuccinoCoreData defaultCoreData];
        _userComputerDao = [[UserComputerDao alloc] init];
    }
    
    return self;
}

- (void)createFileUploadGroupWithUploadGroupId:(NSString *)uploadGroupId targetDirectory:(NSString *)targetDirectory subdirectoryType:(NSInteger)subdirectoryType subdirectoryValue:(NSString *)subdirectoryValue descriptionType:(NSInteger)descriptionType descriptionValue:(NSString *)descriptionValue notificationType:(NSInteger)notificationType userComputerId:(NSString *)userComputerId completionHandler:(void (^)(void))completionHandler {
    NSNumber *createTimestamp = [Utility currentJavaTimeMilliseconds];

//    NSString *sectionName = [Utility dateStringFromDate:[NSDate date]];

//    NSDate *currentDate = [NSDate date];
//
//    NSString *sectionName = [Utility dateStringFromDate:currentDate format:DATE_FORMAT_FOR_FILE_UPLOAD_TABLE_VIEW_SECTION locale:[NSLocale autoupdatingCurrentLocale]];

    [self createFileUploadGroupWithUploadGroupId:uploadGroupId
                                 targetDirectory:targetDirectory
                                subdirectoryType:subdirectoryType
                               subdirectoryValue:subdirectoryValue
                                 descriptionType:descriptionType
                                descriptionValue:descriptionValue
                                notificationType:notificationType
                                 createTimestamp:createTimestamp
                                  userComputerId:userComputerId
                               completionHandler:completionHandler];
}

- (void)createFileUploadGroupWithUploadGroupId:(NSString *)uploadGroupId
                               targetDirectory:(NSString *)targetDirectory
                              subdirectoryType:(NSInteger)subdirectoryType
                             subdirectoryValue:(NSString *)subdirectoryValue
                               descriptionType:(NSInteger)descriptionType
                              descriptionValue:(NSString *)descriptionValue
                              notificationType:(NSInteger)notificationType
                               createTimestamp:(NSNumber *)createTimestamp
                                userComputerId:(NSString *)userComputerId
                             completionHandler:(void (^)(void))completionHandler {
    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlock:^() {
        UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

        if (userComputer) {
            FileUploadGroup *fileUploadGroup = (FileUploadGroup *) [NSEntityDescription insertNewObjectForEntityForName:@"FileUploadGroup" inManagedObjectContext:moc];

            // get current time for millisec and string for date format
            NSDate *currentDate = [NSDate date];

            fileUploadGroup.userComputer = userComputer;
            fileUploadGroup.uploadGroupId = uploadGroupId;
            fileUploadGroup.uploadGroupDirectory = targetDirectory;
            fileUploadGroup.subdirectoryType = @(subdirectoryType);
            fileUploadGroup.subdirectoryName = subdirectoryValue;
            fileUploadGroup.descriptionType = @(descriptionType);
            fileUploadGroup.descriptionValue = descriptionValue;
            fileUploadGroup.notificationType = @(notificationType);
            fileUploadGroup.createTimestamp = createTimestamp;
            fileUploadGroup.createdInDesktopTimestamp = [Utility javaTimeMillisecondsFromDate:currentDate];
            fileUploadGroup.createdInDesktopStatus = FILE_TRANSFER_STATUS_SUCCESS;

            if (completionHandler) {
                [self.coreData saveContext:moc completionHandler:completionHandler];
            } else {
                [self.coreData saveContext:moc];
            }
        }
    }];
}

- (FileUploadGroup *)findFileUploadGroupByUploadGroupId:(NSString *)uploadGroupId managedObjectContext:(NSManagedObjectContext *)managedObjectContext {
    __block FileUploadGroup *fileUploadGroup;

    if (uploadGroupId && [uploadGroupId stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
        [managedObjectContext performBlockAndWait:^(){
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileUploadGroup"];

            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"uploadGroupId == %@", uploadGroupId];
            [request setPredicate:predicate];

            NSError *fetchError;
            NSArray *fileUploadGroups = [managedObjectContext executeFetchRequest:request error:&fetchError];

            if (fetchError) {
                NSLog(@"Error on fetching file upload group by id: %@\n%@", uploadGroupId, [fetchError userInfo]);
            }

            if (fileUploadGroups && [fileUploadGroups count] > 0) {
                fileUploadGroup = fileUploadGroups[0];
            }
        }];
    }

    return fileUploadGroup;
}

- (void)findFileUploadGroupByUploadGroupId:(NSString *)uploadGroupId completionHandler:(void (^)(FileUploadGroup *))completionHandler {
    if (completionHandler) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlock:^() {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"FileUploadGroup"];

            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"uploadGroupId == %@", uploadGroupId];
            [request setPredicate:predicate];

            NSError *fetchError;
            NSArray *fileUploadGroups = [moc executeFetchRequest:request error:&fetchError];

            if (fileUploadGroups && [fileUploadGroups count] > 0) {
                completionHandler(fileUploadGroups[0]);
            } else {
                if (fetchError) {
                    NSLog(@"Error on fetching file upload group by id: %@\n%@", uploadGroupId, [fetchError userInfo]);
                }

                completionHandler(nil);
            }
        }];
    }
}
@end
