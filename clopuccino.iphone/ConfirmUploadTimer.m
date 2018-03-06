#import "ConfirmUploadTimer.h"
#import "AssetFileDao.h"
#import "Utility.h"
#import "DirectoryService.h"

static dispatch_source_t _timer;

@implementation ConfirmUploadTimer


+ (void)startWithInterval:(NSTimeInterval)interval stopCurrentTimer:(BOOL)stopCurrentTimer {
    if (_timer && stopCurrentTimer) {
        dispatch_source_set_cancel_handler(_timer, ^{
            _timer = nil;
            
            [ConfirmUploadTimer internalStartWithInterval:interval];
        });
        
        dispatch_source_cancel(_timer);
    } else {
        [ConfirmUploadTimer internalStartWithInterval:interval];
    }
}

+ (void)internalStartWithInterval:(NSTimeInterval)interval {
    //    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    //    NSLog(@"Confirm-upload-timer created.");
    
    _timer = createDispatchTimer(interval, queue, ^{
        //        NSLog(@"Starting to check file upload status of wait-to-confirm");
        
        AssetFileDao *assetFileDao = [[AssetFileDao alloc] init];
        
        NSDictionary *dictionary = [assetFileDao findWaitToConfirmAssetFileTransferKeyAndStatusDictionary];
        
        if (dictionary && [dictionary count] > 0) {
            DirectoryService *directoryService = [[DirectoryService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];
            
            [directoryService confirmUploadWithTransferKeyAndStatusDictionary:dictionary tryAgainIfConnectionFailed:NO];
        } else {
            // if there's no unfinished uploading file, stop itself.
            
            if (![assetFileDao existingUnfinishedAssetFile]) {
                [ConfirmUploadTimer stop];
            }
            
        }
    });
}

//+ (void)startTimer {
//    if (!_timer) {
//        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
//
//        NSLog(@"Confirm-upload-timer created.");
//
//        _timer = createDispatchTimer(CONFIRM_UPLOAD_TIME_INTERVAL, queue, ^{
//            NSLog(@"Starting to check file upload status of wait-to-confirm");
//
//            AssetFileDao *assetFileDao = [[AssetFileDao alloc] init];
//
//            NSDictionary *dictionary = [assetFileDao findWaitToConfirmAssetFileTransferKeyAndStatusDictionary];
//
//            if (dictionary && [dictionary count] > 0) {
//                [[FilelugUtility defaultAssetUploadService] confirmUploadWithTransferKeyAndStatusDictionary:dictionary tryAgainIfConnectionFailed:NO];
//            } else {
//                // if there's no unfinished uploading file, stop itself.
//
//                if (![assetFileDao existingUnfinishedAssetFile]) {
//                    [ConfirmUploadTimer stop];
//                }
//
//            }
//        });
//    }
//}

+ (void)stop {
    if (_timer) {
        dispatch_source_cancel(_timer);
        
        _timer = nil;
        
        NSLog(@"Confirm-upload-timer stopped.");
    }
}

@end
