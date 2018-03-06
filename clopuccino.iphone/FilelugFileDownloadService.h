#import <Foundation/Foundation.h>

@protocol BackgroundTransferService;
@class HierarchicalModelWithoutManaged;

NS_ASSUME_NONNULL_BEGIN

@interface FilelugFileDownloadService : NSObject <BackgroundTransferService, NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDownloadDelegate>

@property(nonatomic, readonly) NSURLRequestCachePolicy cachePolicy;

@property(nonatomic, readonly) NSTimeInterval timeInterval;

- (instancetype)init;

- (instancetype)initWithBackgroundCompletionHandler:(void (^ _Nullable)(void))completionHandler;

// Use this method only when you want to download a file on the following cases :
// 1. The realServerPath of the file not found in local db table FileTransfer
// 2. The realServerPath of the file found in local db table FileTransfer and the status is success
// 3. The realServerPath of the file found in local db table FileTransfer and the status is failure, and the user wants to download again from the start, instead of using resmue data.
//
// In case 1 & 2, you must create download summary in server before invoking this method.
// In case 3, you must replace the old transfer key with the new one in server before invoking this method.
- (void)downloadFromStartWithTransferKey:(NSString *)transferKey
                          realServerPath:(NSString *)realServerPath
                           fileSeparator:(NSString *)fileSeparator
                         downloadGroupId:(NSString *_Nullable)downloadGroupId
                          userComputerId:(NSString *)userComputerId
                               sessionId:(NSString *)sessionId
                    actionsAfterDownload:(NSString *_Nullable)actionsAfterDownload
     addToStartTimestampWithMilliseconds:(unsigned long)millisecondsToAdd
                       completionHandler:(void (^ _Nullable)(void))completionHandler;

// Use this method only when the realServerPath of the file found in local db table FileTransfer and the status is failure, and the user wants to use the resmue data to resume downloading file.
// The parameter resumeData can't be nil. If resumeData is nil, you should use [self downloadFromStartWithTransferKey:...] instead.
- (void)resumeDownloadWithRealFilePath:(NSString *)realServerPath resumeData:(NSData *_Nullable)resumeData completionHandler:(void (^ _Nullable)(void))completionHandler;

// Event if the transferKey is nil, the completionHandler still be invoked.
// Even if the download task not found, the completionHandler still be invoked.
- (void)cancelDownloadWithTransferKey:(NSString *)transferKey completionHandler:(void (^ _Nullable)(void))completionHandler;

- (void)cancelAllFilesDownloading;

#pragma mark - Manage resumeData

// append

- (void)addResumeData:(NSData *_Nullable)resumeData toFileTransferWithTransferKey:(NSString *)transferKey completionHandler:(void (^ _Nullable)(NSError *_Nullable error))completionHandler;

// find

- (nullable NSData *)resumeDataFromFileTransferWithTransferKey:(NSString *)transferKey error:(NSError *_Nullable __autoreleasing *_Nullable)error;

// remove single record

- (void)removeResumeDataFromFileTransferWithTransferKey:(NSString *)transferKey completionHandler:(void (^ _Nullable)(NSError *_Nullable))completionHandler;

- (void)removeResumeDataWithRealServerPath:(NSString *)realServerPath userComputerId:(NSString *)userComputerId completionHandler:(void (^ _Nullable)(NSError *_Nullable))completionHandler;

// DEBUG: Removed when in production!

- (void)sendSingleSuccessLocalNotificationWithTransferKey:(NSString *)transferKey filename:(NSString *)filename;

@end

NS_ASSUME_NONNULL_END
