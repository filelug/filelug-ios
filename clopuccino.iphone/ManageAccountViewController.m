#import "ManageAccountViewController.h"
#import "ChangeEmailViewController.h"
#import "AppService.h"
#import "FilelugUtility.h"
#import "ChangeNicknameViewController.h"
#import "DownloadHistoryViewController.h"
#import "UploadHistoryViewController.h"
#import "MenuTabBarController.h"
#import "AppDelegate.h"
#import "AccountKitServiceDelegate.h"
#import "StartupViewController.h"

// -------------- section 0 -----------------
#define kAccountSectionIndexOfProfile           0

#define kAccountRowIndexOfPhoneNumber           0
#define kAccountRowIndexOfEmailAddress          1
#define kAccountRowIndexOfNickname              2

// -------------- section 1 -----------------
#define kAccountSectionIndexOfHistory           1

#define kAccountRowIndexOfDownloadedHistory     0
#define kAccountRowIndexOfUploadedHistory       1

// -------------- section 2 -----------------
#define kAccountSectionIndexOfDeletion          2

#define kAccountRowIndexOfDeleteAccount         0

// row key for NSDictionary
#define kAccountRowKeyCellStyle                                    @"style"
#define kAccountRowKeyLabelText                                    @"label_text"
#define kAccountRowKeyLabelTextAdjustsFontSizeToFitWidth           @"label_text_adjusts_font_size_to_fit_width"
#define kAccountRowKeyLabelTextNumberOfLines                       @"label_text_number_of_lines"
#define kAccountRowKeyDetailLabelText                              @"detail_label_text"
#define kAccountRowKeyDetailLabelTextColor                         @"detail_label_text_color"
#define kAccountRowKeyDetailLabelTextAdjustsFontSizeToFitWidth     @"detail_label_text_adjusts_font_size_to_fit_width"
#define kAccountRowKeyDetailLabelTextNumberOfLines                 @"detail_label_text_number_of_lines"
#define kAccountRowKeyImage                                        @"image"
#define kAccountRowKeyAccessoryType                                @"accessory_type"
#define kAccountRowKeyAccessoryView                                @"accessory_view"
#define kAccountRowKeySelectionStyle                               @"selection_style"
#define kAccountRowKeyUserInteractionEnabled                       @"user_interaction_enabled"

#define kNotSetText NSLocalizedString(@"(Not Set2)", @"")

@interface ManageAccountViewController () <AccountKitServiceDelegate>

// elements of NSString
@property(nonatomic, strong) NSArray *tableSections;

// elements of NSArray, which contains NSDictionary contains row keys
@property(nonatomic, strong) NSArray *tableSectionRows;

@property(nonatomic, strong) UserDao *userDao;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) UserComputerService *userComputerService;

@property(nonatomic, strong) UserComputerDao *userComputerDao;

@property(nonatomic, strong) AppService *appService;

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

@property(nonatomic, strong) CountryService *countryService;

@property(nonatomic, strong) AccountKitService *accountKitService;

@end

