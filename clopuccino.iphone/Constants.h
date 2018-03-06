#import <Foundation/Foundation.h>

#ifdef DEBUG
#   define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
#   define DLog(...)
#endif

// ALog always displays output regardless of the DEBUG setting
#define MLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)


@interface Constants : NSObject

// Preferences for app, set each time app launched, do not delete on data clearing

// value is type of NSNumber wrapping BOOL
//extern NSString *const USER_DEFAULTS_KEY_FIRST_TIME_IN_VERSION_1_4_0;

extern NSString *const USER_DEFAULTS_KEY_DOMAIN_URL_SCHEME;

extern NSString *const USER_DEFAULTS_KEY_DOMAIN_ZONE_NAME;

extern NSString *const USER_DEFAULTS_KEY_DOMAIN_NAME;

extern NSString *const USER_DEFAULTS_KEY_PORT;

extern NSString *const USER_DEFAULTS_KEY_CONTEXT_PATH;

extern NSString *const USER_DEFAULTS_KEY_REMOTE_NOTIFICATION_DEVICE_TOKEN;

extern NSString *const USER_DEFAULTS_KEY_MAIN_APP_VERSION;

extern NSString *const USER_DEFAULTS_KEY_MAIN_APP_BUILD_NO;

extern NSString *const USER_DEFAULTS_KEY_MAIN_APP_LOCALE;

extern NSString *const USER_DEFAULTS_KEY_PREFERRED_CONTENT_SIZE_CATEGORY;

//// When upgrading from 1.x to 2.0, everyone needs to login using account kit even if the user already exists.
//// Do not reset on clearing local cached data
//extern NSString *const USER_DEFAULTS_KEY_EVER_ACCOUNT_KIT_LOGIN_SUCCESSFULLY;

// If set to @YES, the UserProfileViewController should display.
// Do not reset on clearing local cached data
extern NSString *const USER_DEFAULTS_KEY_NEED_CREATE_OR_UPDATE_USER_PROFILE;

// On clearing local cached data, the value must be set to NO
//extern NSString *const USER_DEFAULTS_KEY_EVER_PROMPT_DELETING_UPLOADED_FILE;

// On clearing local cached data, all the tmp file path under it must be deleted first.
extern NSString *const USER_DEFAULTS_KEY_TMP_UPLOAD_FILES;

extern NSString *const USER_DEFAULTS_KEY_RELOAD_MENU;

extern NSString *const USER_DEFAULTS_KEY_PREFERENCES_MOVED_TO_FILELUG_KIT;

//// If user allows to receive local/remote notifications
//extern NSString *const USER_DEFAULTS_KEY_ALLOW_RECEIVE_NOTIFICATION;
//
//// If USER_DEFAULTS_KEY_ALLOW_RECEIVE_NOTIFICATION reset
//extern NSString *const USER_DEFAULTS_KEY_RESET_ALLOW_RECEIVE_NOTIFICATION;

extern NSString *const USER_DEFAULTS_KEY_NEED_RELOAD_CORE_DATA;

// value is type of NSNumber wrapped of BOOL
extern NSString *const USER_DEFAULTS_KEY_CONVERTED_LOCAL_PATH_TO_RELATIVE_PATH;

// value is type of NSNumber wrapped of BOOL
extern NSString *const USER_DEFAULTS_KEY_MOVE_DOWNLOADED_FILE_TO_APP_GROUP_DIRECTORY;

// value is type of NSNumber wrapped of BOOL
extern NSString *const USER_DEFAULTS_KEY_FILE_MOVED_TO_DEVICE_SHARING_FOLDER_DIRECTORY;

// value is type of NSNumber wrapped of BOOL
extern NSString *const USER_DEFAULTS_KEY_DELETED_ASSET_FILES_WITH_SOURCE_TYPE_SHARED_FILE_BUT_NO_DOWNLOADED_TRANSFER_KEY;

// value is type of NSNumber wrapped of BOOL
extern NSString *const USER_DEFAULTS_KEY_HIERARCHICAL_MODEL_TYPE_COPIED_TO_SECTION_NAME;

// value is type of NSNumber wrapped of BOOL
extern NSString *const USER_DEFAULTS_KEY_CREATE_FILE_DOWNLOAD_GROUP_TO_NON_ASSIGNED_FILE_TRANSFERS;

// value is type of NSNumber wrapped of BOOL
extern NSString *const CREATE_TIMESTAMP_UPDATED_TO_CURRENT_TIMESTAMP;

