@interface UploadItem : NSObject

@property(nonatomic, strong, nullable) NSURL *url;

@property(nonatomic, strong, nullable) NSData *data;

@property(nonatomic, strong, nonnull) NSString *utcoreType;

@property(nonatomic, strong, nullable) NSString *fileExtension;

@property(nonatomic, strong, nullable) NSString *mimeType;

- (NSString *_Nonnull)description;

@end
