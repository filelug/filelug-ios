#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Utility;

@interface ClopuccinoCoreData : NSObject

@property(nonatomic, assign) BOOL sendsUpdates;

@property(nonatomic, assign) BOOL receivesUpdates;

+ (ClopuccinoCoreData *)defaultCoreData;

- (NSManagedObjectContext *)managedObjectContextFromThread:(NSThread *)thread;

- (void)saveContext:(NSManagedObjectContext *)context;

- (void)saveContext:(NSManagedObjectContext *)context completionHandler:(void (^)(void))completionHandler;

- (void)rollbackContext:(NSManagedObjectContext *)moc;

// check if the table with the specified table name exists
- (BOOL)containsEntityWithEntityName:(NSString *)entityName;

// truncate table with specified table name
- (void)truncateEntityWithEntityName:(NSString *)entityName error:(NSError * __autoreleasing *)error;

@end
