#import "FileInfoViewController.h"
#import "AppService.h"
#import "FilelugUtility.h"

// row key for NSDictionary
#define kRowKeyCellStyle                                    @"style"
#define kRowKeyLabelText                                    @"label_text"
#define kRowKeyDetailLabelText                              @"detail_label_text"
#define kRowKeyLabelTextAdjustsFontSizeToFitWidth           @"label_text_adjusts_font_size_to_fit_width"
#define kRowKeyLabelTextNumberOfLines                       @"label_text_number_of_lines"
#define kRowKeyDetailLabelTextAdjustsFontSizeToFitWidth     @"detail_label_text_adjusts_font_size_to_fit_width"
#define kRowKeyDetailLabelTextNumberOfLines                 @"detail_label_text_number_of_lines"
#define kRowKeyImage                                        @"image"
#define kRowKeyAccessoryType                                @"accessory_type"
#define kRowKeySelectionStyle                               @"selection_style"
#define kRowKeyUserInteractionEnabled                       @"user_interaction_enabled"

@interface FileInfoViewController () {
}

// elements of NSString
@property(nonatomic, strong) NSArray *tableSections;

// elements of NSArray, which contains NSDictionary contains row keys
@property(nonatomic, strong) NSArray *tableSectionRows;

@property(nonatomic, strong) FileTransferDao *fileTransferDao;

@property(nonatomic, strong) NSString *transferKey;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) AppService *appService;

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

@end


@implementation FileInfoViewController
    
@synthesize processing;
    
@synthesize progressView;

- (void)viewDidLoad {
    [super viewDidLoad];

    self.processing = @NO;

    [Utility viewController:self useNavigationLargeTitles:YES];

    _preferredContentSizeCategoryService = [[PreferredContentSizeCategoryService alloc] init];

    // refresh control
    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    
    [refresh setAttributedTitle:[[NSAttributedString alloc] initWithString:NSLocalizedString(@"Pull to refresh", @"")]];

    self.refreshControl = refresh;

    // Use current values of file info
    if (_hierarchicalModel) {
        _filename = self.hierarchicalModel.name;
        _fileParent = self.hierarchicalModel.parent;
        _fileLastModifiedDate = self.hierarchicalModel.lastModified;
        _fileReadable = (self.hierarchicalModel.readable && [self.hierarchicalModel.readable boolValue]) ? NSLocalizedString(@"Permission YES", @"") : NSLocalizedString(@"Permission NO", @"");
        _fileWritable = (self.hierarchicalModel.writable && [self.hierarchicalModel.writable boolValue]) ? NSLocalizedString(@"Permission YES", @"") : NSLocalizedString(@"Permission NO", @"");
        _fileExecutable = (self.hierarchicalModel.executable && [self.hierarchicalModel.executable boolValue]) ? NSLocalizedString(@"Permission YES", @"") : NSLocalizedString(@"Permission NO", @"");
        _fileHidden = (self.hierarchicalModel.hidden && [self.hierarchicalModel.hidden boolValue]) ? NSLocalizedString(@"Hidden YES", @"") : NSLocalizedString(@"Hidden NO", @"");
    }

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

    [self.refreshControl addTarget:self action:@selector(prepareHierarchicalModel:) forControlEvents:UIControlEventValueChanged];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.refreshControl) {
            [self.refreshControl endRefreshing];
        }
    });

    [self prepareHierarchicalModel:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self.refreshControl removeTarget:self action:@selector(prepareHierarchicalModel:) forControlEvents:UIControlEventValueChanged];

    [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) context:NULL];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];

    if (self.progressView) {
        self.progressView = nil;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (FileTransferDao *)fileTransferDao {
    if (!_fileTransferDao) {
        _fileTransferDao = [[FileTransferDao alloc] init];
    }
    
    return _fileTransferDao;
}

- (AuthService *)authService {
    if (!_authService) {
        _authService = [[AuthService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];
    }
    
    return _authService;
}

- (AppService *)appService {
    if (!_appService) {
        _appService = [[AppService alloc] init];
    }
    
    return _appService;
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

                        MBProgressHUD *progressHUD = [Utility prepareProgressViewWithSuperview:self.view inTabWithTabName:selectedTabName refreshControl:self.refreshControl];

                        self.progressView = progressHUD;
                    } else {
                        [self.progressView show:YES];
                    }
                } else {
                    [self.tableView setScrollEnabled:YES];

                    if (self.progressView) {
                        [self.progressView hide:YES];
                    }

                    if (self.refreshControl) {
                        [self.refreshControl endRefreshing];
                    }
                }
            });
        }
    }
}

