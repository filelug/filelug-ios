#import <Foundation/Foundation.h>
#import <AccountKit/AccountKit.h>

@protocol AccountKitServiceDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface AccountKitService : NSObject

// A random, unpredict string created before invoking account kit login.
// The login will remain the same string as the value in AKFViewControllerDelegate method:
// viewController: didCompleteLoginWithAuthorizationCode: state:
// after login successfully
@property(nonatomic, strong) NSString *accountKitLoginState;

- (instancetype)initWithServiceDelegate:(id <AccountKitServiceDelegate>)serviceDelegate;

- (nullable UIViewController<AKFViewController> *)viewControllerForLoginResume;

- (nullable AKFPhoneNumber *)findPhoneNumberForCurrentUserOrExistingUser;

- (AKFPhoneNumber *)preparePhoneNumberWithCountryCode:(NSNumber *)countryCode phoneNumber:(NSString *)phoneNumber;
//- (nullable AKFPhoneNumber *)preparePhoneNumberWithCountryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber;

// state 應該是隨機、無法猜測的值。透過此參數傳遞的任何值都會傳回登入回應，所以將此值與回應值比較，即可確認所收到的回應是否針對原先所發出的要求
- (void)startCurrentUserLoginProcessWithState:(NSString *)state;

// state 應該是隨機、無法猜測的值。透過此參數傳遞的任何值都會傳回登入回應，所以將此值與回應值比較，即可確認所收到的回應是否針對原先所發出的要求
- (void)startLoginProcessWithState:(NSString *)state countryCode:(nullable NSNumber *)countryCode phoneNumber:(nullable NSString *)phoneNumber;
//- (void)startLoginProcessWithState:(NSString *)state countryId:(nullable NSString *)countryId phoneNumber:(nullable NSString *)phoneNumber;

// The method can only be invoked after the authorization code being verified by tthe server
// (e.g. after the service [authService verifyAuthorizationCode: completionHandler:] invoked successfully)
- (void)requestLoginAccountDataWithHandler:(nonnull void (^)(NSString *_Nullable accountId, AKFPhoneNumber *_Nullable phoneNumber, NSError *_Nullable error))handler;

+ (void)startCurrentUserLoginProcessWithServiceDelegate:(id <AccountKitServiceDelegate>)serviceDelegate;

//- (void)loginAndSynchronizeCountriesWithAuthorizationCode:(NSString *)authorizationCode successHandler:(void (^ _Nullable)(NSURLResponse *, NSData *))successHandler failureHandler:(void (^ _Nullable)(NSURLResponse *, NSData *, NSError *))failureHandler;

@end

NS_ASSUME_NONNULL_END
