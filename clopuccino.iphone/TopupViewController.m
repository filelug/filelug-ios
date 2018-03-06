#import "TopupViewController.h"
#import "FilelugUtility.h"
#import "AppService.h"

@interface TopupViewController ()

@property(nonatomic, strong) UIBarButtonItem *refreshItem;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) AppService *appService;

@end

@implementation TopupViewController
    
@synthesize processing;
    
@synthesize progressView;

- (void)viewDidLoad {
    [super viewDidLoad];

    self.processing = @NO;

    [Utility viewController:self useNavigationLargeTitles:YES];

    // right button items
    self.refreshItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(calculatingCapacity:)];

    self.navigationItem.rightBarButtonItem = self.refreshItem;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self addObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if ([self isMovingToParentViewController]) {
        [self calculatingCapacity:nil];
    } else {
        // make sure available transmission capacity reloaded after back from ProductViewController
        [self calculatingCapacityOnly];
    }
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

- (void)calculatingCapacity:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self internalCalculatingCapacityWithTryAgainIfFailed:YES];
    });
}

- (void)internalCalculatingCapacityWithTryAgainIfFailed:(BOOL)tryAgainIfFailed {
//    AuthService *authService = [[AuthService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    if (sessionId == nil || sessionId.length < 1) {
        [FilelugUtility alertEmptyUserSessionFromViewController:self];
//        [FilelugUtility alertUserNeverConnectedWithViewController:self loginSuccessHandler:^(NSURLResponse *response, NSData *data) {
//            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                self.processing = @NO;
//
//                [self internalCalculatingCapacityWithTryAgainIfConnectionFailed:tryAgainIfConnectionFailed];
//            });
//        }];
    } else {
        self.processing = @YES;

        ProductService *productService = [[ProductService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];

        [productService processPendingPurchasesWithSessionId:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            self.processing = @NO;

            /* change status pending to NO */
            if (response) {
                NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

                if (statusCode == 200) {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        NSError *purchaseResponseError;
                        NSArray *successPurchases = [ProductService parseJsonAsPurchaseArray:data error:&purchaseResponseError];

                        if (!purchaseResponseError && [successPurchases count] > 0) {
                            PurchaseDao *purchaseDao = [[PurchaseDao alloc] init];

                            for (PurchaseWithoutManaged *purchaseWithoutManaged in successPurchases) {
                                [purchaseWithoutManaged setPending:@NO];

                                [purchaseDao updatePurchase:purchaseWithoutManaged];
                            }
                        }

                        [self findAvailableTransmissionCapacityWithTryAgainIfFailed:YES];
                    });
                } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
                    self.processing = @YES;

                    [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                        // do not care if lug server id is empty

                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            [self internalCalculatingCapacityWithTryAgainIfFailed:NO];
                        });
                    } failureHandler:^(NSData *loginData, NSURLResponse *loginResponse, NSError *loginError) {
                        self.processing = @NO;

                        NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                        [self alertToProcessPendingPurchaseAgainWithMessagePrefix:messagePrefix response:response data:data error:error];
                    }];
//                    [authService reloginOnlyWithNewPassword:nil onNoActiveUserHandler:^() {
//                        [FilelugUtility showConnectionViewControllerFromParent:self];
//                    } successHandler:^(NSURLResponse *lresponse, NSData *ldata) {
//                        self.processing = @NO;
//
//                        // do not care if lug server id is empty
//
//                        [self internalCalculatingCapacityWithTryAgainIfConnectionFailed:NO];
//                    } failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
//                        self.processing = @NO;
//
//                        NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");
//
//                        [self alertToTryAgainWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror];
//                    }];
                } else {
                    NSString *messagePrefix = NSLocalizedString(@"Error on finding available transmission capacity.", @"");

                    [self alertToProcessPendingPurchaseAgainWithMessagePrefix:messagePrefix response:response data:data error:error];
                }
            }
        }];
    }
}


