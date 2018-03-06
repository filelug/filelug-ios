#import "UploadItem.h"

@implementation UploadItem

- (NSString *)description {
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];
    [description appendFormat:@"size of data=%lu", (unsigned long) (self.data ? [self.data length] : 0)];
    [description appendFormat:@", self.url=%@", self.url];
    [description appendFormat:@", self.utcoreType=%@", self.utcoreType];
    [description appendFormat:@", self.fileExtension=%@", self.fileExtension];
    [description appendFormat:@", self.mimeType=%@", self.mimeType];
    [description appendString:@">"];
    return description;
}


@end