extern char *const DISPATCH_QUEUE_UPLOAD_CONCURRENT;

extern char *const DISPATCH_QUEUE_DOWNLOAD_CONCURRENT;

// Preferences for user account related

extern NSString *const USER_DEFAULTS_KEY_COUNTRY_ID;

extern NSString *const USER_DEFAULTS_KEY_COUNTRY_CODE;

extern NSString *const USER_DEFAULTS_KEY_PHONE_NUMBER;

extern NSString *const USER_DEFAULTS_KEY_PHONE_NUMBER_WITH_COUNTRY;

extern NSString *const USER_DEFAULTS_KEY_USER_ID;

//extern NSString *const USER_DEFAULTS_KEY_PASSWORD;

extern NSString *const USER_DEFAULTS_KEY_NICKNAME;

extern NSString *const USER_DEFAULTS_KEY_USER_EMAIL;

extern NSString *const USER_DEFAULTS_KEY_USER_EMAIL_IS_VERIFIED;

extern NSString *const USER_DEFAULTS_KEY_NOTIFICATION_BADGE_NUMBER;

extern NSString *const USER_DEFAULTS_KEY_UPLOAD_COMPLETED;

extern NSString *const USER_DEFAULTS_KEY_DOWNLOAD_COMPLETED;

// No more used
//extern NSString *const USER_DEFAULTS_KEY_NEED_PROMPT_EMPTY_EMAIL;

extern NSString *const USER_DEFAULTS_KEY_RESET_PASSWORD_USER_ID;

extern NSString *const USER_DEFAULTS_KEY_FIRST_ROOT_DIRECTORY;

// Upload Summary

// value is type of NSString
extern NSString *const USER_DEFAULTS_KEY_UPLOAD_DIRECTORY;

// value is type of NSNumber, including a NSIntgeger
extern NSString *const USER_DEFAULTS_KEY_UPLOAD_SUBDIRECTORY_TYPE;

// value is type of NSString
extern NSString *const USER_DEFAULTS_KEY_UPLOAD_SUBDIRECTORY_VALUE;

// value is type of NSArray, elements of NSString
// Aborted after 1.5.0, use USER_DEFAULTS_KEY_UPLOAD_SUBDIRECTORY_VALUE instead
extern NSString *const USER_DEFAULTS_KEY_UPLOAD_SUBDIRECTORIES;

// value is type of NSNumber, including a NSIntgeger
extern NSString *const USER_DEFAULTS_KEY_UPLOAD_DESCRIPTION_TYPE;

// value is type of NSString
extern NSString *const USER_DEFAULTS_KEY_UPLOAD_DESCRIPTION_VALUE;

// value is type of NSArray, elements of NSString
// Aborted after 1.5.0, use USER_DEFAULTS_KEY_UPLOAD_NOTIFICATION_TYPE instead
extern NSString *const USER_DEFAULTS_KEY_UPLOAD_DESCRIPTIONS;

// value is type of NSNumber, including a NSIntgeger
extern NSString *const USER_DEFAULTS_KEY_UPLOAD_NOTIFICATION_TYPE;

// Download Summary

// value is type of NSString
extern NSString *const USER_DEFAULTS_KEY_DOWNLOAD_DIRECTORY;

// value is type of NSNumber, including a NSIntgeger
extern NSString *const USER_DEFAULTS_KEY_DOWNLOAD_SUBDIRECTORY_TYPE;

// value is type NSString
extern NSString *const USER_DEFAULTS_KEY_DOWNLOAD_SUBDIRECTORY_VALUE;

// value is type of NSNumber, including a NSIntgeger
extern NSString *const USER_DEFAULTS_KEY_DOWNLOAD_DESCRIPTION_TYPE;

// value is type of NSString
extern NSString *const USER_DEFAULTS_KEY_DOWNLOAD_DESCRIPTION_VALUE;

// value is type of NSNumber, including a NSIntgeger
extern NSString *const USER_DEFAULTS_KEY_DOWNLOAD_NOTIFICATION_TYPE;

// Preferences for computer (/user-computer/session) related

// For login and LUG-SERVER-RELATED-SERVICES
extern NSString *const USER_DEFAULTS_KEY_USER_SESSION_ID;

//// For login and AA-SERVER-RELATED-SERVICES
//extern NSString *const USER_DEFAULTS_KEY_USER_SESSION_ID2;

