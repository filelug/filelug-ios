#import "HierarchicalModelWithoutManaged.h"


@implementation HierarchicalModelWithoutManaged

+ (NSDictionary *)bundleDirectorySuffixAndMimetypes {
    static NSDictionary *suffixAndMimetypes;

    if (!suffixAndMimetypes) {
        suffixAndMimetypes = @{
                @".pages" : @"application/x-iwork-pages-sffpages",
                @".numbers" : @"application/x-iwork-numbers-sffnumbers",
                @".key" : @"application/x-iwork-keynote-sffkey",
                @".graffle" : @"application/octet-stream"
        };
    }

    return suffixAndMimetypes;
}

+ (NSString *)bundleDirectoryMimetypeWithSuffix:(NSString *)suffix {
    NSDictionary *bundleDirectorySuffixAndMimetypes = [self bundleDirectorySuffixAndMimetypes];

    if (suffix) {
        return bundleDirectorySuffixAndMimetypes[suffix];
    } else {
        return nil;
    }
}

+ (NSString *)rename:(NSString *)originalName forShortcutType:(NSString *)type {
    return ([type isEqualToString:HIERARCHICAL_MODEL_TYPE_WINDOWS_SHORTCUT_DIRECTORY] || [type isEqualToString:HIERARCHICAL_MODEL_TYPE_WINDOWS_SHORTCUT_FILE]) && [originalName hasSuffix:@".lnk"] ? [originalName stringByDeletingPathExtension] : originalName;
}


+ (BOOL)isTypeOfDirectory:(NSString *)type {
    return [type hasSuffix:HIERARCHICAL_MODEL_TYPE_SUFFIX_DIRECTORY];
}

+ (BOOL)isTypeOfShortcutOrLink:(NSString *)type {
    return ([type rangeOfString:HIERARCHICAL_MODEL_TYPE_CONTAIN_LINK].location != NSNotFound) || ([type rangeOfString:HIERARCHICAL_MODEL_TYPE_CONTAIN_SHORTCUT].location != NSNotFound) || ([type rangeOfString:HIERARCHICAL_MODEL_TYPE_CONTAIN_ALIAS].location != NSNotFound);
}

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
               waitToConfirm:(NSNumber *)waitToConfirm {
    if (self = [super init]) {
        _userComputerId = userComputerId;
        _name = name;
        _parent = parent;
        _realName = realName;
        _realParent = realParent;
        _contentType = contentType;
        _hidden = hidden;
        _symlink = symlink;
        _type = type;
        _sectionName = sectionName;
        _displaySize = displaySize;
        _sizeInBytes = sizeInBytes;
        _readable = readable;
        _writable = writable;
        _executable = executable;
        _lastModified = lastModified;

        // download information
        _realServerPath = realServerPath;
        _status = status;
        _totalSize = totalSize;
        _transferredSize = transferredSize;
        _startTimestamp = startTimestamp;
        _endTimestamp = endTimestamp;
        _actionsAfterDownload = actionsAfterDownload;
        _transferKey = transferKey;
        _waitToConfirm = waitToConfirm;
    }

    return self;
}

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
                lastModified:(NSString *)lastModified {
    return [self initWithUserComputerId:userComputerId
                                   name:name
                                 parent:parent
                               realName:realName
                             realParent:realParent
                            contentType:contentType
                                 hidden:hidden
                                symlink:symlink
                                   type:type
                            sectionName:sectionName
                            displaySize:displaySize
                            sizeInBytes:sizeInBytes
                               readable:readable
                               writable:writable
                             executable:executable
                           lastModified:lastModified
                         realServerPath:nil
                                 status:nil
                              totalSize:nil
                        transferredSize:nil
                         startTimestamp:nil
                           endTimestamp:nil
                   actionsAfterDownload:nil
                            transferKey:nil
                          waitToConfirm:nil];
}

+ (BOOL)isBundleDirectoryWithRealFilename:(NSString *)realFilename {
    BOOL passed = NO;

    if (realFilename) {
        NSString *realFilenameWithLowercase = [realFilename lowercaseString];

        NSArray *bundleDirectorySuffixWiths = [[self bundleDirectorySuffixAndMimetypes] allKeys];

        for (NSString *bundleDirectorySuffixWith in bundleDirectorySuffixWiths) {
            if ([realFilenameWithLowercase hasSuffix:bundleDirectorySuffixWith]) {
                passed = YES;

                break;
            }
        }
    }

    return passed;
}

