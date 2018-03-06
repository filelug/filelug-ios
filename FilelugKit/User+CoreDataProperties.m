//
//  User+CoreDataProperties.m
//  filelug
//
//  Created by masonhsieh on 28/04/2017.
//
//

#import "User+CoreDataProperties.h"

@implementation User (CoreDataProperties)

+ (NSFetchRequest<User *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"User"];
}

@dynamic active;
@dynamic countryId;
@dynamic email;
@dynamic nickname;
@dynamic phoneNumber;
@dynamic sessionId;
@dynamic userId;
@dynamic purchases;
@dynamic userComputers;

@end
