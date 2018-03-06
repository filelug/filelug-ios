#import <Foundation/Foundation.h>


@interface ConfirmUploadTimer : NSObject

+ (void)startWithInterval:(NSTimeInterval)interval stopCurrentTimer:(BOOL)stopCurrentTimer;

+ (void)stop;

@end
