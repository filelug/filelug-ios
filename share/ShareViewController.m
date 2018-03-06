#import <MobileCoreServices/MobileCoreServices.h>
#import "ShareViewController.h"
#import "ShareUtility.h"
#import "UploadItem.h"
#import "SHRootDirectoryViewController.h"

@interface ShareViewController ()

@property(nonatomic, strong) UserDao *userDao;

@property(nonatomic, strong) FileUploadGroupDao *fileUploadGroupDao;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) DirectoryService *directoryService;

@property(nonatomic, strong) UserComputerService *userComputerService;

@property(nonatomic, strong) UserComputerDao *userComputerDao;

@property(nonatomic, strong) NSMutableArray *filePaths;

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

@property(nonatomic, strong) UploadSubdirectoryService *uploadSubdirectoryService;

@property(nonatomic, strong) UploadNotificationService *uploadNotificationService;

@property(nonatomic, strong) SHFileUploadService *fileUploadService;

@end

const NSInteger TABLE_VIEW_SECTION_TO_LIST_UPLOAD_EXTERNAL_FILES = 1;


@implementation ShareViewController

@synthesize processing;

@synthesize progressView;

- (void)viewDidLoad {
    [super viewDidLoad];

    self.processing = @NO;

    [Utility viewController:self useNavigationLargeTitles:YES];

    _preferredContentSizeCategoryService = [[PreferredContentSizeCategoryService alloc] init];

    _filePaths = [NSMutableArray array];

    // for dynamic type, see:
    // https://www.natashatherobot.com/ios-8-self-sizing-table-view-cells-with-dynamic-type/
//    self.tableView.estimatedRowHeight = 89;
//    self.tableView.rowHeight = UITableViewAutomaticDimension;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if ([self isMovingToParentViewController]) {
        // get upload-related settings from db only when being pushed into, not back from other view controller

        [self updateUploadConfiguration];

//        NSUserDefaults *userDefaults = [Utility groupUserDefaults];
//
//        NSString *userComputerId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];
//
//        if (userComputerId) {
//            UserComputerWithoutManaged *userComputerWithoutManaged = [self.userComputerDao findUserComputerForUserComputerId:userComputerId];
//
//            if (userComputerWithoutManaged) {
//                self.directory = userComputerWithoutManaged.uploadDirectory;
//
//                self.uploadSubdirectoryService = [[UploadSubdirectoryService alloc] initWithPersistedTypeAndValue];
//                self.uploadDescriptionService = [[UploadDescriptionService alloc] initWithPersistedTypeAndValue];
//                self.uploadNotificationService = [[UploadNotificationService alloc] initWithPersistedType];
//            }
//        }
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangePreferredContentSize:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];
    
    [self addObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
}

