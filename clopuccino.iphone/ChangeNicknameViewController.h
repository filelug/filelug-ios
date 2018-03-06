#import <UIKit/UIKit.h>

@interface ChangeNicknameViewController : UITableViewController <UITextFieldDelegate, ProcessableViewController>

@property(nonatomic, strong) NSString *currentNickname;

@property(nonatomic, strong) NSString *changeToNickname;

@end
