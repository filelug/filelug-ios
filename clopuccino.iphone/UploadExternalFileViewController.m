#import "UploadExternalFileViewController.h"
#import "RootDirectoryViewController.h"
#import "AppDelegate.h"
#import "MenuTabBarController.h"
#import "AppService.h"
#import "FilelugUtility.h"
#import "FilelugFileUploadService.h"

@interface UploadExternalFileViewController ()

@property(nonatomic, strong) UserDao *userDao;

@property(nonatomic, strong) FileUploadGroupDao *fileUploadGroupDao;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) DirectoryService *directoryService;

@property(nonatomic, strong) UserComputerService *userComputerService;

@property(nonatomic, strong) UserComputerDao *userComputerDao;

@property(nonatomic, strong) AppService *appService;

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

@property(nonatomic, strong) UploadSubdirectoryService *uploadSubdirectoryService;

@property(nonatomic, strong) UploadNotificationService *uploadNotificationService;

@property(nonatomic, strong) FilelugFileUploadService *fileUploadService;

@end

const NSInteger NUMBER_OF_SECTIONS = 2;

const NSInteger NUMBER_OF_ROWS_IN_SECTION_TO_CONFIGURE = 5;

// section 0
const NSInteger TABLE_VIEW_SECTION_TO_CONFIGURE =       0;
const NSInteger TABLE_VIEW_ROW_CURRENT_COMPUTER =       0;
const NSInteger TABLE_VIEW_ROW_UPLOAD_ROOT_DIRECTORY =  1;
const NSInteger TABLE_VIEW_ROW_UPLOAD_SUB_DIRECTORY =   2;
const NSInteger TABLE_VIEW_ROW_DESCRIPTION =            3;
const NSInteger TABLE_VIEW_ROW_NOTIFICATION =           4;

// section 1
const NSInteger TABLE_VIEW_SECTION_TO_LIST_UPLOAD_EXTERNAL_FILES = 1;


@implementation UploadExternalFileViewController

@synthesize processing;

@synthesize progressView;

