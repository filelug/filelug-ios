#import <Foundation/Foundation.h>

@protocol StatusBarHiddableViewController <NSObject>

@required

@property(nonatomic) BOOL shouldStatusBarHidden;

@end
