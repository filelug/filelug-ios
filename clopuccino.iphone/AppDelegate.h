#import <UserNotifications/UserNotifications.h>

@class MenuTabBarController;
@class FileUploadProcessService;
@class FileDownloadProcessService;
@class FilelugFileDownloadService;


typedef void (^CompletionHandlerType)(void);


@interface AppDelegate : UIResponder <UIApplicationDelegate, UNUserNotificationCenterDelegate>

@property(nonatomic, strong) UIWindow *window;

//@property(nonatomic, strong) NSMutableDictionary *completionHandlerDictionary;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) DirectoryService *directoryService;

@property(nonatomic, strong) FileUploadProcessService *fileUploadProcessService;

@property(nonatomic, strong) FileDownloadProcessService *fileDownloadProcessService;

@property(nonatomic, strong) AssetFileDao *assetFileDao;

@property(nonatomic, strong) FileUploadGroupDao *fileUploadGroupDao;

@property(nonatomic, strong) FileTransferDao *fileTransferDao;

// This is the only place you get MenuTabBarController.
@property(nonatomic, strong) MenuTabBarController *menuTabBarController;

//// This is the only place you get StartupViewController
//@property(nonatomic, strong) StartupViewController *startupViewController;

//- (void)addCompletionHandler:(CompletionHandlerType)handler forSession:(NSString *)identifier;
//
//- (void)callCompletionHandlerForSession:(NSString *)identifier;

- (UIViewController *)topViewController;

@end
