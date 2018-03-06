#import "UserWithoutManaged.h"
#import "Utility.h"
#import "NSString+Utlities.h"


@implementation UserWithoutManaged {

}

+ (NSString *)generateVerificationFromUserId:(NSString *)userId password:(NSString *)password nickname:(NSString *)nickname {
    NSString *verification = [[[NSString stringWithFormat:@"%@|%@:%@", userId, password, nickname] SHA256] stringByAppendingString:[[NSString stringWithFormat:@"%@==%@", nickname, password] MD5]];

    return verification;
}

+ (NSString *)generateVerificationFromUserId:(NSString *)userId nickname:(NSString *)nickname session:(NSString *)sessionId {
    NSString *verification = [[[NSString stringWithFormat:@"%@|%@:%@", userId, sessionId, nickname] SHA256] stringByAppendingString:[[NSString stringWithFormat:@"%@==%@", nickname, userId] MD5]];

    return verification;
}

+ (NSString *)generateVerificationFromUserId:(NSString *)userId countryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber {
    // For Java: DigestUtils.sha256Hex(userId + "|" + countryId + ":" + phoneNumber) + DigestUtils.md5Hex(phoneNumber + "==" + countryId);

    NSString *verification = [[[NSString stringWithFormat:@"%@|%@:%@", userId, countryId, phoneNumber] SHA256] stringByAppendingString:[[NSString stringWithFormat:@"%@==%@", phoneNumber, countryId] MD5]];

    return verification;
}

+ (NSString *)generateVerificationFromUserId:(NSString *)userId countryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber password:(NSString *)password {
    NSString *verification = [[[NSString stringWithFormat:@"%@|%@:%@_%@", phoneNumber, password, countryId, userId] SHA256] stringByAppendingString:[[NSString stringWithFormat:@"%@==%@", userId, password] MD5]];

    return verification;
}

+ (NSString *)generateVerificationFromUserId:(NSString *)userId {
    NSString *verification = [[[NSString stringWithFormat:@"%@|:_", userId] SHA256] stringByAppendingString:[[NSString stringWithFormat:@"%@==", userId] MD5]];

    return verification;
}

+ (NSString *)generateVerificationFromUserId:(NSString *)userId countryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber password:(NSString *)password encryptedSecurityCode:(NSString *)encryptedSecurityCode {
    NSString *verification = [[[NSString stringWithFormat:@"%@|%@:%@_%@", phoneNumber, password, countryId, encryptedSecurityCode] SHA256] stringByAppendingString:[[NSString stringWithFormat:@"%@==%@", userId, password] MD5]];

    return verification;
}

+ (NSString *)generateVerificationFromCountryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber password:(NSString *)password nickname:(NSString *)nickname {
    NSString *verification = [[[NSString stringWithFormat:@"%@|%@:%@_%@", phoneNumber, password, countryId, nickname] SHA256] stringByAppendingString:[[NSString stringWithFormat:@"%@==%@", nickname, password] MD5]];

    return verification;
}

+ (NSString *)generateSendSecurityCodeVerificationFromCountryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber {
    NSString *generationToken = @"9413";

    NSString *verification = [[[NSString stringWithFormat:@"%@|%@:%@", generationToken, countryId, phoneNumber] SHA256] stringByAppendingString:[[NSString stringWithFormat:@"%@==%@", phoneNumber, countryId] MD5]];

    return verification;
}

+ (NSString *)userIdFromUserComputerId:(NSString *)userComputerId {
    NSArray *components = [userComputerId componentsSeparatedByString:USER_COMPUTER_DELIMITERS];

    if (components && [components count] == 2) {
        return components[0];
    } else {
        NSLog(@"Incorrect format of user computer id: %@", userComputerId);

        return nil;
    }
}

- (id)initWithUserId:(NSString *)userId countryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber sessionId:(NSString *)sessionId nickname:(NSString *)nickname email:(NSString *)email active:(NSNumber *)active locale:(NSString *)locale {
    if (self = [super init]) {
        _userId = userId;
        _countryId = countryId;
        _phoneNumber = phoneNumber;
        _sessionId = sessionId;
        _nickname = nickname;
        _email = email;
        _active = active;

        if (locale) {
            _locale = locale;
        } else {
            NSUserDefaults *userDefaults = [Utility groupUserDefaults];
            _locale = [userDefaults stringForKey:USER_DEFAULTS_KEY_MAIN_APP_LOCALE];
        }
    }

    return self;
}
//- (id)initWithUserId:(NSString *)userId countryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber nickname:(NSString *)nickname email:(NSString *)email active:(NSNumber *)active locale:(NSString *)locale {
//    if (self = [super init]) {
//        _userId = userId;
//        _countryId = countryId;
//        _phoneNumber = phoneNumber;
//        _nickname = nickname;
//        _email = email;
//        _active = active;
//
//        if (locale) {
//            _locale = locale;
//        } else {
//            NSUserDefaults *userDefaults = [Utility groupUserDefaults];
//            _locale = [userDefaults stringForKey:USER_DEFAULTS_KEY_MAIN_APP_LOCALE];
//        }
//    }
//
//    return self;
//}

- (NSString *)description {
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];
    [description appendFormat:@"self.active=%@", self.active];
    [description appendFormat:@", self.nickname=%@", self.nickname];
    [description appendFormat:@", self.email=%@", self.email];
    [description appendFormat:@", self.passwd=%@", self.passwd];
    [description appendFormat:@", self.showHidden=%@", self.showHidden];
    [description appendFormat:@", self.userId=%@", self.userId];
    [description appendFormat:@", self.countryId=%@", self.countryId];
    [description appendFormat:@", self.phoneNumber=%@", self.phoneNumber];
    [description appendFormat:@", self.sessionId=%@", self.sessionId];
    [description appendFormat:@", self.locale=%@", self.locale];
    [description appendString:@">"];
    return description;
}

@end