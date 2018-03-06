#import "ConnectToComputerStartupViewController.h"
#import "ConnectToComputerScanQRCodeViewController.h"

#define kRowHeightOfDescriptionCell     150
#define kRowHeightOfImageCell           280

@interface ConnectToComputerStartupViewController ()

@end

@implementation ConnectToComputerStartupViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.currentStepButtonItem setTitle:NSLocalizedString(@"Title Startup", @"")];

    // Change the back button for the next view controller

    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Previous Step", @"") style:UIBarButtonItemStylePlain target:nil action:nil];

    [self.navigationItem setBackBarButtonItem:backButton];

    // The next button of the current view controller

    UIBarButtonItem *nextButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Next Step", @"") style:UIBarButtonItemStylePlain target:self action:@selector(goNext:)];

    self.navigationItem.rightBarButtonItem = nextButton;

    // navigation title

    self.navigationItem.title = NSLocalizedString(@"New Computer", @"");

    // Towards down Gesture recogniser for swiping - dismiss itself
    UISwipeGestureRecognizer *rightRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(rightSwipeHandle:)];
    rightRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
    [rightRecognizer setNumberOfTouchesRequired:1];
    [self.view addGestureRecognizer:rightRecognizer];

    // Towards left Gesture recogniser for swiping - go to next
    UISwipeGestureRecognizer *leftRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(leftSwipeHandle:)];
    leftRecognizer.direction = UISwipeGestureRecognizerDirectionLeft;
    [leftRecognizer setNumberOfTouchesRequired:1];
    [self.view addGestureRecognizer:leftRecognizer];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)goNext:(id)sender {
    // navigate to ConnectToComputerScanQRCodeViewController

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        ConnectToComputerScanQRCodeViewController *connectToComputerScanQRCodeViewController = [[ConnectToComputerScanQRCodeViewController alloc] initWithNibName:@"ConnectToComputerScanQRCodeViewController" bundle:nil];

        [connectToComputerScanQRCodeViewController setHidesBottomBarWhenPushed:YES];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.navigationController pushViewController:connectToComputerScanQRCodeViewController animated:YES];
        });
    });
}

- (void)rightSwipeHandle:(UISwipeGestureRecognizer *)gestureRecognizer {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.navigationController popViewControllerAnimated:YES];
    });
}

- (void)leftSwipeHandle:(UISwipeGestureRecognizer *)gestureRecognizer {
    [self goNext:nil];
}

//// Overrides the following two methods to disable orientation and limited to portrait
//
//- (BOOL) shouldAutorotate {
//    return NO;
//}
//
//- (UIInterfaceOrientationMask) supportedInterfaceOrientations {
//    return UIInterfaceOrientationMaskPortrait;
//    // return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
//}
//
//- (UIInterfaceOrientation) preferredInterfaceOrientationForPresentation {
//    // Return the orientation you'd prefer - this is what it launches to. The
//    // user can still rotate. You don't have to implement this method, in which
//    // case it launches in the current orientation
//    return UIInterfaceOrientationPortrait;
//}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *descriptionCellIdentifier = @"DescriptionCell";
    static NSString *imageViewCellIdentifier = @"ImageViewCell";

    [tableView setSeparatorColor:[UIColor clearColor]];

    UITableViewCell *cell;

    if (indexPath.row < 1) {
        // description cell

        cell = [tableView dequeueReusableCellWithIdentifier:descriptionCellIdentifier];

        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:descriptionCellIdentifier];

            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;

            cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
            cell.textLabel.textColor = [UIColor darkTextColor];
            cell.textLabel.numberOfLines = 5;
            cell.textLabel.adjustsFontSizeToFitWidth = NO;
            cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
            cell.textLabel.textAlignment = NSTextAlignmentNatural;

            cell.textLabel.text = NSLocalizedString(@"Description of connecting to computer startup", @"");
            cell.imageView.image = [UIImage imageNamed:@"number-2-active"];
        }
    } else {
        cell = [tableView dequeueReusableCellWithIdentifier:imageViewCellIdentifier];

        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:imageViewCellIdentifier];

            UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"qr-code"]];

            [cell.contentView addSubview:imageView];

            // make it center of the cell
            imageView.center = CGPointMake([UIScreen mainScreen].bounds.size.width / 2, imageView.center.y);
        }
    }

    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return (indexPath.row < 1) ? kRowHeightOfDescriptionCell : kRowHeightOfImageCell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 0;
}

@end
