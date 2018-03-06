#import <UIKit/UIKit.h>

@interface UserProfileViewController : UITableViewController <UITextFieldDelegate, ProcessableViewController>

@property(nonatomic, strong) NSString *nickname;

@property(nonatomic, strong) NSString *email;

@property(nonatomic, strong) NSNumber *showCancelButton;

- (IBAction)updateUserProfile:(id)sender;

@end