- (void)updateUploadConfiguration {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *userComputerId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

    if (userComputerId) {
        UserComputerWithoutManaged *userComputerWithoutManaged = [self.userComputerDao findUserComputerForUserComputerId:userComputerId];

        if (userComputerWithoutManaged) {
            NSString *uploadDirectory = userComputerWithoutManaged.uploadDirectory;

            if (!uploadDirectory) {
                uploadDirectory = [userDefaults objectForKey:USER_DEFAULTS_KEY_FIRST_ROOT_DIRECTORY];
            }

            self.directory = uploadDirectory;
        }

        self.uploadSubdirectoryService = [[UploadSubdirectoryService alloc] initWithPersistedTypeAndValue];
        self.uploadDescriptionService = [[UploadDescriptionService alloc] initWithPersistedTypeAndValue];
        self.uploadNotificationService = [[UploadNotificationService alloc] initWithPersistedType];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // let copy under background queue
    // don't do it if back from other view controllers

    if ([self isMovingToParentViewController]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self copyFilesToExternalRootDirectory];
        });
    } else {
        // So new values updaed to the UI

        dispatch_async(dispatch_get_main_queue(), ^{
            [_uploadBarButton setEnabled:(self.filePaths && [self.filePaths count] > 0)];

            [self.tableView reloadData];
        });
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

- (SHFileUploadService *)fileUploadService {
    if (!_fileUploadService) {
        _fileUploadService = [[SHFileUploadService alloc] init];
    }

    return _fileUploadService;
}

- (BOOL)isLoading {
    return (self.processing && [self.processing boolValue]);
}

- (void)stopLoading {
    self.processing = @NO;
}

- (BOOL)needPersistIfChanged {
    return NO;
}

- (void)didChangePreferredContentSize:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (void)copyFilesToExternalRootDirectory {
    // Copy files to Documents/filelug_exteranl

    NSString *externalRootDirectory = [DirectoryService directoryForExternalFilesWithCreatedIfNotExists:YES];

    NSFileManager *fileManager = [NSFileManager defaultManager];

    self.processing = @YES;

    NSMutableArray *filePathArray = [NSMutableArray array];

    int count = 0;

    @try {
        for (UploadItem *inputItem in _inputItems) {
            // check url first

            NSURL *fileURL = inputItem.url;

            if (fileURL) {
                NSString *filename = [[fileURL lastPathComponent] stringByRemovingPercentEncoding];

                [self copyFileWithAbsolutePath:[fileURL path] toDirectory:externalRootDirectory withNewFilename:filename andSaveNewPathToTargetArray:&filePathArray withFileManager:fileManager];
            } else {
                count++;

                // deal with UploadItem without url, which contains content of a file in inputItem.data

                NSData *data = inputItem.data;

                if (data) {
                    // write to file with extension, if any

                    NSString *extension = inputItem.fileExtension;

                    NSString *filename;

                    NSString *formattedDate = [Utility dateStringFromDate:[NSDate date] format:DATE_FORMAT_FOR_RANDOM_FILENAME locale:[NSLocale autoupdatingCurrentLocale] timeZone:nil];

                    NSString *utcoreType = inputItem.utcoreType;

                    NSString *filenamePrefix;

                    if (utcoreType && [utcoreType isEqualToString:(NSString *)kUTTypeURL]) {
                        // a website url

                        filenamePrefix = @"webpage";
                    } else {
                        filenamePrefix = @"file";
                    }

                    if (extension && extension.length > 0) {
                        filename = [NSString stringWithFormat:@"%@_%@_%d.%@", filenamePrefix, formattedDate, count, extension];
                    } else {
                        filename = [NSString stringWithFormat:@"%@_%@_%d", filenamePrefix, formattedDate, count];
                    }

                    [self fileManager:fileManager saveData:data toDirectory:externalRootDirectory withFilename:filename andSaveNewPathToTargetArray:&filePathArray];
                }
            }
        }
    } @finally {
        self.processing = @NO;

        _filePaths = filePathArray;

        dispatch_async(dispatch_get_main_queue(), ^{
            [_uploadBarButton setEnabled:(self.filePaths && [self.filePaths count] > 0)];

            [self.tableView reloadData];
        });
    }
}

// Make sure the filename is unescaped by removing percent encoding
// Use copy instead of move for host app, like Photos, don't let you move the photo
- (void)copyFileWithAbsolutePath:(NSString *)absolutePath toDirectory:(NSString *)directoryPath withNewFilename:(NSString *)filename andSaveNewPathToTargetArray:(NSMutableArray **)targetArray withFileManager:(NSFileManager *)fileManager {
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

        [self copyFileWithAbsolutePath:absolutePath toDirectory:directoryPath withNewFilename:filename2 andSaveNewPathToTargetArray:targetArray withFileManager:fileManager];
    } else {
        NSError *copyError;
        [fileManager copyItemAtPath:absolutePath toPath:targetAbsolutePath error:&copyError];

        if (copyError) {
            NSLog(@"Failed to copy file from \"%@\" to \"%@\". Reason:\n%@", absolutePath, targetAbsolutePath, [copyError userInfo]);
        } else {
            if (targetArray) {
                [*targetArray addObject:targetAbsolutePath];
            }
        }
    }
}

- (void)fileManager:(NSFileManager *)fileManager saveData:(NSData *)data toDirectory:(NSString *)directoryPath withFilename:(NSString *)filename andSaveNewPathToTargetArray:(NSMutableArray **)targetArray {
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

        [self fileManager:fileManager saveData:data toDirectory:directoryPath withFilename:filename2 andSaveNewPathToTargetArray:targetArray];
    } else {
        if ([data writeToFile:targetAbsolutePath atomically:YES]) {
            if (targetArray) {
                [*targetArray addObject:targetAbsolutePath];
            }
        } else {
            NSLog(@"Failed to write data to file: \"%@\"", targetAbsolutePath);
        }
    }
}

- (IBAction)close:(id)sender {
    // remove notified when data saved to db and save the data to file so folder watcher can detect it.
    ClopuccinoCoreData *coreData = [ClopuccinoCoreData defaultCoreData];
    coreData.sendsUpdates = NO;

    // delete file
    if (self.filePaths && [self.filePaths count] > 0) {
        for (NSString *filePath in self.filePaths) {
            NSError *deleteError;
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:&deleteError];

            if (deleteError) {
                NSLog(@"Error on deleting file: %@\nReason:\n%@", filePath, [deleteError userInfo]);
            }
        }
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self dismissViewControllerAnimated:YES completion:^{
            NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];

            errorDetail[NSLocalizedDescriptionKey] = NSLocalizedString(@"User canceled.", @"");

            NSError *error = [NSError errorWithDomain:APP_GROUP_NAME code:-1 userInfo:errorDetail];

            [self.shareExtensionContext cancelRequestWithError:error];
        }];
    });
}

