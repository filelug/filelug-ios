//
//  RecentDirectory+CoreDataProperties.h
//  filelug
//
//  Created by masonhsieh on 13/08/2017.
//
//

#import "RecentDirectory+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface RecentDirectory (CoreDataProperties)

+ (NSFetchRequest<RecentDirectory *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *directoryPath;
@property (nullable, nonatomic, copy) NSString *directoryRealPath;
@property (nullable, nonatomic, copy) NSNumber *createdTimestamp;
@property (nullable, nonatomic, retain) UserComputer *userComputer;

@end

NS_ASSUME_NONNULL_END
