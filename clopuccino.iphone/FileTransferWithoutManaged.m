#import "FileTransferWithoutManaged.h"


@implementation FileTransferWithoutManaged {

}


+ (NSString *)prepareActionsAfterDownloadWithOpen:(BOOL)open share:(BOOL)share {
    return [NSString stringWithFormat:@"%@%@%@", (open ? YES_ACTION : NO_ACTION), SEPARATOR_ACTIONS_AFTER_DOWNLOADS, (share ? YES_ACTION : NO_ACTION)];
}

+ (NSString *)actionsAfterDownloadFromActionArray:(NSArray *)actionArray {
    NSMutableArray *actions = [FileTransferWithoutManaged prepareActionArrayWithInitialValues];

    NSUInteger initActionCount = [actions count];
    NSUInteger count = [actionArray count];
    if (actionArray && count > 0) {
        for (NSUInteger index = 0; (index < count && index < initActionCount) ; index++) {
            actions[index] = actionArray[index];
        }
    }

    NSMutableString *mutableString = [NSMutableString string];
    for (NSUInteger index = 0; index < initActionCount; index++) {
        [mutableString appendFormat:@"%@%@", actions[index], SEPARATOR_ACTIONS_AFTER_DOWNLOADS];
    }

    // delete the last extra separator
    NSUInteger indexTo = [mutableString length] - 1;

    return [mutableString substringToIndex:indexTo];
}

// Elements of NSString either YES_ACTION or NO_ACTION
+ (NSMutableArray *)prepareActionArrayWithInitialValues {
    NSMutableArray *actions = [NSMutableArray array];

    for (int index = 0; index < NUMBER_OF_ACTIONS_AFTER_DOWNLOADS; index++) {
        [actions addObject:NO_ACTION];
    }

    return actions;
}

// Elements of NSString of either YES_ACTION or NO_ACTION
+ (NSMutableArray *)actionArrayFromActionsAfterDownload:(NSString *)actionsAfterDownload {
    if (actionsAfterDownload && [actionsAfterDownload length] > 0) {
        return [[actionsAfterDownload componentsSeparatedByString:SEPARATOR_ACTIONS_AFTER_DOWNLOADS] mutableCopy];
    } else {
        return [FileTransferWithoutManaged prepareActionArrayWithInitialValues];
    }

//    NSMutableArray *actions = [FileTransferWithoutManaged prepareActionArrayWithInitialValues];
//
//    if (actionsAfterDownload && [actionsAfterDownload length] > 0) {
//        NSArray *actionStrings = [actionsAfterDownload componentsSeparatedByString:SEPARATOR_ACTIONS_AFTER_DOWNLOADS];
//
//        NSUInteger count = [actionStrings count];
//
//        for (NSUInteger index = 0; index < count; index++) {
//            actions[index] = [actionStrings[index] boolValue] ? @YES : @NO;
//        }
//    }
//
//    return actions;
}

+ (BOOL)openInActionsAfterDownload:(NSString *_Nullable)actionsAfterDownload {
    if (actionsAfterDownload && [actionsAfterDownload length] > 0) {
        NSArray *actionStrings = [actionsAfterDownload componentsSeparatedByString:SEPARATOR_ACTIONS_AFTER_DOWNLOADS];

        return [actionStrings[0] isEqualToString:YES_ACTION];
    } else {
        return NO;
    }
}

+ (BOOL)shareInActionsAfterDownload:(NSString *_Nullable)actionsAfterDownload {
    if (actionsAfterDownload && [actionsAfterDownload length] > 0) {
        NSArray *actionStrings = [actionsAfterDownload componentsSeparatedByString:SEPARATOR_ACTIONS_AFTER_DOWNLOADS];

        if ([actionStrings count] > 1) {
            return [actionStrings[1] isEqualToString:YES_ACTION];
        } else {
            return NO;
        }
    } else {
        return NO;
    }
}

- (id)initWithUserComputerId:(NSString *)userComputerId
             downloadGroupId:(NSString *)downloadGroupId
                  serverPath:(NSString *)serverPath
              realServerPath:(NSString *)realServerPath
                   localPath:(NSString *_Nullable)localPath
                 contentType:(NSString *_Nullable)contentType
                 displaySize:(NSString *_Nullable)displaySize
                        type:(NSString *_Nullable)type
                lastModified:(NSString *_Nullable)lastModified
                      status:(NSString *_Nullable)status
                   totalSize:(NSNumber *_Nullable)totalSize
             transferredSize:(NSNumber *_Nullable)transferredSize
              startTimestamp:(NSNumber *_Nullable)startTimestamp
                endTimestamp:(NSNumber *_Nullable)endTimestamp
        actionsAfterDownload:(NSString *_Nullable)actionsAfterDownload
                 transferKey:(NSString *_Nullable)transferKey
                      hidden:(NSNumber *_Nullable)hidden
               waitToConfirm:(NSNumber *_Nullable)waitToConfirm {
    if (self = [super init]) {
        _userComputerId = userComputerId;
        _downloadGroupId = downloadGroupId;
        _serverPath = serverPath;
        _realServerPath = realServerPath;
        _localPath = localPath;
        _contentType = contentType;
        _displaySize = displaySize;
        _type = type;
        _lastModified = lastModified;
        _status = status;
        _totalSize = totalSize;
        _transferredSize = transferredSize;
        _startTimestamp = startTimestamp;
        _endTimestamp = endTimestamp;
        _actionsAfterDownload = actionsAfterDownload;
        _transferKey = transferKey;
        _hidden = hidden;
        _waitToConfirm = waitToConfirm;
    }

    return self;
}

