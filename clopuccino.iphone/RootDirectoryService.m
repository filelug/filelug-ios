#import "RootDirectoryService.h"
#import "Utility.h"
#import "RootDirectoryModel.h"
#import "RootDirectory.h"

@implementation RootDirectoryService {
}

- (id)initWithCachePolicy:(NSURLRequestCachePolicy)policy timeInterval:(NSTimeInterval)interval {
    if (self = [super init]) {
        _cachePolicy = policy;
        _timeInterval = interval;
    }

    return self;
}

- (void)findRootsAndHomeDirectoryWithSession:(NSString *)sessionId showHidden:(BOOL)showHidden completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    NSString *urlString = [Utility composeLugServerURLStringWithPath:@"directory/roots"];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[Utility URLWithString:urlString excludedFromBackup:YES] cachePolicy:_cachePolicy timeoutInterval:_timeInterval];

    [request setHTTPMethod:@"POST"];

    NSString *bodyString = [NSString stringWithFormat:@"{\"showHidden\" : %@}", showHidden ? @"true" : @"false"];

    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];

    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    [request setValue:sessionId forHTTPHeaderField:HTTP_HEADER_NAME_AUTHORIZATION];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:handler] resume];
}

+ (NSMutableArray *)parseJsonAsRootDirectoryModelArray:(NSData *)data error:(NSError * __autoreleasing *)error {
    NSError *jsonError = nil;
    NSArray *jsonArray = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];

    if (jsonError) {
        if (error) {
            *error = jsonError;
        } else {
            NSLog(@"Failed to parse root directory data.\n%@", [jsonError userInfo]);
        }

        return nil;
    } else {
        NSMutableArray *directories = [[NSMutableArray alloc] init];

        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        for (NSDictionary *jsonObject in jsonArray) {
            NSString *path = jsonObject[@"path"];
            NSString *realPath = jsonObject[@"realPath"];
            NSString *label = jsonObject[@"label"];
            NSString *type = jsonObject[@"type"];

            RootDirectoryModel *rootDirectoryModel = [[RootDirectoryModel alloc] initWithLabel:label path:path realPath:realPath type:type];

            [directories addObject:rootDirectoryModel];

            // set the realPath of the first directory to preference USER_DEFAULTS_KEY_FIRST_ROOT_DIRECTORY

            if ([type isEqualToString:ROOT_DIRECTORY_TYPE_USER_HOME]) {
                [userDefaults setObject:realPath forKey:USER_DEFAULTS_KEY_FIRST_ROOT_DIRECTORY];
            }
        }

        NSArray *sortedDirectories;

        sortedDirectories = [directories sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            return [RootDirectoryService compareRootDirectoryModel:((RootDirectoryModel *) obj1) withAnotherRootDirectoryModel:((RootDirectoryModel *) obj2)];
        }];

        return [sortedDirectories mutableCopy];
    }
}

