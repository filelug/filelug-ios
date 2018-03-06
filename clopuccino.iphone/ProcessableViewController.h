#import <Foundation/Foundation.h>
#import "MBProgressHUD.h"

@protocol ProcessableViewController <NSObject>

@required

@property(nonatomic, strong) NSNumber *processing;

@property(nonatomic, strong) MBProgressHUD *progressView;

- (BOOL)isLoading;

- (void)stopLoading;

@end
