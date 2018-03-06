#import <Foundation/Foundation.h>

typedef enum {
    ToastAlertLocationAlignmentCenterTop = 0, // default
    ToastAlertLocationAlignmentCenterMiddle = 1,
    ToastAlertLocationAlignmentRightMiddle = 2,
} ToastAlertLocationAlignment;

@interface ToastAlert : UILabel {
}

- (id)initWithText:(NSString *)message fontSize:(CGFloat)fontSize delay:(NSTimeInterval)delay duration:(NSTimeInterval)duration alignment:(ToastAlertLocationAlignment)alignment completionHandler:(void (^)(void))completionHandler;

@end