- (IBAction)upload:(id)sender {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    dispatch_async(queue, ^{
        NSString *targetDirectory = self.directory;
        NSArray *localAbsolutPaths = [NSArray arrayWithArray:self.filePaths];

        if (!targetDirectory || [targetDirectory stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length < 1) {
            // prompt that empty directory not allowed

            [Utility viewController:self alertWithMessageTitle:@"" messageBody:NSLocalizedString(@"Directory should not be empty", @"") actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0.0 actionHandler:nil];
        } else {
            BOOL keepUploading = YES;

            for (NSString *localAbsolutePath in localAbsolutPaths) {
                NSString *filename = [localAbsolutePath lastPathComponent];

                if (!localAbsolutePath || ![Utility validFilename:filename]) {
                    // validate filename

                    keepUploading = NO;

                    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Filename is empty or contains illegal character", @""), filename];

                    [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0.0 actionHandler:nil];

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
            [Utility alertInExtensionEmptyUserSessionFromViewController:self completion:^{
                self.processing = @NO;
            }];
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

                                        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"File Too Large", @"") message:message preferredStyle:UIAlertControllerStyleAlert];

                                        // Ask if upload others only if there're more than one files trying to upload and not all of them are too large.
                                        if ([localAbsolutePaths count] > 1 && [localAbsolutePaths count] > [tooLargeAbsoluteFileIndexSet count]) {
                                            UIAlertAction *uploadOthersAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Upload other selected files", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                                [self.filePaths removeObjectsAtIndexes:tooLargeAbsoluteFileIndexSet];

                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                    [self.tableView reloadData];
                                                });

                                                [self upload:nil];

//                                                dispatch_queue_t gQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
//                                                dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (DELAY_UPLOAD_TIMER_INTERVAL * NSEC_PER_SEC));
//
//                                                dispatch_after(delayTime, gQueue, ^(void) {
//                                                    [self upload:nil];
//                                                });
                                            }];

                                            [alertController addAction:uploadOthersAction];
                                        }

                                        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"") style:UIAlertActionStyleCancel handler:nil];
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

                                    [self.directoryService createFileUploadSummaryWithUploadGroupId:uploadGroupId targetDirectory:directoryPathWithSubdirectory transferKeys:transferKeys subdirectoryType:subdirectoryType subdirectoryValue:fullSubdirectoryPath descriptionType:descriptionType descriptionValue:fullDescriptionContent notificationType:notificationType session:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] completionHandler:^(NSData *dataFromCreate, NSURLResponse *responseFromCreate, NSError *errorFromCreate) {
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
                                                            [self.fileUploadService uploadFileFromFileObject:localAbsolutePath
                                                                                                  sourceType:@(ASSET_FILE_SOURCE_TYPE_EXTERNAL_FILE)
                                                                                                   sessionId:sessionId
                                                                                           fileUploadGroupId:uploadGroupId
                                                                                                   directory:directoryPathWithSubdirectory
                                                                                                    filename:filename
                                                                               shouldCheckIfLocalFileChanged:NO
                                                                                       fileUploadStatusModel:fileUploadStatusModel
                                                                             addToStartTimestampWithMillisec:index
                                                                                           completionHandler:^(NSError *uploadError) {
                                                                if (uploadError) {
                                                                    failureCount++;
                                                                }
                                                            }];
                                                        }
                                                    } @finally {
                                                        // reload core data so containing app get the correct uploading status

                                                        [userDefaults setObject:@YES forKey:USER_DEFAULTS_KEY_NEED_RELOAD_CORE_DATA];

                                                        // delayed to make sure there's at least one upload file of which status is preparing

                                                        dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (DELAY_UPLOAD_TIMER_INTERVAL * NSEC_PER_SEC));
                                                        dispatch_after(delayTime, queue, ^(void) {
                                                            self.processing = @NO;

                                                            NSString *message;

                                                            if (failureCount == 0) {
                                                                // all success
                                                                message = [NSString stringWithFormat:NSLocalizedString(@"File is uploading in extension", @""), NSLocalizedString(@"Upload File", @"")];
                                                            } else if (failureCount == fileCount) {
                                                                // all failed
                                                                message = [NSString stringWithFormat:NSLocalizedString(@"Uploaded failed. Try again later", @"")];
                                                            } else {
                                                                // partial failure
                                                                message = [NSString stringWithFormat:NSLocalizedString(@"Some files failed to upload in extension", @""), failureCount, NSLocalizedString(@"Upload File", @"")];
                                                            }

                                                            [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:^(UIAlertAction *action) {
                                                                [self.shareExtensionContext completeRequestReturningItems:nil completionHandler:^(BOOL expired) {
                                                                    if (expired) {
                                                                        // remove notified when data saved to db and save the data to file so folder watcher can detect it.
                                                                        @try {
                                                                            ClopuccinoCoreData *coreData = [ClopuccinoCoreData defaultCoreData];
                                                                            coreData.sendsUpdates = NO;
                                                                        } @catch (NSException *e) {
                                                                            // ignored
                                                                            NSLog(@"Error on removing notifications on data saving.\n%@", [e userInfo]);
                                                                        }
                                                                    }
                                                                }];
                                                            }];
                                                        });
                                                    }
                                                });
                                            }];
                                        } else {
                                            self.processing = @NO;

                                            NSString *messagePrefix = NSLocalizedString(@"Error on upload file.", @"");

                                            [self alertToTryUploadAgainWithMessagePrefix:messagePrefix response:responseFromCreate data:dataFromCreate error:errorFromCreate absoluteFilePaths:localAbsolutePaths targetDirectory:targetDirectory];
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

                            [self alertToTryUploadAgainWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror absoluteFilePaths:localAbsolutePaths targetDirectory:targetDirectory];
                        }];
                    } else if (tryAgainIfFailed && statusCode == 503) {
                        // server not connected, so request connection
                        [self requestConnectWithAuthService:self.authService userDefaults:userDefaults absolutePaths:localAbsolutePaths directory:targetDirectory];
                    } else {
                        self.processing = @NO;

                        NSString *messagePrefix = NSLocalizedString(@"Error on upload file.", @"");

                        [self alertToTryUploadAgainWithMessagePrefix:messagePrefix response:response data:data error:error absoluteFilePaths:localAbsolutePaths targetDirectory:targetDirectory];
                    }
                });
            }];
        }
}

