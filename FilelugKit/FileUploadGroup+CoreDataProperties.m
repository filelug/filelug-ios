//
//  FileUploadGroup+CoreDataProperties.m
//  filelug
//
//  Created by masonhsieh on 28/04/2017.
//
//

#import "FileUploadGroup+CoreDataProperties.h"

@implementation FileUploadGroup (CoreDataProperties)

+ (NSFetchRequest<FileUploadGroup *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"FileUploadGroup"];
}

@dynamic createdInDesktopStatus;
@dynamic createdInDesktopTimestamp;
@dynamic createTimestamp;
@dynamic descriptionType;
@dynamic descriptionValue;
@dynamic notificationType;
@dynamic subdirectoryName;
@dynamic subdirectoryType;
@dynamic uploadGroupDirectory;
@dynamic uploadGroupId;
@dynamic assetFiles;
@dynamic userComputer;

@end
