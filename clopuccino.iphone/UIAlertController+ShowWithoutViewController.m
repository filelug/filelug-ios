#import "UIAlertController+ShowWithoutViewController.h"
#import <objc/runtime.h>

@interface UIAlertController (Private)

@property (nonatomic, strong) UIWindow *alertWindow;

@end

@implementation UIAlertController (Private)

@dynamic alertWindow;

- (void)setAlertWindow:(UIWindow *)alertWindow {
    objc_setAssociatedObject(self, @selector(alertWindow), alertWindow, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIWindow *)alertWindow {
    return objc_getAssociatedObject(self, @selector(alertWindow));
}

@end

@implementation UIAlertController (ShowWithoutViewController)

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    // make sure that the window destroyed
    self.alertWindow.hidden = YES;
    self.alertWindow = nil;
}

- (void)presentWithAnimated:(BOOL)animated {
    [self presentWithAnimated:animated completion:nil];
}

- (void)presentWithAnimated:(BOOL)animated completion:(void (^ _Nullable)(void))completion {
    self.alertWindow = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    self.alertWindow.rootViewController = [[UIViewController alloc] init];

    self.alertWindow.windowLevel = UIWindowLevelAlert + 1;

    [self.alertWindow makeKeyAndVisible];

    UIView *sourceView;
    CGRect sourceRect;

    if (self.preferredStyle == UIAlertControllerStyleActionSheet) {
        sourceView = self.alertWindow.rootViewController.view;
        sourceRect = self.alertWindow.rootViewController.view.frame;
    } else {
        sourceView = nil;
        sourceRect = CGRectNull;
    }

    [self presentWithViewController:self.alertWindow.rootViewController sourceView:sourceView sourceRect:sourceRect barButtonItem:nil animated:animated completion:completion];

}

- (void)presentWithViewController:(__kindof UIViewController *_Nonnull)viewController sourceView:(UIView *_Nullable)sourceView sourceRect:(CGRect)sourceRect barButtonItem:(UIBarButtonItem *_Nullable)barButtonItem animated:(BOOL)animated completion:(void (^ _Nullable)(void))completion {
    if (sourceView) {
        self.popoverPresentationController.sourceView = sourceView;
        self.popoverPresentationController.sourceRect = sourceRect;
    }

    if (barButtonItem) {
        self.popoverPresentationController.barButtonItem = barButtonItem;
    }

    [viewController presentViewController:self animated:animated completion:completion];
}

@end
