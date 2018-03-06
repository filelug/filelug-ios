#import "FKEditingPackedUploadDescriptionViewController.h"
#import "Utility.h"
#import "UserComputerDao.h"
#import "AuthService.h"
#import "MBProgressHUD.h"
#import "UploadDescriptionDataSource.h"
#import "UploadDescriptionService.h"


@interface FKEditingPackedUploadDescriptionViewController ()

@property(nonatomic, strong) UserComputerDao *userComputerDao;

@property(nonatomic, strong) AuthService *authService;

@end

@implementation FKEditingPackedUploadDescriptionViewController

@synthesize processing;

@synthesize progressView;

- (void)viewDidLoad {
    [super viewDidLoad];

    self.processing = @NO;
    
    if (_descriptionNavigationItem) {
        [_descriptionNavigationItem setTitle:NSLocalizedString(@"Enter customized description", @"")];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // adding observers

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangePreferredContentSize:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];

    [self addObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];

    // Register for keyboard shown/hidden to move up/down the editing area of text view
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWasShown:) name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillBeHidden:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // insert current text and cursor to the end of the document

    NSString *text;

    if (self.uploadDescriptionDataSource && self.uploadDescriptionDataSource.uploadDescriptionService) {
        text = [self.uploadDescriptionDataSource.uploadDescriptionService customizedValue];
    }

    if (!text || [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length < 1) {
        text = NSLocalizedString(@"Upload Summary", @"");
    }

    [self.textView setText:text];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.textView becomeFirstResponder];
        
        [self.textView setSelectedRange:NSMakeRange([self.textView text].length, 0)];
    });
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardDidShowNotification object:nil];

    [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) context:NULL];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];

    if (self.progressView) {
        self.progressView = nil;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (UserComputerDao *)userComputerDao {
    if (!_userComputerDao) {
        _userComputerDao = [[UserComputerDao alloc] init];
    }

    return _userComputerDao;
}

- (AuthService *)authService {
    if (!_authService) {
        _authService = [[AuthService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];
    }

    return _authService;
}

- (BOOL)isLoading {
    return (self.processing && [self.processing boolValue]);
}

- (void)stopLoading {
    self.processing = @NO;
}

- (void)didChangePreferredContentSize:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.textView resignFirstResponder];

//        // scroll to the end -- Not working well
//        NSUInteger lastCharacterPosition = self.textView.text.length > 0 ? self.textView.text.length - 1 : 0;
//        NSRange lastCharacterRange = NSMakeRange(lastCharacterPosition, 1);
//        [self.textView scrollRangeToVisible:lastCharacterRange];
    });

    self.textView.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.textView.textColor = [UIColor darkTextColor];
    self.textView.textAlignment = NSTextAlignmentNatural;

    [self.textView invalidateIntrinsicContentSize];
}

#pragma mark - NSKeyValueObserving

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(processing))]) {
        NSNumber *newValue = change[NSKeyValueChangeNewKey];
        NSNumber *oldValue = change[NSKeyValueChangeOldKey];

        if (![newValue isEqualToNumber:oldValue]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([newValue boolValue]) {
                    if (!self.progressView) {
                        MBProgressHUD *progressHUD = [Utility prepareProgressViewWithSuperview:self.view inTabWithTabName:nil refreshControl:nil];

                        self.progressView = progressHUD;
                    } else {
                        [self.progressView show:YES];
                    }
                } else {
                    if (self.progressView) {
                        [self.progressView hide:YES];
                    }
                }
            });
        }
    }
}

- (IBAction)cancel:(id)sender {
    [self.textView endEditing:YES];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self dismissOrPopupViewController];
    });
}