- (void)prepareHierarchicalModel:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *localRealFilePath = [NSString stringWithString:self.realFilePath];

        /* fetch from server, save to DB, then retrieve from DB */
        [self internalPrepareHierarchicalModelWithRealFilePath:localRealFilePath tryAgainIfFailed:YES];
    });
}

- (void)internalPrepareHierarchicalModelWithRealFilePath:(NSString *)realFilePath tryAgainIfFailed:(BOOL)tryAgainIfFailed {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

        NSString *userComputerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

        NSString *tempLugServerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID];

        if (sessionId == nil || sessionId.length < 1) {
            [FilelugUtility alertEmptyUserSessionFromViewController:self];
//        [FilelugUtility alertUserNeverConnectedWithViewController:self loginSuccessHandler:^(NSURLResponse *response, NSData *data) {
//            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                self.processing = @NO;
//
//                [self internalPrepareHierarchicalModelWithRealFilePath:realFilePath userComputer:userComputerId];
//            });
//        }];
        } else if (tempLugServerId == nil || tempLugServerId.length < 1) {
            [self requestConnectWithAuthService:self.authService userDefaults:userDefaults realFilePath:realFilePath];
        } else {
            if (realFilePath) {
                self.processing = @YES;

                DirectoryService *directoryService = [[DirectoryService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];

                [directoryService findFileWithPath:realFilePath calculateSize:YES session:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                    self.processing = @NO;

                    NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

                    if (statusCode == 200) {
                        NSError *parseError;

                        self.hierarchicalModel = [DirectoryService parseJsonAsHierarchicalModel:data userComputerId:userComputerId error:&parseError];

                        if (parseError) {
                            NSString *dataContent;

                            if (data && [data length] > 0) {
                                dataContent = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                            } else {
                                dataContent = @"";
                            }

                            NSLog(@"Error on parsing json data as hierarchical model array. JSON data=%@. %@, %@", dataContent, parseError, [parseError userInfo]);
                        } else {
                            self.filename = self.hierarchicalModel.name;
                            self.fileParent = self.hierarchicalModel.parent;
                            self.fileSize = self.hierarchicalModel.displaySize;
                            self.fileMimetype = [Utility contentTypeFromFilenameExtension:[self.hierarchicalModel.realName pathExtension]];
                            self.fileLastModifiedDate = self.hierarchicalModel.lastModified;
                            self.fileReadable = (self.hierarchicalModel.readable && [self.hierarchicalModel.readable boolValue]) ? NSLocalizedString(@"Permission YES", @"") : NSLocalizedString(@"Permission NO", @"");
                            self.fileWritable = (self.hierarchicalModel.writable && [self.hierarchicalModel.writable boolValue]) ? NSLocalizedString(@"Permission YES", @"") : NSLocalizedString(@"Permission NO", @"");
                            self.fileExecutable = (self.hierarchicalModel.executable && [self.hierarchicalModel.executable boolValue]) ? NSLocalizedString(@"Permission YES", @"") : NSLocalizedString(@"Permission NO", @"");
                            self.fileHidden = (self.hierarchicalModel.hidden && [self.hierarchicalModel.hidden boolValue]) ? NSLocalizedString(@"Hidden YES", @"") : NSLocalizedString(@"Hidden NO", @"");

                            [self prepareTableViewCells];

                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self.tableView reloadData];
                            });
                        }
                    } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
                        self.processing = @YES;

                        [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                            if ([userDefaults objectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID]) {
                                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                    [self internalPrepareHierarchicalModelWithRealFilePath:realFilePath tryAgainIfFailed:NO];
                                });
                            } else {
                                [self requestConnectWithAuthService:self.authService userDefaults:userDefaults realFilePath:realFilePath];
                            }
                        } failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
                            self.processing = @NO;

                            NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                            [self alertToTryAgainWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror];
                        }];
