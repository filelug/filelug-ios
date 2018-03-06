#import <UIKit/UIKit.h>

@interface RootDirectoryViewController : UITableViewController <ProcessableViewController>

@property (nonatomic, strong) UIViewController *fromViewController;

// show only the directory (ie, no files) for the sub-directory of the root directory.
@property(nonatomic, assign) BOOL directoryOnly;

- (void)addDirectory:(UITapGestureRecognizer *)recognizer;

- (void)prepareDirectoriesWithTryAgainIfFailed:(BOOL)tryAgainIfFailed;

@end
