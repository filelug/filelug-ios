#import <Foundation/Foundation.h>
#import <Photos/Photos.h>
#import "UserComputerWithoutManaged.h"

@class MBProgressHUD;
@class FileTransferDao;
@class UIImage;

NS_ASSUME_NONNULL_BEGIN

@interface Utility : NSObject

+ (NSError *)errorWithErrorCode:(NSInteger)code localizedDescription:(NSString *)localizedDescription;

+ (NSError *)generateIncorrectDataFormatError;

+ (NSString *)systemVersion;

+ (BOOL)systemVersionEqualTo:(NSString *)version;

+ (BOOL)systemVersionGreaterThan:(NSString *)version;

+ (BOOL)systemVersionGreaterThanOrEqualTo:(NSString *)version;

+ (BOOL)systemVersionLessThan:(NSString *)version;

+ (BOOL)systemVersionLessThanOrEqualTo:(NSString *)version;

+ (BOOL)desktopVersionEqualTo:(NSString *)version;

+ (BOOL)desktopVersionGreaterThan:(NSString *)version;

+ (BOOL)desktopVersionGreaterThanOrEqualTo:(NSString *)version;

+ (BOOL)desktopVersionLessThan:(NSString *)version;

+ (BOOL)desktopVersionLessThanOrEqualTo:(NSString *)version;

//+ (NSString *)applicationLocale;

// Examples of the result:
// zh-Hant-TW, zh-Hant-HK, zh-Hant-MO(澳門)
// zh-Hans-US
// en, en-US
+ (NSString *)deviceLocale;

+ (NSArray *)deviceAvailableLocales;

// view controller from storyboard with name @"Main"
+ (nonnull id)instantiateViewControllerWithIdentifier:(NSString *)identifier;

+ (id)instantiateViewControllerWithIdentifier:(NSString *)identifier fromStoryboardWithName:(NSString *)name;

// Compose message.
// The message key must contains 2 parameters:
// the first is %d, as the specified status code and
// the second paramter is %@ show the error message composed of the specified error and the response data.
+ (NSString *)messageWithMessagePrefix:(nullable NSString *)messagePrefix statusCode:(NSInteger)statusCode error:(nullable NSError *)error data:(nullable NSData *)data;

// Compose message with status code
+ (NSString *)messageWithMessagePrefix:(NSString *_Nullable)messagePrefix error:(NSError *_Nullable)error data:(NSData *_Nullable)data;

// Compose message without status code
+ (NSString *)messageWithURLResponseStatusCodeAndMessageParameters:(NSString *)messageKey statusCode:(NSInteger)statusCode error:(NSError *)error data:(NSData *)data;

+ (BOOL)validateEmail:(NSString *)candidate;

//+ (NSString *)byteCountToDisplaySize:(double)bytes;
+ (NSString *)byteCountToDisplaySize:(long long int)bytes;

+ (float)divideDenominator:(NSNumber *)denominator byNumerator:(NSNumber *)numerator;

+ (float)divideDenominatorDouble:(double)denominator byNumeratorDouble:(double)numerator;

+ (NSString *)parentPathToTmpUploadFile;

+ (NSString *)tmpUploadFilenameWithFilename:(NSString *)filename;

+ (NSString *)tmpUploadFilePathWithFilename:(NSString *)filename;

+ (NSString *)uuid;

+ (NSString *)generatePurchaseIdFromProductId:(NSString *)productId userId:(NSString *)userId;

+ (NSString *)encodeUsingBase64:(NSString *)rawString;

+ (NSString *)decodeUsingBase64:(NSString *)encodedString;

/* Date related */

+ (NSNumber *)currentJavaTimeMilliseconds;

+ (NSNumber *)currentJavaTimeMillisecondsWithMillisecondsToAdd:(unsigned long)millisecondsToAdd;

+ (NSString *)currentJavaTimeMillisecondsString;

+ (NSDate *)dateFromJavaTimeMillisecondsString:(NSString *)javaTimeString;

+ (NSDate *)dateFromJavaTimeMilliseconds:(NSNumber *)javaTimeNumber;

