#import "MenuTabBarController.h"
#import "AppService.h"
#import "StartupViewController.h"

@interface MenuTabBarController ()

@property(nonatomic, strong) NSArray *children;

@property(nonatomic, strong) AppService *appService;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic) BOOL needShowStartupViewController;

@property(nonatomic) BOOL needShowUserProfileViewController;

@end

@implementation MenuTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _children = @[@{@"storyboardId" : @"DownloadFile", @"icon" : [UIImage imageNamed:@"download"], @"titleKey" : @"Download"},
            @{@"storyboardId" : @"FileUpload", @"icon" : [UIImage imageNamed:@"upload"], @"titleKey" : @"upload"},
            @{@"storyboardId" : @"RootDirectory", @"icon" : [UIImage imageNamed:@"root-directory"], @"titleKey" : @"Browse"},
            @{@"storyboardId" : @"Settings", @"icon" : [UIImage imageNamed:@"settings"], @"titleKey" : @"Settings"}];

    // delete the prefixed '0' of the phone number for each user when the first time upgrading from 1.x

    if ([Utility needShowStartupViewController]) {
        self.needShowStartupViewController = YES;

        [self.appService removeZeroPrefixPhoneNumberForAllUsers];
    } else {
        self.needShowStartupViewController = NO;

        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSNumber *needCreateOrUpdateUserProfile = [userDefaults objectForKey:USER_DEFAULTS_KEY_NEED_CREATE_OR_UPDATE_USER_PROFILE];

        self.needShowUserProfileViewController = (needCreateOrUpdateUserProfile && [needCreateOrUpdateUserProfile boolValue]);

        NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

        if (sessionId) {
            [self.authService reloginWithSuccessHandler:nil failureHandler:^(NSData *loginData, NSURLResponse *loginResponse, NSError *loginError) {
                NSInteger loginStatusCode = [(NSHTTPURLResponse *) loginResponse statusCode];
                NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Login failed. %@ Status:%d", @""), [loginError localizedDescription], loginStatusCode];
                NSLog(@"%@", message);
            }];
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    NSMutableArray *controllerArray = [NSMutableArray array];

    for (NSUInteger index = 0; index < [self.children count]; index++) {
        NSDictionary *currentDictionary = self.children[index];

        UIViewController *currentViewController = [Utility instantiateViewControllerWithIdentifier:currentDictionary[@"storyboardId"]];

        UITabBarItem *tabItem = [[UITabBarItem alloc] init];

        UIImage *currentImage = currentDictionary[@"icon"];
        tabItem.image = currentImage;
        tabItem.selectedImage = currentImage;
        tabItem.title = NSLocalizedString(currentDictionary[@"titleKey"], @"");
        tabItem.tag = index;

        [currentViewController setTabBarItem:tabItem];

        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:currentViewController];

        [controllerArray addObject:navigationController];
    }

    self.viewControllers = controllerArray;

    self.delegate = self;

    _reloadDownloadTab = NO;
    _reloadUploadTab = NO;
    _reloadBrowseTab = NO;
    _reloadSettingsTab = NO;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onUserDefaultsChanged:) name:NSUserDefaultsDidChangeNotification object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    if (self.needShowStartupViewController) {
        self.needShowStartupViewController = NO;

        StartupViewController *startupViewController = [Utility instantiateViewControllerWithIdentifier:@"Startup"];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentViewController:startupViewController animated:YES completion:nil];
        });
    } else if (self.needShowUserProfileViewController) {
        self.needShowUserProfileViewController = NO;

        [self.appService showUserProfileViewControllerFromViewController:self showCancelButton:@NO];
    } else if (![userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID]) {
        // Force reload cells in SettingsViewController when the selected index is INDEX_OF_TAB_BAR_SETTINGS

        dispatch_async(dispatch_get_main_queue(), ^{
            [self setSelectedIndex:INDEX_OF_TAB_BAR_SETTINGS];
        });
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSUserDefaultsDidChangeNotification object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (AppService *)appService {
    if (!_appService) {
        _appService = [[AppService alloc] init];
    }

    return _appService;
}

- (AuthService *)authService {
    if (!_authService) {
        _authService = [[AuthService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];
    }

    return _authService;
}

- (void)onUserDefaultsChanged:(NSNotification *)notification {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSNumber *needReloadMenu = [userDefaults objectForKey:USER_DEFAULTS_KEY_RELOAD_MENU];
    
    if (needReloadMenu && [needReloadMenu boolValue]) {
        [userDefaults setBool:NO forKey:USER_DEFAULTS_KEY_RELOAD_MENU];

        // Remove all view controllers except for the home view controller of the non-active tabs
        NSUInteger selectedTabIndex = self.selectedIndex;

        NSArray *navigationControllers = self.viewControllers;

        NSUInteger navigationControllerCount = [navigationControllers count];

        for (NSUInteger index = 0; index < navigationControllerCount; index++) {
            if (index != selectedTabIndex) {
                UINavigationController *navigationController = navigationControllers[index];

                UIViewController *underlineViewController = [navigationController viewControllers][0];

                [navigationController setViewControllers:@[underlineViewController] animated:NO];
            }
        }

        // Reload Non-Active Tabs

        if (selectedTabIndex == INDEX_OF_TAB_BAR_DOWNLOAD) {
            self.reloadUploadTab = YES;
            self.reloadBrowseTab = YES;
            self.reloadSettingsTab = YES;
        } else if (selectedTabIndex == INDEX_OF_TAB_BAR_UPLOAD) {
            self.reloadDownloadTab = YES;
            self.reloadBrowseTab = YES;
            self.reloadSettingsTab = YES;
        } else if (selectedTabIndex == INDEX_OF_TAB_BAR_BROWSE) {
            self.reloadDownloadTab = YES;
            self.reloadUploadTab = YES;
            self.reloadSettingsTab = YES;
        } else if (selectedTabIndex == INDEX_OF_TAB_BAR_SETTINGS) {
            self.reloadDownloadTab = YES;
            self.reloadUploadTab = YES;
            self.reloadBrowseTab = YES;
        }
    }
}

# pragma mark UIViewController of each tab item

- (DownloadFileViewController *)downloadFileViewController {
    _downloadFileViewController = [self findUnderlineViewControllerWithIndex:INDEX_OF_TAB_BAR_DOWNLOAD];
    
    return _downloadFileViewController;
}

- (FileUploadViewController *)fileUploadViewController {
    _fileUploadViewController = [self findUnderlineViewControllerWithIndex:INDEX_OF_TAB_BAR_UPLOAD];
    
    return _fileUploadViewController;
}

- (RootDirectoryViewController *)rootDirectoryViewController {
    _rootDirectoryViewController = [self findUnderlineViewControllerWithIndex:INDEX_OF_TAB_BAR_BROWSE];
    
    return _rootDirectoryViewController;
}

- (SettingsViewController *)settingsViewController {
    _settingsViewController = [self findUnderlineViewControllerWithIndex:INDEX_OF_TAB_BAR_SETTINGS];
    
    return _settingsViewController;
}

- (UINavigationController *)navigationControllerAtTabBarIndex:(NSUInteger)index {
    return self.viewControllers[index];
}

- (id)findUnderlineViewControllerWithIndex:(NSUInteger)index {
    UINavigationController * navigationController = [self navigationControllerAtTabBarIndex:index];
    
    return [navigationController viewControllers][0];
}

- (NSString *)selectedTabName {
    NSDictionary *currentDictionary = self.children[self.selectedIndex];

    return NSLocalizedString(currentDictionary[@"titleKey"], @"");
}

# pragma mark - UITabBarControllerDelegate

- (BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController {
    BOOL shouldReturn = YES;

    if ([viewController isKindOfClass:[UINavigationController class]]) {
        // Stop using the deprecated method setStatusBarHidden: and using prefersStatusBarHidden to control hiding view controller individually.
        // There's no reason to invoke the method 'setStatusBarHidden:' here!

        // In case the previous view controller hides the status bar,
        // like user press in the AssetPreviewViewController to show the full scrren

        if ([self.navigationController isNavigationBarHidden]) {
            [self.navigationController setNavigationBarHidden:NO];
        }

        NSUInteger oldSelectedTabIndex = tabBarController.selectedIndex;

        UINavigationController *controller = (UINavigationController *) viewController;

        NSString *newSelectedViewControllerClassName = NSStringFromClass([[controller viewControllers][0] class]);

        // if new selected tab index is the same as the old one, stop loading before poping to the root view controller of the navigation controller

        if ((oldSelectedTabIndex == INDEX_OF_TAB_BAR_DOWNLOAD && [newSelectedViewControllerClassName isEqualToString:NSStringFromClass([DownloadFileViewController class])])
                || (oldSelectedTabIndex == INDEX_OF_TAB_BAR_UPLOAD && [newSelectedViewControllerClassName isEqualToString:NSStringFromClass([FileUploadViewController class])])
                || (oldSelectedTabIndex == INDEX_OF_TAB_BAR_BROWSE && [newSelectedViewControllerClassName isEqualToString:NSStringFromClass([RootDirectoryViewController class])])
                || (oldSelectedTabIndex == INDEX_OF_TAB_BAR_SETTINGS && [newSelectedViewControllerClassName isEqualToString:NSStringFromClass([SettingsViewController class])])) {

            NSArray<__kindof UIViewController *> *viewControllers = controller.viewControllers;

            if (viewControllers && [viewControllers count] > 0) {
                // stop loading current view controller and pop to root, if any

                NSUInteger currentViewControllerIndex = [viewControllers count] - 1;

                id currentViewController = viewControllers[currentViewControllerIndex];

                if ([currentViewController conformsToProtocol:@protocol(ProcessableViewController)]) {
                    if ([currentViewController isLoading]) {
                        [currentViewController stopLoading];

                        shouldReturn = NO;
                    }
                }

                // When returns NO and the current view controller is the root view controller, set reloadXxxTab to NO
                if (!shouldReturn && currentViewControllerIndex == 0) {
                    if (oldSelectedTabIndex == INDEX_OF_TAB_BAR_DOWNLOAD && self.reloadDownloadTab) {
                        self.reloadDownloadTab = NO;
                    } else if (oldSelectedTabIndex == INDEX_OF_TAB_BAR_UPLOAD && self.reloadUploadTab) {
                        self.reloadUploadTab = NO;
                    } else if (oldSelectedTabIndex == INDEX_OF_TAB_BAR_BROWSE && self.reloadBrowseTab) {
                        self.reloadBrowseTab = NO;
                    } else if (oldSelectedTabIndex == INDEX_OF_TAB_BAR_SETTINGS && self.reloadSettingsTab) {
                        self.reloadSettingsTab = NO;
                    }
                }
            }
        }
    }

    return shouldReturn;
}

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
    NSUInteger selectedTabIndex = tabBarController.selectedIndex;

    if (selectedTabIndex == INDEX_OF_TAB_BAR_DOWNLOAD && self.reloadDownloadTab) {
        self.reloadDownloadTab = NO;

        [self navigationViewController:viewController popToRootViewControllerAnimated:YES];
    } else if (selectedTabIndex == INDEX_OF_TAB_BAR_UPLOAD && self.reloadUploadTab) {
        self.reloadUploadTab = NO;

        [self navigationViewController:viewController popToRootViewControllerAnimated:YES];
    } else if (selectedTabIndex == INDEX_OF_TAB_BAR_BROWSE && self.reloadBrowseTab) {
        self.reloadBrowseTab = NO;

        [self navigationViewController:viewController popToRootViewControllerAnimated:YES];
    } else if (selectedTabIndex == INDEX_OF_TAB_BAR_SETTINGS && self.reloadSettingsTab) {
        self.reloadSettingsTab = NO;

        [self navigationViewController:viewController popToRootViewControllerAnimated:YES];
    }
}

- (void)navigationViewController:(UIViewController *)viewController popToRootViewControllerAnimated:(BOOL)animated{
    // Show the root controller of the nativation controller

    if ([viewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *controller = (UINavigationController *) viewController;

        if ([[controller viewControllers] count] > 1) {
            // Stop using the deprecated method setStatusBarHidden: and using prefersStatusBarHidden to control hiding view controller individually.
            // There's no reason to invoke the method 'setStatusBarHidden:' here!
            
            // In case the previous view controller hides the status bar,
            // like user press in the AssetPreviewViewController to show the full scrren

            if ([self.navigationController isNavigationBarHidden]) {
                [self.navigationController setNavigationBarHidden:NO];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                [controller popToRootViewControllerAnimated:animated];
            });
        }
    }
}

@end
