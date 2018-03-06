#import <MobileCoreServices/MobileCoreServices.h>
#import "EnterShareViewController.h"
#import "ShareViewController.h"
#import "UploadItem.h"
#import "ShareUtility.h"

@interface EnterShareViewController ()

@property(nonatomic, strong) PreferredContentSizeCategoryService *preferredContentSizeCategoryService;

@end

@implementation EnterShareViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    _preferredContentSizeCategoryService = [[PreferredContentSizeCategoryService alloc] init];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangePreferredContentSize:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];

    // test if user exists
    NSUserDefaults *userDefaults = [Utility groupUserDefaults];

    NSString *userId = [userDefaults stringForKey:USER_DEFAULTS_KEY_USER_ID];

    if (!userId) {
        // prompt to connect first

        [Utility alertInExtensionEmptyUserSessionFromViewController:self completion:^{
            NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];

            errorDetail[NSLocalizedDescriptionKey] = NSLocalizedString(@"User canceled.", @"");

            NSError *error = [NSError errorWithDomain:APP_GROUP_NAME code:-1 userInfo:errorDetail];

            [self.extensionContext cancelRequestWithError:error];
        }];
    } else {
        // Elements of type of UploadItem
        NSMutableArray *uploadItems = [NSMutableArray array];

        NSArray *extensionItems = self.extensionContext.inputItems;

        for (NSExtensionItem *extensionItem in extensionItems) {
//        // DEBUG
//        NSLog(@"NSExtensionItem.attributedTitle:\n%@", extensionItem.attributedTitle);
//        NSLog(@"NSExtensionItem.attributedContentText:\n%@", extensionItem.attributedContentText);
//        NSLog(@"NSExtensionItem.userInfo:\n%@", [extensionItem userInfo]);

            NSArray *attachments = extensionItem.attachments;

            for (NSItemProvider *itemProvider in attachments) {
                NSArray *itemProviderRegisteredTypeIdentifiers = [itemProvider registeredTypeIdentifiers];

                if (itemProviderRegisteredTypeIdentifiers && [itemProviderRegisteredTypeIdentifiers count] > 0) {
                    // DEBUG
//                    NSLog(@"NSItemProvider.registeredTypeIdentifiers:\n%@", [itemProviderRegisteredTypeIdentifiers description]);
//
//                    NSLog(@"Use the type identifier: %@", itemProviderRegisteredTypeIdentifiers[0]);

                    [itemProvider loadItemForTypeIdentifier:itemProviderRegisteredTypeIdentifiers[0] options:nil completionHandler:^(id <NSSecureCoding> itemId, NSError *error) {
                        UploadItem *uploadItem = [[UploadItem alloc] init];

                        uploadItem.utcoreType = itemProviderRegisteredTypeIdentifiers[0];

                        NSObject *item = (NSObject *) itemId;

                        if (item) {
                            if ([item isKindOfClass:[NSURL class]]) {
                                // make sure it's a file url

                                NSURL *itemURL = (NSURL *) item;

                                if ([itemURL isFileURL]) {
                                    NSLog(@"Item is File NSURL");

                                    uploadItem.url = itemURL;

                                    NSString *lastPathComponent = [itemURL lastPathComponent];

                                    if (lastPathComponent) {
                                        NSString *extension = [lastPathComponent pathExtension];

                                        if (extension && extension.length > 0) {
                                            uploadItem.fileExtension = extension;
                                        }
                                    }
                                }

                                // Non-File URL will be processed by 'Copy to Filelug', which is handled by
                                // [ApplicationDelegate application: openURL: sourceApplication: annotation:]
//                            else {
//                                NSLog(@"Item is Non-File NSURL");
//
//                                // save the url to a file
//
//                                if ([itemProvider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeURL]) {
//                                    uploadItem.utcoreType = (NSString *)kUTTypeURL;
//                                }
//
//                                NSString *urlString = [itemURL absoluteString];
//
//                                uploadItem.data = [urlString dataUsingEncoding:NSUTF8StringEncoding];
//
//                                uploadItem.fileExtension = @"txt";
//                            }
                            } else if ([item isKindOfClass:[UIImage class]]) {
                                NSLog(@"Item is UIImage");

                                NSData *itemData = UIImagePNGRepresentation((UIImage *) item);

                                if (itemData) {
                                    uploadItem.data = itemData;
                                    uploadItem.fileExtension = @"png";
                                } else {
                                    itemData = UIImageJPEGRepresentation((UIImage *) item, 1.0);

                                    if (itemData) {
                                        uploadItem.data = itemData;
                                        uploadItem.fileExtension = @"jpg";
                                    }
                                }

                                if (!itemData) {
                                    NSLog(@"Error on converting UIImage to data: %@", (UIImage *) item);
                                }
                            } else if ([item isKindOfClass:[NSString class]]) {
                                NSLog(@"Item is NSString");

                                if ([itemProvider hasItemConformingToTypeIdentifier:(NSString *) kUTTypeText]) {
                                    /*
                                     *  kUTTypeText;
                                     *  kUTTypePlainText;
                                     *  kUTTypeUTF8PlainText;
                                     *  kUTTypeUTF16ExternalPlainText;
                                     *  kUTTypeUTF16PlainText;
                                     *  kUTTypeRTF;
                                     *  kUTTypeHTML;
                                     *  kUTTypeXML;
                                     *  kUTTypeSourceCode;
                                     *  kUTTypeCSource;
                                     *  kUTTypeObjectiveCSource;
                                     *  kUTTypeCPlusPlusSource;
                                     *  kUTTypeObjectiveCPlusPlusSource;
                                     *  kUTTypeCHeader;
                                     *  kUTTypeCPlusPlusHeader;
                                     *  kUTTypeJavaSource;
                                     */
                                    if ([itemProvider hasItemConformingToTypeIdentifier:(NSString *) kUTTypeHTML]) {
                                        uploadItem.fileExtension = @"html";
                                    } else if ([itemProvider hasItemConformingToTypeIdentifier:(NSString *) kUTTypeXML]) {
                                        uploadItem.fileExtension = @"xml";
                                    } else if ([itemProvider hasItemConformingToTypeIdentifier:(NSString *) kUTTypeRTF]) {
                                        uploadItem.fileExtension = @"rtf";
                                    } else {
                                        uploadItem.fileExtension = @"txt";
                                    }

                                    if ([itemProvider hasItemConformingToTypeIdentifier:(NSString *) kUTTypeUTF16ExternalPlainText]
                                            || [itemProvider hasItemConformingToTypeIdentifier:(NSString *) kUTTypeUTF8PlainText]) {
                                        uploadItem.data = [(NSString *) item dataUsingEncoding:NSUTF16StringEncoding];
                                    } else {
                                        uploadItem.data = [(NSString *) item dataUsingEncoding:NSUTF8StringEncoding];
                                    }
                                } else {
                                    uploadItem.data = [(NSString *) item dataUsingEncoding:NSUTF8StringEncoding];
                                }
                            } else if ([item isKindOfClass:[NSData class]]) {
                                NSLog(@"Item is NSData");

                                if ([itemProvider hasItemConformingToTypeIdentifier:(NSString *) kUTTypeVCard]) {
                                    uploadItem.fileExtension = @"vcf";
                                }

                                uploadItem.data = (NSData *) item;
                            } else {
                                NSLog(@"Unknow image class: %@", [item class]);
                            }

                            [uploadItems addObject:uploadItem];
                        } else {
                            if (error) {
                                NSLog(@"Error on loading image\n%@", [error userInfo]);
                            } else {
                                NSLog(@"Image item not exists.");
                            }
                        }

                        NSLog(@"Upload Item:\n%@", [uploadItem description]);
                    }];
                }
            }
        }

        // get notified when data saved to db and save the data to file so folder watcher can detect it.
        ClopuccinoCoreData *coreData = [ClopuccinoCoreData defaultCoreData];
        coreData.sendsUpdates = YES;

        ShareViewController *shareViewController = [ShareUtility instantiateViewControllerWithIdentifier:@"sh_share"];

        shareViewController.shareExtensionContext = self.extensionContext;

        shareViewController.extensionItems = extensionItems;

        shareViewController.inputItems = uploadItems;

        UINavigationController *shareNavigationController = [[UINavigationController alloc] initWithRootViewController:shareViewController];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentViewController:shareNavigationController animated:YES completion:nil];
        });
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];
}

- (void)didChangePreferredContentSize:(NSNotification *)notification {
    [self.preferredContentSizeCategoryService didChangePreferredContentSizeWithNotification:notification];
}

@end