+ (NSNumber *)javaTimeMillisecondsFromDate:(NSDate *)date;

+ (NSString *)javaTimeMillisecondsStringFromDate:(NSDate *)date;

+ (NSDate *)dateFromString:(NSString *)dateString format:(NSString *)dateFormat;

+ (NSString *)dateStringFromDate:(NSDate *)date;

+ (NSString *)dateStringFromJavaTimeMilliseconds:(NSNumber *)javaTimeNumber;

+ (NSString *)dateStringFromJavaTimeMilliseconds:(NSNumber *)javaTimeNumber format:(NSString *)dateFormat locale:(NSLocale *)locale;

+ (NSString *)dateStringFromDate:(NSDate *)date format:(NSString *)dateFormat locale:(nullable NSLocale *)locale timeZone:(nullable NSTimeZone *)timeZone;

+ (NSString *)generateUploadKeyWithSessionId:(NSString *)sessionId sourceFilename:(NSString *)sourceFilename;

+ (NSString *)generateUploadKeyWithSessionId:(NSString *)sessionId sourceFileIdentifier:(NSString *)identifier;

+ (NSString *)generateDownloadKeyWithSessionId:(NSString *)sessionId realFilePath:(NSString *)realFilePath;

+ (void)updateLastModifiedDate:(NSDate *)lastModifiedDate atPath:(NSString *)fullPath error:(NSError * __autoreleasing *)error;

+ (NSDate *)lastModifiedDateOfFilePath:(NSString *)filePath error:(NSError * __autoreleasing *)error;

+ (unsigned long long int)fileSizeWithAbsolutePath:(NSString *)absolutePath error:(NSError * __autoreleasing *)error;

+ (NSString *)contentTypeFromFilenameExtension:(NSString *)filenameExtension;

// return true only if filePath is a file (not a directory) and exists.
+ (BOOL)fileExistsAtPath:(NSString *)filePath;

// Get the content type of the file with the specified file path.
+ (nullable NSString *)fileContentTypeWithFilePath:(NSString *)filePath;

// Get the content type of the file with the specified file path.
+ (nullable NSString *)fileContentTypeWithFileExtension:(NSString *)fileExtension;

+ (nullable NSString *)utiWithFileExtension:(NSString *)fileExtension;

// get UTI from file content type or mime type
+ (nullable NSString *)utiWithContentType:(NSString *)contentType;

+ (nullable NSString *)fileContentTypeWithFileDataUTI:(NSString *)dataUTI;

+ (BOOL)checkFileIfImageOrVideoWithFileExtension:(NSString *)fileExtension contentType:(NSString *)contentType;

+ (NSURL *)URLWithString:(NSString *)urlString excludedFromBackup:(BOOL)excludedFromBackup;

// Composes the url string of AA Server with parameters, elements all from user-specified values.
// parameters must have encoded first before passed in
+ (NSString *)composeAAServerURLStringWithScheme:(NSString *)scheme domainName:(NSString *)domainName port:(NSInteger)port context:(NSString *)context path:(NSString *)path paramters:(nullable NSDictionary *)parameters;

// Composes the url string of AA Server, elements all from user-specified values.
+ (NSString *)composeAAServerURLStringWithScheme:(NSString *)scheme domainName:(NSString *)domainName port:(NSInteger)port context:(nullable NSString *)context path:(nullable NSString *)path;

// Composes the url string of AA Server, elements all from user-default values except for the path value and parameters.
+ (NSString *)composeAAServerURLStringWithPath:(NSString *)path paramters:(nullable NSDictionary *)parameters;

// Composes the url string of AA Server, elements all from user-default values except for the path value.
+ (NSString *)composeAAServerURLStringWithPath:(NSString *)path;

// Composes the url string of Lug Server with parameters, elements all from user-specified values.
// parameters must have encoded first before passed in
+ (NSString *)composeLugServerURLStringWithScheme:(NSString *)scheme subDomainName:(NSString *)subDomainName domainZoneName:(NSString *)domainZoneName port:(NSInteger)port context:(NSString *)context path:(NSString *)path paramters:(nullable NSDictionary *)parameters;

