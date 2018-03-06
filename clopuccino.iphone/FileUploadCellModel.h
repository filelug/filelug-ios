#import <Foundation/Foundation.h>


@interface FileUploadCellModel : NSObject

@property(nonatomic, strong) NSURL *assetURL;

@property(nonatomic, strong) UIImage *thumbnail;

@property(nonatomic, strong) NSString *filename;

@end
