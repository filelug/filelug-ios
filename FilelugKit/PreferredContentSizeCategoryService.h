#import <Foundation/Foundation.h>
#import "Utility.h"

@interface PreferredContentSizeCategoryService : NSObject

@property(nonatomic, strong) NSString *contentSizeCategory;

- (instancetype)init;

- (void)didChangePreferredContentSizeWithNotification:(NSNotification *)notification;

- (BOOL)isSmallContentSizeCategory;

- (BOOL)isMediumContentSizeCategory;

- (BOOL)isMediumOrLargeContentSizeCategory;

- (BOOL)isLargeContentSizeCategory;

- (BOOL)isXXLargeContentSizeCategory;

@end
