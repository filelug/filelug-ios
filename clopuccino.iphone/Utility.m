#import <MobileCoreServices/MobileCoreServices.h>
#import <Photos/Photos.h>
#import "DirectoryService.h"
#import "Utility.h"
#import "NSString+Utlities.h"
#import "MBProgressHUD.h"
#import "UserDao.h"
#import "FileTransferDao.h"
#import "FilePreviewController.h"
#import "UIColor+Filelug.h"
#import "HierarchicalModelWithoutManaged.h"
#import "AssetFileDao.h"
#import "HierarchicalModelDao.h"
#import "HierarchicalModel+CoreDataClass.h"
#import "UserComputerDao.h"
#import "UserComputer+CoreDataClass.h"
#import "FileTransfer+CoreDataClass.h"
#import "FileDownloadGroupDao.h"
#import "DownloadNotificationService.h"
#import "FileUploadGroup+CoreDataClass.h"
#import "UIAlertController+ShowWithoutViewController.h"
#import "UIViewController+Visibility.h"
#import "FileDownloadGroup+CoreDataClass.h"

#define IOS_VERSION [[UIDevice currentDevice] systemVersion]
#define DEVICE_VERSION ([[UIDevice currentDevice] systemVersion])

@implementation Utility {
}

static long long int const ONE_KB = 1024;
static long long int const ONE_MB = ONE_KB * ONE_KB;
static long long int const ONE_GB = ONE_KB * ONE_MB;

static NSUserDefaults *groupUserDefaults;

+ (NSError *)errorWithErrorCode:(NSInteger)code localizedDescription:(NSString *)localizedDescription {
    NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
    [errorDetail setValue:localizedDescription forKey:NSLocalizedDescriptionKey];

    NSError *error = [NSError errorWithDomain:APP_GROUP_NAME code:code userInfo:errorDetail];

    return [error copy];
}

+ (NSError *)generateIncorrectDataFormatError {
    NSString *errorMessage = NSLocalizedString(@"Incorrect response data", @"");

    NSError *incorrectResponseDataFormatError = [Utility errorWithErrorCode:ERROR_CODE_INCORRECT_DATA_FORMAT_KEY localizedDescription:errorMessage];

    return incorrectResponseDataFormatError;
}

+ (NSString *)systemVersion {
    return [[UIDevice currentDevice] systemVersion];
}

+ (BOOL)systemVersionEqualTo:(NSString *)version {
    return [[self systemVersion] compare:version options:NSNumericSearch] == NSOrderedSame;
}

+ (BOOL)systemVersionGreaterThan:(NSString *)version {
    return [[self systemVersion] compare:version options:NSNumericSearch] == NSOrderedDescending;
}

+ (BOOL)systemVersionGreaterThanOrEqualTo:(NSString *)version {
    return [[self systemVersion] compare:version options:NSNumericSearch] != NSOrderedAscending;
}

+ (BOOL)systemVersionLessThan:(NSString *)version {
    return [[self systemVersion] compare:version options:NSNumericSearch] == NSOrderedAscending;
}

+ (BOOL)systemVersionLessThanOrEqualTo:(NSString *)version {
    return [[self systemVersion] compare:version options:NSNumericSearch] != NSOrderedDescending;
}

+ (BOOL)desktopVersionEqualTo:(NSString *)version {
    NSUserDefaults *userDefaults = [self groupUserDefaults];
    NSString *desktopVersion = [userDefaults stringForKey:USER_DEFAULTS_KEY_DESKTOP_VERSION];
    
    return desktopVersion && [desktopVersion compare:version options:NSNumericSearch] == NSOrderedSame;
}

+ (BOOL)desktopVersionGreaterThan:(NSString *)version {
    NSUserDefaults *userDefaults = [self groupUserDefaults];
    NSString *desktopVersion = [userDefaults stringForKey:USER_DEFAULTS_KEY_DESKTOP_VERSION];
    
    return desktopVersion && [desktopVersion compare:version options:NSNumericSearch] == NSOrderedDescending;
}

+ (BOOL)desktopVersionGreaterThanOrEqualTo:(NSString *)version {
    NSUserDefaults *userDefaults = [self groupUserDefaults];
    
    NSString *desktopVersion = [userDefaults stringForKey:USER_DEFAULTS_KEY_DESKTOP_VERSION];
    
    return desktopVersion && [desktopVersion compare:version options:NSNumericSearch] != NSOrderedAscending;
}

+ (BOOL)desktopVersionLessThan:(NSString *)version {
    NSUserDefaults *userDefaults = [self groupUserDefaults];
    
    NSString *desktopVersion = [userDefaults stringForKey:USER_DEFAULTS_KEY_DESKTOP_VERSION];
    
    return desktopVersion && [desktopVersion compare:version options:NSNumericSearch] == NSOrderedAscending;
}

+ (BOOL)desktopVersionLessThanOrEqualTo:(NSString *)version {
    NSUserDefaults *userDefaults = [self groupUserDefaults];
    
    NSString *desktopVersion = [userDefaults stringForKey:USER_DEFAULTS_KEY_DESKTOP_VERSION];
    
    return desktopVersion && [desktopVersion compare:version options:NSNumericSearch] != NSOrderedDescending;
}

+ (NSString *)deviceLocale {
    return [NSLocale preferredLanguages][0];
}

+ (NSArray *)deviceAvailableLocales {
    NSUserDefaults *userDefaults = [self groupUserDefaults];

    return [userDefaults arrayForKey:@"AppleLanguages"];
}

+ (id)instantiateViewControllerWithIdentifier:(NSString *)identifier {
    return [self instantiateViewControllerWithIdentifier:identifier fromStoryboardWithName:@"Main"];
}

+ (id)instantiateViewControllerWithIdentifier:(NSString *)identifier fromStoryboardWithName:(NSString *)name {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:name bundle:nil];
    return [storyboard instantiateViewControllerWithIdentifier:identifier];
}

+ (NSString *)messageWithMessagePrefix:(NSString *_Nullable)messagePrefix statusCode:(NSInteger)statusCode error:(NSError *_Nullable)error data:(NSData *_Nullable)data {
    NSMutableString *message = [[NSMutableString alloc] init];
    
    if (error) {
        [message appendString:[NSString stringWithFormat:@"\n%@", [error localizedDescription]]];
    }
    
    if (data) {
        NSString *responseData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

        [message appendString:[NSString stringWithFormat:@"\n%@", responseData]];
    }
    
    // Move the status code to the very last line of the prompt message
    if (messagePrefix && messagePrefix.length > 0) {
        return [NSString stringWithFormat:@"%@\n%@\n%@%d", messagePrefix, message, NSLocalizedString(@"Status code:", @""), [@(statusCode) intValue]];
    } else {
        return [NSString stringWithFormat:@"%@\n%@%d", message, NSLocalizedString(@"Status code:", @""), [@(statusCode) intValue]];
    }
}

+ (NSString *)messageWithMessagePrefix:(NSString *_Nullable)messagePrefix error:(NSError *_Nullable)error data:(NSData *_Nullable)data {
    NSMutableString *message = [[NSMutableString alloc] init];
    
    if (error) {
        [message appendString:[error localizedDescription]];
    }
    
    if (data) {
        NSString *responseData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        [message appendString:@"\n"];
        [message appendString:responseData];
    }
    
    // Move the status code to the very last line of the prompt message
    if (messagePrefix && messagePrefix.length > 0) {
        return [NSString stringWithFormat:@"%@\n%@", messagePrefix, message];
    } else {
        return [NSString stringWithFormat:@"%@", message];
    }
}

+ (NSString *)messageWithURLResponseStatusCodeAndMessageParameters:(NSString *)messageKey statusCode:(NSInteger)statusCode error:(NSError *)error data:(NSData *)data {
    NSMutableString *message = [[NSMutableString alloc] init];
    
    if (error) {
        [message appendString:[error localizedDescription]];
    }
    
    if (data) {
        NSString *responseData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        [message appendString:@"\n"];
        [message appendString:responseData];
    }
    
    return [NSString stringWithFormat:NSLocalizedString(messageKey, @""), statusCode, message];
}

+ (BOOL)validateEmail:(NSString *)candidate {
    NSString *emailRegex =
    @"(?:[a-z0-9!#$%\\&'*+/=?\\^_`{|}~-]+(?:\\.[a-z0-9!#$%\\&'*+/=?\\^_`{|}"
    @"~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\"
    @"x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-z0-9](?:[a-"
    @"z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5"
    @"]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-"
    @"9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21"
    @"-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])";
    
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES[c] %@", emailRegex];
    
    return [emailTest evaluateWithObject:candidate];
}

+ (NSString *)byteCountToDisplaySize:(long long int)bytes {
    NSString *displaySize;

    if (bytes / ONE_GB > 0) {
        displaySize = [NSString stringWithFormat:@"%.2f GB", (double) bytes / ONE_GB];
    } else if (bytes / ONE_MB > 0) {
        displaySize = [NSString stringWithFormat:@"%.2f MB", (double) bytes / ONE_MB];
    } else if (bytes / ONE_KB > 0) {
        displaySize = [NSString stringWithFormat:@"%.2f KB", (double) bytes / ONE_KB];
    } else {
        displaySize = [NSString stringWithFormat:@"%d bytes", (int) bytes];
    }

    return displaySize;
}

// 分母(denominator), 分子(numerator)
+ (float)divideDenominator:(NSNumber *)denominator byNumerator:(NSNumber *)numerator {
    if (!denominator) {
        return 0.0f;
    }
    
    //分母
    double denominatorDouble = [denominator doubleValue];
    
    if (denominatorDouble == 0) {
        return 0.0f;
    }
    
    //分子
    double numeratorDouble = (numerator ? [numerator doubleValue] : 0.0);
    
    return [[NSString stringWithFormat:@"%.2f", (numeratorDouble / denominatorDouble)] floatValue];
}

// 分母(denominator), 分子(numerator)
+ (float)divideDenominatorDouble:(double)denominator byNumeratorDouble:(double)numerator {
    //分母
    if (denominator == 0) {
        return 0.0f;
    }

    //分子
    return [[NSString stringWithFormat:@"%.2f", (numerator / denominator)] floatValue];
}

+ (NSString *)parentPathToTmpUploadFile {
    return NSTemporaryDirectory();
}

+ (NSString *)tmpUploadFilenameWithFilename:(NSString *)filename {
    NSString *tmpFilename;
    
    NSString *extension = [[filename stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] pathExtension];
    
    if (extension && [extension length] > 0) {
        tmpFilename = [NSString stringWithFormat:@"%@%@_%@.%@", TMP_UPLOAD_FILE_PREFIX, [[filename lastPathComponent] stringByDeletingPathExtension], [Utility uuid], extension];
    } else {
        tmpFilename = [NSString stringWithFormat:@"%@%@_%@", TMP_UPLOAD_FILE_PREFIX, [[filename lastPathComponent] stringByDeletingPathExtension], [Utility uuid]];
    }
    
    return tmpFilename;
}