- (void)viewDidLoad {
    [super viewDidLoad];

    self.processing = @NO;

    [Utility viewController:self useNavigationLargeTitles:YES];

    _preferredContentSizeCategoryService = [[PreferredContentSizeCategoryService alloc] init];
    
    // Move file to Documents/filelug-delete
    
    [self moveFilesToExternalRootDirectory];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if ([self isMovingToParentViewController]) {
        // get upload-related settings from db only when being pushed into, not back from other view controller

        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSString *userComputerId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

        if (userComputerId) {
            UserComputerWithoutManaged *userComputerWithoutManaged = [self.userComputerDao findUserComputerForUserComputerId:userComputerId];

            if (userComputerWithoutManaged) {
                self.directory = userComputerWithoutManaged.uploadDirectory;

                self.uploadSubdirectoryService = [[UploadSubdirectoryService alloc] initWithPersistedTypeAndValue];
                self.uploadDescriptionService = [[UploadDescriptionService alloc] initWithPersistedTypeAndValue];
                self.uploadNotificationService = [[UploadNotificationService alloc] initWithPersistedType];
            }
        }
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangePreferredContentSize:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];

    [self addObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [_uploadBarButton setEnabled:(_absolutePaths && [_absolutePaths count] > 0)];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
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

- (BOOL)isLoading {
    return (self.processing && [self.processing boolValue]);
}

- (void)stopLoading {
    self.processing = @NO;
}

- (void)moveFilesToExternalRootDirectory {
    // Move files to Documents/filelug_exteranl
    
    NSMutableArray *movedFilePaths = [NSMutableArray array];

    NSString *externalRootDirectory = [DirectoryService directoryForExternalFilesWithCreatedIfNotExists:YES];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    for (NSString *absolutePath in _absolutePaths) {
        NSString *filename = [[absolutePath lastPathComponent] stringByRemovingPercentEncoding];
        
        [self moveFileWithAbsolutePath:absolutePath toDirectory:externalRootDirectory withNewFilename:filename andSaveNewPathToTargetArray:&movedFilePaths withFileManager:fileManager];
    }
    
    self.absolutePaths = movedFilePaths;
}

- (void)didChangePreferredContentSize:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

// Make sure the filename is unescaped by removing percent encoding
- (void)moveFileWithAbsolutePath:(NSString *)absolutePath toDirectory:(NSString *)directoryPath withNewFilename:(NSString *)filename andSaveNewPathToTargetArray:(NSMutableArray **)targetArray withFileManager:(NSFileManager *)fileManager {
    NSString *targetAbsolutePath = [directoryPath stringByAppendingPathComponent:filename];
    
    if ([fileManager fileExistsAtPath:targetAbsolutePath]) {
        NSString *fileBaseName = [filename stringByDeletingPathExtension];
        NSString *fileExtension = [filename pathExtension];
        
        int randomInteger = arc4random() % 100;
        
        NSString *filename2;
        if (fileExtension && [fileExtension length] > 0) {
            filename2 = [NSString stringWithFormat:@"%@-%d.%@", fileBaseName, randomInteger, fileExtension];
        } else {
            filename2 = [NSString stringWithFormat:@"%@-%d", fileBaseName, randomInteger];
        }
        
        [self moveFileWithAbsolutePath:absolutePath toDirectory:directoryPath withNewFilename:filename2 andSaveNewPathToTargetArray:targetArray withFileManager:fileManager];
    } else {
        NSError *moveError;
        [fileManager moveItemAtPath:absolutePath toPath:targetAbsolutePath error:&moveError];
        
        if (moveError) {
            NSLog(@"Error on moving file from \"%@\" to \"%@\". Reason:\n%@", absolutePath, targetAbsolutePath, [moveError userInfo]);
        } else {
            if (targetArray) {
                [*targetArray addObject:targetAbsolutePath];
            }
        }
    }
}

- (UserDao *)userDao {
    if (!_userDao) {
        _userDao = [[UserDao alloc] init];
    }
    
    return _userDao;
}

- (FileUploadGroupDao *)fileUploadGroupDao {
    if (!_fileUploadGroupDao) {
        _fileUploadGroupDao = [[FileUploadGroupDao alloc] init];
    }
    
    return _fileUploadGroupDao;
}

- (AuthService *)authService {
    if (!_authService) {
        _authService = [[AuthService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];
    }
    
    return _authService;
}

- (DirectoryService *)directoryService {
    if (!_directoryService) {
        _directoryService = [[DirectoryService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];
    }
    
    return _directoryService;
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

- (FilelugFileUploadService *)fileUploadService {
    if (!_fileUploadService) {
        _fileUploadService = [[FilelugFileUploadService alloc] init];
    }

    return _fileUploadService;
}

- (BOOL)needPersistIfChanged {
    return NO;
}

- (IBAction)close:(id)sender {
    // delete file

    if (self.absolutePaths && [self.absolutePaths count] > 0) {
        for (NSString *filePath in self.absolutePaths) {
            NSError *deleteError;
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:&deleteError];
            
            if (deleteError) {
                NSLog(@"Error on deleting file: %@\nReason:\n%@", filePath, [deleteError userInfo]);
            }
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self dismissViewControllerAnimated:YES completion:nil];
    });
}

- (IBAction)upload:(id)sender {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_async(queue, ^{
        NSString *targetDirectory = self.directory;
        NSArray *localAbsolutPaths = [NSArray arrayWithArray:self.absolutePaths];
        
        if (!targetDirectory || [targetDirectory stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length < 1) {
            // prompt that empty directory not allowed

            NSString *message = NSLocalizedString(@"Directory should not be empty", @"");

            [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
        } else {
            BOOL keepUploading = YES;
            
            for (NSString *localAbsolutePath in localAbsolutPaths) {
                NSString *filename = [localAbsolutePath lastPathComponent];
                
                if (!localAbsolutePath || ![Utility validFilename:filename]) {
                    // validate filename
                    
                    keepUploading = NO;
                    
                    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Filename is empty or contains illegal character", @""), filename];

                    [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];

                    break;
                }
            }
            
            if (keepUploading) {
                [self internalUploadWithLocalAbsoluteFilePaths:localAbsolutPaths targetDirectory:self.directory tryAgainIfFailed:YES];
            }
        }
    });
}

- (void)internalUploadWithLocalAbsoluteFilePaths:(NSArray <NSString *> *)localAbsolutePaths targetDirectory:(NSString *)targetDirectory tryAgainIfFailed:(BOOL)tryAgainIfFailed {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];
    
    NSString *tempLugServerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID];
    
    if (sessionId == nil || sessionId.length < 1) {
        [FilelugUtility alertEmptyUserSessionFromViewController:self];
//        [FilelugUtility alertUserNeverConnectedWithViewController:self loginSuccessHandler:^(NSURLResponse *response, NSData *data) {
//            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                self.processing = @NO;
//
//                [self internalUploadWithLocalAbsoluteFilePaths:localAbsolutePaths targetDirectory:targetDirectory];
//            });
//        }];
    } else if (tempLugServerId == nil || tempLugServerId.length < 1) {
        self.processing = @NO;
        
        [self requestConnectWithAuthService:self.authService userDefaults:userDefaults absolutePaths:localAbsolutePaths directory:targetDirectory];
    } else {
        self.processing = @YES;
        
        SystemService *systemService = [[SystemService alloc] initWithCachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeInterval:CONNECTION_TIME_INTERVAL];
        
        [systemService pingDesktop:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
            
            dispatch_async(queue, ^{
                NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];
                
                if (statusCode == 200) {
                    [SystemService parsePingDesktopResponseJson:data completionHandler:^(NSDictionary *dictionary) {
                        __block BOOL canUpload = YES;
                        
                        dispatch_async(queue, ^{
                            if (dictionary && dictionary[@"upload-size-limit"]) {
                                NSNumber *uploadSizeLimit = dictionary[@"upload-size-limit"];
                                
                                long long int fileSizeLimit = [uploadSizeLimit longLongValue];

                                // Collect and prompt too-large files for once
                                
                                NSMutableIndexSet *tooLargeAbsoluteFileIndexSet = [[NSMutableIndexSet alloc] init];
                                
                                NSUInteger fileCount = [localAbsolutePaths count];
                                
                                for (NSUInteger index = 0; index < fileCount; index++) {
                                    NSString *absolutePath = localAbsolutePaths[index];
                                    
                                    NSError *fileSizeError;
                                    long long int fileSize = [Utility fileSizeWithAbsolutePath:absolutePath error:&fileSizeError];

                                    if (fileSizeError || fileSize > fileSizeLimit) {
                                        canUpload = NO;
                                        
                                        [tooLargeAbsoluteFileIndexSet addIndex:index];
                                    }
                                }
                                
                                if ([tooLargeAbsoluteFileIndexSet count] > 0) {
                                    self.processing = @NO;
                                    
                                    NSMutableString *tooLargeFilenames = [NSMutableString string];
                                    
                                    [tooLargeAbsoluteFileIndexSet enumerateIndexesUsingBlock:^(NSUInteger filenameIndex, BOOL *stop) {
                                        [tooLargeFilenames appendFormat:@"\n%@", [localAbsolutePaths[filenameIndex] lastPathComponent]];
                                    }];
                                    
                                    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"exceed.upload.size.limit3", @""), [tooLargeFilenames mutableCopy]];

                                    // Do not ask if upload others if only one selected, or all uploads are too large
                                    if ([localAbsolutePaths count] < 2 || [localAbsolutePaths count] == [tooLargeAbsoluteFileIndexSet count]) {
                                        [Utility viewController:self alertWithMessageTitle:NSLocalizedString(@"File Too Large", @"") messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                                    } else {
                                        [Utility viewController:self alertWithMessageTitle:NSLocalizedString(@"File Too Large", @"") messageBody:message actionTitle:NSLocalizedString(@"Upload other selected files", @"") containsCancelAction:YES cancelTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:^(UIAlertAction *action) {
                                            [self onUploadOtherFilesAfterTooLargeFilesRemovedWithIndexSet:tooLargeAbsoluteFileIndexSet];
                                        } cancelHandler:nil];
                                    }
                                }
                            }
                            
                            if (canUpload) {
                                // create all the transfer keys for the uploading files first

                                NSMutableArray *transferKeys = [NSMutableArray array];
                                NSMutableArray *filenames = [NSMutableArray array];

                                for (NSString *absolutePath in localAbsolutePaths) {
                                    // generate new transfer key - unique for all users
                                    NSString *transferKey = [Utility generateUploadKeyWithSessionId:sessionId sourceFileIdentifier:absolutePath];

                                    [transferKeys addObject:transferKey];

                                    [filenames addObject:[absolutePath lastPathComponent]];
                                }

                                // create upload summary in desktop

                                // uploadDirectory contains subdirectoryValue, if any

                                NSString *realSubdirectoryValue = [self.uploadSubdirectoryService generateRealSubdirectoryValue];

                                NSString *directoryPathWithSubdirectory;

                                if (realSubdirectoryValue && [realSubdirectoryValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
                                    directoryPathWithSubdirectory = [NSString stringWithFormat:@"%@%@%@", targetDirectory, [userDefaults stringForKey:USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR], realSubdirectoryValue];
                                } else {
                                    directoryPathWithSubdirectory = targetDirectory;
                                }

                                NSString *uploadGroupId = [Utility generateUploadGroupIdWithFilenames:filenames];

                                NSInteger subdirectoryType = self.uploadSubdirectoryService.type ? [self.uploadSubdirectoryService.type integerValue] : [UploadSubdirectoryService defaultType];

                                NSString *subdirectoryValue = [self.uploadSubdirectoryService customizable] ? [self.uploadSubdirectoryService customizedValue] : @"";

                                NSString *fullSubdirectoryPath = [self.uploadSubdirectoryService generateRealSubdirectoryValue];

                                NSInteger descriptionType = self.uploadDescriptionService.type ? [self.uploadDescriptionService.type integerValue] : [UploadDescriptionService defaultType];

                                NSString *descriptionValue = [self.uploadDescriptionService customizable] ? [self.uploadDescriptionService customizedValue] : @"";

                                NSString *fullDescriptionContent = [self.uploadDescriptionService generateRealDescriptionValueWithFilenames:filenames];

                                NSInteger notificationType = self.uploadNotificationService.type ? [self.uploadNotificationService.type integerValue] : [UploadNotificationService defaultType];

                                self.processing = @YES;

                                [self.directoryService createFileUploadSummaryWithUploadGroupId:uploadGroupId
                                                                                targetDirectory:directoryPathWithSubdirectory
                                                                                   transferKeys:transferKeys
                                                                               subdirectoryType:subdirectoryType
                                                                              subdirectoryValue:fullSubdirectoryPath
                                                                                descriptionType:descriptionType
                                                                               descriptionValue:fullDescriptionContent
                                                                               notificationType:notificationType
                                                                                        session:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID]
                                                                              completionHandler:^(NSData *dataFromCreate, NSURLResponse *responseFromCreate, NSError *errorFromCreate) {
                                    NSInteger statusCodeFromCreate = [(NSHTTPURLResponse *) responseFromCreate statusCode];

                                    if (!errorFromCreate && statusCodeFromCreate == 200) {
                                        // Save file-upload-group to local db before upload each files

                                        // The values of subdirectoryValue and descriptionValue are not the same from the ones uploaded to the server

                                        [self.fileUploadGroupDao createFileUploadGroupWithUploadGroupId:uploadGroupId
                                                                                        targetDirectory:directoryPathWithSubdirectory
                                                                                       subdirectoryType:subdirectoryType
                                                                                      subdirectoryValue:subdirectoryValue
                                                                                        descriptionType:descriptionType
                                                                                       descriptionValue:descriptionValue
                                                                                       notificationType:notificationType
                                                                                         userComputerId:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID]
                                                                                      completionHandler:^() {
                                            // upload file one by one

                                            dispatch_async(queue, ^{
                                                const NSUInteger fileCount = [localAbsolutePaths count];

                                                __block int failureCount = 0;

                                                @try {
                                                    for (NSUInteger index = 0; index < fileCount; index++) {
                                                        NSString *localAbsolutePath = localAbsolutePaths[index];

                                                        NSString *filename = filenames[index];
                                                        NSString *transferKey = transferKeys[index];

                                                        FileUploadStatusModel *fileUploadStatusModel = [[FileUploadStatusModel alloc] initWithTransferKey:transferKey transferredSize:@0 fileSize:@0 fileLastModifiedDate:@0];

                                                        // save and upload one-by-one
                                                        [self.fileUploadService uploadFileFromFileObject:localAbsolutePath sourceType:@(ASSET_FILE_SOURCE_TYPE_EXTERNAL_FILE) sessionId:sessionId fileUploadGroupId:uploadGroupId directory:directoryPathWithSubdirectory filename:filename shouldCheckIfLocalFileChanged:NO fileUploadStatusModel:fileUploadStatusModel addToStartTimestampWithMillisec:index completionHandler:^(NSError *uploadError) {
                                                            if (uploadError) {
                                                                failureCount++;
                                                            }
                                                        }];
                                                    }
                                                } @finally {
                                                    // delayed to make sure there's at least one upload file of which status is preparing

                                                    dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (DELAY_UPLOAD_TIMER_INTERVAL * NSEC_PER_SEC));
                                                    dispatch_after(delayTime, queue, ^(void) {
                                                        self.processing = @NO;

                                                        if (failureCount == 0) {
                                                            // all success
                                                            NSString *message = [NSString stringWithFormat:NSLocalizedString(@"File is uploading2", @""), NSLocalizedString(@"Upload File", @"")];

                                                            NSString *buttonTitle = NSLocalizedString(@"View Status", @"");

                                                            [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:buttonTitle containsCancelAction:YES cancelTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:^(UIAlertAction *action) {
                                                                [self onGoToFileUploadViewController];
                                                            } cancelHandler:nil];
                                                        } else if (failureCount == fileCount) {
                                                            // all failed
                                                            NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Uploaded failed. Try again later", @"")];

                                                            [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                                                        } else {
                                                            // partial failure
                                                            NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Some files failed to upload", @""), failureCount, NSLocalizedString(@"Upload File", @"")];

                                                            [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                                                        }
                                                    });
                                                }
                                            });
                                        }];
                                    } else {
                                        self.processing = @NO;

                                        NSString *messagePrefix = NSLocalizedString(@"Error on upload file.", @"");

                                        [self alertToTryUploadAgainWithMessagePrefix:messagePrefix response:responseFromCreate data:dataFromCreate error:errorFromCreate absolutePaths:localAbsolutePaths directory:targetDirectory];
                                    }
                                }];
                            }
                        });
                    }];
                } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
                    self.processing = @YES;

                    [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                        if ([userDefaults objectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID]) {
                            /* recursively invoked */

                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                [self internalUploadWithLocalAbsoluteFilePaths:localAbsolutePaths targetDirectory:targetDirectory tryAgainIfFailed:NO];
                            });
                        } else {
                            // server not connected, so request connection
                            [self requestConnectWithAuthService:self.authService userDefaults:userDefaults absolutePaths:localAbsolutePaths directory:targetDirectory];
                        }
                    } failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
                        self.processing = @NO;

                        NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                        [self alertToTryUploadAgainWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror absolutePaths:localAbsolutePaths directory:targetDirectory];
                    }];
//                    [self.appService authService:self.authService reloginCurrentUserComputerFromViewController:self successHandler:^(NSURLResponse *lresponse, NSData *ldata) {
//                        if ([userDefaults objectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID]) {
//                            /* recursively invoked */
//                            [self internalUploadWithLocalAbsoluteFilePaths:localAbsolutePaths targetDirectory:targetDirectory];
//                        } else {
//                            // server not connected, so request connection
//                            [self requestConnectWithAuthService:self.authService userDefaults:userDefaults absolutePaths:localAbsolutePaths directory:targetDirectory];
//                        }
//                    } failureHandler:^(NSURLResponse *lresponse, NSData *ldata, NSError *lerror) {
//                        self.processing = @NO;
//
//                        NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");
//
//                        [self alertToTryUploadAgainWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror];
//                    }];
                } else if (tryAgainIfFailed && statusCode == 503) {
                    // server not connected, so request connection
                    [self requestConnectWithAuthService:self.authService userDefaults:userDefaults absolutePaths:localAbsolutePaths directory:targetDirectory];
                } else {
                    self.processing = @NO;
                    
                    NSString *messagePrefix = NSLocalizedString(@"Error on upload file.", @"");
                    
                    [self alertToTryUploadAgainWithMessagePrefix:messagePrefix response:response data:data error:error absolutePaths:localAbsolutePaths directory:targetDirectory];
                }
            });
        }];
    }
}

