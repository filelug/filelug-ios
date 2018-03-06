#import <Foundation/Foundation.h>

@class PurchaseWithoutManaged;

@interface PurchaseDao : NSObject

- (void)createPurchaseFromPurchaseWithoutMaanaged:(PurchaseWithoutManaged *)purchaseWithoutManaged;

- (NSArray *)findPendingPurchasesForUserId:(NSString *)userId error:(NSError * __autoreleasing *)error;

- (void)updatePurchase:(PurchaseWithoutManaged *)purchaseWithoutManaged;

@end