+ (NSString *)tmpUploadFilePathWithFilename:(NSString *)filename {
    NSString *path;
    
    path = [[Utility parentPathToTmpUploadFile] stringByAppendingPathComponent:[self tmpUploadFilenameWithFilename:filename]];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if (![fileManager fileExistsAtPath:path]) {
        return path;
    } else {
        return [Utility tmpUploadFilePathWithFilename:filename];
    }
}

+ (NSString *)uuid {
    CFUUIDRef cfuuid = CFUUIDCreate(kCFAllocatorDefault);
    
    return (NSString *) CFBridgingRelease(CFUUIDCreateString(kCFAllocatorDefault, cfuuid));
}

+ (NSString *)generatePurchaseIdFromProductId:(NSString *)productId userId:(NSString *)userId {
    return [NSString stringWithFormat:@"%@%@%@%@%@%@%@",
            productId, PURCHASE_ID_DELIMITERS,
            userId, PURCHASE_ID_DELIMITERS,
            [self currentJavaTimeMillisecondsString], PURCHASE_ID_DELIMITERS,
            [self uuid]];
}

+ (NSString *)encodeUsingBase64:(NSString *)rawString {
    NSData *data = [rawString dataUsingEncoding:NSUTF8StringEncoding];
    
    return [data base64EncodedStringWithOptions:0];
}

+ (NSString *)decodeUsingBase64:(NSString *)encodedString {
    NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:encodedString options:0];
    
    return [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
}

/* Date related */

// simple version of javaTimeMillisecondsFromDate: that use the current date as the parameter
+ (NSNumber *)currentJavaTimeMilliseconds {
    long long currentTimeMillis = (long long) [[NSDate date] timeIntervalSince1970] * 1000;
    
    return @(currentTimeMillis);
}

+ (NSNumber *)currentJavaTimeMillisecondsWithMillisecondsToAdd:(unsigned long)millisecondsToAdd {
    long long currentTimeMillis = ((long long) [[NSDate date] timeIntervalSince1970] * 1000) + millisecondsToAdd;
    
    return @(currentTimeMillis);
}

// simple version of javaTimeMillisecondsFromDate: that use the current date as the parameter
+ (NSString *)currentJavaTimeMillisecondsString {
    long long currentTimeMillis = (long long) [[NSDate date] timeIntervalSince1970] * 1000;
    
    return [NSString stringWithFormat:@"%qi", currentTimeMillis];
}

+ (NSDate *)dateFromJavaTimeMillisecondsString:(NSString *)javaTimeString {
    double javaTimeDouble = [javaTimeString doubleValue];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:javaTimeDouble / 1000];
    
    return date;
}

// reverse of javaTimeMillisecondsFromDate:
+ (NSDate *)dateFromJavaTimeMilliseconds:(NSNumber *)javaTimeNumber {
    double javaTimeDouble = [javaTimeNumber doubleValue];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:javaTimeDouble / 1000];
    
    return date;
}

// reverse of dateFromJavaTimeMilliseconds:
+ (NSNumber *)javaTimeMillisecondsFromDate:(NSDate *)date {
    NSTimeInterval timeInSeconds = [date timeIntervalSince1970];
    long long timeInMilliseconds = (long long) (timeInSeconds * 1000);
    
    return @(timeInMilliseconds);
}

+ (NSString *)javaTimeMillisecondsStringFromDate:(NSDate *)date {
    NSNumber *javaTimeNumber = [Utility javaTimeMillisecondsFromDate:date];
    
    return [NSString stringWithFormat:@"%qi", [javaTimeNumber longLongValue]];
}

+ (NSDate *)dateFromString:(NSString *)dateString format:(NSString *)dateFormat {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:dateFormat];
    
    return [dateFormatter dateFromString:dateString];
}

+ (NSString *)dateStringFromDate:(NSDate *)date {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterShortStyle];
    [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];

    NSLocale *locale = [NSLocale autoupdatingCurrentLocale];
    [dateFormatter setLocale:locale];
    
    return [dateFormatter stringFromDate:date];
}

+ (NSString *)dateStringFromJavaTimeMilliseconds:(NSNumber *)javaTimeNumber {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterShortStyle];
    [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    
    NSLocale *locale = [NSLocale autoupdatingCurrentLocale];
    [dateFormatter setLocale:locale];
    
    return [dateFormatter stringFromDate:[self dateFromJavaTimeMilliseconds:javaTimeNumber]];
}

+ (NSString *)dateStringFromJavaTimeMilliseconds:(NSNumber *)javaTimeNumber format:(NSString *)dateFormat locale:(NSLocale *)locale {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:dateFormat];
    [dateFormatter setLocale:locale];

    return [dateFormatter stringFromDate:[self dateFromJavaTimeMilliseconds:javaTimeNumber]];
}

+ (NSString *)dateStringFromDate:(NSDate *)date format:(NSString *)dateFormat locale:(nullable NSLocale *)locale timeZone:(nullable NSTimeZone *)timeZone {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:dateFormat];

    if (locale) {
        [dateFormatter setLocale:locale];
    }

    if (timeZone) {
        [dateFormatter setTimeZone:timeZone];
    }

    return [dateFormatter stringFromDate:date];
}

+ (NSString *)generateUploadKeyWithSessionId:(NSString *)sessionId sourceFilename:(NSString *)sourceFilename {
    return [NSString stringWithFormat:@"%@+%@+up+%@", sessionId, [sourceFilename MD5], [Utility uuid]];
}

+ (NSString *)generateUploadKeyWithSessionId:(NSString *)sessionId sourceFileIdentifier:(NSString *)identifier {
    return [NSString stringWithFormat:@"%@+%@+up+%@", sessionId, [identifier MD5], [Utility uuid]];
}

+ (NSString *)generateDownloadKeyWithSessionId:(NSString *)sessionId realFilePath:(NSString *)realFilePath {
    return [NSString stringWithFormat:@"%@+%@+down+%@", sessionId, [realFilePath MD5], [Utility uuid]];
}

+ (void)updateLastModifiedDate:(NSDate *)lastModifiedDate atPath:(NSString *)fullPath error:(NSError * __autoreleasing *)error {
    if (lastModifiedDate) {
        NSDictionary *attributes = @{@"NSFileCreationDate" : lastModifiedDate, @"NSFileModificationDate" : lastModifiedDate};

        NSFileManager *fileManager = [NSFileManager defaultManager];

        [fileManager setAttributes:attributes ofItemAtPath:fullPath error:error];
    }
}

+ (NSDate *)lastModifiedDateOfFilePath:(NSString *)filePath error:(NSError * __autoreleasing *)error {
    NSString *unescapedAbsolutePath = [filePath stringByRemovingPercentEncoding];

    if (!unescapedAbsolutePath) {
        unescapedAbsolutePath = filePath;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSDictionary<NSString *, id> *attributes = [fileManager attributesOfItemAtPath:unescapedAbsolutePath error:error];

    return attributes ? attributes[@"NSFileModificationDate"] : nil;
}

+ (unsigned long long int)fileSizeWithAbsolutePath:(NSString *)absolutePath error:(NSError *_Nullable __autoreleasing *_Nullable)error {
    NSString *unescapedAbsolutePath = [absolutePath stringByRemovingPercentEncoding];
    
    if (!unescapedAbsolutePath) {
        unescapedAbsolutePath = absolutePath;
    }
    
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:unescapedAbsolutePath error:error];
    
    unsigned long long int fileSize;
    if (fileAttributes) {
        fileSize = [fileAttributes fileSize];
    } else {
        fileSize = 0;
    }
    
    return fileSize;
}

+ (NSString *)contentTypeFromFilenameExtension:(NSString *)filenameExtension {
    NSString *mimeType;

    if (filenameExtension && filenameExtension.length > 0) {
        CFStringRef pathExtension = (__bridge_retained CFStringRef) filenameExtension;
        CFStringRef type = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension, NULL);
        CFRelease(pathExtension);

        // The UTI can be converted to a mime type:

        mimeType = (__bridge_transfer NSString *) UTTypeCopyPreferredTagWithClass(type, kUTTagClassMIMEType);

        if (type != NULL) {
            CFRelease(type);
        }
    }

    if (!mimeType) {
        NSString *extensionWithDot = [NSString stringWithFormat:@".%@", filenameExtension];

        mimeType = [HierarchicalModelWithoutManaged bundleDirectoryMimetypeWithSuffix:extensionWithDot];
    }
    
    return mimeType ? mimeType : @"application/octet-stream";
}

+ (BOOL)fileExistsAtPath:(NSString *)filePath {
    BOOL isDirectory;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDirectory];
    
    return exists && !isDirectory;
}

+ (NSString *)fileContentTypeWithFilePath:(NSString *)filePath {
    NSString *fileExtension = [filePath pathExtension];

    return [self fileContentTypeWithFileExtension:fileExtension];
}

+ (NSString *)fileContentTypeWithFileExtension:(NSString *)fileExtension {
    NSString *UTI = [self utiWithFileExtension:fileExtension];

    NSString *contentType;

    if (UTI) {
        contentType = (__bridge_transfer NSString *) UTTypeCopyPreferredTagWithClass((__bridge CFStringRef) UTI, kUTTagClassMIMEType);
    }

    return contentType;
}

+ (nullable NSString *)utiWithFileExtension:(NSString *)fileExtension {
    return (__bridge_transfer NSString *) UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef) fileExtension, NULL);
}

+ (nullable NSString *)utiWithContentType:(NSString *)contentType {
    return (__bridge_transfer NSString *) UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef) contentType, NULL);
}

+ (NSString *)fileContentTypeWithFileDataUTI:(NSString *)dataUTI {
    NSString *contentType = (__bridge_transfer NSString *) UTTypeCopyPreferredTagWithClass((__bridge CFStringRef) dataUTI, kUTTagClassMIMEType);
    
    return contentType;
}

+ (BOOL)checkFileIfImageOrVideoWithFileExtension:(NSString *)fileExtension contentType:(NSString *)contentType {
    NSString *fileUTI;

    if (fileExtension && fileExtension.length > 0) {
        fileUTI = [Utility utiWithFileExtension:fileExtension];
    }

    if (!fileUTI && contentType && contentType.length > 0) {
        fileUTI = [Utility utiWithContentType:contentType];
    }

    return fileUTI && (UTTypeConformsTo((__bridge CFStringRef) fileUTI, kUTTypeImage) || UTTypeConformsTo((__bridge CFStringRef) fileUTI, kUTTypeMovie));
}

+ (NSURL *)URLWithString:(NSString *)urlString excludedFromBackup:(BOOL)excludedFromBackup {
    NSURL *url = [NSURL URLWithString:urlString];
    
    /* error when url is no scheme. message:
     * CFURLSetResourcePropertyForKey failed because it was passed this URL which has no scheme
     */
    if (excludedFromBackup && [[url scheme] length] > 0) {
        NSError *error;
        [url setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:&error];
        
        if (error) {
            NSLog(@"Failed to set NSURLIsExcludedFromBackupKey to YES. %@\n%@", [error userInfo], error);
        }
    }
    
    return url;
}

