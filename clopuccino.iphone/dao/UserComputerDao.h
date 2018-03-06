#import <Foundation/Foundation.h>

@class UserComputerWithoutManaged;
@class UserComputer;
@class NSManagedObjectContext;

NS_ASSUME_NONNULL_BEGIN

@interface UserComputerDao : NSObject

// Find by user id, sort by computerId asc, return elements of UserComputerWithoutManaged
- (NSArray *)findUserComputersForUserId:(NSString *)userId error:(NSError * __autoreleasing *)error;

// Type of NSString for each element in returned array
- (NSArray *)findAllUserComputerIdsWithError:(NSError * __autoreleasing *)error;

- (void)enumerateUserComputerWithEachCompletionHandler:(void (^)(UserComputer *, NSManagedObjectContext *))eachCompletionHandler saveContextAfterFinishedAllCompletionHandler:(BOOL)saveContextAfterFinishedAllCompletionHandler afterFinishedAllCompletionHandler:(void (^)(void))allCompletionHandler;

- (nullable UserComputerWithoutManaged *)findUserComputerForUserComputerId:(NSString *)userComputerId;

- (NSNumber *)findShowHiddenForUserComputerId:(NSString *)userComputerId;

- (nullable NSArray *)userComputersFromFindAvailableComputersResponseData:(NSData *)data error:(NSError * __autoreleasing *)error;

// Must be wrapped under performBlock: or peformBlockAndWait:
// If userComputerId is nil, use default user computer id in the NSUserDefaults
- (nullable UserComputer *)findUserComputerByUserComputerId:(NSString *)userComputerId managedObjectContext:(NSManagedObjectContext *)managedObjectContext;

- (void)updateUserComputerWithUserComputerWithoutManaged:(UserComputerWithoutManaged *)userComputerWithoutManaged completionHandler:(void (^ _Nullable)(NSError *error))completionHandler;

- (void)createOrUpdateUserComputerFromUserComputerWithoutManaged:(UserComputerWithoutManaged *)userComputerWithoutManaged completionHandler:(void (^ _Nullable)(NSError *error))completionHandler;

- (void)deleteUserComputerWithUserComputerId:(NSString *_Nonnull)userComputerId successHandler:(void (^ _Nullable)(void))successHandler errorHandler:(void (^ _Nullable)(NSError *error))errorHandler;

@end

NS_ASSUME_NONNULL_END
