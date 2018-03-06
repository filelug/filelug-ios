#import "TransferHistoryModel.h"


@implementation TransferHistoryModel {

}
- (id)initWithComputerGroup:(NSString *)computerGroup computerName:(NSString *)computerName fileSize:(NSNumber *)fileSize endTimestamp:(NSNumber *)endTimestamp filename:(NSString *)filename {
    if (self = [super init]) {
        _computerGroup = computerGroup;
        _computerName = computerName;
        _fileSize = fileSize;
        _endTimestamp = endTimestamp;
        _filename = filename;
    }

    return self;
}

@end