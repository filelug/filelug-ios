#import <Foundation/Foundation.h>

@class UploadDescriptionService;

@protocol UploadDescriptionDataSource <NSObject>

@required

@property(nonatomic, strong) UploadDescriptionService *uploadDescriptionService;

- (BOOL)needPersistIfChanged;

@end
