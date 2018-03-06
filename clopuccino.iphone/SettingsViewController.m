#import <objc/runtime.h>
#import "SettingsViewController.h"
#import "MenuTabBarController.h"
#import "AppDelegate.h"
#import "AppService.h"
#import "FilelugUtility.h"
#import "TutorialViewController.h"
#import <SafariServices/SFSafariViewController.h>
#import "AccountKitServiceDelegate.h"
#import "ConnectToComputerIntroductionTableViewController.h"
#import "PortraitNavigationController.h"
#import "ManageAccountViewController.h"
#import "ManageComputerViewController.h"
#import "StartupViewController.h"

// -------------- section 0 -----------------
#define kSettingsSectionIndexOfAccountAndComputer   0

#define kSettingsRowIndexOfCurrentAccount           0
#define kSettingsRowIndexOfCurrentComputer          1
#define kSettingsRowIndexOfManageCurrentAccount     2
#define kSettingsRowIndexOfManageCurrentComputer    3

// -------------- section 1 -----------------
#define kSettingsSectionIndexOfAbout                1

#define kSettingsRowIndexOfDeleteLocalCachedData    0
#define kSettingsRowIndexOfGettingStarted           1
#define kSettingsRowIndexOfFeedBack                 2
#define kSettingsRowIndexOfRateOnAppStore           3
#define kSettingsRowIndexOfTermsOfUse               4
#define kSettingsRowIndexOfPrivacyPolicy            5
#define kSettingsRowIndexOfAppVersion               6

// row key for NSDictionary
#define kSettingsRowKeyCellStyle                                    @"style"
#define kSettingsRowKeyLabelText                                    @"label_text"
#define kSettingsRowKeyLabelTextAdjustsFontSizeToFitWidth           @"label_text_adjusts_font_size_to_fit_width"
#define kSettingsRowKeyLabelTextNumberOfLines                       @"label_text_number_of_lines"
#define kSettingsRowKeyDetailLabelText                              @"detail_label_text"
#define kSettingsRowKeyDetailLabelTextColor                         @"detail_label_text_color"
#define kSettingsRowKeyDetailLabelTextAdjustsFontSizeToFitWidth     @"detail_label_text_adjusts_font_size_to_fit_width"
#define kSettingsRowKeyDetailLabelTextNumberOfLines                 @"detail_label_text_number_of_lines"
#define kSettingsRowKeyImage                                        @"image"
#define kSettingsRowKeyAccessoryType                                @"accessory_type"
#define kSettingsRowKeyAccessoryView                                @"accessory_view"
#define kSettingsRowKeySelectionStyle                               @"selection_style"
#define kSettingsRowKeyUserInteractionEnabled                       @"user_interaction_enabled"

#define kSettingsNotSetText NSLocalizedString(@"(Not Set2)", @"")

@interface SettingsViewController () <AccountKitServiceDelegate>

// elements of NSString
@property(nonatomic, strong) NSArray *tableSections;

// elements of NSArray, which contains NSDictionary contains row keys
@property(nonatomic, strong) NSArray *tableSectionRows;

@property(nonatomic, strong) UserDao *userDao;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) UserComputerService *userComputerService;

@property(nonatomic, strong) UserComputerDao *userComputerDao;

@property(nonatomic, strong) AppService *appService;

@property(nonatomic, strong) AccountKitService *accountKitService;

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

@property(nonatomic, strong) CountryService *countryService;

@end

const char ASSOCIATE_KEY_LOGIN_REASON;

@implementation SettingsViewController

@synthesize processing;

@synthesize progressView;

- (void)viewDidLoad {
    [super viewDidLoad];

    self.processing = @NO;

    [Utility viewController:self useNavigationLargeTitles:YES];

    _preferredContentSizeCategoryService = [[PreferredContentSizeCategoryService alloc] init];

    _accountKitService = [[AccountKitService alloc] initWithServiceDelegate:self];

    [self prepareTableViewCells];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // adding observers

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangePreferredContentSize:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];

    [self addObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self reloadUserData];

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    // do only when NOT back from its sub ViewController or user canceled to add a new computer
    if (![userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID]) {
        if ([userDefaults objectForKey:USER_DEFAULTS_KEY_USER_ID]) {
            // find available computers, if only one computer available, connect directly
            // if no computer available, show connect wizard to add a new computer

            NSNumber *disabledFindAvailableComputers = [userDefaults objectForKey:USER_DEFAULTS_KEY_DISABLED_FIND_AVAILABLE_COMPUTERS_ON_VIEW_DID_APPEAR];

            if (disabledFindAvailableComputers && [disabledFindAvailableComputers boolValue]) {
                // Next time, do invoke [self findAvailableComputersToConnectWithTryAgainOnInvalidSession:YES connectDirectlyIfOnlyOneFound:YES addNewComputerDirectlyIfNotFound:NO];
                [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_DISABLED_FIND_AVAILABLE_COMPUTERS_ON_VIEW_DID_APPEAR];
            } else {
                [self findAvailableComputersToConnectWithTryAgainOnInvalidSession:YES connectDirectlyIfOnlyOneFound:YES addNewComputerDirectlyIfNotFound:NO];
            }
        } else {
            [self showAccountActionSheetToLoginWithAnotherAccount];
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) context:NULL];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];
    
    if (self.progressView) {
        self.progressView = nil;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
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

- (UserComputerService *)userComputerService {
    if (!_userComputerService) {
        _userComputerService = [[UserComputerService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];
    }

    return _userComputerService;
}

- (UserComputerDao *)userComputerDao {
    if (!_userComputerDao) {
        _userComputerDao = [[UserComputerDao alloc] init];
    }

    return _userComputerDao;
}

- (AppService *)appService {
    if (!_appService) {
        _appService = [[AppService alloc] init];
    }

    return _appService;
}

- (CountryService *)countryService {
    if (!_countryService) {
        _countryService = [[CountryService alloc] init];
    }

    return _countryService;
}

- (BOOL)isLoading {
    return (self.processing && [self.processing boolValue]);
}

- (void)stopLoading {
    self.processing = @NO;
}

- (void)didChangePreferredContentSize:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

#pragma mark - NSKeyValueObserving

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(processing))]) {
        NSNumber *newValue = change[NSKeyValueChangeNewKey];
        NSNumber *oldValue = change[NSKeyValueChangeOldKey];

        if (![newValue isEqualToNumber:oldValue]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([newValue boolValue]) {
                    [self.tableView setScrollEnabled:NO];

                    if (!self.progressView) {
                        // Get the current tab name from MenuTabViewController
                        NSString *selectedTabName = [FilelugUtility selectedTabName];

                        MBProgressHUD *progressHUD = [Utility prepareProgressViewWithSuperview:self.view inTabWithTabName:selectedTabName refreshControl:nil];

                        self.progressView = progressHUD;
                    } else {
                        [self.progressView show:YES];
                    }
                } else {
                    [self.tableView setScrollEnabled:YES];

                    if (self.progressView) {
                        [self.progressView hide:YES];
                    }
                }
            });
        }
    }
}

