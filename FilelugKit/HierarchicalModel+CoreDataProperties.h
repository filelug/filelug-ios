//
//  HierarchicalModel+CoreDataProperties.h
//  filelug
//
//  Created by masonhsieh on 28/04/2017.
//
//

#import "HierarchicalModel+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface HierarchicalModel (CoreDataProperties)

+ (NSFetchRequest<HierarchicalModel *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *actionsAfterDownload;
@property (nullable, nonatomic, copy) NSString *contentType;
@property (nullable, nonatomic, copy) NSString *displaySize;
@property (nullable, nonatomic, copy) NSNumber *endTimestamp;
@property (nullable, nonatomic, copy) NSNumber *executable;
@property (nullable, nonatomic, copy) NSNumber *hidden;
@property (nullable, nonatomic, copy) NSString *lastModified;
@property (nullable, nonatomic, copy) NSString *name;
@property (nullable, nonatomic, copy) NSString *parent;
@property (nullable, nonatomic, copy) NSNumber *readable;
@property (nullable, nonatomic, copy) NSString *realName;
@property (nullable, nonatomic, copy) NSString *realParent;
@property (nullable, nonatomic, copy) NSString *realServerPath;
@property (nullable, nonatomic, copy) NSString *sectionName;
@property (nullable, nonatomic, copy) NSNumber *sizeInBytes;
@property (nullable, nonatomic, copy) NSNumber *startTimestamp;
@property (nullable, nonatomic, copy) NSString *status;
@property (nullable, nonatomic, copy) NSNumber *symlink;
@property (nullable, nonatomic, copy) NSNumber *totalSize;
@property (nullable, nonatomic, copy) NSString *transferKey;
@property (nullable, nonatomic, copy) NSNumber *transferredSize;
@property (nullable, nonatomic, copy) NSString *type;
@property (nullable, nonatomic, copy) NSNumber *waitToConfirm;
@property (nullable, nonatomic, copy) NSNumber *writable;
@property (nullable, nonatomic, retain) UserComputer *userComputer;

@end

NS_ASSUME_NONNULL_END