// request connect for file upload
- (void)requestConnectWithAuthService:(AuthService *)authService userDefaults:(NSUserDefaults *)userDefaults absolutePaths:(NSArray *)absolutePaths directory:(NSString *)directory {
    self.processing = @YES;

    NSString *newSessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];
    
    [authService requestConnectWithSession:newSessionId successHandler:^(NSURLResponse *rcresponse, NSData *rcdata) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self internalUploadWithLocalAbsoluteFilePaths:absolutePaths targetDirectory:directory tryAgainIfFailed:NO];
        });
    } failureHandler:^(NSData *rcdata, NSURLResponse *rcresponse, NSError *rcerror) {
        self.processing = @NO;
        
        [self alertToTryUploadAgainWithMessagePrefix:nil response:rcresponse data:rcdata error:rcerror absolutePaths:absolutePaths directory:directory];
    }];
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

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger count;
    
    if (section == TABLE_VIEW_SECTION_TO_CONFIGURE) {
        count = NUMBER_OF_ROWS_IN_SECTION_TO_CONFIGURE;
    } else if (section == TABLE_VIEW_SECTION_TO_LIST_UPLOAD_EXTERNAL_FILES) {
        count = [self.absolutePaths count];
    } else {
        count = 0;
    }
    
    return count;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return NUMBER_OF_SECTIONS;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *title;
    
    if (section == TABLE_VIEW_SECTION_TO_CONFIGURE) {
        title = NSLocalizedString(@"Settings", @"");
    } else if (section == TABLE_VIEW_SECTION_TO_LIST_UPLOAD_EXTERNAL_FILES) {
        title = NSLocalizedString(@"Files to save. Click to change filename", @"");
    }
    
    return title;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat height;

    if (indexPath.section < 1) {
        if ([self.preferredContentSizeCategoryService isXXLargeContentSizeCategory]) {
            height = 100;
        } else if ([self.preferredContentSizeCategoryService isLargeContentSizeCategory]) {
            height = 80;
        } else {
            height = 60;
        }
    } else {
        if ([self.preferredContentSizeCategoryService isLargeContentSizeCategory]) {
            height = 80;
        } else {
            height = 60;
        }
    }

    return height;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *UploadExternalFileSettingsCell = @"UploadExternalFileSettingsCell";
    static NSString *UploadExternalFileFilesCell = @"UploadExternalFileFilesCell";

    UITableViewCell *cell;
    
    NSInteger section = [indexPath section];
    NSInteger row = [indexPath row];
    
    if (section == TABLE_VIEW_SECTION_TO_CONFIGURE) {
        cell = [Utility tableView:tableView createOrDequeueCellWithStyle:UITableViewCellStyleDefault reuseIdentifier:UploadExternalFileSettingsCell forIndexPath:indexPath];

        // configure the preferred font

        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        cell.textLabel.textColor = [UIColor darkTextColor];
        cell.textLabel.numberOfLines = 1;
        cell.textLabel.adjustsFontSizeToFitWidth = NO;
        cell.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        cell.textLabel.textAlignment = NSTextAlignmentNatural;

        cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        cell.detailTextLabel.textColor = [UIColor aquaColor];
        cell.detailTextLabel.numberOfLines = 0;
        cell.detailTextLabel.adjustsFontSizeToFitWidth = NO;
        cell.detailTextLabel.lineBreakMode = NSLineBreakByCharWrapping;
        cell.detailTextLabel.textAlignment = NSTextAlignmentNatural;
        
        if (row == TABLE_VIEW_ROW_CURRENT_COMPUTER) {
            // upload to computer
            
            [cell.imageView setImage:[UIImage imageNamed:@"computer"]];
            
            [cell.textLabel setText:NSLocalizedString(@"Save To Computer", @"")];
            
            [cell setAccessoryType:UITableViewCellAccessoryNone];
            
            NSUserDefaults *userDefaults = [Utility groupUserDefaults];
            
            NSString *computerName = [userDefaults stringForKey:USER_DEFAULTS_KEY_COMPUTER_NAME];
            
            [cell.detailTextLabel setText:computerName ? computerName : @""];
        } else if (row == TABLE_VIEW_ROW_UPLOAD_ROOT_DIRECTORY) {
            // upload to directory
            
            [cell.imageView setImage:[UIImage imageNamed:@"ic_folder"]];
            
            [cell.textLabel setText:NSLocalizedString(@"All Upload To Directory", @"")];
            
            [cell.detailTextLabel setText:self.directory];
            
            [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        } else if (row == TABLE_VIEW_ROW_UPLOAD_SUB_DIRECTORY) {
            // subfolder
            
            [cell.imageView setImage:[UIImage imageNamed:@"folder-add"]];
            
            [cell.textLabel setText:NSLocalizedString(@"Subdirectory Name", @"")];
            
            [cell.detailTextLabel setText:[self.uploadSubdirectoryService displayedText]];
            
            [cell setAccessoryType:UITableViewCellAccessoryNone];
        } else if (row == TABLE_VIEW_ROW_DESCRIPTION) {
            // description
            
            [cell.imageView setImage:[UIImage imageNamed:@"note-write"]];
            
            [cell.textLabel setText:NSLocalizedString(@"Description", @"")];
            
            [cell.detailTextLabel setText:[self.uploadDescriptionService displayedText]];
            
            [cell setAccessoryType:UITableViewCellAccessoryNone];
        } else if (row == TABLE_VIEW_ROW_NOTIFICATION) {
            // notification
            
            [cell.imageView setImage:[UIImage imageNamed:@"bell"]];
            
            [cell.textLabel setText:NSLocalizedString(@"Upload Notification", @"")];
            
            [cell.detailTextLabel setText:[self.uploadNotificationService name]];
            
            [cell setAccessoryType:UITableViewCellAccessoryNone];
        } else {
            // for unknow rows
            
            [cell.imageView setImage:[UIImage imageNamed:@"ic_folder"]];
            
            [cell.textLabel setText:@""];
            
            [cell.detailTextLabel setText:@""];
            
            [cell setAccessoryType:UITableViewCellAccessoryNone];
        }
    } else if (section == TABLE_VIEW_SECTION_TO_LIST_UPLOAD_EXTERNAL_FILES) {
        cell = [Utility tableView:tableView createOrDequeueCellWithStyle:UITableViewCellStyleDefault reuseIdentifier:UploadExternalFileFilesCell forIndexPath:indexPath];

        // configure the preferred font
        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        cell.textLabel.textColor = [UIColor darkTextColor];
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.adjustsFontSizeToFitWidth = NO;
        cell.textLabel.lineBreakMode = NSLineBreakByCharWrapping;
        cell.textLabel.textAlignment = NSTextAlignmentNatural;

        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        
        NSString *fileAbsolutePath = self.absolutePaths[(NSUInteger) indexPath.row];
        
        [cell.imageView setImage:[DirectoryService imageForFileExtension:[fileAbsolutePath pathExtension]]];
        
        [cell.textLabel setText:[fileAbsolutePath lastPathComponent]];
        
        [cell setAccessoryType:UITableViewCellAccessoryNone];
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self tableView:tableView didSelectPackedUploadCellOrButtonAtRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    [self tableView:tableView didSelectPackedUploadCellOrButtonAtRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectPackedUploadCellOrButtonAtRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;
    
    if (section == TABLE_VIEW_SECTION_TO_CONFIGURE) {
        if (row == TABLE_VIEW_ROW_CURRENT_COMPUTER) {
            // Change Connected Computer
            
            // clear the selected gray - just for looking good
            [tableView deselectRowAtIndexPath:indexPath animated:NO];

            [self findAvailableComputersWithTryAgainIfFailed:YES];
        } else if (row == TABLE_VIEW_ROW_UPLOAD_ROOT_DIRECTORY) {
            // Choose upload directory
            
            RootDirectoryViewController *rootDirectoryViewController = (RootDirectoryViewController *) [Utility instantiateViewControllerWithIdentifier:@"RootDirectory"];
            
            rootDirectoryViewController.fromViewController = self;
            rootDirectoryViewController.directoryOnly = YES;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.navigationController pushViewController:rootDirectoryViewController animated:YES];
            });
        } else if (row == TABLE_VIEW_ROW_UPLOAD_SUB_DIRECTORY) {
            // subfolder

            NSArray *allNames = [UploadSubdirectoryService namesOfAllTypesWithOrder];

            if (allNames) {
                NSString *actionSheetTitle = NSLocalizedString(@"Choose type of subdirectory", @"");

                UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:actionSheetTitle message:@"" preferredStyle:UIAlertControllerStyleActionSheet];

                for (NSString *name in allNames) {
                    NSNumber *subdirectoryType = [UploadSubdirectoryService uploadSubdirectoryTypeWithUploadSubdirectoryName:name];

                    if (subdirectoryType) {
                        UIAlertAction *nameAction = [UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                            [self onChooseSubdirectoryWithSubdirectoryType:subdirectoryType];
                        }];

                        [actionSheet addAction:nameAction];
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
        } else if (row == TABLE_VIEW_ROW_DESCRIPTION) {
            // description

            NSArray *allNames = [UploadDescriptionService namesOfAllTypesWithOrder];

            if (allNames) {
                NSString *actionSheetTitle = NSLocalizedString(@"Choose type of description", @"");

                UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:actionSheetTitle message:@"" preferredStyle:UIAlertControllerStyleActionSheet];

                for (NSString *name in allNames) {
                    NSNumber *descriptionType = [UploadDescriptionService uploadDescriptionTypeWithUploadDescriptionName:name];

                    if (descriptionType) {
                        UIAlertAction *nameAction = [UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                            [self onChooseDescriptionWithDescriptionType:descriptionType];
                        }];

                        [actionSheet addAction:nameAction];
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
        } else if (row == TABLE_VIEW_ROW_NOTIFICATION) {
            // notification

            NSArray *allNames = [UploadNotificationService namesOfAllTypesWithOrder];

            if (allNames) {
                NSString *actionSheetTitle = NSLocalizedString(@"Choose type of upload notification", @"");

                UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:actionSheetTitle message:@"" preferredStyle:UIAlertControllerStyleActionSheet];

                for (NSString *name in allNames) {
                    NSNumber *notificationType = [UploadNotificationService uploadNotificationTypeWithUploadNotificationName:name];

                    if (notificationType) {
                        UIAlertAction *nameAction = [UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                            [self onChooseNotificationWithNotificationType:notificationType];
                        }];

                        [actionSheet addAction:nameAction];
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
        }
    } else if (section == TABLE_VIEW_SECTION_TO_LIST_UPLOAD_EXTERNAL_FILES) {
        // edit filename
        
        NSString *filename = [self.absolutePaths[(NSUInteger) indexPath.row] lastPathComponent];
        NSRange selectedTextRange = [filename rangeOfString:[filename stringByDeletingPathExtension]];

        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Change filename to:", @"") message:@"" preferredStyle:UIAlertControllerStyleAlert];

        [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            [textField setText:filename];

            [Utility selectTextInTextField:textField range:selectedTextRange];
        }];

        UIAlertAction *confirmChangeAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Confirm Change", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSString *newFilename = [alertController.textFields[0] text];

            [self changeFilename:filename toNewFilename:newFilename forFileAtIndexPath:[indexPath copy]];
        }];

        [alertController addAction:confirmChangeAction];

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
}

