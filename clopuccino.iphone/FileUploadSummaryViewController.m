#import <QuickLook/QuickLook.h>
#import "FileUploadSummaryViewController.h"
#import "AssetsPreviewViewController.h"
#import "RootDirectoryViewController.h"
#import "AppService.h"
#import "FilelugUtility.h"
#import "FilePreviewController.h"
#import "FileUploadProcessService.h"
#import "AppDelegate.h"
#import "FilelugFileUploadService.h"

// -------------- section 0 -----------------
#define kUploadSummarySectionIndexOfSettings        0
#define kUploadSummaryRowIndexOfUploadDirectory     0

@interface FileUploadSummaryViewController ()

@property(nonatomic, strong) UIBarButtonItem *uploadBarButtonItem;

@property(nonatomic, strong) DirectoryService *directoryService;

@property(nonatomic, strong) FileUploadGroupDao *fileUploadGroupDao;

@property(nonatomic, strong) UserComputerDao *userComputerDao;

// for iOS 8 or later --> elements of PHAsset
// The values are ordered by createDate, and the order applies to self.selectedAssetIdentifiers in [self reloadAssets]
@property(nonatomic, strong) NSMutableArray *assets;

// iOS 8 or later
@property(nonatomic, strong) PHCachingImageManager *cachingImageManager;

// iOS 8 or later
@property(nonatomic, assign) CGSize imageResizedSize;

@property(nonatomic, strong) FileUploadProcessService *uploadProcessService;

@property(nonatomic, strong) AuthService *authService;

@property(nonatomic, strong) AppService *appService;

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

// Keep the reference to prevent error like: 'UIDocumentInteractionController/QLPreviewController has gone away prematurely!'
@property(nonatomic, strong) id keptController;

@property(nonatomic, strong) UploadSubdirectoryService *uploadSubdirectoryService;

@property(nonatomic, strong) UploadNotificationService *uploadNotificationService;

// Used to count how many files already go into uploading process
// When the value equals to the total files to be uploaded, pop to FileUploadViewController
// atomic(the default value if not provided) is used to make sure thread-safe
@property(atomic) NSUInteger uploadedCount;

@property(nonatomic) BOOL registeredPhotoChangeObserver;

@property(nonatomic, strong) FilelugFileUploadService *fileUploadService;

@end

const NSInteger TABLE_VIEW_SECTION_TO_LIST_UPLOAD_FILES = 2;

@implementation FileUploadSummaryViewController
    
@synthesize processing;
    
@synthesize progressView;

- (void)viewDidLoad {
    [super viewDidLoad];

    self.processing = @NO;

    [Utility viewController:self useNavigationLargeTitles:YES];

    self.registeredPhotoChangeObserver = NO;

    _uploadProcessService = [[FilelugUtility applicationDelegate] fileUploadProcessService];

    _assets = [NSMutableArray array];

    _preferredContentSizeCategoryService = [[PreferredContentSizeCategoryService alloc] init];
    
    [self.navigationItem setTitle:NSLocalizedString(@"Upload Summary", @"")];
    
    _uploadBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"upload", @"") style:UIBarButtonItemStylePlain target:self action:@selector(upload:)];
    
    [self.navigationItem setRightBarButtonItems:@[_uploadBarButtonItem] animated:YES];

    // Change the back button for the next view controller
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel", @"") style:UIBarButtonItemStylePlain target:nil action:nil];

    [self.navigationItem setBackBarButtonItem:backButton];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if ([self isMovingToParentViewController]) {
        // fetch group-upload data only when being pushed into, not back from other view controller
        // because any change to upload-related profiles here won't be persisted into db nor preferences

        [self updateUploadConfiguration];
    }

    // prepare assets and update selectedAssetsIdentifiers using sorted one
    [self reloadAssets];

    // adding observers

    if (!self.registeredPhotoChangeObserver) {
        PHAuthorizationStatus authorizationStatus = [PHPhotoLibrary authorizationStatus];

        if (authorizationStatus == PHAuthorizationStatusAuthorized) {
            [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];

            self.registeredPhotoChangeObserver = YES;
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

    // So the upload directory refreshed after updated
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];

        [self enabledOrDisabledUploadBarButtonItem];
    });
}

- (void)enabledOrDisabledUploadBarButtonItem {
    BOOL atLeastOneFileToUpload = [self tableView:self.tableView numberOfRowsInSection:TABLE_VIEW_SECTION_TO_LIST_UPLOAD_FILES] > 0;

    [self.uploadBarButtonItem setEnabled:atLeastOneFileToUpload];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(processing)) context:NULL];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];

    if (self.registeredPhotoChangeObserver) {
        [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];

        self.registeredPhotoChangeObserver = NO;
    }

    if (_assets) {
        [_assets removeAllObjects];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (DirectoryService *)directoryService {
    if (!_directoryService) {
        _directoryService = [[DirectoryService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];
    }
    
    return _directoryService;
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

- (AppService *)appService {
    if (!_appService) {
        _appService = [[AppService alloc] init];
    }
    
    return _appService;
}

- (UserComputerDao *)userComputerDao {
    if (!_userComputerDao) {
        _userComputerDao = [[UserComputerDao alloc] init];
    }

    return _userComputerDao;
}

- (FilelugFileUploadService *)fileUploadService {
    if (!_fileUploadService) {
        _fileUploadService = [[FilelugFileUploadService alloc] init];
    }

    return _fileUploadService;
}

- (void)updateUploadConfiguration {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *userComputerId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

    if (userComputerId) {
        NSString *defaultUploadDirectory = [userDefaults objectForKey:USER_DEFAULTS_KEY_UPLOAD_DIRECTORY];

        if (!defaultUploadDirectory || defaultUploadDirectory.length < 1) {
            defaultUploadDirectory = [userDefaults objectForKey:USER_DEFAULTS_KEY_FIRST_ROOT_DIRECTORY];
        }

        self.directory = defaultUploadDirectory;

        self.uploadSubdirectoryService = [[UploadSubdirectoryService alloc] initWithPersistedTypeAndValue];
        self.uploadDescriptionService = [[UploadDescriptionService alloc] initWithPersistedTypeAndValue];
        self.uploadNotificationService = [[UploadNotificationService alloc] initWithPersistedType];
    }
}

- (BOOL)needPersistIfChanged {
    return NO;
}

- (void)didChangePreferredContentSize:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (void)photoLibraryDidChange:(PHChange *)changeInstance {
    if (self.assets && [self.assets count] > 0) {
        NSMutableIndexSet *indexesToRemove = [NSMutableIndexSet indexSet];

        for (NSUInteger index = 0; index < [self.assets count]; index++) {
            PHAsset *phAsset = self.assets[index];

            NSString *localIdentifier = phAsset.localIdentifier;

            if (localIdentifier) {
                PHFetchResult<PHAsset *> *fetchResults = [PHAsset fetchAssetsWithLocalIdentifiers:@[localIdentifier] options:nil];

                if (!fetchResults || [fetchResults count] < 1) {
                    // PHAsset not found for the local identifier

                    [indexesToRemove addIndex:index];
                }
            } else {
                [indexesToRemove addIndex:index];
            }
        }

        if ([indexesToRemove count] > 0) {
            [self.assets removeObjectsAtIndexes:indexesToRemove];
        }
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];

        [self enabledOrDisabledUploadBarButtonItem];
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
                }
            });
        }
    }
}

- (void)reloadAssets {
    if (_assets) {
        [_assets removeAllObjects];
    }

    NSMutableArray *orderedAssetIdentifiers = [NSMutableArray array];

    // selectedAssetIdentifiers are elements of type NSString, value of localIdentifier of PHAsset

    _cachingImageManager = [[PHCachingImageManager alloc] init];

    CGFloat scale = [[UIScreen mainScreen] scale];

    CGRect screenBounds = [[UIScreen mainScreen] bounds];

    // each row contains 4 columns at least
    int columnCountPerRowAtLeast = 4;

    _imageResizedSize = CGSizeMake(screenBounds.size.width * scale / columnCountPerRowAtLeast, screenBounds.size.height * scale / columnCountPerRowAtLeast);

    PHFetchOptions *options = [[PHFetchOptions alloc] init];

    if ([Utility isDeviceVersion9OrLater]) {
        options.includeAssetSourceTypes = PHAssetSourceTypeCloudShared | PHAssetSourceTypeUserLibrary | PHAssetSourceTypeiTunesSynced;
    }

    // Show the oldest asset first
    options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:YES]];

    PHFetchResult *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:self.uploadProcessService.selectedAssetIdentifiers options:options];

    [fetchResult enumerateObjectsUsingBlock:^(PHAsset *asset, NSUInteger idx, BOOL *stop) {
        [_assets addObject:asset];

        [orderedAssetIdentifiers addObject:asset.localIdentifier];

        PHImageRequestOptions *imageRequestOptions = [Utility imageRequestOptionsWithAsset:asset];

        // start caching image
        [self.cachingImageManager startCachingImagesForAssets:@[asset] targetSize:_imageResizedSize contentMode:PHImageContentModeAspectFit options:imageRequestOptions];
    }];
    
    self.uploadProcessService.selectedAssetIdentifiers = orderedAssetIdentifiers;
}

