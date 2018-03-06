#import <Foundation/Foundation.h>

@class FileUploadGroup;

NS_ASSUME_NONNULL_BEGIN

@interface FileUploadGroupDao : NSObject

- (void)createFileUploadGroupWithUploadGroupId:(NSString *)uploadGroupId targetDirectory:(NSString *)targetDirectory subdirectoryType:(NSInteger)subdirectoryType subdirectoryValue:(NSString *)subdirectoryValue descriptionType:(NSInteger)descriptionType descriptionValue:(NSString *)descriptionValue notificationType:(NSInteger)notificationType userComputerId:(NSString *)userComputerId completionHandler:(void (^ _Nullable)(void))completionHandler;

- (nullable FileUploadGroup *)findFileUploadGroupByUploadGroupId:(NSString *)uploadGroupId managedObjectContext:(NSManagedObjectContext *)managedObjectContext;

- (void)findFileUploadGroupByUploadGroupId:(NSString *)uploadGroupId completionHandler:(void (^)(FileUploadGroup *))completionHandler;

//- (void)updateEmptySectionNameToTableFileUploadGroup;
//
//- (void)createFileUploadGroupForUncategoryAssetFiles;
@end

NS_ASSUME_NONNULL_END
