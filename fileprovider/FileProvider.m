#import "FileProvider.h"

@interface FileProvider ()

@end

@implementation FileProvider

- (NSFileCoordinator *)fileCoordinator {
    NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] init];
    [fileCoordinator setPurposeIdentifier:[self providerIdentifier]];
    return fileCoordinator;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self.fileCoordinator coordinateWritingItemAtURL:[self documentStorageURL] options:0 error:NULL byAccessor:^(NSURL *newURL) {
            // ensure the documentStorageURL actually exists
            NSError *error;
            [[NSFileManager defaultManager] createDirectoryAtURL:newURL withIntermediateDirectories:YES attributes:nil error:&error];
        }];
    }
    return self;
}

- (void)providePlaceholderAtURL:(NSURL *)url completionHandler:(void (^)(NSError *error))completionHandler {
    // Should call + writePlaceholderAtURL:withMetadata:error: with the placeholder URL, then call the completion handler with the error if applicable.

    NSLog(@"providePlaceholderAtURL:%@", url);
    
//    NSString *fileName = [url lastPathComponent];
//    
//    NSURL *placeholderURL = [NSFileProviderExtension placeholderURLForURL:[self.documentStorageURL URLByAppendingPathComponent:fileName]];
//    
//    // TODO: get file size for file at <url> from model
//    NSUInteger fileSize = 0;
//    NSDictionary* metadata = @{ NSURLFileSizeKey : @(fileSize)};
//    [NSFileProviderExtension writePlaceholderAtURL:placeholderURL withMetadata:metadata error:NULL];
    
    if (completionHandler) {
        completionHandler(nil);
    }
}

- (void)startProvidingItemAtURL:(NSURL *)url completionHandler:(void (^)(NSError *))completionHandler {
    // Should ensure that the actual file is in the position returned by URLForItemWithIdentifier:, then call the completion handler
    
    NSLog(@"startProvidingItemAtURL:%@", url);
    
//    NSError *fileError = nil;
//    
//    // TODO: get the contents of file at <url> from model
//    NSData *fileData = [NSData data];
//    
//    [fileData writeToURL:url options:0 error:&fileError];
    
    if (completionHandler) {
        completionHandler(nil);
    }
}


- (void)itemChangedAtURL:(NSURL *)url {
    // For Open and Move modes, you need to upload your document when the host app runs a coordinated write on your document.
    // After the write, the itemChangedAtURL: method of your File Provider is called.
    
    // Called at some point after the file has changed; the provider may then trigger an upload
    
    // TODO: mark file at <url> as needing an update in the model; kick off update process
    NSLog(@"Item changed at URL %@", url);
}

- (void)stopProvidingItemAtURL:(NSURL *)url {
    // Called after the last claim to the file has been released. At this point, it is safe for the file provider to remove the content file.
    // Care should be taken that the corresponding placeholder file stays behind after the content file has been deleted.
    
    NSLog(@"stopProvidingItemAtURL:%@", url);
    
    [[NSFileManager defaultManager] removeItemAtURL:url error:NULL];
    [self providePlaceholderAtURL:url completionHandler:^(NSError * _Nullable error) {
        // TODO: handle any error, do any necessary cleanup
    }];
}

@end