- (BOOL)isLoading {
    return (self.processing && [self.processing boolValue]);
}

- (void)stopLoading {
    self.processing = @NO;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self tableView:tableView internalDidSelectRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    [self tableView:tableView internalDidSelectRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView internalDidSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSInteger section = indexPath.section;
        NSInteger row = indexPath.row;
        
        if (section == 0) {
            if (row == 0) {
                // upload to directory
                
                RootDirectoryViewController *rootDirectoryViewController = [Utility instantiateViewControllerWithIdentifier:@"RootDirectory"];
                
                rootDirectoryViewController.fromViewController = self;
                rootDirectoryViewController.directoryOnly = YES;
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.navigationController pushViewController:rootDirectoryViewController animated:YES];
                });
            } else if (row == 1) {
                // subfolder

                NSArray *allNames = [UploadSubdirectoryService namesOfAllTypesWithOrder];
                
                if (allNames) {
                    NSNumber *currentUploadSubdirectoryType = [self.uploadSubdirectoryService type];

                    BOOL disabledCurrentSelected = (currentUploadSubdirectoryType && ![UploadSubdirectoryService isCustomizableWithType:currentUploadSubdirectoryType.integerValue]);

                    NSString *actionSheetTitle = NSLocalizedString(@"Choose type of subdirectory", @"");

                    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:actionSheetTitle message:@"" preferredStyle:UIAlertControllerStyleActionSheet];
                    
                    for (NSString *name in allNames) {
                        NSNumber *subdirectoryType = [UploadSubdirectoryService uploadSubdirectoryTypeWithUploadSubdirectoryName:name];
                        
                        if (subdirectoryType) {
                            UIAlertAction *subfolderAction = [UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                                [self onSelectSubdirectoryActionWithSubdirectoryType:subdirectoryType];
                            }];

                            [subfolderAction setEnabled:!(disabledCurrentSelected && [subdirectoryType isEqualToNumber:currentUploadSubdirectoryType])];

                            [actionSheet addAction:subfolderAction];
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
            } else if (row == 2) {
                // description

                NSArray *allNames = [UploadDescriptionService namesOfAllTypesWithOrder];
                
                if (allNames) {
                    NSNumber *currentUploadDescriptionType = [self.uploadDescriptionService type];

                    BOOL disabledCurrentSelected = (currentUploadDescriptionType && ![UploadDescriptionService isCustomizableWithType:currentUploadDescriptionType.integerValue]);

                    NSString *actionSheetTitle = NSLocalizedString(@"Choose type of description", @"");
                    
                    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:actionSheetTitle message:@"" preferredStyle:UIAlertControllerStyleActionSheet];
                    
                    for (NSString *name in allNames) {
                        NSNumber *descriptionType = [UploadDescriptionService uploadDescriptionTypeWithUploadDescriptionName:name];
                        
                        if (descriptionType) {
                            UIAlertAction *descriptionAction = [UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                                [self onSelectDescriptionActionWithDescriptionType:descriptionType];
                            }];

                            [descriptionAction setEnabled:!(disabledCurrentSelected && [descriptionType isEqualToNumber:currentUploadDescriptionType])];

                            [actionSheet addAction:descriptionAction];
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
            } else if (row == 3) {
                // notification

                NSArray *allNames = [UploadNotificationService namesOfAllTypesWithOrder];
                
                if (allNames) {
                    NSString *actionSheetTitle = NSLocalizedString(@"Choose type of upload notification", @"");
                    
                    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:actionSheetTitle message:@"" preferredStyle:UIAlertControllerStyleActionSheet];
                    
                    for (NSString *name in allNames) {
                        NSNumber *notificationType = [UploadNotificationService uploadNotificationTypeWithUploadNotificationName:name];
                        
                        if (notificationType) {
                            UIAlertAction *notificationAction = [UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                                [self onSelectNotificationActionWithNotificationType:notificationType];
                            }];

                            BOOL enabledAction = !self.uploadNotificationService.type || ![self.uploadNotificationService.name isEqualToString:name];

                            [notificationAction setEnabled:enabledAction];
                            
                            [actionSheet addAction:notificationAction];
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
        } else if (section == TABLE_VIEW_SECTION_TO_LIST_UPLOAD_FILES) {
            // preview file

            NSUInteger assetCount;
            if (self.assets) {
                assetCount = [self.assets count];
            } else {
                assetCount = 0;
            }
            
            NSInteger biasToAssetCount = indexPath.row - assetCount;
            
            if (biasToAssetCount > -1) {
                // belong to selectedFileRelPaths

                FileTransferWithoutManaged *fileTransferWithoutManaged = self.uploadProcessService.downloadedFiles[(NSUInteger) biasToAssetCount];

                if (fileTransferWithoutManaged) {
                    NSString *fileAbsolutePath = [DirectoryService absoluteFilePathFromLocalPath:fileTransferWithoutManaged.localPath userComputerId:fileTransferWithoutManaged.userComputerId];

                    FilePreviewController *filePreviewController = [[FilePreviewController alloc] init];

                    filePreviewController.fileAbsolutePath = fileAbsolutePath;
                    filePreviewController.fromViewController = self;
                    filePreviewController.delegate = self;

                    [filePreviewController preview];

                    self.keptController = filePreviewController;
                }
            } else {
                // belong to assets
                
                AssetsPreviewViewController *previewViewController = [Utility instantiateViewControllerWithIdentifier:@"AssetsPreview"];
                
                previewViewController.asset = self.assets[(NSUInteger) indexPath.row];

                // hides tab bar
                [previewViewController setHidesBottomBarWhenPushed:YES];

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.navigationController pushViewController:previewViewController animated:YES];
                });
            }
        }
    });
}

- (void)onSelectSubdirectoryActionWithSubdirectoryType:(NSNumber *_Nonnull)subdirectoryType {
    // check if customizable
    if ([UploadSubdirectoryService isCustomizableWithType:[subdirectoryType integerValue]]) {
        // let user enter customized name of subdirectory
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:NSLocalizedString(@"Enter customized name", @"") preferredStyle:UIAlertControllerStyleAlert];
        
        [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            [textField setKeyboardType:UIKeyboardTypeDefault];
            
            // set text to the latest customized value in db
            NSString *text = [self.uploadSubdirectoryService customizedValue];
            
            [textField setText:(text ? text : NSLocalizedString(@"New Folder", @""))];
        }];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSString *enteredText = [alertController.textFields[0] text];
            
            [self onEnterCustomizedSubdirectoryName:enteredText subdirectoryType:subdirectoryType];
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

- (void)onSelectDescriptionActionWithDescriptionType:(NSNumber *_Nonnull)descriptionType {
    // Not possible that self.packedUploadDescription is nil
    
    if ([UploadDescriptionService isCustomizableWithType:[descriptionType integerValue]]) {
        // let user enter customized description
        
        FKEditingPackedUploadDescriptionViewController *editingPackedUploadDescriptionViewController = [Utility instantiateViewControllerWithIdentifier:@"FKEditingPackedUploadDescription"];
        
        editingPackedUploadDescriptionViewController.selectedType = descriptionType;
        editingPackedUploadDescriptionViewController.uploadDescriptionDataSource = (id) self;
        
        dispatch_async(dispatch_get_main_queue(), ^ {
            [self.navigationController pushViewController:editingPackedUploadDescriptionViewController animated:YES];
        });
    } else {
        if (!self.uploadDescriptionService.type || ![self.uploadDescriptionService.type isEqualToNumber:descriptionType]) {
            // keep the old customized values so it shows when user changed back from non-customized option.
            NSString *oldDescriptionCustomizedValue = [self.uploadDescriptionService customizedValue];
            
            self.uploadDescriptionService = [[UploadDescriptionService alloc] initWithUploadDescriptionType:descriptionType uploadDescriptionValue:oldDescriptionCustomizedValue];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
        }
    }
}

