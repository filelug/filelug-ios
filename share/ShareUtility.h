#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ShareUtility : NSObject

// view controller from storyboard with name @"MainInterface"
+ (id)instantiateViewControllerWithIdentifier:(NSString *)identifier;

@end

NS_ASSUME_NONNULL_END