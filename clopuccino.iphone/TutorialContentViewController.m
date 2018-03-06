#import "TutorialContentViewController.h"

@interface TutorialContentViewController ()

@property(nonatomic, strong) NSArray *backgroundColors;

@end

@implementation TutorialContentViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    _backgroundColors = @[@"#fbc137", @"#dfc645", @"#c3cb53", @"#a7d162", @"#75da7b"];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self reloadWithIndex:_index];

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
        self.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        self.textLabel.textColor = [UIColor blackColor];
    });
}

- (void)reloadWithIndex:(NSInteger)index {
    NSString *imageNameLocalizedKey = [NSString stringWithFormat:@"How To %d Image", (int) (index + 1)];
    NSString *textLocalizedKey = [NSString stringWithFormat:@"How To %d Text", (int) (index + 1)];

    NSString *imageName = NSLocalizedString(imageNameLocalizedKey, @"");
    NSString *text = NSLocalizedString(textLocalizedKey, @"");

    [_imageView setImage:[UIImage imageNamed:imageName]];
    [_textLabel setText:text];
    
    // previous button title
    if (index > 0) {
        _previousButtonTitle = NSLocalizedString(@"Previous", @"");
    } else {
        _previousButtonTitle = NSLocalizedString(@"Cancel", @"");
    }
    
    // next button title
    if (index < [_backgroundColors count] - 1) {
        _nextButtonTitle = NSLocalizedString(@"Next", @"");
    } else {
        _nextButtonTitle = NSLocalizedString(@"Done", @"");
    }
    
    _backgroundColor = [Utility colorFromHexString:_backgroundColors[(NSUInteger) index] alpha:1.0];
}

@end