- (void)prepareTableViewCells {
    _tableSections = @[
            NSLocalizedString(@"Account and Computer", @""),
            NSLocalizedString(@"Others", @"")
    ];

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSArray *sectionRows0 = @[
            // Current Account
            @{
                    kSettingsRowKeyCellStyle : @(UITableViewCellStyleSubtitle),                                                 // NSNumber, wrapping NSInteger
                    kSettingsRowKeyLabelText : [self prepareCurrentAccountLabelTextWithUserDefaults:userDefaults],              // NSString
                    kSettingsRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),                                                  // NSNumber, wrapping BOOL
                    kSettingsRowKeyLabelTextNumberOfLines : @(1),                                                               // NSNumber, wrapping NSInteger

                    // DEBUG: For Video Recording
//                    kSettingsRowKeyDetailLabelText : @"0968897603 (TW)",
                    kSettingsRowKeyDetailLabelText : [self prepareCurrentAccountDetailLabelTextWithUserDefaults:userDefaults],  // NSString
                    kSettingsRowKeyDetailLabelTextColor: [self prepareCurrentAccountTextColorWithUserDefaults:userDefaults],
                    kSettingsRowKeyDetailLabelTextAdjustsFontSizeToFitWidth : @(NO),                                            // NSNumber, wrapping BOOL
                    kSettingsRowKeyDetailLabelTextNumberOfLines : @(0),                                                         // NSNumber, wrapping NSInteger
                    kSettingsRowKeyImage : @"account",                                                                          // NSString
                    kSettingsRowKeyAccessoryType : @(UITableViewCellAccessoryNone),                                             // NSNumber, wrapping NSInteger
                    kSettingsRowKeyUserInteractionEnabled : @YES                                                                // NSNumber, wrapping BOOL
            },
            // Current Computer
            @{
                    kSettingsRowKeyCellStyle : @(UITableViewCellStyleSubtitle),
                    kSettingsRowKeyLabelText : NSLocalizedString(@"Current Computer", @""),
                    kSettingsRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kSettingsRowKeyLabelTextNumberOfLines : @(1),
                    kSettingsRowKeyDetailLabelText : [self prepareCurrentComputerDetailLabelTextWithUserDefaults:userDefaults],
                    kSettingsRowKeyDetailLabelTextColor: [self prepareCurrentComputerTextColorWithUserDefaults:userDefaults],
                    kSettingsRowKeyDetailLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kSettingsRowKeyDetailLabelTextNumberOfLines : @(0),
                    kSettingsRowKeyImage : @"computer",
                    kSettingsRowKeyAccessoryType : @(UITableViewCellAccessoryNone),
                    kSettingsRowKeyUserInteractionEnabled : @([userDefaults objectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] != nil)
            },
            // Manage Current Account
            @{
                    kSettingsRowKeyCellStyle : @(UITableViewCellStyleDefault),
                    kSettingsRowKeyLabelText : NSLocalizedString(@"Manage Current Account", @""),
                    kSettingsRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kSettingsRowKeyLabelTextNumberOfLines : @(1),
                    kSettingsRowKeyDetailLabelText : @"",
                    kSettingsRowKeyImage : @"manage-account",
                    kSettingsRowKeyAccessoryType : @(UITableViewCellAccessoryDisclosureIndicator),
                    kSettingsRowKeyUserInteractionEnabled : @([userDefaults objectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] != nil)
            },
            // Manage Current Computer
            @{
                    kSettingsRowKeyCellStyle : @(UITableViewCellStyleDefault),
                    kSettingsRowKeyLabelText : NSLocalizedString(@"Manage Current Computer", @""),
                    kSettingsRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kSettingsRowKeyLabelTextNumberOfLines : @(1),
                    kSettingsRowKeyDetailLabelText : @"",
                    kSettingsRowKeyImage : @"manage-computer",
                    kSettingsRowKeyAccessoryType : @(UITableViewCellAccessoryDisclosureIndicator),
                    kSettingsRowKeyUserInteractionEnabled : @([userDefaults objectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] != nil && [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID] != nil)
            }
    ];

    NSArray *sectionRows1 = @[
            // Delete local cached data
            @{
                    kSettingsRowKeyCellStyle : @(UITableViewCellStyleDefault),
                    kSettingsRowKeyLabelText : NSLocalizedString(@"Delete Local Cached Data", @""),
                    kSettingsRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kSettingsRowKeyLabelTextNumberOfLines : @(0),
                    kSettingsRowKeyImage : @"sweep",
                    kSettingsRowKeyAccessoryType : @(UITableViewCellAccessoryNone)
            },
            // Getting started with Filelug
            @{
                    kSettingsRowKeyCellStyle : @(UITableViewCellStyleDefault),                          // NSNumber, wrapping NSInteger
                    kSettingsRowKeyLabelText : NSLocalizedString(@"Getting Started with Filelug", @""),                         // NSString
                    kSettingsRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),                          // NSNumber, wrapping BOOL
                    kSettingsRowKeyLabelTextNumberOfLines : @(0),                                       // NSNumber, wrapping NSInteger
                    kSettingsRowKeyImage : @"book-flip",                                                // NSString
                    kSettingsRowKeyAccessoryType : @(UITableViewCellAccessoryDisclosureIndicator)       // NSNumber, wrapping NSInteger
            },
            // Write your feedback
            @{
                    kSettingsRowKeyCellStyle : @(UITableViewCellStyleDefault),
                    kSettingsRowKeyLabelText : NSLocalizedString(@"Write Your Feedback", @""),
                    kSettingsRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kSettingsRowKeyLabelTextNumberOfLines : @(0),
                    kSettingsRowKeyImage : @"feedback",
                    kSettingsRowKeyAccessoryType : @(UITableViewCellAccessoryNone)
            },
            // Rate Filelug on App Store
            @{
                    kSettingsRowKeyCellStyle : @(UITableViewCellStyleDefault),
                    kSettingsRowKeyLabelText : NSLocalizedString(@"Rate Filelug on App Store", @""),
                    kSettingsRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kSettingsRowKeyLabelTextNumberOfLines : @(0),
                    kSettingsRowKeyImage : @"rate",
                    kSettingsRowKeyAccessoryType : @(UITableViewCellAccessoryNone)
            },
            // Terms of Use
            @{
                    kSettingsRowKeyCellStyle : @(UITableViewCellStyleDefault),
                    kSettingsRowKeyLabelText : NSLocalizedString(@"Terms of Service", @""),
                    kSettingsRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kSettingsRowKeyLabelTextNumberOfLines : @(0),
                    kSettingsRowKeyImage : @"terms",
                    kSettingsRowKeyAccessoryType : @(UITableViewCellAccessoryNone)
            },
            // Privacy Policy
            @{
                    kSettingsRowKeyCellStyle : @(UITableViewCellStyleDefault),
                    kSettingsRowKeyLabelText : NSLocalizedString(@"Privacy Policy", @""),
                    kSettingsRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kSettingsRowKeyLabelTextNumberOfLines : @(0),
                    kSettingsRowKeyImage : @"privacy",
                    kSettingsRowKeyAccessoryType : @(UITableViewCellAccessoryNone)
            },
            // App Version
            @{
                    kSettingsRowKeyCellStyle : @(UITableViewCellStyleValue1),
                    kSettingsRowKeyLabelText : NSLocalizedString(@"App Version", @""),
                    kSettingsRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kSettingsRowKeyLabelTextNumberOfLines : @(1),
                    kSettingsRowKeyDetailLabelText : [userDefaults stringForKey:USER_DEFAULTS_KEY_MAIN_APP_VERSION],
                    kSettingsRowKeyDetailLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kSettingsRowKeyDetailLabelTextNumberOfLines : @(1),
                    kSettingsRowKeyImage : @"number-2-active",
                    kSettingsRowKeyAccessoryType : @(UITableViewCellAccessoryNone),
                    kSettingsRowKeySelectionStyle : @(UITableViewCellSelectionStyleNone)
            }
    ];


    _tableSectionRows = @[sectionRows0, sectionRows1];
}

