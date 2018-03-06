#import <Foundation/Foundation.h>

@interface CountryService : NSObject

+ (NSString *)stringRepresentationWithCountryCode:(NSNumber *)countryCode phoneNumber:(NSString *)phoneNumber;

// Return @0 if country id is nil or no related country code found.
- (NSNumber *)countryCodeFromCountryId:(NSString *)countryId;

@end
