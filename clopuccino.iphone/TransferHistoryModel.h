#import <Foundation/Foundation.h>


@interface TransferHistoryModel : NSObject

@property(nonatomic, strong) NSString *computerGroup;

@property(nonatomic, strong) NSString *computerName;

@property(nonatomic, strong) NSNumber *fileSize;

@property(nonatomic, strong) NSNumber *endTimestamp;

@property(nonatomic, strong) NSString *filename;

- (id)initWithComputerGroup:(NSString *)computerGroup computerName:(NSString *)computerName fileSize:(NSNumber *)fileSize endTimestamp:(NSNumber *)endTimestamp filename:(NSString *)filename;

@end