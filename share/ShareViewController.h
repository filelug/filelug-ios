@interface ShareViewController : UITableViewController <UploadDescriptionDataSource, ProcessableViewController>

@property(nonatomic, strong) NSExtensionContext *shareExtensionContext;

// original inputItems from extension context, elements of type NSExtensionItem, should not be changed
// If from APP Photos, only one NSExtensionItem and contains multiple attachments,
// each of the attachments is a picture or vedio.
@property(nonatomic, strong) NSArray *extensionItems;

// Elements of type UploadItem, representing the absolute file path.
@property(nonatomic, strong) NSMutableArray *inputItems;

@property(nonatomic, weak) IBOutlet UIBarButtonItem *uploadBarButton;

@property(nonatomic, strong) NSString *directory;

#pragma mark - UploadDescriptionDataSource

@property(nonatomic, strong) UploadDescriptionService *uploadDescriptionService;

- (BOOL)needPersistIfChanged;

- (IBAction)upload:(id)sender;

- (IBAction)close:(id)sender;

@end
