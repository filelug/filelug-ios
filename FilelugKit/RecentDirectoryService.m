//
//  RecentDirectoryService.m
//  filelug
//
//  Created by masonhsieh on 13/08/2017.
//
//

#import "RecentDirectoryService.h"
#import "RecentDirectoryDao.h"
#import "RootDirectoryModel.h"
#import "Utility.h"
#import "RecentDirectory+CoreDataClass.h"
#import "DirectoryService.h"

@interface RecentDirectoryService()

@property (nonatomic, strong) RecentDirectoryDao *recentDirectoryDao;

@end

@implementation RecentDirectoryService

- (RecentDirectoryDao *)recentDirectoryDao {
    if (!_recentDirectoryDao) {
        _recentDirectoryDao = [[RecentDirectoryDao alloc] init];
    }

    return _recentDirectoryDao;
}

- (NSMutableArray *)recentDirectoriesForCurrentUserComputer {
    NSMutableArray<RootDirectoryModel *> *directories = [NSMutableArray array];

    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *userComputerId = [userDefaults objectForKey:USER_DEFAULTS_KEY_USER_COMPUTER_ID];

    if (userComputerId) {
        NSError *error;

        NSArray<RecentDirectory *> *recentDirectories = [self.recentDirectoryDao recentDirectoriesWithUserComputer:userComputerId error:&error];

        if (error) {
            NSLog(@"Error on finding recent directories.\n%@", [error userInfo]);
        }

        if (recentDirectories && [recentDirectories count] > 0) {
            for (RecentDirectory *recentDirectory in recentDirectories) {
                NSString *directoryPath = recentDirectory.directoryPath;
                NSString *directoryRealPath = recentDirectory.directoryRealPath;

                NSString *label = [DirectoryService filenameFromServerFilePath:directoryPath];

                RootDirectoryModel *rootDirectoryModel = [[RootDirectoryModel alloc] initWithLabel:label path:directoryPath realPath:directoryRealPath type:ROOT_DIRECTORY_TYPE_DIRECTORY];

                [directories addObject:rootDirectoryModel];
            }
        }
    }

    return directories;
}

- (void)createOrUpdateRecentDirectoryWithDirectoryPath:(NSString *)directoryPath directoryRealPath:(NSString *)directoryRealPath completionHandler:(void (^)(void))handler {
    [self.recentDirectoryDao createOrUpdateRecentDirectoryWithDirectoryPath:directoryPath directoryRealPath:directoryRealPath completionHandler:handler];
}

- (void)deleteRecentDirectoryWithDirectoryPath:(NSString *)directoryPath successHandler:(void (^)(void))handler {
    [self.recentDirectoryDao deleteRecentDirectoryWithDirectoryPath:directoryPath successHandler:handler];
}
@end
