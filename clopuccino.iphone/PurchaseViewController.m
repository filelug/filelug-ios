#import "PurchaseViewController.h"
#import "ProductViewController.h"
#import "FilelugUtility.h"
#import "AppService.h"

@interface PurchaseViewController ()

@property(nonatomic, strong) UIBarButtonItem *refreshItem;

// Elements of Product
@property(nonatomic, strong) NSArray *products;

// Elements of Product, for temp use.
@property(nonatomic, strong) NSMutableArray *productsToBeValidated;

// Elements of SKProduct
@property(nonatomic, strong) NSArray *skproducts;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) AppService *appService;

@end

@implementation PurchaseViewController

@synthesize processing;

@synthesize progressView;

- (void)viewDidLoad {
    [super viewDidLoad];

    self.processing = @NO;

    [Utility viewController:self useNavigationLargeTitles:YES];

    // right button items
    self.refreshItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(findAndDisplayAllProducts:)];

    self.navigationItem.rightBarButtonItem = self.refreshItem;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self addObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self findAndDisplayAllProducts:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) context:NULL];
    
    if (self.progressView) {
        self.progressView = nil;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (AuthService *)authService {
    if (!_authService) {
        _authService = [[AuthService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];
    }
    
    return _authService;
}

- (AppService *)appService {
    if (!_appService) {
        _appService = [[AppService alloc] init];
    }
    
    return _appService;
}

- (BOOL)isLoading {
    return (self.processing && [self.processing boolValue]);
}

- (void)stopLoading {
    self.processing = @NO;
}

#pragma mark - NSKeyValueObserving

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(processing))]) {
        NSNumber *newValue = change[NSKeyValueChangeNewKey];
        NSNumber *oldValue = change[NSKeyValueChangeOldKey];

        if (![newValue isEqualToNumber:oldValue]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([newValue boolValue]) {
                    [self.tableView setScrollEnabled:NO];

                    if (!self.progressView) {
                        NSString *selectedTabName = [FilelugUtility selectedTabName];

                        MBProgressHUD *progressHUD = [Utility prepareProgressViewWithSuperview:self.view inTabWithTabName:selectedTabName refreshControl:nil];

                        self.progressView = progressHUD;
                    } else {
                        [self.progressView show:YES];
                    }
                } else {
                    [self.tableView setScrollEnabled:YES];

                    if (self.progressView) {
                        [self.progressView hide:YES];
                    }
                }
            });
        }
    }
}

- (void)findAndDisplayAllProducts:(id)sender {
    if ([SKPaymentQueue canMakePayments]) {
        [self internalFindAndDisplayAllProductsWithTryAgainIfFailed:YES];
    } else {
        NSString *message = NSLocalizedString(@"Restricted from accessing the App Store.", @"");

        // alert with delay of 1 sec to prevent method viewDidLoad not finished
        [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:1.0 actionHandler:nil];
    }
}

