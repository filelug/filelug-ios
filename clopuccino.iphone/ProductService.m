#import "ProductService.h"
#import "Product.h"
#import "PurchaseWithoutManaged.h"
#import "AuthService.h"
#import "Utility.h"
#import "PurchaseDao.h"
#import "UIAlertController+ShowWithoutViewController.h"

@implementation ProductService {
}

+ (NSMutableArray *)parseJsonAsProductArray:(NSData *)data error:(NSError * __autoreleasing *)error {
    NSError *jsonError = nil;
    NSArray *jsonArray = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];

    if (jsonError) {
        if (error) {
            *error = jsonError;
        } else {
            NSLog(@"Failed to parse product data.\n%@", [jsonError userInfo]);
        }

        return nil;
    } else {
        NSMutableArray *products = [[NSMutableArray alloc] init];

        for (NSDictionary *jsonObject in jsonArray) {
            NSString *productId = jsonObject[@"product-id"];
            NSString *productVendor = jsonObject[@"product-vendor"];
            NSString *vendorProductType = jsonObject[@"vendor-product-type"];
            NSNumber *transferBytes = jsonObject[@"transfer-bytes"];
            NSString *displayedTransferCapacity = jsonObject[@"displayed-transfer-capacity"];
            NSNumber *unlimited = jsonObject[@"unlimited"];
            NSString *locale = jsonObject[@"locale"];
            NSString *productName = jsonObject[@"product-name"];
            NSNumber *productPrice = jsonObject[@"product-price"];
            NSString *productDisplayedPrice = jsonObject[@"product-displayed-price"];
            NSString *productDescription = jsonObject[@"product-description"];

            [products addObject:[[Product alloc] initWithProductId:productId productVendor:productVendor vendorProductType:vendorProductType transferBytes:transferBytes displayedTransferCapacity:displayedTransferCapacity unlimited:[unlimited boolValue] locale:locale productName:productName productPrice:productPrice productDisplayedPrice:productDisplayedPrice productDescription:productDescription]];
        }

        return products;
    }
}

+ (NSMutableArray *)parseJsonAsPurchaseArray:(NSData *)data error:(NSError * __autoreleasing *)error {
    NSError *jsonError = nil;
    NSArray *jsonArray = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];

    if (jsonError) {
        if (error) {
            *error = jsonError;
        } else {
            NSLog(@"Failed to parse purchase data.\n%@", [jsonError userInfo]);
        }

        return nil;
    } else {
        NSMutableArray *purchases = [[NSMutableArray alloc] init];

        for (NSDictionary *jsonObject in jsonArray) {
            NSString *purchaseId = jsonObject[@"purchase-id"];
            NSString *productId = jsonObject[@"product-id"];
            NSString *userId = jsonObject[@"user-id"];
            NSNumber *quantity = jsonObject[@"quantity"];
            NSString *vendorTransactionId = jsonObject[@"vendor-transaction-id"];
            NSString *vendorUserId = jsonObject[@"vendor-user-id"];
            NSNumber *purchaseTimestamp = jsonObject[@"purchase-timestamp"];
            NSDate *purchaseDate;
            if (purchaseTimestamp) {
                purchaseDate = [Utility dateFromJavaTimeMilliseconds:purchaseTimestamp];
            }

            [purchases addObject:[[PurchaseWithoutManaged alloc] initWithPurchaseId:purchaseId productId:productId userId:userId quantity:quantity vendorTransactionId:vendorTransactionId vendorUserId:vendorUserId purchaseTimestamp:purchaseDate pending:@NO]];
        }

        return purchases;
    }
}

- (id)initWithCachePolicy:(NSURLRequestCachePolicy)policy timeInterval:(NSTimeInterval)interval {
    if (self = [super init]) {
        _cachePolicy = policy;
        _timeInterval = interval;
    }

    return self;
}

- (void)findProductsByVendor:(NSString *)vendor session:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    NSString *urlString = [Utility composeAAServerURLStringWithPath:@"product/findByVendor"];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
    [request setHTTPMethod:@"POST"];

    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];

    NSString *bodyString = [NSString stringWithFormat:@"{\"vendor\":\"%@\"}", vendor];
    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/json; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];

//    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
//    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:handler];
}

- (void)createPurchase:(PurchaseWithoutManaged *)purchase session:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    NSString *urlString = [Utility composeAAServerURLStringWithPath:@"product/newPurchase"];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
    [request setHTTPMethod:@"POST"];

    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];

    NSNumber *purchaseTimestampInMillis;
    if (purchase.purchaseTimestamp) {
        purchaseTimestampInMillis = [Utility javaTimeMillisecondsFromDate:purchase.purchaseTimestamp];
    } else {
        purchaseTimestampInMillis = [Utility currentJavaTimeMilliseconds];
    }

    // can't ignore purchase id
    NSString *bodyString = [NSString stringWithFormat:@"{\"purchase-id\":\"%@\",\"product-id\":\"%@\",\"user-id\":\"%@\",\"quantity\":%@,\"vendor-transaction-id\":\"%@\",\"vendor-user-id\":\"%@\",\"purchase-timestamp\":%@}", purchase.purchaseId, purchase.productId, purchase.userId, purchase.quantity, purchase.vendorTransactionId, purchase.vendorUserId, purchaseTimestampInMillis];

    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/json; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];