- (NSString *)prepareCurrentAccountLabelTextWithUserDefaults:(NSUserDefaults *)userDefaults {
    NSString *sessionId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];
    
    NSString *labelText;
    
    if (sessionId) {
        labelText = NSLocalizedString(@"Current Account", @"");
    } else {
        labelText = NSLocalizedString(@"Login", @"");
    }
    
    return labelText;
}

- (NSString *)prepareCurrentAccountDetailLabelTextWithUserDefaults:(NSUserDefaults *)userDefaults {
    NSString *sessionId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    NSNumber *currentCountryCode = [userDefaults objectForKey:USER_DEFAULTS_KEY_COUNTRY_CODE];

    NSString *currentPhoneNumber = [userDefaults stringForKey:USER_DEFAULTS_KEY_PHONE_NUMBER];

    NSString *labelText;

    if (sessionId && currentCountryCode && currentPhoneNumber) {
        labelText = [CountryService stringRepresentationWithCountryCode:currentCountryCode phoneNumber:currentPhoneNumber];
    } else {
        labelText = kSettingsNotSetText;
    }

    return labelText;
}

- (UIColor *)prepareCurrentAccountTextColorWithUserDefaults:(NSUserDefaults *)userDefaults {
    NSString *sessionId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    return (sessionId) ? [UIColor aquaColor] : [UIColor redColor];
}

- (NSString *)prepareCurrentComputerDetailLabelTextWithUserDefaults:(NSUserDefaults *)userDefaults {
    NSString *sessionId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    NSString *userComputerId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

    NSString *labelText;

    if (sessionId && userComputerId) {
        NSString *computerName = [userDefaults stringForKey:USER_DEFAULTS_KEY_COMPUTER_NAME];

        labelText = computerName ? computerName : kSettingsNotSetText;
    } else {
        labelText = kSettingsNotSetText;
    }

    return labelText;
}

- (UIColor *)prepareCurrentComputerTextColorWithUserDefaults:(NSUserDefaults *)userDefaults {
    NSString *sessionId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];
    NSString *userComputerId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

    if (!sessionId) {
        return [UIColor lightGrayColor];
    } else if (!userComputerId) {
        return [UIColor redColor];
    } else {
        return [UIColor aquaColor];
    }
}

- (void)reloadUserData {
    [self prepareTableViewCells];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (void)findAvailableComputersToConnectWithTryAgainOnInvalidSession:(BOOL)tryAgainOnInvalidSession
                                      connectDirectlyIfOnlyOneFound:(BOOL)connectDirectlyIfOnlyOneFound
                                   addNewComputerDirectlyIfNotFound:(BOOL)addNewComputerDirectlyIfNotFound {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.appService viewController:self findAvailableComputersWithTryAgainOnInvalidSession:tryAgainOnInvalidSession onSuccessHandler:^(NSArray<UserComputerWithoutManaged *> *availableUserComputers) {
            self.processing = @NO;

            // if the computer id in preferences not exists in the available computers, delete the computer-related data from preferences

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self.userComputerService deleteComputerDataInUserDefautsIfComputerIdNotFoundInUserComputers:availableUserComputers didDeletedHandler:^{
                    [self reloadUserData];
                }];
            });

            // Consider if returning only one available computer and contains only userId in it.

            if (availableUserComputers && [availableUserComputers count] > 0 && availableUserComputers[0].computerId) {

                // show action sheet to choose

                if ([availableUserComputers count] == 1 && connectDirectlyIfOnlyOneFound) {
                    // connect directly

                    UserComputerWithoutManaged *userComputerWithoutManaged = availableUserComputers[0];

                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        NSString *userComputerId = userComputerWithoutManaged.userComputerId;

                        // Find the UserComputer in local db and use the value for showHidden and set to @(NO) if not found.
                        // The UserComputerWithoutManaged is from server and there's no value to property showHidden.

                        NSNumber *showHidden = [self.userComputerDao findShowHiddenForUserComputerId:userComputerId];

                        if (!showHidden) {
                            showHidden = @(NO);
                        }

                        NSString *userId = userComputerWithoutManaged.userId;

                        NSNumber *computerId = userComputerWithoutManaged.computerId;

                        NSString *computerName = userComputerWithoutManaged.computerName;

                        // connect to computer
                        [self connectToComputerWithUserId:userId computerId:computerId computerName:computerName showHidden:showHidden tryAgainIfFailed:YES];
                    });
                } else {
                    [self selectComputerNameToConnectWithAvailableUserComputers:availableUserComputers];
                }
            } else {
                if (addNewComputerDirectlyIfNotFound) {
                    // Go to add a new computer directly

                    // Go to ConnectComputerXxxViewController

                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        ConnectToComputerIntroductionTableViewController *connectToComputerIntroductionTableViewController = [[ConnectToComputerIntroductionTableViewController alloc] initWithNibName:@"ConnectToComputerIntroductionTableViewController" bundle:nil];

                        [connectToComputerIntroductionTableViewController setHidesBottomBarWhenPushed:YES];

                        connectToComputerIntroductionTableViewController.fromViewController = self;

                        PortraitNavigationController *portraitNavigationController = [[PortraitNavigationController alloc] initWithRootViewController:connectToComputerIntroductionTableViewController];

                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self presentViewController:portraitNavigationController animated:YES completion:nil];
                        });
                    });
                } else {
                    [self selectComputerNameToConnectWithAvailableUserComputers:availableUserComputers];
                }
            }
        }];
    });
}
   
