#import "AssetsLibraryViewController.h"
#import "AssetsCollectionViewController.h"
#import "ChooseSharingFileViewController.h"
#import "UIButton+UploadBadgeBarButton.h"
#import "FileUploadProcessService.h"
#import "FilelugUtility.h"
#import "AppDelegate.h"
#import "ChooseDownloadedFileViewController.h"

@interface AssetsLibraryViewController ()

// iOS 8 or later --> Elements of type AssetCollectionModel for albums, smart albums, and all-photos.
@property(nonatomic, strong) NSMutableArray *groups;

@property(nonatomic, strong) UIButton *uploadBadgeBarButton;

@property(nonatomic, strong) BBBadgeBarButtonItem *doneButtonItem;

// iOS 8 or later
@property(nonatomic, assign) CGSize imageResizedSize;

@property(nonatomic, strong) FileUploadProcessService *uploadProcessService;

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

@property(nonatomic) BOOL registeredPhotoChangeObserver;

@end

@implementation AssetsLibraryViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.registeredPhotoChangeObserver = NO;

    [Utility viewController:self useNavigationLargeTitles:YES];

    _uploadProcessService = [[FilelugUtility applicationDelegate] fileUploadProcessService];

    _preferredContentSizeCategoryService = [[PreferredContentSizeCategoryService alloc] init];
    
    // upload badge

    _uploadBadgeBarButton = [UIButton uploadBadgeBarButton];

    BBBadgeBarButtonItem *badgeBarButtonItem = [[BBBadgeBarButtonItem alloc] initWithUploadBadgeBarButton:_uploadBadgeBarButton];

    self.doneButtonItem = badgeBarButtonItem;
    
    self.navigationItem.rightBarButtonItem = self.doneButtonItem;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // Fills self.groups by AssetCollectionModel or AssetGroupModel
    [self prepareAssetGroups];

    // update badge

    [self.uploadProcessService updateBadgeBarButtonItem:self.doneButtonItem];

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

    [self.uploadBadgeBarButton addTarget:self action:@selector(doneSelection:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (![self isMovingToParentViewController]) {
        // reload table when back from other view controller,
        // for example, file may be removed from upload list in FileUploadSummaryViewController
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    if (_groups) {
        [_groups removeAllObjects];
    }

    // removing observers

    [self.uploadBadgeBarButton removeTarget:self action:@selector(doneSelection:) forControlEvents:UIControlEventTouchUpInside];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];
    
    if (self.registeredPhotoChangeObserver) {
        [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];

        self.registeredPhotoChangeObserver = NO;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)didChangePreferredContentSize:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (void)photoLibraryDidChange:(PHChange *)changeInstance {
    // Fills self.groups by AssetCollectionModel or AssetGroupModel
    [self prepareAssetGroups];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (void)doneSelection:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.uploadProcessService pushToUploadSummaryViewControllerFromViewController:self];
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *title;
    
    if (section == 0) {
        title = NSLocalizedString(@"Photos and Videos", @"");
    } else if (section == 1) {
        title = NSLocalizedString(@"Others", @"");
    }
    
    return title;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? [self.groups count] : 1;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return TABLE_VIEW_CELL_ROW_HEIGHT_FOR_MEDIUM_CONTENT_SIZE_CATEGORY;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat height;

    if ([self.preferredContentSizeCategoryService isXXLargeContentSizeCategory]) {
        height = TABLE_VIEW_CELL_ROW_HEIGHT_FOR_XX_LARGE_CONTENT_SIZE_CATEGORY;
    } else if ([self.preferredContentSizeCategoryService isLargeContentSizeCategory]) {
        height = TABLE_VIEW_CELL_ROW_HEIGHT_FOR_LARGE_CONTENT_SIZE_CATEGORY;
    } else if ([self.preferredContentSizeCategoryService isMediumContentSizeCategory]) {
        height = TABLE_VIEW_CELL_ROW_HEIGHT_FOR_MEDIUM_CONTENT_SIZE_CATEGORY;
    } else {
        height = TABLE_VIEW_CELL_ROW_HEIGHT_FOR_SMALL_CONTENT_SIZE_CATEGORY;
    }

    return height;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"AssetsLibraryCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];

    // configure the preferred font

    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    cell.textLabel.textColor = [UIColor darkTextColor];
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.adjustsFontSizeToFitWidth = NO;
    cell.textLabel.lineBreakMode = NSLineBreakByCharWrapping;
    cell.textLabel.textAlignment = NSTextAlignmentNatural;

    cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    cell.detailTextLabel.textColor = [UIColor lightGrayColor];
    cell.detailTextLabel.numberOfLines = 1;
    cell.detailTextLabel.adjustsFontSizeToFitWidth = NO;
    cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    cell.detailTextLabel.textAlignment = NSTextAlignmentNatural;

    NSInteger section = indexPath.section;
    
    if (section == 0) {
        AssetCollectionModel *assetCollectionModel = self.groups[(NSUInteger) indexPath.row];

        cell.textLabel.text = assetCollectionModel.title;

        cell.detailTextLabel.text = [@(assetCollectionModel.count) stringValue];

        UIImage *thumbnail = assetCollectionModel.thumbnail;

        if (!thumbnail) {
            thumbnail = [UIImage imageNamed:@"ic_folder"];
        }

        cell.imageView.image = thumbnail;

        cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
    } else if (section == 1) {
        cell.imageView.image = [UIImage imageNamed:@"folder"];
        
        cell.textLabel.text = NSLocalizedString(@"Downloaded Files", @"");
        
        cell.detailTextLabel.text = @"";
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if ([self.groups count] > (NSUInteger) indexPath.row) {
            AssetsCollectionViewController *viewController = [Utility instantiateViewControllerWithIdentifier:@"AssetsCollection"];

            viewController.assetsGroup = self.groups[(NSUInteger) indexPath.row];

            [self.navigationController pushViewController:viewController animated:YES];
        }
    } else {
        ChooseDownloadedFileViewController *viewController = [Utility instantiateViewControllerWithIdentifier:@"ChooseDownloadedFile"];

        [self.navigationController pushViewController:viewController animated:YES];
    }
}

- (void)prepareAssetGroups {
    if (!self.groups) {
        _groups = [[NSMutableArray alloc] init];
    } else {
        [self.groups removeAllObjects];
    }

    PHAuthorizationStatus photoAuthorizationStatus = [PHPhotoLibrary authorizationStatus];

    if (photoAuthorizationStatus == PHAuthorizationStatusAuthorized) {
        // Use PHAssetCollection for iOS 8 or later

        _imageResizedSize = [Utility thumbnailSizeForUploadFileTableViewCellImage];

        PHFetchOptions *smartAlbumOptions = [[PHFetchOptions alloc] init];
        smartAlbumOptions.includeAllBurstAssets = YES;
        smartAlbumOptions.includeHiddenAssets = YES;
        smartAlbumOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"localizedTitle" ascending:YES]];

        // Smart Albums

        PHFetchResult *smartAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeAlbumRegular options:smartAlbumOptions];

        [smartAlbums enumerateObjectsUsingBlock:^(PHAssetCollection *collection, NSUInteger idx, BOOL *stop) {
            // DEBUG
//            NSLog(@"[Smart Album]%@ estimated asset count: %u", [collection localizedTitle], [collection estimatedAssetCount]);

            if (![collection.localizedTitle isEqualToString:NSLocalizedString(@"Smart Album Recently Deleted", @"")]) {
                AssetCollectionModel *assetCollectionModel = [self assetCollectionModelFromCollection:collection];

                if (assetCollectionModel) {
                    [self.groups addObject:assetCollectionModel];
                }
            }
        }];

        // Albums and user libraries

        PHFetchOptions *albumOptions = [[PHFetchOptions alloc] init];

        albumOptions.includeAllBurstAssets = YES;
        albumOptions.includeHiddenAssets = YES;
        albumOptions.includeAssetSourceTypes = PHAssetSourceTypeCloudShared | PHAssetSourceTypeUserLibrary | PHAssetSourceTypeiTunesSynced;

        albumOptions.predicate = [NSPredicate predicateWithFormat:@"estimatedAssetCount > 0"];
        albumOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"localizedTitle" ascending:YES]];

        PHFetchResult *albums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAlbumRegular options:albumOptions];

        [albums enumerateObjectsUsingBlock:^(PHAssetCollection *collection, NSUInteger idx, BOOL *stop) {
            // DEBUG
//            NSLog(@"[Album]%@ estimated asset count: %u", [collection localizedTitle], [collection estimatedAssetCount]);

            AssetCollectionModel *assetCollectionModel = [self assetCollectionModelFromCollection:collection];

            if (assetCollectionModel) {
                [self.groups addObject:assetCollectionModel];
            }
        }];

        // All photos - PHFetchResult contains PHAsset, instead of PHAssetCollection

        PHFetchOptions *allPhotosOptions = [[PHFetchOptions alloc] init];

        allPhotosOptions.includeAssetSourceTypes = PHAssetSourceTypeCloudShared | PHAssetSourceTypeUserLibrary | PHAssetSourceTypeiTunesSynced;

        // Show the latest asset first, so the thumbnail comes from the latest asset.
        allPhotosOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];

        PHFetchResult *assetFetchResult = [PHAsset fetchAssetsWithOptions:allPhotosOptions];

        NSUInteger count = [assetFetchResult count];

        if (count > 0) {
            PHAsset *asset = [assetFetchResult firstObject];

            __block UIImage *thumbnail;

            if (asset) {
                [Utility requestAssetThumbnailWithAsset:asset resizedToSize:_imageResizedSize resultHandler:^(UIImage *result) {
                    thumbnail = result;
                }];
            }

            AssetCollectionModel *assetCollectionModel = [[AssetCollectionModel alloc] initWithTitle:NSLocalizedString(@"Alblum_All Photos", @"") count:count thumbnail:thumbnail collection:nil];

            [self.groups addObject:assetCollectionModel];
        }
    }
}

- (AssetCollectionModel *_Nullable)assetCollectionModelFromCollection:(PHAssetCollection *__nonnull)collection {
    AssetCollectionModel *assetCollectionModel;
    
    PHFetchOptions *fetchOptions = [[PHFetchOptions alloc] init];
    fetchOptions.sortDescriptors = @[
                                     // Show the latest asset first, so the thumbnail comes from the latest asset.
                                     [NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]
                                     ];
    
    PHFetchResult *assetFetchResult = [PHAsset fetchAssetsInAssetCollection:collection options:fetchOptions];
    
    NSUInteger count = [assetFetchResult count];
    
    if (count > 0) {
        PHAsset *asset = [assetFetchResult firstObject];
        
        __block UIImage *thumbnail;
        
        if (asset) {
            [Utility requestAssetThumbnailWithAsset:asset resizedToSize:_imageResizedSize resultHandler:^(UIImage *result) {
                thumbnail = result;
            }];
        } else {
            thumbnail = [UIImage imageNamed:@"album"];
        }
        
        assetCollectionModel = [[AssetCollectionModel alloc] initWithTitle:[collection localizedTitle] count:count thumbnail:thumbnail collection:collection];
    }
    
    return assetCollectionModel;
}

@end