// Composes the url string of Lug Server, elements all from user-specified values.
+ (NSString *)composeLugServerURLStringWithScheme:(NSString *)scheme subDomainName:(nullable NSString *)subDomainName domainZoneName:(NSString *)domainZoneName port:(NSInteger)port context:(nullable NSString *)context path:(nullable NSString *)path;

// Composes the url string of Lug Server, elements all from user default values except for the path value and parameters.
+ (NSString *)composeLugServerURLStringWithPath:(NSString *)path parameters:(nullable NSDictionary *)parameters;

// Composes the url string of Lug Server, elements all from user default values except for the path value.
+ (NSString *)composeLugServerURLStringWithPath:(NSString *)path;

// The first input like "#00FF00" (#RRGGBB)
+ (UIColor *)colorFromHexString:(NSString *)hexString alpha:(CGFloat)alpha;

//+ (NSString *)deviceName;

// The method checks if the os is 8.0 or later because in os 7.1, the method crash the app.
+ (void)emptyTaskDescriptionForTask:(nullable NSURLSessionTask *)task;

// Required to use main thread to run this method
+ (MBProgressHUD *)prepareProgressViewWithSuperview:(UIView *)superview inTabWithTabName:(nullable NSString *)tabName refreshControl:(nullable UIRefreshControl *)refreshControl;

+ (MBProgressHUD *)prepareAnnularDeterminateProgressViewWithSuperview:(UIView *)superview labelText:(NSString *)labelText;

+ (UIToolbar *)keyboardToolbarWithTarget:(id)target showNextButton:(BOOL)hasNextButton showDoneButton:(BOOL)hasDoneButton nextAction:(nullable SEL)nextAction doneAction:(nullable SEL)doneAction;

+ (BOOL)isEmailFormat:(NSString *)emailCandicate;

+ (NSString *)encryptPassword:(NSString *)rawPassword;

+ (NSString *)encryptSecurityCode:(NSString *)rawSecurityCode;

+ (NSString *)encryptUserId:(NSString *)rawUserId;

+ (void)prepareInitialPreferencesWithUserDefaults:(NSUserDefaults *)userDefaults;

+ (void)deleteUserDataWithUserDefaults:(NSUserDefaults *)userDefaults;

+ (void)deleteComputerDataWithUserDefaults:(NSUserDefaults *)userDefaults;

+ (nullable NSDictionary *)parseJsonAsDictionaryFromData:(NSData *)data error:(NSError * __autoreleasing *)error;

dispatch_source_t createDispatchTimer(double interval, dispatch_queue_t queue, dispatch_block_t block);

+ (void)promptUpdateDesktopWithUserDefaults:(NSUserDefaults *)userDefaults inViewController:(nonnull UIViewController *)viewController;

+ (void)incrementCachedNotificationBadgeNumber;

+ (void)clearCachedNotificationBadgeNumber;

+ (NSNumber *)currentCachedLocalNotificationBadgeNumber;

+ (void)checkDirectoryName:(NSString *)directoryName illegalCharacters:(NSArray *_Nullable *_Nullable)illegalCharacters;

+ (NSString *)generateUploadGroupIdWithFilenames:(nullable NSArray *)filenames;

+ (NSString *)generateDownloadGroupIdWithFilenames:(NSArray *)filenames;

+ (NSString *)stringFromStringArray:(NSArray *)stringArray separator:(NSString *)separator quotedCharacter:(NSString *)quoteCharacter;

// Return YES if the device is iPad; otherwise the device is iPhone
+ (BOOL)isIPad;

+ (BOOL)isIPhone;

+ (BOOL)isDeviceVersion8OrLater;

+ (BOOL)isDeviceVersion9OrLater;

// iOS 9.1 or later, to support such as Live Photo
+ (BOOL)isDeviceVersion91OrLater;

// iOS 10.0 or later
+ (BOOL)isDeviceVersion10OrLater;

