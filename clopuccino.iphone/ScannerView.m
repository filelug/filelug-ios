#import "ScannerView.h"

#define kTagOfScanRectView                  10
#define kPaddingOfScannerRectOfInterest     10

@interface ScannerView () <AVCaptureMetadataOutputObjectsDelegate>

@property(nonatomic, strong) id <ScannerViewDelegate> delegate;

@property(strong, nonatomic) AVCaptureDevice *device;
@property(strong, nonatomic) AVCaptureDeviceInput *input;
@property(strong, nonatomic) AVCaptureMetadataOutput *output;
@property(strong, nonatomic) AVCaptureSession *session;
@property(strong, nonatomic) AVCaptureVideoPreviewLayer *preview;

@end

@implementation ScannerView

- (instancetype)initWithDelegate:(id <ScannerViewDelegate>)delegate {
    self = [super init];

    if (self) {
        self.delegate = delegate;
    }

    return self;
}

- (void)startWithViewRect:(CGRect)viewRect {
    CGSize viewRectSize = viewRect.size;

    self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    self.input = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:nil];

    // output

    self.output = [[AVCaptureMetadataOutput alloc] init];

    // setup the rectOfInterest from viewRect, excludes the paddings for height

    CGFloat rectWidth = MIN(viewRectSize.width, (viewRectSize.height - kPaddingOfScannerRectOfInterest * 2));

    CGSize scanSize = CGSizeMake(rectWidth, rectWidth);
    CGRect scanRectOfInterest = CGRectMake((viewRectSize.width-scanSize.width)/2, (viewRectSize.height-scanSize.height)/2, scanSize.width, scanSize.height);

    // For orientation Portrait, the positions of x and y needs to change to each other.
    scanRectOfInterest = CGRectMake(scanRectOfInterest.origin.y/viewRectSize.height, scanRectOfInterest.origin.x/viewRectSize.width, scanRectOfInterest.size.height/viewRectSize.height,scanRectOfInterest.size.width/viewRectSize.width);

    self.output.rectOfInterest = scanRectOfInterest;

    // session
    self.session = [[AVCaptureSession alloc] init];
    [self.session setSessionPreset:(viewRectSize.height < 500) ? AVCaptureSessionPreset640x480 : AVCaptureSessionPresetHigh];
    [self.session addInput:self.input];
    [self.session addOutput:self.output];
    
    // The available types are dependent on the AVCaptureDeviceInput, so it needs to be set after AVCaptureSession set its input and output
    
    self.output.metadataObjectTypes = @[AVMetadataObjectTypeQRCode];
    [self.output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    
    // show view for scan rect
    UIView *scanRectView = [UIView new];
    
    scanRectView.tag = kTagOfScanRectView;
    
    scanRectView.frame = CGRectMake(0, 0, rectWidth, rectWidth);
    scanRectView.center = CGPointMake(CGRectGetMidX(viewRect), CGRectGetMidY(viewRect));
    scanRectView.layer.borderColor = [UIColor redColor].CGColor;
    scanRectView.layer.borderWidth = 1;
    
    [self addSubview:scanRectView];

    // preview
    self.preview = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    self.preview.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.preview.frame = viewRect;
    [self.layer insertSublayer:self.preview atIndex:0];

    [self.session startRunning];
}

- (BOOL)isStarting {
    return self.session && [self.session isRunning];
}

- (void)stop {
    UIView *scanRectView = [self viewWithTag:kTagOfScanRectView];

    if (scanRectView) {
        [scanRectView removeFromSuperview];
    }

    if ([self isStarting]) {
        [self.session stopRunning];
    }
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    if (metadataObjects.count > 0) {
        [self.delegate scannerView:self decodeWithMetatdataObjects:metadataObjects];
    }
}


@end
