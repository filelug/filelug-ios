#import <Foundation/Foundation.h>


@interface Product : NSObject

@property(nonatomic, strong) NSString *productId;
@property(nonatomic, strong) NSString *productVendor;
@property(nonatomic, strong) NSString *vendorProductType;
@property(nonatomic, strong) NSNumber *transferBytes;
@property(nonatomic, strong) NSString *displayedTransferCapacity;
@property(nonatomic, assign) BOOL unlimited;
@property(nonatomic, strong) NSString *locale;
@property(nonatomic, strong) NSString *productName;
@property(nonatomic, strong) NSNumber *productPrice;
@property(nonatomic, strong) NSString *productDisplayedPrice;
@property(nonatomic, strong) NSString *productDescription;

- (instancetype)initWithProductId:(NSString *)productId productVendor:(NSString *)productVendor vendorProductType:(NSString *)vendorProductType transferBytes:(NSNumber *)transferBytes displayedTransferCapacity:(NSString *)displayedTransferCapacity unlimited:(BOOL)unlimited locale:(NSString *)locale productName:(NSString *)productName productPrice:(NSNumber *)productPrice productDisplayedPrice:(NSString *)productDisplayedPrice productDescription:(NSString *)productDescription;

- (Product *)copy;

@end