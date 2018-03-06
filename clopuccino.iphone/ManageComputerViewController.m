#import "ManageComputerViewController.h"
#import "RootDirectoryViewController.h"
#import "AppService.h"
#import "FilelugUtility.h"

// -------------- section 0 -----------------
#define kComputerSectionIndexOfProfile              0

#define kComputerRowIndexOfComputerName             0

// -------------- section 2 -----------------
#define kComputerSectionIndexOfUploadGroup          2

#define kComputerRowIndexOfUploadDirectory          0
#define kComputerRowIndexOfSubdirectoryName         1
#define kComputerRowIndexOfDescription              2
#define kComputerRowIndexOfUploadNotification       3

// -------------- section 3 -----------------
#define kComputerSectionIndexOfDownloadGroup        3

#define kComputerRowIndexOfDownloadNotification     0

// -------------- section 4 -----------------
#define kComputerSectionIndexOfDeletion             4

#define kComputerRowIndexOfDeleteComputer           0

// row key for NSDictionary
#define kComputerRowKeyCellStyle                                    @"style"
#define kComputerRowKeyLabelText                                    @"label_text"
#define kComputerRowKeyLabelTextAdjustsFontSizeToFitWidth           @"label_text_adjusts_font_size_to_fit_width"
#define kComputerRowKeyLabelTextNumberOfLines                       @"label_text_number_of_lines"
#define kComputerRowKeyDetailLabelText                              @"detail_label_text"
#define kComputerRowKeyDetailLabelTextAdjustsFontSizeToFitWidth     @"detail_label_text_adjusts_font_size_to_fit_width"
#define kComputerRowKeyDetailLabelTextNumberOfLines                 @"detail_label_text_number_of_lines"
#define kComputerRowKeyImage                                        @"image"
#define kComputerRowKeyAccessoryType                                @"accessory_type"
#define kComputerRowKeyAccessoryView                                @"accessory_view"
#define kComputerRowKeySelectionStyle                               @"selection_style"
#define kComputerRowKeyUserInteractionEnabled                       @"user_interaction_enabled"

#define kNotSetText NSLocalizedString(@"(Not Set2)", @"")

@interface ManageComputerViewController ()

@property(nonatomic, strong) NSString *uploadDirectory;

@property(nonatomic, strong) UploadSubdirectoryService *uploadSubdirectoryService;

@property(nonatomic, strong) UploadNotificationService *uploadNotificationService;

@property(nonatomic, strong) DownloadNotificationService *downloadNotificationService;

// elements of NSString
@property(nonatomic, strong) NSArray *tableSections;

// elements of NSArray, which contains NSDictionary contains row keys
@property(nonatomic, strong) NSArray *tableSectionRows;

@property(nonatomic, strong) UserDao *userDao;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) UserComputerService *userComputerService;

@property(nonatomic, strong) UserComputerDao *userComputerDao;

@property(nonatomic, strong) UISwitch *showHiddenSwitch;

@property(nonatomic, strong) AppService *appService;

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

@end

@implementation ManageComputerViewController

@synthesize processing;

@synthesize progressView;

- (void)viewDidLoad {
    [super viewDidLoad];

    self.processing = @NO;

    [Utility viewController:self useNavigationLargeTitles:YES];

    _preferredContentSizeCategoryService = [[PreferredContentSizeCategoryService alloc] init];

    _showHiddenSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];

    [self prepareTableViewCells];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *userComputerId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

    self.uploadDirectory = userComputerId ? [userDefaults objectForKey:USER_DEFAULTS_KEY_UPLOAD_DIRECTORY] : @"";

    self.uploadSubdirectoryService = userComputerId ? [[UploadSubdirectoryService alloc] initWithPersistedTypeAndValue] : nil;

    self.uploadDescriptionService = userComputerId ? [[UploadDescriptionService alloc] initWithPersistedTypeAndValue] : nil;

    self.uploadNotificationService = userComputerId ? [[UploadNotificationService alloc] initWithPersistedType] : nil;

    self.downloadNotificationService = userComputerId ? [[DownloadNotificationService alloc] initWithPersistedType] : nil;

    [_showHiddenSwitch addTarget:self action:@selector(switchShowHidden:) forControlEvents:UIControlEventValueChanged];

    // adding observers

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangePreferredContentSize:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];

    [self addObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    if (![userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.navigationController popViewControllerAnimated:YES];
        });
    } else {
        [self reloadUserData];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) context:NULL];

    [self.showHiddenSwitch removeTarget:self action:@selector(switchShowHidden:) forControlEvents:UIControlEventValueChanged];

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

