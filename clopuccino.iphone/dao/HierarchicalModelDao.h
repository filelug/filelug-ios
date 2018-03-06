#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@class HierarchicalModelWithoutManaged;
@class HierarchicalModel;
@class NSFetchedResultsController;


@interface HierarchicalModelDao : NSObject

- (void)createHierarchicalModelFromHierarchicalModelWithoutManaged:(HierarchicalModelWithoutManaged *)hierarchicalModelWithoutManaged;

// The completionHandler block will be run under [moc performBlockAndWait:]
- (void)enumerateHierarchicalModelWithCompletionHandler:(void (^)(HierarchicalModel *))completionHandler saveContextAfterFinishedAllCompletionHandler:(BOOL)saveContextAfterFinishedAllCompletionHandler;

// find by user and parent, sort by name asc, return elements of HierarchicalModelWithoutManaged
- (NSArray *)findAllHierarchicalModelsForUserComputer:(NSString *)userComputerId parent:(NSString *)parent error:(NSError * __autoreleasing *)error;

// find by user and real file path
- (HierarchicalModelWithoutManaged *)findHierarchicalModelForUserComputer:(NSString *)userComputerId realServerPath:(NSString *)realServerPath fileSeparator:fileSeparator error:(NSError * __autoreleasing *)error;

// find by user, parent and name
- (HierarchicalModelWithoutManaged *)findHierarchicalModelForUserComputer:(NSString *)userComputerId parent:(NSString *)parent name:(NSString *)name error:(NSError * __autoreleasing *)error;

- (void)updateHierarchicalModel:(HierarchicalModelWithoutManaged *)hierarchicalModelWithoutManaged completionHandler:(void (^)(NSError *error))completionHandler;

// Delete the models with the parent. If hierarchically set to YES, all hierarchical sub-directories and files from this parent will be deleted as well.
- (void)deleteHierarchicalModelForUserComputer:(NSString *)userComputerId parent:(NSString *)parent hierarchically:(BOOL)hierarchically;

// parsing json data with hierarchical models and synchronize it with local db data
- (void)parseJsonAndSyncWithCurrentHierarchicalModels:(NSData *)data userComputer:(NSString *)userComputerId parentPath:(NSString *)parentPath completionHandler:(void (^)(void))completionHandler;

- (NSFetchedResultsController *)createHierarchicalModelsFetchedResultsControllerForUserComputer:(NSString *)userComputerId parent:(NSString *)parent directoryOnly:(BOOL)directoryOnly delegate:(id <NSFetchedResultsControllerDelegate>)delegate;

- (BOOL)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController performFetch:(NSError * __autoreleasing *)error;

- (HierarchicalModelWithoutManaged *)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController objectAtIndexPath:(NSIndexPath *)indexPath;

- (BOOL)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController isDirectoryAtIndexPath:(NSIndexPath *)indexPath;

- (NSInteger)numberOfSectionsForFetchedResultsController:(NSFetchedResultsController *)fetchedResultsController;

- (NSInteger)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController numberOfRowsInSection:(NSInteger)section;

- (NSString *)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController sectionName:(NSInteger)section;

- (NSArray *)sectionIndexTitlesForFetchedResultsController:(NSFetchedResultsController *)fetchedResultsController;

- (NSInteger)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index;

#pragma mark - Manage download-related information

- (void)removeDownloadInformationInHierarchicalModelsWithTransferKey:(NSString *)transferKey completionHandler:(void (^)(void))completionHandler;
//- (void)removeDownloadInformationInHierarchicalModelsWithTransferKey:(NSString *)transferKey;

// If findHierarchicalModelsByRealServerPath == YES, find the HierarchicalModel objects by fileTransferWithoutManaged.realServerPath (and fileTransferWithoutManaged.userComputerId) and fileSeparator can be nil.
// If findHierarchicalModelsByRealServerPath == NO, find the HierarchicalModel objects by realParent and realName (and fileTransferWithoutManaged.userComputerId) and fileSeparator cannot be nil.
// ps. realParent and realName can be found from fileTransferWithoutManaged.realServerPath and fileSeparator
- (void)updateDownloadInformationToHierarchicalModelsFromFileTransferWithoutManaged:(FileTransferWithoutManaged *)fileTransferWithoutManaged findHierarchicalModelsByRealServerPath:(BOOL)findHierarchicalModelsByRealServerPath fileSeparator:(NSString *)fileSeparator;

- (HierarchicalModelWithoutManaged *)findHierarchicalModelForTransferKey:(NSString *)transferKey error:(NSError * __autoreleasing *)error;
@end
