#import "FileUploadDetailViewController.h"

@interface FileUploadDetailViewController ()

@property(nonatomic, nonnull, strong) AssetFileDao *assetFileDao;

@property(nonatomic, nonnull, strong) UserComputerDao *userComputerDao;

@property(nonatomic, nonnull, strong) FileUploadGroupDao *fileUploadGroupDao;

@property(nonatomic, strong) NSFetchedResultsController *fetchedResultsController;

@property(nonatomic, strong) AssetFileWithoutManaged *__nonnull assetFileWithoutManaged;

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

@end

@implementation FileUploadDetailViewController

// To prevent warning:
// Auto property synthesis will not synthesize property 'previewController' declared in protocol 'FilePreviewControllerDelegate'
@synthesize previewController;

- (void)viewDidLoad {
    [super viewDidLoad];

    [Utility viewController:self useNavigationLargeTitles:NO];

    _preferredContentSizeCategoryService = [[PreferredContentSizeCategoryService alloc] init];

    [self.assetFileDao fetchedResultsController:self.fetchedResultsController performFetch:NULL];

    // refresh control
    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];

    [refresh setAttributedTitle:[[NSAttributedString alloc] initWithString:NSLocalizedString(@"Pull to refresh", @"")]];

    self.refreshControl = refresh;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // adding observers

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangePreferredContentSize:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];

    [self.refreshControl addTarget:self action:@selector(prepareData:) forControlEvents:UIControlEventValueChanged];

    [self reloadAssetFileWithReloadTableViewData:YES];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (self.refreshControl) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.refreshControl endRefreshing];
        });
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    // removing observers

    [self.refreshControl removeTarget:self action:@selector(prepareData:) forControlEvents:UIControlEventValueChanged];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)didChangePreferredContentSize:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (AssetFileDao *)assetFileDao {
    if (!_assetFileDao) {
        _assetFileDao = [[AssetFileDao alloc] init];
    }

    return _assetFileDao;
}

- (UserComputerDao *)userComputerDao {
    if (!_userComputerDao) {
        _userComputerDao = [[UserComputerDao alloc] init];
    }

    return _userComputerDao;
}

- (FileUploadGroupDao *)fileUploadGroupDao {
    if (!_fileUploadGroupDao) {
        _fileUploadGroupDao = [[FileUploadGroupDao alloc] init];
    }

    return _fileUploadGroupDao;
}

- (NSFetchedResultsController *)fetchedResultsController {
    if (!_fetchedResultsController) {
        _fetchedResultsController = [self.assetFileDao createFileUploadFetchedResultsControllerForTransferKey:_transferKey delegate:self];
    }

    return _fetchedResultsController;
}

- (void)reloadAssetFileWithReloadTableViewData:(BOOL)reloadTableViewData {
    [_assetFileDao findAssetFileForTransferKey:_transferKey completionHandler:^(AssetFileWithoutManaged *foundAssetFileWithoutManaged, NSError *findError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.refreshControl && [self.refreshControl isRefreshing]) {
                [self.refreshControl endRefreshing];
            }
        });

        if (foundAssetFileWithoutManaged) {
            _assetFileWithoutManaged = foundAssetFileWithoutManaged;

            if (reloadTableViewData) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.tableView reloadData];
                });
            }
        }
    }];
}

