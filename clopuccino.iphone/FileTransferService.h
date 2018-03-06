#import <Foundation/Foundation.h>
#import "FileTransferWithoutManaged.h"

@class HierarchicalModelWithoutManaged;

NS_ASSUME_NONNULL_BEGIN

@interface FileTransferService : NSObject

// Use this method only when you want to download a file on the following cases :
// 1. The realServerPath of the file not found in local db table FileTransfer
// 2. The realServerPath of the file found in local db table FileTransfer and the status is success
// 3. The realServerPath of the file found in local db table FileTransfer and the status is failure, and the user wants to download again from the start, instead of using resmue data.
//
// In case 1 & 2, you must create download summary in server before invoking this method.
// In case 3, you must replace the old transfer key with the new one in server before invoking this method.
- (void)downloadFromStartWithURLSession:(NSURLSession *)urlSession
                            transferKey:(NSString *)transferKey
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
- (void)resumeDownloadWithURLSession:(NSURLSession *)urlSession realFilePath:(NSString *)realServerPath resumeData:(NSData *_Nullable)resumeData completionHandler:(void (^ _Nullable)(void))completionHandler;

// Event if the transferKey is nil, the completionHandler still be invoked.
// Even if the download task not found, the completionHandler still be invoked.
- (void)cancelDownloadWithURLSession:(NSURLSession *)urlSession transferKey:(NSString *)transferKey completionHandler:(void (^ _Nullable)(void))completionHandler;

- (void)cancelAllFilesDownloadingWithURLSession:(NSURLSession *)urlSession;

#pragma mark - Manage resumeData

// append

- (void)addResumeData:(NSData *_Nullable)resumeData toFileTransferWithTransferKey:(NSString *)transferKey completionHandler:(void (^ _Nullable)(NSError *))completionHandler;

// find

- (NSData *)resumeDataFromFileTransferWithTransferKey:(NSString *)transferKey error:(NSError *_Nullable __autoreleasing *_Nullable)error;

// remove single record

- (void)removeResumeDataFromFileTransferWithTransferKey:(NSString *)transferKey completionHandler:(void (^ _Nullable)(NSError *_Nullable))completionHandler;

- (void)removeResumeDataWithRealServerPath:(NSString *)realServerPath userComputerId:(NSString *)userComputerId completionHandler:(void (^ _Nullable)(NSError *_Nullable))completionHandler;

#pragma mark - mimic NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite completionHandler:(void (^ _Nullable)(NSString *_Nullable, float, FileTransferWithoutManaged *_Nullable))completionHandler;

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes completionHandler:(void (^ _Nullable)(NSString *_Nullable, FileTransferWithoutManaged *_Nullable))completionHandler;

// The second argument of the completionHandler will be nil if error on file moving.
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location completionHandler:(void (^ _Nullable)(NSString *_Nullable, NSString *_Nullable, FileTransferWithoutManaged *))completionHandler;

#pragma mark - mimic NSURLSessionTaskDelegate

// If file downloaded successfully, invoked after URLSession:downloadTask:didFinishDownloadingToURL:completionHandler:.
// If file downloaded failed, invoked after error responsed.
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *_Nullable)error completionHandler:(void (^ _Nullable)(NSString *_Nullable, FileTransferWithoutManaged *))completionHandler;

@end

NS_ASSUME_NONNULL_END
