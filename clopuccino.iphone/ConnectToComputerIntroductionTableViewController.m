#import "ConnectToComputerIntroductionTableViewController.h"
#import "ConnectToComputerInstallationViewController.h"
#import "SettingsViewController.h"

#define kRowHeightOfDescriptionCell     150
#define kRowHeightOfImageCell           280

@interface ConnectToComputerIntroductionTableViewController ()

@end

@implementation ConnectToComputerIntroductionTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Change the back button for the next view controller

    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel", @"") style:UIBarButtonItemStylePlain target:nil action:nil];
    [self.navigationItem setBackBarButtonItem:backButton];

    // The cancel button of the current view controller

    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel", @"") style:UIBarButtonItemStylePlain target:self action:@selector(dismissItself:)];
    self.navigationItem.leftBarButtonItem = cancelButton;

    // The next button of the current view controller

    UIBarButtonItem *nextButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Next Step", @"") style:UIBarButtonItemStylePlain target:self action:@selector(goNext:)];

    self.navigationItem.rightBarButtonItem = nextButton;

    // navigation title

    self.navigationItem.title = NSLocalizedString(@"New Computer", @"");

    // Towards down Gesture recogniser for swiping - dismiss itself
    UISwipeGestureRecognizer *downRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(downSwipeHandle:)];
    downRecognizer.direction = UISwipeGestureRecognizerDirectionDown;
    [downRecognizer setNumberOfTouchesRequired:1];
    [self.view addGestureRecognizer:downRecognizer];

    // Towards left Gesture recogniser for swiping - go to next
    UISwipeGestureRecognizer *leftRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(leftSwipeHandle:)];
    leftRecognizer.direction = UISwipeGestureRecognizerDirectionLeft;
    [leftRecognizer setNumberOfTouchesRequired:1];
    [self.view addGestureRecognizer:leftRecognizer];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dismissItself:(id)sender {
    if (self.fromViewController && [self.fromViewController isKindOfClass:[SettingsViewController class]]) {
        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        [userDefaults setObject:@YES forKey:USER_DEFAULTS_KEY_DISABLED_FIND_AVAILABLE_COMPUTERS_ON_VIEW_DID_APPEAR];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
    });
}

- (void)downSwipeHandle:(UISwipeGestureRecognizer *)gestureRecognizer {
    [self dismissItself:nil];
}

- (void)leftSwipeHandle:(UISwipeGestureRecognizer *)gestureRecognizer {
    [self goNext:nil];
}

//- (void)popToRoot:(id)sender {
//    dispatch_async(dispatch_get_main_queue(), ^{
//        [self.navigationController popToRootViewControllerAnimated:YES];
//    });
//}

- (void)goNext:(id)sender {
    // navigate to ConnectToComputerInstallationViewController

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        ConnectToComputerInstallationViewController *connectToComputerInstallationViewController = [[ConnectToComputerInstallationViewController alloc] initWithNibName:@"ConnectToComputerInstallationViewController" bundle:nil];

        [connectToComputerInstallationViewController setHidesBottomBarWhenPushed:YES];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.navigationController pushViewController:connectToComputerInstallationViewController animated:YES];
        });
    });

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

            cell.textLabel.text = NSLocalizedString(@"Description of connecting to computer introduction", @"");
        }
    } else {
        cell = [tableView dequeueReusableCellWithIdentifier:imageViewCellIdentifier];

        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:imageViewCellIdentifier];

            UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"add-new-computer"]];

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
