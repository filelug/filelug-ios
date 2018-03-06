#import <Foundation/Foundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

NS_ASSUME_NONNULL_BEGIN

@interface AssetFileWithoutManaged : NSObject <NSCopying>

@property(nonatomic, strong) NSString *userComputerId;

@property(nonatomic, strong) NSString *fileUploadGroupId;

@property(nonatomic, strong) NSString *transferKey;

// For a ALAsset, the absolute path of asset url
// For a PHAsset, the local identifier of PHAsset
// For a shared file, the relative path of the downloaded file, e.g. FileTransfer.localPath
@property(nonatomic, strong) NSString *assetURL;

// NSUInteger wrapped by NSNumber, values including:
// ASSET_FILE_SOURCE_TYPE_UNKNOWN,
// ASSET_FILE_SOURCE_TYPE_ALASSET,
// ASSET_FILE_SOURCE_TYPE_PHASSET,
// ASSET_FILE_SOURCE_TYPE_SHARED_FILE,
// ASSET_FILE_SOURCE_TYPE_EXTERNAL_FILE
@property(nonatomic, strong) NSNumber *sourceType;

@property(nonatomic, strong) NSString *serverDirectory;

@property(nonatomic, strong) NSString *serverFilename;

@property(nonatomic, strong) NSNumber *_Nullable startTimestamp;

@property(nonatomic, strong) NSNumber *_Nullable endTimestamp;

@property(nonatomic, strong) NSString *_Nullable status;

@property(nonatomic, strong) UIImage *_Nullable thumbnail;

@property(nonatomic, strong) NSNumber *_Nullable totalSize;

@property(nonatomic, strong) NSNumber *_Nullable transferredSize;

@property(nonatomic, strong) NSNumber *_Nullable transferredSizeBeforeResume;

@property(nonatomic, strong) NSNumber *_Nullable waitToConfirm;

// For sourceType ASSET_FILE_SOURCE_TYPE_SHARED_FILE, the value is the FileTransfer.transferKey
// For sourceType of others, the value is nil
@property (nonatomic, strong) NSString *_Nullable downloadedFileTransferKey;

//- (id)initWithUserComputerId:(NSString *)userComputerId fileUploadGroupId:(NSString *)fileUploadGroupId transferKey:(NSString *)transferKey assetURL:(NSString *)assetURL sourceType:(NSUInteger)sourceType serverDirectory:(NSString *)serverDirectory serverFilename:(NSString *)serverFilename status:(NSString *)status thumbnail:(UIImage *)thumbnail totalSize:(NSNumber *)totalSize transferredSize:(NSNumber *)transferredSize transferredSizeBeforeResume:(NSNumber *)transferredSizeBeforeResume startTimestamp:(NSNumber *)startTimestamp endTimestamp:(NSNumber *)endTimestamp waitToConfirmed:(NSNumber *)waitToConfirmed;

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
   downloadedFileTransferKey:(NSString *_Nullable)downloadeFileTransferKey;

- (NSString *)description;

- (id)copyWithZone:(nullable NSZone *)zone;

@end

NS_ASSUME_NONNULL_END