- (void)internalFindAndDisplayAllProductsWithTryAgainIfFailed:(BOOL)tryAgainIfFailed  {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

        if (sessionId == nil || sessionId.length < 1) {
            [FilelugUtility alertEmptyUserSessionFromViewController:self];
        } else {
            self.processing = @YES;

            ProductService *productService = [[ProductService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];

            [productService findProductsByVendor:@"apple" session:sessionId completionHandler:^(NSData *productResponseData, NSURLResponse *productResponse, NSError *productResponseError) {
                self.processing = @NO;

                NSInteger statusCode = [(NSHTTPURLResponse *) productResponse statusCode];

                if (statusCode == 200) {
                    NSError *parseError;
                    self.productsToBeValidated = [ProductService parseJsonAsProductArray:productResponseData error:&parseError];

                    if (parseError) {
                        NSString *dataContent;

                        if (productResponseData && [productResponseData length] > 0) {
                            dataContent = [[NSString alloc] initWithData:productResponseData encoding:NSUTF8StringEncoding];
                        } else {
                            dataContent = @"";
                        }

                        NSLog(@"Error on parsing json data as product array. JSON data=%@. %@, %@", dataContent, parseError, [parseError userInfo]);
                    } else {
                        self.products = [NSArray arrayWithArray:self.productsToBeValidated];

                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.tableView reloadData];
                        });

                        /* TODO: close the verification until in-app purchase is ready on-line */
                        if (self.products && [self.products count] > 0) {
                            NSMutableSet *productIds = [NSMutableSet set];

                            for (Product *product in self.productsToBeValidated) {
                                [productIds addObject:product.productId];
                            }

                            SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIds];

                            productsRequest.delegate = self;

                            [productsRequest start];
                        }
                    }
                } else if (tryAgainIfFailed && (statusCode == 401 || (productResponseError && ([productResponseError code] == NSURLErrorUserCancelledAuthentication || [productResponseError code] == NSURLErrorSecureConnectionFailed)))) {
                    self.processing = @YES;

                    [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                        // do not care if lug server id is empty

                        [self internalFindAndDisplayAllProductsWithTryAgainIfFailed:NO];
                    } failureHandler:^(NSData *loginData, NSURLResponse *loginResponse, NSError *loginError) {
                        self.processing = @NO;

                        NSInteger loginStatusCode = [(NSHTTPURLResponse *) loginResponse statusCode];
                        NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Login failed. %@ Status:%d", @""), [loginError localizedDescription], loginStatusCode];

                        NSLog(@"%@", message);
                        [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                    }];
                } else {
                    NSString *messagePrefix = NSLocalizedString(@"Error on finding products.", @"");

                    UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
                        [self findAndDisplayAllProducts:nil];
                    }];

                    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:productResponse data:productResponseData error:productResponseError tryAgainAction:tryAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                        [self findAndDisplayAllProducts:nil];
                    }];
                }
            }];
        }
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.products ? [self.products count] : 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PurchaseCell" forIndexPath:indexPath];

    Product *product = (self.products)[(NSUInteger) indexPath.row];

    if (product) {
        UILabel *productNameLabel = (UILabel *) [cell viewWithTag:1];

        [productNameLabel setText:product.productName];

        UILabel *productPriceLabel = (UILabel *) [cell viewWithTag:2];

        [productPriceLabel setText:product.productDisplayedPrice];
    }

    return cell;
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];

    if (selectedIndexPath && [self.products count] > selectedIndexPath.row) {
        ProductViewController *productViewController = [segue destinationViewController];

        Product *selectedProduct = self.products[(NSUInteger) selectedIndexPath.row];

        NSString *productId = selectedProduct.productId;

        productViewController.product = selectedProduct;

        if (self.skproducts && [self.skproducts count] > 0) {
            for (SKProduct *skproduct in self.skproducts) {
                if ([skproduct.productIdentifier isEqualToString:productId]) {
                    productViewController.skproduct = skproduct;

                    break;
                }
            }
        }
    }
}

#pragma mark - SKProductsRequestDelegate protocol

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    @try {
        @autoreleasepool {
            // Elements of valid SKProduct
            self.skproducts = response.products;

            NSMutableArray *tmpProducts = [NSMutableArray array];

            if (self.skproducts && [self.skproducts count] > 0) {
                for (Product *product in self.productsToBeValidated) {
                    NSString *productId = product.productId;

                    for (SKProduct *skProduct in self.skproducts) {
//                        /* DEBUG */
//                        NSLog(@"Valid SKProduct: %@\n%@\n%@\n%@n%@", skProduct.productIdentifier, skProduct.priceLocale.localeIdentifier, skProduct.localizedTitle, skProduct.price, skProduct.localizedDescription);

                        if ([productId isEqualToString:skProduct.productIdentifier]) {
                            [tmpProducts addObject:product];

                            break;
                        }
                    }
                }
            }

            self.products = [NSArray arrayWithArray:tmpProducts];

            for (NSString *invalidIdentifier in response.invalidProductIdentifiers) {
                NSLog(@"Product removed from invalid product id: %@", invalidIdentifier);
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
        }
    } @finally {
        self.productsToBeValidated = nil;
    }
}

@end