- (void)onSelectNotificationActionWithNotificationType:(NSNumber *_Nonnull)notificationType {
    // notification
    
    if (!self.uploadNotificationService.type || ![self.uploadNotificationService.type isEqualToNumber:notificationType]) {
        self.uploadNotificationService = [[UploadNotificationService alloc] initWithUploadNotificationType:notificationType];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *title;
    
    if (section == 0) {
        title = NSLocalizedString(@"Settings", @"");
    } else if (section == 1) {
        NSString *totalDisplaySize = [self sizeOfAllFiles];

        title = [NSString stringWithFormat:NSLocalizedString(@"Files selected to upload (Total)", @""), totalDisplaySize];
    }
    
    return title;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    NSString *title;
    
    if (section == 1) {
        title = NSLocalizedString(@"Select to preview, or slide to remove from selection.", @"");
    }
    
    return title;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger row;
    
    if (section == 0) {
        // directory, subfolder, description and notification
        
        row = 4;
    } else if (section == TABLE_VIEW_SECTION_TO_LIST_UPLOAD_FILES) {
        // including assets and absolutePaths
        
        NSInteger assetsCount;
        if (self.assets) {
            assetsCount = [self.assets count];
        } else {
            assetsCount = 0;
        }
        
        NSInteger downloadedFilesCount;
        if (self.uploadProcessService.downloadedFiles) {
            downloadedFilesCount = [self.uploadProcessService.downloadedFiles count];
        } else {
            downloadedFilesCount = 0;
        }
        
        row = assetsCount + downloadedFilesCount;

//        NSInteger relPathsCount;
//        if (self.uploadProcessService.selectedFileRelPaths) {
//            relPathsCount = [self.uploadProcessService.selectedFileRelPaths count];
//        } else {
//            relPathsCount = 0;
//        }
//
//        row = assetsCount + relPathsCount;
    } else {
        row = 0;
    }
    
    return row;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return TABLE_VIEW_CELL_ROW_HEIGHT_FOR_MEDIUM_CONTENT_SIZE_CATEGORY;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat height;

    if (indexPath.section == kUploadSummarySectionIndexOfSettings && indexPath.row == kUploadSummaryRowIndexOfUploadDirectory) {
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
//    if ([self.preferredContentSizeCategoryService isXXLargeContentSizeCategory]) {
//        height = TABLE_VIEW_CELL_ROW_HEIGHT_FOR_XX_LARGE_CONTENT_SIZE_CATEGORY;
//    } else if ([self.preferredContentSizeCategoryService isLargeContentSizeCategory]) {
//        height = TABLE_VIEW_CELL_ROW_HEIGHT_FOR_LARGE_CONTENT_SIZE_CATEGORY;
//    } else if ([self.preferredContentSizeCategoryService isMediumContentSizeCategory]) {
//        height = TABLE_VIEW_CELL_ROW_HEIGHT_FOR_MEDIUM_CONTENT_SIZE_CATEGORY;
//    } else {
//        height = TABLE_VIEW_CELL_ROW_HEIGHT_FOR_SMALL_CONTENT_SIZE_CATEGORY;
//    }
//
//    return height;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *UploadSummarySettingCell = @"UploadSummarySettingCell";
    static NSString *UploadSummaryFileCell = @"UploadSummaryFileCell";

    UITableViewCell *cell;
    
    NSInteger section = [indexPath section];
    NSInteger row = [indexPath row];
    
    if (section == kUploadSummarySectionIndexOfSettings) {
        cell = [Utility tableView:tableView createOrDequeueCellWithStyle:UITableViewCellStyleDefault reuseIdentifier:UploadSummarySettingCell forIndexPath:indexPath];

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
        cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        cell.detailTextLabel.textAlignment = NSTextAlignmentNatural;

        if (row == kUploadSummaryRowIndexOfUploadDirectory) {
            // upload to directory
            
            [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
            
            [cell.imageView setImage:[UIImage imageNamed:@"ic_folder"]];
            
            [cell.textLabel setText:NSLocalizedString(@"All Upload To Directory", @"")];

            if (self.directory && [self.directory stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
                [cell.detailTextLabel setText:self.directory];
            } else {
                [cell.detailTextLabel setText:NSLocalizedString(@"(Not Set2)", @"")];
            }
        } else if (row == 1) {
            // subfolder
            
            [cell setAccessoryType:UITableViewCellAccessoryNone];
            
            [cell.imageView setImage:[UIImage imageNamed:@"folder-add"]];
            
            [cell.textLabel setText:NSLocalizedString(@"Subdirectory Name", @"")];
            
            [cell.detailTextLabel setText:[self.uploadSubdirectoryService displayedText]];
        } else if (row == 2) {
            // description
            
            [cell setAccessoryType:UITableViewCellAccessoryNone];
            
            [cell.imageView setImage:[UIImage imageNamed:@"note-write"]];
            
            [cell.textLabel setText:NSLocalizedString(@"Description", @"")];
            
            [cell.detailTextLabel setText:[self.uploadDescriptionService displayedText]];
        } else if (row == 3) {
            // notification
            
            [cell setAccessoryType:UITableViewCellAccessoryNone];
            
            [cell.imageView setImage:[UIImage imageNamed:@"bell"]];
            
            [cell.textLabel setText:NSLocalizedString(@"Upload Notification", @"")];
            
            [cell.detailTextLabel setText:[self.uploadNotificationService name]];
        } else {
            // for unknow rows
            
            [cell setAccessoryType:UITableViewCellAccessoryNone];
            
            [cell.imageView setImage:[UIImage imageNamed:@"ic_folder"]];
            
            [cell.textLabel setText:@""];
            
            [cell.detailTextLabel setText:@""];
        }
    } else if (section == TABLE_VIEW_SECTION_TO_LIST_UPLOAD_FILES) {
        cell = [Utility tableView:tableView createOrDequeueCellWithStyle:UITableViewCellStyleDefault reuseIdentifier:UploadSummaryFileCell forIndexPath:indexPath];

        // configure the preferred font

        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        cell.textLabel.textColor = [UIColor darkTextColor];
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.adjustsFontSizeToFitWidth = NO;
        cell.textLabel.lineBreakMode = NSLineBreakByCharWrapping;
        cell.textLabel.textAlignment = NSTextAlignmentNatural;
        
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        
        // First list assets, then files in self.selectedAbsoluteFilePaths
        
        NSUInteger assetCount;
        if (self.assets) {
            assetCount = [self.assets count];
        } else {
            assetCount = 0;
        }
        
        NSInteger biasToAssetCount = row - assetCount;
        
        if (biasToAssetCount > -1 && [self.uploadProcessService.downloadedFiles count] > biasToAssetCount) {
            // belong to downloadedFiles

            FileTransferWithoutManaged *fileTransferWithoutManaged = self.uploadProcessService.downloadedFiles[(NSUInteger) biasToAssetCount];

            if (fileTransferWithoutManaged) {
                NSString *localRelPath = fileTransferWithoutManaged.localPath;

                [cell.imageView setImage:[DirectoryService imageForLocalFilePath:localRelPath isDirectory:NO]];

                [cell.textLabel setText:[localRelPath lastPathComponent]];
            }
            
//            NSString *fileRelPath = self.uploadProcessService.selectedFileRelPaths[(NSUInteger) biasToAssetCount];
//
//            [cell.imageView setImage:[DirectoryService imageForLocalFilePath:fileRelPath isDirectory:NO]];
//
//            [cell.textLabel setText:[fileRelPath lastPathComponent]];
        } else if ([self.assets count] > row) {
            // belong to assets

            PHAsset *asset = self.assets[(NSUInteger) row];

            if (asset) {
                PHImageRequestOptions *requestOptions = [Utility imageRequestOptionsWithAsset:asset];

                [self.cachingImageManager requestImageForAsset:asset
                                                    targetSize:self.imageResizedSize
                                                   contentMode:PHImageContentModeAspectFit
                                                       options:requestOptions
                                                 resultHandler:^(UIImage *result, NSDictionary *info) {
                                                     if (result) {
                                                         [cell.imageView setImage:result];
                                                     } else {
                                                         UIImage *defaultImage = [UIImage imageNamed:@"upload_file_temp"];

                                                         [cell.imageView setImage:defaultImage];
                                                     }
                                                 }];

                // TODO: Make sure it works under iOS 8 and 9 for [asset valueForKey:@"filename"]
                [cell.textLabel setText:[asset valueForKey:@"filename"]];
            }
        } else {
            UIImage *defaultImage = [UIImage imageNamed:@"upload_file_temp"];

            [cell.imageView setImage:defaultImage];
            [cell.textLabel setText:@""];
        }
    }
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == TABLE_VIEW_SECTION_TO_LIST_UPLOAD_FILES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        @try {
            NSUInteger assetCount;
            if (self.assets) {
                assetCount = [self.assets count];
            } else {
                assetCount = 0;
            }
            
            NSUInteger rowIndex = (NSUInteger) indexPath.row;
            
            NSInteger biasToAssetCount = rowIndex - assetCount;

            if (biasToAssetCount > -1 && [self.uploadProcessService.downloadedFiles count] > biasToAssetCount) {
                // belong to selectedFileRelPaths

                [self.uploadProcessService.downloadedFiles removeObjectAtIndex:(NSUInteger) biasToAssetCount];
            } else {
                // belong to assets

                [self.assets removeObjectAtIndex:rowIndex];
                [self.uploadProcessService.selectedAssetIdentifiers removeObjectAtIndex:rowIndex];
            }
//            if (biasToAssetCount > -1 && [self.uploadProcessService.selectedFileRelPaths count] > biasToAssetCount) {
//                // belong to selectedFileRelPaths
//
//                [self.uploadProcessService.selectedFileRelPaths removeObjectAtIndex:(NSUInteger) biasToAssetCount];
//            } else {
//                // belong to assets
//
//                [self.assets removeObjectAtIndex:rowIndex];
//                [self.uploadProcessService.selectedAssetIdentifiers removeObjectAtIndex:rowIndex];
//            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
        } @catch(NSException *e) {
            NSLog(@"Error on deleting row at: %ld\n%@", (long) indexPath.row, e.userInfo);
        }

        if ([self tableView:tableView numberOfRowsInSection:TABLE_VIEW_SECTION_TO_LIST_UPLOAD_FILES] < 1) {
            // no row to upload --> disabled upload bar button item

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.uploadBarButtonItem setEnabled:NO];
            });
        }
    }
}