//                    [self.appService authService:self.authService reloginCurrentUserComputerFromViewController:self successHandler:^(NSURLResponse *lresponse, NSData *ldata) {
//                        self.processing = @NO;
//
//                        if ([userDefaults objectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID]) {
//                            [self internalPrepareHierarchicalModelWithRealFilePath:realFilePath userComputer:userComputerId];
//                        } else {
//                            [self requestConnectWithAuthService:self.authService userDefaults:userDefaults realFilePath:realFilePath userComputerId:userComputerId];
//                        }
//                    } failureHandler:^(NSURLResponse *lresponse, NSData *ldata, NSError *lerror) {
//                        self.processing = @NO;
//
//                        NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");
//
//                        [self alertToTryAgainWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror];
//                    }];
                    } else if (tryAgainIfFailed && statusCode == 503) {
                        // server not connected, so request connection
                        [self requestConnectWithAuthService:self.authService userDefaults:userDefaults realFilePath:realFilePath];
                    } else {
                        self.processing = @NO;

                        NSString *messagePrefix = NSLocalizedString(@"Error on finding file information.", @"");

                        [self alertToTryAgainWithMessagePrefix:messagePrefix response:response data:data error:error];
                    }
                }];
            } else {
                self.processing = @NO;

                NSLog(@"No file selected.");
            }
        }
    });
}

