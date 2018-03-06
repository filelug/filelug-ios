#import "UserComputerWithoutManaged.h"


@implementation UserComputerWithoutManaged {

}


+ (NSString *)userComputerIdFromUserId:(NSString *)userId computerId:(NSNumber *)computerId {
    NSString *userComputerId = [NSString stringWithFormat:@"%@%@%lld", userId, USER_COMPUTER_DELIMITERS, [computerId longLongValue]];

    return userComputerId;
}

- (id)initWithUserId:(NSString *)userId
      userComputerId:(NSString *)userComputerId
          computerId:(NSNumber *)computerId
     computerAdminId:(NSString *)computerAdminId
       computerGroup:(NSString *)computerGroup
        computerName:(NSString *)computerName
          showHidden:(NSNumber *)showHidden {
    if (self = [super init]) {
        _userId = userId;
        _userComputerId = userComputerId;
        _computerId = computerId;
        _computerAdminId = computerAdminId;
        _computerGroup = computerGroup;
        _computerName = computerName;
        _showHidden = showHidden;
    }

    return self;
}

- (instancetype)initWithUserId:(NSString *)userId
                userComputerId:(NSString *)userComputerId
                    computerId:(NSNumber *)computerId
               computerAdminId:(NSString *)computerAdminId
                 computerGroup:(NSString *)computerGroup
                  computerName:(NSString *)computerName
                    showHidden:(NSNumber *)showHidden
               uploadDirectory:(NSString *)uploadDirectory
        uploadSubdirectoryType:(NSNumber *)uploadSubdirectoryType
       uploadSubdirectoryValue:(NSString *)uploadSubdirectoryValue
         uploadDescriptionType:(NSNumber *)uploadDescriptionType
        uploadDescriptionValue:(NSString *)uploadDescriptionValue
        uploadNotificationType:(NSNumber *)uploadNotificationType
             downloadDirectory:(NSString *)downloadDirectory
      downloadSubdirectoryType:(NSNumber *)downloadSubdirectoryType
     downloadSubdirectoryValue:(NSString *)downloadSubdirectoryValue
       downloadDescriptionType:(NSNumber *)downloadDescriptionType
      downloadDescriptionValue:(NSString *)downloadDescriptionValue
      downloadNotificationType:(NSNumber *)downloadNotificationType {
    if (self = [super init]) {
        _userId = userId;
        _userComputerId = userComputerId;
        _computerId = computerId;
        _computerAdminId = computerAdminId;
        _computerGroup = computerGroup;
        _computerName = computerName;
        _showHidden = showHidden;

        _uploadDirectory = uploadDirectory;
        _uploadSubdirectoryType = uploadSubdirectoryType;
        _uploadSubdirectoryValue = uploadSubdirectoryValue;
        _uploadDescriptionType = uploadDescriptionType;
        _uploadDescriptionValue = uploadDescriptionValue;
        _uploadNotificationType = uploadNotificationType;

        _downloadDirectory = downloadDirectory;
        _downloadSubdirectoryType = downloadSubdirectoryType;
        _downloadSubdirectoryValue = downloadSubdirectoryValue;
        _downloadDescriptionType = downloadDescriptionType;
        _downloadDescriptionValue = downloadDescriptionValue;
        _downloadNotificationType = downloadNotificationType;
    }

    return self;
}

- (NSString *)description {
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];
    [description appendFormat:@"self.userComputerId=%@", self.userComputerId];
    [description appendFormat:@", self.computerId=%@", self.computerId];
    [description appendFormat:@", self.computerAdminId=%@", self.computerAdminId];
    [description appendFormat:@", self.computerGroup=%@", self.computerGroup];
    [description appendFormat:@", self.computerName=%@", self.computerName];
    [description appendFormat:@", self.showHidden=%@", self.showHidden];
    [description appendFormat:@", self.userId=%@", self.userId];
    [description appendFormat:@", self.downloadDirectory=%@", self.downloadDirectory];
    [description appendFormat:@", self.downloadSubdirectoryType=%@", self.downloadSubdirectoryType];
    [description appendFormat:@", self.downloadSubdirectoryValue=%@", self.downloadSubdirectoryValue];
    [description appendFormat:@", self.downloadDescriptionType=%@", self.downloadDescriptionType];
    [description appendFormat:@", self.downloadDescriptionValue=%@", self.downloadDescriptionValue];
    [description appendFormat:@", self.downloadNotificationType=%@", self.downloadNotificationType];
    [description appendFormat:@", self.uploadDirectory=%@", self.uploadDirectory];
    [description appendFormat:@", self.uploadSubdirectoryType=%@", self.uploadSubdirectoryType];
    [description appendFormat:@", self.uploadSubdirectoryValue=%@", self.uploadSubdirectoryValue];
    [description appendFormat:@", self.uploadDescriptionType=%@", self.uploadDescriptionType];
    [description appendFormat:@", self.uploadDescriptionValue=%@", self.uploadDescriptionValue];
    [description appendFormat:@", self.uploadNotificationType=%@", self.uploadNotificationType];
    [description appendString:@">"];
    return description;
}

- (id)copyWithZone:(NSZone *)zone {
    UserComputerWithoutManaged *copy = (UserComputerWithoutManaged *) [[[self class] allocWithZone:zone] init];

    if (copy != nil) {
        copy.userComputerId = self.userComputerId;
        copy.computerId = self.computerId;
        copy.computerAdminId = self.computerAdminId;
        copy.computerGroup = self.computerGroup;
        copy.computerName = self.computerName;
        copy.showHidden = self.showHidden;
        copy.userId = self.userId;
        copy.uploadDirectory = self.uploadDirectory;
        copy.uploadSubdirectoryType = self.uploadSubdirectoryType;
        copy.uploadSubdirectoryValue = self.uploadSubdirectoryValue;
        copy.uploadDescriptionType = self.uploadDescriptionType;
        copy.uploadDescriptionValue = self.uploadDescriptionValue;
        copy.uploadNotificationType = self.uploadNotificationType;
        copy.downloadDirectory = self.downloadDirectory;
        copy.downloadSubdirectoryType = self.downloadSubdirectoryType;
        copy.downloadSubdirectoryValue = self.downloadSubdirectoryValue;
        copy.downloadDescriptionType = self.downloadDescriptionType;
        copy.downloadDescriptionValue = self.downloadDescriptionValue;
        copy.downloadNotificationType = self.downloadNotificationType;
    }

    return copy;
}


@end