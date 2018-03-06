#import <Photos/Photos.h>
#import "AssetCollectionModel.h"


@implementation AssetCollectionModel {

}

- (instancetype)initWithTitle:(NSString *)title count:(NSUInteger)count thumbnail:(UIImage *)thumbnail collection:(PHAssetCollection *)collection {
    self = [super init];

    if (self) {
        self.title = title;
        self.count = count;
        self.thumbnail = thumbnail;
        self.collection = collection;
    }

    return self;
}

@end