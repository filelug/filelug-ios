#import <UIKit/UIKit.h>

@interface TutorialViewController : UIViewController <UIPageViewControllerDataSource, UIPageViewControllerDelegate>

@property(nonatomic, weak) IBOutlet UIButton *nextButton;

@property(nonatomic, weak) IBOutlet UIButton *previousButton;

@property(strong, nonatomic) UIPageViewController *pageController;

// wrapping NSInteger
@property(strong, nonatomic) NSNumber *startViewControllerIndex;

- (IBAction)doNext:(id)sender;

- (IBAction)doPrevious:(id)sender;

@end
