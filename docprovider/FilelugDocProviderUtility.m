#import <MobileCoreServices/MobileCoreServices.h>
#import "FilelugDocProviderUtility.h"

@implementation FilelugDocProviderUtility

+ (id)instantiateViewControllerWithIdentifier:(NSString *)identifier {
    return [Utility instantiateViewControllerWithIdentifier:identifier fromStoryboardWithName:@"MainInterface"];
}

+ (NSString *)docProviderFileRootPathWithDocumentStorageURL:(NSURL *)documentStorageURL userComputerId:(NSString *)userComputerId {
    NSString *fileRootPath;

    if (userComputerId) {
        // stringByStandardizingPath is not url-encoded, see the following for more information:
        // https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSString_Class/#//apple_ref/occ/instp/NSString/stringByStandardizingPath
        NSString *standardizePathFromUserComputerId = [userComputerId stringByStandardizingPath];

        fileRootPath = [[documentStorageURL path] stringByAppendingPathComponent:standardizePathFromUserComputerId];
    }

    return fileRootPath;
}

+ (NSString *)docProviderFilePathWithDocumentStorageURL:(NSURL *)documentStorageURL userComputerId:(NSString *)userComputerId downloadedFileLocalPath:(NSString *)downloadedFileLocalPath {
    NSString *filePath;

    NSString *fileRootPath = [self docProviderFileRootPathWithDocumentStorageURL:documentStorageURL userComputerId:userComputerId];

    if (fileRootPath) {
        filePath = [fileRootPath stringByAppendingFormat:@"/%@", downloadedFileLocalPath];
    }

    return filePath;
}

+ (BOOL)filename:(NSString *)filename conformToValidTypes:(NSArray *)validTypes {
    BOOL disabledCell = YES;

    if (filename && validTypes && [validTypes count] > 0) {
        NSString *extension = [filename pathExtension];

        if (extension && [extension length] > 0) {
            CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef) extension, NULL);

            for (NSString *typeString in validTypes) {
                if (UTTypeConformsTo(uti, (__bridge CFStringRef) typeString)) {
                    disabledCell = NO;

                    break;
                }
            }
        } else {
            disabledCell = NO;
        }
    } else {
        disabledCell = NO;
    }

    return disabledCell;
}

@end
