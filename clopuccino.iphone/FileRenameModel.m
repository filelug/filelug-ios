#import "FileRenameModel.h"


@implementation FileRenameModel


- (id)initWithOldPath:(NSString *)oldPath newPath:(NSString *)newPath oldFilename:(NSString *)oldFilename newFilename:(NSString *)newFilename {
    if (self = [super init]) {
        _beforePath = oldPath;
        _afterPath = newPath;
        _beforeFilename = oldFilename;
        _afterFilename = newFilename;
    }

    return self;
}

@end