#import "TmpUploadFileService.h"
#import "Utility.h"

@implementation TmpUploadFileService

- (instancetype)init {
    self = [super init];
    if (self) {
        // create new NSDictionary for tmp uploaded files if not exists
        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        if (![userDefaults objectForKey:USER_DEFAULTS_KEY_TMP_UPLOAD_FILES]) {
            [userDefaults setObject:[NSDictionary dictionary] forKey:USER_DEFAULTS_KEY_TMP_UPLOAD_FILES];
        }
    }
    
    return self;
}

+ (TmpUploadFileService *)defaultService {
    static TmpUploadFileService *_instance = nil;
    
    @synchronized (self) {
        if (_instance == nil) {
            _instance = [[self alloc] init];
        }
    }
    
    return _instance;
}

- (void)setTmpUploadFileAbsolutePath:(NSString *)tmpUploadFileAbsolutePath forTransferKey:(NSString *)transferKey {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSDictionary *dictionary = [userDefaults dictionaryForKey:USER_DEFAULTS_KEY_TMP_UPLOAD_FILES];
    
    NSMutableDictionary *mutableDictionary = [dictionary mutableCopy];
    
    mutableDictionary[transferKey] = tmpUploadFileAbsolutePath;
    
    [userDefaults setObject:mutableDictionary forKey:USER_DEFAULTS_KEY_TMP_UPLOAD_FILES];
}

- (void)removeAllTmpUploadFileAbsolutePathsWithUserDefaults:(NSUserDefaults *)userDefaults {
    NSDictionary *dictionary = [userDefaults dictionaryForKey:USER_DEFAULTS_KEY_TMP_UPLOAD_FILES];

    if (dictionary) {
        NSFileManager *fileManager = [NSFileManager defaultManager];

        @try {
            // enumerateKeysAndObjectsUsingBlock executes the block by order
            // and the finally block runs after each block in enumerateKeysAndObjectsUsingBlock finished.
            [dictionary enumerateKeysAndObjectsUsingBlock:^(NSString *transferKey, NSString *absolutePath, BOOL *stop) {
                if (absolutePath) {
                    BOOL isDirectory;
                    BOOL fileExists = [fileManager fileExistsAtPath:absolutePath isDirectory:&isDirectory];

                    if (fileExists && !isDirectory) {
                        [fileManager removeItemAtPath:absolutePath error:NULL];

                        [self removeRelatedEmptyFileWithAbsolutePath:absolutePath fileManager:fileManager];
                    }
                }
            }];
        } @finally {
            // reset dictionary
            [userDefaults setObject:[NSDictionary dictionary] forKey:USER_DEFAULTS_KEY_TMP_UPLOAD_FILES];
        }
    }
}

- (void)removeRelatedEmptyFileWithAbsolutePath:(NSString *)absolutePath fileManager:(NSFileManager *)fileManager {
    // delete related-empty file, if any

    NSString *relatedEmptyFilePath = [Utility generateEmptyFilePathFromTmpUploadFilePath:absolutePath];

    BOOL isDirectory;

    BOOL emptyFileExists = [fileManager fileExistsAtPath:relatedEmptyFilePath isDirectory:&isDirectory];

    if (emptyFileExists && !isDirectory) {
        [fileManager removeItemAtPath:relatedEmptyFilePath error:NULL];
    }
}

- (void)removeTmpUploadFileAbsoluePathWithTransferKey:(NSString *)transferKey
                                  removeTmpUploadFile:(BOOL)removeTmpUploadFile
                                          deleteError:(NSError *_Nullable __autoreleasing *_Nullable)deleteError {
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSDictionary *dictionary = [userDefaults dictionaryForKey:USER_DEFAULTS_KEY_TMP_UPLOAD_FILES];
    
    if (removeTmpUploadFile) {
        NSString *absolutePath = dictionary[transferKey];
        
        if (absolutePath) {
            NSFileManager *fileManager = [NSFileManager defaultManager];
            
            BOOL isDirectory;
            BOOL fileExists = [fileManager fileExistsAtPath:absolutePath isDirectory:&isDirectory];
            
            if (fileExists && !isDirectory) {
                [[NSFileManager defaultManager] removeItemAtPath:absolutePath error:deleteError];

                [self removeRelatedEmptyFileWithAbsolutePath:absolutePath fileManager:fileManager];
            }
        }
    }
    
    NSMutableDictionary *mutableDictionary = [dictionary mutableCopy];
    
    [mutableDictionary removeObjectForKey:transferKey];
    
    [userDefaults setObject:mutableDictionary forKey:USER_DEFAULTS_KEY_TMP_UPLOAD_FILES];
}

@end
