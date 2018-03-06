#import <Foundation/Foundation.h>


@interface UserWithoutManaged : NSObject

@property(nonatomic, strong) NSString *nickname;
@property(nonatomic, strong) NSString *email;
@property(nonatomic, strong) NSString *passwd;
@property(nonatomic, strong) NSNumber *showHidden;
@property(nonatomic, strong) NSNumber *active;
@property(nonatomic, strong) NSString *userId;
@property(nonatomic, strong) NSString *countryId;
@property(nonatomic, strong) NSString *phoneNumber;
@property(nonatomic, strong) NSString *sessionId;
@property(nonatomic, strong) NSString *locale;


+ (NSString *)generateVerificationFromUserId:(NSString *)userId password:(NSString *)password nickname:(NSString *)nickname;

+ (NSString *)generateVerificationFromUserId:(NSString *)userId nickname:(NSString *)nickname session:(NSString *)sessionId;

+ (NSString *)generateVerificationFromUserId:(NSString *)userId countryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber;

+ (NSString *)generateVerificationFromUserId:(NSString *)userId countryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber password:(NSString *)password;

+ (NSString *)generateVerificationFromUserId:(NSString *)userId;

+ (NSString *)generateVerificationFromUserId:(NSString *)userId countryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber password:(NSString *)password encryptedSecurityCode:(NSString *)encryptedSecurityCode;

+ (NSString *)generateVerificationFromCountryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber password:(NSString *)password nickname:(NSString *)nickname;

+ (NSString *)generateSendSecurityCodeVerificationFromCountryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber;

+ (NSString *)userIdFromUserComputerId:(NSString *)userComputerId;

- (id)initWithUserId:(NSString *)userId countryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber sessionId:(NSString *)sessionId nickname:(NSString *)nickname email:(NSString *)email active:(NSNumber *)active locale:(NSString *)locale;
//- (id)initWithUserId:(NSString *)userId countryId:(NSString *)countryId phoneNumber:(NSString *)phoneNumber nickname:(NSString *)nickname email:(NSString *)email active:(NSNumber *)active locale:(NSString *)locale;

- (NSString *)description;

@end