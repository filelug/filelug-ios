#import <Foundation/Foundation.h>

@interface FolderWatcher : NSObject

- (instancetype)initWithFolderURL:(NSURL *)folderURL writeAction:(dispatch_block_t)writeAction;

@property(nonatomic, readonly) NSURL *folderURL;

@end
