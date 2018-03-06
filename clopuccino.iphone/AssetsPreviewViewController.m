#import "AssetsPreviewViewController.h"

@interface AssetsPreviewViewController ()

@property(nonatomic, strong) AVPlayer *player;

@property(nonatomic, strong) AVPlayerItem *playerItem;

@property(nonatomic, strong) UIBarButtonItem *playBarButtonItem;

@property(nonatomic, strong) UIBarButtonItem *pauseBarButtonItem;

@property(nonatomic) BOOL registeredPhotoChangeObserver;

@end

@implementation AssetsPreviewViewController

// Explicitly synthesize the property declared in protocol.
// Auto property synthesis will not synthesize property declared in protocol.
@synthesize shouldStatusBarHidden;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.shouldStatusBarHidden = NO;

    self.registeredPhotoChangeObserver = NO;

    [Utility viewController:self useNavigationLargeTitles:NO];

    if (self.asset) {
        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleNavigationBar:)];
        tapGestureRecognizer.numberOfTapsRequired = 1;
        tapGestureRecognizer.numberOfTouchesRequired = 1;
        [self.previewImageView addGestureRecognizer:tapGestureRecognizer];
        
        _playBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay target:self action:@selector(play:)];
        
        _pauseBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPause target:self action:@selector(pause:)];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // adding observers

    if (!self.registeredPhotoChangeObserver) {
        PHAuthorizationStatus authorizationStatus = [PHPhotoLibrary authorizationStatus];

        if (authorizationStatus == PHAuthorizationStatusAuthorized) {
            [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];

            self.registeredPhotoChangeObserver = YES;
        }
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self prepareAssetToPreview];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    if (_playerItem) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:self.playerItem];

        [_playerItem removeObserver:self forKeyPath:@"status" context:NULL];
    }

    if (self.registeredPhotoChangeObserver) {
        [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];

        self.registeredPhotoChangeObserver = NO;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)toggleNavigationBar:(UITapGestureRecognizer *)tapGestureRecognizer {
    self.shouldStatusBarHidden = !self.shouldStatusBarHidden;
    [self setNeedsStatusBarAppearanceUpdate];

    [self.navigationController setNavigationBarHidden:![self.navigationController isNavigationBarHidden] animated:YES];
}

- (void)photoLibraryDidChange:(PHChange *)changeInstance {
    [self prepareAssetToPreview];
}

- (void)promptAssetNotFound {
    [Utility viewController:self alertWithMessageTitle:@"" messageBody:NSLocalizedString(@"Can't preview this file.", @"") actionTitle:NSLocalizedString(@"Back", @"") delayInSeconds:0 actionHandler:^(UIAlertAction *action) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[self navigationController] popViewControllerAnimated:YES];
        });
    }];
}

- (void)prepareAssetToPreview {
    if (!self.asset) {
        [self promptAssetNotFound];
    } else if ([self.asset isKindOfClass:[PHAsset class]]) {
        // asset is type of PHAsset
        
        PHAsset *phAsset = (PHAsset *) self.asset;

        NSString *localIdentifier = phAsset.localIdentifier;

        if (localIdentifier) {
            PHFetchResult<PHAsset *> *fetchResults = [PHAsset fetchAssetsWithLocalIdentifiers:@[localIdentifier] options:nil];

            if (fetchResults && [fetchResults count] > 0) {
                if (phAsset.mediaType == PHAssetMediaTypeVideo) {
                    // prepare for video play

                    PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
                    options.version = PHVideoRequestOptionsVersionCurrent;
                    options.networkAccessAllowed = YES;
                    options.deliveryMode = PHVideoRequestOptionsDeliveryModeAutomatic;

                    [[PHImageManager defaultManager] requestPlayerItemForVideo:phAsset options:options resultHandler:^(AVPlayerItem *playerItem, NSDictionary *info) {
                        self.playerItem = playerItem;

                        [self.playerItem addObserver:self forKeyPath:@"status" options:0 context:NULL];

                        self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
                        self.player.actionAtItemEnd = AVPlayerActionAtItemEndNone;

                        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidReachEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.playerItem];

                        dispatch_async(dispatch_get_main_queue(), ^{
                            [(VideoPlayerView *) self.view setPlayer:self.player];

                            [self syncPlayerWithUI];
                        });
                    }];
                } else {
                    // prepare for image play

                    // target size
                    CGRect rect = [[UIScreen mainScreen] bounds];

                    CGFloat scale = [[UIScreen mainScreen] scale];

                    CGSize targetSize = CGSizeMake(rect.size.width * scale, rect.size.height * scale);

                    // request options
                    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];

                    options.resizeMode = PHImageRequestOptionsResizeModeExact;
                    options.synchronous = YES;
                    options.networkAccessAllowed = YES;

                    [[PHImageManager defaultManager] requestImageForAsset:phAsset targetSize:targetSize contentMode:PHImageContentModeAspectFit options:options resultHandler:^(UIImage *result, NSDictionary *info) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.previewImageView setImage:result];

                            [self syncPlayerWithUI];
                        });
                    }];
                }
            } else {
                [self promptAssetNotFound];
            }
        } else {
            [self promptAssetNotFound];
        }
    }
}

#pragma mark - NSKeyValueObserving

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"status"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self syncPlayerWithUI];
        });
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

// The method must be invoked under main queue
- (void)syncPlayerWithUI {
    if (_player.currentItem && [_player.currentItem status] == AVPlayerItemStatusReadyToPlay) {
        if (![self.navigationItem rightBarButtonItem]) {
            [self.navigationItem setRightBarButtonItem:_playBarButtonItem animated:YES];
        }
    } else {
        [self.navigationItem setRightBarButtonItem:nil animated:YES];
    }
}
//- (void)syncPlayerWithUI {
//    if (_player.currentItem && [_player.currentItem status] == AVPlayerItemStatusReadyToPlay) {
//        if (![self.navigationItem rightBarButtonItem]) {
//            dispatch_async(dispatch_get_main_queue(), ^{
//                [self.navigationItem setRightBarButtonItem:_playBarButtonItem animated:YES];
//            });
//        }
//    } else {
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [self.navigationItem setRightBarButtonItem:nil animated:YES];
//        });
//    }
//}

- (void)play:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.player play];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.navigationItem setRightBarButtonItem:_pauseBarButtonItem animated:YES];
        });
    });
}


- (void)pause:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.player pause];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.navigationItem setRightBarButtonItem:_playBarButtonItem animated:YES];
        });
    });
}

- (BOOL)prefersStatusBarHidden {
    return self.shouldStatusBarHidden;
}

- (void)playerItemDidReachEnd:(NSNotification *)notification {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.navigationItem setRightBarButtonItem:self.playBarButtonItem animated:YES];
        });
        
        if (self.shouldStatusBarHidden) {
            self.shouldStatusBarHidden = NO;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setNeedsStatusBarAppearanceUpdate];
            });
        }
        
        if ([self.navigationController isNavigationBarHidden]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.navigationController setNavigationBarHidden:NO animated:YES];
            });
        }
        
        [self.player pause];
        [self.player seekToTime:kCMTimeZero];
    });
}
@end