- (void)selectComputerNameToConnectWithAvailableUserComputers:(NSArray<UserComputerWithoutManaged *> *_Nonnull)availableUserComputers {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *sourceView;
        CGRect sourceRect;
        
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:kSettingsRowIndexOfCurrentComputer inSection:kSettingsSectionIndexOfAccountAndComputer];
        
        UITableViewCell *currentComputerCell = [self.tableView cellForRowAtIndexPath:indexPath];
        
        if (currentComputerCell) {
            sourceView = currentComputerCell;
            sourceRect = currentComputerCell.bounds;
        } else {
            sourceView = self.tableView;
            sourceRect = self.tableView.frame;
        }
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [Utility promptActionSheetToChooseComputerNameWithAlertControllerTitle:NSLocalizedString(@"Choose Computer Name", @"")
                                                            availableUserComputers:availableUserComputers
                                                                  inViewController:self
                                                                        sourceView:sourceView
                                                                        sourceRect:sourceRect
                                                                     barButtonItem:nil
                                                                  allowNewComputer:YES
                                       onSelectComputerNameWithUserComputerHandler:^(UserComputerWithoutManaged *_Nonnull userComputerWithoutManaged) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    NSString *userComputerId = userComputerWithoutManaged.userComputerId;

                    // Find the UserComputer in local db and use the value for showHidden and set to @(NO) if not found.
                    // The UserComputerWithoutManaged is from server and there's no value to property showHidden.

                    NSNumber *showHidden = [self.userComputerDao findShowHiddenForUserComputerId:userComputerId];

                    if (!showHidden) {
                        showHidden = @(NO);
                    }

                    NSString *userId = userComputerWithoutManaged.userId;

                    NSNumber *computerId = userComputerWithoutManaged.computerId;

                    NSString *computerName = userComputerWithoutManaged.computerName;

                    // connect to computer
                    [self connectToComputerWithUserId:userId computerId:computerId computerName:computerName showHidden:showHidden tryAgainIfFailed:YES];
                });
            }                                           onSelectNewComputerHandler:^{
                // Go to ConnectComputerXxxViewController

                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    ConnectToComputerIntroductionTableViewController *connectToComputerIntroductionTableViewController = [[ConnectToComputerIntroductionTableViewController alloc] initWithNibName:@"ConnectToComputerIntroductionTableViewController" bundle:nil];

                    [connectToComputerIntroductionTableViewController setHidesBottomBarWhenPushed:YES];

                    connectToComputerIntroductionTableViewController.fromViewController = self;

                    PortraitNavigationController *portraitNavigationController = [[PortraitNavigationController alloc] initWithRootViewController:connectToComputerIntroductionTableViewController];

                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self presentViewController:portraitNavigationController animated:YES completion:nil];
                    });
                });
            }];
        });
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id rowsInfo = self.tableSectionRows[(NSUInteger) section];

    if ([rowsInfo respondsToSelector:@selector(count)]) {
        return [rowsInfo count];
    } else {
        return 0;
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.tableSections count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.tableSections[(NSUInteger) section];
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellDefaultIdentifier = @"SettingsCellDefault";
    static NSString *CellSubtitleIdentifier = @"SettingsCellSubtitle";
    static NSString *CellValue1Identifier = @"SettingsCellValue1";

    UITableViewCell *cell;

    // Configure the cell
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;

    NSDictionary *rowDictionary = self.tableSectionRows[(NSUInteger) section][(NSUInteger) row];

    if (rowDictionary) {
        // cell style

        NSNumber *cellStyle = rowDictionary[kSettingsRowKeyCellStyle];

        if (!cellStyle) {
            cellStyle = @(UITableViewCellStyleDefault);
        }

        NSString *reuseIdentifier;

        UIFont *textLabelFont;
        UIColor *textLabelTextColor;

        UIFont *detailLabelFont;
        UIColor *detailLabelTextColor;

        UITableViewCellStyle style = (UITableViewCellStyle) [cellStyle integerValue];

        switch (style) {
            case UITableViewCellStyleDefault:
                reuseIdentifier = CellDefaultIdentifier;

                textLabelFont = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
                textLabelTextColor = [UIColor darkTextColor];

                break;
            case UITableViewCellStyleSubtitle:
                reuseIdentifier = CellSubtitleIdentifier;

                textLabelFont = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
                textLabelTextColor = [UIColor darkTextColor];
                detailLabelFont = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
                detailLabelTextColor = [UIColor aquaColor];

                break;
            case UITableViewCellStyleValue1:
                reuseIdentifier = CellValue1Identifier;

                textLabelFont = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
                textLabelTextColor = [UIColor darkTextColor];
                detailLabelFont = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
                detailLabelTextColor = [UIColor aquaColor];

                break;
            default:
                reuseIdentifier = CellDefaultIdentifier;

                textLabelFont = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
                textLabelTextColor = [UIColor darkTextColor];
                detailLabelFont = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
                detailLabelTextColor = [UIColor aquaColor];
        }

        cell = [Utility tableView:tableView createOrDequeueCellWithStyle:style reuseIdentifier:reuseIdentifier forIndexPath:indexPath];

        // configure the preferred font

        cell.textLabel.font = textLabelFont;
        cell.textLabel.textColor = textLabelTextColor;

        cell.detailTextLabel.font = detailLabelFont;
        cell.detailTextLabel.textColor = detailLabelTextColor;

        // specical detail text color

        UIColor *specialDetailTextLabelColor = rowDictionary[kSettingsRowKeyDetailLabelTextColor];

        if (specialDetailTextLabelColor) {
            cell.detailTextLabel.textColor = specialDetailTextLabelColor;
        }

        // label text

        [cell.textLabel setText:rowDictionary[kSettingsRowKeyLabelText]];

        // kSettingsRowKeyLabelTextNumberOfLines

        NSNumber *labelTextNumberOfLines = rowDictionary[kSettingsRowKeyLabelTextNumberOfLines];

        if (labelTextNumberOfLines) {
            cell.textLabel.numberOfLines = [labelTextNumberOfLines integerValue];
        } else {
            cell.textLabel.numberOfLines = 1;
        }

        if (cell.textLabel.numberOfLines > 0) {
            cell.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        } else {
            cell.textLabel.lineBreakMode = NSLineBreakByCharWrapping;
        }

        // kSettingsRowKeyLabelTextAdjustsFontSizeToFitWidth

        NSNumber *labelTextAdjustsFontSizeToFitWidth = rowDictionary[kSettingsRowKeyLabelTextAdjustsFontSizeToFitWidth];

        if (labelTextAdjustsFontSizeToFitWidth) {
            cell.textLabel.adjustsFontSizeToFitWidth = [labelTextAdjustsFontSizeToFitWidth boolValue];

            if (cell.textLabel.adjustsFontSizeToFitWidth) {
                cell.textLabel.minimumScaleFactor = 0.5;
            }
        } else {
            cell.textLabel.adjustsFontSizeToFitWidth = NO;
        }

        // detail label text

        if (style != UITableViewCellStyleDefault) {
            [cell.detailTextLabel setText:rowDictionary[kSettingsRowKeyDetailLabelText]];
        } else {
            [cell.detailTextLabel setText:nil];
        }

        // kSettingsRowKeyDetailLabelTextNumberOfLines

        NSNumber *detailLabelTextNumberOfLines = rowDictionary[kSettingsRowKeyDetailLabelTextNumberOfLines];

        if (detailLabelTextNumberOfLines) {
            cell.detailTextLabel.numberOfLines = [detailLabelTextNumberOfLines integerValue];
        } else {
            cell.detailTextLabel.numberOfLines = 1;
        }

        if (cell.detailTextLabel.numberOfLines > 0) {
            cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        } else {
            cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        }

        // kSettingsRowKeyDetailLabelTextAdjustsFontSizeToFitWidth

        NSNumber *detailLabelTextAdjustsFontSizeToFitWidth = rowDictionary[kSettingsRowKeyDetailLabelTextAdjustsFontSizeToFitWidth];

        if (detailLabelTextAdjustsFontSizeToFitWidth) {
            cell.detailTextLabel.adjustsFontSizeToFitWidth = [detailLabelTextAdjustsFontSizeToFitWidth boolValue];

            if (cell.detailTextLabel.adjustsFontSizeToFitWidth) {
                cell.detailTextLabel.minimumScaleFactor = 0.5;
            }
        } else {
            cell.detailTextLabel.adjustsFontSizeToFitWidth = NO;
        }

        // image

        NSString *imageName = rowDictionary[kSettingsRowKeyImage];

        if (imageName) {
            UIImage *image = [UIImage imageNamed:imageName];

            [cell.imageView setImage:image];
        } else {
            [cell.imageView setImage:nil];
        }

        // accessory type

        NSNumber *accessoryType = rowDictionary[kSettingsRowKeyAccessoryType];

        if (accessoryType) {
            [cell setAccessoryType:(UITableViewCellAccessoryType) [accessoryType integerValue]];
        } else {
            [cell setAccessoryType:UITableViewCellAccessoryNone];
        }

        // accessory view - only if cell accessory type is UITableViewCellAccessoryNone

        if ([cell accessoryType] == UITableViewCellAccessoryNone) {
            [cell setAccessoryView:rowDictionary[kSettingsRowKeyAccessoryView]];
        }

        // selection style - default Blue

        NSNumber *selectionStyle = rowDictionary[kSettingsRowKeySelectionStyle];

        if (selectionStyle) {
            [cell setSelectionStyle:(UITableViewCellSelectionStyle) [selectionStyle integerValue]];
        } else {
            [cell setSelectionStyle:UITableViewCellSelectionStyleBlue];
        }

        // user interaction enabled

        NSNumber *userInteractionEnabled = rowDictionary[kSettingsRowKeyUserInteractionEnabled];

        BOOL canSelected = (!userInteractionEnabled || [userInteractionEnabled boolValue]);

        [cell setUserInteractionEnabled:canSelected];

        if (cell.textLabel) {
            [cell.textLabel setEnabled:canSelected];
        }

        if (cell.detailTextLabel) {
            [cell.detailTextLabel setEnabled:canSelected];
        }
    }

    // fallback

    if (!cell) {
        cell = [Utility tableView:tableView createOrDequeueCellWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellDefaultIdentifier forIndexPath:indexPath];
    }

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;

    // clear the selected gray - just for looking good
    [tableView deselectRowAtIndexPath:indexPath animated:NO];

    if (section == kSettingsSectionIndexOfAccountAndComputer) {
        if (row == kSettingsRowIndexOfCurrentAccount) {
            // Login with another account

            // Check if current user computer contains unfinished uploads or downloads before loging in with another account

            NSString *actionDisplayName = [NSLocalizedString(@"Login", @"") lowercaseString];

            [self checkNoRunningFileTransfersWithActionDisplayName:actionDisplayName completedHandler:^{
                [self showAccountActionSheetToLoginWithAnotherAccount];
            }];
        } else if (row == kSettingsRowIndexOfCurrentComputer) {
            // Change connected computer

            // Check if current user computer contains unfinished uploads or downloads before change connected computer

            NSString *actionDisplayName = [NSLocalizedString(@"Change connected computer", @"") lowercaseString];

            [self checkNoRunningFileTransfersWithActionDisplayName:actionDisplayName completedHandler:^{
                [self findAvailableComputersToConnectWithTryAgainOnInvalidSession:YES connectDirectlyIfOnlyOneFound:NO addNewComputerDirectlyIfNotFound:YES];
            }];
        } else if (row == kSettingsRowIndexOfManageCurrentAccount) {
            // Go to ManageAccountViewController

            ManageAccountViewController *manageAccountViewController = [[ManageAccountViewController alloc] initWithNibName:@"ManageAccountViewController" bundle:nil];

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.navigationController pushViewController:manageAccountViewController animated:YES];
            });
        } else if (row == kSettingsRowIndexOfManageCurrentComputer) {
            // Go to ManageComputerViewController

            ManageComputerViewController *manageComputerViewController = [[ManageComputerViewController alloc] initWithNibName:@"ManageComputerViewController" bundle:nil];

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.navigationController pushViewController:manageComputerViewController animated:YES];
            });
        }
    } else if (section == kSettingsSectionIndexOfAbout) {
        if (row == kSettingsRowIndexOfDeleteLocalCachedData) {
            // Check if current user computer contains unfinished uploads or downloads before deleting local cached data

            NSString *actionDisplayName = [NSLocalizedString(@"Delete Local Cached Data", @"") lowercaseString];

            [self checkNoRunningFileTransfersWithActionDisplayName:actionDisplayName completedHandler:^{
                // confirm before clear local data

                NSString *message = NSLocalizedString(@"Are you sure to delete local cached data?", @"");

                [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"Confirm Delete", @"") containsCancelAction:YES delayInSeconds:0 actionHandler:^(UIAlertAction * _Nonnull action) {
                    [self onConfirmDeleteLocalCachedData];
                }];
            }];
        } else if (row == kSettingsRowIndexOfGettingStarted) {
            // Getting started with Filelug

            TutorialViewController *tutorialViewController = [Utility instantiateViewControllerWithIdentifier:@"Tutorial"];

            dispatch_async(dispatch_get_main_queue(), ^{
                [self presentViewController:tutorialViewController animated:YES completion:nil];
            });
        } else if (row == kSettingsRowIndexOfFeedBack) {
            // Write feedback
            
            NSUserDefaults *userDefaults = [Utility groupUserDefaults];
            
            NSString *nickname = [userDefaults objectForKey:USER_DEFAULTS_KEY_NICKNAME];
            
            NSString *subject = [NSString stringWithFormat:NSLocalizedString(@"Feedback from", @""), nickname];
            
            NSString *encodedSubject = [subject stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet letterCharacterSet]];
            
            NSString *body = @"✉";
            
            NSString *encodedBody = [body stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet letterCharacterSet]];
            
            NSString *query = [NSString stringWithFormat:@"subject=%@&body=%@", encodedSubject, encodedBody];
            
            NSString *feedbackURLString = [NSString stringWithFormat:@"%@?%@", FILELUG_URL_TO_FEEDBACK, query];

            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:feedbackURLString] options:[NSDictionary dictionary] completionHandler:nil];
        } else if (row == kSettingsRowIndexOfRateOnAppStore) {
            // Rate and review app
            
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:FILELUG_URL_IN_APP_STORE] options:[NSDictionary dictionary] completionHandler:nil];
        } else if (row == kSettingsRowIndexOfTermsOfUse) {
            // Terms of Use

            NSURL *url = [NSURL URLWithString:FILELUG_URL_TO_TERMS_OF_USER];

            if ([SFSafariViewController class]) {
                SFSafariViewController *safariViewController = [[SFSafariViewController alloc] initWithURL:url entersReaderIfAvailable:NO];

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self presentViewController:safariViewController animated:YES completion:nil];
                });
            } else {
                // TODO: consider url for different locales
                [[UIApplication sharedApplication] openURL:url options:[NSDictionary dictionary] completionHandler:nil];
            }
        } else if (row == kSettingsRowIndexOfPrivacyPolicy) {
            // Privacy Policy

            NSURL *url = [NSURL URLWithString:FILELUG_URL_TO_PRIVACY_POLICY];

            if ([SFSafariViewController class]) {
                SFSafariViewController *safariViewController = [[SFSafariViewController alloc] initWithURL:url entersReaderIfAvailable:NO];

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self presentViewController:safariViewController animated:YES completion:nil];
                });
            } else {
                // TODO: consider url for different locales
                [[UIApplication sharedApplication] openURL:url options:[NSDictionary dictionary] completionHandler:nil];
            }
        } else if (row == kSettingsRowIndexOfAppVersion) {
            // App Version

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
            });
        }
    }
}