- (BOOL)needPersistIfChanged {
    return YES;
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
            NSLocalizedString(@"File Browse", @""),
            NSLocalizedString(@"File Upload", @""),
            NSLocalizedString(@"File Download", @""),
            NSLocalizedString(@"Deletion", @"")
    ];

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSArray *sectionRows0 = @[
            // ComputerName
            @{
                    kComputerRowKeyCellStyle : @(UITableViewCellStyleSubtitle),
                    kComputerRowKeyLabelText : NSLocalizedString(@"Computer Name", @""),
                    kComputerRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kComputerRowKeyLabelTextNumberOfLines : @(1),
                    kComputerRowKeyDetailLabelText : [self prepareComputerNameWithUserDefaults:userDefaults],
                    kComputerRowKeyDetailLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kComputerRowKeyDetailLabelTextNumberOfLines : @(0),
                    kComputerRowKeyImage : @"computer",
                    kComputerRowKeyAccessoryType : @(UITableViewCellAccessoryNone),
                    kComputerRowKeyUserInteractionEnabled : @([userDefaults objectForKey:USER_DEFAULTS_KEY_COMPUTER_ID] != nil)
            }
    ];

    NSArray *sectionRows1 = @[
            // If Show Hidden Files - make sure self.showHiddenSwitch already initiated
            @{
                    kComputerRowKeyCellStyle : @(UITableViewCellStyleSubtitle),
                    kComputerRowKeyLabelText : NSLocalizedString(@"If Show Hidden Files", @""),
                    kComputerRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kComputerRowKeyLabelTextNumberOfLines : @(1),
                    kComputerRowKeyDetailLabelText : [self prepareShowHiddenValueWithUserDefaults:userDefaults andUpdateValueWithSwitch:self.showHiddenSwitch],
                    kComputerRowKeyDetailLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kComputerRowKeyDetailLabelTextNumberOfLines : @(0),
                    kComputerRowKeyImage : @"hidden",
                    kComputerRowKeyAccessoryType : @(UITableViewCellAccessoryNone),
                    kComputerRowKeyAccessoryView : self.showHiddenSwitch,
                    kComputerRowKeySelectionStyle : @(UITableViewCellSelectionStyleNone),
                    kComputerRowKeyUserInteractionEnabled : @([userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID] != nil)
            }
    ];

    NSArray *sectionRows2 = @[
            // Upload Directory
            @{
                    kComputerRowKeyCellStyle : @(UITableViewCellStyleSubtitle),                                                         // NSNumber, wrapping NSInteger
                    kComputerRowKeyLabelText : NSLocalizedString(@"Upload Directory", @""),                                                                     // NSString
                    kComputerRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),                                                          // NSNumber, wrapping BOOL
                    kComputerRowKeyLabelTextNumberOfLines : @(1),                                                                       // NSNumber, wrapping NSInteger
                    kComputerRowKeyDetailLabelText : [self prepareUploadDirectory],                                                     // NSString
                    kComputerRowKeyDetailLabelTextAdjustsFontSizeToFitWidth : @(NO),                                                   // NSNumber, wrapping BOOL
                    kComputerRowKeyDetailLabelTextNumberOfLines : @(0),                                                                 // NSNumber, wrapping NSInteger
                    kComputerRowKeyImage : @"upload",                                                                                   // NSString
                    kComputerRowKeyAccessoryType : @(UITableViewCellAccessoryDisclosureIndicator),                                      // NSNumber, wrapping NSInteger
                    kComputerRowKeyUserInteractionEnabled : @([userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID] != nil)    // NSNumber, wrapping BOOL
            },
            // Upload Subdirectory Name
            @{
                    kComputerRowKeyCellStyle : @(UITableViewCellStyleSubtitle),
                    kComputerRowKeyLabelText : NSLocalizedString(@"Subdirectory Name", @""),
                    kComputerRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kComputerRowKeyLabelTextNumberOfLines : @(1),
                    kComputerRowKeyDetailLabelText : [self prepareUploadSubdirectoryDisplayText],
                    kComputerRowKeyDetailLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kComputerRowKeyDetailLabelTextNumberOfLines : @(0),
                    kComputerRowKeyImage : @"folder-add",
                    kComputerRowKeyAccessoryType : @(UITableViewCellAccessoryNone),
                    kComputerRowKeyUserInteractionEnabled : @([userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID] != nil)
            },
            // Upload Description
            @{
                    kComputerRowKeyCellStyle : @(UITableViewCellStyleSubtitle),
                    kComputerRowKeyLabelText : NSLocalizedString(@"Description", @""),
                    kComputerRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kComputerRowKeyLabelTextNumberOfLines : @(1),
                    kComputerRowKeyDetailLabelText : [self prepareUploadDescriptionDisplayText],
                    kComputerRowKeyDetailLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kComputerRowKeyDetailLabelTextNumberOfLines : @(0),
                    kComputerRowKeyImage : @"note-write",
                    kComputerRowKeyAccessoryType : @(UITableViewCellAccessoryNone),
                    kComputerRowKeyUserInteractionEnabled : @([userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID] != nil)
            },
            // Upload Notification
            @{
                    kComputerRowKeyCellStyle : @(UITableViewCellStyleSubtitle),
                    kComputerRowKeyLabelText : NSLocalizedString(@"Upload Notification", @""),
                    kComputerRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kComputerRowKeyLabelTextNumberOfLines : @(1),
                    kComputerRowKeyDetailLabelText : [self prepareUploadNotificationDisplayText],
                    kComputerRowKeyDetailLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kComputerRowKeyDetailLabelTextNumberOfLines : @(0),
                    kComputerRowKeyImage : @"bell",
                    kComputerRowKeyAccessoryType : @(UITableViewCellAccessoryNone),
                    kComputerRowKeyUserInteractionEnabled : @([userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID] != nil)
            }
    ];

    NSArray *sectionRows3 = @[
            // Download Notification
            @{
                    kComputerRowKeyCellStyle : @(UITableViewCellStyleSubtitle),
                    kComputerRowKeyLabelText : NSLocalizedString(@"Download Notification", @""),
                    kComputerRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kComputerRowKeyLabelTextNumberOfLines : @(1),
                    kComputerRowKeyDetailLabelText : [self prepareDownloadNotificationDisplayText],
                    kComputerRowKeyDetailLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kComputerRowKeyDetailLabelTextNumberOfLines : @(0),
                    kComputerRowKeyImage : @"bell",
                    kComputerRowKeyAccessoryType : @(UITableViewCellAccessoryNone),
                    kComputerRowKeyUserInteractionEnabled : @([userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID] != nil)
            }
    ];

    NSArray *sectionRows4 = @[
            // Delete Computer
            @{
                    kComputerRowKeyCellStyle : @(UITableViewCellStyleDefault),
                    kComputerRowKeyLabelText : NSLocalizedString(@"Delete Computer", @""),
                    kComputerRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kComputerRowKeyLabelTextNumberOfLines : @(1),
                    kComputerRowKeyDetailLabelText : @"",
                    kComputerRowKeyImage : @"delete-computer",
                    kComputerRowKeyAccessoryType : @(UITableViewCellAccessoryNone),
                    kComputerRowKeyUserInteractionEnabled : @([userDefaults objectForKey:USER_DEFAULTS_KEY_USER_ID] != nil && ![[userDefaults objectForKey:USER_DEFAULTS_KEY_USER_ID] isEqualToString:DEMO_ACCOUNT_USER_ID])
            }
    ];

    _tableSectionRows = @[sectionRows0, sectionRows1, sectionRows2, sectionRows3, sectionRows4];
}

- (NSString *)prepareUploadDirectory {
    NSString *uploadDirectory = self.uploadDirectory;

    return uploadDirectory ? uploadDirectory : @"";
}

- (NSString *)prepareUploadSubdirectoryDisplayText {
    NSString *displayText;

    if (self.uploadSubdirectoryService) {
        displayText = [self.uploadSubdirectoryService displayedText];
    } else {
        displayText = @"";
    }

    return displayText;
}

- (NSString *)prepareUploadDescriptionDisplayText {
    NSString *displayText;

    if (self.uploadDescriptionService) {
        displayText = [self.uploadDescriptionService displayedText];
    } else {
        displayText = @"";
    }

    return displayText;
}

- (NSString *)prepareUploadNotificationDisplayText {
    NSString *displayText;

    if (self.uploadNotificationService) {
        displayText = [self.uploadNotificationService name];
    } else {
        displayText = @"";
    }

    return displayText;
}

- (NSString *)prepareDownloadNotificationDisplayText {
    NSString *displayText;

    if (self.downloadNotificationService) {
        displayText = [self.downloadNotificationService name];
    } else {
        displayText = @"";
    }

    return displayText;
}

- (void)switchShowHidden:(id)sender {
    self.processing = @YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UISwitch *showHiddenSwitch = sender;
        BOOL isShowHidden = [showHiddenSwitch isOn];
    
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // update to UserComputer and preferences before invoker service to update value to server

            NSUserDefaults *userDefaults = [Utility groupUserDefaults];

            [userDefaults setBool:isShowHidden forKey:USER_DEFAULTS_KEY_SHOW_HIDDEN];

            NSString *userComputerId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

            if (userComputerId) {
                UserComputerWithoutManaged *userComputerWithoutManaged = [self.userComputerDao findUserComputerForUserComputerId:userComputerId];

                NSNumber *showHiddenInDb = userComputerWithoutManaged.showHidden;

                if (!showHiddenInDb || ([showHiddenInDb boolValue] ^ isShowHidden)) {
                    userComputerWithoutManaged.showHidden = @(isShowHidden);

                    [self.userComputerDao updateUserComputerWithUserComputerWithoutManaged:userComputerWithoutManaged completionHandler:nil];
                }
            }

            [self.userComputerService changeShowHiddenForCurrentSessionWithShowHidden:isShowHidden completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                self.processing = @NO;

                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [self reloadUserData];
                });
            }];
        });
    });
}

