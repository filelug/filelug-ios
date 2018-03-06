//
//  UserComputer+CoreDataProperties.h
//  filelug
//
//  Created by masonhsieh on 28/04/2017.
//
//

#import "UserComputer+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface UserComputer (CoreDataProperties)

+ (NSFetchRequest<UserComputer *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *computerAdminId;
@property (nullable, nonatomic, copy) NSString *computerGroup;
@property (nullable, nonatomic, copy) NSNumber *computerId;
@property (nullable, nonatomic, copy) NSString *computerName;
@property (nullable, nonatomic, copy) NSNumber *downloadDescriptionType;
@property (nullable, nonatomic, copy) NSString *downloadDescriptionValue;
@property (nullable, nonatomic, copy) NSString *downloadDirectory;
@property (nullable, nonatomic, copy) NSNumber *downloadNotificationType;
@property (nullable, nonatomic, copy) NSNumber *downloadSubdirectoryType;
@property (nullable, nonatomic, copy) NSString *downloadSubdirectoryValue;
@property (nullable, nonatomic, copy) NSNumber *showHidden;
@property (nullable, nonatomic, copy) NSNumber *uploadDescriptionType;
@property (nullable, nonatomic, copy) NSString *uploadDescriptionValue;
@property (nullable, nonatomic, copy) NSString *uploadDirectory;
@property (nullable, nonatomic, copy) NSNumber *uploadNotificationType;
@property (nullable, nonatomic, copy) NSNumber *uploadSubdirectoryType;
@property (nullable, nonatomic, copy) NSString *uploadSubdirectoryValue;
@property (nullable, nonatomic, copy) NSString *userComputerId;
@property (nullable, nonatomic, retain) NSSet<AssetFile *> *assetFiles;
@property (nullable, nonatomic, retain) NSSet<FileDownloadGroup *> *fileDownloadGroups;
@property (nullable, nonatomic, retain) NSSet<FileTransfer *> *fileTransfers;
@property (nullable, nonatomic, retain) NSSet<FileUploadGroup *> *fileUploadGroups;
@property (nullable, nonatomic, retain) NSSet<HierarchicalModel *> *hierarchicalModels;
@property (nullable, nonatomic, retain) User *user;

@end

@interface UserComputer (CoreDataGeneratedAccessors)

- (void)addAssetFilesObject:(AssetFile *)value;
- (void)removeAssetFilesObject:(AssetFile *)value;
- (void)addAssetFiles:(NSSet<AssetFile *> *)values;
- (void)removeAssetFiles:(NSSet<AssetFile *> *)values;

- (void)addFileDownloadGroupsObject:(FileDownloadGroup *)value;
- (void)removeFileDownloadGroupsObject:(FileDownloadGroup *)value;
- (void)addFileDownloadGroups:(NSSet<FileDownloadGroup *> *)values;
- (void)removeFileDownloadGroups:(NSSet<FileDownloadGroup *> *)values;

- (void)addFileTransfersObject:(FileTransfer *)value;
- (void)removeFileTransfersObject:(FileTransfer *)value;
- (void)addFileTransfers:(NSSet<FileTransfer *> *)values;
- (void)removeFileTransfers:(NSSet<FileTransfer *> *)values;

- (void)addFileUploadGroupsObject:(FileUploadGroup *)value;
- (void)removeFileUploadGroupsObject:(FileUploadGroup *)value;
- (void)addFileUploadGroups:(NSSet<FileUploadGroup *> *)values;
- (void)removeFileUploadGroups:(NSSet<FileUploadGroup *> *)values;

- (void)addHierarchicalModelsObject:(HierarchicalModel *)value;
- (void)removeHierarchicalModelsObject:(HierarchicalModel *)value;
- (void)addHierarchicalModels:(NSSet<HierarchicalModel *> *)values;
- (void)removeHierarchicalModels:(NSSet<HierarchicalModel *> *)values;

@end

NS_ASSUME_NONNULL_END
