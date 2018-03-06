#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface FileInfoViewController : UITableViewController <ProcessableViewController>

// server path
@property(nonatomic, strong) NSString *filePath;

// real server path, usually get the value from either:
// 1. [DirectoryService serverPathFromParent: name:]
// 2. FileTransfer.realServerPath
@property(nonatomic, strong) NSString *realFilePath;

@property(nonatomic, strong) NSString *filename;

@property(nonatomic, strong) NSString *fileParent;

@property(nonatomic, strong) NSString *fileSize;

@property(nonatomic, strong) NSString *fileMimetype;

@property(nonatomic, strong) NSString *fileLastModifiedDate;

@property(nonatomic, strong) NSString *fileReadable;

@property(nonatomic, strong) NSString *fileWritable;

@property(nonatomic, strong) NSString *fileExecutable;

@property(nonatomic, strong) NSString *fileHidden;

@property(nonatomic, strong) NSString *openFile;

// Optional, can be nil on viewDidLoad:
@property(nonatomic, strong) HierarchicalModelWithoutManaged *hierarchicalModel;

@property(nonatomic, strong) UIViewController *fromViewController;

@end
