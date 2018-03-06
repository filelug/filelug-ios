#import <Foundation/Foundation.h>


@interface UserComputerWithoutManaged : NSObject <NSCopying>

@property(nonatomic, strong) NSString *userComputerId;
@property(nonatomic, strong) NSNumber *computerId;
@property(nonatomic, strong) NSString *computerAdminId;
@property(nonatomic, strong) NSString *computerGroup;
@property(nonatomic, strong) NSString *computerName;
@property(nonatomic, strong) NSNumber *showHidden;
@property(nonatomic, strong) NSString *userId;

// Upload Summary

@property (nonatomic, retain) NSString *uploadDirectory;
@property (nonatomic, retain) NSNumber *uploadSubdirectoryType;
@property (nonatomic, retain) NSString *uploadSubdirectoryValue;
@property (nonatomic, retain) NSNumber *uploadDescriptionType;
@property (nonatomic, retain) NSString *uploadDescriptionValue;
@property (nonatomic, retain) NSNumber *uploadNotificationType;

// Download Summary

@property (nonatomic, retain) NSString *downloadDirectory;
@property (nonatomic, retain) NSNumber *downloadSubdirectoryType;
@property (nonatomic, retain) NSString *downloadSubdirectoryValue;
@property (nonatomic, retain) NSNumber *downloadDescriptionType;
@property (nonatomic, retain) NSString *downloadDescriptionValue;
@property (nonatomic, retain) NSNumber *downloadNotificationType;

+ (NSString *)userComputerIdFromUserId:(NSString *)userId computerId:(NSNumber *)computerId;

- (id)initWithUserId:(NSString *)userId
      userComputerId:(NSString *)userComputerId
          computerId:(NSNumber *)computerId
     computerAdminId:(NSString *)computerAdminId
       computerGroup:(NSString *)computerGroup
        computerName:(NSString *)computerName
          showHidden:(NSNumber *)showHidden;

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
      downloadNotificationType:(NSNumber *)downloadNotificationType;

- (NSString *)description;

- (id)copyWithZone:(NSZone *)zone;



@end