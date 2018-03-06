#import "UploadDescriptionService.h"
#import "UserComputerService.h"
#import "UserComputerDao.h"
#import "Utility.h"
#import "UserComputerWithoutManaged.h"

@interface UploadDescriptionService ()

@property(nonatomic, strong) UserComputerDao *userComputerDao;

@property(nonatomic, strong) UserComputerService *userComputerService;

@end

@implementation UploadDescriptionService

static NSUInteger defaultType = 0;

+ (NSDictionary *)allTypeAndNameDictionaryWithOrder {
    static NSDictionary *allTypeAndNames;

    if (!allTypeAndNames) {
        allTypeAndNames = @{
                @0 : NSLocalizedString(@"No description", @""),
                @1 : NSLocalizedString(@"Filename list", @""),
                @2 : NSLocalizedString(@"Customized description", @""),
                @3 : NSLocalizedString(@"Customized description + Filename list", @"")
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

+ (NSString *)uploadDescriptionNameWithUploadDescriptionType:(NSNumber *)uploadDescriptionType {
    NSUInteger typeInteger = uploadDescriptionType ? [uploadDescriptionType unsignedIntegerValue] : defaultType;

    NSNumber *typeNumber = @(typeInteger);

    return [self allTypeAndNameDictionaryWithOrder][typeNumber];
}

+ (NSNumber *)uploadDescriptionTypeWithUploadDescriptionName:(NSString *)uploadDescriptionName {
    if (!uploadDescriptionName || [uploadDescriptionName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length < 1) {
        return @(defaultType);
    } else {
        __block NSNumber *typeNumber;

        [[self allTypeAndNameDictionaryWithOrder] enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, NSString *value, BOOL *stop) {
            if ([uploadDescriptionName isEqualToString:value]) {
                typeNumber = key;

                *stop = YES;
            }
        }];

        return typeNumber;
    }
}

- (instancetype)initWithUploadDescriptionType:(NSNumber *)uploadDescriptionType uploadDescriptionValue:(NSString *)uploadDescriptionValue {
    self = [super init];

    if (self) {
        [self prepareWithUploadDescriptionType:uploadDescriptionType uploadDescriptionValue:uploadDescriptionValue];
    }

    return self;
}

- (instancetype)initWithPersistedTypeAndValue {
    self = [super init];

    if (self) {
        NSUserDefaults *userDefaults = [Utility groupUserDefaults];

        NSNumber *persistedType = [userDefaults objectForKey:USER_DEFAULTS_KEY_UPLOAD_DESCRIPTION_TYPE];
        NSString *persistedValue = [userDefaults objectForKey:USER_DEFAULTS_KEY_UPLOAD_DESCRIPTION_VALUE];

        [self prepareWithUploadDescriptionType:persistedType uploadDescriptionValue:persistedValue];
    }

    return self;
}

- (void)prepareWithUploadDescriptionType:(NSNumber *)uploadDescriptionType uploadDescriptionValue:(NSString *)uploadDescriptionValue {
    NSUInteger typeInteger = uploadDescriptionType ? [uploadDescriptionType unsignedIntegerValue] : defaultType;

    _type = @(typeInteger);

    _name = [UploadDescriptionService allTypeAndNameDictionaryWithOrder][_type];

    _customizable = typeInteger > 1;

    if (uploadDescriptionValue && [uploadDescriptionValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
        _customizedValue = uploadDescriptionValue;
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

- (NSString *)generateRealDescriptionValueWithFilenames:(NSArray *)filenames {
    NSString *realDescriptionValue;

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *lineSeparator = [userDefaults stringForKey:USER_DEFAULTS_KEY_SERVER_LINE_SEPARATOR];

    if (!lineSeparator) {
        NSString *fileSeparator = [userDefaults stringForKey:USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR];

        /* LF(\n): Multics, Unix and Unix-like systems (GNU/Linux, AIX, Xenix, Mac OS X, FreeBSD, etc.), BeOS, Amiga, RISC OS, and others
         * CR+LF(\r\n): DEC RT-11 and most other early non-Unix, non-IBM OSes, CP/M, MP/M, DOS, OS/2, Microsoft Windows,Symbian OS
         * CR(\r): Commodore machines, Apple II family, Mac OS up to version 9 and OS-9
         */

        if (fileSeparator && [fileSeparator isEqualToString:@"/"]) {
            lineSeparator = @"\n";
        } else {
            lineSeparator = @"\r\n";
        }
    }

    if (self.type) {
        switch ([self.type unsignedIntegerValue]) {
            case 1:
                realDescriptionValue = [NSString stringWithFormat:@"---- %@ ----%@%@", NSLocalizedString(@"Filename List", @""), lineSeparator, [Utility stringFromStringArray:filenames separator:lineSeparator quotedCharacter:@""]];
                break;
            case 2:
                realDescriptionValue = self.customizedValue;
                break;
            case 3:
                realDescriptionValue = [NSString stringWithFormat:@"%@%@%@---- %@ ----%@%@", self.customizedValue, lineSeparator, lineSeparator, NSLocalizedString(@"Filename List", @""), lineSeparator, [Utility stringFromStringArray:filenames separator:lineSeparator quotedCharacter:@""]];
                break;
            default:
                realDescriptionValue = @"";
        }
    }

    return realDescriptionValue ? realDescriptionValue : @"";
}

- (NSString *)displayedText {
    return self.name;
}

- (void)persistWithSession:(NSString *)sessionId completionHandler:(void (^)(NSURLResponse *, NSData *, NSError *))completionHandler {
    // update type and value to server, and then update local db and preferences after server updated successfully

    NSNumber *copiedType = [self.type copy];
    NSString *copiedCustomizedValue = self.customizedValue;

    NSDictionary *profiles = @{
            @"upload-description-type" : copiedType,
            @"upload-description-value" : copiedCustomizedValue
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
                    userComputerWithoutManaged.uploadDescriptionType = copiedType;
                    userComputerWithoutManaged.uploadDescriptionValue = copiedCustomizedValue;

                    [self.userComputerDao updateUserComputerWithUserComputerWithoutManaged:userComputerWithoutManaged completionHandler:^(NSError *updateError){
                        if (updateError) {
                            NSLog(@"Error on updating upload description type with: '%@', description value with: '%@'\n%@", copiedType, copiedCustomizedValue, [updateError userInfo]);
                        } else {
                            [userDefaults setObject:copiedType forKey:USER_DEFAULTS_KEY_UPLOAD_DESCRIPTION_TYPE];
                            [userDefaults setObject:copiedCustomizedValue forKey:USER_DEFAULTS_KEY_UPLOAD_DESCRIPTION_VALUE];
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