// reload table view after getting the latest AssetFileWithoutManaged
- (void)prepareData:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self reloadAssetFileWithReloadTableViewData:YES];
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat height;

    if (indexPath.section == 0 && indexPath.row == 1 && [self.preferredContentSizeCategoryService isLargeContentSizeCategory]) {
        height = 80;
    } else {
        height = 60;
    }

    return height;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *title;

    switch (section) {
        case 0:
            title = NSLocalizedString(@"Upload Information", @"");

            break;
        case 1:
            title = NSLocalizedString(@"Upload Group Information", @"");

            break;
        default:
            title = @"";
    }

    return title;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger count;

    switch (section) {
        case 0:
            count = 7;

            break;
        case 1:
            count = 3;

            break;
        default:
            count = 0;
    }

    return count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"FileUploadDetailCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];

    // configure the preferred font

    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    cell.textLabel.textColor = [UIColor darkTextColor];
    cell.textLabel.numberOfLines = 1;
    cell.textLabel.adjustsFontSizeToFitWidth = NO;
    cell.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    cell.detailTextLabel.textColor = [UIColor aquaColor];
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.adjustsFontSizeToFitWidth = NO;
    cell.detailTextLabel.lineBreakMode = NSLineBreakByCharWrapping;

    // Configure the cell
    [self configureCell:cell atIndexPath:indexPath];

    return cell;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    if (cell && indexPath) {
        NSInteger section = indexPath.section;
        NSInteger row = indexPath.row;

        if (_assetFileWithoutManaged) {
            if (section == 0) {
                if (row == 0) {
                    // computer name

                    [cell.textLabel setText:NSLocalizedString(@"Upload To Computer", @"")];

                    NSString *userComputerId = self.assetFileWithoutManaged.userComputerId;

                    if (userComputerId) {
                        UserComputerWithoutManaged *userComputerWithoutManaged = [self.userComputerDao findUserComputerForUserComputerId:userComputerId];

                        if (userComputerWithoutManaged) {
                            [cell.detailTextLabel setText:userComputerWithoutManaged.computerName];
                        }
                    }
                } else if (row == 1) {
                    // upload absolute full path

                    [cell.textLabel setText:NSLocalizedString(@"Upload Path", @"")];

                    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

                    NSString *separator = [userDefaults stringForKey:USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR];

                    NSString *fullPath;

                    if (separator) {
                        fullPath = [DirectoryService serverPathFromParent:_assetFileWithoutManaged.serverDirectory name:_assetFileWithoutManaged.serverFilename fileSeparator:separator];
                    } else {
                        fullPath = [_assetFileWithoutManaged.serverDirectory stringByAppendingPathComponent:_assetFileWithoutManaged.serverFilename];
                    }

                    [cell.detailTextLabel setText:fullPath];
                } else if (row == 2) {
                    // start timestamp - when earlier than 1970, set to empty

                    [cell.textLabel setText:NSLocalizedString(@"Start Upload Timestamp", @"")];

                    NSNumber *startTimestamp = _assetFileWithoutManaged.startTimestamp;

                    double timestamp1970 = NSTimeIntervalSince1970 * 1000;

                    if (startTimestamp && [startTimestamp doubleValue] > timestamp1970) {
                        NSString *dateString = [Utility dateStringFromJavaTimeMilliseconds:startTimestamp];

                        [cell.detailTextLabel setText:dateString];
                    } else {
                        [cell.detailTextLabel setText:@""];
                    }
                } else if (row == 3) {
                    // upload status

                    [cell.textLabel setText:NSLocalizedString(@"Upload Status", @"")];

                    NSString *detailTextLabelText = cell.detailTextLabel.text;
                    UIColor *detailTextLabelTextColor = cell.detailTextLabel.textColor;

                    [self.assetFileDao prepareUploadStatusWithAssetFileWithoutManaged:_assetFileWithoutManaged
                                                                  currentStatusString:detailTextLabelText
                                                                   currentStatusColor:detailTextLabelTextColor
                                                                    completionHandler:^(NSString *statusString, UIColor *statusColor) {
                                                                        [cell.detailTextLabel setTextColor:statusColor];
                                                                        [cell.detailTextLabel setText:statusString];
                                                                    }];
                } else if (row == 4) {
                    // end timestamp

                    [cell.textLabel setText:NSLocalizedString(@"End Upload Timestamp", @"")];

                    NSString *endTimeStampString;

                    NSString *uploadStatus = _assetFileWithoutManaged.status;

                    if ([uploadStatus isEqualToString:FILE_TRANSFER_STATUS_SUCCESS] || [uploadStatus isEqualToString:FILE_TRANSFER_STATUS_FAILED]) {
                        NSNumber *endTimestamp = _assetFileWithoutManaged.endTimestamp;

                        double timestamp1970 = NSTimeIntervalSince1970 * 1000;

                        if (endTimestamp && [endTimestamp doubleValue] > timestamp1970) {
                            endTimeStampString = [Utility dateStringFromJavaTimeMilliseconds:endTimestamp];
                        }
                    }

                    if (!endTimeStampString) {
                        endTimeStampString = @"";
                    }

                    [cell.detailTextLabel setText:endTimeStampString];
                } else if (row == 5) {
                    // file size

                    [cell.textLabel setText:NSLocalizedString(@"File Size", @"")];

                    NSNumber *fileSizeInBytes = _assetFileWithoutManaged.totalSize;

                    if (fileSizeInBytes) {
                        NSString *fileSizeString = [Utility byteCountToDisplaySize:[fileSizeInBytes longLongValue]];

                        [cell.detailTextLabel setText:fileSizeString];
                    } else {
                        [cell.detailTextLabel setText:@""];
                    }
                } else if (row == 6) {
                    // uploaded size

                    [cell.textLabel setText:NSLocalizedString(@"File Uploaded Size", @"")];

                    NSNumber *transferredSize = _assetFileWithoutManaged.transferredSize;

                    if (transferredSize) {
                        NSString *uploadedSizeString = [Utility byteCountToDisplaySize:[transferredSize longLongValue]];

                        [cell.detailTextLabel setText:uploadedSizeString];
                    } else {
                        [cell.detailTextLabel setText:@""];
                    }
                } else {
                    // unknown cell

                    [cell.textLabel setText:@""];
                    [cell.detailTextLabel setText:@""];
                }
            } else if (section == 1) {
                NSString *fileUploadGroupId = _assetFileWithoutManaged.fileUploadGroupId;

                if (row == 0) {
                    // subfolder

                    [cell.textLabel setText:NSLocalizedString(@"Subdirectory Name", @"")];
                } else if (row == 1) {
                    // description

                    [cell.textLabel setText:NSLocalizedString(@"Description", @"")];
                } else if (row == 2) {
                    // notification

                    [cell.textLabel setText:NSLocalizedString(@"Upload Notification", @"")];
                } else {
                    // unknown cell

                    [cell.textLabel setText:@""];
                    [cell.detailTextLabel setText:@""];
                }

                if (fileUploadGroupId) {
                    [self.fileUploadGroupDao findFileUploadGroupByUploadGroupId:fileUploadGroupId completionHandler:^(FileUploadGroup *fileUploadGroup) {
                        if (fileUploadGroup) {
                            if (row == 0) {
                                // subfolder

                                NSString *displayValue;

                                NSNumber *subdirectoryType = fileUploadGroup.subdirectoryType;

                                NSString *subdirectoryValue = fileUploadGroup.subdirectoryName;

                                if (subdirectoryType) {
                                    UploadSubdirectoryService *uploadSubdirectoryService = [[UploadSubdirectoryService alloc] initWithUploadSubdirectoryType:subdirectoryType uploadSubdirectoryValue:subdirectoryValue];

                                    displayValue = [uploadSubdirectoryService displayedText];
                                }

                                if (!displayValue) {
                                    displayValue = NSLocalizedString(@"(Not Set2)", @"");
                                }

                                [cell.detailTextLabel setText:displayValue];
                            } else if (row == 1) {
                                // description

                                NSString *displayValue;

                                NSNumber *descriptionType = fileUploadGroup.descriptionType;

                                NSString *descriptionValue = fileUploadGroup.descriptionValue;

                                if (descriptionType) {
                                    UploadDescriptionService *uploadDescriptionService = [[UploadDescriptionService alloc] initWithUploadDescriptionType:descriptionType uploadDescriptionValue:descriptionValue];

                                    displayValue = [uploadDescriptionService displayedText];
                                }

                                if (!displayValue) {
                                    displayValue = NSLocalizedString(@"(Not Set2)", @"");
                                }

                                [cell.detailTextLabel setText:displayValue];
                            } else if (row == 2) {
                                // notification

                                NSString *displayValue;

                                NSNumber *notificationType = fileUploadGroup.notificationType;

                                if (notificationType) {
                                    displayValue = [UploadNotificationService uploadNotificationNameWithUploadNotificationType:notificationType];
                                }

                                if (!displayValue) {
                                    displayValue = NSLocalizedString(@"(Not Set2)", @"");
                                }

                                [cell.detailTextLabel setText:displayValue];
                            } else {
                                // unknown cell

                                [cell.detailTextLabel setText:@""];
                            }
                        } else {
                            [cell.textLabel setText:NSLocalizedString(@"(Not Set2)", @"")];
                        }
                    }];
                } else {
                    [cell.textLabel setText:NSLocalizedString(@"(Not Set2)", @"")];
                }
            }
        }
    }
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self prepareData:nil];
}

@end
