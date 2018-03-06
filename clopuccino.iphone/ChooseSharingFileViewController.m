#import "ChooseSharingFileViewController.h"
#import "UIButton+UploadBadgeBarButton.h"
#import "FileUploadProcessService.h"
#import "FilelugUtility.h"
#import "AppDelegate.h"

@interface ChooseSharingFileViewController ()

// the root path of the sharing directory
@property(nonatomic, strong) NSString *sharingDirectoryPath;

// elements of two mutable arrays, the first contains the name of the directories,
// and the second contains the name of the files
@property(nonatomic, strong) NSArray <NSMutableArray *> *directoriesAndFiles;

@property(nonatomic, strong) UIButton *uploadBadgeBarButton;

@property(nonatomic, strong) BBBadgeBarButtonItem *doneButtonItem;

@property(nonatomic, strong) FileUploadProcessService *uploadProcessService;

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

@property(nonatomic, strong) NSNumber *reloading;

@end

@implementation ChooseSharingFileViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.reloading = @NO;

    [Utility viewController:self useNavigationLargeTitles:YES];

    _uploadProcessService = [[FilelugUtility applicationDelegate] fileUploadProcessService];

    _preferredContentSizeCategoryService = [[PreferredContentSizeCategoryService alloc] init];
    
    [self navigationItem].title = NSLocalizedString(@"Select one to upload", @"");
    
    // refresh control
    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    
    [refresh setAttributedTitle:[[NSAttributedString alloc] initWithString:NSLocalizedString(@"Pull to refresh", @"")]];

    self.refreshControl = refresh;

    // upload badge

    _uploadBadgeBarButton = [UIButton uploadBadgeBarButton];

    BBBadgeBarButtonItem *badgeBarButtonItem = [[BBBadgeBarButtonItem alloc] initWithUploadBadgeBarButton:_uploadBadgeBarButton];

    self.doneButtonItem = badgeBarButtonItem;
    
    self.navigationItem.rightBarButtonItem = self.doneButtonItem;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // always update badge and table no matter if go back or not
    
    [self.uploadProcessService updateBadgeBarButtonItem:self.doneButtonItem];

    // adding observers

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangePreferredContentSize:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];

    [self.uploadBadgeBarButton addTarget:self action:@selector(doneSelection:) forControlEvents:UIControlEventTouchUpInside];

    [self addObserver:self forKeyPath:NSStringFromSelector(@selector(reloading)) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];

    [self.refreshControl addTarget:self action:@selector(prepareSubDirectoriesAndFiles) forControlEvents:UIControlEventValueChanged];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.refreshControl) {
            [self.refreshControl endRefreshing];
        }
    });

    [self prepareSubDirectoriesAndFiles];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    // removing observers

    [self.refreshControl removeTarget:self action:@selector(prepareSubDirectoriesAndFiles) forControlEvents:UIControlEventValueChanged];

    [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(reloading)) context:NULL];

    [self.uploadBadgeBarButton removeTarget:self action:@selector(doneSelection:) forControlEvents:UIControlEventTouchUpInside];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];

    if (_directoriesAndFiles && [_directoriesAndFiles count] == 2) {
        NSMutableArray *directories = _directoriesAndFiles[0];

        if (directories) {
            [directories removeAllObjects];
        }

        NSMutableArray *files = _directoriesAndFiles[1];

        if (files) {
            [files removeAllObjects];
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - NSKeyValueObserving

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(reloading))]) {
        NSNumber *newValue = change[NSKeyValueChangeNewKey];
        NSNumber *oldValue = change[NSKeyValueChangeOldKey];

        if (![newValue isEqualToNumber:oldValue]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (![newValue boolValue]) {
                    if (self.refreshControl) {
                        [self.refreshControl endRefreshing];
                    }
                }
            });
        }
    }
}

