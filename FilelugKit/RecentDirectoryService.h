//
//  RecentDirectoryService.h
//  filelug
//
//  Created by masonhsieh on 13/08/2017.
//
//

#import <Foundation/Foundation.h>

@interface RecentDirectoryService : NSObject

- (NSMutableArray *)recentDirectoriesForCurrentUserComputer;

- (void)createOrUpdateRecentDirectoryWithDirectoryPath:(NSString *)directoryPath directoryRealPath:(NSString *)directoryRealPath completionHandler:(void (^)(void))handler;

- (void)deleteRecentDirectoryWithDirectoryPath:(NSString *)directoryPath successHandler:(void (^)(void))handler;
@end
