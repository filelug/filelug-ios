//
//  UserComputer+CoreDataProperties.m
//  filelug
//
//  Created by masonhsieh on 28/04/2017.
//
//

#import "UserComputer+CoreDataProperties.h"

@implementation UserComputer (CoreDataProperties)

+ (NSFetchRequest<UserComputer *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"UserComputer"];
}

@dynamic computerAdminId;
@dynamic computerGroup;
@dynamic computerId;
@dynamic computerName;
@dynamic downloadDescriptionType;
@dynamic downloadDescriptionValue;
@dynamic downloadDirectory;
@dynamic downloadNotificationType;
@dynamic downloadSubdirectoryType;
@dynamic downloadSubdirectoryValue;
@dynamic showHidden;
@dynamic uploadDescriptionType;
@dynamic uploadDescriptionValue;
@dynamic uploadDirectory;
@dynamic uploadNotificationType;
@dynamic uploadSubdirectoryType;
@dynamic uploadSubdirectoryValue;
@dynamic userComputerId;
@dynamic assetFiles;
@dynamic fileDownloadGroups;
@dynamic fileTransfers;
@dynamic fileUploadGroups;
@dynamic hierarchicalModels;
@dynamic user;

@end