@implementation ManageAccountViewController

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
            NSLocalizedString(@"Profiles", @""),
            NSLocalizedString(@"History", @""),
            NSLocalizedString(@"Deletion", @"")
    ];

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSArray *sectionRows0 = @[
            // Phone Number
            @{
                    kAccountRowKeyCellStyle: @(UITableViewCellStyleSubtitle),                                                 // NSNumber, wrapping NSInteger
                    kAccountRowKeyLabelText: NSLocalizedString(@"Phone number", @""),                                                                 // NSString
                    kAccountRowKeyLabelTextAdjustsFontSizeToFitWidth: @(NO),                                                  // NSNumber, wrapping BOOL
                    kAccountRowKeyLabelTextNumberOfLines: @(1),                                                               // NSNumber, wrapping NSInteger

                    // DEBUG: For Video Recording
//                    kAccountRowKeyDetailLabelText : @"0968897603 (TW)",
                    kAccountRowKeyDetailLabelText: [self preparePhoneNumberLabelTextWithUserDefaults:userDefaults],           // NSString
                    kAccountRowKeyDetailLabelTextAdjustsFontSizeToFitWidth: @(NO),                                            // NSNumber, wrapping BOOL
                    kAccountRowKeyDetailLabelTextNumberOfLines: @(0),                                                         // NSNumber, wrapping NSInteger
                    kAccountRowKeyImage: @"iphone5-active",                                                                   // NSString
                    kAccountRowKeyAccessoryType: @(UITableViewCellAccessoryNone),                                             // NSNumber, wrapping NSInteger
                    kAccountRowKeyUserInteractionEnabled: @NO                                                                 // NSNumber, wrapping BOOL
            },
            // Email
            @{
                    kAccountRowKeyCellStyle: @(UITableViewCellStyleSubtitle),
                    kAccountRowKeyLabelText: [self prepareEmailLableWithUserDefaults:userDefaults],
                    kAccountRowKeyLabelTextAdjustsFontSizeToFitWidth: @(NO),
                    kAccountRowKeyLabelTextNumberOfLines: @(1),
                    kAccountRowKeyDetailLabelText: [self prepareEmailWithUserDefaults:userDefaults],
                    kAccountRowKeyDetailLabelTextColor: [self prepareEmailTextColorWithUserDefaults:userDefaults],
                    kAccountRowKeyDetailLabelTextAdjustsFontSizeToFitWidth: @(NO),
                    kAccountRowKeyDetailLabelTextNumberOfLines: @(0),
                    kAccountRowKeyImage: @"email-active",
                    kAccountRowKeyAccessoryType: @(UITableViewCellAccessoryDisclosureIndicator),
                    kAccountRowKeyUserInteractionEnabled: @([userDefaults objectForKey:USER_DEFAULTS_KEY_USER_ID] != nil)
            },
            // Nickname
            @{
                    kAccountRowKeyCellStyle: @(UITableViewCellStyleSubtitle),
                    kAccountRowKeyLabelText: NSLocalizedString(@"Nickname", @""),
                    kAccountRowKeyLabelTextAdjustsFontSizeToFitWidth: @(NO),
                    kAccountRowKeyLabelTextNumberOfLines: @(1),
                    kAccountRowKeyDetailLabelText: [self prepareNicknameWithUserDefaults:userDefaults],
                    kAccountRowKeyDetailLabelTextAdjustsFontSizeToFitWidth: @(NO),
                    kAccountRowKeyDetailLabelTextNumberOfLines: @(0),
                    kAccountRowKeyImage: @"id-card",
                    kAccountRowKeyAccessoryType: @(UITableViewCellAccessoryDisclosureIndicator),
                    kAccountRowKeyUserInteractionEnabled: @([userDefaults objectForKey:USER_DEFAULTS_KEY_USER_ID] != nil)
            }
    ];

    NSArray *sectionRows1 = @[
            // Downloaded files history
            @{
                    kAccountRowKeyCellStyle: @(UITableViewCellStyleDefault),                                                  // NSNumber, wrapping NSInteger
                    kAccountRowKeyLabelText: NSLocalizedString(@"Downloaded Files History", @""),                                                     // NSString
                    kAccountRowKeyLabelTextAdjustsFontSizeToFitWidth: @(NO),                                                  // NSNumber, wrapping BOOL
                    kAccountRowKeyLabelTextNumberOfLines: @(0),                                                               // NSNumber, wrapping NSInteger
                    kAccountRowKeyImage: @"download-history",                                                                 // NSString
                    kAccountRowKeyAccessoryType: @(UITableViewCellAccessoryDisclosureIndicator),                              // NSNumber, wrapping NSInteger
                    kAccountRowKeyUserInteractionEnabled: @([userDefaults objectForKey:USER_DEFAULTS_KEY_USER_ID] != nil)     // NSNumber, wrapping BOOL
            },
            // Uploaded files history
            @{
                    kAccountRowKeyCellStyle: @(UITableViewCellStyleDefault),
                    kAccountRowKeyLabelText: NSLocalizedString(@"Uploaded Files History", @""),
                    kAccountRowKeyLabelTextAdjustsFontSizeToFitWidth: @(NO),
                    kAccountRowKeyLabelTextNumberOfLines: @(0),
                    kAccountRowKeyImage: @"upload-history",
                    kAccountRowKeyAccessoryType: @(UITableViewCellAccessoryDisclosureIndicator),
                    kAccountRowKeyUserInteractionEnabled: @([userDefaults objectForKey:USER_DEFAULTS_KEY_USER_ID] != nil)
            }
    ];

    NSArray *sectionRows2 = @[
            // Delete Account
            @{
                    kAccountRowKeyCellStyle : @(UITableViewCellStyleDefault),
                    kAccountRowKeyLabelText : NSLocalizedString(@"Delete Account", @""),
                    kAccountRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kAccountRowKeyLabelTextNumberOfLines : @(1),
                    kAccountRowKeyDetailLabelText : @"",
                    kAccountRowKeyImage : @"delete-account",
                    kAccountRowKeyAccessoryType : @(UITableViewCellAccessoryNone),
                    kAccountRowKeyUserInteractionEnabled : @([userDefaults objectForKey:USER_DEFAULTS_KEY_USER_ID] != nil && ![[userDefaults objectForKey:USER_DEFAULTS_KEY_USER_ID] isEqualToString:DEMO_ACCOUNT_USER_ID])
            }
    ];

    _tableSectionRows = @[sectionRows0, sectionRows1, sectionRows2];
}

