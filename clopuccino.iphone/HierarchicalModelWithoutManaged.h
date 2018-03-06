#import <Foundation/Foundation.h>


@interface HierarchicalModelWithoutManaged : NSObject <NSCopying>

@property(nonatomic, strong) NSString *userComputerId;
@property(nonatomic, strong) NSNumber *symlink;
@property(nonatomic, strong) NSString *name;
@property(nonatomic, strong) NSString *parent;
@property(nonatomic, strong) NSString *realName;
@property(nonatomic, strong) NSString *realParent;
@property(nonatomic, strong) NSNumber *readable;
@property(nonatomic, strong) NSNumber *writable;
@property(nonatomic, strong) NSNumber *executable;
@property(nonatomic, strong) NSString *displaySize;
@property(nonatomic, strong) NSNumber *sizeInBytes;
@property(nonatomic, strong) NSNumber *hidden;
@property(nonatomic, strong) NSString *lastModified;
@property(nonatomic, strong) NSString *type;
@property(nonatomic, strong) NSString *sectionName;
@property(nonatomic, strong) NSString *contentType;

// related to file download
@property(nonatomic, strong) NSString *realServerPath;
@property(nonatomic, strong) NSString *status;
@property(nonatomic, strong) NSNumber *totalSize;
@property(nonatomic, strong) NSNumber *transferredSize;
@property(nonatomic, strong) NSNumber *startTimestamp;
@property(nonatomic, strong) NSNumber *endTimestamp;
@property(nonatomic, strong) NSString *actionsAfterDownload;
@property(nonatomic, strong) NSString *transferKey;
@property(nonatomic, strong) NSNumber *waitToConfirm;

+ (NSDictionary *)bundleDirectorySuffixAndMimetypes;

+ (NSString *)bundleDirectoryMimetypeWithSuffix:(NSString *)suffix;

+ (NSString *)rename:(NSString *)originalName forShortcutType:(NSString *)type;

+ (BOOL)isTypeOfDirectory:(NSString *)type;

+ (BOOL)isTypeOfShortcutOrLink:(NSString *)type;

// Init with download information
- (id)initWithUserComputerId:(NSString *)userComputerId
                        name:(NSString *)name
                      parent:(NSString *)parent
                    realName:(NSString *)realName
                  realParent:(NSString *)realParent
                 contentType:(NSString *)contentType
                      hidden:(NSNumber *)hidden
                     symlink:(NSNumber *)symlink
                        type:(NSString *)type
                 sectionName:(NSString *)sectionName
                 displaySize:(NSString *)displaySize
                 sizeInBytes:(NSNumber *)sizeInBytes
                    readable:(NSNumber *)readable
                    writable:(NSNumber *)writable
                  executable:(NSNumber *)executable
                lastModified:(NSString *)lastModified
              realServerPath:(NSString *)realServerPath
                      status:(NSString *)status
                   totalSize:(NSNumber *)totalSize
             transferredSize:(NSNumber *)transferredSize
              startTimestamp:(NSNumber *)startTimestamp
                endTimestamp:(NSNumber *)endTimestamp
        actionsAfterDownload:(NSString *)actionsAfterDownload
                 transferKey:(NSString *)transferKey
               waitToConfirm:(NSNumber *)waitToConfirm;

// Init without download information
- (id)initWithUserComputerId:(NSString *)userComputerId
                        name:(NSString *)name
                      parent:(NSString *)parent
                    realName:(NSString *)realName
                  realParent:(NSString *)realParent
                 contentType:(NSString *)contentType
                      hidden:(NSNumber *)hidden
                     symlink:(NSNumber *)symlink
                        type:(NSString *)type
                 sectionName:(NSString *)sectionName
                 displaySize:(NSString *)displaySize
                 sizeInBytes:(NSNumber *)sizeInBytes
                    readable:(NSNumber *)readable
                    writable:(NSNumber *)writable
                  executable:(NSNumber *)executable
                lastModified:(NSString *)lastModified;

+ (BOOL)isBundleDirectoryWithRealFilename:(NSString *)realFilename;

+ (BOOL)isDirectoryWithType:(NSString *)type;

- (id)initWithUserComputerId:(NSString *)userComputerId name:(NSString *)name parent:(NSString *)parent realName:(NSString *)realName realParent:(NSString *)realParent contentType:(NSString *)contentType hidden:(NSNumber *)hidden symlink:(NSNumber *)symlink type:(NSString *)type displaySize:(NSString *)displaySize readable:(NSNumber *)readable writable:(NSNumber *)writable executable:(NSNumber *)executable lastModified:(NSString *)lastModified;

- (BOOL)isBundleDirectory;

- (BOOL)isDirectory;

- (BOOL)isShortcutOrLink;

- (NSString *)description;

@end