+ (NSString *)composeAAServerURLStringWithScheme:(NSString *)scheme domainName:(NSString *)domainName port:(NSInteger)port context:(NSString *)context path:(NSString *)path paramters:(nullable NSDictionary *)parameters {
    NSString *urlString;

    if (context && context.length > 0) {
        urlString = [NSString stringWithFormat:@"%@://%@:%d/%@/%@", scheme, domainName, (int) port, context, path];
    } else {
        urlString =  [NSString stringWithFormat:@"%@://%@:%d/%@", scheme, domainName, (int) port, path];
    }

    if (parameters && [parameters count] > 0) {
        NSMutableString *parametersString = [NSMutableString string];

        NSArray<NSString *> *keys = [parameters allKeys];

        for (NSString *key in keys) {
            NSString *value = parameters[key];
            [parametersString appendFormat:@"%@=%@&", key, value];
        }

        // delete the last &
        NSUInteger lastAndIndex = [parametersString length] - 1;

        urlString = [NSString stringWithFormat:@"%@?%@", urlString, [parametersString substringToIndex:lastAndIndex]];
    }

    return urlString;
}

+ (NSString *)composeAAServerURLStringWithScheme:(NSString *)scheme domainName:(NSString *)domainName port:(NSInteger)port context:(NSString *)context path:(NSString *)path {
    return [self composeAAServerURLStringWithScheme:scheme domainName:domainName port:port context:context path:path paramters:nil];
}

+ (NSString *)composeAAServerURLStringWithPath:(NSString *)path paramters:(nullable NSDictionary *)parameters {
    NSUserDefaults *userDefaults = [self groupUserDefaults];

    NSString *scheme = [userDefaults stringForKey:USER_DEFAULTS_KEY_DOMAIN_URL_SCHEME];
    NSString *domainName = [userDefaults stringForKey:USER_DEFAULTS_KEY_DOMAIN_NAME];
    NSInteger port = [userDefaults integerForKey:USER_DEFAULTS_KEY_PORT];
    NSString *context = [userDefaults stringForKey:USER_DEFAULTS_KEY_CONTEXT_PATH];

    return [self composeAAServerURLStringWithScheme:scheme domainName:domainName port:port context:context path:path paramters:parameters];
}

+ (NSString *)composeAAServerURLStringWithPath:(NSString *)path {
    return [self composeAAServerURLStringWithPath:path paramters:nil];
}

+ (NSString *)composeLugServerURLStringWithScheme:(NSString *)scheme subDomainName:(NSString *)subDomainName domainZoneName:(NSString *)domainZoneName port:(NSInteger)port context:(NSString *)context path:(NSString *)path paramters:(nullable NSDictionary *)parameters {
    if ([subDomainName isEqualToString:AA_SERVER_ID_AS_LUG_SERVER]) {
        return [self composeAAServerURLStringWithScheme:scheme domainName:CREPO_DOMAIN_NAME port:port context:context path:path paramters:parameters];
    } else {
        NSString *urlString;

        if (context && context.length > 0) {
            urlString = [NSString stringWithFormat:@"%@://%@.%@:%d/%@/%@", scheme, subDomainName, domainZoneName, (int) port, context, path];
        } else {
            urlString = [NSString stringWithFormat:@"%@.%@://%@:%d/%@", scheme, subDomainName, domainZoneName, (int) port, path];
        }

        if (parameters && [parameters count] > 0) {
            NSMutableString *parametersString = [NSMutableString string];

            NSArray<NSString *> *keys = [parameters allKeys];

            for (NSString *key in keys) {
                NSString *value = parameters[key];
                [parametersString appendFormat:@"%@=%@&", key, value];
            }

            // delete the last &
            NSUInteger lastAndIndex = [parametersString length] - 1;

            urlString = [NSString stringWithFormat:@"%@?%@", urlString, [parametersString substringToIndex:lastAndIndex]];
        }

        return urlString;
    }
}

+ (NSString *)composeLugServerURLStringWithScheme:(NSString *)scheme subDomainName:(NSString *)subDomainName domainZoneName:(NSString *)domainZoneName port:(NSInteger)port context:(NSString *)context path:(NSString *)path {
    return [self composeLugServerURLStringWithScheme:scheme subDomainName:subDomainName domainZoneName:domainZoneName port:port context:context path:path paramters:nil];
}

+ (NSString *)composeLugServerURLStringWithPath:(NSString *)path parameters:(nullable NSDictionary *)parameters {
    NSUserDefaults *userDefaults = [self groupUserDefaults];

    NSString *scheme = [userDefaults stringForKey:USER_DEFAULTS_KEY_DOMAIN_URL_SCHEME];
    NSString *subDomainName = [userDefaults stringForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID];
    NSString *domainZoneName = [userDefaults stringForKey:USER_DEFAULTS_KEY_DOMAIN_ZONE_NAME];
    NSInteger port = [userDefaults integerForKey:USER_DEFAULTS_KEY_PORT];
    NSString *context = [userDefaults stringForKey:USER_DEFAULTS_KEY_CONTEXT_PATH];

    return [self composeLugServerURLStringWithScheme:scheme subDomainName:subDomainName domainZoneName:domainZoneName port:port context:context path:path paramters:parameters];
}

+ (NSString *)composeLugServerURLStringWithPath:(NSString *)path {
    return [self composeLugServerURLStringWithPath:path parameters:nil];
}

// The first input like "#00FF00" (#RRGGBB)
+ (UIColor *)colorFromHexString:(NSString *)hexString alpha:(CGFloat)alpha {
    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner setScanLocation:1]; // bypass '#' character
    [scanner scanHexInt:&rgbValue];
    
    return [UIColor colorWithRed:(CGFloat) (((rgbValue & 0xFF0000) >> 16) / 255.0) green:(CGFloat) (((rgbValue & 0xFF00) >> 8) / 255.0) blue:(CGFloat) ((rgbValue & 0xFF) / 255.0) alpha:alpha];
}

+ (void)emptyTaskDescriptionForTask:(NSURLSessionTask *)task {
    if (task && [self isDeviceVersion8OrLater]) {
        [task setTaskDescription:@""];
    }
}

// Required to use main thread to run this method
+ (MBProgressHUD *)prepareProgressViewWithSuperview:(UIView *)superview inTabWithTabName:(nullable NSString *)tabName refreshControl:(nullable UIRefreshControl *)refreshControl {
    if (refreshControl && [refreshControl isRefreshing]) {
        [refreshControl endRefreshing];
    }

    MBProgressHUD *progressView;

    if (superview) {
        // remove current before adding new one
        [MBProgressHUD hideAllHUDsForView:superview animated:NO];

        progressView = [MBProgressHUD showHUDAddedTo:superview animated:YES];

        // Set to NO to prevent errors like:
        // Assertion failure in -[MBProgressHUD initWithView:], ... reason: 'View must not be nil.'
        progressView.removeFromSuperViewOnHide = NO;
        progressView.backgroundColor = [Utility colorFromHexString:@"#525252" alpha:0.4];
        progressView.color = [UIColor clearColor];

        NSInteger oldHash = progressView.hash;

        double delayInSeconds = 3.0;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (progressView && [progressView hash] == oldHash) {
                    progressView.labelFont = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
                    progressView.labelText = NSLocalizedString(@"Wait for data loading", @"");

                    progressView.detailsLabelFont = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];

                    if (tabName) {
                        progressView.detailsLabelText = [NSString stringWithFormat:NSLocalizedString(@"Detail for data loading", @""), tabName];
                    } else {
                        progressView.detailsLabelText = NSLocalizedString(@"Detail for data loading2", @"");
                    }
                }
            });
        });

        // Now user can hide progressView by press the same tab, so it seems not necessary to do auto hiding.
        // hide if not after seconds of CONNECTION_TIME_INTERVAL
    }

    return progressView;
}

+ (MBProgressHUD *)prepareAnnularDeterminateProgressViewWithSuperview:(UIView *)superview labelText:(NSString *)labelText {
    MBProgressHUD *progressView;

    if (superview) {
        // remove current before adding new one
        [MBProgressHUD hideAllHUDsForView:superview animated:NO];

        progressView = [MBProgressHUD showHUDAddedTo:superview animated:YES];

        progressView.removeFromSuperViewOnHide = NO;
        progressView.backgroundColor = [Utility colorFromHexString:@"#525252" alpha:0.4];
        progressView.color = [UIColor clearColor];
//        progressView.removeFromSuperViewOnHide = YES;
//        progressView.color = [Utility colorFromHexString:@"#525252" alpha:0.4];

        progressView.mode = MBProgressHUDModeAnnularDeterminate;

        progressView.labelFont = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        progressView.labelText = labelText;

        progressView.progress = 0.0f;

        /* hide if not after seconds of CONNECTION_TIME_INTERVAL */
        NSInteger oldHash = progressView.hash;

        dispatch_queue_t gQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

        double delayInSeconds = CONNECTION_TIME_INTERVAL;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, gQueue, ^(void) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (progressView && [progressView hash] == oldHash) {
                    [progressView hide:YES];
                }
            });
        });
    }

    return progressView;
}

+ (UIToolbar *)keyboardToolbarWithTarget:(id)target showNextButton:(BOOL)hasNextButton showDoneButton:(BOOL)hasDoneButton nextAction:(SEL)nextAction doneAction:(SEL)doneAction {
    UIToolbar *keyboardDoneButtonView = [[UIToolbar alloc] init];
    
    [keyboardDoneButtonView sizeToFit];
    
    NSMutableArray *buttonItems = [NSMutableArray array];
    
    if (hasDoneButton) {
        UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", @"")
                                                                       style:UIBarButtonItemStylePlain
                                                                      target:target
                                                                      action:doneAction];
        
        [buttonItems addObject:doneButton];
    }
    
    if (hasNextButton) {
        UIBarButtonItem *nextButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Next", @"")
                                                                       style:UIBarButtonItemStylePlain
                                                                      target:target
                                                                      action:nextAction];
        
        [buttonItems addObject:nextButton];
    }
    
    [keyboardDoneButtonView setItems:buttonItems];
    
    return keyboardDoneButtonView;
}

+ (BOOL)isEmailFormat:(NSString *)emailCandicate {
    NSString *emailRegex = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,6}";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
    
    return [predicate evaluateWithObject:emailCandicate];
}

+ (NSString *)encryptPassword:(NSString *)rawPassword {
    return [rawPassword SHA256];
}

+ (NSString *)encryptSecurityCode:(NSString *)rawSecurityCode {
    return [rawSecurityCode SHA256];
}

+ (NSString *)encryptUserId:(NSString *)rawUserId {
    return [rawUserId SHA256];
}