- (void)findAvailableComputersWithTryAgainIfFailed:(BOOL)tryAgainIfFailed {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSString *sessionId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

        if (!sessionId || sessionId.length < 1) {
            [FilelugUtility alertEmptyUserSessionFromViewController:self];
        } else {
            /* prepare indicator view */
            self.processing = @YES;

            [self.userComputerService findAvailableComputersWithSession:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                self.processing = @NO;
                
                NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];
                
                if (statusCode == 200) {
                    /* DO NOT create or update user first FOR NOW */
                    
                    NSError *fetchError;
                    NSArray *availableUserComputers = [self.userComputerDao userComputersFromFindAvailableComputersResponseData:data error:&fetchError];
                    
                    if (fetchError) {
                        NSString *message = NSLocalizedString(@"Error on fetching computer information. Try again later.", @"");

                        [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                    } else {
                        if (availableUserComputers
                            && [availableUserComputers count] > 0
                            && ((UserComputerWithoutManaged *) availableUserComputers[0]).computerId) {
                            // show action sheet to choose

                            UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Choose Computer Name", @"") message:@"" preferredStyle:UIAlertControllerStyleActionSheet];

                            for (UserComputerWithoutManaged *newUserComputerWithoutManaged in availableUserComputers) {
                                NSString *computerName = newUserComputerWithoutManaged.computerName;

                                UIAlertAction *action = [UIAlertAction actionWithTitle:computerName style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
                                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                        [self connectComputerWithSelectedUserComputer:newUserComputerWithoutManaged tryAgainIfFailed:YES];
                                    });
                                }];

                                [actionSheet addAction:action];
                            }

                            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:nil];
                            [actionSheet addAction:cancelAction];

                            if ([self isVisible]) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    UIView *sourceView;
                                    CGRect sourceRect;
                                    
                                    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:TABLE_VIEW_ROW_CURRENT_COMPUTER inSection:TABLE_VIEW_SECTION_TO_CONFIGURE];
                                    
                                    UITableViewCell *selectedCell = [self.tableView cellForRowAtIndexPath:indexPath]; // must be called from main thread only
                                    
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
                        } else {
                            [FilelugUtility alertNoComputerEverConnectedWithViewController:self delayInSeconds:0.1 completionHandler:nil];
                        }
                    }
                } else if (tryAgainIfFailed && (statusCode == 401 || (error && [error code] == NSURLErrorUserCancelledAuthentication))) {
                    // invalid session id

                    if (tryAgainIfFailed) {
                        // re-login to get the new session id

                        self.processing = @YES;

                        [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                            [self findAvailableComputersWithTryAgainIfFailed:NO];
                        } failureHandler:^(NSData *loginData, NSURLResponse *loginResponse, NSError *loginError) {
                            self.processing = @NO;

                            NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                            [self alertToFindAvailableComputersAgainWithMessagePrefix:messagePrefix response:response data:data error:error];
                        }];
                    } else {
                        NSString *message = NSLocalizedString(@"Error on finding connected computers", @"");

                        [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                    }

//                    // incorrect password
//
//                    NSString *message = NSLocalizedString(@"Incorrect Password", @"");
//
//                    [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                } else {
                    NSString *messagePrefix = NSLocalizedString(@"Error on finding connected computers", @"");

                    [self alertToFindAvailableComputersAgainWithMessagePrefix:messagePrefix response:response data:data error:error];
                }
            }];
        }
    });
}

