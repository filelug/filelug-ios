#import <Foundation/Foundation.h>

@interface RootDirectoryModel : NSObject <NSCopying>

@property(nonatomic, strong) NSString *directoryLabel;
@property(nonatomic, strong) NSString *directoryPath;
@property(nonatomic, strong) NSString *directoryRealPath;
@property(nonatomic, strong) NSString *type;

- (instancetype)initWithLabel:(NSString *)label path:(NSString *)path realPath:(NSString *)realPath type:(NSString *)type;

- (NSString *)displayNameForCellLabelText;

@end