+ (void)prepareInitialPreferencesWithUserDefaults:(NSUserDefaults *)userDefaults {
    [userDefaults setObject:CREPO_DOMAIN_URL_SCHEME forKey:USER_DEFAULTS_KEY_DOMAIN_URL_SCHEME];
    [userDefaults setObject:CREPO_DOMAIN_ZONE_NAME forKey:USER_DEFAULTS_KEY_DOMAIN_ZONE_NAME];
    [userDefaults setObject:CREPO_DOMAIN_NAME forKey:USER_DEFAULTS_KEY_DOMAIN_NAME];
    [userDefaults setInteger:CREPO_PORT forKey:USER_DEFAULTS_KEY_PORT];
    [userDefaults setObject:CREPO_CONTEXT_PATH forKey:USER_DEFAULTS_KEY_CONTEXT_PATH];
    
    if (![userDefaults objectForKey:USER_DEFAULTS_KEY_SHOW_HIDDEN]) {
        [userDefaults setBool:NO forKey:USER_DEFAULTS_KEY_SHOW_HIDDEN];
    }
    
    if (![userDefaults objectForKey:USER_DEFAULTS_KEY_RELOAD_MENU]) {
        [userDefaults setBool:NO forKey:USER_DEFAULTS_KEY_RELOAD_MENU];
    }
}

+ (void)deleteUserDataWithUserDefaults:(NSUserDefaults *)userDefaults {
    if (userDefaults) {
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_USER_SESSION_ID];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_COUNTRY_ID];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_PHONE_NUMBER];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_USER_ID];
//        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_PASSWORD];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_NICKNAME];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_USER_EMAIL];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_UPLOAD_SUBDIRECTORY_TYPE];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_UPLOAD_SUBDIRECTORY_VALUE];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_UPLOAD_DESCRIPTION_TYPE];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_UPLOAD_DESCRIPTION_VALUE];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_UPLOAD_NOTIFICATION_TYPE];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_RESET_PASSWORD_USER_ID];

        // local and remote notification badge number
        [userDefaults setObject:@0 forKey:USER_DEFAULTS_KEY_NOTIFICATION_BADGE_NUMBER];

        [userDefaults synchronize];
    }
}

+ (void)deleteComputerDataWithUserDefaults:(NSUserDefaults *)userDefaults {
    if (userDefaults) {
        // reset to NO
        [userDefaults setBool:NO forKey:USER_DEFAULTS_KEY_SHOW_HIDDEN];
        
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_COMPUTER_ID];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_COMPUTER_ADMIN_ID];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_COMPUTER_GROUP];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_COMPUTER_NAME];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_PATH_SEPARATOR];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_LINE_SEPARATOR];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_USER_COUNTRY];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_USER_LANGUAGE];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_USER_HOME];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_USER_DIRECTORY];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_TEMP_DIRECTORY];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_SERVER_FILE_ENCODING];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_DESKTOP_VERSION];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_LUG_SERVER_ID];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_UPLOAD_DIRECTORY];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_FIRST_ROOT_DIRECTORY];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_UPLOAD_SUBDIRECTORY_TYPE];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_UPLOAD_SUBDIRECTORY_VALUE];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_UPLOAD_DESCRIPTION_TYPE];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_UPLOAD_DESCRIPTION_VALUE];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_UPLOAD_NOTIFICATION_TYPE];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_DOWNLOAD_DIRECTORY];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_DOWNLOAD_SUBDIRECTORY_TYPE];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_DOWNLOAD_SUBDIRECTORY_VALUE];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_DOWNLOAD_DESCRIPTION_TYPE];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_DOWNLOAD_DESCRIPTION_VALUE];
        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_DOWNLOAD_NOTIFICATION_TYPE];

        [userDefaults synchronize];
    }
}

+ (NSDictionary *_Nullable)parseJsonAsDictionaryFromData:(NSData *)data error:(NSError *_Nullable __autoreleasing *_Nullable)error {
    NSError *jsonError = nil;
    NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];
    
    if (jsonError) {
        if (error) {
            *error = jsonError;
        }

        return nil;
    } else {
        return jsonDictionary;
    }
}

dispatch_source_t createDispatchTimer(double interval, dispatch_queue_t queue, dispatch_block_t block) {
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    if (timer) {
        dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, (int64_t) (interval * NSEC_PER_SEC)), (uint64_t) (interval * NSEC_PER_SEC), (1ull * NSEC_PER_SEC) / 10);
        dispatch_source_set_event_handler(timer, block);
        dispatch_resume(timer);
    }
    return timer;
}

+ (void)promptUpdateDesktopWithUserDefaults:(NSUserDefaults *)userDefaults inViewController:(nonnull UIViewController *)viewController {
    NSString *currentComputerName = [userDefaults stringForKey:USER_DEFAULTS_KEY_COMPUTER_NAME];
    
    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Upgrade desktop %@ first", @""), currentComputerName];
    
    [self viewController:viewController alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
}

// including local and remote notifications
+ (void)incrementCachedNotificationBadgeNumber {
    NSUserDefaults *userDefaults = [self groupUserDefaults];

    NSNumber *currentBadgeNumber = [userDefaults objectForKey:USER_DEFAULTS_KEY_NOTIFICATION_BADGE_NUMBER];
    
    if (!currentBadgeNumber) {
        currentBadgeNumber = @0;
    }
    
    [userDefaults setObject:@([currentBadgeNumber integerValue] + 1) forKey:USER_DEFAULTS_KEY_NOTIFICATION_BADGE_NUMBER];
}

+ (void)clearCachedNotificationBadgeNumber {
    NSUserDefaults *userDefaults = [self groupUserDefaults];

    [userDefaults setObject:@0 forKey:USER_DEFAULTS_KEY_NOTIFICATION_BADGE_NUMBER];
}

// including local and remote notifications
+ (NSNumber *)currentCachedLocalNotificationBadgeNumber {
    NSUserDefaults *userDefaults = [self groupUserDefaults];

    NSNumber *currentBadgeNumber = [userDefaults objectForKey:USER_DEFAULTS_KEY_NOTIFICATION_BADGE_NUMBER];

    return currentBadgeNumber ? currentBadgeNumber : @0;
}

+ (void)checkDirectoryName:(NSString *)directoryName illegalCharacters:(NSArray **)illegalCharacters {
    // find the OS of current connected desktop
    
    NSUserDefaults *userDefaults = [self groupUserDefaults];

    NSString *fileSeparator = [userDefaults objectForKey:USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR];
    
    NSString *regPattern;
    if (fileSeparator && [fileSeparator isEqualToString:@"\\"]) {
        // windows
        
        /*
         The following reserved characters are not allowed:
         < (less than)
         > (greater than)
         : (colon)
         " (double quote)
         / (forward slash) -- reserved for regular expression
         \ (backslash) -- reserved for regular expression
         | (vertical bar or pipe) -- reserved for regular expression
         ? (question mark) -- reserved for regular expression
         * (asterisk) -- reserved for regular expression
         */
        
        regPattern = @"(<|>|:|\"|\\/|\\\\|\\||\\?|\\*)+";
    } else {
        // linux or mac
        
        regPattern = @"(\\/)+";
    }
    
    NSError *regError;
    NSRegularExpression *regularExpression = [NSRegularExpression regularExpressionWithPattern:regPattern options:NSRegularExpressionCaseInsensitive error:&regError];
    
    NSArray *matches = [regularExpression matchesInString:directoryName options:0 range:NSMakeRange(0, [directoryName length])];
    
    NSMutableArray *foundCharacters = [NSMutableArray array];
    for (NSTextCheckingResult *match in matches) {
        NSRange matchRange = [match range];
        
        if (!NSEqualRanges(matchRange, NSMakeRange(NSNotFound, 0))) {
            [foundCharacters addObject:[directoryName substringWithRange:matchRange]];
        }
    }
    
    *illegalCharacters = foundCharacters;
}

+ (NSString *)generateUploadGroupIdWithFilenames:(NSArray *)filenames {
    NSMutableString *mutableString = [NSMutableString string];
    
    if (filenames) {
        for (NSString *filename in filenames) {
            [mutableString appendString:filename];
        }
    }
    
    [mutableString appendString:[Utility uuid]];
    
    return [mutableString MD5];
}

+ (NSString *)generateDownloadGroupIdWithFilenames:(NSArray *)filenames {
    return [self generateUploadGroupIdWithFilenames:filenames];
}

+ (NSString *)stringFromStringArray:(NSArray *)stringArray separator:(NSString *)separator quotedCharacter:(NSString *)quoteCharacter {
    NSMutableString *mutableString = [NSMutableString string];
    
    if (stringArray) {
        NSUInteger count = [stringArray count];
        
        for (NSUInteger index = 0; index < count; index++) {
            if (index < (count - 1)) {
                [mutableString appendFormat:@"%@%@%@%@", quoteCharacter, stringArray[index], quoteCharacter, separator];
            } else {
                // the last one skip the separator
                [mutableString appendFormat:@"%@%@%@", quoteCharacter, stringArray[index], quoteCharacter];
            }
        }
    }
    
    return [NSString stringWithString:mutableString];
}

+ (BOOL)isIPad {
    return [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
//    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
}

+ (BOOL)isIPhone {
    return [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone;
}

+ (BOOL)isDeviceVersion8OrLater {
    return [[NSDecimalNumber decimalNumberWithString:IOS_VERSION] doubleValue] >= 8.0;
}

+ (BOOL)isDeviceVersion9OrLater {
    return [[NSDecimalNumber decimalNumberWithString:IOS_VERSION] doubleValue] >= 9.0;
}

+ (BOOL)isDeviceVersion91OrLater {
    return [[NSDecimalNumber decimalNumberWithString:IOS_VERSION] doubleValue] >= 9.1;
}

+ (BOOL)isDeviceVersion10OrLater {
    return [[NSDecimalNumber decimalNumberWithString:IOS_VERSION] doubleValue] >= 10.0;
}

+ (BOOL)isDeviceVersion10Or10_1 {
    double ver = [[NSDecimalNumber decimalNumberWithString:IOS_VERSION] doubleValue];
    return (ver >= 10.0 && ver < 10.2);
}

+ (BOOL)isDeviceVersion11OrLater {
    return [[NSDecimalNumber decimalNumberWithString:IOS_VERSION] doubleValue] >= 11.0;
}

+ (void)selectTextInTextField:(UITextField *)textField range:(NSRange)range {
    UITextPosition *from = [textField positionFromPosition:[textField beginningOfDocument] offset:range.location];
    
    UITextPosition *to = [textField positionFromPosition:from offset:range.length];
    
    [textField setSelectedTextRange:[textField textRangeFromPosition:from toPosition:to]];
}

+ (NSString *)removeIllegalCharactersFromFileName:(NSString *)filename {
    NSCharacterSet *illegalCharacters = [NSCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>"];
    
    NSString *newFilename = [[filename componentsSeparatedByCharactersInSet:illegalCharacters] componentsJoinedByString:@""];
    
    return [newFilename stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

+ (BOOL)validFilename:(NSString *)filename {
    NSString *newFilename = [self removeIllegalCharactersFromFileName:filename];
    
    return [newFilename isEqualToString:filename] && [[newFilename stringByTrimmingCharactersInSet:[NSCharacterSet punctuationCharacterSet]] length] > 0;
}

+ (CGSize)thumbnailSizeForUploadFileTableViewCellImage {
    CGFloat heightWithRetina = [[UIScreen mainScreen] scale] * 60;
    
    return CGSizeMake(heightWithRetina, heightWithRetina);
}

+ (CGSize)thumbnailSizeWithHeight:(CGFloat)height {
    CGFloat heightWithRetina = [[UIScreen mainScreen] scale] * height;

    return CGSizeMake(heightWithRetina, heightWithRetina);
}

+ (NSData *)dataFromImage:(UIImage *)image {
    NSData *data;

    if (image) {
        data = UIImagePNGRepresentation(image);

        if (!data) {
            data = UIImageJPEGRepresentation(image, 1.0);
        }
    }

    return data;
}

+ (NSUserDefaults *)groupUserDefaults {
    if (!groupUserDefaults) {
        groupUserDefaults = [[NSUserDefaults alloc] initWithSuiteName:APP_GROUP_NAME];
    }
    
    return groupUserDefaults;
}

// For storyboard
+ (UITableViewCell *)tableView:(UITableView *)tableView createOrDequeueCellWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier forIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier forIndexPath:indexPath];

    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:reuseIdentifier];
    }

    return cell;
}

// For xib
+ (UITableViewCell *)tableView:(UITableView *)tableView createOrDequeueCellWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];

    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:reuseIdentifier];
    }

    return cell;
}

