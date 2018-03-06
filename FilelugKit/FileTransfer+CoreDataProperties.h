//
//  FileTransfer+CoreDataProperties.h
//  filelug
//
//  Created by masonhsieh on 28/04/2017.
//
//

#import "FileTransfer+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface FileTransfer (CoreDataProperties)

+ (NSFetchRequest<FileTransfer *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *actionsAfterDownload;
@property (nullable, nonatomic, copy) NSString *contentType;
@property (nullable, nonatomic, copy) NSString *displaySize;
@property (nullable, nonatomic, copy) NSNumber *endTimestamp;
@property (nullable, nonatomic, copy) NSNumber *hidden;
@property (nullable, nonatomic, copy) NSString *lastModified;
@property (nullable, nonatomic, copy) NSString *localPath;
@property (nullable, nonatomic, copy) NSNumber *notification_type;
@property (nullable, nonatomic, copy) NSString *realServerPath;
@property (nullable, nonatomic, retain) NSData *resumeData;
@property (nullable, nonatomic, copy) NSString *serverPath;
@property (nullable, nonatomic, copy) NSNumber *startTimestamp;
@property (nullable, nonatomic, copy) NSString *status;
@property (nullable, nonatomic, copy) NSNumber *totalSize;
@property (nullable, nonatomic, copy) NSString *transferKey;
@property (nullable, nonatomic, copy) NSNumber *transferredSize;
@property (nullable, nonatomic, copy) NSString *type;
@property (nullable, nonatomic, copy) NSNumber *waitToConfirm;
@property (nullable, nonatomic, retain) FileDownloadGroup *fileDownloadGroup;
@property (nullable, nonatomic, retain) UserComputer *userComputer;

@end

NS_ASSUME_NONNULL_END
