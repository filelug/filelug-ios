#import "AssetsCollectionViewController.h"
#import "UIButton+UploadBadgeBarButton.h"
#import "FileUploadProcessService.h"
#import "FilelugUtility.h"
#import "AppDelegate.h"

#define kImageViewTag 1
#define kVideoIconTag 2
#define kVideoDurationTag 3
#define kCheckedTag 4
#define kAlphaLayerTag 5

@interface AssetsCollectionViewController () {
    
}

@property(nonatomic, strong) UIButton *uploadBadgeBarButton;

@property(nonatomic, strong) BBBadgeBarButtonItem *doneButtonItem;

@property(nonatomic, assign) NSUInteger width;

@property(nonatomic, assign) NSUInteger height;

// for iOS 8 or later --> elements of PHAsset
@property(nonatomic, strong) NSMutableArray *assets;

// iOS 8 or later
@property(nonatomic, assign) CGSize imageResizedSize;

// iOS 8 or later
@property(nonatomic, strong) PHCachingImageManager *cachingImageManager;

@property(nonatomic, strong) FileUploadProcessService *uploadProcessService;

@property(nonatomic) BOOL registeredPhotoChangeObserver;

@end

@implementation AssetsCollectionViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.registeredPhotoChangeObserver = NO;

    [Utility viewController:self useNavigationLargeTitles:YES];

    _uploadProcessService = [[FilelugUtility applicationDelegate] fileUploadProcessService];

    _cachingImageManager = [[PHCachingImageManager alloc] init];

    CGFloat scale = [[UIScreen mainScreen] scale];

    CGRect screenBounds = [[UIScreen mainScreen] bounds];

    // each row contains 4 columns at least
    int columnCountPerRowAtLeast = 4;
    
    _imageResizedSize = CGSizeMake(screenBounds.size.width * scale / columnCountPerRowAtLeast, screenBounds.size.height * scale / columnCountPerRowAtLeast);
    
    AssetCollectionModel *__nonnull assetCollectionModel = (AssetCollectionModel *) _assetsGroup;

    [self navigationItem].title = assetCollectionModel.title;

    _uploadBadgeBarButton = [UIButton uploadBadgeBarButton];

    BBBadgeBarButtonItem *badgeBarButtonItem = [[BBBadgeBarButtonItem alloc] initWithUploadBadgeBarButton:_uploadBadgeBarButton];

    self.doneButtonItem = badgeBarButtonItem;
    
    self.navigationItem.rightBarButtonItem = self.doneButtonItem;
    
    [self prepareScreenSize];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self prepareAssetsAndCacheImagesWithAssetCollectionModel:(AssetCollectionModel *) self.assetsGroup];

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

    [self.uploadBadgeBarButton addTarget:self action:@selector(doneSelection:) forControlEvents:UIControlEventTouchUpInside];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRotate:) name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if ([self isMovingToParentViewController]) {
        // scroll to the last only when NOT back from view controller

        NSInteger item = [self collectionView:self.collectionView numberOfItemsInSection:0] - 1;

        if (item > -1) {
            NSIndexPath *lastIndexPath = [NSIndexPath indexPathForItem:item inSection:0];

            [self.collectionView scrollToItemAtIndexPath:lastIndexPath atScrollPosition:UICollectionViewScrollPositionBottom animated:NO];
        }
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.collectionView reloadData];
    });
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    // removing observers

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];

    [self.uploadBadgeBarButton removeTarget:self action:@selector(doneSelection:) forControlEvents:UIControlEventTouchUpInside];

    if (self.registeredPhotoChangeObserver) {
        [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];

        self.registeredPhotoChangeObserver = NO;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
    if (_assets) {
        [_assets removeAllObjects];
    }
}

