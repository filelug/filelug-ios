#import <Foundation/Foundation.h>
#import "BBBadgeBarButtonItem.h"


@interface BBBadgeBarButtonItem (TransferBadgeBarButtonItem)

- (_Nonnull instancetype)initWithUploadBadgeBarButton:(nonnull UIButton *)uploadBadgeBarButton;

//+ (_Nonnull instancetype)badgeBarButtonItemForUploadFileWithTarget:(nullable id)target action:(_Nonnull SEL)action forControlEvents:(UIControlEvents)controlEvents;

@end