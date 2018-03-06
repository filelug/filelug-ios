#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class User;
@class UserWithoutManaged;

@interface UserDao : NSObject

- (void)createUserFromUserWithoutManaged:(UserWithoutManaged *)userWithoutManaged;

- (void)updateUserFromUserWithoutManaged:(UserWithoutManaged *)userWithoutManaged completionHandler:(void (^)(void))completionHandler;

- (UserWithoutManaged *)findUserWithoutManagedById:(NSString *)userId error:(NSError * __autoreleasing *)error;

// elements of UserWithoutManaged
- (NSArray *)findAllUsersWithSortByActive:(BOOL)activeFirst error:(NSError * __autoreleasing *)error;

- (UserWithoutManaged *)findActiveUserWithError:(NSError * __autoreleasing *)error;

// Must be wrapped under performBlock: or peformBlockAndWait:
// If userId is nil, use default user in the NSUserDefaults
- (User *)findUserById:(NSString *)userId managedObjectContext:(NSManagedObjectContext *)managedObjectContext;

- (void)updateNicknameTo:(NSString *)newNickname forUserId:(NSString *)userId;

- (void)updateEmailTo:(NSString *)newEmail forUserId:(NSString *)userId;

- (void)updateEmail:(NSString *)newEmail nickname:(NSString *)newNickname forUserId:(NSString *)userId;

- (UserWithoutManaged *)findUserWithoutManagedByCountryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber error:(NSError * __autoreleasing *)error;

- (void)createOrUpdateUserWithUserWithoutManaged:(UserWithoutManaged *)userWithoutManaged completionHandler:(void (^)(NSError *))completionHandler;

// delete user and the related data in other tables will be delted because of the cascade delete rule
- (void)deleteUserByCountryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber completionHandler:(void (^)(NSError *))completionHandler;

// delete user and the related data in other tables will be delted because of the cascade delete rule
- (void)deleteUserByUserId:(NSString *)userId completionHandler:(void (^)(NSError *))completionHandler;

// return NSNumber wrapped NSUInteger. If not found, return @(0)
- (NSNumber *)countAllUsers;
@end