- (void)alertToFindAvailableComputersAgainWithMessagePrefix:messagePrefix response:response data:data error:error {
    UIAlertAction *tryDownloadAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Upload Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        [self findAvailableComputersWithTryAgainIfFailed:YES];
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryDownloadAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        [self findAvailableComputersWithTryAgainIfFailed:NO];
    }];
}

- (void)connectComputerWithSelectedUserComputer:(UserComputerWithoutManaged *)userComputerWithoutManaged tryAgainIfFailed:(BOOL)tryAgainIfFailed {
    self.processing = @YES;

    NSString *userId = userComputerWithoutManaged.userId;
    NSNumber *computerId = userComputerWithoutManaged.computerId;
    NSNumber *showHidden = userComputerWithoutManaged.showHidden;
    NSString *computerName = userComputerWithoutManaged.computerName;

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *sessionId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    [self.userComputerService connectToComputerWithUserId:userId computerId:computerId showHidden:showHidden session:sessionId successHandler:^(NSURLResponse *response, NSData *data) {
        self.processing = @NO;

        // refresh computer name even if lug server id is not found
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
    } failureHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        self.processing = @NO;

        NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

        if (tryAgainIfFailed && (statusCode == 401 || (error && [error code] == NSURLErrorUserCancelledAuthentication))) {
            // invalid session

            if (tryAgainIfFailed) {
                // re-login to get the new session id

                self.processing = @YES;

                [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        [self connectComputerWithSelectedUserComputer:userComputerWithoutManaged tryAgainIfFailed:NO];
                    });
                } failureHandler:^(NSData *loginData, NSURLResponse *loginResponse, NSError *loginError) {
                    self.processing = @NO;

                    NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                    [self alertToConnectComputerAgainWithMessagePrefix:messagePrefix response:response data:data error:error userComputer:userComputerWithoutManaged];
                }];
            } else {
                NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Error on connecting to computer %@", @""), computerName];

                [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
            }
        } else if (statusCode == 501 || statusCode == 460) {
            // computer not found -- ask if user wants to find available computers again

            NSString *errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Computer %@ not exists. Do you want to find other computers to connect?", @""), computerName];

            [Utility viewController:self alertWithMessageTitle:@"" messageBody:errorMessage actionTitle:NSLocalizedString(@"Find Computers", @"") containsCancelAction:YES cancelTitle:NSLocalizedString(@"Cancel", @"") delayInSeconds:0 actionHandler:^(UIAlertAction *action) {
                // Change Connected Computer

                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionTop];
                    [self tableView:self.tableView didSelectRowAtIndexPath:indexPath];
                });
            } cancelHandler:nil];
        } else {
            NSString *messagePrefix = [NSString stringWithFormat:NSLocalizedString(@"Error on connecting to computer %@", @""), computerName];

            [self alertToConnectComputerAgainWithMessagePrefix:messagePrefix response:response data:data error:error userComputer:userComputerWithoutManaged];
        }
    }];
}

