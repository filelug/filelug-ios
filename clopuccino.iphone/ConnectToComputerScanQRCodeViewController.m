#import "ConnectToComputerScanQRCodeViewController.h"
#import "FilelugUtility.h"

#define kRowHeightOfDescriptionCell     150
#define kRowHeightOfImageCell           280
#define kTagOfScannerView               1

@interface ConnectToComputerScanQRCodeViewController ()

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

@property(nonatomic) BOOL scannable;

@property(nonatomic, strong) UserComputerService *userComputerService;

@end

@implementation ConnectToComputerScanQRCodeViewController

@synthesize processing;

@synthesize progressView;

- (void)viewDidLoad {
    [super viewDidLoad];

    self.processing = @NO;

    self.scannable = YES;

    [self.currentStepButtonItem setTitle:NSLocalizedString(@"Title Scan", @"")];

    // Towards down Gesture recogniser for swiping - dismiss itself
    UISwipeGestureRecognizer *rightRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(rightSwipeHandle:)];
    rightRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
    [rightRecognizer setNumberOfTouchesRequired:1];
    [self.view addGestureRecognizer:rightRecognizer];
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

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) context:NULL];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UserComputerService *)userComputerService {
    if (!_userComputerService) {
        _userComputerService = [[UserComputerService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];
    }

    return _userComputerService;
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
                        MBProgressHUD *progressHUD = [Utility prepareProgressViewWithSuperview:self.view inTabWithTabName:nil refreshControl:nil];

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

- (void)rightSwipeHandle:(UISwipeGestureRecognizer *)gestureRecognizer {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.navigationController popViewControllerAnimated:YES];
    });
}

//// Overrides the following two methods to disable orientation and limited to portrait
//
//- (BOOL) shouldAutorotate {
//    return NO;
//}
//
//- (UIInterfaceOrientationMask) supportedInterfaceOrientations {
//    return UIInterfaceOrientationMaskPortrait;
//    // return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
//}
//
//- (UIInterfaceOrientation) preferredInterfaceOrientationForPresentation {
//    // Return the orientation you'd prefer - this is what it launches to. The
//    // user can still rotate. You don't have to implement this method, in which
//    // case it launches in the current orientation
//    return UIInterfaceOrientationPortrait;
//}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *descriptionCellIdentifier = @"DescriptionCell";
    static NSString *cameraCellIdentifier = @"CameraCell";

    [tableView setSeparatorColor:[UIColor clearColor]];
    
    UITableViewCell *cell;
    
    if (indexPath.row < 1) {
        // description cell
        
        cell = [tableView dequeueReusableCellWithIdentifier:descriptionCellIdentifier];

        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:descriptionCellIdentifier];

            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;

            cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
            cell.textLabel.textColor = [UIColor darkTextColor];
            cell.textLabel.numberOfLines = 5;
            cell.textLabel.adjustsFontSizeToFitWidth = NO;
            cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
            cell.textLabel.textAlignment = NSTextAlignmentNatural;

            cell.textLabel.text = NSLocalizedString(@"Description of connecting to computer with QRCode scanning", @"");
            cell.imageView.image = [UIImage imageNamed:@"number-3-active"];
        }
    } else {
        cell = [tableView dequeueReusableCellWithIdentifier:cameraCellIdentifier];
        
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cameraCellIdentifier];
            
            ScannerView *scannerView = [[ScannerView alloc] initWithDelegate:self];

            scannerView.tag = kTagOfScannerView;
            
            [cell.contentView addSubview:scannerView];
        }
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return (indexPath.row < 1) ? kRowHeightOfDescriptionCell : kRowHeightOfImageCell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 0;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row > 0) {
        // camera row - show scanner
        
        ScannerView *scannerView = [cell.contentView viewWithTag:kTagOfScannerView];
        
        if (scannerView) {
            if ([scannerView isStarting]) {
                [scannerView stop];
            }

            [scannerView startWithViewRect:cell.contentView.bounds];
        }
    }
}

#pragma mark - ScannerViewDelegate

