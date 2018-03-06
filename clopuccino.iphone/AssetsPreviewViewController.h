#import <UIKit/UIKit.h>

@interface AssetsPreviewViewController : UIViewController <StatusBarHiddableViewController, PHPhotoLibraryChangeObserver>

@property(nonatomic, weak) IBOutlet UIImageView *previewImageView;

// DO NOT deal with files from file-sharing here, use QLPreviewController instead.

// for iOS 8 or later, type of PHAsset
@property(nonatomic, strong) id asset;

@end