// iOS 10.0 or 10.1x do not support resumable download
+ (BOOL)isDeviceVersion10Or10_1;

// iOS 11.0 or later, to use UNUserNotificationCenterDelegate
+ (BOOL)isDeviceVersion11OrLater;

+ (void)selectTextInTextField:(UITextField *)textField range:(NSRange)range;

+ (NSString *)removeIllegalCharactersFromFileName:(NSString *)filename;

// Check if any illegal character exists or contains only punctuation characgters.
+ (BOOL)validFilename:(NSString *)filename;

+ (CGSize)thumbnailSizeForUploadFileTableViewCellImage;

+ (CGSize)thumbnailSizeWithHeight:(CGFloat)height;

+ (NSData *)dataFromImage:(UIImage *)image;

+ (NSUserDefaults *)groupUserDefaults;

+ (UITableViewCell *)tableView:(UITableView *)tableView createOrDequeueCellWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier forIndexPath:(NSIndexPath *)indexPath;

+ (UITableViewCell *)tableView:(UITableView *)tableView createOrDequeueCellWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier;

// alert with only one action
+ (void)viewController:(nullable UIViewController *)viewController alertWithMessageTitle:(NSString *)messageTitle messageBody:(NSString *)messageBody actionTitle:(NSString *)actionTitle delayInSeconds:(double)delayInSeconds actionHandler:(void (^ _Nullable)(UIAlertAction *action))actionHandler;

// alert with one action, and one cancel action if containsCancelAction is YES
+ (void)viewController:(nullable UIViewController *)viewController alertWithMessageTitle:(NSString *)messageTitle messageBody:(NSString *)messageBody actionTitle:(NSString *)actionTitle containsCancelAction:(BOOL)containsCancelAction delayInSeconds:(double)delayInSeconds actionHandler:(void (^ _Nullable)(UIAlertAction *action))actionHandler;

+ (void)viewController:(UIViewController *)viewController alertWithMessageTitle:(NSString *)messageTitle messageBody:(NSString *)messageBody actionTitle:(NSString *)actionTitle containsCancelAction:(BOOL)containsCancelAction cancelTitle:(NSString *)cancelTitle delayInSeconds:(double)delayInSeconds actionHandler:(void (^ _Nullable)(UIAlertAction *action))actionHandler cancelHandler:(void (^ _Nullable)(UIAlertAction *action))cancelHandler;

+ (void)moveExternalDirectoryToAppGroupDirectory;

+ (void)updateFileTransferLocalPathToRelativePath;

+ (void)moveDownloadFileToAppGroupDirectory;

// For the first time APP with version 1.5.1 starts up,
// to assign FileTransfers without FileDownloadGroup, for each UserComputer
// and delete FileTransfers without status of success
+ (void)createFileDownloadGroupToNonAssignedFileTransfersWithEachUserComputerWithUserDefaults:(NSUserDefaults *)userDefaults;

+ (void)copyHierarchicalModelTypeToSectionNameWithUserDefaults:(NSUserDefaults *)userDefaults;

+ (void)moveUploadSettingsFromArrayToStringWithUserDefaults:(NSUserDefaults *)userDefaults;

// Delete all AssetFiles for source type of ASSET_FILE_SOURCE_TYPE_SHARED_FILE but no value in column downloadedFileTransferKey.
// It won't do again if ever did before
+ (void)deleteAssetFilesWithSharedFileSourceTypeButNoDownloadedTransferKeyWithUserDefaults:(NSUserDefaults *)userDefaults;

+ (PHImageRequestOptions *)imageRequestOptionsWithAsset:(PHAsset *)asset;

+ (CGRect)prepareRectWithAsset:(PHAsset *)asset;

+ (void)requestAssetThumbnailWithAsset:(PHAsset *)asset resizedToSize:(CGSize)resizedToSize resultHandler:(void (^)(UIImage *_Nullable result))resultHandler;

+ (NSString *)backgroundUploadIdentifierForFilelug;

+ (NSString *)backgroundUploadIdentifierForShareExtension;

+ (NSString *)backgroundDownloadIdentifierForFilelug;