+ (void)viewController:(nullable UIViewController *)viewController alertWithMessageTitle:(NSString *)messageTitle messageBody:(NSString *)messageBody actionTitle:(NSString *)actionTitle delayInSeconds:(double)delayInSeconds actionHandler:(void (^ _Nullable)(UIAlertAction *action))actionHandler {
    [self viewController:viewController alertWithMessageTitle:messageTitle messageBody:messageBody actionTitle:actionTitle containsCancelAction:NO delayInSeconds:delayInSeconds actionHandler:actionHandler];
}

+ (void)viewController:(nullable UIViewController *)viewController alertWithMessageTitle:(NSString *)messageTitle messageBody:(NSString *)messageBody actionTitle:(NSString *)actionTitle containsCancelAction:(BOOL)containsCancelAction delayInSeconds:(double)delayInSeconds actionHandler:(void (^ _Nullable)(UIAlertAction *action))actionHandler {
    [self viewController:viewController alertWithMessageTitle:messageTitle messageBody:messageBody actionTitle:actionTitle containsCancelAction:containsCancelAction cancelTitle:NSLocalizedString(@"Cancel", @"") delayInSeconds:delayInSeconds actionHandler:actionHandler cancelHandler:nil];
}

+ (void)viewController:(UIViewController *)viewController alertWithMessageTitle:(NSString *)messageTitle messageBody:(NSString *)messageBody actionTitle:(NSString *)actionTitle containsCancelAction:(BOOL)containsCancelAction cancelTitle:(NSString *)cancelTitle delayInSeconds:(double)delayInSeconds actionHandler:(void (^ _Nullable)(UIAlertAction *action))actionHandler cancelHandler:(void (^ _Nullable)(UIAlertAction *action))cancelHandler {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:messageTitle message:messageBody preferredStyle:UIAlertControllerStyleAlert];

    UIAlertActionStyle actionStyle = actionHandler ? UIAlertActionStyleDefault : UIAlertActionStyleCancel;

    UIAlertAction *okAction = [UIAlertAction actionWithTitle:actionTitle style:actionStyle handler:^(UIAlertAction *action) {
        if (viewController && [viewController isKindOfClass:[UITableViewController class]]) {
            UITableViewController *tableViewController = (UITableViewController *)viewController;

            if (tableViewController.refreshControl && [tableViewController.refreshControl isRefreshing]) {
                [tableViewController.refreshControl endRefreshing];
            }
        }

        if (actionHandler) {
            actionHandler(action);
        }
    }];
    [alertController addAction:okAction];

    if (containsCancelAction) {
        NSString *cancelActionTitle;

        if (cancelTitle && [cancelTitle stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
            cancelActionTitle = cancelTitle;
        } else {
            cancelActionTitle = NSLocalizedString(@"Cancel", @"");
        }

        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancelActionTitle style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            if (viewController && [viewController isKindOfClass:[UITableViewController class]]) {
                UITableViewController *tableViewController = (UITableViewController *)viewController;

                if (tableViewController.refreshControl && [tableViewController.refreshControl isRefreshing]) {
                    [tableViewController.refreshControl endRefreshing];
                }
            }

            if (cancelHandler) {
                cancelHandler(action);
            }
        }];

        [alertController addAction:cancelAction];
    }
    
    // To prevent the alert controller not show up because the view of the ViewController is not in the window hierarchy,
    
    if (delayInSeconds > 0) {
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
            if (viewController && [viewController isVisible]) {
                [alertController presentWithViewController:viewController sourceView:nil sourceRect:CGRectNull barButtonItem:nil animated:YES completion:nil];
            } else {
                [alertController presentWithAnimated:YES];
            }
        });
    } else {
        if (viewController && [viewController isVisible]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [alertController presentWithViewController:viewController sourceView:nil sourceRect:CGRectNull barButtonItem:nil animated:YES completion:nil];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [alertController presentWithAnimated:YES];
            });
        }
    }
}

+ (void)moveExternalDirectoryToAppGroupDirectory {
    NSString *sourceDirectory = [[DirectoryService iTunesFileSharingRootPath] stringByAppendingPathComponent:EXTERNAL_FILE_DIRECTORY_NAME];

    NSFileManager *fileManager = [NSFileManager defaultManager];

    BOOL sourceIsDirectory;
    BOOL sourcePathExists = [fileManager fileExistsAtPath:sourceDirectory isDirectory:&sourceIsDirectory];

    if (sourcePathExists && sourceIsDirectory) {
        // move the directory to the application group directory

        NSString *destDirectory = [[DirectoryService appGroupRootDirectory] stringByAppendingPathComponent:EXTERNAL_FILE_DIRECTORY_NAME];

        BOOL destPathExists = [fileManager fileExistsAtPath:destDirectory];

        // Do nothing if dest directory exists

        if (!destPathExists) {
            NSError *moveError;
            BOOL moved = [fileManager moveItemAtPath:sourceDirectory toPath:destDirectory error:&moveError];

            if (moveError) {
                NSLog(@"Move external directory failed. Error:\n%@", [moveError userInfo]);
            } else if (!moved) {
                NSLog(@"External directory moved failed for no error.");
            } else {
                NSLog(@"External directory moved successfully.");
            }
        }
    }
}

+ (void)updateFileTransferLocalPathToRelativePath {
    NSUserDefaults *userDefaults = [self groupUserDefaults];

    NSNumber *converted = [userDefaults objectForKey:USER_DEFAULTS_KEY_CONVERTED_LOCAL_PATH_TO_RELATIVE_PATH];

    if (!converted || ![converted boolValue]) {
        @try {
            [DirectoryService updateFileTransferLocalPathToRelativePath];

            [userDefaults setObject:@YES forKey:USER_DEFAULTS_KEY_CONVERTED_LOCAL_PATH_TO_RELATIVE_PATH];
        } @catch (NSException *e) {
            NSLog(@"Error on converting local path to relative path.\n%@", e);
        }
    }
}

+ (void)moveDownloadFileToAppGroupDirectory {
    NSUserDefaults *userDefaults = [self groupUserDefaults];

    NSNumber *converted = [userDefaults objectForKey:USER_DEFAULTS_KEY_MOVE_DOWNLOADED_FILE_TO_APP_GROUP_DIRECTORY];

    if (!converted || ![converted boolValue]) {
        @try {
            [DirectoryService moveDownloadFileToAppGroupDirectory];

            [userDefaults setObject:@YES forKey:USER_DEFAULTS_KEY_MOVE_DOWNLOADED_FILE_TO_APP_GROUP_DIRECTORY];
        } @catch (NSException *e) {
            NSLog(@"Error on moving download files to app group directory.\n%@", e);
        }
    }
}

+ (void)createFileDownloadGroupToNonAssignedFileTransfersWithEachUserComputerWithUserDefaults:(NSUserDefaults *)userDefaults {
    NSNumber *copied = [userDefaults objectForKey:USER_DEFAULTS_KEY_CREATE_FILE_DOWNLOAD_GROUP_TO_NON_ASSIGNED_FILE_TRANSFERS];

    if (!copied || ![copied boolValue]) {
        @try {
            UserComputerDao *userComputerDao = [[UserComputerDao alloc] init];

            FileDownloadGroupDao *fileDownloadGroupDao = [[FileDownloadGroupDao alloc] init];

            NSInteger defaultNotificationType = [DownloadNotificationService defaultType];

            [userComputerDao enumerateUserComputerWithEachCompletionHandler:^(UserComputer *userComputer, NSManagedObjectContext *moc) {
                if (userComputer && moc) {
                    NSSet *fileTransfers = userComputer.fileTransfers;

                    if (fileTransfers && [fileTransfers count] > 0) {
                        // create new FileDownloadGroup and assigned these fileTransfers to it.

                        NSMutableSet<FileTransfer *> *fileTransfersWithoutGroup = [NSMutableSet set];
                        NSMutableArray *filenames = [NSMutableArray array];

                        for (FileTransfer *fileTransfer in fileTransfers) {
                            // Add those FileTransfer that without value of FileDownloadGroup

                            if (!fileTransfer.fileDownloadGroup) {
                                [fileTransfersWithoutGroup addObject:fileTransfer];

                                NSString *localRelPath = fileTransfer.localPath;

                                NSString *realFilename = [localRelPath lastPathComponent];

                                [filenames addObject:realFilename];
                            }
                        }

                        NSString *downloadGroupId = [Utility generateDownloadGroupIdWithFilenames:filenames];

                        [fileDownloadGroupDao createFileDownloadGroupButNotSaveInManagedObjectContext:moc downloadGroupId:downloadGroupId notificationType:defaultNotificationType userComputer:userComputer fileTransfers:fileTransfersWithoutGroup];
                    }
                }
            } saveContextAfterFinishedAllCompletionHandler:YES afterFinishedAllCompletionHandler:^() {
                [userDefaults setObject:@YES forKey:USER_DEFAULTS_KEY_CREATE_FILE_DOWNLOAD_GROUP_TO_NON_ASSIGNED_FILE_TRANSFERS];

                FileTransferDao *fileTransferDao = [[FileTransferDao alloc] init];

                [fileTransferDao deleteFileTransfersWithoutStatusOfSuccess];

                // DEBUG
//                NSLog(@"Assign download group to all downloaded files and delete non-downloaded files.");
            }];
        } @catch (NSException *e) {
            NSLog(@"Error on assigning downloaded files without download group, for each user computer.\n%@", e);
        }
    }
}