extern NSString *const USER_DEFAULTS_KEY_SHOW_HIDDEN;

extern NSString *const USER_DEFAULTS_KEY_COMPUTER_ID;

extern NSString *const USER_DEFAULTS_KEY_COMPUTER_ADMIN_ID;

extern NSString *const USER_DEFAULTS_KEY_COMPUTER_GROUP;

extern NSString *const USER_DEFAULTS_KEY_COMPUTER_NAME;

extern NSString *const USER_DEFAULTS_KEY_USER_COMPUTER_ID;

extern NSString *const USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR;

extern NSString *const USER_DEFAULTS_KEY_SERVER_PATH_SEPARATOR;

extern NSString *const USER_DEFAULTS_KEY_SERVER_LINE_SEPARATOR;

extern NSString *const USER_DEFAULTS_KEY_SERVER_USER_COUNTRY;

extern NSString *const USER_DEFAULTS_KEY_SERVER_USER_LANGUAGE;

extern NSString *const USER_DEFAULTS_KEY_SERVER_USER_HOME;

extern NSString *const USER_DEFAULTS_KEY_SERVER_USER_DIRECTORY;

extern NSString *const USER_DEFAULTS_KEY_SERVER_TEMP_DIRECTORY;

extern NSString *const USER_DEFAULTS_KEY_SERVER_FILE_ENCODING;

extern NSString *const USER_DEFAULTS_KEY_DESKTOP_VERSION;

extern NSString *const USER_DEFAULTS_KEY_LUG_SERVER_ID;

// If value of the key is YES ([NSNumber boolValue]),
// when SettingsViewController appears,
// scroll to connected-computer row and prompt that user need to install Filelug in the computer
extern NSString *const USER_DEFAULTS_KEY_SHOULD_SCROLL_TO_CONNECTED_COMPUTER_AND_PROMPT;

// If value of the key is YES ([NSNumber boolValue]),
// when SettingsViewController appears,
// press 'Login with Another Account' programatically
extern NSString *const USER_DEFAULTS_KEY_SHOULD_LOGIN_WITH_ANOTHER_ACCOUNT;

// When user computer changed, set both to @YES so DownloadFileViewController and FileUploadViewController will get new NSFetchedResults

extern NSString *const USER_DEFAULTS_KEY_NEED_RELOAD_DOWNLOAD_LIST;

extern NSString *const USER_DEFAULTS_KEY_NEED_RELOAD_UPLOAD_LIST;

extern NSString *const USER_DEFAULTS_KEY_DISABLED_FIND_AVAILABLE_COMPUTERS_ON_VIEW_DID_APPEAR;

// timeout interval related

extern float const CONNECTION_TIME_INTERVAL;

extern float const REQUEST_CONNECT_TIME_INTERVAL;

extern float const CONNECTION_TIME_INTERVAL_FOR_BACKGROUND_DOWNLOAD;

extern float const CONNECTION_TIME_INTERVAL_FOR_BACKGROUND_UPLOAD;

extern NSString *const HIERARCHICAL_MODEL_TYPE_FILE;

extern NSString *const HIERARCHICAL_MODEL_TYPE_DIRECTORY;

extern NSString *const HIERARCHICAL_MODEL_TYPE_BUNDLE_DIRECTORY_FILE;

extern NSString *const HIERARCHICAL_MODEL_TYPE_MAC_ALIAS_FILE;

extern NSString *const HIERARCHICAL_MODEL_TYPE_MAC_ALIAS_DIRECTORY;

extern NSString *const HIERARCHICAL_MODEL_TYPE_WINDOWS_SHORTCUT_DIRECTORY;

extern NSString *const HIERARCHICAL_MODEL_TYPE_WINDOWS_SHORTCUT_FILE;

extern NSString *const HIERARCHICAL_MODEL_TYPE_UNIX_SYMBOLIC_LINK_FILE;

extern NSString *const HIERARCHICAL_MODEL_TYPE_UNIX_SYMBOLIC_LINK_DIRECTORY;

extern NSString *const HIERARCHICAL_MODEL_TYPE_SUFFIX_FILE;

extern NSString *const HIERARCHICAL_MODEL_TYPE_SUFFIX_DIRECTORY;

extern NSString *const HIERARCHICAL_MODEL_SECTION_NAME_FILE;

extern NSString *const HIERARCHICAL_MODEL_SECTION_NAME_DIRECTORY;

