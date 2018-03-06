#import "RootDirectoryModel.h"

@implementation RootDirectoryModel

- (instancetype)initWithLabel:(NSString *)label path:(NSString *)path realPath:(NSString *)realPath type:(NSString *)type {
    self = [super init];
    
    if (self) {
        self.directoryLabel = label;
        self.directoryPath = path;
        self.directoryRealPath = realPath;
        self.type = type;
    }
    
    return self;
}

- (NSString *)displayNameForCellLabelText {
    NSString *text;

    if (self.directoryLabel && [self.directoryLabel stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
        text = self.directoryLabel;
    } else if (self.directoryPath && [self.directoryPath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
        text = self.directoryPath;
    } else {
        text = self.directoryRealPath;
    }

    return text;
}

#pragma mark -- NSCopying

- (id)copyWithZone:(NSZone *)zone {
    RootDirectoryModel *newModel = [RootDirectoryModel allocWithZone:zone];

    [newModel setDirectoryLabel:self.directoryLabel];
    [newModel setDirectoryPath:self.directoryPath];
    [newModel setDirectoryRealPath:self.directoryRealPath];
    [newModel setType:self.type];

    return newModel;
}

@end
