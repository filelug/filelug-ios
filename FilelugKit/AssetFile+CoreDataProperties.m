//
//  AssetFile+CoreDataProperties.m
//  filelug
//
//  Created by masonhsieh on 05/06/2017.
//
//

#import "AssetFile+CoreDataProperties.h"

@implementation AssetFile (CoreDataProperties)

+ (NSFetchRequest<AssetFile *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"AssetFile"];
}

@dynamic assetURL;
@dynamic endTimestamp;
@dynamic resumeData;
@dynamic serverDirectory;
@dynamic serverFilename;
@dynamic sourceType;
@dynamic startTimestamp;
@dynamic status;
@dynamic thumbnail;
@dynamic totalSize;
@dynamic transferKey;
@dynamic transferredSize;
@dynamic transferredSizeBeforeResume;
@dynamic waitToConfirm;
@dynamic downloadedFileTransferKey;
@dynamic fileUploadGroup;
@dynamic userComputer;

@end
