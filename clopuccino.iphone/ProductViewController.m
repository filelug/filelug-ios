#import <StoreKit/StoreKit.h>
#import "ProductViewController.h"

// TODO: Supporting dynamic style and dynamic height of UITableViewCell
@interface ProductViewController ()

@property(nonatomic, weak) IBOutlet UILabel *productNameLabel;

@property(nonatomic, weak) IBOutlet UILabel *productDisplayedPriceLabel;

@property(nonatomic, weak) IBOutlet UILabel *productDescriptionLabel;

- (IBAction)buyProduct:(id)sender;

@end

@implementation ProductViewController


- (void)viewDidLoad {
    [super viewDidLoad];

    [Utility viewController:self useNavigationLargeTitles:YES];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (self.product) {
        [self.productNameLabel setText:self.product.productName];
        [self.productDisplayedPriceLabel setText:self.product.productDisplayedPrice];
        [self.productDescriptionLabel setText:self.product.productDescription];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (IBAction)buyProduct:(id)sender {
    if (self.product) {
        NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Confirm to buy:%@", @""), self.productNameLabel.text];
        
        [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"YES", @"") containsCancelAction:YES delayInSeconds:0 actionHandler:^(UIAlertAction * _Nonnull action) {
            // go into in-app purchase process
            if (!self.skproduct) {
                [Utility viewController:self alertWithMessageTitle:@"" messageBody:NSLocalizedString(@"Product is off the shelf", @"") actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
            } else {
                NSUserDefaults *userDefaults = [Utility groupUserDefaults];
                
                NSString *userId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_ID];
                NSString *vendorUserId = [Utility encryptUserId:userId];
                
                SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:self.skproduct];
                payment.quantity = 1;
                payment.applicationUsername = vendorUserId;
                
                [[SKPaymentQueue defaultQueue] addPayment:payment];
            }
        }];
    }
}

@end
