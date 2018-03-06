#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

@class PurchaseWithoutManaged;

@interface ProductService : NSObject <SKPaymentTransactionObserver>

@property(nonatomic, assign) NSURLRequestCachePolicy cachePolicy;

@property(nonatomic, assign) NSTimeInterval timeInterval;

// elements of Product
+ (NSMutableArray *)parseJsonAsProductArray:(NSData *)data error:(NSError * __autoreleasing *)error;

// elements of PurchaseWithoutManaged, with pending value 'NO'
+ (NSMutableArray *)parseJsonAsPurchaseArray:(NSData *)data error:(NSError * __autoreleasing *)error;

- (id)initWithCachePolicy:(NSURLRequestCachePolicy)policy timeInterval:(NSTimeInterval)interval;

- (void)findProductsByVendor:(NSString *)vendor session:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler;

- (void)createPurchase:(PurchaseWithoutManaged *)purchase session:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler;

// login-only to the repository to get session id and invoke [self createPurchase: session: completionHandler:],
// in completionHandler:, mark pending of the Purchase to false and finish transaction.
- (void)createPurchase:(PurchaseWithoutManaged *)purchaseWithoutManaged;

- (void)processPendingPurchasesWithSessionId:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler;

- (void)findPurchasesByUser:(NSString *)userId session:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler;
@end
