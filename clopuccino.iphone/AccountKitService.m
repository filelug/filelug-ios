#import <AccountKit/AccountKit.h>
#import "AccountKitService.h"
#import "AccountKitServiceDelegate.h"

@interface AccountKitService () <AKFViewControllerDelegate>

@property(nonatomic, strong) UserDao *userDao;

@property(nonatomic, strong) AKFAccountKit *accountKit;

@property(nonatomic, strong) id <AKFViewControllerDelegate> akfDelegate;

@property(nonatomic, strong) id<AccountKitServiceDelegate> serviceDelegate;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) CountryService *countryService;

@property (nonatomic, strong) UIWindow *baseWindow;

@end

@implementation AccountKitService {
}

//- (void)setBaseWindow:(UIWindow *)baseWindow {
//    objc_setAssociatedObject(self, @selector(baseWindow), baseWindow, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
//}
//
//- (UIWindow *)baseWindow {
//    return objc_getAssociatedObject(self, @selector(baseWindow));
//}

- (instancetype)initWithServiceDelegate:(id <AccountKitServiceDelegate>)serviceDelegate {
    self = [super init];

    if (self) {
//        // make it only one instance of AKFAccountKit
//        if (!_accountKit) {
//            _accountKit = [[AKFAccountKit alloc] initWithResponseType:AKFResponseTypeAuthorizationCode];
//
//            _akfDelegate = self;
//        }

        _accountKit = [[AKFAccountKit alloc] initWithResponseType:AKFResponseTypeAuthorizationCode];

        _akfDelegate = self;

        _serviceDelegate = serviceDelegate;
    }

    return self;
}
//- (instancetype)initWithServiceDelegate:(id <AccountKitServiceDelegate>)serviceDelegate {
//    self = [super init];
//
//    if (self) {
//        _accountKit = [[AKFAccountKit alloc] initWithResponseType:AKFResponseTypeAuthorizationCode];
//
//        _akfDelegate = self;
//
//        _serviceDelegate = serviceDelegate;
//    }
//
//    return self;
//}

- (nullable UIViewController<AKFViewController> *)viewControllerForLoginResume {
    UIViewController<AKFViewController> *viewController = [_accountKit viewControllerForLoginResume];

    [self prepareLoginViewController:viewController];

    return viewController;
}

- (void)dealloc {
    // make sure that the window destroyed

    if (self.baseWindow) {
        self.baseWindow.hidden = YES;
        [self.baseWindow removeFromSuperview];
        self.baseWindow = nil;
    }
}

- (UserDao *)userDao {
    if (!_userDao) {
        _userDao = [[UserDao alloc] init];
    }

    return _userDao;
}

- (AuthService *)authService {
    if (!_authService) {
        _authService = [[AuthService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];
    }

    return _authService;
}

- (CountryService *)countryService {
    if (!_countryService) {
        _countryService = [[CountryService alloc] init];
    }

    return _countryService;
}

- (void)prepareLoginViewController:(UIViewController<AKFViewController> *)loginViewController {
    loginViewController.delegate = self.akfDelegate;

    // Optionally, you may use the Advanced UI Manager or set a theme to customize the UI.

    AKFTheme *theme = [AKFTheme themeWithPrimaryColor:[UIColor aquaColor]
                                   primaryTextColor:[UIColor whiteColor]
                                     secondaryColor:[UIColor colorWithRed:(CGFloat) (221 / 255.0) green:(CGFloat) (239 / 255.0) blue:(CGFloat) (250 / 255.0) alpha:1] // 221,239,250
                                 secondaryTextColor:[UIColor darkGrayColor]
                                     statusBarStyle:UIStatusBarStyleDefault];

    loginViewController.theme = theme;
}

- (nullable AKFPhoneNumber *)findPhoneNumberForCurrentUserOrExistingUser {
    AKFPhoneNumber *countryCodeAndPhoneNumber;

    NSUserDefaults* userDefaults = [Utility groupUserDefaults];

    NSNumber *countryCode = [userDefaults objectForKey:USER_DEFAULTS_KEY_COUNTRY_CODE];

    NSString *phoneNumber = [userDefaults objectForKey:USER_DEFAULTS_KEY_PHONE_NUMBER];

    if (countryCode && phoneNumber) {
        NSString *phoneNumberWithoutZeroPrefix;

        if ([phoneNumber hasPrefix:@"0"]) {
            phoneNumberWithoutZeroPrefix = [phoneNumber substringFromIndex:1];
        } else {
            phoneNumberWithoutZeroPrefix = phoneNumber;
        }

        countryCodeAndPhoneNumber = [[AKFPhoneNumber alloc] initWithCountryCode:[countryCode stringValue] phoneNumber:phoneNumberWithoutZeroPrefix];
    }

    return countryCodeAndPhoneNumber;
}

- (AKFPhoneNumber *)preparePhoneNumberWithCountryCode:(NSNumber *)countryCode phoneNumber:(NSString *)phoneNumber {
    AKFPhoneNumber *countryCodeAndPhoneNumber;

    NSString *phoneNumberWithoutZeroPrefix;

    if ([phoneNumber hasPrefix:@"0"]) {
        phoneNumberWithoutZeroPrefix = [phoneNumber substringFromIndex:1];
    } else {
        phoneNumberWithoutZeroPrefix = phoneNumber;
    }

    countryCodeAndPhoneNumber = [[AKFPhoneNumber alloc] initWithCountryCode:[countryCode stringValue] phoneNumber:phoneNumberWithoutZeroPrefix];

    return countryCodeAndPhoneNumber;
}

- (void)startCurrentUserLoginProcessWithState:(NSString *)state {
    // first get current country code and phone number

    AKFPhoneNumber *preFillPhoneNumber = [self findPhoneNumberForCurrentUserOrExistingUser];

    self.accountKitLoginState = [state copy];

    UIViewController<AKFViewController> *accountKitViewController = [_accountKit viewControllerForPhoneLoginWithPhoneNumber:preFillPhoneNumber state:state];

    [self prepareLoginViewController:accountKitViewController];

    // 如果將此旗幟設為 YES，當簡訊傳送失敗，且所輸入的電話號碼是 Facebook 帳號的主要電話號碼時，用戶可選擇是否透過 Facebook 推播通知來接收登入確認訊息。此旗幟預設為 NO
    accountKitViewController.enableSendToFacebook = YES;

    [self presentAccountKitViewController:accountKitViewController animated:YES compltion:nil];
}

- (void)presentAccountKitViewController:(nonnull UIViewController<AKFViewController> *)accountKitViewController animated:(BOOL)animated compltion:(void (^ _Nullable)(void))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setBaseWindow:[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]]];

        self.baseWindow.rootViewController = [[UIViewController alloc] init];
        self.baseWindow.windowLevel = UIWindowLevelNormal;
        [self.baseWindow makeKeyAndVisible];

        [self.baseWindow.rootViewController presentViewController:accountKitViewController animated:animated completion:completion];
    });
}