extern NSString *const HIERARCHICAL_MODEL_TYPE_CONTAIN_LINK;

extern NSString *const HIERARCHICAL_MODEL_TYPE_CONTAIN_SHORTCUT;

extern NSString *const HIERARCHICAL_MODEL_TYPE_CONTAIN_ALIAS;

extern NSString *const CREPO_DOMAIN_URL_SCHEME;

extern NSString *const CREPO_DOMAIN_ZONE_NAME;

extern NSString *const CREPO_DOMAIN_NAME;

extern NSUInteger const CREPO_PORT;

extern NSString *const CREPO_CONTEXT_PATH;

// Demo Account
extern NSString *const DEMO_ACCOUNT_SESSION_ID;
extern NSString *const DEMO_ACCOUNT_USER_ID;
extern NSString *const DEMO_ACCOUNT_COUNTRY_ID;
extern NSString *const DEMO_ACCOUNT_PHONE_NUMBER;
extern NSString *const DEMO_ACCOUNT_NICKNAME;
extern NSString *const DEMO_ACCOUNT_EMAIL;

// Last date to show demo account
extern NSInteger const YEAR_OF_LAST_DATE_TO_SHOW_DEMO_ACCOUNT;
extern NSInteger const MONTH_OF_LAST_DATE_TO_SHOW_DEMO_ACCOUNT;
extern NSInteger const DAY_OF_LAST_DATE_TO_SHOW_DEMO_ACCOUNT;
extern NSInteger const TIME_ZONE_OF_LAST_DATE_TO_SHOW_DEMO_ACCOUNT; // TZ: "Asia/Taipei", secondes from GMT: 28800

extern NSString *const HTTP_HEADER_NAME_AUTHORIZATION;

extern NSString *const HTTP_HEADER_NAME_UPLOAD_KEY;

extern NSString *const HTTP_HEADER_NAME_UPLOAD_DIRECTORY;

extern NSString *const HTTP_HEADER_NAME_UPLOAD_FILE_NAME;

extern NSString *const HTTP_HEADER_NAME_UPLOAD_FILE_SIZE;

extern NSString *const HTTP_HEADER_NAME_FILE_RANGE;

extern NSString *const HTTP_HEADER_NAME_FILE_LAST_MODIFIED_DATE;

extern NSString *const HTTP_HEADER_NAME_UPLOADED_BUT_UNCONFIRMED;

extern NSString *const HTTP_HEADER_NAME_ACCEPT_ENCODING;

extern NSString *const HTTP_HEADER_NAME_CONTENT_ENCODING;

extern NSString *const CHANGE_TYPE_ADD;

extern NSString *const CHANGE_TYPE_UPDATE;

extern NSString *const CHANGE_TYPE_DELETE;

extern NSString *const ERROR_DOMAIN_CLOPUCCINO;

extern NSString *const IS_APP_FIRST_TIME_RUN;

extern NSString *const DATA_BASE_NAME;

extern NSString *const APP_NAME;

extern NSString *const APP_GROUP_NAME;

extern NSString *const BACKGROUND_DOWNLOAD_ID_FOR_FILELUG_PREFIX;

extern NSString *const BACKGROUND_DOWNLOAD_ID_FOR_DOCUMENT_PROVIDER_EXTENSION_PREFIX;

extern NSString *const BACKGROUND_UPLOAD_ID_FOR_FILELUG_PREFIX;

extern NSString *const BACKGROUND_UPLOAD_ID_FOR_SHARE_EXTENSION_PREFIX;

extern NSString *const SHARED_DATA_BASE_NAME;

extern NSString* const DATA_TICKLE_DIRECTORY_NAME;

extern NSString *const RESPONSE_HEADER_CHANGE_TIMESTAMP;

extern int const WAIT_RECONNECT_INTERVAL_IN_SECONDS;

extern NSString *const DEFAULT_ROOT_DIRECTORY_NAME;

extern NSString *const FILE_TRANSFER_STATUS_PREPARING;

extern NSString *const FILE_TRANSFER_STATUS_PROCESSING;

extern NSString *const FILE_TRANSFER_STATUS_CANCELING;

extern NSString *const FILE_TRANSFER_STATUS_CONFIRMING;

extern NSString *const FILE_TRANSFER_STATUS_FAILED;

extern NSString *const FILE_TRANSFER_STATUS_SUCCESS;

