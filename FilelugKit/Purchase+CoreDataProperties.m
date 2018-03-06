//
//  Purchase+CoreDataProperties.m
//  filelug
//
//  Created by masonhsieh on 28/04/2017.
//
//

#import "Purchase+CoreDataProperties.h"

@implementation Purchase (CoreDataProperties)

+ (NSFetchRequest<Purchase *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"Purchase"];
}

@dynamic pending;
@dynamic productId;
@dynamic purchaseId;
@dynamic purchaseTimestamp;
@dynamic quantity;
@dynamic vendorTransactionId;
@dynamic vendorUserId;
@dynamic user;

@end
