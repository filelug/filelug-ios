#import "UserWithoutManaged.h"
#import "UserDao.h"
#import "User+CoreDataClass.h"
#import "ClopuccinoCoreData.h"
#import "Utility.h"

@interface UserDao ()

@property(nonatomic, strong) ClopuccinoCoreData *coreData;

@end

@implementation UserDao {
}

- (id)init {
    self = [super init];
    if (self) {
        _coreData = [ClopuccinoCoreData defaultCoreData];
    }

    return self;
}

- (void)createUserFromUserWithoutManaged:(UserWithoutManaged *)userWithoutManaged {
    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlock:^() {
        User *user = [NSEntityDescription insertNewObjectForEntityForName:@"User" inManagedObjectContext:moc];

        user.userId = userWithoutManaged.userId;
        user.countryId = userWithoutManaged.countryId;
        user.phoneNumber = userWithoutManaged.phoneNumber;
        user.sessionId = userWithoutManaged.sessionId;
        user.nickname = userWithoutManaged.nickname;

        NSString *email = userWithoutManaged.email;

        if (email && [email stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
            user.email = email;
        }

        user.active = userWithoutManaged.active;

        [self.coreData saveContext:moc];
    }];
}

- (void)updateUserFromUserWithoutManaged:(UserWithoutManaged *)userWithoutManaged completionHandler:(void (^)(void))completionHandler {
    if (userWithoutManaged
            && userWithoutManaged.userId
            && userWithoutManaged.countryId
            && userWithoutManaged.phoneNumber
            && userWithoutManaged.active) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlock:^() {
            User *user = [self findUserById:userWithoutManaged.userId managedObjectContext:moc];

            if (user) {
                user.countryId = userWithoutManaged.countryId;
                user.phoneNumber = userWithoutManaged.phoneNumber;
                user.sessionId = userWithoutManaged.sessionId;
                user.nickname = userWithoutManaged.nickname;

                NSString *email = userWithoutManaged.email;

                if (email && [email stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
                    user.email = userWithoutManaged.email;
                }

                user.active = userWithoutManaged.active;

                if (completionHandler) {
                    [self.coreData saveContext:moc completionHandler:completionHandler];
                } else {
                    [self.coreData saveContext:moc];
                }
            }
        }];
    }
}

- (UserWithoutManaged *)findUserWithoutManagedById:(NSString *)userId error:(NSError * __autoreleasing *)error {
    __block UserWithoutManaged *userWithoutManaged;
    __block NSError *findError;

    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"User"];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userId == %@", userId];
    [request setPredicate:predicate];

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlockAndWait:^() {
        NSArray *users = [moc executeFetchRequest:request error:&findError];

        if (users && [users count] > 0) {
            userWithoutManaged = [self userWithoutManagedFromUser:users[0]];
        }
    }];

    if (error && findError) {
        *error = findError;
    }

    return userWithoutManaged;
}

// make sure it is wrapped under performBlock: or performBlockAndWait:
- (UserWithoutManaged *)userWithoutManagedFromUser:(User *)user {
    UserWithoutManaged *userWithoutManaged;

    if (user) {
        userWithoutManaged = [[UserWithoutManaged alloc] initWithUserId:user.userId countryId:user.countryId phoneNumber:user.phoneNumber sessionId:user.sessionId nickname:user.nickname email:user.email active:user.active locale:nil];
    }

    return userWithoutManaged;
}

- (NSArray *)findAllUsersWithSortByActive:(BOOL)activeFirst error:(NSError * __autoreleasing *)error {
    __block NSMutableArray *usersWithoutManaged = [NSMutableArray array];
    __block NSError *findError;

    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"User"];

    if (activeFirst) {
        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"active" ascending:NO];
        [request setSortDescriptors:@[sortDescriptor]];
    }

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlockAndWait:^() {
        NSArray *users = [moc executeFetchRequest:request error:&findError];

        if (users && [users count] > 0) {
            for (User *user in users) {
                [usersWithoutManaged addObject:[self userWithoutManagedFromUser:user]];
            }
        }
    }];

    if (error && findError) {
        *error = findError;
    }

    return usersWithoutManaged;
}

