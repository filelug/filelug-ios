#import <Foundation/Foundation.h>
#import "AccountKitService.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppService : NSObject

// login asynchronously from outside of ConnectionViewController
// when response code is 200 without any error, go to success handler; otherwise go to failureHandler.
// response data will be saved by this method when response code is 200 without any error and invokers don't have to deal with it.
//- (void)authService:(AuthService *)authService reloginCurrentUserComputerFromViewController:(nullable UIViewController *)viewController successHandler:(void (^ _Nullable)(NSURLResponse *, NSData *))successHandler failureHandler:(void (^ _Nullable)(NSURLResponse *, NSData *, NSError *))failureHandler;

//- (void)authService:(AuthService *)authService alertToReloginOrTryConnectAgainWithMessagePrefix:(nullable NSString *)messagePrefix
//           response:(NSURLResponse *)response
//               data:(nullable NSData *)data
//              error:(nullable NSError *)error
//     tryAgainAction:(nullable UIAlertAction *)tryAgainAction
//   inViewController:(nonnull UIViewController *)viewController;

//- (void)moveFileToITunesSharingFolderWithTableView:(UITableView *)tableView localRelPath:(NSString *)localRelPath deleteFileTransferWithTransferKey:(nullable NSString *)transferKey fileTransferDao:(nullable FileTransferDao *)fileTransferDao successHandler:(void (^ _Nullable)())successHandler;

- (void)showToastAlertWithTableView:(UITableView *)tableView message:(NSString *)message completionHandler:(void (^ _Nullable)(void))completionHandler;

- (void)showUserProfileViewControllerFromViewController:(UIViewController *)fromViewController showCancelButton:(NSNumber *)showCancelButton;

- (void)removeZeroPrefixPhoneNumberForAllUsers;

- (void)viewController:(UIViewController *)viewController findAvailableComputersWithTryAgainOnInvalidSession:(BOOL)tryAgainOnInvalidSession onSuccessHandler:(nullable void(^)(NSArray<UserComputerWithoutManaged *> *availableUserComputers))handler;
@end

NS_ASSUME_NONNULL_END
