#import <UIKit/UIKit.h>

@interface UploadExternalFileViewController : UITableViewController <UploadDescriptionDataSource, ProcessableViewController>

@property(nonatomic, weak) IBOutlet UIBarButtonItem *uploadBarButton;

@property(nonatomic, strong) NSString *directory;

// Elements of type NSString, representing the absolute file path.
@property(nonatomic, strong) NSMutableArray *absolutePaths;

#pragma mark - UploadDescriptionDataSource

@property(nonatomic, strong) UploadDescriptionService *uploadDescriptionService;

- (BOOL)needPersistIfChanged;

- (IBAction)upload:(id)sender;

- (IBAction)close:(id)sender;

@end