- (NSString *)prepareComputerNameWithUserDefaults:(NSUserDefaults *)userDefaults {
    NSString *computerName = [userDefaults stringForKey:USER_DEFAULTS_KEY_COMPUTER_NAME];

    return computerName ? computerName : kNotSetText;
}

- (NSString *)prepareShowHiddenValueWithUserDefaults:(NSUserDefaults *)userDefaults andUpdateValueWithSwitch:(UISwitch *)switchView {
    NSNumber *showHidden = @([userDefaults boolForKey:USER_DEFAULTS_KEY_SHOW_HIDDEN]);

    // load from db if not found, and then update value to USER_DEFAULTS_KEY_SHOW_HIDDEN in user defaults
    if (!showHidden) {
        NSError *fetchError;
        UserWithoutManaged *userWithoutManaged = [self.userDao findActiveUserWithError:&fetchError];

        // react only when the value in db is different than the new one
        if (userWithoutManaged) {
            if (userWithoutManaged.showHidden) {
                showHidden = userWithoutManaged.showHidden;

                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [userDefaults setBool:[showHidden boolValue] forKey:USER_DEFAULTS_KEY_SHOW_HIDDEN];
                });
            } else {
                showHidden = @(NO);

                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [userDefaults setBool:[showHidden boolValue] forKey:USER_DEFAULTS_KEY_SHOW_HIDDEN];

                    userWithoutManaged.showHidden = showHidden;
                    [self.userDao updateUserFromUserWithoutManaged:userWithoutManaged completionHandler:nil];
                });
            }
        } else {
            showHidden = @(NO);

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [userDefaults setBool:[showHidden boolValue] forKey:USER_DEFAULTS_KEY_SHOW_HIDDEN];
            });
        }
    }

    if (switchView) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [switchView setOn:[showHidden boolValue] animated:YES];
        });
    }

    return [showHidden boolValue] ? NSLocalizedString(@"Show hidden files", @"") : NSLocalizedString(@"Do not show hidden files", @"");
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
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat height;

    if (indexPath.section == kComputerSectionIndexOfUploadGroup && indexPath.row == kComputerRowIndexOfUploadDirectory) {
        if ([self.preferredContentSizeCategoryService isXXLargeContentSizeCategory]) {
            height = TABLE_VIEW_CELL_ROW_HEIGHT_FOR_ULTIMATE_LARGE_CONTENT_SIZE_CATEGORY;
        } else if ([self.preferredContentSizeCategoryService isLargeContentSizeCategory]) {
            height = TABLE_VIEW_CELL_ROW_HEIGHT_FOR_XX_LARGE_CONTENT_SIZE_CATEGORY;
        } else if ([self.preferredContentSizeCategoryService isMediumContentSizeCategory]) {
            height = TABLE_VIEW_CELL_ROW_HEIGHT_FOR_XX_LARGE_CONTENT_SIZE_CATEGORY;
        } else {
            height = TABLE_VIEW_CELL_ROW_HEIGHT_FOR_MEDIUM_CONTENT_SIZE_CATEGORY;
        }
    } else {
        if ([self.preferredContentSizeCategoryService isXXLargeContentSizeCategory]) {
            height = TABLE_VIEW_CELL_ROW_HEIGHT_FOR_XX_LARGE_CONTENT_SIZE_CATEGORY;
        } else if ([self.preferredContentSizeCategoryService isLargeContentSizeCategory]) {
            height = TABLE_VIEW_CELL_ROW_HEIGHT_FOR_LARGE_CONTENT_SIZE_CATEGORY;
        } else {
            height = TABLE_VIEW_CELL_ROW_HEIGHT_FOR_MEDIUM_CONTENT_SIZE_CATEGORY;
        }
    }

    return height;

//    CGFloat height;
//
//    if (indexPath.section == kComputerSectionIndexOfUploadGroup && indexPath.row == kComputerRowIndexOfUploadDirectory) {
//        if ([self.preferredContentSizeCategoryService isXXLargeContentSizeCategory]) {
//            height = 100;
//        } else if ([self.preferredContentSizeCategoryService isMediumOrLargeContentSizeCategory]) {
//            height = 80;
//        } else {
//            height = 60;
//        }
//    } else {
//        height = 60;
//    }
//
//    return height;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellDefaultIdentifier = @"ManageComputerCellDefault";
    static NSString *CellSubtitleIdentifier = @"ManageComputerCellSubtitle";
