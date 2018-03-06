#import "FileUploadStatusModel.h"

@implementation FileUploadStatusModel

- (instancetype)initWithTransferKey:(NSString *)transferKey transferredSize:(NSNumber *)transferredSize fileSize:(NSNumber *)fileSize fileLastModifiedDate:(NSNumber *)fileLastModifiedDate {
    self = [super init];

    if (self) {
        self.transferKey = transferKey;
        self.transferredSize = transferredSize;
        self.fileSize = fileSize;
        self.fileLastModifiedDate = fileLastModifiedDate;
    }

    return self;
}

@end