- (void)checkNoRunningFileTransfersWithActionDisplayName:(NSString *)actionDisplayName completedHandler:(void(^)(void))handler {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.authService checkNoRunningFileTransfersWithActionDisplayName:actionDisplayName inViewController:self completedHandler:handler];
    });
}

- (void)showAccountActionSheetToLoginWithAnotherAccount {
    NSString *title = NSLocalizedString(@"Choose Account to Login", @"");

    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:title message:@"" preferredStyle:UIAlertControllerStyleActionSheet];

    // find all users, make sure the active user is the first one row
    NSError *fetchError;
    NSArray *usersWithoutManaged = [self.userDao findAllUsersWithSortByActive:YES error:&fetchError];

    if (fetchError) {
        NSLog(@"Error on getting active user information! %@, %@", fetchError, [fetchError userInfo]);
    }

    if ([usersWithoutManaged count] > 0) {
        for (UserWithoutManaged *userWithoutManaged in usersWithoutManaged) {
            NSString *countryId = userWithoutManaged.countryId;
            NSString *phoneNumber = userWithoutManaged.phoneNumber;

            NSNumber *countryCode = [self.countryService countryCodeFromCountryId:countryId];

            NSString *countryAndPhoneNumber = [CountryService stringRepresentationWithCountryCode:countryCode phoneNumber:phoneNumber];

            UIAlertAction *countryAndPhoneNumberAction = [UIAlertAction actionWithTitle:countryAndPhoneNumber style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [self onSelectOtherAccountToLoginWithCountryId:countryId phoneNumber:phoneNumber];
            }];

            [actionSheet addAction:countryAndPhoneNumberAction];
        }
    }

    UIAlertAction *otherAccountAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Add New Account", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self startLoginProcessWithCountryCode:nil phoneNumber:nil];
    }];

    [actionSheet addAction:otherAccountAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:nil];

    [actionSheet addAction:cancelAction];

    if ([self isVisible]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIView *sourceView;
            CGRect sourceRect;
            
            // index path for current account cell
            NSIndexPath *currentAccountCellIndexPath = [NSIndexPath indexPathForRow:kSettingsRowIndexOfCurrentAccount inSection:kSettingsSectionIndexOfAccountAndComputer];
            
            UITableViewCell *selectedCell = [self.tableView cellForRowAtIndexPath:currentAccountCellIndexPath]; // must be called from main thread only
            
            if (selectedCell) {
                sourceView = selectedCell;
                sourceRect = selectedCell.bounds; // must be called from main thread only
            } else {
                sourceView = self.tableView;
                sourceRect = self.tableView.frame;
            }
            
            [actionSheet presentWithViewController:self sourceView:sourceView sourceRect:sourceRect barButtonItem:nil animated:YES completion:nil];
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [actionSheet presentWithAnimated:YES];
        });
    }
}

