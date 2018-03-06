@protocol BackgroundTransferService <NSObject>

@required

// Set as Nullable because it will be set to nil after all tasks are completed.
// Usually set in [NSURLSessionDelegate URLSessionDidFinishEventsForBackgroundURLSession:]
@property (nullable, nonatomic, strong) NSURLSession *backgroundSession;

//- (NSURLSession *_Nullable)backgroundSession;



@end
