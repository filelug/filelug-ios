#import "TopupsHistoryViewController.h"
#import "FilelugUtility.h"
#import "AppService.h"

@interface TopupsHistoryViewController ()

@property(nonatomic, strong) UIBarButtonItem *refreshItem;

// Elements of Product
@property(nonatomic, strong) NSArray *products;

// Elements of PurchaseWithoutManaged
@property(nonatomic, strong) NSMutableArray *purchases;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) AppService *appService;

@end

@implementation TopupsHistoryViewController

@synthesize processing;

@synthesize progressView;

- (void)viewDidLoad {
    [super viewDidLoad];

    self.processing = @NO;

    [Utility viewController:self useNavigationLargeTitles:YES];

    // right button items
    self.refreshItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(findUserPurchases:)];

    self.navigationItem.rightBarButtonItem = self.refreshItem;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self addObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self findUserPurchases:nil];
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
                        // Get the current tab name from MenuTabViewController
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

- (void)findUserPurchases:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self internalFindPurchasesByCurrentUserWithTryAgainIfFailed:YES];
    });
}

- (void)internalFindPurchasesByCurrentUserWithTryAgainIfFailed:(BOOL)tryAgainIfFailed {
//    AuthService *authService = [[AuthService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    if (sessionId == nil || sessionId.length < 1) {
        [FilelugUtility alertEmptyUserSessionFromViewController:self];
//        [FilelugUtility alertUserNeverConnectedWithViewController:self loginSuccessHandler:^(NSURLResponse *response, NSData *data) {
//            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                self.processing = @NO;
//
//                [self internalFindPurchasesByCurrentUserWithTryAgainIfConnectionFailed:tryAgainIfConnectionFailed];
//            });
//        }];
    } else {
        self.processing = @YES;

        ProductService *productService = [[ProductService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];

        [productService findProductsByVendor:@"apple" session:sessionId completionHandler:^(NSData *productResponseData, NSURLResponse *productResponse, NSError *productResponseError) {
            self.processing = @NO;

            NSInteger statusCode = [(NSHTTPURLResponse *) productResponse statusCode];

            if (statusCode == 200) {
                NSError *parseProductError;
                self.products = [ProductService parseJsonAsProductArray:productResponseData error:&parseProductError];

                if (parseProductError) {
                    NSString *dataContent;

                    if (productResponseData && [productResponseData length] > 0) {
                        dataContent = [[NSString alloc] initWithData:productResponseData encoding:NSUTF8StringEncoding];
                    } else {
                        dataContent = @"";
                    }

                    // DEBUG
                    NSLog(@"Error on parsing json data as product array. JSON data=%@. %@, %@", dataContent, parseProductError, [parseProductError userInfo]);
                } else {
                    self.processing = @YES;

                    NSString *userId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_ID];

                    [productService findPurchasesByUser:userId session:sessionId completionHandler:^(NSData *purchaseData, NSURLResponse *purchaseResponse, NSError *purchaseError) {
                        self.processing = @NO;

                        NSInteger purchaseStatusCode = [(NSHTTPURLResponse *) purchaseResponse statusCode];

                        if (purchaseStatusCode == 200) {
                            NSError *parsePurchaseError;
                            self.purchases = [ProductService parseJsonAsPurchaseArray:purchaseData error:&parsePurchaseError];

                            if (parsePurchaseError) {
                                NSString *dataContent;

                                if (purchaseData && [purchaseData length] > 0) {
                                    dataContent = [[NSString alloc] initWithData:purchaseData encoding:NSUTF8StringEncoding];
                                } else {
                                    dataContent = @"";
                                }

                                /* DEBUG */
                                NSLog(@"Error on parsing json data as purchase array. JSON data=%@. %@, %@", dataContent, parsePurchaseError, [parsePurchaseError userInfo]);
                            } else {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [self.tableView reloadData];
                                });
                            }
                        } else {
                            NSString *messagePrefix = @"Error on finding purchase data";
                            
                            [self alertToTryAgainWithMessagePrefix:messagePrefix response:purchaseResponse data:purchaseData error:purchaseError];
                        }
                    }];
                }
            } else if (tryAgainIfFailed && (statusCode == 401 || (productResponseError && ([productResponseError code] == NSURLErrorUserCancelledAuthentication || [productResponseError code] == NSURLErrorSecureConnectionFailed)))) {
                self.processing = @YES;

                [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                    // do not care if lug server id is empty

                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        [self internalFindPurchasesByCurrentUserWithTryAgainIfFailed:NO];
                    });
                } failureHandler:^(NSData *loginData, NSURLResponse *loginResponse, NSError *loginError) {
                    self.processing = @NO;

                    NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                    [self alertToTryAgainWithMessagePrefix:messagePrefix response:productResponse data:productResponseData error:productResponseError];

//                    NSInteger loginStatusCode = [(NSHTTPURLResponse *) loginResponse statusCode];
//                    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Login failed. %@ Status:%d", @""), [loginError localizedDescription], loginStatusCode];
//
//                    NSLog(@"%@", message);
//                    [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                }];
//                [authService reloginOnlyWithNewPassword:nil onNoActiveUserHandler:^() {
//                    [FilelugUtility showConnectionViewControllerFromParent:self];
//                } successHandler:^(NSURLResponse *lresponse, NSData *ldata) {
//                    self.processing = @NO;
//
//                    // do not care if lug server id is empty
//
//                    [self internalFindPurchasesByCurrentUserWithTryAgainIfConnectionFailed:NO];
//                } failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
//                    self.processing = @NO;
//
//                    NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");
//
//                    [self alertToTryAgainWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror];
//                }];
            } else {
                NSString *messagePrefix = NSLocalizedString(@"Error on finding products.", @"");

                [self alertToTryAgainWithMessagePrefix:messagePrefix response:productResponse data:productResponseData error:productResponseError];
            }
        }];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.purchases count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TopupsHistoryCell" forIndexPath:indexPath];

    PurchaseWithoutManaged *purchaseWithoutManaged = (self.purchases)[(NSUInteger) indexPath.row];

    if (purchaseWithoutManaged) {
        NSString *productId = purchaseWithoutManaged.productId;

        NSString *productName;
        if (self.products && [self.products count] > 0) {
            for (Product *product in self.products) {
                if ([product.productId isEqualToString:productId]) {
                    productName = product.productName;

                    break;
                }
            }
        }

        if (!productName) {
            productName = NSLocalizedString(@"Not For Sale Product", @"");
        }

        [cell.textLabel setText:productName];

        NSString *dateString = [Utility dateStringFromDate:purchaseWithoutManaged.purchaseTimestamp];
        [cell.detailTextLabel setText:[NSString stringWithFormat:@"%@:%@, %@", NSLocalizedString(@"quantity", @""), purchaseWithoutManaged.quantity, dateString]];
    }

    return cell;
}

- (void)alertToTryAgainWithMessagePrefix:messagePrefix response:response data:data error:error {
    UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self internalFindPurchasesByCurrentUserWithTryAgainIfFailed:YES];
        });
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self internalFindPurchasesByCurrentUserWithTryAgainIfFailed:NO];
        });
    }];
}

@end