// request connect for file upload
- (void)requestConnectWithAuthService:(AuthService *)authService userDefaults:(NSUserDefaults *)userDefaults absolutePaths:(NSArray *)absolutePaths directory:(NSString *)directory {
    self.processing = @YES;

    [authService requestConnectWithSession:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] successHandler:^(NSURLResponse *rcresponse, NSData *rcdata) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self internalUploadWithLocalAbsoluteFilePaths:absolutePaths targetDirectory:directory tryAgainIfFailed:NO];
        });
    } failureHandler:^(NSData *rcdata, NSURLResponse *rcresponse, NSError *rcerror) {
        self.processing = @NO;

        [self alertToTryUploadAgainWithMessagePrefix:nil response:rcresponse data:rcdata error:rcerror absoluteFilePaths:absolutePaths targetDirectory:directory];
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
    
    if (section == 0) {
        count = 5;
    } else if (section == TABLE_VIEW_SECTION_TO_LIST_UPLOAD_EXTERNAL_FILES) {
        count = [self.filePaths count];
    } else {
        count = 0;
    }
    
    return count;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *title;
    
    if (section == 0) {
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
    static NSString *UploadExternalFileSettingsCell = @"ShareSettingsCell";
    static NSString *UploadExternalFileFilesCell = @"ShareFilesCell";

    UITableViewCell *cell;

    NSInteger section = [indexPath section];
    NSInteger row = [indexPath row];

    if (section == 0) {
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

        if (row == 0) {
            // upload to computer

            [cell.imageView setImage:[UIImage imageNamed:@"computer"]];

            [cell.textLabel setText:NSLocalizedString(@"Save To Computer", @"")];

            [cell setAccessoryType:UITableViewCellAccessoryNone];

            NSUserDefaults *userDefaults = [Utility groupUserDefaults];

            NSString *computerName = [userDefaults stringForKey:USER_DEFAULTS_KEY_COMPUTER_NAME];

            [cell.detailTextLabel setText:computerName ? computerName : NSLocalizedString(@"(Not Set2)", @"")];
        } else if (row == 1) {
            // upload to directory

            [cell.imageView setImage:[UIImage imageNamed:@"ic_folder"]];

            [cell.textLabel setText:NSLocalizedString(@"All Upload To Directory", @"")];

            NSString *directoryPath = self.directory ? self.directory : NSLocalizedString(@"(Not Set2)", @"");

            [cell.detailTextLabel setText:directoryPath];

            [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        } else if (row == 2) {
            // subfolder

            [cell.imageView setImage:[UIImage imageNamed:@"folder-add"]];

            [cell.textLabel setText:NSLocalizedString(@"Subdirectory Name", @"")];

            [cell.detailTextLabel setText:[self.uploadSubdirectoryService displayedText]];

            [cell setAccessoryType:UITableViewCellAccessoryNone];
        } else if (row == 3) {
            // description

            [cell.imageView setImage:[UIImage imageNamed:@"note-write"]];

            [cell.textLabel setText:NSLocalizedString(@"Description", @"")];

            [cell.detailTextLabel setText:[self.uploadDescriptionService displayedText]];

            [cell setAccessoryType:UITableViewCellAccessoryNone];
        } else if (row == 4) {
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

        [cell setAccessoryType:UITableViewCellAccessoryNone];

        NSString *fileAbsolutePath = self.filePaths[(NSUInteger) indexPath.row];

        [cell.imageView setImage:[DirectoryService imageForFileExtension:[fileAbsolutePath pathExtension]]];

        [cell.textLabel setText:[fileAbsolutePath lastPathComponent]];
    }

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self tableView:tableView didSelectUploadCellOrButtonAtRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    [self tableView:tableView didSelectUploadCellOrButtonAtRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectUploadCellOrButtonAtRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;

    if (section == 0) {
        if (row == 0) {
            // Change Connected Computer

            // clear the selected gray - just for looking good
            [tableView deselectRowAtIndexPath:indexPath animated:NO];

            [self findAvailableComputersWithSelectedRowAtIndexPath:indexPath];
        } else if (row == 1) {
            // Choose root directory

            SHRootDirectoryViewController *rootDirectoryViewController = (SHRootDirectoryViewController *) [ShareUtility instantiateViewControllerWithIdentifier:@"SHRootDirectory"];

            rootDirectoryViewController.fromViewController = self;

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.navigationController pushViewController:rootDirectoryViewController animated:YES];
            });
        } else {
            UIAlertController *actionSheet;

            if (row == 2) {
                // subfolder

                actionSheet = [self prepareAlertControllerForUploadSubdirectory];
            } else if (row == 3) {
                // description

                actionSheet = [self prepareAlertControllerForUploadDescription];
            } else if (row == 4) {
                // notification

                actionSheet = [self prepareAlertControllerForUploadNotification];
            }

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
    } else if (section == TABLE_VIEW_SECTION_TO_LIST_UPLOAD_EXTERNAL_FILES) {
        // edit filename

        NSString *oldFileAbsolutePath = self.filePaths[(NSUInteger) row];

        NSString *oldFilename = [oldFileAbsolutePath lastPathComponent];

        NSIndexPath *selectedIndexPath = [indexPath copy];

        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Change filename to:", @"") message:nil preferredStyle:UIAlertControllerStyleAlert];

        [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            [textField setText:oldFilename];

            NSRange selectedTextRange = [oldFilename rangeOfString:[oldFilename stringByDeletingPathExtension]];

            [Utility selectTextInTextField:textField range:selectedTextRange];
        }];

        UIAlertAction *confirmChangeAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Confirm Change", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
            // Validate new filename, including path format and duplicated with existing other filenames

            NSString *newFilename = [[alertController textFields][0] text];

            NSArray *illegalCharacters;
            [Utility checkDirectoryName:newFilename illegalCharacters:&illegalCharacters];

            if (illegalCharacters && [illegalCharacters count] > 0) {
                NSMutableString *illegalCharacterString = [NSMutableString string];

                for (NSString *illegalChar in illegalCharacters) {
                    [illegalCharacterString appendFormat:@"%@\n", illegalChar];
                }

                NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Filename can't contain the following character(s): %@", @""), illegalCharacterString];

                [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0.1 actionHandler:nil];
            } else if ([newFilename stringByTrimmingCharactersInSet:[NSCharacterSet punctuationCharacterSet]].length < 1) {
                NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Filename can't contain only punctuation characters.", @"")];

                [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0.1 actionHandler:nil];
            } else {
                NSString *destinationDirectory = [oldFileAbsolutePath stringByDeletingLastPathComponent];

                NSString *newAbsolutePath = [destinationDirectory stringByAppendingPathComponent:newFilename];

                // check duplicated name among all files to be uploaded

                BOOL duplicated = NO;

                if (![newFilename isEqualToString:oldFilename] && [self.filePaths count] > 1) {
                    for (NSString *absolutePath in self.filePaths) {
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

                    UIAlertController *duplicatedAlertController = [UIAlertController alertControllerWithTitle:@"" message:message preferredStyle:UIAlertControllerStyleAlert];

                    UIAlertAction *changeAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Rename Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull handledAction) {
                        // show alert view again to rename file again.
                        [self tableView:self.tableView didSelectUploadCellOrButtonAtRowAtIndexPath:selectedIndexPath];
                    }];
                    [duplicatedAlertController addAction:changeAgainAction];
                    
                    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:nil];
                    [duplicatedAlertController addAction:cancelAction];

                    if ([self isVisible]) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [duplicatedAlertController presentWithViewController:self sourceView:nil sourceRect:CGRectNull barButtonItem:nil animated:YES completion:nil];
                        });
                    } else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [duplicatedAlertController presentWithAnimated:YES];
                        });
                    }
                } else {
                    // rename

                    NSError *moveError;
                    [[NSFileManager defaultManager] moveItemAtPath:oldFileAbsolutePath toPath:newAbsolutePath error:&moveError];

                    if (moveError) {
                        NSLog(@"Error on rename file from '%@' to '%@'\n%@", [oldFileAbsolutePath lastPathComponent], [newAbsolutePath lastPathComponent], [moveError userInfo]);

                        NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Failed to rename file to: %@", @""), newFilename];

                        [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                    } else {
                        // set to upload file list
                        self.filePaths[(NSUInteger) selectedIndexPath.row] = newAbsolutePath;

                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.tableView reloadData];
                        });
                    }
                }
            }
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

