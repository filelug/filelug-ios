//
//  UserComputer+CoreDataClass.h
//  filelug
//
//  Created by masonhsieh on 28/04/2017.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class AssetFile, FileDownloadGroup, FileTransfer, FileUploadGroup, HierarchicalModel, User;

NS_ASSUME_NONNULL_BEGIN

@interface UserComputer : NSManagedObject

@end

NS_ASSUME_NONNULL_END

#import "UserComputer+CoreDataProperties.h"