- (void)startLoginProcessWithState:(NSString *)state countryCode:(nullable NSNumber *)countryCode phoneNumber:(nullable NSString *)phoneNumber {
    AKFPhoneNumber *preFillPhoneNumber;

    if (countryCode && phoneNumber) {
        preFillPhoneNumber = [self preparePhoneNumberWithCountryCode:countryCode phoneNumber:phoneNumber];
    }

    self.accountKitLoginState = [state copy];

    UIViewController<AKFViewController> *accountKitViewController = [_accountKit viewControllerForPhoneLoginWithPhoneNumber:preFillPhoneNumber state:state];

    [self prepareLoginViewController:accountKitViewController];

    // 如果將此旗幟設為 YES，當簡訊傳送失敗，且所輸入的電話號碼是 Facebook 帳號的主要電話號碼時，用戶可選擇是否透過 Facebook 推播通知來接收登入確認訊息。此旗幟預設為 NO
    accountKitViewController.enableSendToFacebook = YES;

    [self presentAccountKitViewController:accountKitViewController animated:YES compltion:nil];
}

- (void)requestLoginAccountDataWithHandler:(nonnull void (^)(NSString *_Nullable accountId, AKFPhoneNumber *_Nullable phoneNumber, NSError *_Nullable error))handler {
    [self.accountKit requestAccount:^(id <AKFAccount> account, NSError *error) {
        if (error || !account) {
            handler(nil, nil, error);
        } else {
            handler(account.accountID, account.phoneNumber, nil);
        }
    }];
}

+ (void)startCurrentUserLoginProcessWithServiceDelegate:(id <AccountKitServiceDelegate>)serviceDelegate {
    AccountKitService *accountKitService = [[AccountKitService alloc] initWithServiceDelegate:serviceDelegate];

    NSString *inputState = [[NSUUID UUID] UUIDString];

    [accountKitService startCurrentUserLoginProcessWithState:inputState];
}

#pragma mark - AKFViewControllerDelegate

- (void)viewController:(UIViewController<AKFViewController> *)viewController didCompleteLoginWithAuthorizationCode:(NSString *)code state:(NSString *)state {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.baseWindow setHidden:YES];
        [self.baseWindow removeFromSuperview];
    });

    if (state && [state isEqualToString:self.accountKitLoginState]) {
        // invoke server service register, send authorization code

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self.authService exchangeAccessTokenWithAuthorizationCode:code successHandler:^(NSString *countryId, NSString *phoneNumber) {
                if (self.serviceDelegate && [self.serviceDelegate respondsToSelector:@selector(accountKitService:didSuccessfullyGetCountryId:phoneNumber:authorizationCode:state:)]) {
                    [self.serviceDelegate accountKitService:self didSuccessfullyGetCountryId:countryId phoneNumber:phoneNumber authorizationCode:code state:state];
                }
            } failureHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                if (self.serviceDelegate && [self.serviceDelegate respondsToSelector:@selector(accountKitService:didFailedGetCountryIdAndPhoneNumberWithResponse:data:error:authorizationCode:state:)]) {
                    [self.serviceDelegate accountKitService:self didFailedGetCountryIdAndPhoneNumberWithResponse:response data:data error:error authorizationCode:code state:state];
                }
            }];
        });
    } else {
        NSLog(@"login state not the same. Retry again");
    }
}

- (void)viewController:(UIViewController<AKFViewController> *)viewController didFailWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.baseWindow setHidden:YES];
        [self.baseWindow removeFromSuperview];
    });

    if (self.serviceDelegate && [self.serviceDelegate respondsToSelector:@selector(accountKitService:didFailWithError:)]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self.serviceDelegate accountKitService:self didFailWithError:error];
        });
    }
}

- (void)viewControllerDidCancel:(UIViewController<AKFViewController> *)viewController {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.baseWindow setHidden:YES];
        [self.baseWindow removeFromSuperview];
    });

    if (self.serviceDelegate && [self.serviceDelegate respondsToSelector:@selector(accountKitServiceDidCanceled:)]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self.serviceDelegate accountKitServiceDidCanceled:self];
        });
    }
}

@end