- (UIAlertController *)prepareAlertControllerForUploadNotification {
    UIAlertController *actionSheetController = [UIAlertController alertControllerWithTitle:@"" message:NSLocalizedString(@"Choose type of upload notification", @"") preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray *allNames = [UploadNotificationService namesOfAllTypesWithOrder];

    for (NSString *notificationName in allNames) {
        UIAlertAction *actionSheetAction = [UIAlertAction actionWithTitle:notificationName style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
            if (!self.uploadNotificationService || ![self.uploadNotificationService.name isEqualToString:notificationName]) {
                NSNumber *notificationType = [UploadNotificationService uploadNotificationTypeWithUploadNotificationName:notificationName];

                if (!notificationType) {
                    notificationType = @([UploadNotificationService defaultType]);
                }

                self.uploadNotificationService = [[UploadNotificationService alloc] initWithUploadNotificationType:notificationType];

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.tableView reloadData];
                });
            }
        }];

        [actionSheetController addAction:actionSheetAction];
    }

    // add cancel to the last

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:nil];

    [actionSheetController addAction:cancelAction];

    return actionSheetController;
}

- (UIAlertController *)prepareAlertControllerForUploadDescription {
    UIAlertController *actionSheetController = [UIAlertController alertControllerWithTitle:@"" message:NSLocalizedString(@"Choose type of description", @"") preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray *allTypes = [UploadDescriptionService allTypesWithOrder];

    for (NSNumber *currentType in allTypes) {
        NSString *currentName = [UploadDescriptionService uploadDescriptionNameWithUploadDescriptionType:currentType];

        UIAlertAction *actionSheetAction = [UIAlertAction actionWithTitle:currentName style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
            // check if customizable
            BOOL customizable = [UploadDescriptionService isCustomizableWithType:[currentType unsignedIntegerValue]];

            if (customizable) {
                FKEditingPackedUploadDescriptionViewController *editingUploadDescriptionViewController = [ShareUtility instantiateViewControllerWithIdentifier:@"FKEditingPackedUploadDescription"];
                editingUploadDescriptionViewController.selectedType = currentType;
                editingUploadDescriptionViewController.uploadDescriptionDataSource = (id) self;

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.navigationController pushViewController:editingUploadDescriptionViewController animated:YES];
                });
            } else {
                if (!self.uploadDescriptionService.type || ![self.uploadDescriptionService.type isEqualToNumber:currentType]) {
                    NSString *oldCustomizedValue = [self.uploadDescriptionService customizedValue];

                    self.uploadDescriptionService = [[UploadDescriptionService alloc] initWithUploadDescriptionType:currentType uploadDescriptionValue:oldCustomizedValue];

                    // DO NOT persist. Only the value changed in SettingsViewController can be persisted.

                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.tableView reloadData];
                    });
                }
            }
        }];

        [actionSheetController addAction:actionSheetAction];
    }

    // add cancel to the last

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:nil];

    [actionSheetController addAction:cancelAction];

    return actionSheetController;
}

