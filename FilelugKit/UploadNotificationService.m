#import "UploadNotificationService.h"
#import "UserComputerDao.h"
#import "UserComputerService.h"
#import "Utility.h"
#import "UserComputerWithoutManaged.h"

@interface UploadNotificationService ()

@property(nonatomic, strong) UserComputerDao *userComputerDao;

@property(nonatomic, strong) UserComputerService *userComputerService;

@end

@implementation UploadNotificationService

// Default notification type
static NSUInteger defaultType = 2;

+ (NSDictionary *)allTypeAndNameDictionaryWithOrder {
    static NSDictionary *allTypeAndNames;

    if (!allTypeAndNames) {
        allTypeAndNames = @{
                @(FILE_TRANSFER_NOTIFICATION_TYPE_NO_NOTIFICATION) : NSLocalizedString(@"No notification", @""),
                @(FILE_TRANSFER_NOTIFICATION_TYPE_ON_EACH_FILE) : NSLocalizedString(@"On each file", @""),
                @(FILE_TRANSFER_NOTIFICATION_TYPE_ON_ALL_FILES) : NSLocalizedString(@"On all files", @"")
        };
    }

    return allTypeAndNames;
}

+ (NSArray *)allTypesWithOrder {
    static NSArray *keys;

    if (!keys) {
        keys = [[[self allTypeAndNameDictionaryWithOrder] allKeys] sortedArrayUsingComparator:^NSComparisonResult(id a, id b){
            return [((NSNumber *) a) compare:(NSNumber *) b];
        }];
    }

    return keys;
}

+ (NSArray *)namesOfAllTypesWithOrder {
    static NSArray *values;

    if (!values) {
        NSArray *sortedKeys = [self allTypesWithOrder];

        NSMutableArray *mutableValues = [NSMutableArray arrayWithCapacity:[sortedKeys count]];

        NSDictionary *keyValues = [self allTypeAndNameDictionaryWithOrder];

        for (NSNumber *key in sortedKeys) {
            [mutableValues addObject:keyValues[key]];
        }

        values = [mutableValues copy];
    }

    return values;
}

+ (NSInteger)defaultType {
    return defaultType;
}

+ (NSString *)uploadNotificationNameWithUploadNotificationType:(NSNumber *)uploadNotificationType {
    NSUInteger typeInteger = uploadNotificationType ? [uploadNotificationType unsignedIntegerValue] : defaultType;

    NSNumber *typeNumber = @(typeInteger);

    return [self allTypeAndNameDictionaryWithOrder][typeNumber];
}

+ (NSNumber *)uploadNotificationTypeWithUploadNotificationName:(NSString *)uploadNotificationName {
    if (!uploadNotificationName || [uploadNotificationName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length < 1) {
        return @(defaultType);
    } else {
        __block NSNumber *typeNumber;

        [[self allTypeAndNameDictionaryWithOrder] enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, NSString *value, BOOL *stop) {
            if ([uploadNotificationName isEqualToString:value]) {
                typeNumber = key;

                *stop = YES;
            }
        }];

        return typeNumber;
    }
}

- (instancetype)initWithUploadNotificationType:(NSNumber *)uploadNotificationType {
    self = [super init];

    if (self) {
        [self prepareWithUploadNotificationType:uploadNotificationType];
    }

    return self;
}

- (instancetype)initWithPersistedType {
    self = [super init];

    if (self) {
        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSNumber *persistedType = [userDefaults objectForKey:USER_DEFAULTS_KEY_UPLOAD_NOTIFICATION_TYPE];

        [self prepareWithUploadNotificationType:persistedType];
    }

    return self;
}

- (void)prepareWithUploadNotificationType:(NSNumber *)uploadNotificationType {
    NSUInteger typeInteger = uploadNotificationType ? [uploadNotificationType unsignedIntegerValue] : defaultType;

    _type = @(typeInteger);

    _name = [UploadNotificationService allTypeAndNameDictionaryWithOrder][_type];
}

- (UserComputerDao *)userComputerDao {
    if (!_userComputerDao) {
        _userComputerDao = [[UserComputerDao alloc] init];
    }

    return _userComputerDao;
}

- (UserComputerService *)userComputerService {
    if (!_userComputerService) {
        _userComputerService = [[UserComputerService alloc] initWithCachePolicy:NSURLRequestUseProtocolCachePolicy timeInterval:CONNECTION_TIME_INTERVAL];
    }

    return _userComputerService;
}

- (void)persistWithSession:(NSString *)sessionId completionHandler:(void (^)(NSURLResponse *, NSData *, NSError *))completionHandler {
    // update type to server, and then update local db and preferences after server updated successfully

    NSNumber *copiedType = [self.type copy];

    NSDictionary *profiles = @{
            @"upload-notification-type" : copiedType
    };

    [self.userComputerService updateUserComputerProfilesWithProfiles:profiles session:sessionId completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];

        if (statusCode == 200) {
            // Save to local db and update preferences

            NSUserDefaults *userDefaults = [Utility groupUserDefaults];

            NSString *userComputerId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

            if (userComputerId) {
                UserComputerWithoutManaged *userComputerWithoutManaged = [self.userComputerDao findUserComputerForUserComputerId:userComputerId];

                if (userComputerWithoutManaged) {
                    userComputerWithoutManaged.uploadNotificationType = copiedType;

                    [self.userComputerDao updateUserComputerWithUserComputerWithoutManaged:userComputerWithoutManaged completionHandler:^(NSError *updateError){
                        if (updateError) {
                            NSLog(@"Error on updating upload notification type with: '%@'\n%@", copiedType, [updateError userInfo]);
                        } else {
                            [userDefaults setObject:copiedType forKey:USER_DEFAULTS_KEY_UPLOAD_NOTIFICATION_TYPE];
                        }
                    }];
                }
            }
        }

        if (completionHandler) {
            completionHandler(response, data, error);
        }
    }];
}

- (NSString *)description {
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];
    [description appendFormat:@"self.type=%@", self.type];
    [description appendFormat:@", self.name=%@", self.name];
    [description appendString:@">"];
    return description;
}

@end