- (void)alertToConnectComputerAgainWithMessagePrefix:messagePrefix response:response data:data error:error userComputer:(UserComputerWithoutManaged *)userComputerWithoutManaged  {
    UIAlertAction *tryDownloadAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Upload Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self connectComputerWithSelectedUserComputer:userComputerWithoutManaged tryAgainIfFailed:YES];
        });
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryDownloadAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self connectComputerWithSelectedUserComputer:userComputerWithoutManaged tryAgainIfFailed:NO];
        });
    }];
}

- (void)onChooseSubdirectoryWithSubdirectoryType:(NSNumber *_Nonnull)subdirectoryType {
    BOOL customizable = [UploadSubdirectoryService isCustomizableWithType:[subdirectoryType integerValue]];

    // check if customizable
    if (customizable) {
        // let user enter customized name of subdirectory

        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:NSLocalizedString(@"Enter customized name", @"") preferredStyle:UIAlertControllerStyleAlert];

        [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            [textField setKeyboardType:UIKeyboardTypeDefault];

            // set text to the latest customized value in db
            NSString *text = [self.uploadSubdirectoryService customizedValue];

            [textField setText:(text ? text : NSLocalizedString(@"New Folder", @""))];
        }];

        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSString *customizedName = [alertController.textFields[0] text];

            [self onEnteredSubdirectoryWithCustomizedName:customizedName subdirectoryType:subdirectoryType];
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
        // keep the old customized values so it shows when user changed back from non-customized option.

        if (!self.uploadSubdirectoryService.type || ![self.uploadSubdirectoryService.type isEqualToNumber:subdirectoryType]) {
            NSString *oldSubdirectoryCustomizedValue = [self.uploadSubdirectoryService customizedValue];

            self.uploadSubdirectoryService = [[UploadSubdirectoryService alloc] initWithUploadSubdirectoryType:subdirectoryType uploadSubdirectoryValue:oldSubdirectoryCustomizedValue];

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
        }
    }
}

