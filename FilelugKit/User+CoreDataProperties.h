//
//  User+CoreDataProperties.h
//  filelug
//
//  Created by masonhsieh on 28/04/2017.
//
//

#import "User+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface User (CoreDataProperties)

+ (NSFetchRequest<User *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSNumber *active;
@property (nullable, nonatomic, copy) NSString *countryId;
@property (nullable, nonatomic, copy) NSString *email;
@property (nullable, nonatomic, copy) NSString *nickname;
@property (nullable, nonatomic, copy) NSString *phoneNumber;
@property (nullable, nonatomic, copy) NSString *sessionId;
@property (nullable, nonatomic, copy) NSString *userId;
@property (nullable, nonatomic, retain) NSSet<Purchase *> *purchases;
@property (nullable, nonatomic, retain) NSSet<UserComputer *> *userComputers;

@end

@interface User (CoreDataGeneratedAccessors)

- (void)addPurchasesObject:(Purchase *)value;
- (void)removePurchasesObject:(Purchase *)value;
- (void)addPurchases:(NSSet<Purchase *> *)values;
- (void)removePurchases:(NSSet<Purchase *> *)values;

- (void)addUserComputersObject:(UserComputer *)value;
- (void)removeUserComputersObject:(UserComputer *)value;
- (void)addUserComputers:(NSSet<UserComputer *> *)values;
- (void)removeUserComputers:(NSSet<UserComputer *> *)values;

@end

NS_ASSUME_NONNULL_END
