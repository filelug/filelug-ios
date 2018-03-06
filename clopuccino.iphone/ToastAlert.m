#import "ToastAlert.h"

@interface ToastAlert ()

@property (nonatomic, assign) CGFloat fontSize;

@property(nonatomic, assign) NSTimeInterval delay;

@property(nonatomic, assign) NSTimeInterval duration;

@property(nonatomic, assign) ToastAlertLocationAlignment alignment;

@property(nonatomic, strong) void (^completionHandler)(void);

@end

@implementation ToastAlert

//#define POPUP_DELAY  0.5
//#define TEXT_FONT_SIZE 15

//- (id)initWithText:(NSString *)message {
//    self = [super init];
//
//    if (self) {
//
//        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
//        self.textColor = [UIColor colorWithWhite:1 alpha:0.95];
//        self.font = [UIFont boldSystemFontOfSize:TEXT_FONT_SIZE];
//        self.text = message;
//        self.numberOfLines = 0;
//        self.textAlignment = NSTextAlignmentCenter;
//        self.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
//
//
//    }
//
//    return self;
//}

- (id)initWithText:(NSString *)message fontSize:(CGFloat)fontSize delay:(NSTimeInterval)delay duration:(NSTimeInterval)duration alignment:(ToastAlertLocationAlignment)alignment completionHandler:(void (^)(void))completionHandler {
    self = [super init];

    if (self) {
        _fontSize = fontSize;
        _delay = delay;
        _duration = duration;
        _alignment = alignment;
        _completionHandler = completionHandler;

        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
        self.textColor = [UIColor colorWithWhite:1 alpha:0.95];
        self.font = [UIFont boldSystemFontOfSize:_fontSize];
        self.text = message;
        self.numberOfLines = 0;
        self.textAlignment = NSTextAlignmentCenter;
        self.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    }

    return self;
}

- (void)didMoveToSuperview {
    UIView *parent = self.superview;

    if (parent) {

        CGSize maximumLabelSize = CGSizeMake(300, 200);

        NSDictionary *stringAttributes = @{NSFontAttributeName: [UIFont systemFontOfSize:self.fontSize]};

        CGSize expectedLabelSize = [self.text boundingRectWithSize:maximumLabelSize
                                                         options:NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesLineFragmentOrigin
                                                      attributes:stringAttributes context:nil].size;

        expectedLabelSize = CGSizeMake(expectedLabelSize.width + 20, expectedLabelSize.height + 10);

        switch (self.alignment) {
            case ToastAlertLocationAlignmentCenterMiddle:
                /* center-middle */
                self.frame = CGRectMake(parent.center.x - expectedLabelSize.width / 2, parent.bounds.size.height - expectedLabelSize.height - 10, expectedLabelSize.width, expectedLabelSize.height);

                break;
            case ToastAlertLocationAlignmentRightMiddle:
                /* right-middle */
                self.frame = CGRectMake(parent.bounds.size.width - expectedLabelSize.width, parent.bounds.size.height - expectedLabelSize.height - 10, expectedLabelSize.width, expectedLabelSize.height);

                break;
            default:
                /* center-top */
                self.frame = CGRectMake(parent.center.x - expectedLabelSize.width / 2, 0, expectedLabelSize.width, expectedLabelSize.height);
        }

        CALayer *layer = self.layer;

        layer.cornerRadius = 4.0f;

        /* setup shadow */
        layer.shadowOffset = CGSizeMake(0, 3);
        layer.shadowRadius = 5.0f;
        layer.shadowColor = [UIColor blackColor].CGColor;
        layer.shadowOpacity = 0.8;

        [self performSelector:@selector(dismiss:) withObject:nil afterDelay:self.delay];
    }
}

- (void)dismiss:(id)sender {
    // Fade out the message and destroy self
    [UIView animateWithDuration:self.duration delay:0 options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                         self.alpha = 0;
                     }
                     completion:^(BOOL finished) {
                         if (self.completionHandler) {
                             void (^completionHandler)(void) = self.completionHandler;
                             self.completionHandler = nil;

                             completionHandler();
                         }

                         [self removeFromSuperview];
                     }];
}

@end
