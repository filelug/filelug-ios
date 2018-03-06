#import "UploadSubdirectoryService.h"
#import "Utility.h"
#import "UserComputerService.h"
#import "UserComputerWithoutManaged.h"
#import "UserComputerDao.h"

@interface UploadSubdirectoryService ()

@property(nonatomic, strong) UserComputerDao *userComputerDao;

@property(nonatomic, strong) UserComputerService *userComputerService;

@end

@implementation UploadSubdirectoryService

static NSUInteger defaultType = 0;

+ (NSDictionary *)allTypeAndNameDictionaryWithOrder {
    static NSDictionary *allTypeAndNames;

    if (!allTypeAndNames) {
        allTypeAndNames = @{
                @0 : NSLocalizedString(@"No subdirectory", @""),
                @1 : NSLocalizedString(@"Current timestamp", @""),
                @2 : NSLocalizedString(@"Customized name", @""),
                @3 : NSLocalizedString(@"Current timestamp + Customized name", @""),
                @4 : NSLocalizedString(@"Customized name + Current timestamp", @"")
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

+ (BOOL)isCustomizableWithType:(NSInteger)type {
    return type > 1;
}

+ (NSString *)uploadSubdirectoryNameWithUploadSubdirectoryType:(NSNumber *)uploadSubdirectoryType {
    NSUInteger typeInteger = uploadSubdirectoryType ? [uploadSubdirectoryType unsignedIntegerValue] : defaultType;

    NSNumber *typeNumber = @(typeInteger);

    return [self allTypeAndNameDictionaryWithOrder][typeNumber];
}

+ (NSNumber *)uploadSubdirectoryTypeWithUploadSubdirectoryName:(NSString *)uploadSubdirectoryName {
    if (!uploadSubdirectoryName || [uploadSubdirectoryName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length < 1) {
        return @(defaultType);
    } else {
        __block NSNumber *typeNumber;

        [[self allTypeAndNameDictionaryWithOrder] enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, NSString *value, BOOL *stop) {
            if ([uploadSubdirectoryName isEqualToString:value]) {
                typeNumber = key;

                *stop = YES;
            }
        }];

        return typeNumber;
    }
}

- (instancetype)initWithUploadSubdirectoryType:(NSNumber *)uploadSubdirectoryType uploadSubdirectoryValue:(NSString *)uploadSubdirectoryValue {
    self = [super init];

    if (self) {
        [self prepareWithUploadSubdirectoryType:uploadSubdirectoryType uploadSubdirectoryValue:uploadSubdirectoryValue];
    }

    return self;
}

- (instancetype)initWithPersistedTypeAndValue {
    self = [super init];

    if (self) {
        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSNumber *persistedType = [userDefaults objectForKey:USER_DEFAULTS_KEY_UPLOAD_SUBDIRECTORY_TYPE];
        NSString *persistedValue = [userDefaults objectForKey:USER_DEFAULTS_KEY_UPLOAD_SUBDIRECTORY_VALUE];

        [self prepareWithUploadSubdirectoryType:persistedType uploadSubdirectoryValue:persistedValue];
    }

    return self;
}

- (void)prepareWithUploadSubdirectoryType:(NSNumber *)uploadSubdirectoryType uploadSubdirectoryValue:(NSString *)uploadSubdirectoryValue {
    NSUInteger typeInteger = uploadSubdirectoryType ? [uploadSubdirectoryType unsignedIntegerValue] : defaultType;

    _type = @(typeInteger);

    _name = [UploadSubdirectoryService allTypeAndNameDictionaryWithOrder][_type];

    _customizable = typeInteger > 1;

    if (uploadSubdirectoryValue && [uploadSubdirectoryValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
        _customizedValue = uploadSubdirectoryValue;
    } else {
        _customizedValue = @"";
    }
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

- (NSString *)generateRealSubdirectoryValue {
    NSString *realSubdirectoryValue;

    if (self.type) {
        switch ([self.type unsignedIntegerValue]) {
            case 1:
                realSubdirectoryValue = [Utility dateStringFromDate:[NSDate date] format:DATE_FORMAT_FOR_FILE_UPLOAD_GROUP_SUBDIRECTORY locale:[NSLocale autoupdatingCurrentLocale] timeZone:nil];

                break;
            case 2:
                realSubdirectoryValue = self.customizedValue;
                break;
            case 3:
                realSubdirectoryValue = [NSString stringWithFormat:@"%@+%@", [Utility dateStringFromDate:[NSDate date] format:DATE_FORMAT_FOR_FILE_UPLOAD_GROUP_SUBDIRECTORY locale:[NSLocale autoupdatingCurrentLocale] timeZone:nil], self.customizedValue];

                break;
            case 4:
                realSubdirectoryValue = [NSString stringWithFormat:@"%@+%@", self.customizedValue, [Utility dateStringFromDate:[NSDate date] format:DATE_FORMAT_FOR_FILE_UPLOAD_GROUP_SUBDIRECTORY locale:[NSLocale autoupdatingCurrentLocale] timeZone:nil]];

                break;
            default:
                realSubdirectoryValue = @"";
        }
    }

    return realSubdirectoryValue ? realSubdirectoryValue : @"";
}

- (NSString *)displayedText {
    return self.name;
}

- (void)persistWithSession:(NSString *)sessionId completionHandler:(void (^)(NSURLResponse *, NSData *, NSError *))completionHandler {
    // update type and value to server, and then update local db and preferences after server updated successfully

    NSNumber *copiedType = [self.type copy];
    NSString *copiedCustomizedValue = self.customizedValue;

    NSDictionary *profiles = @{
            @"upload-subdirectory-type" : copiedType,
            @"upload-subdirectory-value" : copiedCustomizedValue
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
                    userComputerWithoutManaged.uploadSubdirectoryType = copiedType;
                    userComputerWithoutManaged.uploadSubdirectoryValue = copiedCustomizedValue;

                    [self.userComputerDao updateUserComputerWithUserComputerWithoutManaged:userComputerWithoutManaged completionHandler:^(NSError *updateError){
                        if (updateError) {
                            NSLog(@"Error on updating upload subdirectory type with: '%@', subdirectory value with: '%@'\n%@", copiedType, copiedCustomizedValue, [updateError userInfo]);
                        } else {
                            [userDefaults setObject:copiedType forKey:USER_DEFAULTS_KEY_UPLOAD_SUBDIRECTORY_TYPE];
                            [userDefaults setObject:copiedCustomizedValue forKey:USER_DEFAULTS_KEY_UPLOAD_SUBDIRECTORY_VALUE];
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
    [description appendFormat:@", self.customizable=%d", self.customizable];
    [description appendFormat:@", self.customizedValue=%@", self.customizedValue];
    [description appendString:@">"];
    return description;
}

@end