+ (void)copyHierarchicalModelTypeToSectionNameWithUserDefaults:(NSUserDefaults *)userDefaults {
    NSNumber *copied = [userDefaults objectForKey:USER_DEFAULTS_KEY_HIERARCHICAL_MODEL_TYPE_COPIED_TO_SECTION_NAME];

    if (!copied || ![copied boolValue]) {
        @try {
            HierarchicalModelDao *hierarchicalModelDao = [[HierarchicalModelDao alloc] init];

            [hierarchicalModelDao enumerateHierarchicalModelWithCompletionHandler:^(HierarchicalModel *hierarchicalModel) {
                // The block will be run under [moc performBlockAndWait:]

                NSString *type = hierarchicalModel.type;

                if (type && [[type lowercaseString] hasSuffix:@"file"]) {
                        hierarchicalModel.sectionName = @"file";
                } else {
                    hierarchicalModel.sectionName = @"directory";
                }

                // DEBUG
//                NSLog(@"Set HierarchicalModel section name: '%@' from type value: '%@'", hierarchicalModel.sectionName, hierarchicalModel.type);
            } saveContextAfterFinishedAllCompletionHandler:YES];

            [userDefaults setObject:@YES forKey:USER_DEFAULTS_KEY_HIERARCHICAL_MODEL_TYPE_COPIED_TO_SECTION_NAME];
        } @catch (NSException *e) {
            NSLog(@"Error on coping hierarchical mode type to section name.\n%@", e);
        }
    }
}

+ (void)moveUploadSettingsFromArrayToStringWithUserDefaults:(NSUserDefaults *)userDefaults {
    NSArray *uploadSubdirectories = [userDefaults objectForKey:USER_DEFAULTS_KEY_UPLOAD_SUBDIRECTORIES];

    if (uploadSubdirectories && [uploadSubdirectories count] > 0) {
        [userDefaults setObject:uploadSubdirectories[0] forKey:USER_DEFAULTS_KEY_UPLOAD_SUBDIRECTORY_VALUE];

        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_UPLOAD_SUBDIRECTORIES];

        // DEBUG
        NSLog(@"Preferences key replaced with upload subdirectory.");
    }

    NSArray *uploadDescriptions = [userDefaults objectForKey:USER_DEFAULTS_KEY_UPLOAD_DESCRIPTIONS];

    if (uploadDescriptions && [uploadDescriptions count] > 0) {
        [userDefaults setObject:uploadDescriptions[0] forKey:USER_DEFAULTS_KEY_UPLOAD_DESCRIPTION_VALUE];

        [userDefaults removeObjectForKey:USER_DEFAULTS_KEY_UPLOAD_DESCRIPTIONS];

        // DEBUG
        NSLog(@"Preferences key replaced with upload description.");
    }
}

+ (void)deleteAssetFilesWithSharedFileSourceTypeButNoDownloadedTransferKeyWithUserDefaults:(NSUserDefaults *)userDefaults {
    if (![userDefaults objectForKey:USER_DEFAULTS_KEY_DELETED_ASSET_FILES_WITH_SOURCE_TYPE_SHARED_FILE_BUT_NO_DOWNLOADED_TRANSFER_KEY]) {
        AssetFileDao *assetFileDao = [[AssetFileDao alloc] init];

        [assetFileDao deleteAssetFilesWithSourceTypeOfSharedFileButNoDownloadedTransferKeyWithCompletionHandler:nil];

//        NSArray<NSString *> *localRelPaths = [assetFileDao findAssetURLWithSourceType:@(ASSET_FILE_SOURCE_TYPE_SHARED_FILE)];
//
//        if (localRelPaths && [localRelPaths count] > 0) {
//            NSString *toPathFolder = [DirectoryService devicdSharingFolderPath];
//
//            NSFileManager *fileManager = [NSFileManager defaultManager];
//
//            for (NSString *localRelPath in localRelPaths) {
//                NSString *localAbsolutePath = [toPathFolder stringByAppendingPathComponent:localRelPath];
//
//                BOOL isDirectory;
//                if ([fileManager fileExistsAtPath:localAbsolutePath isDirectory:&isDirectory]) {
//                    if (!isDirectory) {
//                        NSError *removeError;
//                        [fileManager removeItemAtPath:localAbsolutePath error:&removeError];
//                    }
//                }
//            }
//
//        }

        [userDefaults setObject:@YES forKey:USER_DEFAULTS_KEY_DELETED_ASSET_FILES_WITH_SOURCE_TYPE_SHARED_FILE_BUT_NO_DOWNLOADED_TRANSFER_KEY];
    }
}

+ (PHImageRequestOptions *)imageRequestOptionsWithAsset:(PHAsset *)asset {
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];

    options.resizeMode = PHImageRequestOptionsResizeModeExact;
//    options.synchronous = YES;
    options.networkAccessAllowed = YES;

    // the key to make it square
    options.normalizedCropRect = [self prepareRectWithAsset:asset];
    
    return options;
}

+ (CGRect)prepareRectWithAsset:(PHAsset *)asset {
    CGRect squareRect;

    NSUInteger assetWidth = asset.pixelWidth;
    NSUInteger assetHeight = asset.pixelHeight;

    if (assetWidth > assetHeight) {
        squareRect = CGRectMake((CGFloat) ((assetWidth - assetHeight) / 2.0), 0, assetHeight, assetHeight);
    } else if (assetHeight > assetWidth) {
        squareRect = CGRectMake(0, (CGFloat) ((assetHeight - assetWidth) / 2.0), assetWidth, assetWidth);
    } else {
        squareRect = CGRectMake(0, 0, assetWidth, assetHeight);
    }

    CGRect cropRect = CGRectApplyAffineTransform(squareRect, CGAffineTransformMakeScale((CGFloat) (1.0 / assetWidth), (CGFloat) (1.0 / assetHeight)));

    return cropRect;
}

+ (void)requestAssetThumbnailWithAsset:(PHAsset *)asset resizedToSize:(CGSize)resizedToSize resultHandler:(void (^)(UIImage *_Nullable result))resultHandler {
    PHImageRequestOptions *imageRequestOptions = [self imageRequestOptionsWithAsset:asset];

    // Height of cell is 66, and consider of 3-times dimension
    [[PHImageManager defaultManager] requestImageForAsset:asset
                                               targetSize:resizedToSize
                                              contentMode:PHImageContentModeAspectFit
                                                  options:imageRequestOptions
                                            resultHandler:^(UIImage *result, NSDictionary *info) {
                                                if (result && resultHandler) {
                                                    resultHandler(result);
                                                } else if (resultHandler) {
                                                    resultHandler(nil);
                                                }
                                            }
    ];
}

+ (NSString *)backgroundUploadIdentifierForFilelug {
    NSString *identifier = [NSString stringWithFormat:@"%@.%@", BACKGROUND_UPLOAD_ID_FOR_FILELUG_PREFIX, APP_GROUP_NAME];

    return identifier;
}

+ (NSString *)backgroundUploadIdentifierForShareExtension {
    NSString *identifier = [NSString stringWithFormat:@"%@.%@", BACKGROUND_UPLOAD_ID_FOR_SHARE_EXTENSION_PREFIX, APP_GROUP_NAME];

    return identifier;
}

+ (NSString *)backgroundDownloadIdentifierForFilelug {
    NSString *identifier = [NSString stringWithFormat:@"%@.%@", BACKGROUND_DOWNLOAD_ID_FOR_FILELUG_PREFIX, APP_GROUP_NAME];

    return identifier;
}

+ (NSString *)backgroundDownloadIdentifierForDocumentProviderExtension {
    NSString *identifier = [NSString stringWithFormat:@"%@.%@", BACKGROUND_DOWNLOAD_ID_FOR_DOCUMENT_PROVIDER_EXTENSION_PREFIX, APP_GROUP_NAME];

    return identifier;
}

+ (void)addTapGestureRecognizerForImageView:(UIImageView *)imageView withTarget:(id)target action:(SEL)action {
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:target action:action];

    tapRecognizer.numberOfTouchesRequired = 1;
    tapRecognizer.numberOfTapsRequired = 1;
    tapRecognizer.delaysTouchesEnded = NO;
    tapRecognizer.delaysTouchesBegan = YES;
    tapRecognizer.cancelsTouchesInView = YES;

    [imageView addGestureRecognizer:tapRecognizer];
}

+ (NSString *)convertFileTransferLocalPath:(NSString *)localPath toRelativePathWithUserComputerId:(NSString *)userComputerId {
    NSString *relativePath;

    if (localPath && userComputerId) {
        NSArray *pathComponents = [localPath pathComponents];

        BOOL foundUserComputerId = NO;
        for (NSString *component in pathComponents) {
            if (foundUserComputerId) {
                if (relativePath) {
                    relativePath = [relativePath stringByAppendingPathComponent:component];
                } else {
                    relativePath = component;
                }
            } else {
                if ([component isEqualToString:userComputerId]) {
                    foundUserComputerId = YES;
                }
            }
        }
    }

    return relativePath;
}

+ (NSString *)applicationSupportDirectoryWithFileManager:(NSFileManager *)fileManager {
    NSError *error;

    NSURL *url = [fileManager URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error];

    if (!url) {
        NSLog(@"Failed to find or create applicaion support diectory:\n%@", [error userInfo]);
    }

    return url.path;
}

+ (BOOL)string:(NSString *)string1 notTheSameWith:(NSString *)string2 {
    if (!string1 && !string2) {
        return NO;
    } else if (!string1 || !string2) {
        return YES;
    }

    return ![string1 isEqualToString:string2];
}

+ (BOOL)number:(NSNumber *)number1 notTheSameWith:(NSNumber *)number2 {
    if (!number1 && !number2) {
        return NO;
    } else if (!number1 || !number2) {
        return YES;
    }

    return ![number1 isEqualToNumber:number2];
}

+ (void)logTransferStateWithTaskState:(NSURLSessionTaskState)taskState {
    if (taskState == NSURLSessionTaskStateRunning) {
        NSLog(@"Transfer task state is NSURLSessionTaskStateRunning(%ld)", (long)taskState);
    } else if (taskState == NSURLSessionTaskStateCanceling) {
        NSLog(@"Transfer task state is NSURLSessionTaskStateCanceling(%ld)", (long)taskState);
    } else if (taskState == NSURLSessionTaskStateCompleted) {
        NSLog(@"Transfer task state is NSURLSessionTaskStateCompleted(%ld)", (long)taskState);
    } else if (taskState == NSURLSessionTaskStateSuspended) {
        NSLog(@"Transfer task state is NSURLSessionTaskStateSuspended(%ld)", (long)taskState);
    } else {
        NSLog(@"Unknown transfer task state(%ld)", (long)taskState);
    }
}

