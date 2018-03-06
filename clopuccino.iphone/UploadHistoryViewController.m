#import "UploadHistoryViewController.h"
#import "FilelugUtility.h"
#import "AppService.h"

@interface UploadHistoryViewController ()

// elements of TransferHistoryModel, for uploads
@property(nonatomic, strong) NSMutableArray *transferHistories;

@property(nonatomic, assign) NSInteger selectedSegmentIndex;

// key=TRANSFER_HISTORY_TYPE_XXX(NSInteger to NSNumber), value=localized name
@property(nonatomic, strong) NSDictionary *actionSheetButtons;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) AppService *appService;

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

@end

@implementation UploadHistoryViewController

@synthesize processing;

@synthesize progressView;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.processing = @NO;

    [Utility viewController:self useNavigationLargeTitles:YES];
    
    _selectedSegmentIndex = TRANSFER_HISTORY_TYPE_LATEST_20;
    
    _actionSheetButtons = @{
                            @(TRANSFER_HISTORY_TYPE_LATEST_20) : NSLocalizedString(@"transfer.history.search.latest 20", @""),
                            @(TRANSFER_HISTORY_TYPE_LATEST_WEEK) : NSLocalizedString(@"transfer.history.search.latest.week", @""),
                            @(TRANSFER_HISTORY_TYPE_LATEST_MONTH) : NSLocalizedString(@"transfer.history.search.latest.month", @""),
                            @(TRANSFER_HISTORY_TYPE_ALL) : NSLocalizedString(@"transfer.history.search.all", @"")
                            };

    _preferredContentSizeCategoryService = [[PreferredContentSizeCategoryService alloc] init];
    
    // right button items
    UIBarButtonItem *searchItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(search:)];
    
    self.navigationItem.rightBarButtonItem = searchItem;

    // refresh control
    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    
    [refresh setAttributedTitle:[[NSAttributedString alloc] initWithString:NSLocalizedString(@"Pull to refresh", @"")]];

    self.refreshControl = refresh;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // adding observers

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangePreferredContentSize:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];

    [self addObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];

    [self.refreshControl addTarget:self action:@selector(reloadData:) forControlEvents:UIControlEventValueChanged];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.refreshControl) {
            [self.refreshControl endRefreshing];
        }
    });

    [self reloadData:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self.refreshControl removeTarget:self action:@selector(reloadData:) forControlEvents:UIControlEventValueChanged];
    
    [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) context:NULL];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];
    
    if (self.progressView) {
        self.progressView = nil;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
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

                    if (self.refreshControl) {
                        [self.refreshControl endRefreshing];
                    }
                }
            });
        }
    }
}

- (void)search:(id)sender {
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Choose search range", @"") message:@"" preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSArray *allKeys = [[self.actionSheetButtons allKeys] sortedArrayUsingSelector:@selector(compare:)];

    for (NSNumber *key in allKeys) {
        UIAlertAction *searchAction = [UIAlertAction actionWithTitle:(self.actionSheetButtons)[key] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            self.selectedSegmentIndex = [key integerValue];
            
            [self reloadData:actionSheet];
        }];
        
        BOOL enabledAction = ([key integerValue] != self.selectedSegmentIndex);
        
        [searchAction setEnabled:enabledAction];
        
        [actionSheet addAction:searchAction];
    }
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:nil];
    
    [actionSheet addAction:cancelAction];

    if ([self isVisible]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [actionSheet presentWithViewController:self sourceView:nil sourceRect:CGRectNull barButtonItem:(UIBarButtonItem *)sender animated:YES completion:nil];
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [actionSheet presentWithAnimated:YES];
        });
    }
}

- (IBAction)reloadData:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self internalReloadDataWithSelectedSegmentIndex:self.selectedSegmentIndex tryAgainIfFailed:YES];
    });
}

- (void)internalReloadDataWithSelectedSegmentIndex:(NSInteger)selectedSegmentIndex tryAgainIfFailed:(BOOL)tryAgainIfFailed {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];
    
    if (sessionId == nil || sessionId.length < 1) {
        [FilelugUtility alertEmptyUserSessionFromViewController:self];
//        [FilelugUtility alertUserNeverConnectedWithViewController:self loginSuccessHandler:^(NSURLResponse *response, NSData *data) {
//            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                self.processing = @NO;
//
//                [self internalReloadDataWithSelectedSegmentIndex:selectedSegmentIndex tryAgainIfConnectionFailed:tryAgainIfConnectionFailed];
//            });
//        }];
    } else {
        self.processing = @YES;
        
        DirectoryService *directoryService = [[DirectoryService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];
        
        [directoryService findUploadHistoryWithTransferHistoryType:selectedSegmentIndex session:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            self.processing = @NO;
            
            NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];
            
            if (statusCode == 200) {
                NSError *parseError;
                self.transferHistories = [DirectoryService parseJsonAsTransferHistoryModelArray:data error:&parseError];
                
                if (parseError) {
                    NSString *dataContent;
                    
                    if (data && [data length] > 0) {
                        dataContent = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    } else {
                        dataContent = @"";
                    }
                    
                    NSLog(@"Error on parsing json data as upload history model array. JSON data=%@. %@, %@", dataContent, parseError, [parseError userInfo]);
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.tableView reloadData];
                    });
                }
            } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
                self.processing = @YES;

                [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                    // do not care if lug server id is empty

                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        [self internalReloadDataWithSelectedSegmentIndex:selectedSegmentIndex tryAgainIfFailed:NO];
                    });
                } failureHandler:^(NSData *loginData, NSURLResponse *loginResponse, NSError *loginError) {
                    self.processing = @NO;

                    NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                    [self alertToTryAgainWithMessagePrefix:messagePrefix response:response data:data error:error];
                }];
