#import "CountryService.h"

@interface CountryService()

@property (nonatomic, strong) NSDictionary *countryIdAndCode;

@end

@implementation CountryService {

}

- (NSDictionary *)countryIdAndCode {
    if (!_countryIdAndCode) {
        NSString *path = [[NSBundle bundleWithIdentifier:@"com.filelug.FilelugKit"] pathForResource:@"CountryIdAndCode" ofType:@"strings"];

        _countryIdAndCode = [NSDictionary dictionaryWithContentsOfFile:path];
    }

    return _countryIdAndCode;
}

+ (NSString *)stringRepresentationWithCountryCode:(NSNumber *)countryCode phoneNumber:(NSString *)phoneNumber {
    return [NSString stringWithFormat:@"+%@ %@", [countryCode stringValue], phoneNumber];
}

- (NSNumber *)countryCodeFromCountryId:(NSString *)countryId {
    NSDictionary *countryIdAndCodes = [self countryIdAndCode];

    NSNumber *countryCode;

    if (countryIdAndCodes) {
        NSString *countryCodeString = (NSString *) countryIdAndCodes[countryId];

        NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];

        numberFormatter.numberStyle = NSNumberFormatterNoStyle;

        countryCode = [numberFormatter numberFromString:countryCodeString];
    } else {
        countryCode = @(0);
    }

    return countryCode;
}


@end
