#import "UIButton+UploadBadgeBarButton.h"

@implementation UIButton (UploadBadgeBarButton)

+ (instancetype)uploadBadgeBarButton {
    UIButton *doneButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];

    [doneButton setImage:[UIImage imageNamed:@"upload"] forState:UIControlStateNormal];

    return doneButton;
}


@end