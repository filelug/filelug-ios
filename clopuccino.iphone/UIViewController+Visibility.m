#import "UIViewController+Visibility.h"

@implementation UIViewController (Visibility)

- (BOOL)isVisible {
    __block BOOL visible;
    
    // Check if main thread

    if ([NSThread isMainThread]) {
        visible = [self isViewLoaded] && self.view.window;
    } else {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

        dispatch_async(dispatch_get_main_queue(), ^{
            visible = [self isViewLoaded] && self.view.window;

            dispatch_semaphore_signal(semaphore);
        });

        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    }
    
    return visible;
}

@end
