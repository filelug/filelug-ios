#import "Product.h"


@implementation Product {

}

- (instancetype)initWithProductId:(NSString *)productId productVendor:(NSString *)productVendor vendorProductType:(NSString *)vendorProductType transferBytes:(NSNumber *)transferBytes displayedTransferCapacity:(NSString *)displayedTransferCapacity unlimited:(BOOL)unlimited locale:(NSString *)locale productName:(NSString *)productName productPrice:(NSNumber *)productPrice productDisplayedPrice:(NSString *)productDisplayedPrice productDescription:(NSString *)productDescription {
    self = [super init];
    if (self) {
        self.productId = productId;
        self.productVendor = productVendor;
        self.vendorProductType = vendorProductType;
        self.transferBytes = transferBytes;
        self.displayedTransferCapacity = displayedTransferCapacity;
        self.unlimited = unlimited;
        self.locale = locale;
        self.productName = productName;
        self.productPrice = productPrice;
        self.productDisplayedPrice = productDisplayedPrice;
        self.productDescription = productDescription;
    }

    return self;
}

- (Product *)copy {
    return [[Product alloc] initWithProductId:self.productId productVendor:self.productVendor vendorProductType:self.vendorProductType transferBytes:self.transferBytes displayedTransferCapacity:self.displayedTransferCapacity unlimited:self.unlimited locale:self.locale productName:self.productName productPrice:self.productPrice productDisplayedPrice:self.productDisplayedPrice productDescription:self.productDescription];
}

@end