- (NSString *)preparePhoneNumberLabelTextWithUserDefaults:(NSUserDefaults *)userDefaults {
    NSString *phoneNumberLabelText;

    NSNumber *currentCountryCode = [userDefaults objectForKey:USER_DEFAULTS_KEY_COUNTRY_CODE];
    NSString *currentPhoneNumber = [userDefaults stringForKey:USER_DEFAULTS_KEY_PHONE_NUMBER];

    if (currentCountryCode && currentPhoneNumber) {
        phoneNumberLabelText = [CountryService stringRepresentationWithCountryCode:currentCountryCode phoneNumber:currentPhoneNumber];
    } else {
        phoneNumberLabelText = kNotSetText;
    }

    return phoneNumberLabelText;
}

- (NSString *)prepareEmailLableWithUserDefaults:(NSUserDefaults *)userDefaults {
    NSNumber *emailIsVerified = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_EMAIL_IS_VERIFIED];

    return (emailIsVerified && [emailIsVerified boolValue]) ? NSLocalizedString(@"email", @"") : NSLocalizedString(@"email(not verified)", @"");
}

- (UIColor *)prepareEmailTextColorWithUserDefaults:(NSUserDefaults *)userDefaults {
    NSNumber *emailIsVerified = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_EMAIL_IS_VERIFIED];

    return (emailIsVerified && [emailIsVerified boolValue]) ? [UIColor aquaColor] : [UIColor redColor];
}

- (NSString *)prepareEmailWithUserDefaults:(NSUserDefaults *)userDefaults {
    NSString *email = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_EMAIL];

    return email ? email : kNotSetText;
}

- (NSString *)prepareNicknameWithUserDefaults:(NSUserDefaults *)userDefaults {
    NSString *nickname = [userDefaults stringForKey:USER_DEFAULTS_KEY_NICKNAME];

    return nickname ? nickname : kNotSetText;
}

