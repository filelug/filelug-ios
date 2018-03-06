#import "FolderWatcher.h"

@interface FolderWatcher ()

@property(copy, nonatomic) dispatch_block_t writeAction;
@property(nonatomic) dispatch_source_t source;
@property(nonatomic) dispatch_queue_t queue;
@property(nonatomic) int fileDescriptor;

@end

@implementation FolderWatcher

- (instancetype)initWithFolderURL:(NSURL *)folderURL writeAction:(dispatch_block_t)writeAction; {
    if (!(self = [super init])) return nil;

    _folderURL = folderURL;
    _writeAction = [writeAction copy];
    _fileDescriptor = open([[folderURL path] fileSystemRepresentation], O_EVTONLY);
    _queue = dispatch_queue_create("com.filelug.FilelugKit.folderwatcher", 0);
    _source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, _fileDescriptor, DISPATCH_VNODE_WRITE, _queue);

    dispatch_source_set_cancel_handler(_source, ^{
        close(_fileDescriptor);
    });

    dispatch_source_set_event_handler(_source, _writeAction);

    dispatch_resume(_source);

    return self;
}

- (void)dealloc {
    dispatch_source_cancel(_source);
}

@end