- (UserWithoutManaged *)findActiveUserWithError:(NSError * __autoreleasing *)error {
    __block UserWithoutManaged *userWithoutManaged;
    __block NSError *findError;

    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"User"];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"active == %@", @YES];
    [request setPredicate:predicate];

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlockAndWait:^() {
        NSArray *users = [moc executeFetchRequest:request error:&findError];

        if (users && [users count] > 0) {
            userWithoutManaged = [self userWithoutManagedFromUser:users[0]];
        }
    }];

    if (error && findError) {
        *error = findError;
    }

    return userWithoutManaged;
}


// Must be wrapped under performBlock: or peformBlockAndWait:
// If userId is nil, use default user in the NSUserDefaults
- (User *)findUserById:(NSString *)userId managedObjectContext:(NSManagedObjectContext *)managedObjectContext {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"User"];

    if (!userId) {
        NSLog(@"Use default user");

        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        userId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_ID];
    }

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userId == %@", userId];

    [request setPredicate:predicate];

    NSError *userError;
    NSArray *users = [managedObjectContext executeFetchRequest:request error:&userError];

    if (userError) {
        NSLog(@"Error on finding user: %@\n%@", userId, userError);
    }

    if (users && [users count] > 0) {
        return users[0];
    }

    return nil;
}

- (void)updateNicknameTo:(NSString *)newNickname forUserId:(NSString *)userId {
    if (newNickname && userId) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlock:^() {
            User *user = [self findUserById:userId managedObjectContext:moc];

            if (user) {
                user.nickname = newNickname;

                [self.coreData saveContext:moc];
            }
        }];
    }
}

- (void)updateEmailTo:(NSString *)newEmail forUserId:(NSString *)userId {
    if (newEmail && userId) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlock:^() {
            User *user = [self findUserById:userId managedObjectContext:moc];

            if (user) {
                user.email = newEmail;

                [self.coreData saveContext:moc];
            }
        }];
    }
}

- (void)updateEmail:(NSString *)newEmail nickname:(NSString *)newNickname forUserId:(NSString *)userId {
    if (newEmail && newNickname && userId) {
        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlock:^() {
            User *user = [self findUserById:userId managedObjectContext:moc];

            if (user) {
                user.email = newEmail;
                user.nickname = newNickname;

                [self.coreData saveContext:moc];
            }
        }];
    }
}

- (UserWithoutManaged *)findUserWithoutManagedByCountryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber error:(NSError * __autoreleasing *)error {
    __block UserWithoutManaged *userWithoutManaged;
    __block NSError *findError;

    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"User"];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"countryId == %@ AND phoneNumber == %@", countryId, phoneNumber];
    [request setPredicate:predicate];

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlockAndWait:^() {
        NSArray *users = [moc executeFetchRequest:request error:&findError];

        if (users && [users count] > 0) {
            userWithoutManaged = [self userWithoutManagedFromUser:users[0]];
        }
    }];

    if (error && findError) {
        *error = findError;
    }

    return userWithoutManaged;
}