- (void)upload:(id)sender {
    [self setUploadedCount:0];

    self.processing = @YES;

    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    dispatch_async(queue, ^{
        if (!self.directory || [self.directory stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length < 1) {
            // prompt that empty directory not allowed

            dispatch_async(dispatch_get_main_queue(), ^{
                self.processing = @NO;

                NSString *message = NSLocalizedString(@"Directory should not be empty", @"");

                [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
            });
        } else {
            NSArray * assets;
            if (self.assets) {
                assets = [NSArray arrayWithArray:self.assets];
            } else {
                assets = [NSArray array];
            }

            [self internalUploadWithAssets:assets downloadedFiles:[NSArray arrayWithArray:self.uploadProcessService.downloadedFiles] directory:self.directory tryAgainIfFailed:YES];
        }
    });
}

- (void)internalUploadWithAssets:(NSArray *)assets downloadedFiles:(NSArray <FileTransferWithoutManaged *> *)downloadedFiles directory:(NSString *)directory tryAgainIfFailed:(BOOL)tryAgainIfFailed {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];

    NSString *tempLugServerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID];

    if (sessionId == nil || sessionId.length < 1) {
        [FilelugUtility alertEmptyUserSessionFromViewController:self];
    } else if (tempLugServerId == nil || tempLugServerId.length < 1) {
        self.processing = @NO;

        [self requestConnectWithAuthService:self.authService userDefaults:userDefaults assets:assets downloadedFiles:downloadedFiles directory:directory];
    } else {
        self.processing = @YES;

        SystemService *systemService = [[SystemService alloc] initWithCachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeInterval:CONNECTION_TIME_INTERVAL];

        dispatch_queue_t globalConcurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

        [systemService pingDesktop:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            dispatch_async(globalConcurrentQueue, ^{
                NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

                if (statusCode == 200) {
                    [SystemService parsePingDesktopResponseJson:data completionHandler:^(NSDictionary *dictionary) {
                        __block BOOL canUpload = YES;

                        // Check file size limit

                        if (!dictionary || !dictionary[@"upload-size-limit"]) {
                            canUpload = NO;

                            NSLog(@"Skip check upload size limit for uload size limit not found.");
                        } else {
                            NSNumber *uploadSizeLimit = dictionary[@"upload-size-limit"];

                            if (uploadSizeLimit) {
                                long long int fileSizeLimit = [uploadSizeLimit longLongValue];

                                canUpload = [self checkUploadFileSizeWithFileSizeLimit:fileSizeLimit assets:assets downloadedFiles:downloadedFiles];
                            } else {
                                canUpload = NO;

                                NSLog(@"Skip check upload size limit for uload size limit not found.");
                            }
                        }

                        if (canUpload) {
                            // The queue will be used in dispatch_barrier_async, so it must an concurrent queue and created by dispatch_queue_create
                            dispatch_queue_t concurrentQueueForBarrier = dispatch_queue_create(DISPATCH_QUEUE_UPLOAD_CONCURRENT, DISPATCH_QUEUE_CONCURRENT);

                            dispatch_async(concurrentQueueForBarrier, ^{
                                // create all the transfer keys for the uploading files

                                NSMutableArray *transferKeysForAbsolutePaths = [NSMutableArray array];
                                NSMutableArray *filenamesForAbsolutePaths = [NSMutableArray array];

                                NSMutableArray *transferKeysForAsset = [NSMutableArray array];
                                NSMutableArray *filenamesForAsset = [NSMutableArray array];

                                // for files from file-sharing

                                for (FileTransferWithoutManaged *fileTransferWithoutManaged in downloadedFiles) {
                                    NSString *filename = [fileTransferWithoutManaged.localPath lastPathComponent];

                                    NSString *transferKey = [Utility generateUploadKeyWithSessionId:sessionId sourceFilename:filename];

                                    [transferKeysForAbsolutePaths addObject:transferKey];

                                    [filenamesForAbsolutePaths addObject:filename];
                                }

                                // for assets

                                for (PHAsset *asset in assets) {
                                    // transfer key

                                    NSString *assetIdentifier = asset.localIdentifier;

                                    // generate new transfer key - unique for all users
                                    NSString *transferKey = [Utility generateUploadKeyWithSessionId:sessionId sourceFileIdentifier:assetIdentifier];

                                    [transferKeysForAsset addObject:transferKey];

                                    // filename
                                    // Make sure it works under iOS 8 and 9 for [asset valueForKey:@"filename"]
                                    [filenamesForAsset addObject:[asset valueForKey:@"filename"]];
                                }

                                // create upload summary data in server

                                self.processing = @YES;

                                // uploadDirectory contains fullSubdirectoryPath, if any

                                NSString *realSubdirectoryValue = [self.uploadSubdirectoryService generateRealSubdirectoryValue];

                                NSString *directoryPathWithSubdirectory;

                                if (realSubdirectoryValue && [realSubdirectoryValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
                                    directoryPathWithSubdirectory = [NSString stringWithFormat:@"%@%@%@", directory, [userDefaults stringForKey:USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR], realSubdirectoryValue];
                                } else {
                                    directoryPathWithSubdirectory = directory;
                                }

                                // combine two filename arrays
                                NSArray *filenames = [filenamesForAbsolutePaths arrayByAddingObjectsFromArray:filenamesForAsset];

                                NSString *uploadGroupId = [Utility generateUploadGroupIdWithFilenames:filenames];

                                NSInteger subdirectoryType = self.uploadSubdirectoryService.type ? [self.uploadSubdirectoryService.type integerValue] : [UploadSubdirectoryService defaultType];

                                NSString *subdirectoryValue = [self.uploadSubdirectoryService customizable] ? [self.uploadSubdirectoryService customizedValue] : @"";

                                NSString *fullSubdirectoryPath = [self.uploadSubdirectoryService generateRealSubdirectoryValue];

                                NSInteger descriptionType = self.uploadDescriptionService.type ? [self.uploadDescriptionService.type integerValue] : [UploadDescriptionService defaultType];

                                NSString *descriptionValue = [self.uploadDescriptionService customizable] ? [self.uploadDescriptionService customizedValue] : @"";

                                NSString *fullDescriptionContent = [self.uploadDescriptionService generateRealDescriptionValueWithFilenames:filenames];

                                NSInteger notificationType = self.uploadNotificationService.type ? [self.uploadNotificationService.type integerValue] : [UploadNotificationService defaultType];

                                // combine two transferKey arrays
                                NSArray *transferKeys = [transferKeysForAbsolutePaths arrayByAddingObjectsFromArray:transferKeysForAsset];

                                // DBUG: See if all packed uploaded values are correct
//                                    NSLog(@"Subdirectory:\n%@\nDescription:\n%@\nNotification:\n%@", [self.packedUploadSubdirectory description], [self.packedUploadDescription description], [self.packedUploadNotification description]);

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

                                                                                                                                        dispatch_async(concurrentQueueForBarrier, ^{
                                                                                                                                            @try {
                                                                                                                                                const NSUInteger fileCount = [downloadedFiles count];

                                                                                                                                                const NSUInteger assetCount = [assets count];

                                                                                                                                                const NSUInteger totalCount = fileCount + assetCount;

                                                                                                                                                // files from file-sharing

                                                                                                                                                for (NSUInteger index = 0; index < fileCount; index++) {
                                                                                                                                                    FileTransferWithoutManaged *fileTransferWithoutManaged = downloadedFiles[index];

                                                                                                                                                    NSString *filename = filenamesForAbsolutePaths[index];
                                                                                                                                                    NSString *transferKey = transferKeysForAbsolutePaths[index];

                                                                                                                                                    FileUploadStatusModel *fileUploadStatusModel = [[FileUploadStatusModel alloc] initWithTransferKey:transferKey transferredSize:@0 fileSize:@0 fileLastModifiedDate:@0];

                                                                                                                                                    // save and upload one-by-one
                                                                                                                                                    [self.fileUploadService uploadFileFromFileObject:fileTransferWithoutManaged sourceType:@(ASSET_FILE_SOURCE_TYPE_SHARED_FILE) sessionId:sessionId fileUploadGroupId:uploadGroupId directory:directoryPathWithSubdirectory filename:filename shouldCheckIfLocalFileChanged:NO fileUploadStatusModel:fileUploadStatusModel addToStartTimestampWithMillisec:index completionHandler:^(NSError *uploadError) {
                                                                                                                                                        // Use dispatch_barrier_async to make sure the block in it will be serialized processed by the queue.
                                                                                                                                                        // Be sure that the queue is an concurrent queue and created by dispatch_queue_create

                                                                                                                                                        dispatch_barrier_async(concurrentQueueForBarrier, ^{
                                                                                                                                                            self.uploadedCount += 1;

                                                                                                                                                            if (totalCount == self.uploadedCount) {
                                                                                                                                                                // delay to prevent it won't pop to fromViewController because of the upload speeds too fast

                                                                                                                                                                double delayInSeconds = 1.0;
                                                                                                                                                                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));
                                                                                                                                                                dispatch_after(popTime, globalConcurrentQueue, ^(void) {
                                                                                                                                                                    [self popToFromViewController];
                                                                                                                                                                });
                                                                                                                                                            }
                                                                                                                                                        });
                                                                                                                                                    }];
                                                                                                                                                }

                                                                                                                                                // assets

                                                                                                                                                for (NSUInteger index = 0; index < assetCount; index++) {
                                                                                                                                                    PHAsset *asset = assets[index];

                                                                                                                                                    NSString *filename = filenamesForAsset[index];
                                                                                                                                                    NSString *transferKey = transferKeysForAsset[index];

                                                                                                                                                    FileUploadStatusModel *fileUploadStatusModel = [[FileUploadStatusModel alloc] initWithTransferKey:transferKey transferredSize:@0 fileSize:@0 fileLastModifiedDate:@0];

                                                                                                                                                    // save and upload one-by-one
                                                                                                                                                    [self.fileUploadService uploadFileFromFileObject:asset sourceType:@(ASSET_FILE_SOURCE_TYPE_PHASSET) sessionId:sessionId fileUploadGroupId:uploadGroupId directory:directoryPathWithSubdirectory filename:filename shouldCheckIfLocalFileChanged:NO fileUploadStatusModel:fileUploadStatusModel addToStartTimestampWithMillisec:(fileCount + index) completionHandler:^(NSError *uploadError) {
                                                                                                                                                        // Use dispatch_barrier_async to make sure the block in it will be serialized processed by the queue.
                                                                                                                                                        // Be sure that the queue is an concurrent queue and created by dispatch_queue_create

                                                                                                                                                        dispatch_barrier_async(concurrentQueueForBarrier, ^{
                                                                                                                                                            self.uploadedCount += 1;

                                                                                                                                                            if (totalCount == self.uploadedCount) {
                                                                                                                                                                // delay to prevent it won't pop to fromViewController because of the upload speeds too fast

                                                                                                                                                                double delayInSeconds = 1.0;
                                                                                                                                                                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));
                                                                                                                                                                dispatch_after(popTime, globalConcurrentQueue, ^(void) {
                                                                                                                                                                    [self popToFromViewController];
                                                                                                                                                                });
                                                                                                                                                            }
                                                                                                                                                        });
                                                                                                                                                    }];
                                                                                                                                                }
                                                                                                                                            } @finally {
                                                                                                                                                self.processing = @NO;
                                                                                                                                            }
                                                                                                                                        });
                                                                                                                                    }];
                                                                                  } else {
                                                                                      self.processing = @NO;

                                                                                      NSString *messagePrefix = NSLocalizedString(@"Error on upload file.", @"");

                                                                                      [self alertToTryUploadAgainWithMessagePrefix:messagePrefix response:responseFromCreate data:dataFromCreate error:errorFromCreate assets:assets downloadedFiles:downloadedFiles directory:directory];
                                                                                  }
                                                                              }];
                            });
                        }
                    }];
                } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
                    self.processing = @YES;

                    [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
                        if ([userDefaults objectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID]) {
                            /* recursively invoked */

                            dispatch_async(globalConcurrentQueue, ^{
                                [self internalUploadWithAssets:assets downloadedFiles:downloadedFiles directory:directory tryAgainIfFailed:NO];
                            });
                        } else {
                            // server not connected, so request connection
                            [self requestConnectWithAuthService:self.authService userDefaults:userDefaults assets:assets downloadedFiles:downloadedFiles directory:directory];
                        }
                    } failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
                        self.processing = @NO;

                        NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");

                        [self alertToTryUploadAgainWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror assets:assets downloadedFiles:downloadedFiles directory:directory];
                    }];
                } else if (tryAgainIfFailed && statusCode == 503) {
                    // server not connected, so request connection
                    [self requestConnectWithAuthService:self.authService userDefaults:userDefaults assets:assets downloadedFiles:downloadedFiles directory:directory];
                } else {
                    self.processing = @NO;

                    NSString *messagePrefix = NSLocalizedString(@"Error on upload file.", @"");

                    [self alertToTryUploadAgainWithMessagePrefix:messagePrefix response:response data:data error:error assets:assets downloadedFiles:downloadedFiles directory:directory];
                }
            });
        }];
    }
}

