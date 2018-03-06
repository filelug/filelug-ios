//
//  RecentDirectoryDao.m
//  filelug
//
//  Created by masonhsieh on 13/08/2017.
//
//

#import "RecentDirectoryDao.h"
#import "UserComputerDao.h"
#import "ClopuccinoCoreData.h"
#import "Utility.h"
#import "RecentDirectory+CoreDataClass.h"

@interface RecentDirectoryDao ()

@property(nonatomic, strong) ClopuccinoCoreData *coreData;

@property(nonatomic, strong) UserComputerDao *userComputerDao;

@end

@implementation RecentDirectoryDao

- (id)init {
    self = [super init];
    if (self) {
        _coreData = [ClopuccinoCoreData defaultCoreData];

        _userComputerDao = [[UserComputerDao alloc] init];
    }

    return self;
}

- (NSArray *)recentDirectoriesWithUserComputer:(NSString *)userComputerId error:(NSError **)error {
    __block NSArray *recentDirectories;
    __block NSError *findError;

    if (userComputerId) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlockAndWait:^() {
            UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

            if (userComputer) {
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"RecentDirectory"];

                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@", userComputer];
                [request setPredicate:predicate];

                NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"createdTimestamp" ascending:NO];
                [request setSortDescriptors:@[sortDescriptor]];

                recentDirectories = [moc executeFetchRequest:request error:&findError];
            }
        }];

        if (error && findError) {
            *error = findError;
        }
    }

    return recentDirectories;
}

- (void)createOrUpdateRecentDirectoryWithDirectoryPath:(NSString *)directoryPath directoryRealPath:(NSString *)directoryRealPath completionHandler:(void (^)(void))handler {
    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *userComputerId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

    [moc performBlock:^() {
        UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

        if (userComputer) {
            NSError *findError;
            RecentDirectory *recentDirectory = [self findRecentDirectoryWithUserComputer:userComputer directoryPath:directoryPath managedObjectContext:moc error:&findError];

            if (findError) {
                NSLog(@"Error on finding recent directory with directory path: %@\n%@", directoryPath, [findError userInfo]);
            }

            if (recentDirectory) {
                recentDirectory.directoryRealPath = directoryRealPath;

                // always update the timestamp so the first one shows the latest accessed folder
                recentDirectory.createdTimestamp = [Utility currentJavaTimeMilliseconds];
            } else {
                recentDirectory = [NSEntityDescription insertNewObjectForEntityForName:@"RecentDirectory" inManagedObjectContext:moc];

                recentDirectory.directoryPath = directoryPath;
                recentDirectory.directoryRealPath = directoryRealPath;
                recentDirectory.createdTimestamp = [Utility currentJavaTimeMilliseconds];
                recentDirectory.userComputer = userComputer;
            }

            if (handler) {
                [self.coreData saveContext:moc completionHandler:handler];
            } else {
                [self.coreData saveContext:moc];
            }
        }
    }];
}

- (RecentDirectory *)findRecentDirectoryWithUserComputer:(UserComputer *)userComputer directoryPath:(NSString *)directoryPath managedObjectContext:(NSManagedObjectContext *)moc error:(NSError **)error {
    __block RecentDirectory *recentDirectory;
    __block NSError *findError;

    @autoreleasepool {
        [moc performBlockAndWait:^() {
            if (userComputer) {
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"RecentDirectory"];

                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND directoryPath == %@", userComputer, directoryPath];
                [request setPredicate:predicate];

                NSArray *recentDirectories = [moc executeFetchRequest:request error:&findError];

                if (recentDirectories && [recentDirectories count] > 0) {
                    recentDirectory = recentDirectories[0];
                }
            }
        }];
    }

    if (error && findError) {
        *error = findError;
    }

    return recentDirectory;
}

- (void)deleteRecentDirectoryWithDirectoryPath:(NSString *)directoryPath successHandler:(void (^)(void))handler {
    if (directoryPath) {
        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSString *userComputerId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

        if (userComputerId) {
            @autoreleasepool {
                NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

                [moc performBlock:^() {
                    UserComputer *userComputer = [self.userComputerDao findUserComputerByUserComputerId:userComputerId managedObjectContext:moc];

                    if (userComputer) {
                        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"RecentDirectory"];

                        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userComputer == %@ AND directoryPath == %@", userComputer, directoryPath];
                        [request setPredicate:predicate];

                        NSError *fetchError;
                        NSArray *foundRecentDirectories = [moc executeFetchRequest:request error:&fetchError];

                        if (foundRecentDirectories && [foundRecentDirectories count] > 0) {
                            for (RecentDirectory *recentDirectory in foundRecentDirectories) {
                                [moc deleteObject:recentDirectory];
                            }

                            if (handler) {
                                [self.coreData saveContext:moc completionHandler:handler];
                            } else {
                                [self.coreData saveContext:moc];
                            }
                        }
                    }
                }];
            }
        }
    }
}

@end
