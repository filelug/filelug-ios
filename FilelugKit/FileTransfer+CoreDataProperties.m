//
//  FileTransfer+CoreDataProperties.m
//  filelug
//
//  Created by masonhsieh on 28/04/2017.
//
//

#import "FileTransfer+CoreDataProperties.h"

@implementation FileTransfer (CoreDataProperties)

+ (NSFetchRequest<FileTransfer *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"FileTransfer"];
}

@dynamic actionsAfterDownload;
@dynamic contentType;
@dynamic displaySize;
@dynamic endTimestamp;
@dynamic hidden;
@dynamic lastModified;
@dynamic localPath;
@dynamic notification_type;
@dynamic realServerPath;
@dynamic resumeData;
@dynamic serverPath;
@dynamic startTimestamp;
@dynamic status;
@dynamic totalSize;
@dynamic transferKey;
@dynamic transferredSize;
@dynamic type;
@dynamic waitToConfirm;
@dynamic fileDownloadGroup;
@dynamic userComputer;

@end
