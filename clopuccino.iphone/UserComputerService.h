#import <Foundation/Foundation.h>

@class FileTransferWithoutManaged;
@class UserComputerWithoutManaged;

@interface UserComputerService : NSObject

@property(nonatomic, assign) NSURLRequestCachePolicy cachePolicy;

@property(nonatomic, assign) NSTimeInterval timeInterval;

- (id)initWithCachePolicy:(NSURLRequestCachePolicy)policy timeInterval:(NSTimeInterval)interval;

- (void)findAvailableComputersWithSession:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler;

//- (void)findAvailableComputersWithCountryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber password:(NSString *)password nickname:(NSString *)nickname completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler;

// If the computer id in preferences not exists in the available computers, delete the computer-related data from preferences.
// handler invokes only if the computer id in preferences did deleted.
- (void)deleteComputerDataInUserDefautsIfComputerIdNotFoundInUserComputers:(NSArray<UserComputerWithoutManaged *> *)userComputers didDeletedHandler:(void (^)(void))handler;

- (void)updateUserComputerProfilesWithProfiles:(NSDictionary *)profiles session:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler;

- (void)connectToComputerWithUserId:(NSString *)userId computerId:(NSNumber *)computerId showHidden:(NSNumber *)showHidden session:(NSString *)sessionId successHandler:(void (^)(NSURLResponse *, NSData *))successHandler failureHandler:(void (^)(NSData *, NSURLResponse *, NSError *))failureHandler;

- (void)changeShowHiddenForCurrentSessionWithShowHidden:(BOOL)showHidden completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler;

- (void)changeComputerNameForCurrentSessionWithNewComputerName:(NSString *)computerName completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler;

- (void)createComputerWithQRCode:(NSString *)qrCode session:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler;

- (void)deleteComputerWithUserId:(NSString *)userId computerId:(NSNumber *)computerId session:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler;

- (void)findSuccessfullyDownloadedFileForUserComputer:(NSString *)userComputerId completionHandler:(void (^)(FileTransferWithoutManaged *))completionHandler;

@end
