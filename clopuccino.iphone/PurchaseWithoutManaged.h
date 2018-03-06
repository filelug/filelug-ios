@interface PurchaseWithoutManaged : NSObject

@property(nonatomic, strong) NSString *purchaseId;

@property(nonatomic, strong) NSString *productId;

@property(nonatomic, strong) NSString *userId;

@property(nonatomic, strong) NSNumber *quantity;

@property(nonatomic, strong) NSString *vendorTransactionId;

@property(nonatomic, strong) NSString *vendorUserId;

@property(nonatomic, strong) NSDate *purchaseTimestamp;

@property(nonatomic, strong) NSNumber *pending;

- (instancetype)initWithPurchaseId:(NSString *)purchaseId productId:(NSString *)productId userId:(NSString *)userId quantity:(NSNumber *)quantity vendorTransactionId:(NSString *)vendorTransactionId vendorUserId:(NSString *)vendorUserId purchaseTimestamp:(NSDate *)purchaseTimestamp pending:(NSNumber *)pending;

- (PurchaseWithoutManaged *)copy;

@end