extern NSInteger const FILE_TRANSFER_NOTIFICATION_TYPE_NO_NOTIFICATION;

extern NSInteger const FILE_TRANSFER_NOTIFICATION_TYPE_ON_EACH_FILE;

extern NSInteger const FILE_TRANSFER_NOTIFICATION_TYPE_ON_ALL_FILES;

extern NSString *const TEMP_FILE_PATH_EXTENSION;

extern NSUInteger const RECENT_FILES_FETCH_LIMITS;

extern CGFloat DOWNLOAD_STATUS_LABEL_HEIGHT;

extern CGFloat MAX_IMAGE_HEIGHT_FOR_FILE_UPLOAD_TABLE_VIEW_CELL;

extern NSString *const UPLOAD_TASK_DESCRIPTION_SEPARATOR;

extern NSString *const DOWNLOAD_TASK_DESCRIPTION_SEPARATOR;

extern NSString *const TMP_UPLOAD_FILE_PREFIX;

extern NSString *const TMP_UPLOAD_EMPTY_FILE_SUFFIX;

extern NSString *const DATE_FORMAT_FOR_SERVER;

extern NSString *const DATE_FORMAT_FOR_FILE_UPLOAD_GROUP_SUBDIRECTORY;

extern NSString *const DATE_FORMAT_FOR_FILE_UPLOAD_TABLE_VIEW_SECTION;

extern NSString *const DATE_FORMAT_FOR_RANDOM_FILENAME;

extern NSString *const DATE_FORMAT_FOR_HTTP_HEADER_LAST_MODIFIED;

extern NSString *const USER_ACCOUNT_DELIMITERS;

extern NSString *const USER_COMPUTER_DELIMITERS;

extern NSString *const URL_ABOUT_FILE_SHARING;

extern int const NUMBER_OF_ACTIONS_AFTER_DOWNLOADS;

extern NSString *const SEPARATOR_ACTIONS_AFTER_DOWNLOADS;

extern NSString *const YES_ACTION;

extern NSString *const NO_ACTION;

extern NSString *const DEFAULT_COMPUTER_GROUP;

extern NSString *const DEFAULT_COMPUTER_NAME;

extern NSString *const PURCHASE_ID_DELIMITERS;

extern NSString *const AA_SERVER_ID_AS_LUG_SERVER;

extern NSString *const EXTERNAL_FILE_DIRECTORY_NAME;

extern NSString *const DEVICE_SHARING_FOLDER_NAME;

extern NSString *const EXTENSION_FILE_DIRECTORY_NAME;

extern NSString *const SETTINGS_FILE_DIRECTORY_NAME;

extern NSString *const PACKED_UPLOAD_DESCRIPTION_FILENAME;

extern NSString *const PACKED_UPLOAD_NOTIFICATION_FILENAME;

extern NSString *const PACKED_UPLOAD_SUBDIRECTORY_FILENAME;

extern NSString *const FILELUG_URL_IN_APP_STORE;

extern NSString *const FILELUG_URL_TO_FEEDBACK;

extern NSString *const FILELUG_URL_TO_TERMS_OF_USER;

extern NSString *const FILELUG_URL_TO_PRIVACY_POLICY;

// download/upload history types,
// also represented as the segment index in DownloadHistoryViewController/UploadHistoryViewController

extern NSInteger const TRANSFER_HISTORY_TYPE_LATEST_20;

extern NSInteger const TRANSFER_HISTORY_TYPE_LATEST_WEEK;

extern NSInteger const TRANSFER_HISTORY_TYPE_LATEST_MONTH;

extern NSInteger const TRANSFER_HISTORY_TYPE_ALL;

extern NSTimeInterval const CONFIRM_UPLOAD_TIME_INTERVAL;

extern NSTimeInterval const MULTIPLE_FILE_UPLOAD_INTERVAL;

extern NSTimeInterval const DELAY_CONFIRM_UPLOAD_INTERVAL;

extern NSTimeInterval const START_UPLOAD_TIME_INTERVAL;

extern NSTimeInterval const DELAY_UPLOAD_TIMER_INTERVAL;

extern NSString *const QR_CODE_PREFIX;

extern NSString *const FILELUG_SERVICE_CONTENT_KEY_TRANSFER_KEY;

extern NSString *const FILELUG_SERVICE_CONTENT_KEY_STATUS;

// notification messages

extern NSString *const NOTIFICATION_CATEGORY_FILE_UPLOAD;