- (void)reloadUserData {
    [self prepareTableViewCells];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
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
    return TABLE_VIEW_CELL_ROW_HEIGHT_FOR_MEDIUM_CONTENT_SIZE_CATEGORY;
//    return 60;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat height;

    if ([self.preferredContentSizeCategoryService isXXLargeContentSizeCategory]) {
        height = TABLE_VIEW_CELL_ROW_HEIGHT_FOR_XX_LARGE_CONTENT_SIZE_CATEGORY;
    } else if ([self.preferredContentSizeCategoryService isLargeContentSizeCategory]) {
        height = TABLE_VIEW_CELL_ROW_HEIGHT_FOR_LARGE_CONTENT_SIZE_CATEGORY;
    } else {
        height = TABLE_VIEW_CELL_ROW_HEIGHT_FOR_MEDIUM_CONTENT_SIZE_CATEGORY;
    }

    return height;
//    return 60;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellDefaultIdentifier = @"ManageAccountCellDefault";
    static NSString *CellSubtitleIdentifier = @"ManageAccountCellSubtitle";
//    static NSString *CellValue1Identifier = @"ManageAccountCellValue1";

    UITableViewCell *cell;

    // Configure the cell
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;

    NSDictionary *rowDictionary = self.tableSectionRows[(NSUInteger) section][(NSUInteger) row];

    if (rowDictionary) {
        // cell style

        NSNumber *cellStyle = rowDictionary[kAccountRowKeyCellStyle];

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
            default:
                reuseIdentifier = CellDefaultIdentifier;

                textLabelFont = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
                textLabelTextColor = [UIColor darkTextColor];
                detailLabelFont = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
                detailLabelTextColor = [UIColor aquaColor];
        }

        cell = [Utility tableView:tableView createOrDequeueCellWithStyle:style reuseIdentifier:reuseIdentifier];

        // configure the preferred font

        cell.textLabel.font = textLabelFont;
        cell.textLabel.textColor = textLabelTextColor;

        cell.detailTextLabel.font = detailLabelFont;
        cell.detailTextLabel.textColor = detailLabelTextColor;

        // specical detail text color

        UIColor *specialDetailTextLabelColor = rowDictionary[kAccountRowKeyDetailLabelTextColor];

        if (specialDetailTextLabelColor) {
            cell.detailTextLabel.textColor = specialDetailTextLabelColor;
        }

        // label text

        [cell.textLabel setText:rowDictionary[kAccountRowKeyLabelText]];

        // kAccountRowKeyLabelTextNumberOfLines

        NSNumber *labelTextNumberOfLines = rowDictionary[kAccountRowKeyLabelTextNumberOfLines];

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

        // kAccountRowKeyLabelTextAdjustsFontSizeToFitWidth

        NSNumber *labelTextAdjustsFontSizeToFitWidth = rowDictionary[kAccountRowKeyLabelTextAdjustsFontSizeToFitWidth];

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
            [cell.detailTextLabel setText:rowDictionary[kAccountRowKeyDetailLabelText]];
        } else {
            [cell.detailTextLabel setText:@""];
        }

        // kAccountRowKeyDetailLabelTextNumberOfLines

        NSNumber *detailLabelTextNumberOfLines = rowDictionary[kAccountRowKeyDetailLabelTextNumberOfLines];

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

        // kAccountRowKeyDetailLabelTextAdjustsFontSizeToFitWidth

        NSNumber *detailLabelTextAdjustsFontSizeToFitWidth = rowDictionary[kAccountRowKeyDetailLabelTextAdjustsFontSizeToFitWidth];

        if (detailLabelTextAdjustsFontSizeToFitWidth) {
            cell.detailTextLabel.adjustsFontSizeToFitWidth = [detailLabelTextAdjustsFontSizeToFitWidth boolValue];

            if (cell.detailTextLabel.adjustsFontSizeToFitWidth) {
                cell.detailTextLabel.minimumScaleFactor = 0.5;
            }
        } else {
            cell.detailTextLabel.adjustsFontSizeToFitWidth = NO;
        }

        // image

        NSString *imageName = rowDictionary[kAccountRowKeyImage];

        if (imageName) {
            UIImage *image = [UIImage imageNamed:imageName];

            [cell.imageView setImage:image];
        } else {
            [cell.imageView setImage:nil];
        }

        // accessory type

        NSNumber *accessoryType = rowDictionary[kAccountRowKeyAccessoryType];

        if (accessoryType) {
            [cell setAccessoryType:(UITableViewCellAccessoryType) [accessoryType integerValue]];
        } else {
            [cell setAccessoryType:UITableViewCellAccessoryNone];
        }

        // accessory view - only if cell accessory type is UITableViewCellAccessoryNone

        if ([cell accessoryType] == UITableViewCellAccessoryNone) {
            [cell setAccessoryView:rowDictionary[kAccountRowKeyAccessoryView]];
        }

        // selection style - default Blue

        NSNumber *selectionStyle = rowDictionary[kAccountRowKeySelectionStyle];

        if (selectionStyle) {
            [cell setSelectionStyle:(UITableViewCellSelectionStyle) [selectionStyle integerValue]];
        } else {
            [cell setSelectionStyle:UITableViewCellSelectionStyleBlue];
        }

        // user interaction enabled

        NSNumber *userInteractionEnabled = rowDictionary[kAccountRowKeyUserInteractionEnabled];

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

    if (section == kAccountSectionIndexOfProfile) {
        if (row == kAccountRowIndexOfEmailAddress) {
            // Email

            ChangeEmailViewController *changeEmailViewController = [Utility instantiateViewControllerWithIdentifier:@"ChangeEmail"];

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.navigationController pushViewController:changeEmailViewController animated:YES];
            });
        } else if (row == kAccountRowIndexOfNickname) {
            // Nickname

            ChangeNicknameViewController *changeNicknameViewController = [Utility instantiateViewControllerWithIdentifier:@"ChangeNickname"];

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.navigationController pushViewController:changeNicknameViewController animated:YES];
            });
        }
    } else if (section == kAccountSectionIndexOfHistory) {
        if (row == kAccountRowIndexOfDownloadedHistory) {
            DownloadHistoryViewController *downloadHistoryViewController = [Utility instantiateViewControllerWithIdentifier:@"DownloadHistory"];

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.navigationController pushViewController:downloadHistoryViewController animated:YES];
            });
        } else if (row == kAccountRowIndexOfUploadedHistory) {
            UploadHistoryViewController *uploadHistoryViewController = [Utility instantiateViewControllerWithIdentifier:@"UploadHistory"];

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.navigationController pushViewController:uploadHistoryViewController animated:YES];
            });
        }
    } else if (section == kAccountSectionIndexOfDeletion) {
        if (row == kAccountRowIndexOfDeleteAccount) {
            // Check if current user computer contains unfinished uploads or downloads before deleting this or other account

            NSString *actionDisplayName = [NSLocalizedString(@"Delete Account", @"") lowercaseString];

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self.authService checkNoRunningFileTransfersWithActionDisplayName:actionDisplayName inViewController:self completedHandler:^{
                    [self showAccountActionSheetToDeleteWithAnotherAccountWithIndexPath:indexPath];
                }];
            });
        }
    }
}