- (void)requestConnectWithAuthService:(AuthService *)authService userDefaults:(NSUserDefaults *)userDefaults realFilePath:(NSString *)realFilePath {
    self.processing = @YES;
    
    [authService requestConnectWithSession:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] successHandler:^(NSURLResponse *rcresponse, NSData *rcdata) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self internalPrepareHierarchicalModelWithRealFilePath:realFilePath tryAgainIfFailed:NO];
        });
    } failureHandler:^(NSData *rcdata, NSURLResponse *rcresponse, NSError *rcerror) {
        self.processing = @NO;
        
        [self alertToTryAgainWithMessagePrefix:nil response:rcresponse data:rcdata error:rcerror];
    }];
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
    CGFloat height;

    if (indexPath.section == 0 && indexPath.row == 1 && [self.preferredContentSizeCategoryService isLargeContentSizeCategory]) {
        height = 80;
    } else {
        height = 60;
    }

    return height;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *FileInfoDefaultCellIdentifier = @"FileInfoDefaultCell";

    UITableViewCell *cell;

    // Configure the cell

    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;

    NSDictionary *rowDictionary = self.tableSectionRows[(NSUInteger) section][(NSUInteger) row];

    if (rowDictionary) {
        // cell style

        NSNumber *cellStyle = rowDictionary[kRowKeyCellStyle];

        if (!cellStyle) {
            cellStyle = @(UITableViewCellStyleDefault);
        }

        NSString *reuseIdentifier = FileInfoDefaultCellIdentifier;

        UIFont *textLabelFont = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        UIColor *textLabelTextColor = [UIColor darkTextColor];

        UIFont *detailLabelFont = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        UIColor *detailLabelTextColor = [UIColor aquaColor];

        UITableViewCellStyle style = (UITableViewCellStyle) [cellStyle integerValue];

        cell = [Utility tableView:tableView createOrDequeueCellWithStyle:style reuseIdentifier:reuseIdentifier forIndexPath:indexPath];

        // configure the preferred font

        cell.textLabel.font = textLabelFont;
        cell.textLabel.textColor = textLabelTextColor;
        cell.textLabel.textAlignment = NSTextAlignmentNatural;

        cell.detailTextLabel.font = detailLabelFont;
        cell.detailTextLabel.textColor = detailLabelTextColor;
        cell.detailTextLabel.textAlignment = NSTextAlignmentNatural;

        // label text

        [cell.textLabel setText:rowDictionary[kRowKeyLabelText]];

        // label text numberOfLines - kRowKeyLabelTextNumberOfLines

        NSNumber *textLabelNumberOfLines = rowDictionary[kRowKeyLabelTextNumberOfLines];

        if (textLabelNumberOfLines) {
            cell.textLabel.numberOfLines = [textLabelNumberOfLines integerValue];
        } else {
            cell.textLabel.numberOfLines = 1;
        }

        // label text adjustsFontSizeToFitWidth - kRowKeyLabelTextAdjustsFontSizeToFitWidth

        NSNumber *textLabelAdjustsFontSizeToFitWidth = rowDictionary[kRowKeyLabelTextAdjustsFontSizeToFitWidth];

        if (textLabelAdjustsFontSizeToFitWidth) {
            cell.textLabel.adjustsFontSizeToFitWidth = [textLabelAdjustsFontSizeToFitWidth boolValue];

            if (cell.textLabel.adjustsFontSizeToFitWidth) {
                cell.textLabel.minimumScaleFactor = 0.5;
            }
        } else {
            cell.textLabel.adjustsFontSizeToFitWidth = NO;
        }

        cell.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;

        // detail label text

        [cell.detailTextLabel setText:rowDictionary[kRowKeyDetailLabelText]];

        // detail label text numberOfLines - kRowKeyDetailLabelTextNumberOfLines

        NSNumber *detailLabelNumberOfLines = rowDictionary[kRowKeyDetailLabelTextNumberOfLines];

        if (detailLabelNumberOfLines) {
            cell.detailTextLabel.numberOfLines = [detailLabelNumberOfLines integerValue];
        } else {
            cell.detailTextLabel.numberOfLines = 1;
        }

        // detail label text adjustsFontSizeToFitWidth - kRowKeyDetailLabelTextAdjustsFontSizeToFitWidth

        NSNumber *detailLabelTextAdjustsFontSizeToFitWidth = rowDictionary[kRowKeyDetailLabelTextAdjustsFontSizeToFitWidth];

        if (detailLabelTextAdjustsFontSizeToFitWidth) {
            cell.detailTextLabel.adjustsFontSizeToFitWidth = [detailLabelTextAdjustsFontSizeToFitWidth boolValue];

            if (cell.detailTextLabel.adjustsFontSizeToFitWidth) {
                cell.detailTextLabel.minimumScaleFactor = 0.5;
            }
        } else {
            cell.detailTextLabel.adjustsFontSizeToFitWidth = NO;
        }

        cell.detailTextLabel.lineBreakMode = NSLineBreakByCharWrapping;

        // image

        NSString *imageName = rowDictionary[kRowKeyImage];

        if (imageName) {
            UIImage *image = [UIImage imageNamed:imageName];

            [cell.imageView setImage:image];
        } else {
            [cell.imageView setImage:nil];
        }

        // accessory type

        NSNumber *accessoryType = rowDictionary[kRowKeyAccessoryType];

        if (accessoryType) {
            [cell setAccessoryType:(UITableViewCellAccessoryType) [accessoryType integerValue]];
        } else {
            [cell setAccessoryType:UITableViewCellAccessoryNone];
        }

        // selection style - default Blue

        NSNumber *selectionStyle = rowDictionary[kRowKeySelectionStyle];

        if (selectionStyle) {
            [cell setSelectionStyle:(UITableViewCellSelectionStyle) [selectionStyle integerValue]];
        } else {
            [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        }

        // user interaction enabled

        NSNumber *userInteractionEnabled = rowDictionary[kRowKeyUserInteractionEnabled];

        BOOL canSelected = (userInteractionEnabled && [userInteractionEnabled boolValue]);

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
        cell = [Utility tableView:tableView createOrDequeueCellWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:FileInfoDefaultCellIdentifier forIndexPath:indexPath];
    }

    return cell;
}

