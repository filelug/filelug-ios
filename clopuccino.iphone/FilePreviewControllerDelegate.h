#import <Foundation/Foundation.h>
#import <QuickLook/QuickLook.h>

@protocol FilePreviewControllerDelegate <NSObject>

@required

@property(nullable, nonatomic, strong) QLPreviewController *previewController;

@end