//    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
//    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:handler];
}

# pragma mark - SKPaymentTransactionObserver

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
    if (transactions && [transactions count] > 0) {
        for (SKPaymentTransaction *transaction in transactions) {
            switch (transaction.transactionState) {
                case SKPaymentTransactionStatePurchased:
                    [self completeTransaction:transaction];
                    break;
                case SKPaymentTransactionStateFailed:
                    [self failedTransaction:transaction];
//                    [self promptWithMessage:NSLocalizedString(@"Purchase failure with transaction id: %@. Try again.", @"")];
//
//                    NSLog(@"Purchase Failure:\nPurchase id: %@\nQuantity: %@\nVendor transaction id: %@\nVender user id: %@\nPurchase Date: %@",
//                            [[transaction payment] productIdentifier],
//                            [[transaction payment] quantity],
//                            [transaction transactionIdentifier],
//                            [[transaction payment] applicationUsername],
//                            [transaction transactionDate]);

                    break;
                case SKPaymentTransactionStateRestored:
                    // 如果前一次購買途中中斷 再回復後 會執行這段 restore
//                    [self promptWithMessage:NSLocalizedString(@"Purchase restored", @"")];
                    [self completeTransaction:transaction];

                    break;
                default:
                    break;
            }
        }
    }
}

- (void)failedTransaction:(SKPaymentTransaction *)transaction {
    NSString *vendorTransactionId = [transaction transactionIdentifier];

    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Purchase failure with transaction id: %@. Try again.", @""), vendorTransactionId];
    [self promptWithMessage:message];

    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void)completeTransaction:(SKPaymentTransaction *)transaction {
    /* 1. 本機儲存Purchase並調用repository服務createPurchase。
     *    若createPurchase回傳為200，則更新本機Purchase資料的pending為false。
     *    若不是200，則提示使用者連線並重新執行app。
     *    等待下次執行應用程式時（即寫在[AppDelegate application: didFinishLaunchingWithOptions:]）再執行。
     * 2. 通知finish transaction
     */

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *userId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_ID];

    if (!userId) {
        [self promptWithMessage:NSLocalizedString(@"Connect and reopen application", @"")];
    } else {
        SKPayment *payment = [transaction payment];
        NSString *productId = [payment productIdentifier];
        NSString *purchaseId = [Utility generatePurchaseIdFromProductId:productId userId:userId];
        NSNumber *quantity = @([payment quantity]);
        NSString *vendorTransactionId = [transaction transactionIdentifier];
        NSString *vendorUserId = [payment applicationUsername];
        NSDate *purchaseTimestamp = [transaction transactionDate];
        NSNumber *pending = @YES;

        /* 本機儲存Purchase */
        PurchaseWithoutManaged *purchaseWithoutManaged = [[PurchaseWithoutManaged alloc] initWithPurchaseId:purchaseId productId:productId userId:userId quantity:quantity vendorTransactionId:vendorTransactionId vendorUserId:vendorUserId purchaseTimestamp:purchaseTimestamp pending:pending];

        PurchaseDao *purchaseDao = [[PurchaseDao alloc] init];
        [purchaseDao createPurchaseFromPurchaseWithoutMaanaged:purchaseWithoutManaged];

        /* 調用repository服務createPurchase */
        [self createPurchase:purchaseWithoutManaged];
    }

    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void)createPurchase:(PurchaseWithoutManaged *)purchaseWithoutManaged {
    [self internalCreatePurchase:purchaseWithoutManaged tryAgainIfFailed:YES];
}