- (UIAlertController *)prepareAlertControllerForUploadSubdirectory {
    UIAlertController *actionSheetController = [UIAlertController alertControllerWithTitle:@"" message:NSLocalizedString(@"Choose type of subdirectory", @"") preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray *allNames = [UploadSubdirectoryService namesOfAllTypesWithOrder];

    for (NSString *currentSubdirectoryName in allNames) {
        NSNumber *currentSubdirectoryType = [UploadSubdirectoryService uploadSubdirectoryTypeWithUploadSubdirectoryName:currentSubdirectoryName];
        BOOL currentSubdirectorySustomizable = [UploadSubdirectoryService isCustomizableWithType:[currentSubdirectoryType unsignedIntegerValue]];

        UIAlertAction *actionSheetAction = [UIAlertAction actionWithTitle:currentSubdirectoryName style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
            // check if customizable
            if (currentSubdirectorySustomizable) {
                // let user enter customized name of subdirectory

                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:NSLocalizedString(@"Enter customized name", @"") preferredStyle:UIAlertControllerStyleAlert];

                [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                    [textField setKeyboardType:UIKeyboardTypeDefault];

                    // set text to the latest customized value of self.uploadSubdirectoryService

                    NSString *text = [self.uploadSubdirectoryService customizedValue];

                    [textField setText:(text ? text : NSLocalizedString(@"New Folder", @""))];
                }];

                UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *okAlertAction) {
                    // set the new customized value of subdirectory to self.uploadSubdirectoryService
                    // but do not persist

                    NSString *newCustomizedValue = [alertController.textFields[0] text];

                    NSArray *illegalCharacters;
                    [Utility checkDirectoryName:newCustomizedValue illegalCharacters:&illegalCharacters];

                    if (illegalCharacters && [illegalCharacters count] > 0) {
                        NSMutableString *illegalCharacterString = [NSMutableString string];

                        for (NSString *illegalChar in illegalCharacters) {
                            [illegalCharacterString appendFormat:@"%@\n", illegalChar];
                        }

                        NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Directory name can't contain the following character(s): %@", @""), illegalCharacterString];

                        [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                    } else if ([newCustomizedValue stringByTrimmingCharactersInSet:[NSCharacterSet punctuationCharacterSet]].length < 1) {
                        NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Directory name can't contain only punctuation characters.", @"")];

                        [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
                    } else {
                        NSString *customizedNameTrimmed = [newCustomizedValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

                        if (!self.uploadSubdirectoryService.type || ![self.uploadSubdirectoryService.type isEqualToNumber:currentSubdirectoryType]) {
                            self.uploadSubdirectoryService = [[UploadSubdirectoryService alloc] initWithUploadSubdirectoryType:currentSubdirectoryType uploadSubdirectoryValue:customizedNameTrimmed];
                        } else {
                            [self.uploadSubdirectoryService setCustomizedValue:customizedNameTrimmed];
                        }

                        // DO NOT persist. Only the value changed in SettingsViewController can be persisted.

                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.tableView reloadData];
                        });
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
            } else {
                // keep the old customized values so it shows when user changed back from non-customized option.
                if (!self.uploadSubdirectoryService.type || ![self.uploadSubdirectoryService.type isEqualToNumber:currentSubdirectoryType]) {
                    NSString *oldSubdirectoryCustomizedValue = [self.uploadSubdirectoryService customizedValue];

                    self.uploadSubdirectoryService = [[UploadSubdirectoryService alloc] initWithUploadSubdirectoryType:currentSubdirectoryType uploadSubdirectoryValue:oldSubdirectoryCustomizedValue];

                    // DO NOT persist. Only the value changed in SettingsViewController can be persisted.

                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.tableView reloadData];
                    });
                }
            }
        }];

        [actionSheetController addAction:actionSheetAction];
    }

    // add cancel to the last

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:nil];

    [actionSheetController addAction:cancelAction];

    return actionSheetController;
}