- (void)onChooseDescriptionWithDescriptionType:(NSNumber *_Nonnull)descriptionType {
    if ([UploadDescriptionService isCustomizableWithType:[descriptionType integerValue]]) {
        // let user enter customized description

        FKEditingPackedUploadDescriptionViewController *editingPackedUploadDescriptionViewController = [Utility instantiateViewControllerWithIdentifier:@"FKEditingPackedUploadDescription"];

        editingPackedUploadDescriptionViewController.selectedType = descriptionType;
        editingPackedUploadDescriptionViewController.uploadDescriptionDataSource = (id) self;

        dispatch_async(dispatch_get_main_queue(), ^ {
            [self.navigationController pushViewController:editingPackedUploadDescriptionViewController animated:YES];
        });
    } else {
        // keep the old customized values so it shows when user changed back from non-customized option.

        if (!self.uploadDescriptionService.type || [self.uploadDescriptionService.type isEqualToNumber:descriptionType]) {
            NSString *oldDescriptionCustomizedValue = [self.uploadDescriptionService customizedValue];

            self.uploadDescriptionService = [[UploadDescriptionService alloc] initWithUploadDescriptionType:descriptionType uploadDescriptionValue:oldDescriptionCustomizedValue];

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
        }
    }
}

- (void)onChooseNotificationWithNotificationType:(NSNumber *_Nonnull)notificationType {
    if (!self.uploadNotificationService.type || [self.uploadNotificationService.type isEqualToNumber:notificationType]) {
        self.uploadNotificationService = [[UploadNotificationService alloc] initWithUploadNotificationType:notificationType];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
    }
}

//- (void)alertToTryAgainWithMessagePrefix:messagePrefix response:response data:data error:error {
//    UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
//        [self findAvailableComputersWithTryAgainOnInvalidSession:YES];
//    }];
//
//    [self.appService authService:self.authService alertToReloginOrTryConnectAgainWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryAgainAction inViewController:self];
//}

- (void)alertToTryUploadAgainWithMessagePrefix:messagePrefix response:response data:data error:error absolutePaths:(NSArray *)absolutePaths directory:(NSString *)directory {
    UIAlertAction *tryDownloadAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Upload Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self internalUploadWithLocalAbsoluteFilePaths:absolutePaths targetDirectory:directory tryAgainIfFailed:YES];
        });
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryDownloadAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self internalUploadWithLocalAbsoluteFilePaths:absolutePaths targetDirectory:directory tryAgainIfFailed:NO];
        });
    }];
}

