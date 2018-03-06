#import <UIKit/UIKit.h>
#import <QuickLook/QuickLook.h>

@protocol FilePreviewControllerDelegate;

@interface FilePreviewController : NSObject <QLPreviewItem, QLPreviewControllerDataSource>

@property(nonnull, nonatomic, strong) NSString *fileAbsolutePath;

@property(nonnull, nonatomic, strong) UIViewController *fromViewController;

@property(nonnull, nonatomic, strong) id<FilePreviewControllerDelegate> delegate;

- (void)preview;

#pragma mark - QLPreviewItem

@property(nonnull, nonatomic) NSURL *previewItemURL;

@property(nullable, nonatomic) NSString *previewItemTitle;

@end