//- (id)initWithUserComputerId:(NSString *)userComputerId serverPath:(NSString *)serverPath realServerPath:(NSString *)realServerPath localPath:(NSString *)localPath contentType:(NSString *)contentType displaySize:(NSString *)displaySize type:(NSString *)type lastModified:(NSString *)lastModified status:(NSString *)status totalSize:(NSNumber *)totalSize transferredSize:(NSNumber *)transferredSize startTimestamp:(NSNumber *)startTimestamp endTimestamp:(NSNumber *)endTimestamp actionsAfterDownload:(NSString *)actionsAfterDownload transferKey:(NSString *)transferKey hidden:(NSNumber *)hidden waitToConfirm:(NSNumber *)waitToConfirm {
//    if (self = [super init]) {
//        _userComputerId = userComputerId;
//        _serverPath = serverPath;
//        _realServerPath = realServerPath;
//        _localPath = localPath;
//        _contentType = contentType;
//        _displaySize = displaySize;
//        _type = type;
//        _lastModified = lastModified;
//        _status = status;
//        _totalSize = totalSize;
//        _transferredSize = transferredSize;
//        _startTimestamp = startTimestamp;
//        _endTimestamp = endTimestamp;
//        _actionsAfterDownload = actionsAfterDownload;
//        _transferKey = transferKey;
//        _hidden = hidden;
//        _waitToConfirm = waitToConfirm;
//    }
//
//    return self;
//}

- (NSString *)description {
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];
    [description appendFormat:@"self.userComputerId=%@", self.userComputerId];
    [description appendFormat:@"self.downloadGroupId=%@", self.downloadGroupId];
    [description appendFormat:@", self.serverPath=%@", self.serverPath];
    [description appendFormat:@", self.realServerPath=%@", self.realServerPath];
    [description appendFormat:@", self.localPath=%@", self.localPath];
    [description appendFormat:@", self.contentType=%@", self.contentType];
    [description appendFormat:@", self.displaySize=%@", self.displaySize];
    [description appendFormat:@", self.type=%@", self.type];
    [description appendFormat:@", self.lastModified=%@", self.lastModified];
    [description appendFormat:@", self.status=%@", self.status];
    [description appendFormat:@", self.totalSize=%@", self.totalSize];
    [description appendFormat:@", self.transferredSize=%@", self.transferredSize];
    [description appendFormat:@", self.startTimestamp=%@", self.startTimestamp];
    [description appendFormat:@", self.endTimestamp=%@", self.endTimestamp];
    [description appendFormat:@", self.actionsAfterDownload=%@", self.actionsAfterDownload];
    [description appendFormat:@", self.transferKey=%@", self.transferKey];
    [description appendFormat:@", self.waitToConfirm=%@", self.waitToConfirm];
    [description appendString:@">"];
    return description;
}

- (NSArray *)actionArrayAfterDownload {
    return [FileTransferWithoutManaged actionArrayFromActionsAfterDownload:_actionsAfterDownload];
}

- (NSUInteger)countActionsAfterDownload {
    if (_actionsAfterDownload) {
        return [[_actionsAfterDownload componentsSeparatedByString:SEPARATOR_ACTIONS_AFTER_DOWNLOADS] count];
    } else {
        return 0;
    }
}

- (BOOL)openAfterDownload {
    return [FileTransferWithoutManaged openInActionsAfterDownload:_actionsAfterDownload];
}

- (BOOL)shareAfterDownload {
    return [FileTransferWithoutManaged shareInActionsAfterDownload:_actionsAfterDownload];
}

- (id)copyWithZone:(nullable NSZone *)zone {
    FileTransferWithoutManaged *copy = (FileTransferWithoutManaged *) [[[self class] allocWithZone:zone] init];

    if (copy != nil) {
        copy.userComputerId = self.userComputerId;
        copy.downloadGroupId = self.downloadGroupId;
        copy.serverPath = self.serverPath;
        copy.realServerPath = self.realServerPath;
        copy.localPath = self.localPath;
        copy.contentType = self.contentType;
        copy.displaySize = self.displaySize;
        copy.type = self.type;
        copy.lastModified = self.lastModified;
        copy.status = self.status;
        copy.totalSize = self.totalSize;
        copy.transferredSize = self.transferredSize;
        copy.startTimestamp = self.startTimestamp;
        copy.endTimestamp = self.endTimestamp;
        copy.actionsAfterDownload = self.actionsAfterDownload;
        copy.transferKey = self.transferKey;
        copy.hidden = self.hidden;
        copy.waitToConfirm = self.waitToConfirm;
    }

    return copy;
}


@end