- (void)findAvailableComputersWithSelectedRowAtIndexPath:(NSIndexPath *)indexPath {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSString *sessionId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

        if (!sessionId || sessionId.length < 1) {
            [Utility alertInExtensionEmptyUserSessionFromViewController:self completion:^{
                self.processing = @NO;
            }];
        } else {

//        NSString *countryId = [userDefaults stringForKey:USER_DEFAULTS_KEY_COUNTRY_ID];
//        NSString *phoneNumber = [userDefaults stringForKey:USER_DEFAULTS_KEY_PHONE_NUMBER];
//        NSString *password = [userDefaults stringForKey:USER_DEFAULTS_KEY_PASSWORD];
//        if (!countryId
//            || [countryId stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length < 1
//            || !phoneNumber
//            || [phoneNumber stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length < 1
//            || !password
//            || [password stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length < 1) {
//
//            [Utility alertInExtensionEmptyUserSessionFromViewController:self completion:^{
//                self.processing = @NO;
//            }];
//        } else {
//            NSString *nickname = [userDefaults stringForKey:USER_DEFAULTS_KEY_NICKNAME];
//
//            if (!nickname) {
//                /* find nickname in local db first */
//                NSError *foundError;
//                UserWithoutManaged *localUserWithoutManaged = [self.userDao findUserWithoutManagedByCountryId:countryId phoneNumber:phoneNumber error:&foundError];
//
//                if (localUserWithoutManaged) {
//                    nickname = localUserWithoutManaged.nickname;
//                } else {
//                    nickname = [Utility uuid];
//                }
//            }

            /* prepare indicator view */
            self.processing = @YES;

            [self.userComputerService findAvailableComputersWithSession:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
//            [self.userComputerService findAvailableComputersWithCountryId:countryId phoneNumber:phoneNumber password:password nickname:nickname completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                self.processing = @NO;

                NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

                if (statusCode == 200) {
                    /* DO NOT create or update user first FOR NOW */

                    NSError *fetchError;
                    NSArray *availableUserComputers = [self.userComputerDao userComputersFromFindAvailableComputersResponseData:data error:&fetchError];

                    if (fetchError) {
                        NSLog(@"Error on finding user computers for session: %@\n%@", sessionId, [fetchError userInfo]);

                        [Utility viewController:self alertWithMessageTitle:@"" messageBody:NSLocalizedString(@"Error on fetching computer information. Try again later.", @"") actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0.0 actionHandler:nil];
                    } else {
                        if (availableUserComputers
                            && [availableUserComputers count] > 0
                            && ((UserComputerWithoutManaged *) availableUserComputers[0]).computerId) {
                            // show action sheet to choose

                            UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Choose Computer Name", @"") message:@"" preferredStyle:UIAlertControllerStyleActionSheet];

                            for (UserComputerWithoutManaged *newUserComputerWithoutManaged in availableUserComputers) {
                                NSString *computerName = newUserComputerWithoutManaged.computerName;

                                UIAlertAction *action = [UIAlertAction actionWithTitle:computerName style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
                                    if (newUserComputerWithoutManaged && newUserComputerWithoutManaged.computerId) {
                                        self.processing = @YES;

                                        NSString *userId = newUserComputerWithoutManaged.userId;
                                        NSNumber *computerId = newUserComputerWithoutManaged.computerId;
                                        NSString *userComputerId = newUserComputerWithoutManaged.userComputerId;
                                        NSString *computerName = newUserComputerWithoutManaged.computerName;

                                        // Find the UserComputer in local db and use the value for showHidden and set to @(NO) if not found.
                                        // The UserComputerWithoutManaged is from server and there's no value to property showHidden.

                                        NSNumber *showHidden = [self.userComputerDao findShowHiddenForUserComputerId:userComputerId];

                                        if (!showHidden) {
                                            showHidden = @(NO);
                                        }

                                        NSString *sessionId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

                                        [self.userComputerService connectToComputerWithUserId:userId computerId:computerId showHidden:showHidden session:sessionId successHandler:^(NSURLResponse *cresponse, NSData *cdata) {
                                            self.processing = @NO;

                                            // update the values for default upload directory, subdirectory name, upload description and notification type
                                            [self updateUploadConfiguration];

                                            // reload to update the values above and the computer name
                                            dispatch_async(dispatch_get_main_queue(), ^{
                                                [self.tableView reloadData];
                                            });
                                        } failureHandler:^(NSData *cdata, NSURLResponse *cresponse, NSError *cerror) {
                                            self.processing = @NO;

                                            NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                                            [self alertToTryAgainWithMessagePrefix:messagePrefix response:cresponse data:cdata error:cerror computerName:computerName];
                                        }];
                                    }
                                }];

                                [actionSheet addAction:action];
                            }

                            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:nil];

                            [actionSheet addAction:cancelAction];

//                            if ([Utility isIPad]) {
//                                UIView *sourceView = self.view;
//                                CGRect sourceRect = self.view.frame;
//
//                                if (indexPath) {
//                                    UITableViewCell *selectedCell = [self.tableView cellForRowAtIndexPath:indexPath];
//
//                                    if (selectedCell) {
//                                        sourceView = selectedCell;
//                                        sourceRect = selectedCell.bounds;
//                                    }
//                                }
//
//                                actionSheet.popoverPresentationController.sourceView = sourceView;
//                                actionSheet.popoverPresentationController.sourceRect = sourceRect;
//                            }

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
                        } else {
                            [Utility alertInExtensionEmptyUserSessionFromViewController:self completion:^{
                                self.processing = @NO;
                            }];
                        }
                    }
                } else {
                    UIAlertAction *tryUpdateAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
                        [self findAvailableComputersWithSelectedRowAtIndexPath:indexPath];
                    }];

                    [self.authService processCommonRequestFailuresWithMessagePrefix:nil response:response data:data error:error tryAgainAction:tryUpdateAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                        [self findAvailableComputersWithSelectedRowAtIndexPath:indexPath];
                    }];
                }
            }];
        }
    });
}

- (void)alertToTryAgainWithMessagePrefix:(NSString *)messagePrefix response:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error computerName:(NSString *)computerName {
    UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        [self findAvailableComputersWithSelectedRowAtIndexPath:nil];
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        [self findAvailableComputersWithSelectedRowAtIndexPath:nil];
    }];
}

- (void)alertToTryUploadAgainWithMessagePrefix:messagePrefix response:response data:data error:error absoluteFilePaths:localAbsolutePaths targetDirectory:targetDirectory {
    UIAlertAction *tryDownloadAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Upload Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self internalUploadWithLocalAbsoluteFilePaths:localAbsolutePaths targetDirectory:targetDirectory tryAgainIfFailed:YES];
        });
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryDownloadAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self internalUploadWithLocalAbsoluteFilePaths:localAbsolutePaths targetDirectory:targetDirectory tryAgainIfFailed:NO];
        });
    }];
}

@end