- (void)showAccountActionSheetToDeleteWithAnotherAccountWithIndexPath:(NSIndexPath *)indexPath {
    NSString *title = NSLocalizedString(@"Choose Account to Delete", @"");

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
                [self onSelectOtherAccountToDeleteWithCountryCode:countryCode phoneNumber:phoneNumber];
            }];

            [actionSheet addAction:countryAndPhoneNumberAction];
        }
    }

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:nil];

    [actionSheet addAction:cancelAction];

    if ([self isVisible]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIView *sourceView;
            CGRect sourceRect;
            
            if (indexPath && [self.tableView cellForRowAtIndexPath:indexPath]) {
                UITableViewCell *selectedCell = [self.tableView cellForRowAtIndexPath:indexPath]; // must be called from main thread only
                
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

- (void)onSelectOtherAccountToDeleteWithCountryCode:(NSNumber *)countryCode phoneNumber:(NSString *)phoneNumber {
    if (countryCode && phoneNumber) {
        NSString *messageTitle = NSLocalizedString(@"Identification", @"");

        NSString *buttonTitle = NSLocalizedString(@"Verify", @"");

        NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Authenticate Before Deleting Account", @""), buttonTitle];

        [Utility viewController:self alertWithMessageTitle:messageTitle messageBody:message actionTitle:buttonTitle containsCancelAction:YES delayInSeconds:0 actionHandler:^(UIAlertAction *action) {
            // Login with Facebook Account Kit

            NSString *inputState = [[NSUUID UUID] UUIDString];

            [self.accountKitService startLoginProcessWithState:inputState countryCode:countryCode phoneNumber:phoneNumber];
        }];
    }
}

#pragma mark - AccountKitServiceDelegate

- (void)accountKitService:(AccountKitService *)accountKitService didSuccessfullyGetCountryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber authorizationCode:(NSString *)authorizationCode state:(NSString *)state {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.processing = @YES;

        // login with authorization code before deleting

        [self.authService loginWithAuthorizationCode:authorizationCode successHandler:^(NSURLResponse *response, NSData *data) {
            [self confirmDeleteCurrentUser];
        } failureHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
            self.processing = @NO;

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSString *message = [AuthService prepareFailedLoginMessageWithResponse:response error:error data:data];

                [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
            });
        }];
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

- (void)confirmDeleteCurrentUser {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSString *userId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_ID];
        NSString *phoneNumber = [userDefaults objectForKey:USER_DEFAULTS_KEY_PHONE_NUMBER];
        NSString *nickname = [userDefaults objectForKey:USER_DEFAULTS_KEY_NICKNAME];
        NSString *sessionId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

        [self.authService checkIfUserDeletableWithSession:sessionId userId:userId completionHandler:^(NSData *dData, NSURLResponse *dResponse, NSError *dError) {
            self.processing = @NO;

            NSInteger statusCode = [(NSHTTPURLResponse *) dResponse statusCode];

            if (statusCode == 200) {
                // list the names of the computers of which the user is the administrator
                // and no other users are approved to connect to.
                NSString *message;

                NSString *messageSuffix = [NSString stringWithFormat:NSLocalizedString(@"Confirm Deleting User", @""), nickname, phoneNumber];

                NSString *responseString = [[NSString alloc] initWithData:dData encoding:NSUTF8StringEncoding];

                if (responseString && responseString.length > 0) {
                    NSString *messagePreffix = [NSString stringWithFormat:NSLocalizedString(@"Reset computer application", @""), responseString];

                    message = [NSString stringWithFormat:@"%@\n\n%@", messagePreffix, messageSuffix];
                } else {
                    message = messageSuffix;
                }

                UIAlertController *confirmAlertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Confirm Delete", @"") message:message preferredStyle:UIAlertControllerStyleAlert];

                UIAlertAction *yesAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"YES", @"") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        [self deleteUserWithUserId:userId sessionId:sessionId];
                    });
                }];
                [confirmAlertController addAction:yesAction];

                UIAlertAction *noAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"NO", @"") style:UIAlertActionStyleCancel handler:nil];
                [confirmAlertController addAction:noAction];

                if ([self isVisible]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [confirmAlertController presentWithViewController:self sourceView:nil sourceRect:CGRectNull barButtonItem:nil animated:YES completion:nil];
                    });
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [confirmAlertController presentWithAnimated:YES];
                    });
                }
            } else {
                NSString *responseMessage = [[NSString alloc] initWithData:dData encoding:NSUTF8StringEncoding];

                NSString *errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Failed to delete user. Status:%d. %@", @""), statusCode, (responseMessage ? responseMessage : @"")];

                [Utility viewController:self alertWithMessageTitle:@"" messageBody:errorMessage actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
            }
        }];
    });
}

