#import <Foundation/Foundation.h>


@protocol AccountKitServiceDelegate <NSObject>

@optional

- (void)accountKitService:(AccountKitService *)accountKitService didSuccessfullyGetCountryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber authorizationCode:(NSString *)authorizationCode state:(NSString *)state;

- (void)accountKitService:(AccountKitService *)accountKitService didFailedGetCountryIdAndPhoneNumberWithResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error authorizationCode:(NSString *)authorizationCode state:(NSString *)state;

- (void)accountKitService:(AccountKitService *)accountKitService didFailWithError:(NSError *)error;

- (void)accountKitServiceDidCanceled:(AccountKitService *)accountKitService;

//// Invoked only on all 3 criteria meet:
//// 1. after facebook account kit login successfully.
//// 2. login to the server successfully.
//// 3. The value of USER_DEFAULTS_KEY_NEED_CREATE_OR_UPDATE_USER_PROFILE is @YES after login to the server successfully.
//- (void)userDidLoginSuccessfullyWithResponse:(NSURLResponse *)response responseData:(NSData *)responseData authorizationCode:(NSString *)authorizationCode state:(NSString *)state needCreateOrUpdateUserProfile:(NSNumber *)needCreateOrUpdateUserProfile;
//
//// Invoked after facebook account kit login successfully but failed to login to the server.
//- (void)userDidLoginFailedWithResponse:(NSURLResponse *)response responseData:(NSData *)responseData error:(NSError *)responseError authorizationCode:(NSString *)authorizationCode state:(NSString *)state;
//
//// Invoked after failed to do facebook account login
//- (void)accountKitDidLoginFailedWithError:(NSError *)responseError;
//
//// Invoked after user canceled facebook account login process.
//- (void)accountKitLoginDidCanceled;

@end