- (void)prepareAssetsAndCacheImagesWithAssetCollectionModel:(AssetCollectionModel *)assetCollectionModel {
    NSMutableArray *assets = [NSMutableArray array];

    if (assetCollectionModel) {
        PHAssetCollection *collection = assetCollectionModel.collection;

        if (collection) {
            // make sure the PHAssetCollection exists

            PHFetchOptions *fetchOptions = [[PHFetchOptions alloc] init];
            fetchOptions.sortDescriptors = @[
                    // Show the oldest asset first
                    [NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:YES]
            ];

            PHFetchResult *assetFetchResult = [PHAsset fetchAssetsInAssetCollection:collection options:fetchOptions];

            [assetFetchResult enumerateObjectsUsingBlock:^(PHAsset *asset, NSUInteger idx, BOOL *stop) {
                [assets addObject:asset];

                PHImageRequestOptions *options = [Utility imageRequestOptionsWithAsset:asset];

                // start caching image
                [self.cachingImageManager startCachingImagesForAssets:@[asset] targetSize:_imageResizedSize contentMode:PHImageContentModeAspectFit options:options];
            }];
        } else {
            // all-photos

            PHFetchOptions *allPhotosOptions = [[PHFetchOptions alloc] init];

            if ([Utility isDeviceVersion9OrLater]) {
                allPhotosOptions.includeAssetSourceTypes = PHAssetSourceTypeCloudShared | PHAssetSourceTypeUserLibrary | PHAssetSourceTypeiTunesSynced;
            }

            // Show the oldest asset first
            allPhotosOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:YES]];

            PHFetchResult *assetFetchResult = [PHAsset fetchAssetsWithOptions:allPhotosOptions];

            [assetFetchResult enumerateObjectsUsingBlock:^(PHAsset *asset, NSUInteger idx, BOOL *stop) {
                [assets addObject:asset];

                PHImageRequestOptions *options = [Utility imageRequestOptionsWithAsset:asset];

                // start caching image
                [self.cachingImageManager startCachingImagesForAssets:@[asset] targetSize:_imageResizedSize contentMode:PHImageContentModeAspectFit options:options];
            }];
        }
    }
    
    self.assets = assets;
}

- (void)didRotate:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self prepareScreenSize];
        
        [self.collectionView reloadData];
    });
}

- (void)prepareScreenSize {
    CGSize screenSize = [[UIScreen mainScreen] bounds].size;
    _width = (NSUInteger) screenSize.width;
    _height = (NSUInteger) screenSize.height;
}

- (void)photoLibraryDidChange:(PHChange *)changeInstance {
    BOOL needGoBack = NO;

    AssetCollectionModel *assetCollectionModel = (AssetCollectionModel *) self.assetsGroup;

    if (!assetCollectionModel) {
        needGoBack = YES;
    } else {
        PHAssetCollection *collection = assetCollectionModel.collection;

        if (!collection) {
            needGoBack = YES;
        } else {
            NSString *localIdentifier = collection.localIdentifier;

            if (!localIdentifier) {
                needGoBack = YES;
            } else {
                PHFetchResult<PHAssetCollection *> *fetchResult = [PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:@[localIdentifier] options:nil];

                if ([fetchResult count] < 1) {
                    needGoBack = YES;
                } else {
                    [self prepareAssetsAndCacheImagesWithAssetCollectionModel:(AssetCollectionModel *) self.assetsGroup];

                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.collectionView reloadData];
                    });
                }
            }
        }
    }

    if (needGoBack) {
        // delay 1.0 sec to make sure the view is displayed.

        double delayInSeconds = 1.0;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
            [self.navigationController popViewControllerAnimated:YES];
        });
    }
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    // calculate cell size by device screen bounds
    /*
     iPhone 4,4S	: 320 x 480
     iPhone 5,5S : 320 x 568
     iPhone 6 : 375 x 667
     iPhone 6+ : 414 x 736
     All types of iPads  : 768 x 1024
     */
    
    int columns;
    int screenWidth = (int) self.width;
    int screenHeight = (int) self.height;
    
    if (screenWidth > 700 && screenWidth < screenHeight) {
        columns = 5;
    } else {
        if (screenWidth > 500) {
            columns = 7;
        } else if (screenWidth > 420) {
            columns = 6;
        } else {
            columns = 4;
        }
    }
    
    int cellWidth = screenWidth / columns;
    
    return CGSizeMake(cellWidth, cellWidth);
}

#pragma mark - UICollectionViewDelegate

- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section {
    return [self.assets count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"AssetsCollectionCell";
    
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:CellIdentifier forIndexPath:indexPath];
    
    BOOL isVideo = NO;
    
    BOOL alreadyChecked = NO;
    
    // nil if not a video
    NSNumber *duration;

    PHAsset *asset = self.assets[(NSUInteger) indexPath.row];

    PHImageRequestOptions *requestOptions = [Utility imageRequestOptionsWithAsset:asset];

    [self.cachingImageManager requestImageForAsset:asset
                                        targetSize:self.imageResizedSize
                                       contentMode:PHImageContentModeAspectFit
                                           options:requestOptions
                                     resultHandler:^(UIImage *result, NSDictionary *info) {
         ((UIImageView *) [cell viewWithTag:kImageViewTag]).image = result;
     }];

    alreadyChecked = [self.uploadProcessService.selectedAssetIdentifiers containsObject:asset.localIdentifier];

    PHAssetMediaType assetMediaType = asset.mediaType;

    isVideo = (assetMediaType == PHAssetMediaTypeVideo);

    if (isVideo) {
        duration = @(asset.duration);
    }
    
    UIImageView *videoIconImageView = (UIImageView *) [cell viewWithTag:kVideoIconTag];
    UILabel *videoDurationLabel = (UILabel *) [cell viewWithTag:kVideoDurationTag];
    UIImageView *checkedImageView = (UIImageView *) [cell viewWithTag:kCheckedTag];
    UIView *alphaLayerView = [cell viewWithTag:kAlphaLayerTag];
    
    if (isVideo) {
        [videoIconImageView setHidden:NO];
        [alphaLayerView setHidden:NO];
        
        if (alreadyChecked) {
            [checkedImageView setHidden:NO];
            [videoDurationLabel setHidden:YES];
            
        } else {
            [checkedImageView setHidden:YES];
            [videoDurationLabel setHidden:NO];
            
            int minutes = [duration intValue] / 60;
            int seconds = [duration intValue] % 60;
            NSString *durationString = [NSString stringWithFormat:@"%d:%d", minutes, seconds];
            [videoDurationLabel setText:durationString];
        }
    } else {
        [videoIconImageView setHidden:YES];
        [videoDurationLabel setHidden:YES];
        
        [checkedImageView setHidden:!alreadyChecked];
        [alphaLayerView setHidden:!alreadyChecked];
    }
    
    return cell;
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSString *assetIdentifier;

    PHAsset *asset = self.assets[(NSUInteger) indexPath.row];

    assetIdentifier = asset.localIdentifier;
    
    if (assetIdentifier) {
        if ([self.uploadProcessService.selectedAssetIdentifiers containsObject:assetIdentifier]) {
            [self.uploadProcessService.selectedAssetIdentifiers removeObject:assetIdentifier];
            
            // deselect -- hide checked circle and show video duration label
            
            UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
            
            if (cell) {
                UIImageView *checkedImageView = (UIImageView *) [cell viewWithTag:kCheckedTag];
                
                UIImageView *videoIconImageView = (UIImageView *) [cell viewWithTag:kVideoIconTag];
                
                UIView *alphaLayerView = [cell viewWithTag:kAlphaLayerTag];
                
                UILabel *videoDurationLabel = (UILabel *) [cell viewWithTag:kVideoDurationTag];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    [checkedImageView setHidden:YES];
                    
                    [alphaLayerView setHidden:[videoIconImageView isHidden]];
                    
                    [videoDurationLabel setHidden:[videoIconImageView isHidden]];
                    
                    // update badge
                    
                    [self.uploadProcessService updateBadgeBarButtonItem:self.doneButtonItem];
                });
            }
        } else {
            [self.uploadProcessService.selectedAssetIdentifiers addObject:assetIdentifier];
            
            // select -- hide video duration label and show ckecked circle
            
            UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
            
            if (cell) {
                UIImageView *checkedImageView = (UIImageView *) [cell viewWithTag:kCheckedTag];
                
                UIView *alphaLayerView = [cell viewWithTag:kAlphaLayerTag];
                
                UILabel *videoDurationLabel = (UILabel *) [cell viewWithTag:kVideoDurationTag];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [checkedImageView setHidden:NO];
                    
                    [alphaLayerView setHidden:NO];
                    
                    [videoDurationLabel setHidden:YES];
                    
                    // update badge
                    
                    [self.uploadProcessService updateBadgeBarButtonItem:self.doneButtonItem];
                });
            }
        }
        
        return YES;
    } else {
        // asset identifier/url not found and can not allow to select
        
        return NO;
    }
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
}

- (void)doneSelection:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.uploadProcessService pushToUploadSummaryViewControllerFromViewController:self];
    });
}

@end