- (void)onSelectOtherAccountToLoginWithCountryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber {
    if (countryId && phoneNumber) {
        // login with the latest session id of this user. If not found, go Facebook Account Kit

        NSError *findError;
        UserWithoutManaged *userWithoutManaged = [self.userDao findUserWithoutManagedByCountryId:countryId phoneNumber:phoneNumber error:&findError];

        if (findError) {
            NSLog(@"Error on finding user with country: %@ and phone number: %@\n%@", countryId, phoneNumber, [findError userInfo]);
        }

        if (userWithoutManaged) {
            self.processing = @YES;

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self.authService loginWithUserWithoutManaged:userWithoutManaged successHandler:^(NSURLResponse *response, NSData *data) {
                    // reload to update current account before finding available computers

                    [self reloadUserData];

                    [self findAvailableComputersToConnectWithTryAgainOnInvalidSession:YES connectDirectlyIfOnlyOneFound:YES addNewComputerDirectlyIfNotFound:NO];
                } failureHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                    self.processing = @NO;

                    NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

                    if (statusCode == 403) {
                        // session not found --> go to Facebook Account Kit

                        NSNumber *countryCode = [self.countryService countryCodeFromCountryId:countryId];

                        [self startLoginProcessWithCountryCode:countryCode phoneNumber:phoneNumber];
                    } else {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            NSString *message = [AuthService prepareFailedLoginMessageWithResponse:response error:error data:data];

                            [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                        });
                    }
                }];
            });
        }
    }
}

