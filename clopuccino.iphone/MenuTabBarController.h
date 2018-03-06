#import <UIKit/UIKit.h>
#import "DownloadFileViewController.h"
#import "FileUploadViewController.h"
#import "RootDirectoryViewController.h"
#import "SettingsViewController.h"

@interface MenuTabBarController : UITabBarController <UITabBarControllerDelegate>

@property(nonatomic, strong) DownloadFileViewController *downloadFileViewController;

@property(nonatomic, strong) FileUploadViewController *fileUploadViewController;

@property(nonatomic, strong) RootDirectoryViewController *rootDirectoryViewController;

@property(nonatomic, strong) SettingsViewController *settingsViewController;

@property(nonatomic, assign) BOOL reloadDownloadTab;

@property(nonatomic, assign) BOOL reloadUploadTab;

// Clear browsing histories, display and refresh RootDirectoryViewController
// when next time the tab 'Browse' is pressed.
@property(nonatomic, assign) BOOL reloadBrowseTab;

@property(nonatomic, assign) BOOL reloadSettingsTab;

- (UINavigationController *)navigationControllerAtTabBarIndex:(NSUInteger)index;

- (NSString *)selectedTabName;

@end
