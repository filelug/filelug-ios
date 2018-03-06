#import "BBBadgeBarButtonItem+TransferBadgeBarButtonItem.h"
#import "Utility.h"


@implementation BBBadgeBarButtonItem (TransferBadgeBarButtonItem)

- (_Nonnull instancetype)initWithUploadBadgeBarButton:(nonnull UIButton *)uploadBadgeBarButton {
    BBBadgeBarButtonItem *badgeBarButtonItem = [[BBBadgeBarButtonItem alloc] initWithCustomUIButton:uploadBadgeBarButton];

    badgeBarButtonItem.badgeOriginX = 22;
    badgeBarButtonItem.badgeOriginY = 0;
    badgeBarButtonItem.badgeBGColor = [Utility colorFromHexString:@"#007AFF" alpha:1.0];
    badgeBarButtonItem.badgeTextColor = [UIColor whiteColor];

    return badgeBarButtonItem;
}

//+ (_Nonnull instancetype)badgeBarButtonItemForUploadFileWithTarget:(nullable id)target action:(SEL)action forControlEvents:(UIControlEvents)controlEvents {
//    UIButton *doneButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
//    [doneButton addTarget:target action:action forControlEvents:controlEvents];
//    [doneButton setImage:[UIImage imageNamed:@"arrow-circle-02"] forState:UIControlStateNormal];
//
//    BBBadgeBarButtonItem *badgeBarButtonItem = [[BBBadgeBarButtonItem alloc] initWithCustomUIButton:doneButton];
//
//    badgeBarButtonItem.badgeOriginX = 22;
//    badgeBarButtonItem.badgeOriginY = 0;
//    badgeBarButtonItem.badgeBGColor = [Utility colorFromHexString:@"#007AFF" alpha:1.0];
//    badgeBarButtonItem.badgeTextColor = [UIColor whiteColor];
//
//    return badgeBarButtonItem;
//}

@end