//- (void)upload:(id)sender {
//    [self setUploadedCount:0];
//
//    self.processing = @YES;
//
//    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
//
//    dispatch_async(queue, ^{
//        if (!self.directory || [self.directory stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length < 1) {
//            // prompt that empty directory not allowed
//
//            dispatch_async(dispatch_get_main_queue(), ^{
//                self.processing = @NO;
//
//                NSString *message = NSLocalizedString(@"Directory should not be empty", @"");
//
//                [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
//            });
//        } else {
//            NSArray * assets;
//            if (self.assets) {
//                assets = [NSArray arrayWithArray:self.assets];
//            } else {
//                assets = [NSArray array];
//            }
//
//            NSMutableArray *fileAbsolutePaths = [NSMutableArray array];
//
//            if (self.uploadProcessService.downloadedFiles && [self.uploadProcessService.downloadedFiles count] > 0) {
//                // copy from FileUploadProcessService and make them absolute paths
//
//                for (FileTransferWithoutManaged *fileTransferWithoutManaged in self.uploadProcessService.downloadedFiles) {
//                    NSString *fileAbsolutePath = [DirectoryService absoluteFilePathFromLocalPath:fileTransferWithoutManaged.localPath userComputerId:fileTransferWithoutManaged.userComputerId];
//
//                    [fileAbsolutePaths addObject:fileAbsolutePath];
//                }
//            }
////            if (self.uploadProcessService.selectedFileRelPaths && [self.uploadProcessService.selectedFileRelPaths count] > 0) {
////                // copy from FileUploadProcessService and make them absolute paths
////
////                fileAbsolutePaths = [NSMutableArray array];
////
////                NSString *devicdSharingFolderPath = [DirectoryService devicdSharingFolderPath];
////
////                for (NSString *fileRelPath in self.uploadProcessService.selectedFileRelPaths) {
////                    NSString *fileAbsolutePath = [devicdSharingFolderPath stringByAppendingPathComponent:fileRelPath];
////
////                    [fileAbsolutePaths addObject:fileAbsolutePath];
////                }
////            }
//
//            [self internalUploadWithAssets:assets fileAbsolutePaths:fileAbsolutePaths directory:self.directory tryAgainIfFailed:YES];
//        }
//    });
//}
//
//- (void)internalUploadWithAssets:(NSArray *)assets fileAbsolutePaths:(NSArray <NSString *> *)fileAbsolutePaths directory:(NSString *)directory tryAgainIfFailed:(BOOL)tryAgainIfFailed {
//    NSUserDefaults *userDefaults = [Utility groupUserDefaults];
//
//    NSString *sessionId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];
//
//    NSString *tempLugServerId = [userDefaults stringForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID];
//
//    if (sessionId == nil || sessionId.length < 1) {
//        [FilelugUtility alertEmptyUserSessionFromViewController:self];
////        [FilelugUtility alertUserNeverConnectedWithViewController:self loginSuccessHandler:^(NSURLResponse *response, NSData *data) {
////            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
////                self.processing = @NO;
////
////                [self internalUploadWithAssets:assets fileAbsolutePaths:fileAbsolutePaths directory:directory];
////            });
////        }];
//    } else if (tempLugServerId == nil || tempLugServerId.length < 1) {
//        self.processing = @NO;
//
//        [self requestConnectWithAuthService:self.authService userDefaults:userDefaults assets:assets fileAbsolutePaths:fileAbsolutePaths directory:directory];
//    } else {
//        self.processing = @YES;
//
//        SystemService *systemService = [[SystemService alloc] initWithCachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeInterval:CONNECTION_TIME_INTERVAL];
//
//        dispatch_queue_t globalConcurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
//
//        [systemService pingDesktop:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
//            dispatch_async(globalConcurrentQueue, ^{
//                NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];
//
//                if (statusCode == 200) {
//                    [SystemService parsePingDesktopResponseJson:data completionHandler:^(NSDictionary *dictionary) {
//                        __block BOOL canUpload = YES;
//
//                        // Check file size limit
//
//                        if (!dictionary || !dictionary[@"upload-size-limit"]) {
//                            canUpload = NO;
//
//                            NSLog(@"Skip check upload size limit for uload size limit not found.");
//                        } else {
//                            NSNumber *uploadSizeLimit = dictionary[@"upload-size-limit"];
//
//                            if (uploadSizeLimit) {
//                                long long int fileSizeLimit = [uploadSizeLimit longLongValue];
//
//                                canUpload = [self checkUploadFileSizeWithFileSizeLimit:fileSizeLimit assets:assets fileAbsolutePaths:fileAbsolutePaths];
//                            } else {
//                                canUpload = NO;
//
//                                NSLog(@"Skip check upload size limit for uload size limit not found.");
//                            }
//                        }
//
//                        if (canUpload) {
//                            // The queue will be used in dispatch_barrier_async, so it must an concurrent queue and created by dispatch_queue_create
//                            dispatch_queue_t concurrentQueueForBarrier = dispatch_queue_create(DISPATCH_QUEUE_UPLOAD_CONCURRENT, DISPATCH_QUEUE_CONCURRENT);
//
//                            dispatch_async(concurrentQueueForBarrier, ^{
//                                // create all the transfer keys for the uploading files
//
//                                NSMutableArray *transferKeysForAbsolutePaths = [NSMutableArray array];
//                                NSMutableArray *filenamesForAbsolutePaths = [NSMutableArray array];
//
//                                NSMutableArray *transferKeysForAsset = [NSMutableArray array];
//                                NSMutableArray *filenamesForAsset = [NSMutableArray array];
//
//                                // for files from file-sharing
//
//                                for (NSString *absolutePath in fileAbsolutePaths) {
//                                    NSString *transferKey = [Utility generateUploadKeyWithSessionId:sessionId sourceFilePath:absolutePath];
//
//                                    [transferKeysForAbsolutePaths addObject:transferKey];
//
//                                    [filenamesForAbsolutePaths addObject:[absolutePath lastPathComponent]];
//                                }
//
//                                // for assets
//
//                                for (PHAsset *asset in assets) {
//                                    // transfer key
//
//                                    NSString *assetIdentifier = asset.localIdentifier;
//
//                                    // generate new transfer key - unique for all users
//                                    NSString *transferKey = [Utility generateUploadKeyWithSessionId:sessionId sourceFileIdentifier:assetIdentifier];
//
//                                    [transferKeysForAsset addObject:transferKey];
//
//                                    // filename
//                                    // Make sure it works under iOS 8 and 9 for [asset valueForKey:@"filename"]
//                                    [filenamesForAsset addObject:[asset valueForKey:@"filename"]];
//                                }
//
//                                // create upload summary data in server
//
//                                self.processing = @YES;
//
//                                // uploadDirectory contains fullSubdirectoryPath, if any
//
//                                NSString *realSubdirectoryValue = [self.uploadSubdirectoryService generateRealSubdirectoryValue];
//
//                                NSString *directoryPathWithSubdirectory;
//
//                                if (realSubdirectoryValue && [realSubdirectoryValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
//                                    directoryPathWithSubdirectory = [NSString stringWithFormat:@"%@%@%@", directory, [userDefaults stringForKey:USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR], realSubdirectoryValue];
//                                } else {
//                                    directoryPathWithSubdirectory = directory;
//                                }
//
//                                // combine two filename arrays
//                                NSArray *filenames = [filenamesForAbsolutePaths arrayByAddingObjectsFromArray:filenamesForAsset];
//
//                                NSString *uploadGroupId = [Utility generateUploadGroupIdWithFilenames:filenames];
//
//                                NSInteger subdirectoryType = self.uploadSubdirectoryService.type ? [self.uploadSubdirectoryService.type integerValue] : [UploadSubdirectoryService defaultType];
//
//                                NSString *subdirectoryValue = [self.uploadSubdirectoryService customizable] ? [self.uploadSubdirectoryService customizedValue] : @"";
//
//                                NSString *fullSubdirectoryPath = [self.uploadSubdirectoryService generateRealSubdirectoryValue];
//
//                                NSInteger descriptionType = self.uploadDescriptionService.type ? [self.uploadDescriptionService.type integerValue] : [UploadDescriptionService defaultType];
//
//                                NSString *descriptionValue = [self.uploadDescriptionService customizable] ? [self.uploadDescriptionService customizedValue] : @"";
//
//                                NSString *fullDescriptionContent = [self.uploadDescriptionService generateRealDescriptionValueWithFilenames:filenames];
//
//                                NSInteger notificationType = self.uploadNotificationService.type ? [self.uploadNotificationService.type integerValue] : [UploadNotificationService defaultType];
//
//                                // combine two transferKey arrays
//                                NSArray *transferKeys = [transferKeysForAbsolutePaths arrayByAddingObjectsFromArray:transferKeysForAsset];
//
//                                // DBUG: See if all packed uploaded values are correct
////                                    NSLog(@"Subdirectory:\n%@\nDescription:\n%@\nNotification:\n%@", [self.packedUploadSubdirectory description], [self.packedUploadDescription description], [self.packedUploadNotification description]);
//
//                                [self.directoryService createFileUploadSummaryWithUploadGroupId:uploadGroupId
//                                                                                targetDirectory:directoryPathWithSubdirectory
//                                                                                   transferKeys:transferKeys
//                                                                               subdirectoryType:subdirectoryType
//                                                                              subdirectoryValue:fullSubdirectoryPath
//                                                                                descriptionType:descriptionType
//                                                                               descriptionValue:fullDescriptionContent
//                                                                               notificationType:notificationType
//                                                                                        session:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID]
//                                                                              completionHandler:^(NSData *dataFromCreate, NSURLResponse *responseFromCreate, NSError *errorFromCreate) {
//                                    NSInteger statusCodeFromCreate = [(NSHTTPURLResponse *) responseFromCreate statusCode];
//
//                                    if (!errorFromCreate && statusCodeFromCreate == 200) {
//                                        // Save file-upload-group to local db before upload each files
//
//                                        // The values of subdirectoryValue and descriptionValue are not the same from the ones uploaded to the server
//
//                                        [self.fileUploadGroupDao createFileUploadGroupWithUploadGroupId:uploadGroupId
//                                                                                        targetDirectory:directoryPathWithSubdirectory
//                                                                                       subdirectoryType:subdirectoryType
//                                                                                      subdirectoryValue:subdirectoryValue
//                                                                                        descriptionType:descriptionType
//                                                                                       descriptionValue:descriptionValue
//                                                                                       notificationType:notificationType
//                                                                                         userComputerId:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID]
//                                                                                      completionHandler:^() {
//                                              // upload file one by one
//
//                                              dispatch_async(concurrentQueueForBarrier, ^{
//                                                  @try {
//                                                      const NSUInteger fileCount = [fileAbsolutePaths count];
//
//                                                      const NSUInteger assetCount = [assets count];
//
//                                                      const NSUInteger totalCount = fileCount + assetCount;
//
//                                                      // files from file-sharing
//
//                                                      for (NSUInteger index = 0; index < fileCount; index++) {
//                                                          NSString *absolutePath = fileAbsolutePaths[index];
//
//                                                          NSString *filename = filenamesForAbsolutePaths[index];
//                                                          NSString *transferKey = transferKeysForAbsolutePaths[index];
//
//                                                          FileUploadStatusModel *fileUploadStatusModel = [[FileUploadStatusModel alloc] initWithTransferKey:transferKey transferredSize:@0 fileSize:@0 fileLastModifiedDate:@0];
//
//                                                          // save and upload one-by-one
//                                                          [[FilelugUtility defaultAssetUploadService] uploadFileFromFileObject:absolutePath sourceType:@(ASSET_FILE_SOURCE_TYPE_SHARED_FILE) sessionId:sessionId fileUploadGroupId:uploadGroupId directory:directoryPathWithSubdirectory filename:filename shouldCheckIfLocalFileChanged:NO fileUploadStatusModel:fileUploadStatusModel addToStartTimestampWithMillisec:index completionHandler:^(NSError *uploadError) {
//                                                              // Use dispatch_barrier_async to make sure the block in it will be serialized processed by the queue.
//                                                              // Be sure that the queue is an concurrent queue and created by dispatch_queue_create
//
//                                                              dispatch_barrier_async(concurrentQueueForBarrier, ^{
//                                                                  self.uploadedCount += 1;
//
//                                                                  if (totalCount == self.uploadedCount) {
//                                                                      // delay to prevent it won't pop to fromViewController because of the upload speeds too fast
//
//                                                                      double delayInSeconds = 1.0;
//                                                                      dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));
//                                                                      dispatch_after(popTime, globalConcurrentQueue, ^(void) {
//                                                                          [self popToFromViewController];
//                                                                      });
//                                                                  }
//                                                              });
//                                                          }];
//                                                      }
//
//                                                      // assets
//
//                                                      for (NSUInteger index = 0; index < assetCount; index++) {
//                                                          PHAsset *asset = assets[index];
//
//                                                          NSString *filename = filenamesForAsset[index];
//                                                          NSString *transferKey = transferKeysForAsset[index];
//
//                                                          FileUploadStatusModel *fileUploadStatusModel = [[FileUploadStatusModel alloc] initWithTransferKey:transferKey transferredSize:@0 fileSize:@0 fileLastModifiedDate:@0];
//
//                                                          // save and upload one-by-one
//                                                          [[FilelugUtility defaultAssetUploadService] uploadFileFromFileObject:asset sourceType:@(ASSET_FILE_SOURCE_TYPE_PHASSET) sessionId:sessionId fileUploadGroupId:uploadGroupId directory:directoryPathWithSubdirectory filename:filename shouldCheckIfLocalFileChanged:NO fileUploadStatusModel:fileUploadStatusModel addToStartTimestampWithMillisec:(fileCount + index) completionHandler:^(NSError *uploadError) {
//                                                              // Use dispatch_barrier_async to make sure the block in it will be serialized processed by the queue.
//                                                              // Be sure that the queue is an concurrent queue and created by dispatch_queue_create
//
//                                                              dispatch_barrier_async(concurrentQueueForBarrier, ^{
//                                                                  self.uploadedCount += 1;
//
//                                                                  if (totalCount == self.uploadedCount) {
//                                                                      // delay to prevent it won't pop to fromViewController because of the upload speeds too fast
//
//                                                                      double delayInSeconds = 1.0;
//                                                                      dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));
//                                                                      dispatch_after(popTime, globalConcurrentQueue, ^(void) {
//                                                                          [self popToFromViewController];
//                                                                      });
//                                                                  }
//                                                              });
////                                                              self.uploadedCount += 1;
////
////                                                              if (totalCount == self.uploadedCount) {
////                                                                  [self popToFromViewController];
////                                                              }
//                                                          }];
//                                                      }
//                                                  } @finally {
//                                                      self.processing = @NO;
//                                                  }
//                                              });
//                                          }];
//                                    } else {
//                                        self.processing = @NO;
//
//                                        NSString *messagePrefix = NSLocalizedString(@"Error on upload file.", @"");
//
//                                        [self alertToTryUploadAgainWithMessagePrefix:messagePrefix response:responseFromCreate data:dataFromCreate error:errorFromCreate assets:assets fileAbsolutePaths:fileAbsolutePaths directory:directory];
//                                    }
//                                }];
//                            });
//                        }
//                    }];
//                } else if (tryAgainIfFailed && (statusCode == 401 || (error && ([error code] == NSURLErrorUserCancelledAuthentication || [error code] == NSURLErrorSecureConnectionFailed)))) {
//                    self.processing = @YES;
//
//                    [self.authService reloginWithSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
//                        if ([userDefaults objectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID]) {
//                            /* recursively invoked */
//
//                            dispatch_async(globalConcurrentQueue, ^{
//                                [self internalUploadWithAssets:assets fileAbsolutePaths:fileAbsolutePaths directory:directory tryAgainIfFailed:NO];
//                            });
//                        } else {
//                            // server not connected, so request connection
//                            [self requestConnectWithAuthService:self.authService userDefaults:userDefaults assets:assets fileAbsolutePaths:fileAbsolutePaths directory:directory];
//                        }
//                    } failureHandler:^(NSData *ldata, NSURLResponse *lresponse, NSError *lerror) {
//                        self.processing = @NO;
//
//                        NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");
//
//                        [self alertToTryUploadAgainWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror assets:assets fileAbsolutePaths:fileAbsolutePaths directory:directory];
//                    }];
////                    [self.appService authService:self.authService reloginCurrentUserComputerFromViewController:self successHandler:^(NSURLResponse *lresponse, NSData *ldata) {
////                        if ([userDefaults objectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID]) {
////                            /* recursively invoked */
////                            [self internalUploadWithAssets:assets fileAbsolutePaths:fileAbsolutePaths directory:directory];
////                        } else {
////                            // server not connected, so request connection
////                            [self requestConnectWithAuthService:self.authService userDefaults:userDefaults assets:assets fileAbsolutePaths:fileAbsolutePaths directory:directory];
////                        }
////                    } failureHandler:^(NSURLResponse *lresponse, NSData *ldata, NSError *lerror) {
////                        self.processing = @NO;
////
////                        NSString *messagePrefix = NSLocalizedString(@"Login failed.", @"");
////
////                        [self alertToTryUploadAgainWithMessagePrefix:messagePrefix response:lresponse data:ldata error:lerror];
////                    }];
//                } else if (tryAgainIfFailed && statusCode == 503) {
//                    // server not connected, so request connection
//                    [self requestConnectWithAuthService:self.authService userDefaults:userDefaults assets:assets fileAbsolutePaths:fileAbsolutePaths directory:directory];
//                } else {
//                    self.processing = @NO;
//
//                    NSString *messagePrefix = NSLocalizedString(@"Error on upload file.", @"");
//
//                    [self alertToTryUploadAgainWithMessagePrefix:messagePrefix response:response data:data error:error assets:assets fileAbsolutePaths:fileAbsolutePaths directory:directory];
//                }
//            });
//        }];
//    }
//}

