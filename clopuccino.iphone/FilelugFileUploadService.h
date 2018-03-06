@protocol BackgroundTransferService;

NS_ASSUME_NONNULL_BEGIN

@interface FilelugFileUploadService : NSObject <BackgroundTransferService, NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

- (instancetype)init;

- (instancetype)initWithBackgroundCompletionHandler:(void (^ _Nullable)(void))completionHandler;

// Upload one file
// The type of fileObject is different base on the sourceType:
// ASSET_FILE_SOURCE_TYPE_SHARED_FILE   --> NSString, the absolute file path, e.g. {Shared_File_Folder}/any-subfolder/IMG_7243.JPG
// ASSET_FILE_SOURCE_TYPE_PHASSET       --> PHAsset (for iOS 8 or later)
// ASSET_FILE_SOURCE_TYPE_EXTERNAL_FILE --> NSString, the absolute file path, e.g. {External_File_Folder}/IMG_7243.JPG
//
// DO NOT RUN THIS METHOD ON MAIN THREAD!!
- (void)uploadFileFromFileObject:(id)fileObject
                      sourceType:(NSNumber *)sourceType
                       sessionId:(NSString *)sessionId
               fileUploadGroupId:(NSString *)fileUploadGroupId
                       directory:(NSString *)directory
                        filename:(NSString *)filename
   shouldCheckIfLocalFileChanged:(BOOL)shouldCheckIfLocalFileChanged
           fileUploadStatusModel:(FileUploadStatusModel *)fileUploadStatusModel
 addToStartTimestampWithMillisec:(unsigned long)millisecondsToAdd
               completionHandler:(void (^ _Nullable)(NSError *_Nullable))completionHandler;

- (void)cancelUploadFile:(NSString *)transferKey completionHandler:(void (^ _Nullable)(void))completionHandler;

@end

NS_ASSUME_NONNULL_END