// Only calculate capacity without processing pending purchase
- (void)calculatingCapacityOnly {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    if (sessionId == nil || sessionId.length < 1) {
        [FilelugUtility alertEmptyUserSessionFromViewController:self];
    } else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self findAvailableTransmissionCapacityWithTryAgainIfFailed:YES];
        });
    }
}

//- (void)internalCalculatingCapacityOnly {
//    NSUserDefaults *userDefaults = [Utility groupUserDefaults];
//
//    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];
//
//    if (sessionId == nil || sessionId.length < 1) {
//        [FilelugUtility alertEmptyUserSessionFromViewController:self];
////        [FilelugUtility alertUserNeverConnectedWithViewController:self loginSuccessHandler:^(NSURLResponse *response, NSData *data) {
////            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
////                self.processing = @NO;
////
////                [self internalCalculatingCapacityOnly];
////            });
////        }];
//    } else {
//        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//            [self findAvailableTransmissionCapacityWithTryAgainIfFailed:YES];
//        });
//    }
//}

- (void)findAvailableTransmissionCapacityWithTryAgainIfFailed:(BOOL)tryAgainIfFailed {
    self.processing = @YES;

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    [self.authService findAvailableTransmissionCapacityWithSession:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        self.processing = @NO;

        NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

        if (statusCode == 200) {
            NSString *dataContent = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

            if ([dataContent isEqualToString:@"0"] || [dataContent longLongValue] > 0) {
                // e.g. 2048 MB (2147483648 bytes)
                NSString *capacityString = [NSString stringWithFormat:@"%@ (%@ bytes)", [Utility byteCountToDisplaySize:[dataContent longLongValue]], dataContent];

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.capacityLabel setText:capacityString];

                    [self.tableView reloadData];
                });
            } else {
                NSString *message =  NSLocalizedString(@"Can't find available transmission capacity", @"");

                [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"Try Later", @"") delayInSeconds:0 actionHandler:nil];
            }
        } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
            self.processing = @YES;

            [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                // do not care if lug server id is empty

                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [self findAvailableTransmissionCapacityWithTryAgainIfFailed:NO];
                });
            } failureHandler:^(NSData *loginData, NSURLResponse *loginResponse, NSError *loginError) {
                self.processing = @NO;

                NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                [self alertToFindAvailableTransmissionCapacityAgainWithMessagePrefix:messagePrefix response:response data:data error:error];
            }];
//            [authService reloginOnlyWithNewPassword:nil onNoActiveUserHandler:^() {
//                [FilelugUtility showConnectionViewControllerFromParent:self];
//            } successHandler:^(NSURLResponse *lresponse, NSData *ldata) {
//                self.processing = @NO;
//
//                /* do not care if lug server id is empty */
//
//                [self findAvailableTransmissionCapacityWith:authService userDefaults:userDefaults tryAgainIfConnectionFailed:NO];
//            } failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
//                self.processing = @NO;
//
//                NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");
//
//                [self alertToTryAgainWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror];
//            }];
        } else {
            NSString *messagePrefix = NSLocalizedString(@"Error on finding available transmission capacity.", @"");

            [self alertToFindAvailableTransmissionCapacityAgainWithMessagePrefix:messagePrefix response:response data:data error:error];
        }
    }];
}

- (void)alertToProcessPendingPurchaseAgainWithMessagePrefix:messagePrefix response:response data:data error:error {
    UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self internalCalculatingCapacityWithTryAgainIfFailed:YES];
        });
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self internalCalculatingCapacityWithTryAgainIfFailed:NO];
        });
    }];
}

- (void)alertToFindAvailableTransmissionCapacityAgainWithMessagePrefix:messagePrefix response:response data:data error:error {
    UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self findAvailableTransmissionCapacityWithTryAgainIfFailed:YES];
        });
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self findAvailableTransmissionCapacityWithTryAgainIfFailed:NO];
        });
    }];
}

@end
