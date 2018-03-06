#import <Foundation/Foundation.h>

@class UserDao;
@class UserWithoutManaged;
@class UserComputerDao;

NS_ASSUME_NONNULL_BEGIN

@interface AuthService : NSObject

@property(nonatomic, assign) NSURLRequestCachePolicy cachePolicy;

@property(nonatomic, assign) NSTimeInterval timeInterval;

@property(nonatomic, strong) UserDao *userDao;

@property(nonatomic, strong) UserComputerDao *userComputerDao;

+ (NSString *)prepareFailedConnectToComputerMessageWithResponse:(NSURLResponse *)response error:(NSError *)error data:(NSData *)data;

+ (NSString *)prepareFailedLoginMessageWithResponse:(NSURLResponse *)response error:(NSError *)error data:(NSData *)data;

- (id)initWithCachePolicy:(NSURLRequestCachePolicy)policy timeInterval:(NSTimeInterval)interval;

// Request new connection between repository and server
- (void)requestConnectWithSession:(NSString *)sessionId successHandler:(void (^ _Nullable)(NSURLResponse *, NSData *))successHandler failureHandler:(void (^ _Nullable)(NSData *, NSURLResponse *, NSError *))failureHandler;

// login with the specified user
// The method use the specified user's current session id to get a new session id and login from server.
// The returned session id is different from the current one.
- (void)loginWithUserWithoutManaged:(UserWithoutManaged *)userWithoutManaged successHandler:(void (^)(NSURLResponse *, NSData *))successHandler failureHandler:(void (^)(NSData *, NSURLResponse *, NSError *))failureHandler;

// login with current session id
// The method use the current user's session id to get a new session id and login from server.
// The returned session id is different from the current one.
- (void)reloginWithSuccessHandler:(void (^ _Nullable)(NSURLResponse *, NSData *))successHandler failureHandler:(void (^ _Nullable)(NSData *, NSURLResponse *, NSError *))failureHandler;

// Add or update demo account in local db and get latest session from server
- (void)createOrUpdateDemoAccountWithSuccessHandler:(void (^ _Nullable)(NSURLResponse *, NSData *))successHandler failureHandler:(void (^ _Nullable)(NSData *_Nullable , NSURLResponse *_Nullable , NSError *_Nullable ))failureHandler;

// login but not check if computer exists nor check if computer connected. The computer group, name can be a fake one.
//- (void)loginOnlyWithDomainURLScheme:(NSString *)domainURLScheme domainName:(NSString *)domainName port:(NSInteger)port contextPath:(NSString *)contextPath userId:(NSString *)userId password:(NSString *)password nickname:(NSString *)nickname successHandler:(void (^ _Nullable)(NSURLResponse *, NSData *))successHandler failureHandler:(void (^ _Nullable)(NSData *, NSURLResponse *, NSError *))failureHandler;

// When invoked because of invoking other services and response code == 503, set connectionNotFound to YES; otherwise set connectionNotFound to NO.
//- (void)loginWithDomainURLScheme:(NSString *)domainURLScheme domainName:(NSString *)domainName port:(NSInteger)port contextPath:(NSString *)contextPath userId:(NSString *)userId password:(NSString *)password nickname:(NSString *)nickname showHidden:(BOOL)showHidden computerId:(NSNumber *)computerId successHandler:(void (^ _Nullable)(NSURLResponse *, NSData *))successHandler failureHandler:(void (^ _Nullable)(NSURLResponse *, NSData *, NSError *))failureHandler;

- (void)processCommonRequestFailuresWithMessagePrefix:(nullable NSString *)messagePrefix response:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error tryAgainAction:(UIAlertAction *)tryAgainAction inViewController:(UIViewController *)viewController reloginSuccessHandler:(void (^)(NSURLResponse *, NSData *))reloginSuccessHandler;

//- (void)saveLoginData:(NSData *)data encryptedPassword:(NSString *)encryptedPassword showHidden:(NSNumber *)showHidden error:(NSError * __autoreleasing *_Nullable)error;

//- (void)saveLoginOnlyData:(NSData *)data encryptedPassword:(NSString *)encryptedPassword error:(NSError * __autoreleasing *_Nullable)error;

- (void)saveRequestConnectData:(NSData *)data error:(NSError * __autoreleasing *_Nullable)error;

- (void)findAvailableTransmissionCapacityWithSession:(NSString *)sessionId completionHandler:(void (^ _Nullable)(NSData *data, NSURLResponse *response, NSError *error))handler;

- (void)changeNickname:(NSString *)newNickname session:(NSString *)sessionId completionHandler:(void (^ _Nullable)(NSData *, NSURLResponse *, NSError *))handler;

- (void)changeEmailWithSession:(NSString *)sessionId newEmail:(NSString *)newEmail encryptedSecurityCode:(NSString *)encryptedSecurityCode completionHandler:(void (^ _Nullable)(NSData *, NSURLResponse *, NSError *))handler;

- (void)deleteUserWithSession:(NSString *)sessionId userId:(NSString *)userId completionHandler:(void (^ _Nullable)(NSData *, NSURLResponse *, NSError *))handler;

- (void)sendChangeEmailCodeWithSession:(NSString *)sessionId newEmail:(NSString *)newEmail completionHandler:(void (^ _Nullable)(NSData *, NSURLResponse *, NSError *))handler;

- (void)checkIfUserDeletableWithSession:(NSString *)sessionId userId:(NSString *)userId completionHandler:(void (^ _Nullable)(NSData *, NSURLResponse *, NSError *))handler;

- (void)updateAllUsersWithDeviceToken:(NSString *)deviceToken session:(NSString *)sessionId completionHandler:(void (^ _Nullable)(NSData *data, NSURLResponse *response, NSError *connectionError))handler;

- (void)incrementBadgeNumber:(NSInteger)incrementBadgeNumber withSession:(NSString *)sessionId deviceToken:(NSString *)deviceToken userId:(NSString *)userId completionHandler:(void (^ _Nullable)(NSData *data, NSURLResponse *response, NSError *connectionError))handler;

- (void)clearBadgeNumberWithSession:(NSString *)sessionId deviceToken:(NSString *)deviceToken userId:(NSString *)userId completionHandler:(void (^ _Nullable)(NSData *data, NSURLResponse *response, NSError *connectionError))handler;

- (void)exchangeAccessTokenWithAuthorizationCode:(NSString *)authorizationCode successHandler:(void (^)(NSString *countryId, NSString *phoneNumber))successHandler failureHandler:(void (^)(NSURLResponse *, NSData *, NSError *))failureHandler;

- (void)loginWithAuthorizationCode:(NSString *)code successHandler:(void (^)(NSURLResponse *, NSData *))successHandler failureHandler:(void (^)(NSURLResponse *, NSData *, NSError *))failureHandler;

- (void)createOrUpdateUserProfileWithEmail:(NSString *)email nickname:(NSString *)nickname session:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler;

- (void)checkNoRunningFileTransfersWithActionDisplayName:(NSString *)actionDisplayName inViewController:(UIViewController *)viewController completedHandler:(void(^)(void))handler;

- (void)findUnfinishedFileTransferForUserComputer:(NSString *)userComputerId completionHandler:(void (^)(NSObject *))completionHandler;

@end

NS_ASSUME_NONNULL_END
