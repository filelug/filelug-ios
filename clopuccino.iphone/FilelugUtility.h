#import <Foundation/Foundation.h>

@class AppDelegate;
@class ConnectionViewController;
@protocol FilePreviewControllerDelegate;
@class FilelugFileDownloadService;

NS_ASSUME_NONNULL_BEGIN

@interface FilelugUtility : NSObject

//// Navigate display ConnectionViewController from the specified view controller.
//// fromViewController cannot be nil
//// The method will executed in main queue with 1.0 second of delay,
//// to prevent method viewDidLoad not finished,
//// if the method is invoked directly/indirectly in method viewDidLoad
//+ (void)showConnectionViewControllerFromParent:(nullable UIViewController *)fromViewController;

//+ (void)showChangePhoneNumberViewControllerFromParent:(nullable UIViewController *)fromViewController delayedInSeconds:(double)seconds;

+ (AppDelegate *)applicationDelegate;

// The first time your app launches and calls this method,
// the system asks the user whether your app should be allowed to deliver notifications before it ask permission to Apple.
+ (void)registerNotificationForWithApplication:(UIApplication *)application fromViewController:(UIViewController *_Nullable)fromViewController;

//+ (void)sendImmediateLocalNotificationWithMessage:(nullable NSString *)message title:(nullable NSString *)title userInfo:(nullable NSDictionary *)userInfo;

// The method will executed in main queue with 1.0 second of delay,
// to prevent method viewDidLoad not finished,
// if the method is invoked directly/indirectly in method viewDidLoad
//+ (void)alertUserNeverConnectedWithViewController:(UIViewController *_Nonnull)viewController loginSuccessHandler:(void (^ __nonnull)(NSURLResponse *, NSData *))loginSuccessHandler;

+ (void)alertEmptyUserSessionFromViewController:(UIViewController *_Nonnull)viewController;

// Return NotReachable, ReachableViaWiFi, ReachableViaWAN(3G or 4G)
+ (NSInteger)detechNetworkStatus;

+ (void)requestNetworkActivityIndicatorVisible:(BOOL)setVisible;

+ (void)prepareInitialPreferencesRelatedToMainAppWithUserDefaults:(NSUserDefaults *)userDefaults;

+ (void)alertNoComputerEverConnectedWithViewController:(UIViewController *_Nonnull)viewController delayInSeconds:(double)seconds completionHandler:(nullable void(^)(void))handler;

+ (void)promptToAllowUsePhotosWithViewController:(UIViewController *)viewController;

+ (void)promptToAllowNotificationWithViewController:(UIViewController *_Nullable)viewController;

+ (NSString *)selectedTabName;

@end

NS_ASSUME_NONNULL_END
