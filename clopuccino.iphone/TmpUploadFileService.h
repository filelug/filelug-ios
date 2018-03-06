#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TmpUploadFileService : NSObject

+ (TmpUploadFileService *)defaultService;

- (void)setTmpUploadFileAbsolutePath:(NSString *)tmpUploadFileAbsolutePath forTransferKey:(NSString *)transferKey;

- (void)removeAllTmpUploadFileAbsolutePathsWithUserDefaults:(NSUserDefaults *)userDefaults;

- (void)removeTmpUploadFileAbsoluePathWithTransferKey:(NSString *)transferKey
                                  removeTmpUploadFile:(BOOL)removeTmpUploadFile
                                          deleteError:(NSError *_Nullable __autoreleasing *_Nullable)deleteError;

@end

NS_ASSUME_NONNULL_END
