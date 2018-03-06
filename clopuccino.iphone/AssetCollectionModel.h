#import <Foundation/Foundation.h>


@class PHAssetCollection;


@interface AssetCollectionModel : NSObject

@property (nonatomic, strong) UIImage *thumbnail;

@property (nonatomic, strong) NSString *title;

@property (nonatomic, assign) NSUInteger count;

@property (nonatomic, strong) PHAssetCollection *collection;

//// element of type PHAsset
//@property (nonatomic, strong) NSMutableArray *assets;

- (instancetype)initWithTitle:(NSString *)title count:(NSUInteger)count thumbnail:(UIImage *)thumbnail collection:(PHAssetCollection *)collection;

@end