#import "AssetFileWithoutManaged.h"


@implementation AssetFileWithoutManaged {

}

//- (id)initWithUserComputerId:(NSString *)userComputerId fileUploadGroupId:(NSString *)fileUploadGroupId transferKey:(NSString *)transferKey assetURL:(NSString *)assetURL sourceType:(NSUInteger)sourceType serverDirectory:(NSString *)serverDirectory serverFilename:(NSString *)serverFilename status:(NSString *)status thumbnail:(UIImage *)thumbnail totalSize:(NSNumber *)totalSize transferredSize:(NSNumber *)transferredSize transferredSizeBeforeResume:(NSNumber *)transferredSizeBeforeResume startTimestamp:(NSNumber *)startTimestamp endTimestamp:(NSNumber *)endTimestamp waitToConfirmed:(NSNumber *)waitToConfirmed {
//    if (self = [super init]) {
//        _userComputerId = userComputerId;
//        _fileUploadGroupId = fileUploadGroupId;
//        _transferKey = transferKey;
//        _assetURL = assetURL;
//        _sourceType = @(sourceType);
//        _serverDirectory = serverDirectory;
//        _serverFilename = serverFilename;
//        _status = status;
//        _thumbnail = thumbnail;
//        _totalSize = totalSize;
//        _transferredSize = transferredSize;
//        _transferredSizeBeforeResume = transferredSizeBeforeResume;
//        _startTimestamp = startTimestamp;
//        _endTimestamp = endTimestamp;
//        _waitToConfirm = waitToConfirmed;
//    }
//
//    return self;
//}

- (id)initWithUserComputerId:(NSString *)userComputerId
           fileUploadGroupId:(NSString *)fileUploadGroupId
                 transferKey:(NSString *)transferKey
                    assetURL:(NSString *)assetURL
                  sourceType:(NSUInteger)sourceType
             serverDirectory:(NSString *)serverDirectory
              serverFilename:(NSString *)serverFilename
                      status:(NSString *_Nullable)status
                   thumbnail:(UIImage *_Nullable)thumbnail
                   totalSize:(NSNumber *_Nullable)totalSize
             transferredSize:(NSNumber *_Nullable)transferredSize
 transferredSizeBeforeResume:(NSNumber *_Nullable)transferredSizeBeforeResume
              startTimestamp:(NSNumber *_Nullable)startTimestamp
                endTimestamp:(NSNumber *_Nullable)endTimestamp
             waitToConfirmed:(NSNumber *_Nullable)waitToConfirmed
   downloadedFileTransferKey:(NSString *_Nullable)downloadeFileTransferKey {
    if (self = [super init]) {
        _userComputerId = userComputerId;
        _fileUploadGroupId = fileUploadGroupId;
        _transferKey = transferKey;
        _assetURL = assetURL;
        _sourceType = @(sourceType);
        _serverDirectory = serverDirectory;
        _serverFilename = serverFilename;
        _status = status;
        _thumbnail = thumbnail;
        _totalSize = totalSize;
        _transferredSize = transferredSize;
        _transferredSizeBeforeResume = transferredSizeBeforeResume;
        _startTimestamp = startTimestamp;
        _endTimestamp = endTimestamp;
        _waitToConfirm = waitToConfirmed;
        _downloadedFileTransferKey = downloadeFileTransferKey;
    }

    return self;
}

- (NSString *)description {
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];
    [description appendFormat:@"self.userComputerId=%@", self.userComputerId];
    [description appendFormat:@", self.fileUploadGroupId=%@", self.fileUploadGroupId];
    [description appendFormat:@", self.transferKey=%@", self.transferKey];
    [description appendFormat:@", self.assetURL=%@", self.assetURL];
    [description appendFormat:@", self.sourceType=%@", self.sourceType];
    [description appendFormat:@", self.serverDirectory=%@", self.serverDirectory];
    [description appendFormat:@", self.serverFilename=%@", self.serverFilename];
    [description appendFormat:@", self.startTimestamp=%@", self.startTimestamp];
    [description appendFormat:@", self.endTimestamp=%@", self.endTimestamp];
    [description appendFormat:@", self.status=%@", self.status];
    [description appendFormat:@", self.thumbnail=%@", self.thumbnail];
    [description appendFormat:@", self.totalSize=%@", self.totalSize];
    [description appendFormat:@", self.transferredSize=%@", self.transferredSize];
    [description appendFormat:@", self.transferredSizeBeforeResume=%@", self.transferredSizeBeforeResume];
    [description appendFormat:@", self.waitToConfirm=%@", self.waitToConfirm];
    [description appendFormat:@", self.downloadedFileTransferKey=%@", self.downloadedFileTransferKey];
    [description appendString:@">"];
    return description;
}

- (id)copyWithZone:(nullable NSZone *)zone {
    AssetFileWithoutManaged *copy = (AssetFileWithoutManaged *) [[[self class] allocWithZone:zone] init];

    if (copy != nil) {
        copy.userComputerId = self.userComputerId;
        copy.fileUploadGroupId = self.fileUploadGroupId;
        copy.transferKey = self.transferKey;
        copy.assetURL = self.assetURL;
        copy.sourceType = self.sourceType;
        copy.serverDirectory = self.serverDirectory;
        copy.serverFilename = self.serverFilename;
        copy.startTimestamp = self.startTimestamp;
        copy.endTimestamp = self.endTimestamp;
        copy.status = self.status;
        copy.thumbnail = self.thumbnail;
        copy.totalSize = self.totalSize;
        copy.transferredSize = self.transferredSize;
        copy.transferredSizeBeforeResume = self.transferredSizeBeforeResume;
        copy.waitToConfirm = self.waitToConfirm;
        copy.downloadedFileTransferKey = self.downloadedFileTransferKey;
    }

    return copy;
}


@end