+ (NSString *)backgroundDownloadIdentifierForDocumentProviderExtension;

+ (void)addTapGestureRecognizerForImageView:(UIImageView *)imageView withTarget:(id)target action:(SEL)action;

+ (NSString *)convertFileTransferLocalPath:(NSString *)localPath toRelativePathWithUserComputerId:(NSString *)userComputerId;

+ (NSString *)applicationSupportDirectoryWithFileManager:(NSFileManager *)fileManager;

// Return NO (the same) if both strings are nil
+ (BOOL)string:(NSString *)string1 notTheSameWith:(NSString *)string2;

// Return NO (the same) if both numbers are nil
+ (BOOL)number:(NSNumber *)number1 notTheSameWith:(NSNumber *)number2;

// This is a debug method to find out the specified NSURLSessionTaskState
+ (void)logTransferStateWithTaskState:(NSURLSessionTaskState)taskState;

+ (void)logMediaTypeWithMediaType:(PHAssetMediaType)mediaType mediaSubType:(PHAssetMediaSubtype)mediaSubtype completionHandler:(void(^)(NSString *mediaTypeAsString, NSString *mediaSubtypeAsString))completionHandler;

+ (void)copyFileWithSourceFilePath:(NSString *)sourceFilePath startFromByteIndex:(NSNumber *)startByteIndex toDestinationFilePath:(NSString *)destinationFilePath completionHandler:(void (^)(NSError *))completionHandler;

+ (void)copyFileWithSourceData:(NSData *)sourceData startFromByteIndex:(NSNumber *)startByteIndex toDestinationFilePath:(NSString *)destinationFilePath completionHandler:(void (^)(NSError *))completionHandler;

+ (void)recreateEmptyFileWithfilePath:(NSString *)filePath;

+ (NSString *)generateEmptyFilePathFromTmpUploadFilePath:(NSString *)filePath;

+ (void)updateFileDownloadAndUploadGroupsCreateTimestampToCurrentTimestamp;

+ (void)alertEmptyUserSessionFromViewController:(nonnull UIViewController *)viewController connectNowHandler:(void (^ _Nullable)(UIAlertAction *connectNowAction))connectNowHandler connectLaterHandler:(void (^ _Nullable)(UIAlertAction *connectLaterAction))connectLaterHandler;

+ (void)promptActionSheetToChooseComputerNameWithAlertControllerTitle:(NSString *_Nonnull)alertControllerTitle
                                               availableUserComputers:(NSArray<UserComputerWithoutManaged *> *_Nonnull)availableUserComputers
                                                     inViewController:(UIViewController *_Nonnull)viewController
                                                           sourceView:(UIView *_Nullable)sourceView
                                                           sourceRect:(CGRect)sourceRect
                                                        barButtonItem:(UIBarButtonItem *_Nullable)barButtonItem
                                                     allowNewComputer:(BOOL)allowNewComputer
                          onSelectComputerNameWithUserComputerHandler:(void (^ _Nullable)(UserComputerWithoutManaged *))selectComputerNameHandler
                                           onSelectNewComputerHandler:(void (^ _Nullable)(void))selectNewComputerHandler;

// prompt alert for extensions

+ (void)alertInExtensionEmptyUserSessionFromViewController:(UIViewController *)viewController completion:(void (^ _Nullable)(void))completion;

+ (nullable NSString *)prepareDeviceTokenJsonWithUserDefaults:(NSUserDefaults *)userDefaults;

+ (NSString *)generateVerificationWithUserId:(NSString *)userId computerId:(NSNumber *)computerId;

+ (BOOL)needShowStartupViewController;

+ (NSString *)generateVerificationWithAuthorizationCode:(NSString *)authorizationCode locale:(NSString *)locale;

+ (NSString *)generateVerificationWithCountryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber;

+ (BOOL)shouldHideLoginToDemoAccount;

+ (void)viewController:(UIViewController *_Nonnull)viewController useNavigationLargeTitles:(BOOL)useNavigationLargeTitles;

@end

NS_ASSUME_NONNULL_END
