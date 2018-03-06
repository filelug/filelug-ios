#import <UIKit/UIKit.h>
#import "ProcessableViewController.h"

@protocol UploadDescriptionDataSource;


@interface FKEditingPackedUploadDescriptionViewController : UIViewController <UITextViewDelegate, ProcessableViewController>

// The selected type of PackedUploadDescription, wrapping type of NSUInteger
@property(nonatomic, strong) NSNumber *selectedType;

//@property(nonatomic, weak) IBOutlet UIScrollView *scrollView;
@property(nonatomic, weak) IBOutlet UITextView *textView;

@property(nonatomic, weak) IBOutlet UINavigationItem *descriptionNavigationItem;

// FileUploadSummaryViewController or UploadExternalFileViewController
@property(nonatomic, strong) id <UploadDescriptionDataSource> uploadDescriptionDataSource;

- (IBAction)saveText:(id)sender;

- (IBAction)cancel:(id)sender;

@end