- (void)didChangePreferredContentSize:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (void)prepareSubDirectoriesAndFiles {
    self.reloading = @YES;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *directoryPath;
        
        BOOL shouldFilter = NO;
        
        if (self.parentRelPath && [self.parentRelPath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
            directoryPath = [self.sharingDirectoryPath stringByAppendingPathComponent:self.parentRelPath];
        } else {
            directoryPath = self.sharingDirectoryPath;
            
            // filter out hidden directories used by filelug in the root directory for file-sharing
            shouldFilter = YES;
        }
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        NSError *findError;
        NSArray *subDirectoriesAndFileNames = [fileManager contentsOfDirectoryAtPath:directoryPath error:&findError];
        
        if (findError) {
            self.reloading = @NO;
            
            NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Error on finding directories and files.%1$@", @""), [findError localizedDescription]];
            
            [Utility viewController:self alertWithMessageTitle:@"" messageBody:message actionTitle:NSLocalizedString(@"OK", @"") delayInSeconds:0 actionHandler:nil];
            
            NSLog(@"Error on finding directories and files.\n%@", [findError userInfo]);
        } else {
            NSArray *filteredChildren;
            
            if (shouldFilter) {
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"NOT SELF IN %@", @[EXTENSION_FILE_DIRECTORY_NAME, EXTERNAL_FILE_DIRECTORY_NAME, SETTINGS_FILE_DIRECTORY_NAME]];
                
                filteredChildren = [subDirectoriesAndFileNames filteredArrayUsingPredicate:predicate];
            } else {
                filteredChildren = subDirectoriesAndFileNames;
            }

            NSMutableArray *directories = [NSMutableArray array];
            NSMutableArray *files = [NSMutableArray array];

            if (filteredChildren && [filteredChildren count] > 0) {
                
                NSError *attrError;
                for (NSString *name in filteredChildren) {
                    NSString *fullPath = [directoryPath stringByAppendingPathComponent:name];
                    
                    attrError = nil;
                    NSDictionary *attributes = [fileManager attributesOfItemAtPath:fullPath error:&attrError];
                    
                    if (!attrError) {
                        NSString *fileType = attributes[NSFileType];
                        
                        if (fileType) {
                            if ([fileType isEqualToString:NSFileTypeDirectory]) {
                                [directories addObject:name];
                            } else {
                                [files addObject:name];
                            }
                        }
                    } else {
                        NSLog(@"Error on finding attributes of file path: %@.\n%@", fullPath, [attrError userInfo]);
                    }
                }
            }

            self.directoriesAndFiles = nil;
            self.directoriesAndFiles = @[directories, files];

            self.reloading = @NO;

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
        }
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.directoriesAndFiles count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *title;
    
    if (section == 0) {
        if (self.directoriesAndFiles[0] && [self.directoriesAndFiles[0] count] > 0) {
            title = NSLocalizedString(@"directory", @"");
        } else {
            title = @"";
        }
    } else {
        if (self.directoriesAndFiles[1] && [self.directoriesAndFiles[1] count] > 0) {
            title = NSLocalizedString(@"file", @"");
        } else {
            title = @"";
        }
    }
    
    return title;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.directoriesAndFiles[(NSUInteger) section] count];
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return TABLE_VIEW_CELL_ROW_HEIGHT_FOR_MEDIUM_CONTENT_SIZE_CATEGORY;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat height;

    if ([self.preferredContentSizeCategoryService isXXLargeContentSizeCategory]) {
        height = TABLE_VIEW_CELL_ROW_HEIGHT_FOR_XX_LARGE_CONTENT_SIZE_CATEGORY;
    } else if ([self.preferredContentSizeCategoryService isLargeContentSizeCategory]) {
        height = TABLE_VIEW_CELL_ROW_HEIGHT_FOR_LARGE_CONTENT_SIZE_CATEGORY;
    } else if ([self.preferredContentSizeCategoryService isMediumContentSizeCategory]) {
        height = TABLE_VIEW_CELL_ROW_HEIGHT_FOR_MEDIUM_CONTENT_SIZE_CATEGORY;
    } else {
        height = TABLE_VIEW_CELL_ROW_HEIGHT_FOR_SMALL_CONTENT_SIZE_CATEGORY;
    }

    return height;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *DefaultCellIdentifier = @"ChooseSharingFileDefaultCell";
    static NSString *SubtitleCellIdentifier = @"ChooseSharingFileSubtitleCell";

    UITableViewCell *cell;

    if (indexPath.section == 0) {
        cell = [tableView dequeueReusableCellWithIdentifier:DefaultCellIdentifier forIndexPath:indexPath];
    } else {
        cell = [tableView dequeueReusableCellWithIdentifier:SubtitleCellIdentifier forIndexPath:indexPath];
    }

    NSString *fileOrDirectoryName = self.directoriesAndFiles[(NSUInteger) indexPath.section][(NSUInteger) indexPath.row];

    // configure the preferred font

    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    cell.textLabel.textColor = [UIColor darkTextColor];
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.adjustsFontSizeToFitWidth = NO;
    cell.textLabel.lineBreakMode = NSLineBreakByCharWrapping;
    cell.textLabel.textAlignment = NSTextAlignmentNatural;

    cell.textLabel.text = fileOrDirectoryName;
    
    NSString *fullPath = [self fileAbsolutePathWithFilename:fileOrDirectoryName];
    
    if (indexPath.section == 0) {
        cell.imageView.image = [DirectoryService imageForLocalFilePath:fullPath isDirectory:YES];
        
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    } else {
        // configure the preferred font

        cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
        cell.detailTextLabel.textColor = [UIColor lightGrayColor];
        cell.detailTextLabel.numberOfLines = 1;
        cell.detailTextLabel.adjustsFontSizeToFitWidth = NO;
        cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        cell.detailTextLabel.textAlignment = NSTextAlignmentNatural;

        // detail label text name

        NSString *displaySize;
        NSString *lastModifiedString;

        NSDictionary<NSString *, id> *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:NULL];

        if (fileAttributes) {
            unsigned long long fileSize = [fileAttributes fileSize];

            displaySize = [Utility byteCountToDisplaySize:fileSize];

            NSDate *lastModifiedDate = [fileAttributes fileModificationDate];

            if (lastModifiedDate) {
                lastModifiedString = [Utility dateStringFromDate:lastModifiedDate];
            }
        }

        NSString *detailLabelText;

        if (lastModifiedString) {
            detailLabelText = [NSString stringWithFormat:@"%@, %@", displaySize, lastModifiedString];
        } else {
            detailLabelText = [NSString stringWithFormat:@"%@", displaySize];
        }

        cell.detailTextLabel.text = detailLabelText;

        // detail label text image

        cell.imageView.image = [DirectoryService imageForLocalFilePath:fullPath isDirectory:NO];
        