+ (NSComparisonResult)compareRootDirectoryModel:(RootDirectoryModel *)model1 withAnotherRootDirectoryModel:(RootDirectoryModel *)model2 {
    // USER_HOME is always the first one
    // Then DIRECTORY(and suffix with DIRECTORY), LOCAL_DISK, EXTERNAL_DISK, DVD_PLAYER, NETWORK_DISK in order
    // TIME_MACHINE is always the last one

    NSComparisonResult result;

    NSString *model1Type = [model1 type];
    NSString *model2Type = [model2 type];

    if (model1Type && model2Type) {
        if ([model1Type isEqualToString:ROOT_DIRECTORY_TYPE_USER_HOME]) {
            result = NSOrderedAscending;
        } else if ([model2Type isEqualToString:ROOT_DIRECTORY_TYPE_USER_HOME]) {
            result = NSOrderedDescending;
        } else if ([model1Type hasSuffix:ROOT_DIRECTORY_TYPE_DIRECTORY] && ([model2Type isEqualToString:ROOT_DIRECTORY_TYPE_LOCAL_DISK] || [model2Type isEqualToString:ROOT_DIRECTORY_TYPE_EXTERNAL_DISK] || [model2Type isEqualToString:ROOT_DIRECTORY_TYPE_DVD_PLAYER] || [model2Type isEqualToString:ROOT_DIRECTORY_TYPE_TIME_MACHINE])) {
            result = NSOrderedAscending;
        } else if ([model2Type hasSuffix:ROOT_DIRECTORY_TYPE_DIRECTORY] && ([model1Type isEqualToString:ROOT_DIRECTORY_TYPE_LOCAL_DISK] || [model1Type isEqualToString:ROOT_DIRECTORY_TYPE_EXTERNAL_DISK] || [model1Type isEqualToString:ROOT_DIRECTORY_TYPE_DVD_PLAYER] || [model1Type isEqualToString:ROOT_DIRECTORY_TYPE_TIME_MACHINE])) {
            result = NSOrderedDescending;
        } else if ([model1Type isEqualToString:ROOT_DIRECTORY_TYPE_LOCAL_DISK] && ([model2Type isEqualToString:ROOT_DIRECTORY_TYPE_EXTERNAL_DISK] || [model2Type isEqualToString:ROOT_DIRECTORY_TYPE_DVD_PLAYER] || [model2Type isEqualToString:ROOT_DIRECTORY_TYPE_TIME_MACHINE])) {
            result = NSOrderedAscending;
        } else if ([model2Type isEqualToString:ROOT_DIRECTORY_TYPE_LOCAL_DISK] && ([model1Type isEqualToString:ROOT_DIRECTORY_TYPE_EXTERNAL_DISK] || [model1Type isEqualToString:ROOT_DIRECTORY_TYPE_DVD_PLAYER] || [model1Type isEqualToString:ROOT_DIRECTORY_TYPE_TIME_MACHINE])) {
            result = NSOrderedDescending;
        } else if ([model1Type isEqualToString:ROOT_DIRECTORY_TYPE_EXTERNAL_DISK] && ([model2Type isEqualToString:ROOT_DIRECTORY_TYPE_DVD_PLAYER] || [model2Type isEqualToString:ROOT_DIRECTORY_TYPE_TIME_MACHINE])) {
            result = NSOrderedAscending;
        } else if ([model2Type isEqualToString:ROOT_DIRECTORY_TYPE_EXTERNAL_DISK] && ([model1Type isEqualToString:ROOT_DIRECTORY_TYPE_DVD_PLAYER] || [model1Type isEqualToString:ROOT_DIRECTORY_TYPE_TIME_MACHINE])) {
            result = NSOrderedDescending;
        } else if ([model1Type isEqualToString:ROOT_DIRECTORY_TYPE_DVD_PLAYER] && [model2Type isEqualToString:ROOT_DIRECTORY_TYPE_TIME_MACHINE]) {
            result = NSOrderedAscending;
        } else if ([model2Type isEqualToString:ROOT_DIRECTORY_TYPE_DVD_PLAYER] && [model1Type isEqualToString:ROOT_DIRECTORY_TYPE_TIME_MACHINE]) {
            result = NSOrderedDescending;
        } else {
            // [obj1Type isEqualToString:obj2Type]
            result = [self compareRootDirectoryWithSameType:model1 withAnotherRootDirectoryModel:model2];
        }
    } else {
        result = [self compareRootDirectoryWithSameType:model1 withAnotherRootDirectoryModel:model2];
    }

    return result;
}

+ (NSComparisonResult)compareRootDirectoryWithSameType:(RootDirectoryModel *)model1 withAnotherRootDirectoryModel:(RootDirectoryModel *)model2 {
    // For the same type(or empty type), compare the followings in order:
    // label, path, realPath

    NSComparisonResult result;

    RootDirectoryModel *copy1 = [model1 copy];
    RootDirectoryModel *copy2 = [model2 copy];

    NSString *obj1Label = [copy1 directoryLabel];
    NSString *obj2Label = [copy2 directoryLabel];

    if ([obj1Label isEqualToString:obj2Label]) {
        NSString *obj1Path = [copy1 directoryPath];
        NSString *obj2Path = [copy2 directoryPath];

        if ([obj1Path isEqualToString:obj2Path]) {
            result = [[copy1 directoryRealPath] compare:[copy2 directoryRealPath]];
        } else {
            result = [obj1Path compare:obj2Path];
        }
    } else {
        result = [obj1Label compare:obj2Label];
    }

    return result;
}

+ (NSString *)imageNameFromRootDirectoryType:(NSString *)type {
    NSString *imageName;

    if ([type isEqualToString:ROOT_DIRECTORY_TYPE_USER_HOME]) {
        imageName = @"user-home";
    } else if ([type isEqualToString:ROOT_DIRECTORY_TYPE_LOCAL_DISK]) {
        imageName = @"local-disk";
    } else if ([type isEqualToString:ROOT_DIRECTORY_TYPE_EXTERNAL_DISK]) {
        imageName = @"external-disk";
    } else if ([type isEqualToString:ROOT_DIRECTORY_TYPE_NETWORK_DISK]) {
        imageName = @"network-disk";
    } else if ([type isEqualToString:ROOT_DIRECTORY_TYPE_DVD_PLAYER]) {
        imageName = @"dvd-drive";
    } else if ([type isEqualToString:ROOT_DIRECTORY_TYPE_TIME_MACHINE]) {
        imageName = @"time-machine";
    } else {
        imageName = @"folder";
    }

    return imageName;
}

@end
