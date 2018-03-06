@interface FileUploadStatusModel : NSObject

@property(nonatomic, strong) NSString *transferKey;

@property(nonatomic, strong) NSNumber *transferredSize;

@property(nonatomic, strong) NSNumber *fileSize;

@property(nonatomic, strong) NSNumber *fileLastModifiedDate;

- (instancetype)initWithTransferKey:(NSString *)transferKey transferredSize:(NSNumber *)transferredSize fileSize:(NSNumber *)fileSize fileLastModifiedDate:(NSNumber *)fileLastModifiedDate;

@end