//        if ([self.uploadProcessService.selectedFileRelPaths containsObject:[self fileRelPathWithFilename:fileOrDirectoryName]]) {
//            [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
//        } else {
//            [cell setAccessoryType:UITableViewCellAccessoryNone];
//        }
    }
        
    // To resolve the width of the detail text not correctly updated
    [cell layoutSubviews];
    
    return cell;
}

- (NSString *)fileRelPathWithFilename:(NSString *)filename {
    if (self.parentRelPath && [self.parentRelPath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
        return [self.parentRelPath stringByAppendingPathComponent:filename];
    } else {
        return filename;
    }
}

- (NSString *)fileAbsolutePathWithFilename:(NSString *)filename {
    if (self.parentRelPath && [self.parentRelPath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
        return [[self.sharingDirectoryPath stringByAppendingPathComponent:self.parentRelPath] stringByAppendingPathComponent:filename];
    } else {
        return [self.sharingDirectoryPath stringByAppendingPathComponent:filename];
    }
}

#pragma mark - UITableViewDelegate

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    return [self tableView:tableView beforeSelectRowAtIndexPath:indexPath];
}

- (NSIndexPath *)tableView:(UITableView *)tableView willDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    return [self tableView:tableView beforeSelectRowAtIndexPath:indexPath];
}

- (NSIndexPath *)tableView:(UITableView *)tableView beforeSelectRowAtIndexPath:(NSIndexPath *)indexPath {
//    if (indexPath.section != 0) {
//        NSString *selectedName = self.directoriesAndFiles[(NSUInteger) indexPath.section][(NSUInteger) indexPath.row];
//
//        NSString *fileRelPath = [self fileRelPathWithFilename:selectedName];
//
//        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
//
//        if (![self.uploadProcessService.selectedFileRelPaths containsObject:fileRelPath]) {
//            // select it
//
//            [self.uploadProcessService.selectedFileRelPaths addObject:fileRelPath];
//
//            if (cell) {
//                dispatch_async(dispatch_get_main_queue(), ^{
//                    [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
//
//                    // update badge
//
//                    [self.uploadProcessService updateBadgeBarButtonItem:self.doneButtonItem];
//                });
//            }
//        } else {
//            // deselect it
//
//            [self.uploadProcessService.selectedFileRelPaths removeObject:fileRelPath];
//
//            dispatch_async(dispatch_get_main_queue(), ^{
//                [cell setAccessoryType:UITableViewCellAccessoryNone];
//
//                // update badge
//
//                [self.uploadProcessService updateBadgeBarButtonItem:self.doneButtonItem];
//            });
//        }
//    }
    
    return indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *selectedFileOrDirectoryName = self.directoriesAndFiles[(NSUInteger) indexPath.section][(NSUInteger) indexPath.row];
    
    if (indexPath.section == 0) {
        // Deselect the row to prevent invoking 'tableView: willDeselectRowAtIndexPath:'
        // when pressing the same row after going back from child view controller.
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView deselectRowAtIndexPath:indexPath animated:NO];
        });
        
        ChooseSharingFileViewController *childViewController = [Utility instantiateViewControllerWithIdentifier:@"ChooseSharingFile"];
        
        childViewController.sharingDirectoryPath = self.sharingDirectoryPath;
        
        childViewController.parentRelPath = [self.parentRelPath stringByAppendingPathComponent:selectedFileOrDirectoryName];
        
        [self.navigationController pushViewController:childViewController animated:YES];
    }
}

- (void)doneSelection:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.uploadProcessService pushToUploadSummaryViewControllerFromViewController:self];
    });
}

@end