- (void)createOrUpdateUserWithUserWithoutManaged:(UserWithoutManaged *)userWithoutManaged completionHandler:(void (^)(NSError *))completionHandler {
    if (userWithoutManaged
            && userWithoutManaged.userId
            && userWithoutManaged.countryId
            && userWithoutManaged.phoneNumber
            && userWithoutManaged.active) {
        NSString *userId = userWithoutManaged.userId;
        NSString *countryId = userWithoutManaged.countryId;
        NSString *phoneNumber = userWithoutManaged.phoneNumber;
        NSString *sessionId = userWithoutManaged.sessionId;
        NSString *nickname = userWithoutManaged.nickname;
        NSString *email = userWithoutManaged.email;
        BOOL active = [userWithoutManaged.active boolValue];

        __block BOOL userFound = NO;
        __block NSError *foundError;

        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"User"];

        NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

        [moc performBlock:^() {
            if (active) {
                // update: set other users' active value to NO

                NSArray *users = [moc executeFetchRequest:request error:&foundError];

                if (users && [users count] > 0) {
                    for (User *user in users) {
                        // Sometimes unknown error occurred when processing login successfully data on application just initiated.
                        // So we use try-catch to avoid crash.
                        @try {
                            if ([user.userId isEqualToString:userId]) {
                                userFound = YES;

                                user.countryId = countryId;
                                user.phoneNumber = phoneNumber;
                                user.sessionId = sessionId;
                                user.nickname = nickname;

                                if (email && [email stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
                                    user.email = email;
                                }

                                user.active = @(YES);
                            } else if (!user.active || [user.active boolValue]) {
                                user.active = @(NO);
                            }
                        } @catch (NSException *e) {
                            NSLog(@"Error on updating user.\n%@", e);
                        }
                    }
                }
            } else {
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userId == %@", userId];
                [request setPredicate:predicate];

                [moc performBlockAndWait:^() {
                    NSArray *users = [moc executeFetchRequest:request error:&foundError];

                    if (users && [users count] > 0) {
                        // update
                        User *user = users[0];
                        userFound = YES;

                        user.countryId = countryId;
                        user.phoneNumber = phoneNumber;
                        user.sessionId = sessionId;
                        user.nickname = nickname;

                        if (email && [email stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
                            user.email = email;
                        }

                        user.active = @(NO);
                    }
                }];
            }

            // create
            if (!userFound) {
                // create new user
                User *user = [NSEntityDescription insertNewObjectForEntityForName:@"User" inManagedObjectContext:moc];

                user.userId = userId;
                user.countryId = countryId;
                user.phoneNumber = phoneNumber;
                user.sessionId = sessionId;
                user.nickname = nickname;

                if (email && [email stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
                    user.email = email;
                }

                user.active = @(active);
            }

            if (completionHandler) {
                [self.coreData saveContext:moc completionHandler:^() {
                    completionHandler(foundError);
                }];
            } else {
                [self.coreData saveContext:moc];
            }
        }];
    }
}

- (void)deleteUserByCountryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber completionHandler:(void (^)(NSError *))completionHandler {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"User"];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"countryId == %@ AND phoneNumber == %@", countryId, phoneNumber];
    [request setPredicate:predicate];

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlock:^() {
        NSError *foundError;
        NSArray *users = [moc executeFetchRequest:request error:&foundError];

        if (users && [users count] > 0) {
            [moc deleteObject:users[0]];

            if (completionHandler) {
                [self.coreData saveContext:moc completionHandler:^() {
                    completionHandler(foundError);
                }];
            } else {
                [self.coreData saveContext:moc];
            }
        }
    }];
}

- (void)deleteUserByUserId:(NSString *)userId completionHandler:(void (^)(NSError *))completionHandler {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"User"];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userId == %@", userId];
    [request setPredicate:predicate];

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlock:^() {
        NSError *foundError;
        NSArray *users = [moc executeFetchRequest:request error:&foundError];

        if (users && [users count] > 0) {
            [moc deleteObject:users[0]];

            if (completionHandler) {
                [self.coreData saveContext:moc completionHandler:^() {
                    completionHandler(foundError);
                }];
            } else {
                [self.coreData saveContext:moc];
            }
        }
    }];
}

- (NSNumber *)countAllUsers {
    __block NSNumber *userCount;

    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"User"];

    [request setIncludesSubentities:NO];

    NSManagedObjectContext *moc = [self.coreData managedObjectContextFromThread:[NSThread currentThread]];

    [moc performBlockAndWait:^() {
        NSUInteger count = [moc countForFetchRequest:request error:NULL];

        userCount = (count == NSNotFound) ? @0 : @(count);
    }];

    return userCount;
}
@end
