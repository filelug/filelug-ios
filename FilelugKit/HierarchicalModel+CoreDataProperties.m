//
//  HierarchicalModel+CoreDataProperties.m
//  filelug
//
//  Created by masonhsieh on 28/04/2017.
//
//

#import "HierarchicalModel+CoreDataProperties.h"

@implementation HierarchicalModel (CoreDataProperties)

+ (NSFetchRequest<HierarchicalModel *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"HierarchicalModel"];
}

@dynamic actionsAfterDownload;
@dynamic contentType;
@dynamic displaySize;
@dynamic endTimestamp;
@dynamic executable;
@dynamic hidden;
@dynamic lastModified;
@dynamic name;
@dynamic parent;
@dynamic readable;
@dynamic realName;
@dynamic realParent;
@dynamic realServerPath;
@dynamic sectionName;
@dynamic sizeInBytes;
@dynamic startTimestamp;
@dynamic status;
@dynamic symlink;
@dynamic totalSize;
@dynamic transferKey;
@dynamic transferredSize;
@dynamic type;
@dynamic waitToConfirm;
@dynamic writable;
@dynamic userComputer;

@end
