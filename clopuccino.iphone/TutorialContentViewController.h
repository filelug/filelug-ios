#import <UIKit/UIKit.h>

@interface TutorialContentViewController : UIViewController

@property(nonatomic) NSInteger index;

@property(nonatomic, weak) IBOutlet UIImageView *imageView;

@property(nonatomic, weak) IBOutlet UILabel *textLabel;

@property(nonatomic, strong, readonly) NSString *previousButtonTitle;

@property(nonatomic, strong, readonly) NSString *nextButtonTitle;

@property(nonatomic, strong, readonly) UIColor *backgroundColor;

@end
