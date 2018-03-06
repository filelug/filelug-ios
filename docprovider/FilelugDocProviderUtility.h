@class UIViewController;

NS_ASSUME_NONNULL_BEGIN

@interface FilelugDocProviderUtility : NSObject

// view controller from storyboard with name @"MainInterface"
+ (id)instantiateViewControllerWithIdentifier:(NSString *)identifier;

+ (NSString *)docProviderFileRootPathWithDocumentStorageURL:(NSURL *)documentStorageURL userComputerId:(NSString *)userComputerId;

// downloadedFileLocalPath is the locally relative path of the downloaded file
+ (NSString *)docProviderFilePathWithDocumentStorageURL:(NSURL *)documentStorageURL userComputerId:(NSString *)userComputerId downloadedFileLocalPath:(NSString *)downloadedFileLocalPath;

+ (BOOL)filename:(NSString *)filename conformToValidTypes:(NSArray *)validTypes;

@end

NS_ASSUME_NONNULL_END
