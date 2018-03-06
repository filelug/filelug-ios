#import "PurchaseWithoutManaged.h"


@implementation PurchaseWithoutManaged {

}
- (instancetype)initWithPurchaseId:(NSString *)purchaseId productId:(NSString *)productId userId:(NSString *)userId quantity:(NSNumber *)quantity vendorTransactionId:(NSString *)vendorTransactionId vendorUserId:(NSString *)vendorUserId purchaseTimestamp:(NSDate *)purchaseTimestamp pending:(NSNumber *)pending {
    self = [super init];
    if (self) {
        self.purchaseId = purchaseId;
        self.productId = productId;
        self.userId = userId;
        self.quantity = quantity;
        self.vendorTransactionId = vendorTransactionId;
        self.vendorUserId = vendorUserId;
        self.purchaseTimestamp = purchaseTimestamp;
        self.pending = pending;
    }

    return self;
}

- (PurchaseWithoutManaged *)copy {
    return [[PurchaseWithoutManaged alloc] initWithPurchaseId:self.purchaseId productId:self.productId userId:self.userId quantity:self.quantity vendorTransactionId:self.vendorTransactionId vendorUserId:self.vendorUserId purchaseTimestamp:self.purchaseTimestamp pending:self.pending];
}


@end