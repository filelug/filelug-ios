#import <UIKit/UIKit.h>

@interface AssetsCollectionViewController : UICollectionViewController <UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, PHPhotoLibraryChangeObserver>

// iOS 8 or later --> type AssetCollectionModel for albums, smart albums, and all-photos.
@property(nonatomic, strong) id assetsGroup;

@end
