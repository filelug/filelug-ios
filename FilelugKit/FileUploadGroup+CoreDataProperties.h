//
//  FileUploadGroup+CoreDataProperties.h
//  filelug
//
//  Created by masonhsieh on 28/04/2017.
//
//

#import "FileUploadGroup+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface FileUploadGroup (CoreDataProperties)

+ (NSFetchRequest<FileUploadGroup *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *createdInDesktopStatus;
@property (nullable, nonatomic, copy) NSNumber *createdInDesktopTimestamp;
@property (nullable, nonatomic, copy) NSNumber *createTimestamp;
@property (nullable, nonatomic, copy) NSNumber *descriptionType;
@property (nullable, nonatomic, copy) NSString *descriptionValue;
@property (nullable, nonatomic, copy) NSNumber *notificationType;
@property (nullable, nonatomic, copy) NSString *subdirectoryName;
@property (nullable, nonatomic, copy) NSNumber *subdirectoryType;
@property (nullable, nonatomic, copy) NSString *uploadGroupDirectory;
@property (nullable, nonatomic, copy) NSString *uploadGroupId;
@property (nullable, nonatomic, retain) NSSet<AssetFile *> *assetFiles;
@property (nullable, nonatomic, retain) UserComputer *userComputer;

@end

@interface FileUploadGroup (CoreDataGeneratedAccessors)

- (void)addAssetFilesObject:(AssetFile *)value;
- (void)removeAssetFilesObject:(AssetFile *)value;
- (void)addAssetFiles:(NSSet<AssetFile *> *)values;
- (void)removeAssetFiles:(NSSet<AssetFile *> *)values;

@end

NS_ASSUME_NONNULL_END
