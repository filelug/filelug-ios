#import "UIColor+Filelug.h"

@implementation UIColor (Filelug)

//+ (UIColor *)colorWithHueDegrees:(CGFloat)hue saturation:(CGFloat)saturation brightness:(CGFloat)brightness {
//    return [UIColor colorWithHue:(hue/360) saturation:saturation brightness:brightness alpha:1.0];
//}

+ (UIColor *)aquaColor {
    static UIColor *color;
    
    if (!color) {
        color = [UIColor colorWithRed:0.0 green:(CGFloat) (122.0 / 255.0) blue:1.0 alpha:1.0];
//        color = [UIColor colorWithHueDegrees:210 saturation:1.0 brightness:1.0];
    }
    
    return color;
}

@end