// clear selected assets, fileRelPaths and pop to fromViewController
- (void)popToFromViewController {
    // clear selected assets, fileRelPaths and from view controller
    [self.uploadProcessService reset];

    UIViewController *fromViewController = (id) [self.uploadProcessService fromViewController];

    if (fromViewController) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[self navigationController] popToViewController:fromViewController animated:YES];
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[self navigationController] popToRootViewControllerAnimated:YES];
        });
    }
}

// Collect and prompt too-large files for files from file-sharing and PHAsset/ALAsset
// Returns YES if all sizes of files in assets and fileAbsolutePaths are equal to or smaller than fileSizeLimit
- (BOOL)checkUploadFileSizeWithFileSizeLimit:(long long int)fileSizeLimit assets:(NSArray *)assets downloadedFiles:(NSArray<FileTransferWithoutManaged *> *)downloadedFiles {
    // For files with file-sharing, elements of NSNumber with unsigned integer
    NSMutableIndexSet *tooLargeAbsoluteFileIndexSet = [[NSMutableIndexSet alloc] init];
    
    // For PHAsset/ALAsset, elements of NSNumber with unsigned integer
    NSMutableIndexSet *tooLargeAssetIndexSet = [[NSMutableIndexSet alloc] init];
    
    // filenames for both absolute paths and assets that size of larger than limit
    NSMutableArray *tooLargeFilenames = [NSMutableArray array];
    
    // for absolute file paths
    
    NSUInteger fileCount = [downloadedFiles count];
    
    if (fileCount) {
        for (NSUInteger index = 0; index < fileCount; index++) {
            FileTransferWithoutManaged *fileTransferWithoutManaged = downloadedFiles[index];

            NSString *absolutePath = [DirectoryService absoluteFilePathFromLocalPath:fileTransferWithoutManaged.localPath userComputerId:fileTransferWithoutManaged.userComputerId];
            
            NSError *fileSizeError;
            long long int fileSize = [Utility fileSizeWithAbsolutePath:absolutePath error:&fileSizeError];
            
            if (fileSizeError || fileSize > fileSizeLimit) {
                [tooLargeAbsoluteFileIndexSet addIndex:index];
                
                [tooLargeFilenames addObject:[absolutePath lastPathComponent]];
            }
        }
    }
    
    // for assets
    
    NSUInteger assetCount = [assets count];
    
    if (assetCount > 0) {
        // assets is elements of type PHAsset

        for (NSUInteger index = 0; index < assetCount; index++) {
            PHAsset *asset = assets[index];

            [self.directoryService findFileSizeWithPHAsset:asset completionHandler:^(NSUInteger fileSize, NSError *error2) {
                // File with zero size should be allowed to upload

                if (error2 || fileSizeLimit < fileSize) {
                    [tooLargeAssetIndexSet addIndex:index];

                    // Make sure it works under iOS 8 and 9 for [asset valueForKey:@"filename"]
                    [tooLargeFilenames addObject:[asset valueForKey:@"filename"]];
                }
            }];
        }
    }
    
    BOOL canUpload = [tooLargeFilenames count] < 1;
    
    if (!canUpload) {
        self.processing = @NO;
        
        NSString *message = [NSString stringWithFormat:NSLocalizedString(@"exceed.upload.size.limit3", @""), [tooLargeFilenames mutableCopy]];
        
        NSUInteger countTryToUpload = fileCount + assetCount;
        NSUInteger countCanNotUpload = [tooLargeFilenames count];
        
        // Do not ask if upload others when only one selected, or all uploads are too large
        if (countTryToUpload < 2 || countTryToUpload == countCanNotUpload) {
            [Utility viewController:self alertWithMessageTitle:NSLocalizedString(@"File Too Large", @"") messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
        } else {
            [Utility viewController:self alertWithMessageTitle:NSLocalizedString(@"File Too Large", @"") messageBody:message actionTitle:NSLocalizedString(@"Upload other selected files", @"") containsCancelAction:YES delayInSeconds:0 actionHandler:^(UIAlertAction * _Nonnull action) {
                // for files from file-sharing
                
                if (tooLargeAbsoluteFileIndexSet && [tooLargeAbsoluteFileIndexSet count] > 0) {
                    [self.uploadProcessService.downloadedFiles removeObjectsAtIndexes:tooLargeAbsoluteFileIndexSet];
                }
                
                // for assets
                
                if (tooLargeAssetIndexSet && [tooLargeAssetIndexSet count] > 0) {
                    [self.assets removeObjectsAtIndexes:tooLargeAssetIndexSet];
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.tableView reloadData];
                });
                
                dispatch_queue_t gQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
                dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (DELAY_UPLOAD_TIMER_INTERVAL * NSEC_PER_SEC));
                
                dispatch_after(delayTime, gQueue, ^(void) {
                    [self upload:nil];
                });
            }];
        }
    }
    
    return canUpload;
}