- (void)dismissOrPopupViewController {
    if (self.navigationController) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (IBAction)saveText:(id)sender {
    [self.textView endEditing:YES];
    
    NSString *customizedDescription = [self.textView text];
    
    if (!customizedDescription || [customizedDescription stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length < 1) {
        // alert empty description
        
        [Utility viewController:self alertWithMessageTitle:@"" messageBody:NSLocalizedString(@"Empty description", @"") actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
    } else {
        if (self.selectedType) {
            if (self.uploadDescriptionDataSource) {
                if (!self.uploadDescriptionDataSource.uploadDescriptionService || !self.uploadDescriptionDataSource.uploadDescriptionService.type || ![self.selectedType isEqualToNumber:self.uploadDescriptionDataSource.uploadDescriptionService.type]) {
                    self.uploadDescriptionDataSource.uploadDescriptionService = [[UploadDescriptionService alloc] initWithUploadDescriptionType:self.selectedType uploadDescriptionValue:customizedDescription];
                } else {
                    self.uploadDescriptionDataSource.uploadDescriptionService.customizedValue = customizedDescription;
                }
            }
        }

        // block as a local variable to dismiss view controller or back to the last view controller

        void (^dismissOrPopupBlock)(void) = ^void() {
            double delayInSeconds = 0.3;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));

            dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
                [self dismissOrPopupViewController];
            });
        };

        if (self.uploadDescriptionDataSource && self.uploadDescriptionDataSource.uploadDescriptionService && [self.uploadDescriptionDataSource needPersistIfChanged]) {
            // update description value to server and then update local db

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self updateUploadDescriptionWithTryAgainIfFailed:YES completionHandler:^() {
                    dismissOrPopupBlock();
                }];
            });
        } else {
            dismissOrPopupBlock();
        }
    }
}

- (void)updateUploadDescriptionWithTryAgainIfFailed:(BOOL)tryAgainIfFailed completionHandler:(void (^)(void))completionHandler {
    self.processing = @YES;

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    if (self.uploadDescriptionDataSource && self.uploadDescriptionDataSource.uploadDescriptionService) {
        [self.uploadDescriptionDataSource.uploadDescriptionService persistWithSession:sessionId completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
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
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        [self updateUploadDescriptionWithTryAgainIfFailed:NO completionHandler:completionHandler];
                    });
                } failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
                    self.processing = @NO;

                    NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                    [self processCommonRequestFailuresWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror tryAgainCompletionHandler:completionHandler];
                }];
//                // Use login instead of login-only because we need to make sure the user-computer exists.
//                // But we do not care if desktop connected. So we don't care if value of lug-server-id exits.
//
//                [self.authService reloginCurrentUserComputerWithSuccessHandler:^(NSURLResponse *lresponse, NSData *ldata) {
//                    self.processing = @NO;
//
//                    // Get the new session id, and the session should contain the user computer data
//                    // because it is from the login, not login-only.
//
//                    [self updateUploadDescriptionWithCompletionHandler:completionHandler];
//                } failureHandler:^(NSURLResponse *lresponse, NSData *ldata, NSError *lerror) {
//                    self.processing = @NO;
//
//                    NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");
//
//                    [self processCommonRequestFailuresWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror tryAgainCompletionHandler:completionHandler];
//                }];
            } else {
                // no possible for error 503 because the service do not care about desktop socket connection

                self.processing = @NO;

                NSString *messagePrefix = NSLocalizedString(@"Failed to change upload directory2", @"");

                [self processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainCompletionHandler:completionHandler];
            }
        }];
    }
}

- (void)processCommonRequestFailuresWithMessagePrefix:(NSString *)messagePrefix response:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error tryAgainCompletionHandler:(void(^)(void))completionHandler {
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

- (void)keyboardWasShown:(NSNotification *)aNotification {
    // Example of values:
    // UIKeyboardFrameBeginUserInfoKey = "NSRect: {{0, 264}, {320, 216}}";
    // UIKeyboardFrameEndUserInfoKey = "NSRect: {{0, 480}, {320, 216}}";
    
    NSDictionary *info = [aNotification userInfo];
    CGSize kbSize = [info[UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height, 0.0);
    // add additional scroll area around content
    self.textView.contentInset = contentInsets;
    // adjust indicators inside of insets
    self.textView.scrollIndicatorInsets = contentInsets;
}

- (void)keyboardWillBeHidden:(NSNotification *)aNotification {
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    self.textView.contentInset = contentInsets;
    self.textView.scrollIndicatorInsets = contentInsets;
}

@end
