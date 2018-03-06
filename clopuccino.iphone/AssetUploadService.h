#import <UIKit/UIKit.h>

@class AssetFile;
@class AssetFileWithoutManaged;
@class PHAsset;
@class PHImageRequestOptions;
@class FileUploadStatusModel;

NS_ASSUME_NONNULL_BEGIN

@interface AssetUploadService : NSObject

// Upload one file
// The type of fileObject is different base on the sourceType:
// ASSET_FILE_SOURCE_TYPE_SHARED_FILE   --> NSString, the absolute file path, e.g. {Shared_File_Folder}/any-subfolder/IMG_7243.JPG
// ASSET_FILE_SOURCE_TYPE_PHASSET       --> PHAsset (for iOS 8 or later)
// ASSET_FILE_SOURCE_TYPE_EXTERNAL_FILE --> NSString, the absolute file path, e.g. {External_File_Folder}/IMG_7243.JPG
//
// DO NOT RUN THIS METHOD ON MAIN THREAD!!
- (void)uploadFileWithURLSession:(NSURLSession *)urlSession
                      fileObject:(id)fileObject
                      sourceType:(NSNumber *)sourceType
                       sessionId:(NSString *)sessionId
               fileUploadGroupId:(NSString *)fileUploadGroupId
                       directory:(NSString *)directory
                        filename:(NSString *)filename
   shouldCheckIfLocalFileChanged:(BOOL)shouldCheckIfLocalFileChanged
           fileUploadStatusModel:(FileUploadStatusModel *)fileUploadStatusModel
 addToStartTimestampWithMillisec:(unsigned long)millisecondsToAdd
               completionHandler:(void (^ _Nullable)(NSError *_Nullable))completionHandler;

- (void)cancelUploadFileWithTransferKey:(NSString *)transferKey
                             urlSession:(NSURLSession *)urlSession
                      completionHandler:(void (^ _Nullable)(void))completionHandler;

#pragma mark - mimic NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend;

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *_Nullable)error;

#pragma mark - mimic NSURLSessionDelegate

// invoked when all upload completed with or without error.
- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session;

@end

NS_ASSUME_NONNULL_END
