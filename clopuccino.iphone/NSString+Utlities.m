#import <CommonCrypto/CommonDigest.h>
#import "NSString+Utlities.h"

@implementation NSString (Utlities)

- (NSString *)MD5 {
    // Create pointer to the string as UTF8
    const char *ptr = [self UTF8String];

    // Create byte array of unsigned chars
    unsigned char md5Buffer[CC_MD5_DIGEST_LENGTH];

    // Create 16 byte MD5 hash value, store in buffer
    CC_MD5(ptr, (CC_LONG) strlen(ptr), md5Buffer);

    // Convert MD5 value in the buffer to NSString of hex values
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];

    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", md5Buffer[i]];
    }

    return output;
}

- (NSString *)SHA256 {
    const int HASH_SIZE = 32;
    unsigned char hashedChars[HASH_SIZE];
    const char *accountName = [self UTF8String];
    size_t accountNameLen = strlen(accountName);

    // Confirm that the length of the user name is small enough
    // to be recast when calling the hash function.
    if (accountNameLen > UINT32_MAX) {
        NSLog(@"Account name too long to hash: %@", self);
        return nil;
    }

    CC_SHA256(accountName, (CC_LONG) accountNameLen, hashedChars);

    // Convert the array of bytes into a string showing its hex representation.
    NSMutableString *userAccountHash = [[NSMutableString alloc] init];

    for (int i = 0; i < HASH_SIZE; i++) {
        [userAccountHash appendFormat:@"%02x", hashedChars[i]];
    }

    return userAccountHash;
}

// The method is used to escape the name or value before composing the JSON string.
- (NSString *)escapeIllegalJsonCharacter {
    NSCharacterSet *illegalCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"\\'\""];

    NSRange range = [self rangeOfCharacterFromSet:illegalCharacterSet];

    if (range.location == NSNotFound) {
        return self;
    } else {
        NSString *escapeString = [self stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
        escapeString = [escapeString stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        escapeString = [escapeString stringByReplacingOccurrencesOfString:@"" withString:@"\\'"];

        return escapeString;
    }
}

@end