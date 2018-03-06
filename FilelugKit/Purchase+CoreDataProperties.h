//
//  Purchase+CoreDataProperties.h
//  filelug
//
//  Created by masonhsieh on 28/04/2017.
//
//

#import "Purchase+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface Purchase (CoreDataProperties)

+ (NSFetchRequest<Purchase *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSNumber *pending;
@property (nullable, nonatomic, copy) NSString *productId;
@property (nullable, nonatomic, copy) NSString *purchaseId;
@property (nullable, nonatomic, copy) NSDate *purchaseTimestamp;
@property (nullable, nonatomic, copy) NSNumber *quantity;
@property (nullable, nonatomic, copy) NSString *vendorTransactionId;
@property (nullable, nonatomic, copy) NSString *vendorUserId;
@property (nullable, nonatomic, retain) User *user;

@end

NS_ASSUME_NONNULL_END