//                [self.authService reloginOnlyWithNewPassword:nil onNoActiveUserHandler:^() {
//                    [FilelugUtility showConnectionViewControllerFromParent:self];
//                } successHandler:^(NSURLResponse *lresponse, NSData *ldata) {
//                    self.processing = @NO;
//
//                    // do not care if lug server id is empty
//
//                    [self internalReloadDataWithSelectedSegmentIndex:selectedSegmentIndex tryAgainIfConnectionFailed:NO];
//                } failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
//                    self.processing = @NO;
//
//                    NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");
//
//                    [self alertToTryAgainWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror];
//                }];
            } else {
                // no possible for error 503 because the service do not care about desktop socket connection
                
                NSString *messagePrefix = NSLocalizedString(@"Error on finding all upload histories.", @"");
                
                [self alertToTryAgainWithMessagePrefix:messagePrefix response:response data:data error:error];
            }
        }];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSArray *histories = [NSArray arrayWithArray:self.transferHistories];
    
    long long int totalBytes = 0;
    for (TransferHistoryModel *model in histories) {
        totalBytes += [model.fileSize longLongValue];
    }
    
    long fileCount = (long) [self.transferHistories count];
    
    NSString *displaySize = [Utility byteCountToDisplaySize:totalBytes];
    
    NSString *searchText = [NSString stringWithFormat:NSLocalizedString(@"Search: %@", @""), (self.actionSheetButtons)[@(self.selectedSegmentIndex)]];
    
    if (fileCount > 1) {
        return [searchText stringByAppendingFormat:@"\n%@", [NSString stringWithFormat:NSLocalizedString(@"%ld files uploaded successfully, total size: %@", @""), fileCount, displaySize]];
    } else {
        return [searchText stringByAppendingFormat:@"\n%@", [NSString stringWithFormat:NSLocalizedString(@"%ld file uploaded successfully, total size: %@", @""), fileCount, displaySize]];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (self.transferHistories ? [self.transferHistories count] : 0);
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat height;

    if ([self.preferredContentSizeCategoryService isXXLargeContentSizeCategory]) {
        height = 100;
    } else if ([self.preferredContentSizeCategoryService isMediumOrLargeContentSizeCategory]) {
        height = 80;
    } else {
        height = 60;
    }

    return height;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"UploadHistoryCell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];

    // configure the preferred font

    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    cell.textLabel.textColor = [UIColor darkTextColor];
    cell.textLabel.adjustsFontSizeToFitWidth = NO;
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.lineBreakMode = NSLineBreakByCharWrapping;
    cell.textLabel.textAlignment = NSTextAlignmentNatural;

    cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    cell.detailTextLabel.textColor = [UIColor aquaColor];
    cell.detailTextLabel.adjustsFontSizeToFitWidth = NO;
    cell.detailTextLabel.numberOfLines = 1;
    cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    cell.detailTextLabel.textAlignment = NSTextAlignmentNatural;
    
    TransferHistoryModel *transferHistoryModel = self.transferHistories[(NSUInteger) indexPath.row];
    
    if (transferHistoryModel) {
        cell.imageView.image = [DirectoryService imageForLocalFilePath:transferHistoryModel.filename isDirectory:NO];
        
        NSString *displaySize = [Utility byteCountToDisplaySize:[transferHistoryModel.fileSize longLongValue]];
        NSString *displayDatetime = [Utility dateStringFromDate:[Utility dateFromJavaTimeMilliseconds:transferHistoryModel.endTimestamp]];
        
        cell.textLabel.text = transferHistoryModel.filename;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@ %@\n%@ %@", displaySize, NSLocalizedString(@"Datetime prop", @""), displayDatetime, NSLocalizedString(@"to", @""), transferHistoryModel.computerName];
    }
    
    return cell;
}

- (void)alertToTryAgainWithMessagePrefix:messagePrefix response:response data:data error:error {
    UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self internalReloadDataWithSelectedSegmentIndex:self.selectedSegmentIndex tryAgainIfFailed:YES];
        });
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self internalReloadDataWithSelectedSegmentIndex:self.selectedSegmentIndex tryAgainIfFailed:NO];
        });
    }];
}

@end
