#import <UIKit/UIKit.h>

@interface ChangeEmailViewController : UITableViewController <UITextFieldDelegate, ProcessableViewController>

@property(nonatomic, strong) NSString *email;

//@property(nonatomic, strong) NSString *currentEmail;
//
//@property(nonatomic, strong) NSString *changeToEmail;
//
//@property(nonatomic, strong) NSString *securityCode;
//
//- (IBAction)enterPassword:(id)sender;
//
//- (IBAction)changeEmail:(id)sender;

@end