- (void)scannerView:(ScannerView *)scannerView decodeWithMetatdataObjects:(NSArray *)metadataObjects {
    if (self.scannable) {
        self.scannable = NO;

        dispatch_queue_t connectToComputerQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

        dispatch_async(connectToComputerQueue, ^{
            AVMetadataMachineReadableCodeObject *metadataObject = metadataObjects.firstObject;

            NSString *scannedOutput = metadataObject.stringValue;

            if (![self presentedViewController] && scannedOutput && [scannedOutput hasPrefix:QR_CODE_PREFIX]) {
                // send QR code to server to create new computer and setup connection between the computer and the server

                self.processing = @YES;

                NSUserDefaults *userDefaults = [Utility groupUserDefaults];

                NSString *sessionId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

                [self.userComputerService createComputerWithQRCode:scannedOutput session:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

                    void (^connectToComputerFailureHandler)(NSData *, NSURLResponse *, NSError *) = ^void(NSData *connectData, NSURLResponse *connectResponse, NSError *connectError) {
                        // prompt to scan again

                        self.processing = @NO;

                        dispatch_async(connectToComputerQueue, ^{
                            NSInteger statusCode = [(NSHTTPURLResponse *) connectResponse statusCode];

                            if (statusCode == 501) {
                                NSString *messageTitle = NSLocalizedString(@"Refresh QR code", @"");

                                NSString *message = NSLocalizedString(@"Expired QR code and need refresh", @"");

                                [Utility viewController:self alertWithMessageTitle:messageTitle messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:^(UIAlertAction *action) {
                                    self.scannable = YES;
                                }];
                            } else {
                                NSString *message = [AuthService prepareFailedConnectToComputerMessageWithResponse:connectResponse error:connectError data:connectData];

                                [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"Try Again", @"") containsCancelAction:YES cancelTitle:NSLocalizedString(@"Cancel", @"") delayInSeconds:0 actionHandler:^(UIAlertAction *action) {
                                    self.scannable = YES;
                                } cancelHandler:^(UIAlertAction *action) {
                                    // pop to root, the SettingsViewController

                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
                                    });
                                }];
                            }
                        });
                    };

                    NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

                    if (statusCode == 200) {
                        NSError *parseError;
                        NSDictionary *responseDictionary = [Utility parseJsonAsDictionaryFromData:data error:&parseError];

                        if (!parseError) {
                            /*
                             {
                                "computer-id" : 89765,
                                "computer-group" : "GENERAL",
                                "computer-name" : "ALBERT'S WORKSTATION",
                                "lug-server-id":"r1"
                            }
                             */

                            NSNumber *createdComputerId = responseDictionary[@"computer-id"];
//                            NSString *createdComputerGroup = responseDictionary[@"computer-group"];
                            NSString *createdComputerName = responseDictionary[@"computer-name"];
//                            NSString *createdLugServerId = responseDictionary[@"lug-server-id"];

                            // connect to computer

                            NSString *userId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_ID];

                            NSNumber *showHidden = [userDefaults objectForKey:USER_DEFAULTS_KEY_SHOW_HIDDEN];

                            if (!showHidden) {
                                showHidden = @NO;
                            }

                            // delay for 5 seconds to make sure the computer connect to the server

                            double delayInSeconds = 5.0;
                            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));
                            dispatch_after(popTime, connectToComputerQueue, ^(void) {
                                [self.userComputerService connectToComputerWithUserId:userId computerId:createdComputerId showHidden:showHidden session:sessionId successHandler:^(NSURLResponse *connectResponse, NSData *connectData) {
                                    // pop to root, the SettingsViewController

                                    // To prevent error like: This application is modifying the autolayout engine from a background thread after the engine was accessed from the main thread.
                                    // use main queue
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        [scannerView stop];
                                    });

                                    self.processing = @NO;

                                    // TODO: create another action to to change computer name.

                                    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Connected to the computer %@ successfully", @""), createdComputerName];

                                    [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:^(UIAlertAction *action) {
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            [self.navigationController dismissViewControllerAnimated:YES completion:nil];
//                                            [self.navigationController popToRootViewControllerAnimated:YES];
                                        });
                                    }];
                                } failureHandler:^(NSData *connectData, NSURLResponse *connectResponse, NSError *connectError) {
                                    connectToComputerFailureHandler(connectData, connectResponse, connectError);
                                }];
                            });
                        } else {
                            NSData *connectData = [NSLocalizedString(@"Incorrect response data", @"") dataUsingEncoding:NSUTF8StringEncoding];

                            connectToComputerFailureHandler(connectData, response, nil);
                        }
                    } else {
                        connectToComputerFailureHandler(data, response, error);
                    }
                }];
            } else {
                self.scannable = YES;
            }
        });
    }
}

@end