//    static NSString *CellValue1Identifier = @"ManageComputerCellValue1";

    UITableViewCell *cell;

    // Configure the cell
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;

    NSDictionary *rowDictionary = self.tableSectionRows[(NSUInteger) section][(NSUInteger) row];

    if (rowDictionary) {
        // cell style

        NSNumber *cellStyle = rowDictionary[kComputerRowKeyCellStyle];

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

        // label text

        [cell.textLabel setText:rowDictionary[kComputerRowKeyLabelText]];

        // kComputerRowKeyLabelTextNumberOfLines

        NSNumber *labelTextNumberOfLines = rowDictionary[kComputerRowKeyLabelTextNumberOfLines];

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

        // kComputerRowKeyLabelTextAdjustsFontSizeToFitWidth

        NSNumber *labelTextAdjustsFontSizeToFitWidth = rowDictionary[kComputerRowKeyLabelTextAdjustsFontSizeToFitWidth];

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
            [cell.detailTextLabel setText:rowDictionary[kComputerRowKeyDetailLabelText]];
        } else {
            [cell.detailTextLabel setText:nil];
        }

        // kComputerRowKeyDetailLabelTextNumberOfLines

        NSNumber *detailLabelTextNumberOfLines = rowDictionary[kComputerRowKeyDetailLabelTextNumberOfLines];

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

        // kComputerRowKeyDetailLabelTextAdjustsFontSizeToFitWidth

        NSNumber *detailLabelTextAdjustsFontSizeToFitWidth = rowDictionary[kComputerRowKeyDetailLabelTextAdjustsFontSizeToFitWidth];

        if (detailLabelTextAdjustsFontSizeToFitWidth) {
            cell.detailTextLabel.adjustsFontSizeToFitWidth = [detailLabelTextAdjustsFontSizeToFitWidth boolValue];

            if (cell.detailTextLabel.adjustsFontSizeToFitWidth) {
                cell.detailTextLabel.minimumScaleFactor = 0.5;
            }
        } else {
            cell.detailTextLabel.adjustsFontSizeToFitWidth = NO;
        }

        // image

        NSString *imageName = rowDictionary[kComputerRowKeyImage];

        if (imageName) {
            UIImage *image = [UIImage imageNamed:imageName];

            [cell.imageView setImage:image];
        } else {
            [cell.imageView setImage:nil];
        }

        // accessory type

        NSNumber *accessoryType = rowDictionary[kComputerRowKeyAccessoryType];

        if (accessoryType) {
            [cell setAccessoryType:(UITableViewCellAccessoryType) [accessoryType integerValue]];
        } else {
            [cell setAccessoryType:UITableViewCellAccessoryNone];
        }

        // accessory view - only if cell accessory type is UITableViewCellAccessoryNone

        if ([cell accessoryType] == UITableViewCellAccessoryNone) {
            [cell setAccessoryView:rowDictionary[kComputerRowKeyAccessoryView]];
        }

        // selection style - default Blue

        NSNumber *selectionStyle = rowDictionary[kComputerRowKeySelectionStyle];

        if (selectionStyle) {
            [cell setSelectionStyle:(UITableViewCellSelectionStyle) [selectionStyle integerValue]];
        } else {
            [cell setSelectionStyle:UITableViewCellSelectionStyleBlue];
        }

        // user interaction enabled

        NSNumber *userInteractionEnabled = rowDictionary[kComputerRowKeyUserInteractionEnabled];

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

    if (section == kComputerSectionIndexOfProfile) {
        if (row == kComputerRowIndexOfComputerName) {
            // change computer name

            [self onChangeComputerName];
        }
    } else if (section == kComputerSectionIndexOfUploadGroup) {
        if (row == kComputerRowIndexOfUploadDirectory) {
            // Upload directory

            RootDirectoryViewController *rootDirectoryViewController = [Utility instantiateViewControllerWithIdentifier:@"RootDirectory"];

            rootDirectoryViewController.fromViewController = self;
            rootDirectoryViewController.directoryOnly = YES;

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.navigationController pushViewController:rootDirectoryViewController animated:YES];
            });
        } else if (row == kComputerRowIndexOfSubdirectoryName) {
            // upload subdirectory name

            NSArray *allNames = [UploadSubdirectoryService namesOfAllTypesWithOrder];

            if (allNames) {
                NSNumber *currentUploadSubdirectoryType = [self.uploadSubdirectoryService type];

                BOOL disabledCurrentSelected = (currentUploadSubdirectoryType && ![UploadSubdirectoryService isCustomizableWithType:currentUploadSubdirectoryType.integerValue]);

                NSString *actionSheetTitle = NSLocalizedString(@"Choose type of subdirectory", @"");

                UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:actionSheetTitle message:@"" preferredStyle:UIAlertControllerStyleActionSheet];

                for (NSString *name in allNames) {
                    NSNumber *subdirectoryType = [UploadSubdirectoryService uploadSubdirectoryTypeWithUploadSubdirectoryName:name];

                    if (subdirectoryType) {
                        UIAlertAction *nameAction = [UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                            [self onSelectSubdirectoryWithSubdirectoryType:subdirectoryType];
                        }];

                        [nameAction setEnabled:!(disabledCurrentSelected && [subdirectoryType isEqualToNumber:currentUploadSubdirectoryType])];

                        [actionSheet addAction:nameAction];
                    }
                }

                UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:nil];

                [actionSheet addAction:cancelAction];

                if ([self isVisible]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        UIView *sourceView;
                        CGRect sourceRect;
                        
                        UITableViewCell *selectedCell = [self.tableView cellForRowAtIndexPath:indexPath]; // must be called from main thread only
                        
                        if (selectedCell) {
                            sourceView = selectedCell;
                            sourceRect = selectedCell.bounds; // must be called from main thread only
                        } else {
                            sourceView = self.tableView;
                            sourceRect = self.tableView.frame;
                        }
                        
                        // deselect cell
                        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];

                        [actionSheet presentWithViewController:self sourceView:sourceView sourceRect:sourceRect barButtonItem:nil animated:YES completion:nil];
                    });
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [actionSheet presentWithAnimated:YES];
                    });
                }
            }
        } else if (row == kComputerRowIndexOfDescription) {
            // upload description

            NSArray *allNames = [UploadDescriptionService namesOfAllTypesWithOrder];

            if (allNames) {
                NSNumber *currentUploadDescriptionType = [self.uploadDescriptionService type];

                BOOL disabledCurrentSelected = (currentUploadDescriptionType && ![UploadDescriptionService isCustomizableWithType:currentUploadDescriptionType.integerValue]);

                NSString *actionSheetTitle = NSLocalizedString(@"Choose type of description", @"");

                UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:actionSheetTitle message:@"" preferredStyle:UIAlertControllerStyleActionSheet];

                for (NSString *name in allNames) {
                    NSNumber *descriptionType = [UploadDescriptionService uploadDescriptionTypeWithUploadDescriptionName:name];

                    if (descriptionType) {
                        UIAlertAction *nameAction = [UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                            [self onSelectDescriptionWithDescriptionType:descriptionType];
                        }];

                        [nameAction setEnabled:!(disabledCurrentSelected && [descriptionType isEqualToNumber:currentUploadDescriptionType])];

                        [actionSheet addAction:nameAction];
                    }
                }

                UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:nil];

                [actionSheet addAction:cancelAction];

                if ([self isVisible]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        UIView *sourceView;
                        CGRect sourceRect;
                        
                        UITableViewCell *selectedCell = [self.tableView cellForRowAtIndexPath:indexPath]; // must be called from main thread only
                        
                        if (selectedCell) {
                            sourceView = selectedCell;
                            sourceRect = selectedCell.bounds; // must be called from main thread only
                        } else {
                            sourceView = self.tableView;
                            sourceRect = self.tableView.frame;
                        }
                        
                        // deselect cell
                        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];

                        [actionSheet presentWithViewController:self sourceView:sourceView sourceRect:sourceRect barButtonItem:nil animated:YES completion:nil];
                    });
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [actionSheet presentWithAnimated:YES];
                    });
                }
            }
        } else if (row == kComputerRowIndexOfUploadNotification) {
            // upload notification

            NSArray *allNames = [UploadNotificationService namesOfAllTypesWithOrder];

            if (allNames) {
                NSString *actionSheetTitle = NSLocalizedString(@"Choose type of upload notification", @"");

                UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:actionSheetTitle message:@"" preferredStyle:UIAlertControllerStyleActionSheet];

                for (NSString *name in allNames) {
                    NSNumber *notificationType = [UploadNotificationService uploadNotificationTypeWithUploadNotificationName:name];

                    if (notificationType) {
                        UIAlertAction *nameAction = [UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                            [self onSelectUploadNotificationWithUploadNotificationType:notificationType];
                        }];

                        BOOL enabledAction = !self.uploadNotificationService.type || ![self.uploadNotificationService.name isEqualToString:name];

                        [nameAction setEnabled:enabledAction];

                        [actionSheet addAction:nameAction];
                    }
                }

                UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:nil];

                [actionSheet addAction:cancelAction];

                if ([self isVisible]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        UIView *sourceView;
                        CGRect sourceRect;
                        
                        UITableViewCell *selectedCell = [self.tableView cellForRowAtIndexPath:indexPath]; // must be called from main thread only
                        
                        if (selectedCell) {
                            sourceView = selectedCell;
                            sourceRect = selectedCell.bounds; // must be called from main thread only
                        } else {
                            sourceView = self.tableView;
                            sourceRect = self.tableView.frame;
                        }
                        
                        // deselect cell
                        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];

                        [actionSheet presentWithViewController:self sourceView:sourceView sourceRect:sourceRect barButtonItem:nil animated:YES completion:nil];
                    });
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [actionSheet presentWithAnimated:YES];
                    });
                }
            }
        }
    } else if (section == kComputerSectionIndexOfDownloadGroup) {
        if (row == kComputerRowIndexOfDownloadNotification) {
            // download notification

            NSArray *allNames = [DownloadNotificationService namesOfAllTypesWithOrder];

            if (allNames) {
                NSString *actionSheetTitle = NSLocalizedString(@"Choose type of download notification", @"");

                UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:actionSheetTitle message:@"" preferredStyle:UIAlertControllerStyleActionSheet];

                for (NSString *name in allNames) {
                    NSNumber *notificationType = [DownloadNotificationService downloadNotificationTypeWithDownloadNotificationName:name];

                    if (notificationType) {
                        UIAlertAction *nameAction = [UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                            [self onSelectDownloadNotificationWithDownloadNotificationType:notificationType];
                        }];

                        BOOL enabledAction = !self.downloadNotificationService.type || ![self.downloadNotificationService.name isEqualToString:name];

                        [nameAction setEnabled:enabledAction];

                        [actionSheet addAction:nameAction];
                    }
                }

                UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:nil];

                [actionSheet addAction:cancelAction];

                if ([self isVisible]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        UIView *sourceView;
                        CGRect sourceRect;
                        
                        UITableViewCell *selectedCell = [self.tableView cellForRowAtIndexPath:indexPath]; // must be called from main thread only
                        
                        if (selectedCell) {
                            sourceView = selectedCell;
                            sourceRect = selectedCell.bounds; // must be called from main thread only
                        } else {
                            sourceView = self.tableView;
                            sourceRect = self.tableView.frame;
                        }
                        
                        // deselect cell
                        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];

                        [actionSheet presentWithViewController:self sourceView:sourceView sourceRect:sourceRect barButtonItem:nil animated:YES completion:nil];
                    });
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [actionSheet presentWithAnimated:YES];
                    });
                }
            }
        }
    } else if (section == kComputerSectionIndexOfDeletion) {
        if (row == kComputerRowIndexOfDeleteComputer) {
            // Before deleting computer, check the followings:
            // Prompt user when current user computer contains unfinished uploads or downloads if the computer to delete is currently used by user.
            // Prompt user that downloaded files not accessible after file deleted, no matter if the computer to delete is currently used by user.

            NSString *actionDisplayName = [NSLocalizedString(@"Delete Computer", @"") lowercaseString];

            [self checkNoRunningFileTransfersWithActionDisplayName:actionDisplayName completedHandler:^{
                [self findAvailableComputersToDeleteWithIndexPath:indexPath tryAgainOnInvalidSession:YES];
            }];
        }
    }
}

