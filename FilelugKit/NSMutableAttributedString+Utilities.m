#import "NSMutableAttributedString+Utilities.h"

@implementation NSMutableAttributedString (Utilities)

- (void)setText:(NSString *)text withColor:(UIColor *)color {
    NSRange range = [self.mutableString rangeOfString:text options:NSCaseInsensitiveSearch];
    
    if (range.location != NSNotFound) {
        [self addAttribute:NSForegroundColorAttributeName value:color range:range];
    }
}

@end
