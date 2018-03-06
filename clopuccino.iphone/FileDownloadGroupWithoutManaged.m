#import "FileDownloadGroupWithoutManaged.h"

@implementation FileDownloadGroupWithoutManaged

- (instancetype)initWithDownloadGroupId:(nullable NSString *)downloadGroupId
                       notificationType:(nullable NSNumber *)notificationType
                        createTimestamp:(nullable NSNumber *)createTimestamp
                       fileTransferKeys:(nullable NSSet<NSString *> *)fileTransferKeys
                         userComputerId:(nullable NSString *)userComputerId {
    self = [super init];

    if (self) {
        self.downloadGroupId = downloadGroupId;
        self.notificationType = notificationType;
        self.createTimestamp = createTimestamp;
        self.fileTransferKeys = fileTransferKeys;
        self.userComputerId = userComputerId;
    }

    return self;
}

- (NSString *)description {
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];
    [description appendFormat:@"self.downloadGroupId=%@", self.downloadGroupId];
    [description appendFormat:@", self.notificationType=%@", self.notificationType];
    [description appendFormat:@", self.createTimestamp=%@", self.createTimestamp];
    [description appendFormat:@", self.fileTransferKeys=%@", self.fileTransferKeys];
    [description appendFormat:@", self.userComputerId=%@", self.userComputerId];
    [description appendString:@">"];
    return description;
}


@end
