//
//  FileDownloadGroup+CoreDataProperties.m
//  filelug
//
//  Created by masonhsieh on 28/04/2017.
//
//

#import "FileDownloadGroup+CoreDataProperties.h"

@implementation FileDownloadGroup (CoreDataProperties)

+ (NSFetchRequest<FileDownloadGroup *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"FileDownloadGroup"];
}

@dynamic createTimestamp;
@dynamic downloadGroupId;
@dynamic notificationType;
@dynamic fileTransfers;
@dynamic userComputer;

@end
