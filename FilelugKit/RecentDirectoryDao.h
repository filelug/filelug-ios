//
//  RecentDirectoryDao.h
//  filelug
//
//  Created by masonhsieh on 13/08/2017.
//
//

#import <Foundation/Foundation.h>

@interface RecentDirectoryDao : NSObject

- (NSArray *)recentDirectoriesWithUserComputer:(NSString *)userComputerId error:(NSError **)error;

- (void)createOrUpdateRecentDirectoryWithDirectoryPath:(NSString *)directoryPath directoryRealPath:(NSString *)directoryRealPath completionHandler:(void (^)(void))handler;

- (void)deleteRecentDirectoryWithDirectoryPath:(NSString *)directoryPath successHandler:(void(^)(void))handler;
@end
