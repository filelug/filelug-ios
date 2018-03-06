//
//  FileDownloadGroup+CoreDataProperties.h
//  filelug
//
//  Created by masonhsieh on 28/04/2017.
//
//

#import "FileDownloadGroup+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface FileDownloadGroup (CoreDataProperties)

+ (NSFetchRequest<FileDownloadGroup *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSNumber *createTimestamp;
@property (nullable, nonatomic, copy) NSString *downloadGroupId;
@property (nullable, nonatomic, copy) NSNumber *notificationType;
@property (nullable, nonatomic, retain) NSSet<FileTransfer *> *fileTransfers;
@property (nullable, nonatomic, retain) UserComputer *userComputer;

@end

@interface FileDownloadGroup (CoreDataGeneratedAccessors)

- (void)addFileTransfersObject:(FileTransfer *)value;
- (void)removeFileTransfersObject:(FileTransfer *)value;
- (void)addFileTransfers:(NSSet<FileTransfer *> *)values;
- (void)removeFileTransfers:(NSSet<FileTransfer *> *)values;

@end

NS_ASSUME_NONNULL_END
