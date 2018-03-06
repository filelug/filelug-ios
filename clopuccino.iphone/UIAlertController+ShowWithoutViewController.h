#import <UIKit/UIKit.h>

@interface UIAlertController (ShowWithoutViewController)

// To present without view controller
- (void)presentWithAnimated:(BOOL)animated;

// To present without view controller
- (void)presentWithAnimated:(BOOL)animated completion:(void (^ _Nullable)(void))completion;

// To present with specified view controller
// For preferredStyle of UIAlertControllerStyleActionSheet, either sourceView (with sourceRect) or barButtonItem must not nil.
// For preferredStyle of UIAlertControllerStyleAlert, set nil to sourceView and barButtonItem and set CGRectNull to sourceRect.
- (void)presentWithViewController:(__kindof UIViewController *_Nonnull)viewController sourceView:(UIView *_Nullable)sourceView sourceRect:(CGRect)sourceRect barButtonItem:(UIBarButtonItem *_Nullable)barButtonItem animated:(BOOL)animated completion:(void (^ _Nullable)(void))completion;

@end