extern NSString *const NOTIFICATION_ACTION_UPLOAD_VIEW;

extern NSString *const NOTIFICATION_CATEGORY_FILE_DOWNLOAD;

extern NSString *const NOTIFICATION_ACTION_DOWNLOAD_OPEN;

extern NSString *const NOTIFICATION_CATEGORY_APPLY_ACCEPTED;

extern NSString *const NOTIFICATION_ACTION_APPLIED_ACCEPTED_CONNECT;

extern NSString *const NOTIFICATION_CATEGORY_APPLY_TO_ADMIN;

extern NSString *const NOTIFICATION_ACTION_ADMIN_ACCEPT;

extern NSString *const NOTIFICATION_ACTION_ADMIN_REJECT;

extern NSString *const NOTIFICATION_ACTION_ADMIN_VIEW_DETAIL;

extern NSString *const DEVICE_TOKEN_NOTIFICATION_TYPE_APNS;

extern NSString *const DEVICE_TOKEN_DEVICE_TYPE_IOS;

extern NSString *const NOTIFICATION_MESSAGE_KEY_TYPE;

extern NSString *const NOTIFICATION_MESSAGE_TYPE_UPLOAD_FILE;

extern NSString *const NOTIFICATION_MESSAGE_TYPE_ALL_FILES_UPLOADED_SUCCESSFULLY;

extern NSString *const NOTIFICATION_MESSAGE_TYPE_DOWNLOAD_FILE;

extern NSString *const NOTIFICATION_MESSAGE_TYPE_ALL_FILES_DOWNLOADED_SUCCESSFULLY;

extern NSString *const NOTIFICATION_MESSAGE_KEY_TRANSFER_KEY;

extern NSString *const NOTIFICATION_MESSAGE_KEY_TRANSFER_STATUS;

extern NSString *const NOTIFICATION_MESSAGE_KEY_APS;

extern NSString *const NOTIFICATION_MESSAGE_KEY_BADGE;

extern NSString *const NOTIFICATION_MESSAGE_KEY_UPLOAD_GROUP_ID;

extern NSString *const NOTIFICATION_MESSAGE_KEY_DOWNLOAD_GROUP_ID;

// value is type of NSNumber: @0 is false(not set), @1 is true(already set)
extern NSString *const ALREADY_SET_EMPTY_TO_SESSION_FOR_VERSION_1_3_7;

extern int const MAX_COMPUTER_NAME_LENGTH;

extern int const MIN_COMPUTER_NAME_LENGTH;

// Customized notification name

// No more needed
//extern NSNotificationName const NOTIFICATION_NAME_CANCEL_ALL_FILES_DOWNLOADING;

extern NSNotificationName const NOTIFICATION_NAME_FILE_DOWNLOAD_DID_WRITE_DATA;

extern NSNotificationName const NOTIFICATION_NAME_FILE_DOWNLOAD_DID_RESUME;

extern NSNotificationName const NOTIFICATION_NAME_FILE_DOWNLOAD_DID_FINISH;

extern NSNotificationName const NOTIFICATION_NAME_FILE_DOWNLOAD_DID_COMPLETE;

// Notification key used in the object when post Notification

extern NSString *const NOTIFICATION_KEY_DOWNLOAD_TRANSFER_KEY;

extern NSString *const NOTIFICATION_KEY_DOWNLOAD_REAL_FILENAME;

extern NSString *const NOTIFICATION_KEY_DOWNLOAD_TRANSFERRED_SIZE;

extern NSString *const NOTIFICATION_KEY_DOWNLOAD_TOTAL_SIZE;

extern NSString *const NOTIFICATION_KEY_DOWNLOAD_PERCENTAGE;

extern NSString *const NOTIFICATION_KEY_DOWNLOAD_PERMANENT_FILE_PATH;

extern NSString *const NOTIFICATION_KEY_DOWNLOAD_STATUS;

extern NSString *const NOTIFICATION_KEY_DOWNLOAD_FILE_LOCAL_PATH;

// The time interval for UNTimeIntervalNotificationTrigger must be greater than 0
extern NSTimeInterval const NOTIFICATION_TRIGGER_TIME_INTERVAL;

// ERROR CODES

extern NSInteger const ERROR_CODE_DUPLICATED_UPLOAD_KEY;

extern NSInteger const ERROR_CODE_DOWNLOAD_TASK_IS_ALIVE_KEY;

extern NSInteger const ERROR_CODE_ENTITY_NOT_FOUND_KEY;

