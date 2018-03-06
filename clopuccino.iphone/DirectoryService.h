#import <Foundation/Foundation.h>
#import <Photos/Photos.h>

@class HierarchicalModelWithoutManaged;
@class FileRenameModel;
@class AssetFileDao;
@class AuthService;
@class FileTransferDao;
@class FileTransferWithoutManaged;
@class FileUploadStatusModel;
@class HierarchicalModelDao;
@class AssetFileWithoutManaged;

@interface DirectoryService : NSObject

@property(nonatomic, assign) NSURLRequestCachePolicy cachePolicy;

@property(nonatomic, assign) NSTimeInterval timeInterval;

@property(nonatomic, strong) AssetFileDao *assetFileDao;

@property(nonatomic, strong) FileTransferDao *fileTransferDao;

@property(nonatomic, strong) HierarchicalModelDao *hierarchicalModelDao;

@property(nonatomic, strong) AuthService *authService;

+ (HierarchicalModelWithoutManaged *)parseJsonAsHierarchicalModel:(NSData *)data userComputerId:(NSString *)userComputerId error:(NSError * __autoreleasing *)error;

+ (FileRenameModel *)parseJsonAsFileRenameModel:(NSData *)data error:(NSError * __autoreleasing *)error;

+ (NSMutableArray *)parseJsonAsTransferHistoryModelArray:(NSData *)data error:(NSError * __autoreleasing *)error;

+ (UIImage *)imageForServerFilePath:(NSString *)serverFilePath fileSeparator:(NSString *)fileSeparator isDirectory:(BOOL)isDirectory;

+ (UIImage *)imageForLocalFilePath:(NSString *)localFilePath isDirectory:(BOOL)isDirectory;

+ (UIImage *)imageForFileExtension:(NSString *)fileExtension;

+ (UIImage *)imageForParentPath:(NSString *)parentPath fileName:(NSString *)fileName fileSeparator:(NSString *)fileSeparator isDirectory:(BOOL)isDirectory;

+ (UIImage *)imageForFile:(HierarchicalModelWithoutManaged *)model fileSeparator:(NSString *)fileSeparator bundleDirectoryAsFile:(BOOL)bundleDirectoryAsFile;

+ (UIImage *)imageForFile:(HierarchicalModelWithoutManaged *)model fileSeparator:(NSString *)fileSeparator;

+ (NSString *)localPathFromRealServerPath:(NSString *)realServerPath fileSeparator:(NSString *)separator;

+ (NSString *)filenameFromServerFilePath:(NSString *)serverFilePath;

+ (NSString *)parentPathFromServerFilePath:(NSString *)serverFilePath separator:(NSString *)separator;

+ (NSString *)directoryNameFromServerDirectoryPath:(NSString *)serverFilePath;

// The method is used only for transfer old data and should be replaced with appGroupDirectoryPathWithUserComputerId:
// return nil if userComputerId is nil
//+ (NSString *)localFileDirectoryPathWithUserComputerId:(NSString *)userComputerId;

// root directory for application group
+ (NSString *)appGroupRootDirectory;

+ (NSString *)appGroupDirectoryPathWithCurrentUserComputerId;

// return nil if userComputerId is nil
+ (NSString *)appGroupDirectoryPathWithUserComputerId:(NSString *)userComputerId;

// Returns nil if either localPath or userComputerId is nil.
+ (NSString *)absoluteFilePathFromLocalPath:(NSString *)localPath userComputerId:(NSString *)userComputerId;

+ (void)deleteLocalCachedDataWithUserComputerId:(NSString *)userComputerId error:(NSError * __autoreleasing *)error;

+ (void)deleteLocalFileWithRealServerPath:(NSString *)realServerPath completionHandler:(void(^)(NSError *))completionHandler;

+ (NSString *)iTunesFileSharingRootPath;

//+ (NSString *)devicdSharingFolderPath;

+ (void)deleteDeviceSharingFolderIfExists;

//+ (NSString *)extractRelativePathFromFileInSharingDirectory:(NSString *)absolutePath;

+ (NSURL *)documentStorageURLForDocumentProvider;

+ (NSString *)directoryForExternalFilesWithCreatedIfNotExists:(BOOL)createdIfNotExists;

+ (void)moveFilePath:(NSString *)fromFilePath toPath:(NSString *)toFilePath replaceIfExists:(BOOL)replace error:(NSError * __autoreleasing *)error;

- (id)initWithCachePolicy:(NSURLRequestCachePolicy)policy timeInterval:(NSTimeInterval)interval;

- (void)listDirectoryChildrenWithParent:(NSString *)path session:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler;

// composed a server path or a real server path from parent path and file name.
+ (NSString *)serverPathFromParent:(NSString *)parentPath name:(NSString *)filename;

// Same as 'serverPathFromParent: name:' but specified the file separator.
+ (NSString *)serverPathFromParent:(NSString *)parentPath name:(NSString *)filename fileSeparator:(NSString *)separator;

- (void)findFileWithPath:(NSString *)path calculateSize:(BOOL)calculateSize session:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler;

- (void)renameFileWithPath:(NSString *)path newFilename:(NSString *)filename session:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler;