- (void)requestConnectWithAuthService:(AuthService *)authService userDefaults:(NSUserDefaults *)userDefaults assets:(NSArray *)assets downloadedFiles:(NSArray<FileTransferWithoutManaged *> *)downloadedFiles directory:(NSString *)directory {
    self.processing = @YES;
    
    [authService requestConnectWithSession:[userDefaults stringForKey:USER_DEFAULTS_KEY_USER_SESSION_ID] successHandler:^(NSURLResponse *rcresponse, NSData *rcdata) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self internalUploadWithAssets:assets downloadedFiles:downloadedFiles directory:directory tryAgainIfFailed:NO];
        });
    } failureHandler:^(NSData *rcdata, NSURLResponse *rcresponse, NSError *rcerror) {
        self.processing = @NO;
        
        [self alertToTryUploadAgainWithMessagePrefix:nil response:rcresponse data:rcdata error:rcerror assets:assets downloadedFiles:downloadedFiles directory:directory];
    }];
}

- (NSString *)sizeOfAllFiles {
    unsigned long long totalSizeInBytes = 0;

    // shared files

    if (self.uploadProcessService.downloadedFiles && [self.uploadProcessService.downloadedFiles count] > 0) {
        // copy from FileUploadProcessService and make them absolute paths

        for (FileTransferWithoutManaged *fileTransferWithoutManaged in self.uploadProcessService.downloadedFiles) {
            NSString *fileAbsolutePath = [DirectoryService absoluteFilePathFromLocalPath:fileTransferWithoutManaged.localPath userComputerId:fileTransferWithoutManaged.userComputerId];

            unsigned long long int size = [Utility fileSizeWithAbsolutePath:fileAbsolutePath error:NULL];

            totalSizeInBytes += size;
        }

//        NSString *devicdSharingFolderPath = [DirectoryService devicdSharingFolderPath];
//
//        for (NSString *fileRelPath in self.uploadProcessService.selectedFileRelPaths) {
//            NSString *fileAbsolutePath = [devicdSharingFolderPath stringByAppendingPathComponent:fileRelPath];
//
//            unsigned long long int size = [Utility fileSizeWithAbsolutePath:fileAbsolutePath error:NULL];
//
//            totalSizeInBytes += size;
//        }
    }

    // PHAssets

    if (self.assets && [self.assets count] > 0) {
        for (PHAsset *phAsset in self.assets) {
            unsigned long long int size = [self assetSizeWithAsset:phAsset];

            totalSizeInBytes += size;
        }
    }

    return totalSizeInBytes > 0 ? [Utility byteCountToDisplaySize:totalSizeInBytes] : @"0";
}