/*
typedef NS_ENUM(NSInteger, PHAssetMediaType) {
    PHAssetMediaTypeUnknown = 0,
    PHAssetMediaTypeImage   = 1,
    PHAssetMediaTypeVideo   = 2,
    PHAssetMediaTypeAudio   = 3,
} NS_ENUM_AVAILABLE_IOS(8_0);

typedef NS_OPTIONS(NSUInteger, PHAssetMediaSubtype) {
    PHAssetMediaSubtypeNone               = 0,

    // Photo subtypes
    PHAssetMediaSubtypePhotoPanorama      = (1UL << 0),
    PHAssetMediaSubtypePhotoHDR           = (1UL << 1),
    PHAssetMediaSubtypePhotoScreenshot NS_AVAILABLE_IOS(9_0) = (1UL << 2),
    PHAssetMediaSubtypePhotoLive NS_AVAILABLE_IOS(9_1) = (1UL << 3),


    // Video subtypes
    PHAssetMediaSubtypeVideoStreamed      = (1UL << 16),
    PHAssetMediaSubtypeVideoHighFrameRate = (1UL << 17),
    PHAssetMediaSubtypeVideoTimelapse     = (1UL << 18),
} NS_AVAILABLE_IOS(8_0);
*/
+ (void)logMediaTypeWithMediaType:(PHAssetMediaType)mediaType mediaSubType:(PHAssetMediaSubtype)mediaSubtype completionHandler:(void(^)(NSString *mediaTypeAsString, NSString *mediaSubtypeAsString))completionHandler {
    if (completionHandler) {
        NSString *mediaTypeString;
        NSString *mediaSubtypeString;

        switch (mediaType) {
            case PHAssetMediaTypeUnknown:
                mediaTypeString = @"PHAssetMediaTypeUnknown";

                break;
            case PHAssetMediaTypeImage:
                mediaTypeString = @"PHAssetMediaTypeImage";

                break;
            case PHAssetMediaTypeVideo:
                mediaTypeString = @"PHAssetMediaTypeVideo";

                break;
            case PHAssetMediaTypeAudio:
                mediaTypeString = @"PHAssetMediaTypeAudio";

                break;
        }

        if ([self isDeviceVersion91OrLater]) {
            switch (mediaSubtype) {
                case PHAssetMediaSubtypeNone:
                    mediaSubtypeString = @"PHAssetMediaSubtypeNone";

                    break;
                case PHAssetMediaSubtypePhotoPanorama:
                    mediaSubtypeString = @"PHAssetMediaSubtypePhotoPanorama";

                    break;
                case PHAssetMediaSubtypePhotoHDR:
                    mediaSubtypeString = @"PHAssetMediaSubtypePhotoHDR";

                    break;
                case PHAssetMediaSubtypePhotoScreenshot:
                    mediaSubtypeString = @"PHAssetMediaSubtypePhotoScreenshot";

                    break;
                case PHAssetMediaSubtypePhotoLive:
                    mediaSubtypeString = @"PHAssetMediaSubtypePhotoLive";

                    break;
                case PHAssetMediaSubtypeVideoStreamed:
                    mediaSubtypeString = @"PHAssetMediaSubtypeVideoStreamed";

                    break;
                case PHAssetMediaSubtypeVideoHighFrameRate:
                    mediaSubtypeString = @"PHAssetMediaSubtypeVideoHighFrameRate";

                    break;
                case PHAssetMediaSubtypeVideoTimelapse:
                    mediaSubtypeString = @"PHAssetMediaSubtypeVideoTimelapse";

                    break;
                default:
                    mediaSubtypeString = [NSString stringWithFormat:@"Unknown media subtype %ld", (long) mediaSubtype];
            }
        } else if ([self isDeviceVersion9OrLater]) {
            // no PHAssetMediaSubtypePhotoLive

            switch (mediaSubtype) {
                case PHAssetMediaSubtypeNone:
                    mediaSubtypeString = @"PHAssetMediaSubtypeNone";

                    break;
                case PHAssetMediaSubtypePhotoPanorama:
                    mediaSubtypeString = @"PHAssetMediaSubtypePhotoPanorama";

                    break;
                case PHAssetMediaSubtypePhotoHDR:
                    mediaSubtypeString = @"PHAssetMediaSubtypePhotoHDR";

                    break;
                case PHAssetMediaSubtypePhotoScreenshot:
                    mediaSubtypeString = @"PHAssetMediaSubtypePhotoScreenshot";

                    break;
                case PHAssetMediaSubtypeVideoStreamed:
                    mediaSubtypeString = @"PHAssetMediaSubtypeVideoStreamed";

                    break;
                case PHAssetMediaSubtypeVideoHighFrameRate:
                    mediaSubtypeString = @"PHAssetMediaSubtypeVideoHighFrameRate";

                    break;
                case PHAssetMediaSubtypeVideoTimelapse:
                    mediaSubtypeString = @"PHAssetMediaSubtypeVideoTimelapse";

                    break;
                default:
                    mediaSubtypeString = [NSString stringWithFormat:@"Unknown media subtype %ld", (long) mediaSubtype];
            }
        } else {
            // no PHAssetMediaSubtypePhotoLive and PHAssetMediaSubtypePhotoScreenshot

            switch (mediaSubtype) {
                case PHAssetMediaSubtypeNone:
                    mediaSubtypeString = @"PHAssetMediaSubtypeNone";

                    break;
                case PHAssetMediaSubtypePhotoPanorama:
                    mediaSubtypeString = @"PHAssetMediaSubtypePhotoPanorama";

                    break;
                case PHAssetMediaSubtypePhotoHDR:
                    mediaSubtypeString = @"PHAssetMediaSubtypePhotoHDR";

                    break;
                case PHAssetMediaSubtypeVideoStreamed:
                    mediaSubtypeString = @"PHAssetMediaSubtypeVideoStreamed";

                    break;
                case PHAssetMediaSubtypeVideoHighFrameRate:
                    mediaSubtypeString = @"PHAssetMediaSubtypeVideoHighFrameRate";

                    break;
                case PHAssetMediaSubtypeVideoTimelapse:
                    mediaSubtypeString = @"PHAssetMediaSubtypeVideoTimelapse";

                    break;
                default:
                    mediaSubtypeString = [NSString stringWithFormat:@"Unknown media subtype %ld", (long) mediaSubtype];
            }
        }

        completionHandler(mediaTypeString, mediaSubtypeString);
    }
}

+ (void)copyFileWithSourceFilePath:(NSString *)sourceFilePath startFromByteIndex:(NSNumber *)startByteIndex toDestinationFilePath:(NSString *)destinationFilePath completionHandler:(void (^)(NSError *))completionHandler {
    NSFileHandle *sourceFileHandle;
    NSFileHandle *destinationFileHandle;

    @try {
        sourceFileHandle = [NSFileHandle fileHandleForReadingAtPath:sourceFilePath];

        // If file at destinationFilePath not exists, create an empty one
        [self recreateEmptyFileWithfilePath:destinationFilePath];

        destinationFileHandle = [NSFileHandle fileHandleForWritingAtPath:destinationFilePath];

        [sourceFileHandle seekToFileOffset:[startByteIndex unsignedLongLongValue]];

        NSData *sourceData = [sourceFileHandle readDataToEndOfFile];

        [destinationFileHandle writeData:sourceData];

        [destinationFileHandle synchronizeFile];

        if (completionHandler) {
            completionHandler(nil);
        }
    } @catch (NSException *e) {
        if (completionHandler) {
            NSError *error = [self errorWithErrorCode:ERROR_CODE_COPY_PARTIAL_FILE_CONTENT_KEY localizedDescription:e.reason];

            completionHandler(error);
        } else {
            @throw;
        }
    } @finally {
        if (sourceFileHandle) {
            [sourceFileHandle closeFile];
        }

        if (destinationFileHandle) {
            [destinationFileHandle closeFile];
        }
    }
}

+ (void)copyFileWithSourceData:(NSData *)sourceData startFromByteIndex:(NSNumber *)startByteIndex toDestinationFilePath:(NSString *)destinationFilePath completionHandler:(void (^)(NSError *))completionHandler {
    NSFileHandle *destinationFileHandle;

    @try {
        // If file at destinationFilePath not exists, create an empty one
        [self recreateEmptyFileWithfilePath:destinationFilePath];

        destinationFileHandle = [NSFileHandle fileHandleForWritingAtPath:destinationFilePath];

        NSUInteger readStartIndex = [startByteIndex unsignedIntegerValue];

        if (readStartIndex >= sourceData.length) {
            NSString *errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Length of file smaller than the index to start copy (%lu < %lu)", @""), sourceData.length, readStartIndex];

            if (completionHandler) {
                NSError *error = [self errorWithErrorCode:ERROR_CODE_DATA_INTEGRITY_KEY localizedDescription:errorMessage];

                completionHandler(error);
            } else {
                NSLog(@"Error on copying file. Reason:\n%@", errorMessage);
            }
        } else {
            NSUInteger readLength = sourceData.length - readStartIndex;

            NSRange dataRange = NSMakeRange(readStartIndex, readLength);

            NSData *readData = [sourceData subdataWithRange:dataRange];

            [destinationFileHandle writeData:readData];

            [destinationFileHandle synchronizeFile];

            if (completionHandler) {
                completionHandler(nil);
            }
        }
    } @catch (NSException *e) {
        if (completionHandler) {
            NSError *error = [self errorWithErrorCode:ERROR_CODE_COPY_PARTIAL_FILE_CONTENT_KEY localizedDescription:e.reason];

            completionHandler(error);
        } else {
            @throw;
        }
    } @finally {
        if (destinationFileHandle) {
            [destinationFileHandle closeFile];
        }
    }
}

+ (void)recreateEmptyFileWithfilePath:(NSString *)filePath {
    NSFileManager *fileManager = [NSFileManager defaultManager];

    if ([fileManager fileExistsAtPath:filePath]) {
        NSError *removeError;
        [fileManager removeItemAtPath:filePath error:&removeError];

        if (removeError) {
            NSLog(@"Failed to remove file: '%@' before creating a new one.\n%@", filePath, [removeError userInfo]);
        }
    }

    [fileManager createFileAtPath:filePath contents:[NSData new] attributes:nil];
}

+ (NSString *)generateEmptyFilePathFromTmpUploadFilePath:(NSString *)filePath {
    NSString *emptyFilePath;

    NSString *filename = [filePath lastPathComponent];

    NSString *parentPath = [filePath stringByDeletingLastPathComponent];

    NSString *extension = [filename pathExtension];

    if (extension && [extension length] > 0) {
        emptyFilePath = [NSString stringWithFormat:@"%@/%@_%@_%@.%@", parentPath, [filename stringByDeletingPathExtension], [Utility uuid], TMP_UPLOAD_EMPTY_FILE_SUFFIX, extension];
    } else {
        emptyFilePath = [NSString stringWithFormat:@"%@/%@_%@_%@", parentPath, filename, [Utility uuid], TMP_UPLOAD_EMPTY_FILE_SUFFIX];
    }

    return emptyFilePath;
}