- (void)internalCreatePurchase:(PurchaseWithoutManaged *)purchaseWithoutManaged tryAgainIfFailed:(BOOL)tryAgainIfFailed {
    // FIXME: The sessionId should placed as an argument and let the invoker to decide how to deal with when session id is nil

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        AuthService *authService = [[AuthService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];

        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

        if (sessionId && sessionId.length > 0) {
            [self createPurchase:purchaseWithoutManaged session:sessionId completionHandler:^(NSData *productResponseData, NSURLResponse *productResponse, NSError *productResponseError) {
                NSInteger statusCode = [(NSHTTPURLResponse *) productResponse statusCode];

                if (statusCode == 200) {
                    NSLog(@"Purchase: '%@' created successfully.", purchaseWithoutManaged.purchaseId);

                    [self changePendingToFalseForPurchase:purchaseWithoutManaged];
                } else if (tryAgainIfFailed && (statusCode == 401 || (productResponseError && ([productResponseError code] == NSURLErrorUserCancelledAuthentication || [productResponseError code] == NSURLErrorSecureConnectionFailed)))) {
                    [authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                        // do not care if lug server id is empty

                        [self internalCreatePurchase:purchaseWithoutManaged tryAgainIfFailed:NO];
                    } failureHandler:^(NSData *loginData, NSURLResponse *loginResponse, NSError *loginError) {
                        NSInteger loginStatusCode = [(NSHTTPURLResponse *) loginResponse statusCode];
                        NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Login failed. %@ Status:%d", @""), [loginError localizedDescription], loginStatusCode];
                        NSLog(@"%@", message);
                    }];
                } else if (statusCode == 409) {
                    /* purchase already exists. */
                    NSLog(@"Duplicated purchase id: %@", purchaseWithoutManaged.purchaseId);

                    [self changePendingToFalseForPurchase:purchaseWithoutManaged];
                } else {
                    [self promptWithMessage:NSLocalizedString(@"Connect and reopen application", @"")];
                }
            }];
        }
    });
}

// change pending to false
- (void)changePendingToFalseForPurchase:(PurchaseWithoutManaged *)purchaseWithoutManaged {
    PurchaseDao *purchaseDao = [[PurchaseDao alloc] init];

    [purchaseWithoutManaged setPending:@NO];

    [purchaseDao updatePurchase:purchaseWithoutManaged];
}

- (void)promptWithMessage:(NSString *)message {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:message preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"") style:UIAlertActionStyleCancel handler:nil];
    [alertController addAction:okAction];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [alertController presentWithAnimated:YES];
    });
}

- (void)processPendingPurchasesWithSessionId:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    /* find pending purchases and compose as json string */
    NSString *userId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_ID];

    if (userId && [userId stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
        PurchaseDao *purchaseDao = [[PurchaseDao alloc] init];

        NSError *findError;
        NSArray *pendingPurchases = [purchaseDao findPendingPurchasesForUserId:userId error:&findError];

        if (!findError) {
            if (pendingPurchases && [pendingPurchases count] > 0) {
                NSMutableString *body = [NSMutableString stringWithString:@"["];

                for (PurchaseWithoutManaged *purchase in pendingPurchases) {
                    NSNumber *purchaseTimestampInMillis;
                    if (purchase.purchaseTimestamp) {
                        purchaseTimestampInMillis = [Utility javaTimeMillisecondsFromDate:purchase.purchaseTimestamp];
                    } else {
                        purchaseTimestampInMillis = [Utility currentJavaTimeMilliseconds];
                    }

                    [body appendFormat:@"{\"purchase-id\":\"%@\",\"product-id\":\"%@\",\"user-id\":\"%@\",\"quantity\":%@,\"vendor-transaction-id\":\"%@\",\"vendor-user-id\":\"%@\",\"purchase-timestamp\":%@},", purchase.purchaseId, purchase.productId, purchase.userId, purchase.quantity, purchase.vendorTransactionId, purchase.vendorUserId, purchaseTimestampInMillis];
                }

                // remove the last comma ','
                NSInteger bodyLength = [body length];
                NSString *tmpString = [body substringWithRange:NSMakeRange(0, (NSUInteger) [@([@(bodyLength) intValue] - 1) integerValue])];
                NSString *bodyString = [NSString stringWithFormat:@"%@]", tmpString];

                NSString *urlString = [Utility composeAAServerURLStringWithPath:@"product/newMultiplePurchases"];

                NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
                [request setHTTPMethod:@"POST"];

                [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];

                [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
                [request setValue:@"application/json; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
                
                [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
            } else {
                handler(nil, nil, nil);
            }
        } else {
            NSLog(@"Error on finding pending purchases.\n%@", [findError userInfo]);
            handler(nil, nil, findError);
        }
    } else {
        NSLog(@"Empty user id");

        NSMutableDictionary *details = [NSMutableDictionary dictionary];
        [details setValue:@"Empty user id" forKey:NSLocalizedDescriptionKey];
        NSError *emptyUserIdError = [[NSError alloc] initWithDomain:@"world" code:-9999 userInfo:details];

        handler(nil, nil, emptyUserIdError);
    }
}

- (void)findPurchasesByUser:(NSString *)userId session:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    NSString *urlString = [Utility composeAAServerURLStringWithPath:@"product/findPurchasesByUser"];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];
    [request setHTTPMethod:@"POST"];

    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];

    NSString *bodyString = [NSString stringWithFormat:@"{\"user-id\":\"%@\"}", userId];
    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/json; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
}

@end