extern NSInteger const ERROR_CODE_DATA_INTEGRITY_KEY;

extern NSInteger const ERROR_CODE_CONNECT_TO_COMPUTER_FIRST_KEY;

extern NSInteger const ERROR_CODE_INCORRECT_DATA_FORMAT_KEY;

extern NSInteger const ERROR_CODE_UNSUPPORTED_FILE_TO_UPLOAD_KEY;

extern NSInteger const ERROR_CODE_COPY_PARTIAL_FILE_CONTENT_KEY;

extern NSInteger const ERROR_CODE_INCORRECT_VERIFICATION_KEY;

extern NSInteger const ERROR_CODE_UNKNOW_KEY;

// ASSET FILE SOURCE TYPES

extern NSUInteger const ASSET_FILE_SOURCE_TYPE_UNKNOWN;
extern NSUInteger const ASSET_FILE_SOURCE_TYPE_ALASSET;
extern NSUInteger const ASSET_FILE_SOURCE_TYPE_PHASSET;
extern NSUInteger const ASSET_FILE_SOURCE_TYPE_SHARED_FILE;
extern NSUInteger const ASSET_FILE_SOURCE_TYPE_EXTERNAL_FILE;

// INDEX OF TAB BAR ITEMS

extern NSUInteger const INDEX_OF_TAB_BAR_DOWNLOAD;
extern NSUInteger const INDEX_OF_TAB_BAR_UPLOAD;
extern NSUInteger const INDEX_OF_TAB_BAR_BROWSE;
//extern NSUInteger const INDEX_OF_TAB_BAR_BOOKMARK;
extern NSUInteger const INDEX_OF_TAB_BAR_SETTINGS;

// TABLE VIEW CELL ROW HEIGHT

extern CGFloat const TABLE_VIEW_CELL_ROW_HEIGHT_FOR_ULTIMATE_LARGE_CONTENT_SIZE_CATEGORY;
extern CGFloat const TABLE_VIEW_CELL_ROW_HEIGHT_FOR_XX_LARGE_CONTENT_SIZE_CATEGORY;
extern CGFloat const TABLE_VIEW_CELL_ROW_HEIGHT_FOR_LARGE_CONTENT_SIZE_CATEGORY;
extern CGFloat const TABLE_VIEW_CELL_ROW_HEIGHT_FOR_MEDIUM_CONTENT_SIZE_CATEGORY;
extern CGFloat const TABLE_VIEW_CELL_ROW_HEIGHT_FOR_SMALL_CONTENT_SIZE_CATEGORY;

// TYPE OF LOGIN WITH ACCOUNT KIT

extern NSInteger const LOGIN_REASON_LOGIN_WITH_ANOTHER_ACCOUNT;
extern NSInteger const LOGIN_REASON_DELETE_ACCOUNT;
//extern NSInteger const LOGIN_REASON_DELETE_COMPUTER;

// TYPE OF ROOT DIRECTORY

extern NSString *const ROOT_DIRECTORY_TYPE_USER_HOME;                   // user home directory, used for root directory
extern NSString *const ROOT_DIRECTORY_TYPE_LOCAL_DISK;                  // disk in local machine, used for root directory
extern NSString *const ROOT_DIRECTORY_TYPE_EXTERNAL_DISK;               // USB or TUNDERBOLT disk, used for root directory
extern NSString *const ROOT_DIRECTORY_TYPE_NETWORK_DISK;                // newwork disk, such as FTP, SMB, used for root directory
extern NSString *const ROOT_DIRECTORY_TYPE_DVD_PLAYER;                  // DVD/VCD player, used for root directory
extern NSString *const ROOT_DIRECTORY_TYPE_DIRECTORY;                   // DIRECTORY, used for root directory
extern NSString *const ROOT_DIRECTORY_TYPE_WINDOWS_SHORTCUT_DIRECTORY;  // Windows directory short-cut, used for root directory
extern NSString *const ROOT_DIRECTORY_TYPE_UNIX_SYMBOLIC_LINK_DIRECTORY;// Unix/Linux directory short-cut, used for root directory
extern NSString *const ROOT_DIRECTORY_TYPE_MAC_ALIAS_DIRECTORY;         // macOS directory short-cut, used for root directory
extern NSString *const ROOT_DIRECTORY_TYPE_TIME_MACHINE;                // Time Machine Backup Disk, for macOS only

@end