- (void)checkNoRunningFileTransfersWithActionDisplayName:(NSString *)actionDisplayName completedHandler:(void(^)(void))handler {
    [self.authService checkNoRunningFileTransfersWithActionDisplayName:actionDisplayName inViewController:self completedHandler:handler];
}

- (void)findAvailableComputersToDeleteWithIndexPath:(NSIndexPath *)indexPath tryAgainOnInvalidSession:(BOOL)tryAgainOnInvalidSession {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.appService viewController:self findAvailableComputersWithTryAgainOnInvalidSession:tryAgainOnInvalidSession onSuccessHandler:^(NSArray<UserComputerWithoutManaged *> *availableUserComputers) {

            // if the computer id in preferences not exists in the available computers, delete the computer-related data from preferences
            [self.userComputerService deleteComputerDataInUserDefautsIfComputerIdNotFoundInUserComputers:availableUserComputers didDeletedHandler:nil];

            // Consider if returning only one available computer and contains only userId in it.

            if (availableUserComputers && [availableUserComputers count] > 0 && availableUserComputers[0].computerId) {

                void (^confirmDeletingComputer)(UserComputerWithoutManaged *) = ^void(UserComputerWithoutManaged *userComputerWithoutManaged) {
                    // confirm before deleting computer

                    NSString *computerName = userComputerWithoutManaged.computerName;

                    NSString *userComputerId = userComputerWithoutManaged.userComputerId;

                    NSString *title = NSLocalizedString(@"Confirm Delete", @"");

                    [self.userComputerService findSuccessfullyDownloadedFileForUserComputer:userComputerId completionHandler:^(FileTransferWithoutManaged *fileTransferWithoutManaged) {
                        NSString *message;

                        if (fileTransferWithoutManaged) {
                            message = [NSString stringWithFormat:NSLocalizedString(@"Are you sure to delete computer %@ with downloaded file?", @""), computerName];
                        } else {
                            message = [NSString stringWithFormat:NSLocalizedString(@"Are you sure to delete computer %@ without downloaded file?", @""), computerName];
                        }

                        [Utility viewController:self alertWithMessageTitle:title messageBody:message actionTitle:NSLocalizedString(@"Delete Computer", @"") containsCancelAction:YES delayInSeconds:0 actionHandler:^(UIAlertAction *action) {
                            self.processing = @YES;

                            [self deleteComputerWithUserComputerWithoutManaged:userComputerWithoutManaged tryAgainOnInvalidSession:YES];
                        }];
                    }];
                };

                if ([availableUserComputers count] == 1) {
                    // confirm deleting computer

                    UserComputerWithoutManaged *userComputerWithoutManaged = availableUserComputers[0];

                    confirmDeletingComputer(userComputerWithoutManaged);
                } else {
                    // show action sheet to choose before account kit login
                    
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
                        
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            [Utility promptActionSheetToChooseComputerNameWithAlertControllerTitle:NSLocalizedString(@"Choose the Computer To Delete", @"")
                                                                            availableUserComputers:availableUserComputers
                                                                                  inViewController:self
                                                                                        sourceView:sourceView
                                                                                        sourceRect:sourceRect
                                                                                     barButtonItem:nil
                                                                                  allowNewComputer:NO
                                                       onSelectComputerNameWithUserComputerHandler:^(UserComputerWithoutManaged *_Nonnull userComputerWithoutManaged) {
                                                           // confirm deleting computer
                                                           confirmDeletingComputer(userComputerWithoutManaged);
                                                       } onSelectNewComputerHandler:nil];
                        });
                    });
                }
            } else {
                NSString *message = NSLocalizedString(@"No computer to delete", @"");

                [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
            }
        }];
    });
}

