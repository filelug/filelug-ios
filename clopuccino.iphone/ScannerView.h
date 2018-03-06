#import <UIKit/UIKit.h>

@class ScannerView;

NS_ASSUME_NONNULL_BEGIN

@protocol ScannerViewDelegate

@required

- (void)scannerView:(ScannerView *)scannerView decodeWithMetatdataObjects:(NSArray *)metadataObjects;

@end

@interface ScannerView : UIView

- (instancetype)initWithDelegate:(id <ScannerViewDelegate>)delegate;

- (void)startWithViewRect:(CGRect)viewRect;

- (BOOL)isStarting;

-(void)stop;

@end

NS_ASSUME_NONNULL_END
