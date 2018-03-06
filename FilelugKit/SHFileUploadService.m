#import "BackgroundTransferService.h"
#import "SHFileUploadService.h"
#import "AssetUploadService.h"
#import "AssetFileDao.h"
#import "DirectoryService.h"
#import "Utility.h"
#import "FileUploadStatusModel.h"

@interface SHFileUploadService ()

@property(nonatomic, nonnull, strong) AssetFileDao *assetFileDao;

@property(nonatomic, nonnull, strong) DirectoryService *directoryService;

@property(nonatomic, strong) AssetUploadService *assetUploadService;

@end

@implementation SHFileUploadService

//static NSURLSession *backgroundSession;

static void (^backgroundCompletionHandler)(void);

@synthesize backgroundSession;

- (instancetype)init {
    self = [super init];

    if (self) {
        [self initialConfigureWithBackgroundCompletionHandler:nil];
    }

    return self;
}

- (instancetype)initWithBackgroundCompletionHandler:(void (^ _Nullable)(void))completionHandler {
    self = [super init];

    if (self) {
        [self initialConfigureWithBackgroundCompletionHandler:completionHandler];
    }

    return self;
}

- (void)initialConfigureWithBackgroundCompletionHandler:(void (^ _Nullable)(void))completionHandler {
    @synchronized (self) {
        // The completionHandler must be added in before creating background session object
        // in order to following the description in [NSURLSessionDelegate URLSessionDidFinishEventsForBackgroundURLSession:]
        // see the url for more information: https://developer.apple.com/documentation/foundation/nsurlsessiondelegate/1617185-urlsessiondidfinisheventsforback
        // if completionHandler is nil, keep the old one, if any.
        if (completionHandler) {
            backgroundCompletionHandler = completionHandler;
        }

        if (!self.backgroundSession) {
            NSString *backgroundUploadIdentifier = [Utility backgroundUploadIdentifierForShareExtension];

            NSURLSessionConfiguration *sessionConfiguration =
                    [self sessionConfigureWithBackgroundSessionIdentifier:backgroundUploadIdentifier
                                                              cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                             timeInterval:CONNECTION_TIME_INTERVAL_FOR_BACKGROUND_UPLOAD];

            self.backgroundSession = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:[[NSOperationQueue alloc] init]];
        }
    }
}

- (NSURLSessionConfiguration *)sessionConfigureWithBackgroundSessionIdentifier:(NSString *)backgroundSessionIdentifier
                                                                   cachePolicy:(enum NSURLRequestCachePolicy)policy
                                                                  timeInterval:(NSTimeInterval)interval {
    NSURLSessionConfiguration *configuration;

    configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:backgroundSessionIdentifier];

    // in iOS 8 or later, user timeoutIntervalForResource to set timeout of background session, instead of using timeoutIntervalForRequest
    configuration.timeoutIntervalForResource = interval;

    configuration.timeoutIntervalForRequest = interval;

    configuration.requestCachePolicy = policy;

    // for app extensions, use share container identifier as the value
    configuration.sharedContainerIdentifier = APP_GROUP_NAME;

    // For background sessions, the default value of URLCache is nil
//    NSString *cachePath = [[DirectoryService localFileRootDirectoryPath] stringByAppendingPathComponent:@"upload"];
//
//    // 16 K, 256 MB
//    configuration.URLCache = [[NSURLCache alloc] initWithMemoryCapacity:16384 diskCapacity:268435456 diskPath:cachePath];

    // The value is default set to YES
    configuration.allowsCellularAccess = YES;

    // to support background upload
    configuration.sessionSendsLaunchEvents = YES;

    // To prevent the system delay transferring large files until the device is plugged in
    // or transferring files only when connected to the network via Wi-Fi,
    // MAKE SURE to set the value to NO
    configuration.discretionary = NO;

    return configuration;
}

- (AssetFileDao *)assetFileDao {
    if (!_assetFileDao) {
        _assetFileDao = [[AssetFileDao alloc] init];
    }

    return _assetFileDao;
}

- (DirectoryService *)directoryService {
    if (!_directoryService) {
        _directoryService = [[DirectoryService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy
                                                             timeInterval:CONNECTION_TIME_INTERVAL];
    }

    return _directoryService;
}

- (AssetUploadService *)assetUploadService {
    if (!_assetUploadService) {
        _assetUploadService = [[AssetUploadService alloc] init];
    }

    return _assetUploadService;
}

- (void)uploadFileFromFileObject:(id)fileObject
                      sourceType:(NSNumber *)sourceType
                       sessionId:(NSString *)sessionId
               fileUploadGroupId:(NSString *)fileUploadGroupId
                       directory:(NSString *)directory
                        filename:(NSString *)filename
   shouldCheckIfLocalFileChanged:(BOOL)shouldCheckIfLocalFileChanged
           fileUploadStatusModel:(FileUploadStatusModel *)fileUploadStatusModel
 addToStartTimestampWithMillisec:(unsigned long)millisecondsToAdd
               completionHandler:(void (^ _Nullable)(NSError *_Nullable))completionHandler {
    [self.assetUploadService uploadFileWithURLSession:self.backgroundSession
                                           fileObject:fileObject
                                           sourceType:sourceType
                                            sessionId:sessionId
                                    fileUploadGroupId:fileUploadGroupId
                                            directory:directory
                                             filename:filename
                        shouldCheckIfLocalFileChanged:shouldCheckIfLocalFileChanged
                                fileUploadStatusModel:fileUploadStatusModel
                      addToStartTimestampWithMillisec:millisecondsToAdd
                                    completionHandler:completionHandler];
}

//#pragma mark - BackgroundTransferService
//
//- (NSURLSession *_Nullable)backgroundSession {
//    return backgroundSession;
//}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    [self.assetUploadService URLSession:session task:task didSendBodyData:bytesSent totalBytesSent:totalBytesSent totalBytesExpectedToSend:totalBytesExpectedToSend];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    [self.assetUploadService URLSession:session task:task didCompleteWithError:error];
}

#pragma mark - NSURLSessionDelegate

// invoked when all upload completed with or without error.
- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
    if (backgroundCompletionHandler) {
        void (^completionHandler)(void) = backgroundCompletionHandler;
        backgroundCompletionHandler = nil;

        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler();
        });
    }

    if (self.backgroundSession && [session.configuration.identifier isEqualToString:self.backgroundSession.configuration.identifier]) {
        [self.backgroundSession invalidateAndCancel];

        self.backgroundSession = nil;
    }
    
//    [self.assetUploadService URLSessionDidFinishEventsForBackgroundURLSession:session];
//
//    // DEBUG
//    NSLog(@"Invoked [SHFileUploadService URLSessionDidFinishEventsForBackgroundURLSession:] with session identifier: %@", session.configuration.identifier);
}

@end