- (void)startLoginProcessWithCountryCode:(NSNumber *_Nullable)countryCode phoneNumber:(NSString *_Nullable)phoneNumber {
    // Login with Facebook Account Kit, without country and phone number

    objc_removeAssociatedObjects(self);

    objc_setAssociatedObject(self, &ASSOCIATE_KEY_LOGIN_REASON, @(LOGIN_REASON_LOGIN_WITH_ANOTHER_ACCOUNT), OBJC_ASSOCIATION_COPY);

    NSString *inputState = [[NSUUID UUID] UUIDString];

    [self.accountKitService startLoginProcessWithState:inputState countryCode:countryCode phoneNumber:phoneNumber];
}

- (void)onConfirmDeleteLocalCachedData {
    // clear local data, including:
    // 1. browsed file system hierarchies, including saved downloaded files
    // 2. external file directory, including subdirectories and files under it
    // 3. data in temp directories
    // 4. all tables (will be truncated)
    // 5. data in user defaults
    // After cleared, go to StartupViewController
    
    self.processing = @YES;
    
    @try {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        // deleted browsed file system hierarchies, including saved downloaded files
        
        NSError *foundError;
        NSArray *allUserComputerIds = [self.userComputerDao findAllUserComputerIdsWithError:&foundError];
        
        if (allUserComputerIds && [allUserComputerIds count] > 0) {
            for (NSString *userComputerId in allUserComputerIds) {
                NSString *localFileRootDirectoryPath = [DirectoryService appGroupDirectoryPathWithUserComputerId:userComputerId];
                
                NSError *pathDeleteError;
                [fileManager removeItemAtPath:localFileRootDirectoryPath error:&pathDeleteError];

                if (pathDeleteError) {
                    NSLog(@"Error on deleting user cached data.\n%@", [pathDeleteError userInfo]);
                }
            }
        }

        // shared file directory
        [DirectoryService deleteDeviceSharingFolderIfExists];

        // external file directory

        NSString *externalDirectoryPath = [DirectoryService directoryForExternalFilesWithCreatedIfNotExists:YES];

        NSError *exteranlDirectoryDeletedError;
        [fileManager removeItemAtPath:externalDirectoryPath error:&exteranlDirectoryDeletedError];

        // data in tmp directory
        
        NSString *tmpDirectoryPath = [Utility parentPathToTmpUploadFile];
        
        NSDirectoryEnumerator *directoryEnum =
        [fileManager enumeratorAtURL:[NSURL fileURLWithPath:tmpDirectoryPath]
          includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey]
                             options:(NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsSubdirectoryDescendants)
                        errorHandler:nil];
        
        for (NSURL *pathURL in directoryEnum) {
            NSNumber *isDirectory;
            [pathURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL];
            
            NSString *filename;
            [pathURL getResourceValue:&filename forKey:NSURLNameKey error:NULL];
            
            if (isDirectory && ![isDirectory boolValue] && [filename hasPrefix:TMP_UPLOAD_FILE_PREFIX]) {
                [fileManager removeItemAtURL:pathURL error:NULL];
            }
        }
        
        // truncate tables
        [self truncateTables];
        
        // delete caches of all NSFetchedResultsController

        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        // Delete all tmp upload files

        [[TmpUploadFileService defaultService] removeAllTmpUploadFileAbsolutePathsWithUserDefaults:userDefaults ];

        // Clear user data in preferences
        [Utility deleteUserDataWithUserDefaults:userDefaults];

        // Clear computer data in preferences
        [Utility deleteComputerDataWithUserDefaults:userDefaults];
    } @finally {
        // Delay to make sure the data in user preferences and local db are cleared

        double delayInSeconds = 2.0;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
            self.processing = @NO;

            // Show StartupViewController on top of MenuTabBarController

            dispatch_async(dispatch_get_main_queue(), ^{
                StartupViewController *startupViewController = [Utility instantiateViewControllerWithIdentifier:@"Startup"];

                [self presentViewController:startupViewController animated:YES completion:nil];
            });
        });
    }
}

- (void)truncateTables {
    /*
     truncate tables with the following sequences:
     1 -> RecentDirectory
     2 -> HierarchicalModel
     3 -> FileDownloadGroup
     4 -> FileUploadGroup
     5 -> FileTransfer
     6 -> AssetFile
     7 -> UserComputer
     8 -> Purchase
     9 -> User
    */
    
    ClopuccinoCoreData *coreData = [ClopuccinoCoreData defaultCoreData];
    
    NSError *truncateError;

    // RecentDirectory
    [coreData truncateEntityWithEntityName:@"RecentDirectory" error:&truncateError];

    if (truncateError) {
        NSLog(@"Error on truncating table recent directory\n%@", [truncateError userInfo]);

        truncateError = nil;
    }
    
    // HierarchicalModel
    [coreData truncateEntityWithEntityName:@"HierarchicalModel" error:&truncateError];
    
    if (truncateError) {
        NSLog(@"Error on truncating table hierarchical model\n%@", [truncateError userInfo]);
        
        truncateError = nil;
    }

    // FileDownloadGroup
    [coreData truncateEntityWithEntityName:@"FileDownloadGroup" error:&truncateError];

    if (truncateError) {
        NSLog(@"Error on truncating table file downloaded group\n%@", [truncateError userInfo]);

        truncateError = nil;
    }

    // FileUploadGroup
    [coreData truncateEntityWithEntityName:@"FileUploadGroup" error:&truncateError];
    
    if (truncateError) {
        NSLog(@"Error on truncating table file uploaded group\n%@", [truncateError userInfo]);
        
        truncateError = nil;
    }
    
    // FileTransfer
    [coreData truncateEntityWithEntityName:@"FileTransfer" error:&truncateError];
    
    if (truncateError) {
        NSLog(@"Error on truncating table file transferred\n%@", [truncateError userInfo]);
        
        truncateError = nil;
    }
    
    // AssetFile
    [coreData truncateEntityWithEntityName:@"AssetFile" error:&truncateError];
    
    if (truncateError) {
        NSLog(@"Error on truncating table asset files\n%@", [truncateError userInfo]);
        
        truncateError = nil;
    }
    
    // UserComputer
    [coreData truncateEntityWithEntityName:@"UserComputer" error:&truncateError];
    
    if (truncateError) {
        NSLog(@"Error on truncating table users with computers\n%@", [truncateError userInfo]);
        
        truncateError = nil;
    }
    
    // Purchase
    [coreData truncateEntityWithEntityName:@"Purchase" error:&truncateError];
    
    if (truncateError) {
        NSLog(@"Error on truncating table purchases\n%@", [truncateError userInfo]);
        
        truncateError = nil;
    }

    // User
    [coreData truncateEntityWithEntityName:@"User" error:&truncateError];

    if (truncateError) {
        NSLog(@"Error on truncating table users\n%@", [truncateError userInfo]);

        truncateError = nil;
    }
}

