#import <Foundation/Foundation.h>


@interface FileRenameModel : NSObject

// file absolute path before rename
@property(nonatomic, strong) NSString *beforePath;

// file absolute path after rename
@property(nonatomic, strong) NSString *afterPath;

// file name before rename
@property(nonatomic, strong) NSString *beforeFilename;

// file name after rename
@property(nonatomic, strong) NSString *afterFilename;

- (id)initWithOldPath:(NSString *)oldPath newPath:(NSString *)newPath oldFilename:(NSString *)oldFilename newFilename:(NSString *)newFilename;

@end