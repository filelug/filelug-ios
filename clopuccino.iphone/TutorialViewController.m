#import "TutorialViewController.h"
#import "TutorialContentViewController.h"

@interface TutorialViewController ()

@end

@implementation TutorialViewController

static NSInteger const pageCount = 5;

- (void)viewDidLoad {
    [super viewDidLoad];

    _pageController = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal options:nil];

    _pageController.dataSource = self;
    _pageController.delegate = self;
    
    // let self.view handles the background color
    // the background color of all elements in TutorialContentViewController should set to nil
    [_pageController.view setBackgroundColor:nil];

    // prepare the rect for UIPageViewController
    CGSize frameSize = [[self view] bounds].size;
    CGFloat width = frameSize.width;
    CGFloat height = frameSize.height - 40;
    CGRect rect = CGRectMake(0, 0, width, height);
    
    [[_pageController view] setFrame:rect];
    
    if (!self.startViewControllerIndex) {
        self.startViewControllerIndex = @(0);
    }
    
    NSInteger startingIndex = [self.startViewControllerIndex integerValue];

    TutorialContentViewController *contentViewController = [self viewControllerAtIndex:startingIndex];

    NSArray *viewControllers = @[contentViewController];

    [_pageController setViewControllers:viewControllers direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];

    [self addChildViewController:_pageController];

    [self.view addSubview:[_pageController view]];

    // addChildViewController: will call [child willMoveToParentViewController:self] before adding the
    // child. However, it will not call didMoveToParentViewController:. It is expected that a container view
    // controller subclass will make this call after a transition to the new child has completed or, in the
    // case of no transition, immediately after the call to addChildViewController:.
    [self.pageController didMoveToParentViewController:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    NSArray *currentViewControllers = [self.pageController viewControllers];
    
    if (currentViewControllers && [currentViewControllers count] > 0) {
        TutorialContentViewController *contentViewController = (TutorialContentViewController *) currentViewControllers[0];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.nextButton setTitle:contentViewController.nextButtonTitle forState:UIControlStateNormal];
            
            [self.previousButton setTitle:contentViewController.previousButtonTitle forState:UIControlStateNormal];
            
            [self.view setBackgroundColor:contentViewController.backgroundColor];
        });
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangePreferredContentSize:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)didChangePreferredContentSize:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        UILabel *nextLabel = self.nextButton.titleLabel;
        nextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        nextLabel.textColor = [UIColor blackColor];

        UILabel *previousLabel = self.previousButton.titleLabel;
        previousLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        previousLabel.textColor = [UIColor blackColor];
    });
}

- (IBAction)doNext:(id)sender {
    NSArray *viewControllers = [self.pageController viewControllers];

    if (viewControllers &&[viewControllers count] > 0) {
        NSInteger currentIndex = [(TutorialContentViewController *) viewControllers[0] index];

        if (currentIndex + 1 == pageCount) {
            [self dismissSelf];
        } else {
            TutorialContentViewController *contentViewController = [self viewControllerAtIndex:++currentIndex];

            [self.pageController setViewControllers:@[contentViewController] direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.nextButton setTitle:contentViewController.nextButtonTitle forState:UIControlStateNormal];
                
                [self.previousButton setTitle:contentViewController.previousButtonTitle forState:UIControlStateNormal];
                
                [self.view setBackgroundColor:contentViewController.backgroundColor];
            });
        }
    }
}

- (void)dismissSelf {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self dismissViewControllerAnimated:YES completion:nil];
    });
}

- (IBAction)doPrevious:(id)sender {
    NSArray *viewControllers = [self.pageController viewControllers];

    if (viewControllers && [viewControllers count] > 0) {
        NSInteger currentIndex = [(TutorialContentViewController *) viewControllers[0] index];

        if (currentIndex == 0) {
            [self dismissSelf];
        } else {
            TutorialContentViewController *contentViewController = [self viewControllerAtIndex:--currentIndex];

            [self.pageController setViewControllers:@[contentViewController] direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.nextButton setTitle:contentViewController.nextButtonTitle forState:UIControlStateNormal];
                
                [self.previousButton setTitle:contentViewController.previousButtonTitle forState:UIControlStateNormal];
                
                [self.view setBackgroundColor:contentViewController.backgroundColor];
            });
        }
    }
}

- (TutorialContentViewController *)viewControllerAtIndex:(NSInteger)index {
    TutorialContentViewController *contentViewController = [Utility instantiateViewControllerWithIdentifier:@"TutorialContent"];
    contentViewController.index = index;
    
    return contentViewController;
    
}

#pragma mark - UIPageViewControllerDelegate

- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers transitionCompleted:(BOOL)completed {
    if (finished) {
        NSArray *currentViewControllers = [pageViewController viewControllers];
        
        TutorialContentViewController *contentViewController = (TutorialContentViewController *) currentViewControllers[0];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.nextButton setTitle:contentViewController.nextButtonTitle forState:UIControlStateNormal];
            
            [self.previousButton setTitle:contentViewController.previousButtonTitle forState:UIControlStateNormal];
            
            [self.view setBackgroundColor:contentViewController.backgroundColor];
        });
    }
}

#pragma mark - UIPageViewControllerDataSource

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController {
    NSInteger index = [(TutorialContentViewController *) viewController index];

    if (index == 0) {
        return nil;
    }

    // Decrease the index by 1 to return
    index--;

    return [self viewControllerAtIndex:index];

}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController {
    NSInteger index = [(TutorialContentViewController *) viewController index];

    index++;

    if (index == pageCount) {
        return nil;
    }

    return [self viewControllerAtIndex:index];

}

- (NSInteger)presentationCountForPageViewController:(UIPageViewController *)pageViewController {
    // The number of items reflected in the page indicator.

    return pageCount;
}

- (NSInteger)presentationIndexForPageViewController:(UIPageViewController *)pageViewController {
    // The selected item reflected in the page indicator.

    NSArray *viewControllers = [pageViewController viewControllers];

    if (viewControllers && [viewControllers count] > 0) {
        return [(TutorialContentViewController *)viewControllers[0] index];
    } else {
        return 0;
    }
}

@end