- (void)connectToComputerWithUserId:(NSString *)userId computerId:(NSNumber *)computerId computerName:(NSString *)computerName showHidden:(NSNumber *)showHidden tryAgainIfFailed:(BOOL)tryAgainIfFailed {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    void (^connectToComputerSuccessHandler)(NSURLResponse *, NSData *) = ^void(NSURLResponse *response, NSData *data) {
        // reload data for newly-selected account

        self.processing = @NO;

        // reload summary settings
        [self reloadUserData];
    };

    void (^connectToComputerFailureHandler)(NSURLResponse *, NSData *, NSError *) = ^void(NSURLResponse *response, NSData *data, NSError *error) {
        self.processing = @NO;

        NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

        if (tryAgainIfFailed && (statusCode == 401 || (error && [error code] == NSURLErrorUserCancelledAuthentication))) {
            // invalid session -- re-login to get the new session id

            self.processing = @NO;

            [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [self connectToComputerWithUserId:userId computerId:computerId computerName:computerName showHidden:showHidden tryAgainIfFailed:NO];
                });
            } failureHandler:^(NSData *loginData, NSURLResponse *loginResponse, NSError *loginError) {
                self.processing = @NO;

                NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Error on connecting to computer %@", @""), computerName];

                [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
            }];
        } else if (statusCode == 403) {
            UserWithoutManaged *userWithoutManaged = [self.userDao findUserWithoutManagedById:userId error:NULL];

            NSNumber *countryCode;

            NSString *phoneNumber;

            if (userWithoutManaged) {
                NSString *countryId = userWithoutManaged.countryId;

                countryCode = [self.countryService countryCodeFromCountryId:countryId];

                phoneNumber = userWithoutManaged.phoneNumber;
            }

            [self startLoginProcessWithCountryCode:countryCode phoneNumber:phoneNumber];
        } else if (statusCode == 501 || statusCode == 460) {
            // computer not found -- ask if user wants to find available computers again

            NSString *errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Computer %@ not exists. Do you want to find other computers to connect?", @""), computerName];

            [Utility viewController:self alertWithMessageTitle:@"" messageBody:errorMessage actionTitle:NSLocalizedString(@"Find Computers", @"") containsCancelAction:YES cancelTitle:NSLocalizedString(@"Cancel", @"") delayInSeconds:0 actionHandler:^(UIAlertAction *action) {
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:kSettingsRowIndexOfCurrentComputer inSection:kSettingsSectionIndexOfAccountAndComputer];

                [self selectRowAndInvokeDelegateMethodAtIndexPath:indexPath scrollPosition:UITableViewScrollPositionMiddle];
            } cancelHandler:nil];
        } else {
            NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Error on connecting to computer %@", @""), computerName];

            UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [self connectToComputerWithUserId:userId computerId:computerId computerName:computerName showHidden:showHidden tryAgainIfFailed:YES];
                });
            }];

            [self.authService processCommonRequestFailuresWithMessagePrefix:message response:response data:data error:error tryAgainAction:tryAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [self connectToComputerWithUserId:userId computerId:computerId computerName:computerName showHidden:showHidden tryAgainIfFailed:NO];
                });
            }];
        }
    };

    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    self.processing = @YES;

    [self.userComputerService connectToComputerWithUserId:userId computerId:computerId showHidden:showHidden session:sessionId successHandler:^(NSURLResponse *response, NSData *data) {
        connectToComputerSuccessHandler(response, data);
    } failureHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        connectToComputerFailureHandler(response, data, error);
    }];
}

- (void)selectLoginWithAnotherAccountAndInvokeDelegateMethod {
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:kSettingsRowIndexOfCurrentAccount inSection:kSettingsSectionIndexOfAccountAndComputer];

    [self selectRowAndInvokeDelegateMethodAtIndexPath:indexPath scrollPosition:UITableViewScrollPositionMiddle];
}

- (void)selectRowAndInvokeDelegateMethodAtIndexPath:(NSIndexPath *)indexPath scrollPosition:(UITableViewScrollPosition)scrollPosition {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:scrollPosition];
        [self tableView:self.tableView didSelectRowAtIndexPath:indexPath];
    });
}

#pragma mark - AccountKitServiceDelegate

- (void)accountKitService:(AccountKitService *)accountKitService didSuccessfullyGetCountryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber authorizationCode:(NSString *)authorizationCode state:(NSString *)state {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSNumber *loginReason;

        @try {
            loginReason = objc_getAssociatedObject(self, &ASSOCIATE_KEY_LOGIN_REASON);
        } @finally {
            objc_removeAssociatedObjects(self);
        }

        NSInteger reason = [loginReason integerValue];

        if (reason == LOGIN_REASON_LOGIN_WITH_ANOTHER_ACCOUNT) {
            // Don't have to check if the target phone number is the same with the login one.

            self.processing = @YES;

            // login with authorization code first

            [self.authService loginWithAuthorizationCode:authorizationCode successHandler:^(NSURLResponse *response, NSData *data) {
                // reload to update the current account before showing up user profile view controller or finding available computers
                [self reloadUserData];

                NSUserDefaults *userDefaults = [Utility groupUserDefaults];

                NSNumber *needCreateOrUpdateUserProfile = [userDefaults objectForKey:USER_DEFAULTS_KEY_NEED_CREATE_OR_UPDATE_USER_PROFILE];

                if (needCreateOrUpdateUserProfile && [needCreateOrUpdateUserProfile boolValue]) {
                    self.processing = @NO;

                    // show UserProfileViewController

                    [self.appService showUserProfileViewControllerFromViewController:self showCancelButton:@YES];
                } else {
                    [self findAvailableComputersToConnectWithTryAgainOnInvalidSession:YES connectDirectlyIfOnlyOneFound:YES addNewComputerDirectlyIfNotFound:NO];
                }
            } failureHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                self.processing = @NO;

                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    NSString *message = [AuthService prepareFailedLoginMessageWithResponse:response error:error data:data];

                    [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                });
            }];
        }
    });
}

- (void)accountKitService:(AccountKitService *)accountKitService didFailedGetCountryIdAndPhoneNumberWithResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error authorizationCode:(NSString *)authorizationCode state:(NSString *)state {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *message = [AuthService prepareFailedLoginMessageWithResponse:response error:error data:data];

        [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
    });
}

- (void)accountKitService:(AccountKitService *)accountKitService didFailWithError:(NSError *)error {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *message;

        if (error) {
            message = [NSString stringWithFormat:@"%@\n%@", NSLocalizedString(@"Login failed. Try later.", @""), [error localizedDescription]];
        } else {
            message = NSLocalizedString(@"Login failed. Try later.", @"");
        }

        [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
    });
}

- (void)accountKitServiceDidCanceled:(AccountKitService *)accountKitService {
    NSLog(@"User canceled login with account kit.");
}

@end