- (id)initWithUserComputerId:(NSString *)userComputerId name:(NSString *)name parent:(NSString *)parent realName:(NSString *)realName realParent:(NSString *)realParent contentType:(NSString *)contentType hidden:(NSNumber *)hidden symlink:(NSNumber *)symlink type:(NSString *)type displaySize:(NSString *)displaySize readable:(NSNumber *)readable writable:(NSNumber *)writable executable:(NSNumber *)executable lastModified:(NSString *)lastModified {
    if (self = [super init]) {
        _userComputerId = userComputerId;
        _name = name;
        _parent = parent;
        _realName = realName;
        _realParent = realParent;
        _contentType = contentType;
        _hidden = hidden;
        _symlink = symlink;
        _type = type;
        _displaySize = displaySize;
        _readable = readable;
        _writable = writable;
        _executable = executable;
        _lastModified = lastModified;
    }

    return self;
}

- (NSString *)description {
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];
    [description appendFormat:@"self.contentType=%@", self.contentType];
    [description appendFormat:@", self.userComputerId=%@", self.userComputerId];
    [description appendFormat:@", self.symlink=%@", self.symlink];
    [description appendFormat:@", self.name=%@", self.name];
    [description appendFormat:@", self.parent=%@", self.parent];
    [description appendFormat:@", self.realName=%@", self.realName];
    [description appendFormat:@", self.realParent=%@", self.realParent];
    [description appendFormat:@", self.readable=%@", self.readable];
    [description appendFormat:@", self.writable=%@", self.writable];
    [description appendFormat:@", self.executable=%@", self.executable];
    [description appendFormat:@", self.displaySize=%@", self.displaySize];
    [description appendFormat:@", self.sizeInBytes=%@", self.sizeInBytes];
    [description appendFormat:@", self.hidden=%@", self.hidden];
    [description appendFormat:@", self.lastModified=%@", self.lastModified];
    [description appendFormat:@", self.type=%@", self.type];
    [description appendString:@">"];
    return description;
}

- (BOOL)isBundleDirectory {
    return [self.type isEqualToString:HIERARCHICAL_MODEL_TYPE_BUNDLE_DIRECTORY_FILE];
}

+ (BOOL)isDirectoryWithType:(NSString *)type {
    return type && [type hasSuffix:HIERARCHICAL_MODEL_TYPE_SUFFIX_DIRECTORY];
}

- (BOOL)isDirectory {
    return [HierarchicalModelWithoutManaged isDirectoryWithType:self.type];
//    return [self.type hasSuffix:HIERARCHICAL_MODEL_TYPE_SUFFIX_DIRECTORY];
}

- (BOOL)isShortcutOrLink {
    return ([self.type rangeOfString:HIERARCHICAL_MODEL_TYPE_CONTAIN_LINK].location != NSNotFound) || ([self.type rangeOfString:HIERARCHICAL_MODEL_TYPE_CONTAIN_SHORTCUT].location != NSNotFound) || ([self.type rangeOfString:HIERARCHICAL_MODEL_TYPE_CONTAIN_ALIAS].location != NSNotFound);
}

#pragma mark -- NSCopying

- (id)copyWithZone:(NSZone *)zone {
    HierarchicalModelWithoutManaged *newModel = [HierarchicalModelWithoutManaged allocWithZone:zone];

    [newModel setUserComputerId:self.userComputerId];
    [newModel setName:self.name];
    [newModel setParent:self.parent];
    [newModel setRealName:self.realName];
    [newModel setRealParent:self.realParent];
    [newModel setContentType:self.contentType];
    [newModel setHidden:self.hidden];
    [newModel setSymlink:self.symlink];
    [newModel setType:self.type];
    [newModel setDisplaySize:self.displaySize];
    [newModel setSizeInBytes:self.sizeInBytes];
    [newModel setReadable:self.readable];
    [newModel setWritable:self.writable];
    [newModel setExecutable:self.executable];
    [newModel setLastModified:self.lastModified];

    return newModel;
}


@end