// Finds all uploaing files with status of wait-to-confirm and ask to server the latest status of these uploading files.
- (void)confirmUploadsWithCompletionHandler:(void (^)(void))completionHandler;

- (void)confirmUploadWithTransferKeyAndStatusDictionary:(NSDictionary *)dictionary tryAgainIfFailed:(BOOL)tryAgainIfFailed completionHandler:(void (^)(void))completionHandler;

- (void)confirmUploadWithTransferKeyAndStatusDictionary:(NSDictionary *)dictionary tryAgainIfConnectionFailed:(BOOL)tryAgainIfConnectionFailed;

- (void)confirmUploadWithTransferKeyAndStatusDictionary:(NSDictionary *)transferKeyAndStatusDictionary session:(NSString *)sessionId completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *connectionError))handler;

- (void)confirmDownloadWithFileTransfer:(FileTransferWithoutManaged *)fileTransferWithoutManaged tryAgainIfFailed:(BOOL)tryAgainIfFailed completionHandler:(void (^)(void))completionHandler;

- (void)confirmDownloadForTransferKey:(NSString *)transferKey status:(NSString *)transferStatus realReceivedBytes:(NSNumber *)realReceivedBytes session:(NSString *)sessionId completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *connectionError))handler;

// the specified dictionary contains only one transfer key and transfer status
// tmp file path will be deleted if found
- (void)updateFileUploadStatusToSuccessOrFailureWithTransferKeyAndStatusDictionary:(NSDictionary *)transferKeyAndStatusDictionary;

- (void)findDownloadHistoryWithTransferHistoryType:(NSInteger)transferHistoryType session:(NSString *)sessionId completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))handler;

- (void)findUploadHistoryWithTransferHistoryType:(NSInteger)transferHistoryType session:(NSString *)sessionId completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))handler;

- (void)createFileUploadSummaryWithUploadGroupId:(NSString *)uploadGroupId targetDirectory:(NSString *)targetDirectory transferKeys:(NSArray *)transferKeys subdirectoryType:(NSInteger)subdirectoryType subdirectoryValue:(NSString *)subdirectoryValue descriptionType:(NSInteger)descriptionType descriptionValue:(NSString *)descriptionValue notificationType:(NSInteger)notificationType session:(NSString *)sessionId completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))handler;

- (void)createFileDownloadSummaryWithDownloadGroupId:(NSString *)downloadGroupId transferKeyAndRealFilePaths:(NSDictionary *)transferKeyAndRealFilePaths notificationType:(NSInteger)notificationType session:(NSString *)sessionId completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler;

- (void)replaceFileUploadTransferKey:(NSString *)oldTransferKey withNewTransferKey:(NSString *)transferKey session:(NSString *)sessionId completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))handler;

- (void)replaceFileDownloadTransferKey:(NSString *)oldTransferKey withNewTransferKey:(NSString *)transferKey session:(NSString *)sessionId completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))handler;

// Returns the value with the type:
// Type of PHAsset -> if sourceType is ASSET_FILE_SOURCE_TYPE_PHASSET, return nil if asset not found.
// Type of FileTransferWithoutManaged with absolute file path -> if sourceType is ASSET_FILE_SOURCE_TYPE_SHARED_FILE, return nil if FileTransferWithoutManged with the specified transfer key not found.
// Type of NSString with absolute file path -> if sourceType is ASSET_FILE_SOURCE_TYPE_EXTERNAL_FILE, return nil if file not found with the file path.
+ (id)assetWithAssetFileWithoutManaged:(AssetFileWithoutManaged *)assetFileWithoutManaged;

//// Returns the value with the type:
//// Type of PHAsset -> if sourceType is ASSET_FILE_SOURCE_TYPE_PHASSET
//// Type of NSString with absolute file path -> if sourceType is ASSET_FILE_SOURCE_TYPE_SHARED_FILE or ASSET_FILE_SOURCE_TYPE_EXTERNAL_FILE
//// Return nil if asset not found or file not found with the file path
////
//// The content of assetURL is different base on sourceType:
//// ASSET_FILE_SOURCE_TYPE_SHARED_FILE   --> any_subfolder/IMG_7243.JPG (without parent path: /var/mobile/Containers/Data/Application/07522D8F-0537-4A90-90A7-75B171E9AC89/Documents)
//// ASSET_FILE_SOURCE_TYPE_PHASSET       --> 4CBE5A4F-90BD-438B-954E-6FF1B14538CD/L0/001
//// ASSET_FILE_SOURCE_TYPE_EXTERNAL_FILE --> any_external_filename.jpg (only filename)
//+ (id)assetWithAssetURL:(NSString *)assetURL sourceType:(NSNumber *)sourceType;

+ (void)updateFileTransferLocalPathToRelativePath;

+ (void)moveDownloadFileToAppGroupDirectory;

- (void)findFileSizeWithPHAsset:(PHAsset *)asset completionHandler:(void (^)(NSUInteger fileSize, NSError *error))completionHandler;

- (void)findFileUploadStatusWithTransferKey:(NSString *)transferKey session:(NSString *)sessionId completionHandler:(void (^)(FileUploadStatusModel *, NSInteger statusCode, NSError *))completionHandler;

@end
