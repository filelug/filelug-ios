//
//  RecentDirectory+CoreDataProperties.m
//  filelug
//
//  Created by masonhsieh on 13/08/2017.
//
//

#import "RecentDirectory+CoreDataProperties.h"

@implementation RecentDirectory (CoreDataProperties)

+ (NSFetchRequest<RecentDirectory *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"RecentDirectory"];
}

@dynamic directoryPath;
@dynamic directoryRealPath;
@dynamic createdTimestamp;
@dynamic userComputer;

@end
