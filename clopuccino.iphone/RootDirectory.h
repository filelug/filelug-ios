#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@class UserComputer;


@interface RootDirectory : NSManagedObject

@property (nonatomic, retain) NSNumber * directoryId;
@property (nonatomic, retain) NSString * directoryLabel;
@property (nonatomic, retain) NSString * directoryPath;
@property (nonatomic, retain) NSString * directoryRealPath;
@property (nonatomic, retain) NSString * type;
@property (nonatomic, retain) UserComputer *userComputer;

@end
