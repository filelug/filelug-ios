//
//  AssetFile+CoreDataProperties.h
//  filelug
//
//  Created by masonhsieh on 05/06/2017.
//
//

#import "AssetFile+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface AssetFile (CoreDataProperties)

+ (NSFetchRequest<AssetFile *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *assetURL;
@property (nullable, nonatomic, copy) NSNumber *endTimestamp;
@property (nullable, nonatomic, retain) NSData *resumeData;
@property (nullable, nonatomic, copy) NSString *serverDirectory;
@property (nullable, nonatomic, copy) NSString *serverFilename;
@property (nullable, nonatomic, copy) NSNumber *sourceType;
@property (nullable, nonatomic, copy) NSNumber *startTimestamp;
@property (nullable, nonatomic, copy) NSString *status;
@property (nullable, nonatomic, retain) NSData *thumbnail;
@property (nullable, nonatomic, copy) NSNumber *totalSize;
@property (nullable, nonatomic, copy) NSString *transferKey;
@property (nullable, nonatomic, copy) NSNumber *transferredSize;
@property (nullable, nonatomic, copy) NSNumber *transferredSizeBeforeResume;
@property (nullable, nonatomic, copy) NSNumber *waitToConfirm;
@property (nullable, nonatomic, copy) NSString *downloadedFileTransferKey;
@property (nullable, nonatomic, retain) FileUploadGroup *fileUploadGroup;
@property (nullable, nonatomic, retain) UserComputer *userComputer;

@end

NS_ASSUME_NONNULL_END