- (void)deleteComputerWithUserComputerWithoutManaged:(UserComputerWithoutManaged *)userComputerWithoutManaged tryAgainOnInvalidSession:(BOOL)tryAgainOnInvalidSession {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSString *sessionId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

        NSString *userId = userComputerWithoutManaged.userId;

        NSNumber *computerId = userComputerWithoutManaged.computerId;

        NSString *userComputerId = userComputerWithoutManaged.userComputerId;

        NSString *computerName = userComputerWithoutManaged.computerName;

        [self.userComputerService deleteComputerWithUserId:userId computerId:computerId session:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

            if (statusCode == 200) {
                // if the computer is the current one, delete the computer-related data in preference

                NSNumber *computerIdInPreferences = [userDefaults objectForKey:USER_DEFAULTS_KEY_COMPUTER_ID];

                if (computerIdInPreferences && [computerIdInPreferences isEqualToNumber:computerId]) {
                    [Utility deleteComputerDataWithUserDefaults:userDefaults];
                }

                // delete local data for this computer

                NSError *pathDeleteError;
                [DirectoryService deleteLocalCachedDataWithUserComputerId:userComputerId error:&pathDeleteError];

                if (pathDeleteError) {
                    NSLog(@"Failed to delete cached data with computer '%@'\n%@", userComputerWithoutManaged.computerName, [pathDeleteError userInfo]);
                }

                // delete the local db for this user-computer and the cached data

                [self.userComputerDao deleteUserComputerWithUserComputerId:userComputerId successHandler:^{
                    NSLog(@"Local db deleted successfully for computer: %@", computerName);
                } errorHandler:^(NSError *deleteError) {
                    NSLog(@"Failed to delete UserComputer with computer '%@'\n%@", userComputerWithoutManaged.computerName, [deleteError userInfo]);
                }];

                // pop up to previous view controller - SettingsViewController
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.navigationController popViewControllerAnimated:YES];
                });
            } else if (tryAgainOnInvalidSession && (statusCode == 401 || (error && [error code] == NSURLErrorUserCancelledAuthentication))) {
                // invalid session id - re-login to get the new session id

                [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                    [self deleteComputerWithUserComputerWithoutManaged:userComputerWithoutManaged tryAgainOnInvalidSession:NO];
                } failureHandler:^(NSData *loginData, NSURLResponse *loginResponse, NSError *loginError) {
                    self.processing = @NO;

                    NSString *message = NSLocalizedString(@"Error on deleting computer", @"");

                    [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                }];
            } else {
                self.processing = @NO;

                NSString *errorMessage = [Utility messageWithMessagePrefix:NSLocalizedString(@"Error on deleting computer", @"") error:error data:data];

                [Utility viewController:self alertWithMessageTitle:@"" messageBody:errorMessage actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
            }
        }];
    });
}

- (void)onChangeComputerName {
    // let user enter new computer name

    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Enter new name of the computer with length limit", @""), MIN_COMPUTER_NAME_LENGTH, MAX_COMPUTER_NAME_LENGTH];

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:message preferredStyle:UIAlertControllerStyleAlert];

    [alertController addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [textField setKeyboardType:UIKeyboardTypeDefault];

            NSUserDefaults *userDefaults = [Utility groupUserDefaults];

            [textField setText:[self prepareComputerNameWithUserDefaults:userDefaults]];

            UITextRange *range = [textField textRangeFromPosition:textField.beginningOfDocument toPosition:textField.endOfDocument];

            [textField setSelectedTextRange:range];
        });
    }];

    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *_Nonnull action) {
        NSString *name = [alertController.textFields[0] text];

        // check length

        if (name
                && [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length <= MAX_COMPUTER_NAME_LENGTH
                && [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length >=  MIN_COMPUTER_NAME_LENGTH) {
            self.processing = @YES;

            [self.userComputerService changeComputerNameForCurrentSessionWithNewComputerName:[name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    self.processing = @NO;

                    NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

                    if (statusCode == 200 && data) {
                        NSError *parseError;
                        NSDictionary *responseDictionary = [Utility parseJsonAsDictionaryFromData:data error:&parseError];

                        if (!parseError) {
                            /*
                             {
                                "computer-id" : 3837763683939,
                                "computer-group" : "GENERAL",
                                "computer-name" : "ALBERT'S LAPTOP"
                             }
                             */

                            NSUserDefaults *userDefaults = [Utility groupUserDefaults];

                            NSNumber *responseComputerId = responseDictionary[@"computer-id"];
                            NSString *responseComputerGroup = responseDictionary[@"computer-group"];
                            NSString *responseComputerName = responseDictionary[@"computer-name"];

                            NSNumber *currentComputerId = [userDefaults objectForKey:USER_DEFAULTS_KEY_COMPUTER_ID];

                            NSString *currentComputerGroup = [userDefaults objectForKey:USER_DEFAULTS_KEY_COMPUTER_GROUP];

                            if ([currentComputerId isEqualToNumber:responseComputerId] && [currentComputerGroup isEqualToString:responseComputerGroup]) {
                                [userDefaults setObject:responseComputerName forKey:USER_DEFAULTS_KEY_COMPUTER_NAME];

                                NSString *successMessage = [NSString stringWithFormat:NSLocalizedString(@"Successfully change computer name to %@", @""), responseComputerName];

                                [Utility viewController:self alertWithMessageTitle:@"" messageBody:successMessage actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:^(UIAlertAction *action) {
                                    [self reloadUserData];
                                }];
                            }
                            // DEBUG
                            else {
                                NSString *responseMessage = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

                                NSString *errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Failed to change computer name. Status:%d. %@", @""), statusCode, (responseMessage ? responseMessage : @"")];

                                NSLog(@"%@", errorMessage);
                            }
                        }
                        // DEBUG
                        else {
                            NSString *responseMessage = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

                            NSLog(@"Error on parsing response message of changing computer name:\n%@\n%@", responseMessage, [parseError userInfo]);
                        }
                    } else {
                        NSString *responseMessage = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

                        NSString *errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Failed to change computer name. Status:%d. %@", @""), statusCode, (responseMessage ? responseMessage : @"")];

                        [Utility viewController:self alertWithMessageTitle:@"" messageBody:errorMessage actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                    }
                });
            }];

        } else {
            NSString *errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Incorrect length of the name", @""), MIN_COMPUTER_NAME_LENGTH, MAX_COMPUTER_NAME_LENGTH];

            [Utility viewController:self alertWithMessageTitle:@"" messageBody:errorMessage actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
        }
    }];

    [alertController addAction:okAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:nil];

    [alertController addAction:cancelAction];

    if ([self isVisible]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [alertController presentWithViewController:self sourceView:nil sourceRect:CGRectNull barButtonItem:nil animated:YES completion:nil];
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [alertController presentWithAnimated:YES];
        });
    }
}