// Remove the file and reupload, after 0.5 sec to wait previoud uploading process stopped.
- (void)onUploadOtherFilesAfterTooLargeFilesRemovedWithIndexSet:(NSIndexSet *)indexSet {
    if (indexSet && [indexSet count] > 0) {
        [self.absolutePaths removeObjectsAtIndexes:indexSet];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });

    dispatch_queue_t gQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (DELAY_UPLOAD_TIMER_INTERVAL * NSEC_PER_SEC));

    dispatch_after(delayTime, gQueue, ^(void) {
        [self upload:nil];
    });
}

// Go to FileUploadViewController
- (void)onGoToFileUploadViewController {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self dismissViewControllerAnimated:YES completion:^{
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                MenuTabBarController *tabBarController = [[FilelugUtility applicationDelegate] menuTabBarController];

                // Error occurred if setSelectedIndex: invoked in background thread:
                // "This application is modifying the autolayout engine from a background thread, which can lead to engine corruption and weird crashes. This will cause an exception in a future release."
                dispatch_async(dispatch_get_main_queue(), ^{
                    [tabBarController setSelectedIndex:INDEX_OF_TAB_BAR_UPLOAD];

                    [[tabBarController navigationControllerAtTabBarIndex:INDEX_OF_TAB_BAR_UPLOAD] popToRootViewControllerAnimated:YES];
                });
            });
        }];
    });
}

- (void)changeFilename:(NSString *)oldFilename toNewFilename:(NSString *)newFilename forFileAtIndexPath:(NSIndexPath *)cellIndexPath {
    // Validate new filename, including path format and duplicated with existing other filenames

    NSArray *illegalCharacters;
    [Utility checkDirectoryName:newFilename illegalCharacters:&illegalCharacters];

    if (illegalCharacters && [illegalCharacters count] > 0) {
        NSMutableString *illegalCharacterString = [NSMutableString string];

        for (NSString *illegalChar in illegalCharacters) {
            [illegalCharacterString appendFormat:@"%@\n", illegalChar];
        }

        NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Filename can't contain the following character(s): %@", @""), illegalCharacterString];

        [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
    } else if ([newFilename stringByTrimmingCharactersInSet:[NSCharacterSet punctuationCharacterSet]].length < 1) {
        NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Filename can't contain only punctuation characters.", @"")];

        [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
    } else {
        NSUInteger rowIndex = (NSUInteger) cellIndexPath.row;

        NSString *oldAbsolutePath = self.absolutePaths[rowIndex];

        NSString *destinationDirectory = [oldAbsolutePath stringByDeletingLastPathComponent];

        if (oldAbsolutePath) {
            NSString *newAbsolutePath = [destinationDirectory stringByAppendingPathComponent:newFilename];

            // check duplicated name among all files to be uploaded

            BOOL duplicated = NO;

            if (![newFilename isEqualToString:oldFilename] && [self.absolutePaths count] > 1) {
                for (NSString *absolutePath in self.absolutePaths) {
                    if ([absolutePath isEqualToString:newAbsolutePath]) {
                        duplicated = YES;

                        break;
                    }
                }
            }

            // check duplicated name with files in the external directory

            if (!duplicated) {
                NSError *findError;
                NSArray *filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:destinationDirectory error:&findError];

                for (NSString *filename in filenames) {
                    if ([filename isEqualToString:newFilename]) {
                        duplicated = YES;

                        break;
                    }
                }
            }

            if (duplicated) {
                NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Filename already exists: %@", @""), newFilename];

                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:message preferredStyle:UIAlertControllerStyleAlert];

                UIAlertAction *changeAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Rename Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    // show alert view again to rename file again.
                    [self tableView:self.tableView didSelectPackedUploadCellOrButtonAtRowAtIndexPath:cellIndexPath];
                }];
                [alertController addAction:changeAgainAction];

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
                // rename
                NSError *moveError;
                [[NSFileManager defaultManager] moveItemAtPath:oldAbsolutePath toPath:newAbsolutePath error:&moveError];

                if (moveError) {
                    NSLog(@"Error on rename file from '%@' to '%@'\n%@", [oldAbsolutePath lastPathComponent], [newAbsolutePath lastPathComponent], [moveError userInfo]);

                    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Failed to rename file to: %@", @""), newFilename];

                    [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                } else {
                    // set to upload file list
                    self.absolutePaths[rowIndex] = newAbsolutePath;

                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.tableView reloadData];
                    });
                }
            }
        }
    }
}

- (void)onEnteredSubdirectoryWithCustomizedName:(NSString *_Nullable)customizedName subdirectoryType:(NSNumber *_Nullable)subdirectoryType {
    if (!customizedName || [customizedName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length < 1) {
        // empty

        NSString *message = NSLocalizedString(@"Empty subdirectory name", @"");

        [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
    } else {
        NSArray *illegalCharacters;
        [Utility checkDirectoryName:customizedName illegalCharacters:&illegalCharacters];

        if (illegalCharacters && [illegalCharacters count] > 0) {
            NSMutableString *illegalCharacterString = [NSMutableString string];

            for (NSString *illegalChar in illegalCharacters) {
                [illegalCharacterString appendFormat:@"%@\n", illegalChar];
            }

            NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Directory name can't contain the following character(s): %@", @""), illegalCharacterString];

            [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
        } else if ([customizedName stringByTrimmingCharactersInSet:[NSCharacterSet punctuationCharacterSet]].length < 1) {
            NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Directory name can't contain only punctuation characters.", @"")];

            [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
        } else {
            // Change to selected type with customized value

            NSString *customizedNameTrimmed = [customizedName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

            if (subdirectoryType && (!self.uploadSubdirectoryService.type || ![self.uploadSubdirectoryService.type isEqualToNumber:subdirectoryType])) {
                self.uploadSubdirectoryService = [[UploadSubdirectoryService alloc] initWithUploadSubdirectoryType:subdirectoryType uploadSubdirectoryValue:customizedNameTrimmed];
            } else {
                self.uploadSubdirectoryService.customizedValue = customizedNameTrimmed;
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
        }
    }
}

@end
