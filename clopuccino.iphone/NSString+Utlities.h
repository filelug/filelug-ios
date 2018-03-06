#import <Foundation/Foundation.h>

@interface NSString (Utlities)

- (NSString *)MD5;

- (NSString *)SHA256;

// The method is used to escape the name or value before composing the JSON string.
// Deal with \, ", and '
- (NSString *)escapeIllegalJsonCharacter;


@end