- (void)onEnteredUploadSubdirectoryName:(NSString *_Nullable)subdirectoryName subdirectoryType:(NSNumber *_Nonnull)subdirectoryType {
    if (!subdirectoryName || [subdirectoryName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length < 1) {
        // empty

        NSString *message = NSLocalizedString(@"Empty subdirectory name", @"");

        [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
    } else {
        NSArray *illegalCharacters;

        [Utility checkDirectoryName:subdirectoryName illegalCharacters:&illegalCharacters];

        if (illegalCharacters && [illegalCharacters count] > 0) {
            NSMutableString *illegalCharacterString = [NSMutableString string];

            for (NSString *illegalChar in illegalCharacters) {
                [illegalCharacterString appendFormat:@"%@\n", illegalChar];
            }

            NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Directory name can't contain the following character(s): %@", @""), illegalCharacterString];

            [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
        } else if ([subdirectoryName stringByTrimmingCharactersInSet:[NSCharacterSet punctuationCharacterSet]].length < 1) {
            NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Directory name can't contain only punctuation characters.", @"")];

            [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
        } else {
            // Change to selected type with customized vallue and persist

            NSString *customizedNameTrimmed = [subdirectoryName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

            if (!self.uploadSubdirectoryService.type || ![self.uploadSubdirectoryService.type isEqualToNumber:subdirectoryType]) {
                self.uploadSubdirectoryService = [[UploadSubdirectoryService alloc] initWithUploadSubdirectoryType:subdirectoryType uploadSubdirectoryValue:customizedNameTrimmed];
            } else {
                self.uploadSubdirectoryService.customizedValue = customizedNameTrimmed;
            }

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self updateUploadSubdirectoryWithTryAgainIfFailed:YES completionHandler:^() {
                    [self reloadUserData];
                }];
            });
        }
    }
}

- (void)updateUploadSubdirectoryWithTryAgainIfFailed:(BOOL)tryAgainIfFailed completionHandler:(void (^)(void))completionHandler {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *sessionId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    self.processing = @YES;

    [self.uploadSubdirectoryService persistWithSession:sessionId completionHandler:^(NSURLResponse *response, NSData *data, NSError *error){
        self.processing = @NO;

        NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

        if (statusCode == 200) {
            // this method already updates local db after successfully persited to the server, so we don't have to do that again.

            if (completionHandler) {
                completionHandler();
            }
        } else if (statusCode == 400) {
            // User not exists or profiles not provided

            NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

            NSString *message;
            if (responseString && responseString.length > 0) {
                message = [NSString stringWithFormat:NSLocalizedString(@"Failed to change upload subdirectory value", @""), responseString];
            } else {
                message = NSLocalizedString(@"Failed to change upload subdirectory value2", @"");
            }

            [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
        } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
            self.processing = @YES;

            [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                // Get the new session id, and the session should contain the user computer data
                // because it is from the login, not login-only.

                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [self updateUploadSubdirectoryWithTryAgainIfFailed:NO completionHandler:completionHandler];
                });
            } failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
                self.processing = @NO;

                NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                [self alertToTryUpdateUploadSubdirectoryAgainWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror completionHandler:completionHandler];
            }];
        } else {
            // no possible for error 503 because the service do not care about desktop socket connection

            self.processing = @NO;

            NSString *messagePrefix = NSLocalizedString(@"Failed to change upload subdirectory value2", @"");

            [self alertToTryUpdateUploadSubdirectoryAgainWithMessagePrefix:messagePrefix response:response data:data error:error completionHandler:completionHandler];
        }
    }];
}

- (void)updateUploadDescriptionWithTryAgainIfFailed:(BOOL)tryAgainIfFailed completionHandler:(void (^)(void))completionHandler {
    self.processing = @YES;

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    [self.uploadDescriptionService persistWithSession:sessionId completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        self.processing = @NO;

        NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

        if (statusCode == 200) {
            // this method will update local db after successfully persited to the server, so we don't have to do that again.

            if (completionHandler) {
                completionHandler();
            }
        } else if (statusCode == 400) {
            // User not exists or profiles not provided

            NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

            NSString *message;
            if (responseString && responseString.length > 0) {
                message = [NSString stringWithFormat:NSLocalizedString(@"Failed to change upload description value", @""), responseString];
            } else {
                message = NSLocalizedString(@"Failed to change upload description value2", @"");
            }

            [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
        } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
            self.processing = @YES;

            [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                // Get the new session id, and the session should contain the user computer data
                // because it is from the login, not login-only.

                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [self updateUploadDescriptionWithTryAgainIfFailed:NO completionHandler:completionHandler];
                });
            } failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
                self.processing = @NO;

                NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                [self alertToTryUpdateUploadDescriptionAgainWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror completionHandler:completionHandler];
            }];
        } else {
            // no possible for error 503 because the service do not care about desktop socket connection

            self.processing = @NO;

            NSString *messagePrefix = NSLocalizedString(@"Failed to change upload description value2", @"");

            [self alertToTryUpdateUploadDescriptionAgainWithMessagePrefix:messagePrefix response:response data:data error:error completionHandler:completionHandler];
        }
    }];
}

- (void)updateUploadNotificationWithTryAgainIfFailed:(BOOL)tryAgainIfFailed completionHandler:(void (^)(void))completionHandler {
    self.processing = @YES;

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    [self.uploadNotificationService persistWithSession:sessionId completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        self.processing = @NO;

        NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

        if (statusCode == 200) {
            // this method will update local db after successfully persited to the server, so we don't have to do that again.

            if (completionHandler) {
                completionHandler();
            }
        } else if (statusCode == 400) {
            // User not exists or profiles not provided

            NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

            NSString *message;
            if (responseString && responseString.length > 0) {
                message = [NSString stringWithFormat:NSLocalizedString(@"Failed to change upload notification value", @""), responseString];
            } else {
                message = NSLocalizedString(@"Failed to change upload notification value2", @"");
            }

            [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
        } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
            self.processing = @YES;

            [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                // Get the new session id, and the session should contain the user computer data
                // because it is from the login, not login-only.

                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [self updateUploadNotificationWithTryAgainIfFailed:NO completionHandler:completionHandler];
                });
            } failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
                self.processing = @NO;

                NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                [self alertToTryUpdateUploadNotificationAgainWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror completionHandler:completionHandler];
            }];
        } else {
            // no possible for error 503 because the service do not care about desktop socket connection

            self.processing = @NO;

            NSString *messagePrefix = NSLocalizedString(@"Failed to change upload notification value2", @"");

            [self alertToTryUpdateUploadNotificationAgainWithMessagePrefix:messagePrefix response:response data:data error:error completionHandler:completionHandler];
        }
    }];
}