- (void)alertToTryAgainWithMessagePrefix:messagePrefix response:response data:data error:error {
    UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        // Request file information again

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *localRealFilePath = [NSString stringWithString:self.realFilePath];

            [self internalPrepareHierarchicalModelWithRealFilePath:localRealFilePath tryAgainIfFailed:YES];
        });
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        // Request file information again

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *localRealFilePath = [NSString stringWithString:self.realFilePath];

            [self internalPrepareHierarchicalModelWithRealFilePath:localRealFilePath tryAgainIfFailed:NO];
        });
    }];
}

- (void)prepareTableViewCells {
    _tableSections = @[
            NSLocalizedString(@"Information", @""),
            NSLocalizedString(@"Permission", @"")
    ];

    NSArray *sectionRows0 = @[
            // File Name
            @{
                    kRowKeyCellStyle : @(UITableViewCellStyleSubtitle),                 // NSNumber, wrapping NSInteger
                    kRowKeyLabelText : NSLocalizedString(@"File Name", @""),            // NSString
                    kRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),                  // NSNumber, wrapping BOOL
                    kRowKeyLabelTextNumberOfLines : @(1),                               // NSString
                    kRowKeyDetailLabelText : self.filename ? self.filename : @"",       // NSString
                    kRowKeyDetailLabelTextAdjustsFontSizeToFitWidth : @(NO),            // NSNumber, wrapping BOOL
                    kRowKeyDetailLabelTextNumberOfLines : @(0),                         // NSString
                    kRowKeyAccessoryType : @(UITableViewCellAccessoryNone),             // NSNumber, wrapping NSInteger
                    kRowKeyUserInteractionEnabled : @(YES),                             // NSNumber, wrapping BOOL
                    kRowKeySelectionStyle : @(UITableViewCellSelectionStyleNone)        // NSNumber, wrapping NSInteger
            },
            // Directory
            @{
                    kRowKeyCellStyle : @(UITableViewCellStyleSubtitle),
                    kRowKeyLabelText : NSLocalizedString(@"Directory", @""),
                    kRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kRowKeyLabelTextNumberOfLines : @(1),
                    kRowKeyDetailLabelText : self.fileParent ? self.fileParent : @"",
                    kRowKeyDetailLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kRowKeyDetailLabelTextNumberOfLines : @(0),
                    kRowKeyAccessoryType : @(UITableViewCellAccessoryNone),
                    kRowKeyUserInteractionEnabled : @(YES),
                    kRowKeySelectionStyle : @(UITableViewCellSelectionStyleNone)
            },
            // File Size
            @{
                    kRowKeyCellStyle : @(UITableViewCellStyleSubtitle),
                    kRowKeyLabelText : NSLocalizedString(@"File Size", @""),
                    kRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kRowKeyLabelTextNumberOfLines : @(1),
                    kRowKeyDetailLabelText : self.fileSize ? self.fileSize : @"",
                    kRowKeyDetailLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kRowKeyDetailLabelTextNumberOfLines : @(0),
                    kRowKeyAccessoryType : @(UITableViewCellAccessoryNone),
                    kRowKeyUserInteractionEnabled : @(YES),
                    kRowKeySelectionStyle : @(UITableViewCellSelectionStyleNone)
            },
            // File MimeType
            @{
                    kRowKeyCellStyle : @(UITableViewCellStyleSubtitle),
                    kRowKeyLabelText : NSLocalizedString(@"Mime Type", @""),
                    kRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kRowKeyLabelTextNumberOfLines : @(1),
                    kRowKeyDetailLabelText : self.fileMimetype ? self.fileMimetype : @"application/octet-stream",
                    kRowKeyDetailLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kRowKeyDetailLabelTextNumberOfLines : @(0),
                    kRowKeyAccessoryType : @(UITableViewCellAccessoryNone),
                    kRowKeyUserInteractionEnabled : @(YES),
                    kRowKeySelectionStyle : @(UITableViewCellSelectionStyleNone)
            },
            // File Last Modified Date
            @{
                    kRowKeyCellStyle : @(UITableViewCellStyleSubtitle),
                    kRowKeyLabelText : NSLocalizedString(@"Last Modified Date", @""),
                    kRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kRowKeyLabelTextNumberOfLines : @(1),
                    kRowKeyDetailLabelText : self.fileLastModifiedDate ? self.fileLastModifiedDate : @"",
                    kRowKeyDetailLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kRowKeyDetailLabelTextNumberOfLines : @(0),
                    kRowKeyAccessoryType : @(UITableViewCellAccessoryNone),
                    kRowKeyUserInteractionEnabled : @(YES),
                    kRowKeySelectionStyle : @(UITableViewCellSelectionStyleNone)
            },
            // File Hidden
            @{
                    kRowKeyCellStyle : @(UITableViewCellStyleSubtitle),
                    kRowKeyLabelText : NSLocalizedString(@"Hidden", @""),
                    kRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kRowKeyLabelTextNumberOfLines : @(1),
                    kRowKeyDetailLabelText : self.fileHidden ? self.fileHidden : @"",
                    kRowKeyDetailLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kRowKeyDetailLabelTextNumberOfLines : @(0),
                    kRowKeyAccessoryType : @(UITableViewCellAccessoryNone),
                    kRowKeyUserInteractionEnabled : @(YES),
                    kRowKeySelectionStyle : @(UITableViewCellSelectionStyleNone)
            }
    ];

    NSArray *sectionRows1 = @[
            // File Readable
            @{
                    kRowKeyCellStyle : @(UITableViewCellStyleSubtitle),
                    kRowKeyLabelText : NSLocalizedString(@"Readable", @""),
                    kRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kRowKeyLabelTextNumberOfLines : @(1),
                    kRowKeyDetailLabelText : self.fileReadable ? self.fileReadable : @"",
                    kRowKeyDetailLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kRowKeyDetailLabelTextNumberOfLines : @(0),
                    kRowKeyAccessoryType : @(UITableViewCellAccessoryNone),
                    kRowKeyUserInteractionEnabled : @(YES),
                    kRowKeySelectionStyle : @(UITableViewCellSelectionStyleNone)
            },
            // File Writable
            @{
                    kRowKeyCellStyle : @(UITableViewCellStyleSubtitle),
                    kRowKeyLabelText : NSLocalizedString(@"Writable", @""),
                    kRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kRowKeyLabelTextNumberOfLines : @(1),
                    kRowKeyDetailLabelText : self.fileWritable ? self.fileWritable : @"",
                    kRowKeyDetailLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kRowKeyDetailLabelTextNumberOfLines : @(0),
                    kRowKeyAccessoryType : @(UITableViewCellAccessoryNone),
                    kRowKeyUserInteractionEnabled : @(YES),
                    kRowKeySelectionStyle : @(UITableViewCellSelectionStyleNone)
            },
            // File Executable
            @{
                    kRowKeyCellStyle : @(UITableViewCellStyleSubtitle),
                    kRowKeyLabelText : NSLocalizedString(@"Executable", @""),
                    kRowKeyLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kRowKeyLabelTextNumberOfLines : @(1),
                    kRowKeyDetailLabelText : self.fileExecutable ? self.fileExecutable : @"",
                    kRowKeyDetailLabelTextAdjustsFontSizeToFitWidth : @(NO),
                    kRowKeyDetailLabelTextNumberOfLines : @(0),
                    kRowKeyAccessoryType : @(UITableViewCellAccessoryNone),
                    kRowKeyUserInteractionEnabled : @(YES),
                    kRowKeySelectionStyle : @(UITableViewCellSelectionStyleNone)
            }
    ];


    _tableSectionRows = @[sectionRows0, sectionRows1];
}

@end
