#import "PreferredContentSizeCategoryService.h"

@interface PreferredContentSizeCategoryService ()

@property(nonatomic, strong) NSUserDefaults *userDefaults;

@end

@implementation PreferredContentSizeCategoryService

- (instancetype)init {
    self = [super init];
    
    if (self) {
        _userDefaults = [Utility groupUserDefaults];
    }
    
    return self;
}

- (NSString *)contentSizeCategory {
    return [self.userDefaults stringForKey:USER_DEFAULTS_KEY_PREFERRED_CONTENT_SIZE_CATEGORY];
}

- (void)setContentSizeCategory:(NSString *)contentSizeCategory {
    if (![contentSizeCategory isEqualToString:self.contentSizeCategory]) {
        [self.userDefaults setObject:contentSizeCategory forKey:USER_DEFAULTS_KEY_PREFERRED_CONTENT_SIZE_CATEGORY];
    }
}

- (void)didChangePreferredContentSizeWithNotification:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];

    if (userInfo) {
        NSString *newContentSizeCategory = [notification userInfo][UIContentSizeCategoryNewValueKey];

        if (newContentSizeCategory) {
            [self setContentSizeCategory:newContentSizeCategory];
        }
    }
}

- (BOOL)isSmallContentSizeCategory {
    NSString *contentSizeCategory = self.contentSizeCategory;

    return contentSizeCategory &&
            ([contentSizeCategory isEqualToString:UIContentSizeCategoryExtraSmall] || [contentSizeCategory isEqualToString:UIContentSizeCategorySmall]);
}

- (BOOL)isMediumContentSizeCategory {
    NSString *contentSizeCategory = self.contentSizeCategory;

    return contentSizeCategory && [contentSizeCategory isEqualToString:UIContentSizeCategoryMedium];
}

- (BOOL)isMediumOrLargeContentSizeCategory {
    NSString *contentSizeCategory = self.contentSizeCategory;

    return contentSizeCategory &&
            ([contentSizeCategory isEqualToString:UIContentSizeCategoryMedium]
                    || [contentSizeCategory isEqualToString:UIContentSizeCategoryLarge]
                    || [contentSizeCategory isEqualToString:UIContentSizeCategoryExtraLarge]
                    || [contentSizeCategory isEqualToString:UIContentSizeCategoryExtraExtraLarge]
                    || [contentSizeCategory isEqualToString:UIContentSizeCategoryExtraExtraExtraLarge]);
}

- (BOOL)isLargeContentSizeCategory {
    NSString *contentSizeCategory = self.contentSizeCategory;

    return contentSizeCategory &&
            ([contentSizeCategory isEqualToString:UIContentSizeCategoryLarge]
                    || [contentSizeCategory isEqualToString:UIContentSizeCategoryExtraLarge]
                    || [contentSizeCategory isEqualToString:UIContentSizeCategoryExtraExtraLarge]
                    || [contentSizeCategory isEqualToString:UIContentSizeCategoryExtraExtraExtraLarge]);
}

- (BOOL)isXXLargeContentSizeCategory {
    NSString *contentSizeCategory = self.contentSizeCategory;

    return contentSizeCategory &&
            ([contentSizeCategory isEqualToString:UIContentSizeCategoryExtraExtraLarge]
                    || [contentSizeCategory isEqualToString:UIContentSizeCategoryExtraExtraExtraLarge]);
}

@end
