#import "ShareUtility.h"

@implementation ShareUtility {
}

+ (id)instantiateViewControllerWithIdentifier:(NSString *)identifier {
    return [Utility instantiateViewControllerWithIdentifier:identifier fromStoryboardWithName:@"share"];
}

@end