- (void)deleteUserWithUserId:(nonnull NSString *)userId sessionId:(nonnull NSString *)sessionId {
    self.processing = @YES;

    [self.authService deleteUserWithSession:sessionId userId:userId completionHandler:^(NSData *dData, NSURLResponse *dResponse, NSError *dError) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSInteger statusCode = [(NSHTTPURLResponse *) dResponse statusCode];

            if (statusCode == 200) {
                @try {
                    // delete local data for this user

                    NSError *userComputerFoundError;
                    NSArray<UserComputerWithoutManaged *> *userComputerWithoutManagedArray = [self.userComputerDao findUserComputersForUserId:userId error:&userComputerFoundError];

                    if (userComputerWithoutManagedArray && [userComputerWithoutManagedArray count] > 0) {
                        for (UserComputerWithoutManaged *userComputerWithoutManaged in userComputerWithoutManagedArray) {
                            NSString *userComputerId = userComputerWithoutManaged.userComputerId;

                            if (userComputerId && userComputerId.length > 0) {
                                NSError *pathDeleteError;
                                [DirectoryService deleteLocalCachedDataWithUserComputerId:userComputerId error:&pathDeleteError];

                                if (pathDeleteError) {
                                    NSLog(@"Failed to delete cached data with computer '%@'\n%@", userComputerWithoutManaged.computerName, [pathDeleteError userInfo]);
                                }
                            }
                        }
                    }

                    // delete user from local db, and the related UserComputer with the same user will be deleted cascade

                    [self.userDao deleteUserByUserId:userId completionHandler:nil];

                    // If the user to delete is the curren one in preferences,
                    // clear user data in preferences, also clear computer-related data in preferences

                    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

                    NSString *userIdInPreferences = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_ID];

                    if (userIdInPreferences && [userIdInPreferences isEqualToString:userId]) {
                        [Utility deleteUserDataWithUserDefaults:userDefaults];
                        [Utility deleteComputerDataWithUserDefaults:userDefaults];
                    }
                } @finally {
                    self.processing = @NO;

                    // If no user left in local db, show StartupViewController.
                    // If there's at least one user left in local db, popup to SettingsViewController and it shows UIActionSheet so user can choose one

                    NSNumber *userCount = [self.userDao countAllUsers];

                    if (!userCount || [userCount integerValue] < 1) {
                        // no user left - dismiss MenuTabBarController and show StartupViewController
                        // this will lead to show StartupViewController even if there's no one initiated when APP started.

                        NSString *successMessage = NSLocalizedString(@"Successfully deleted user and create new account", @"");

                        [Utility viewController:self alertWithMessageTitle:@"" messageBody:successMessage actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:^(UIAlertAction *action) {
                            StartupViewController *startupViewController = [Utility instantiateViewControllerWithIdentifier:@"Startup"];

                            dispatch_async(dispatch_get_main_queue(), ^{
                                // Show StartupViewController on top of MenuTabBarController

                                [self presentViewController:startupViewController animated:YES completion:nil];
                            });
                        }];
                    } else {
                        // at least one user left - show action sheet to choose one, or create a new one

                        NSString *successMessage = NSLocalizedString(@"Successfully deleted user and login other account", @"");

                        [Utility viewController:self alertWithMessageTitle:@"" messageBody:successMessage actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:^(UIAlertAction *action) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self.navigationController popViewControllerAnimated:YES];
                            });
                        }];
                    }
                }
            } else {
                self.processing = @NO;

                NSString *responseMessage = [[NSString alloc] initWithData:dData encoding:NSUTF8StringEncoding];

                NSString *errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Failed to delete user. Status:%d. %@", @""), statusCode, (responseMessage ? responseMessage : @"")];

                [Utility viewController:self alertWithMessageTitle:@"" messageBody:errorMessage actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
            }
        });
    }];
}

@end
