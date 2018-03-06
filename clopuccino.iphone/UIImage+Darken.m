#import "UIImage+Darken.h"

@implementation UIImage (Darken)

- (id)initWithUIImage:(UIImage *)image darkened:(CGFloat)alpha {
    CIImage *inputImage = [[CIImage alloc] initWithImage:image];

    CIContext *context = [CIContext contextWithOptions:nil];

    //1. create some darkness
    CIFilter *blackGenerator = [CIFilter filterWithName:@"CIConstantColorGenerator"];
    CIColor *black = [CIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:alpha];
    [blackGenerator setValue:black forKey:@"inputColor"];
    CIImage *blackImage = [blackGenerator valueForKey:@"outputImage"];

    //2. apply that black
    CIFilter *compositeFilter = [CIFilter filterWithName:@"CIMultiplyBlendMode"];
    [compositeFilter setValue:blackImage forKey:@"inputImage"];
    [compositeFilter setValue:inputImage forKey:@"inputBackgroundImage"];
    CIImage *darkenedImage = [compositeFilter outputImage];

    CGImageRef cgimg = [context createCGImage:darkenedImage fromRect:inputImage.extent];

    self = [UIImage imageWithCGImage:cgimg];

    CGImageRelease(cgimg);

    return self;
}

@end