- (unsigned long long int)assetSizeWithAsset:(PHAsset *)phAsset {
    __block NSNumber *fileSize;

    // Diff slow motion video from normal video, ref:
    // (1) http://stackoverflow.com/questions/26549938/how-can-i-determine-file-size-on-disk-of-a-video-phasset-in-ios8
    // (2) https://overflow.buffer.com/2016/02/29/slow-motion-video-ios/

    PHAssetMediaType phAssetMediaType = phAsset.mediaType;

    // For Slow-Mo video, phAsset.mediaSubtypes == PHAssetMediaSubtypeVideoHighFrameRate

    if (phAssetMediaType == PHAssetMediaTypeVideo || phAssetMediaType == PHAssetMediaTypeAudio) {

        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

        PHVideoRequestOptions *videoRequestOptions = [[PHVideoRequestOptions alloc] init];
        videoRequestOptions.networkAccessAllowed = YES;

        // Use AVURLAsset, instead of AVComposition to prevent re-calculate size every time the table reloaded.
        // It's a different choice from exporting the asset as a file before uploading it.
        videoRequestOptions.version = PHVideoRequestOptionsVersionOriginal; // the type of the slow-mo video is AVURAsset

        [[PHImageManager defaultManager] requestAVAssetForVideo:phAsset options:videoRequestOptions resultHandler:^(AVAsset *avAsset, AVAudioMix *audioMix, NSDictionary *info) {
            if ([avAsset isKindOfClass:[AVURLAsset class]]) {
                AVURLAsset *avurlAsset = (AVURLAsset *) avAsset;

                NSNumber *size;

                [avurlAsset.URL getResourceValue:&size forKey:NSURLFileSizeKey error:NULL];

                fileSize = size;
            }

            dispatch_semaphore_signal(semaphore);
        }];

        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    } else {
        // options that do not crop image to square
        PHImageRequestOptions *originalImageDataOptions = [[PHImageRequestOptions alloc] init];
        originalImageDataOptions.resizeMode = PHImageRequestOptionsResizeModeExact;
        originalImageDataOptions.synchronous = YES;
        originalImageDataOptions.networkAccessAllowed = YES;

        [[PHImageManager defaultManager] requestImageDataForAsset:phAsset options:originalImageDataOptions resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
            NSError *requestError = info[PHImageErrorKey];

            if (!requestError) {
                fileSize = @(imageData.length);
            }
        }];
    }

    return fileSize ? [fileSize unsignedLongLongValue] : 0;
}

- (void)alertToTryUploadAgainWithMessagePrefix:(NSString *)messagePrefix response:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error assets:(NSArray *)assets downloadedFiles:(NSArray <FileTransferWithoutManaged *> *)downloadedFiles directory:(NSString *)directory {
    UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try Upload Again", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self internalUploadWithAssets:assets downloadedFiles:downloadedFiles directory:directory tryAgainIfFailed:YES];
        });
    }];

    [self.authService processCommonRequestFailuresWithMessagePrefix:messagePrefix response:response data:data error:error tryAgainAction:tryAgainAction inViewController:self reloginSuccessHandler:^(NSURLResponse *loginResponse, NSData *loginData) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self internalUploadWithAssets:assets downloadedFiles:downloadedFiles directory:directory tryAgainIfFailed:NO];
        });
    }];
}

- (void)onEnterCustomizedSubdirectoryName:(NSString *)subdirectoryName subdirectoryType:(NSNumber *_Nonnull)subdirectoryType {
    if (!subdirectoryName || [subdirectoryName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length < 1) {
        // empty
        
        [Utility viewController:self alertWithMessageTitle:@"" messageBody:NSLocalizedString(@"Empty subdirectory name", @"") actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
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
            // Change to selected type with customized value

            NSString *customizedNameTrimmed = [subdirectoryName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

            if (!self.uploadSubdirectoryService.type || ![self.uploadSubdirectoryService.type isEqualToNumber:subdirectoryType]) {
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