+ (void)updateFileDownloadAndUploadGroupsCreateTimestampToCurrentTimestamp {
    NSUserDefaults *userDefaults = [self groupUserDefaults];

    NSNumber *createTimestampUpdatedToCurrentTimestamp = [userDefaults objectForKey:CREATE_TIMESTAMP_UPDATED_TO_CURRENT_TIMESTAMP];

    if (!createTimestampUpdatedToCurrentTimestamp || ![createTimestampUpdatedToCurrentTimestamp boolValue]) {
        @try {
            UserComputerDao *userComputerDao = [[UserComputerDao alloc] init];

            [userComputerDao enumerateUserComputerWithEachCompletionHandler:^(UserComputer *userComputer, NSManagedObjectContext *moc) {
                if (userComputer && moc) {
                    // for FileDownloadGroup.createTimestamp

                    NSNumber *currentTimestamp = [self currentJavaTimeMilliseconds];

                    NSSet<FileDownloadGroup *> *fileDownloadGroups = userComputer.fileDownloadGroups;

                    if (fileDownloadGroups && [fileDownloadGroups count] > 0) {
                        for (FileDownloadGroup *fileDownloadGroup in fileDownloadGroups) {
                            NSNumber *createTimestamp = fileDownloadGroup.createTimestamp;

                            if (!createTimestamp || [createTimestamp longLongValue] < 1) {
                                fileDownloadGroup.createTimestamp = currentTimestamp;
                            }
                        }
                    }

                    // for FileUploadGroup.createTimestamp

                    NSSet<FileUploadGroup *> *fileUploadGroups = userComputer.fileUploadGroups;

                    if (fileUploadGroups && [fileUploadGroups count] > 0) {
                        for (FileUploadGroup *fileUploadGroup in fileUploadGroups) {
                            NSNumber *createTimestamp = fileUploadGroup.createTimestamp;

                            if (!createTimestamp || [createTimestamp longLongValue] < 1) {
                                fileUploadGroup.createTimestamp = currentTimestamp;
                            }
                        }
                    }
                }
            } saveContextAfterFinishedAllCompletionHandler:YES afterFinishedAllCompletionHandler:^() {
                [userDefaults setObject:@YES forKey:CREATE_TIMESTAMP_UPDATED_TO_CURRENT_TIMESTAMP];

                // DEBUG
                NSLog(@"Set createTimestamp of download/upload groups to current timestamp successfully.");
            }];
        } @catch (NSException *e) {
            NSLog(@"Error on setting createTimestamp of download/upload groups to current timestamp.\n%@", e);
        }
    }
}

+ (void)alertEmptyUserSessionFromViewController:(nonnull UIViewController *)viewController
                                connectNowHandler:(void (^ _Nullable)(UIAlertAction *connectNowAction))connectNowHandler
                              connectLaterHandler:(void (^ _Nullable)(UIAlertAction *connectLaterAction))connectLaterHandler {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Connection not exists", @"") message:NSLocalizedString(@"Session not found and need login", @"") preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *connectNowAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Login Now", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        if (connectNowHandler) {
            connectNowHandler(action);
        }
    }];

    [alertController addAction:connectNowAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        if (connectLaterHandler) {
            connectLaterHandler(action);
        }
    }];

    [alertController addAction:cancelAction];

    if ([viewController isVisible]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [alertController presentWithViewController:viewController sourceView:nil sourceRect:CGRectNull barButtonItem:nil animated:YES completion:nil];
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [alertController presentWithAnimated:YES];
        });
    }
}

+ (void)promptActionSheetToChooseComputerNameWithAlertControllerTitle:(NSString *_Nonnull)alertControllerTitle
                                               availableUserComputers:(NSArray<UserComputerWithoutManaged *> *_Nonnull)availableUserComputers
                                                     inViewController:(UIViewController *_Nonnull)viewController
                                                           sourceView:(UIView *_Nullable)sourceView
                                                           sourceRect:(CGRect)sourceRect
                                                        barButtonItem:(UIBarButtonItem *_Nullable)barButtonItem
                                                     allowNewComputer:(BOOL)allowNewComputer
                          onSelectComputerNameWithUserComputerHandler:(void (^ _Nullable)(UserComputerWithoutManaged *))selectComputerNameHandler
                                           onSelectNewComputerHandler:(void (^ _Nullable)(void))selectNewComputerHandler {
    // if only one available computer and contains only userId in it, it means no computer connected.

    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:alertControllerTitle message:@"" preferredStyle:UIAlertControllerStyleActionSheet];

    if (availableUserComputers && [availableUserComputers count] > 0 && availableUserComputers[0].computerId) {
        for (UserComputerWithoutManaged *userComputerWithoutManaged in availableUserComputers) {
            NSString *computerName = userComputerWithoutManaged.computerName;

            UIAlertAction *computerNameAction = [UIAlertAction actionWithTitle:computerName style:UIAlertActionStyleDefault handler:^(UIAlertAction *_Nonnull action) {
                if (selectComputerNameHandler) {
                    selectComputerNameHandler(userComputerWithoutManaged);
                }
            }];

            [actionSheet addAction:computerNameAction];
        }
    }

    if (allowNewComputer) {
        if (selectNewComputerHandler) {
            UIAlertAction *newComputerAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Add New Computer", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *_Nonnull action) {
                selectNewComputerHandler();
            }];

            [actionSheet addAction:newComputerAction];
        }
    }

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:nil];

    [actionSheet addAction:cancelAction];

    if ([viewController isVisible]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [actionSheet presentWithViewController:viewController sourceView:sourceView sourceRect:sourceRect barButtonItem:barButtonItem animated:YES completion:nil];
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [actionSheet presentWithAnimated:YES];
        });
    }
}

+ (void)alertInExtensionEmptyUserSessionFromViewController:(UIViewController *)viewController completion:(void (^ _Nullable)(void))completion {
    // alert with delay of 1 sec to prevent method viewDidLoad not finished
    // completion() will not run if alert not display due to [viewController presentedViewController] is not nil.

    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Not login in extension and need login", @"")];

    [Utility viewController:viewController alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:^(UIAlertAction *action) {
        if (completion) {
            completion();
        }
    }];
}

// return nil if device token string not found.
+ (nullable NSString *)prepareDeviceTokenJsonWithUserDefaults:(NSUserDefaults *)userDefaults {
    NSString *deviceTokenJson;

    NSString *deviceToken = [userDefaults objectForKey:USER_DEFAULTS_KEY_REMOTE_NOTIFICATION_DEVICE_TOKEN];

    if (deviceToken) {
        NSString *filelugVersion = [userDefaults objectForKey:USER_DEFAULTS_KEY_MAIN_APP_VERSION];

        NSString *filelugBuild = [userDefaults objectForKey:USER_DEFAULTS_KEY_MAIN_APP_BUILD_NO];

        /*
         {
        "device-token" : "1e39b345af9b036a2fc1066f2689143746f7d1220c23ff1491619a544a167c61",
        "notification-type" : "APNS",
        "device-type" : "IOS",
        "device-version" : "8.3",           // iOS/Android 作業系統版本
        "filelug-version" : "1.1.7",        // Filelug APP 大版號
        "filelug-build" : "2014.09.24.01",  // Filelug APP 小版號
        "badge-number" : 0                   // ignored
        }
         */

        deviceTokenJson = [NSString stringWithFormat:@"{\"device-token\":\"%@\",\"notification-type\":\"%@\",\"device-type\":\"%@\",\"device-version\":\"%@\",\"filelug-version\":\"%@\",\"filelug-build\":\"%@\",\"badge-number\":0}", deviceToken, DEVICE_TOKEN_NOTIFICATION_TYPE_APNS, DEVICE_TOKEN_DEVICE_TYPE_IOS, DEVICE_VERSION, filelugVersion, filelugBuild];
    }

    return deviceTokenJson;
}

+ (NSString *)generateVerificationWithUserId:(NSString *)userId computerId:(NSNumber *)computerId {
    NSString *computerIdString = [computerId stringValue];

    NSString *hash = [[NSString stringWithFormat:@"%@==%@", userId, computerIdString] MD5];

    NSString *verification = [[NSString stringWithFormat:@"%@|%@:%@_%@", userId, hash, computerIdString, hash] SHA256];

    return verification;
}

+ (BOOL)needShowStartupViewController {
    BOOL needSignIn;

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    if ([userDefaults stringForKey:USER_DEFAULTS_KEY_USER_ID]) {
        needSignIn = NO;
    } else {
        UserDao *userDao = [[UserDao alloc] init];

        NSNumber *userCount = [userDao countAllUsers];

        needSignIn = !userCount || ([userCount integerValue] < 1);
    }

    return needSignIn;
}

+ (NSString *)generateVerificationWithAuthorizationCode:(NSString *)authorizationCode locale:(NSString *)locale {
    NSString *authorizationCodeUpperCase = [authorizationCode uppercaseString];

    NSString *authorizationCodeLowerCase = [authorizationCode lowercaseString];

    NSString *hash = [[NSString stringWithFormat:@"%@==%@", authorizationCodeUpperCase, locale] MD5];

    NSString *verification = [[NSString stringWithFormat:@"%@|%@:%@_%@", authorizationCodeLowerCase, hash, locale, hash] SHA256];

    return verification;
}

+ (NSString *)generateVerificationWithCountryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber {
    static NSString *defaultUserId = @"9413";

    NSString *part1 = [[NSString stringWithFormat:@"%@|%@:%@", defaultUserId, countryId, phoneNumber] SHA256];

    NSString *part2 = [[NSString stringWithFormat:@"%@==%@", phoneNumber, countryId] MD5];

    return [NSString stringWithFormat:@"%@%@", part1, part2];
}

+ (BOOL)shouldHideLoginToDemoAccount {
//    for (NSString *name in [NSTimeZone knownTimeZoneNames]) {
//        NSTimeZone *tz = [NSTimeZone timeZoneWithName:name];
//        NSInteger gmtOffset = tz.secondsFromGMT;
//
//        NSLog(@"TZ: %@, secondes from GMT: %ld", name, (long) gmtOffset);
//    }

    NSDateComponents *lastDateComponent = [[NSDateComponents alloc] init];

    [lastDateComponent setYear:YEAR_OF_LAST_DATE_TO_SHOW_DEMO_ACCOUNT];
    [lastDateComponent setMonth:MONTH_OF_LAST_DATE_TO_SHOW_DEMO_ACCOUNT];
    [lastDateComponent setDay:DAY_OF_LAST_DATE_TO_SHOW_DEMO_ACCOUNT];

    // TZ: "Asia/Taipei", secondes from GMT: 28800
    [lastDateComponent setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:TIME_ZONE_OF_LAST_DATE_TO_SHOW_DEMO_ACCOUNT]];

    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *lastDateToShow = [calendar dateFromComponents:lastDateComponent];

    NSDate *currentDate = [NSDate date];

    // if currentDate is later in time than lastDateToShow, hide it
    return ([currentDate compare:lastDateToShow] == NSOrderedDescending);
}

+ (void)viewController:(UIViewController *_Nonnull)viewController useNavigationLargeTitles:(BOOL)useNavigationLargeTitles {
    if ([self isDeviceVersion11OrLater]) {
        UINavigationItemLargeTitleDisplayMode mode;

        if (useNavigationLargeTitles) {
            mode = UINavigationItemLargeTitleDisplayModeAutomatic;
        } else {
            mode = UINavigationItemLargeTitleDisplayModeNever;
        }
        
        viewController.navigationItem.largeTitleDisplayMode = mode;
        viewController.navigationController.navigationBar.prefersLargeTitles = useNavigationLargeTitles;
    }
}

@end