- (void)updateDownloadNotificationWithTryAgainIfFailed:(BOOL)tryAgainIfFailed completionHandler:(void (^)(void))completionHandler {
    self.processing = @YES;

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    [self.downloadNotificationService persistWithSession:sessionId completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        self.processing = @NO;

        NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

        if (statusCode == 200) {
            // this method will update local db after successfully persited to the server, so we don't have to do that again.

            if (completionHandler) {
                completionHandler();
            }
        } else if (statusCode == 400) {
            // User not exists or profiles not provided

            NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

            NSString *message;
            if (responseString && responseString.length > 0) {
                message = [NSString stringWithFormat:NSLocalizedString(@"Failed to change download notification value", @""), responseString];
            } else {
                message = NSLocalizedString(@"Failed to change download notification value2", @"");
            }

            [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
        } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
            self.processing = @YES;

            [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                // Get the new session id, and the session should contain the user computer data
                // because it is from the login, not login-only.
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [self updateDownloadNotificationWithTryAgainIfFailed:NO completionHandler:completionHandler];
                });
            } failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
                self.processing = @NO;

                NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                [self alertToTryUpdateDownloadNotificationAgainWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror completionHandler:completionHandler];
            }];
        } else {
            // no possible for error 503 because the service do not care about desktop socket connection

            self.processing = @NO;

            NSString *messagePrefix = NSLocalizedString(@"Failed to change download notification value2", @"");

            [self alertToTryUpdateDownloadNotificationAgainWithMessagePrefix:messagePrefix response:response data:data error:error completionHandler:completionHandler];
        }
    }];
}

- (void)alertToTryUpdateUploadSubdirectoryAgainWithMessagePrefix:(NSString *)messagePrefix response:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error completionHandler:(void(^)(void))completionHandler {
    UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self updateUploadSubdirectoryWithTryAgainIfFailed:YES completionHandler:completionHandler];
        });
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self updateUploadSubdirectoryWithTryAgainIfFailed:NO completionHandler:completionHandler];
        });
    }];
}

- (void)alertToTryUpdateUploadDescriptionAgainWithMessagePrefix:(NSString *)messagePrefix response:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error completionHandler:(void(^)(void))completionHandler {
    UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self updateUploadDescriptionWithTryAgainIfFailed:YES completionHandler:completionHandler];
        });
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self updateUploadDescriptionWithTryAgainIfFailed:NO completionHandler:completionHandler];
        });
    }];
}

- (void)alertToTryUpdateUploadNotificationAgainWithMessagePrefix:(NSString *)messagePrefix response:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error completionHandler:(void(^)(void))completionHandler {
    UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self updateUploadNotificationWithTryAgainIfFailed:YES completionHandler:completionHandler];
        });
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self updateUploadNotificationWithTryAgainIfFailed:NO completionHandler:completionHandler];
        });
    }];
}

- (void)alertToTryUpdateDownloadNotificationAgainWithMessagePrefix:(NSString *)messagePrefix response:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error completionHandler:(void(^)(void))completionHandler {
    UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self updateDownloadNotificationWithTryAgainIfFailed:YES completionHandler:completionHandler];
        });
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self updateDownloadNotificationWithTryAgainIfFailed:NO completionHandler:completionHandler];
        });
    }];
}

- (void)onSelectSubdirectoryWithSubdirectoryType:(NSNumber *_Nonnull)subdirectoryType {
    BOOL customizable = [UploadSubdirectoryService isCustomizableWithType:[subdirectoryType integerValue]];

    // check if customizable
    if (customizable) {
        // let user enter customized name of subdirectory

        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:NSLocalizedString(@"Enter customized name", @"") preferredStyle:UIAlertControllerStyleAlert];

        [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            [textField setKeyboardType:UIKeyboardTypeDefault];

            [textField setText:[self.uploadSubdirectoryService customizedValue]];
        }];

        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSString *name = [alertController.textFields[0] text];

            [self onEnteredUploadSubdirectoryName:name subdirectoryType:subdirectoryType];
        }];

        [alertController addAction:okAction];

        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:nil];

        [alertController addAction:cancelAction];

        if ([self isVisible]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [alertController presentWithViewController:self sourceView:nil sourceRect:CGRectNull barButtonItem:nil animated:YES completion:nil];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [alertController presentWithAnimated:YES];
            });
        }
    } else {
        if (!self.uploadSubdirectoryService.type || ![self.uploadSubdirectoryService.type isEqualToNumber:subdirectoryType]) {
            // keep the old customized values so it shows when user changed back from non-customized option.

            NSString *oldSubdirectoryCustomizedValue = [self.uploadSubdirectoryService customizedValue];

            self.uploadSubdirectoryService = [[UploadSubdirectoryService alloc] initWithUploadSubdirectoryType:subdirectoryType uploadSubdirectoryValue:oldSubdirectoryCustomizedValue];

            // update to server, local db and preferences before reloading data

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self updateUploadSubdirectoryWithTryAgainIfFailed:YES completionHandler:^() {
                    [self reloadUserData];
                }];
            });
        }
    }
}

- (void)onSelectDescriptionWithDescriptionType:(NSNumber *_Nonnull)descriptionType {
    BOOL cuustomizable = [UploadDescriptionService isCustomizableWithType:[descriptionType integerValue]];

    if (cuustomizable) {
        // let user enter customized description

        FKEditingPackedUploadDescriptionViewController *editingPackedUploadDescriptionViewController = [Utility instantiateViewControllerWithIdentifier:@"FKEditingPackedUploadDescription"];

        editingPackedUploadDescriptionViewController.selectedType = descriptionType;
        editingPackedUploadDescriptionViewController.uploadDescriptionDataSource = (id) self;

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.navigationController pushViewController:editingPackedUploadDescriptionViewController animated:YES];
        });
    } else {
        if (!self.uploadDescriptionService.type || ![self.uploadDescriptionService.type isEqualToNumber:descriptionType]) {
            // keep the old customized values so it shows when user changed back from non-customized option.
            NSString *oldDescriptionCustomizedValue = [self.uploadDescriptionService customizedValue];

            self.uploadDescriptionService = [[UploadDescriptionService alloc] initWithUploadDescriptionType:descriptionType uploadDescriptionValue:oldDescriptionCustomizedValue];

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self updateUploadDescriptionWithTryAgainIfFailed:YES completionHandler:^() {
                    [self reloadUserData];
                }];
            });
        }
    }
}

- (void)onSelectUploadNotificationWithUploadNotificationType:(NSNumber *)notificationType {
    if (!self.uploadNotificationService.type || ![self.uploadNotificationService.type isEqualToNumber:notificationType]) {
        self.uploadNotificationService = [[UploadNotificationService alloc] initWithUploadNotificationType:notificationType];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self updateUploadNotificationWithTryAgainIfFailed:YES completionHandler:^() {
                [self reloadUserData];
            }];
        });
    }
}

- (void)onSelectDownloadNotificationWithDownloadNotificationType:(NSNumber *)notificationType {
    if (!self.downloadNotificationService.type || ![self.downloadNotificationService.type isEqualToNumber:notificationType]) {
        self.downloadNotificationService = [[DownloadNotificationService alloc] initWithDownloadNotificationType:notificationType];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self updateDownloadNotificationWithTryAgainIfFailed:YES completionHandler:^() {
                [self reloadUserData];
            }];
        });
    }
}

@end
