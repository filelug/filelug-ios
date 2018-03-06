// Preferences for app, set each time app launched,
// do not delete on clearing local cached data

NSString *const USER_DEFAULTS_KEY_DOMAIN_URL_SCHEME = @"domainURLScheme";

NSString *const USER_DEFAULTS_KEY_DOMAIN_ZONE_NAME = @"domainZoneName";

NSString *const USER_DEFAULTS_KEY_DOMAIN_NAME = @"domainName";

NSString *const USER_DEFAULTS_KEY_PORT = @"port";

NSString *const USER_DEFAULTS_KEY_CONTEXT_PATH = @"contextPath";

NSString *const USER_DEFAULTS_KEY_REMOTE_NOTIFICATION_DEVICE_TOKEN = @"remote_notification_device_token";

NSString *const USER_DEFAULTS_KEY_MAIN_APP_VERSION = @"main_app_version";

NSString *const USER_DEFAULTS_KEY_MAIN_APP_BUILD_NO = @"main_app_build_no";

NSString *const USER_DEFAULTS_KEY_MAIN_APP_LOCALE = @"main_app_locale";

NSString *const USER_DEFAULTS_KEY_PREFERRED_CONTENT_SIZE_CATEGORY = @"preferred_content_size_category";

//NSString *const USER_DEFAULTS_KEY_EVER_ACCOUNT_KIT_LOGIN_SUCCESSFULLY = @"everAccountKitLoginSuccessfully";

NSString *const USER_DEFAULTS_KEY_NEED_CREATE_OR_UPDATE_USER_PROFILE = @"needCreateOrUpdateUserProfile";

//NSString *const USER_DEFAULTS_KEY_EVER_PROMPT_DELETING_UPLOADED_FILE = @"everPromptDeletingUploadedFile";

NSString *const USER_DEFAULTS_KEY_TMP_UPLOAD_FILES = @"tmp-upload-files";

NSString *const USER_DEFAULTS_KEY_RELOAD_MENU = @"reload_menu";

NSString *const USER_DEFAULTS_KEY_PREFERENCES_MOVED_TO_FILELUG_KIT = @"preferences_moved_to_filelug_kit";

//// If user allows to receive local/remote notifications
//NSString *const USER_DEFAULTS_KEY_ALLOW_RECEIVE_NOTIFICATION = @"allow_receive_notification";
//
//// If USER_DEFAULTS_KEY_ALLOW_RECEIVE_NOTIFICATION reset
//NSString *const USER_DEFAULTS_KEY_RESET_ALLOW_RECEIVE_NOTIFICATION = @"reset_allow_receive_notification";

NSString *const USER_DEFAULTS_KEY_NEED_RELOAD_CORE_DATA = @"need_reload_core_data";

NSString *const USER_DEFAULTS_KEY_CONVERTED_LOCAL_PATH_TO_RELATIVE_PATH = @"converted_local_path_to_relative_path";

NSString *const USER_DEFAULTS_KEY_MOVE_DOWNLOADED_FILE_TO_APP_GROUP_DIRECTORY = @"move_downloaded_file_to_app_group_directory";

NSString *const USER_DEFAULTS_KEY_FILE_MOVED_TO_DEVICE_SHARING_FOLDER_DIRECTORY = @"file_moved_to_device_sharing_folder_directory";

NSString *const USER_DEFAULTS_KEY_DELETED_ASSET_FILES_WITH_SOURCE_TYPE_SHARED_FILE_BUT_NO_DOWNLOADED_TRANSFER_KEY = @"removed_file_under_itunes_and_device_sharing_directories";

NSString *const USER_DEFAULTS_KEY_HIERARCHICAL_MODEL_TYPE_COPIED_TO_SECTION_NAME = @"hierarchical_model_type_copied_to_section_name";

NSString *const USER_DEFAULTS_KEY_CREATE_FILE_DOWNLOAD_GROUP_TO_NON_ASSIGNED_FILE_TRANSFERS = @"create_file_download_group_to_non_assigned_file_transfers";

NSString *const CREATE_TIMESTAMP_UPDATED_TO_CURRENT_TIMESTAMP = @"create_timestamp_updated_to_current_timestamp";

char *const DISPATCH_QUEUE_UPLOAD_CONCURRENT = "com.filelug.upload";

char *const DISPATCH_QUEUE_DOWNLOAD_CONCURRENT = "com.filelug.download";

// Preferences for user account related

NSString *const USER_DEFAULTS_KEY_COUNTRY_ID = @"countryId";

NSString *const USER_DEFAULTS_KEY_COUNTRY_CODE = @"countryCode";

NSString *const USER_DEFAULTS_KEY_PHONE_NUMBER = @"phoneNumber";

NSString *const USER_DEFAULTS_KEY_PHONE_NUMBER_WITH_COUNTRY = @"phoneNumberWithCountry";

NSString *const USER_DEFAULTS_KEY_USER_ID = @"userId";

//NSString *const USER_DEFAULTS_KEY_PASSWORD = @"password";

NSString *const USER_DEFAULTS_KEY_NICKNAME = @"nickname";

NSString *const USER_DEFAULTS_KEY_USER_EMAIL = @"user-email";

// The value of the preference is NSNumber with BOOL inside.
NSString *const USER_DEFAULTS_KEY_USER_EMAIL_IS_VERIFIED = @"user-email-is-verified";

// including local and remote notifications
// On clear local cached data, set to 0
NSString *const USER_DEFAULTS_KEY_NOTIFICATION_BADGE_NUMBER = @"notification_badge_number";

// file upload completed with or without error, e.g. success or failured
NSString *const USER_DEFAULTS_KEY_UPLOAD_COMPLETED = @"upload_completed";

// file download completed with or without error, e.g. success or failured
NSString *const USER_DEFAULTS_KEY_DOWNLOAD_COMPLETED = @"download_completed";

//NSString *const USER_DEFAULTS_KEY_NEED_PROMPT_EMPTY_EMAIL = @"promptEmptyEmail";

NSString *const USER_DEFAULTS_KEY_RESET_PASSWORD_USER_ID = @"reset-password-user-id";

NSString *const USER_DEFAULTS_KEY_FIRST_ROOT_DIRECTORY = @"first-root-directory";

// Upload Summary

// value is type of NSString
NSString *const USER_DEFAULTS_KEY_UPLOAD_DIRECTORY = @"upload-directory";

NSString *const USER_DEFAULTS_KEY_UPLOAD_SUBDIRECTORY_TYPE = @"upload_subdirectory_type";

NSString *const USER_DEFAULTS_KEY_UPLOAD_SUBDIRECTORY_VALUE = @"upload_subdirectory_value";

NSString *const USER_DEFAULTS_KEY_UPLOAD_SUBDIRECTORIES = @"upload_subdirectories";

NSString *const USER_DEFAULTS_KEY_UPLOAD_DESCRIPTION_TYPE = @"upload_description_type";

NSString *const USER_DEFAULTS_KEY_UPLOAD_DESCRIPTION_VALUE = @"upload_description_value";

NSString *const USER_DEFAULTS_KEY_UPLOAD_DESCRIPTIONS = @"upload_descriptions";

NSString *const USER_DEFAULTS_KEY_UPLOAD_NOTIFICATION_TYPE = @"upload_notification_type";

// Download Summary

NSString *const USER_DEFAULTS_KEY_DOWNLOAD_DIRECTORY = @"download-directory";

NSString *const USER_DEFAULTS_KEY_DOWNLOAD_SUBDIRECTORY_TYPE = @"download_subdirectory_type";

NSString *const USER_DEFAULTS_KEY_DOWNLOAD_SUBDIRECTORY_VALUE = @"download_subdirectory_value";

NSString *const USER_DEFAULTS_KEY_DOWNLOAD_DESCRIPTION_TYPE = @"download_description_type";

NSString *const USER_DEFAULTS_KEY_DOWNLOAD_DESCRIPTION_VALUE = @"download_description_value";

NSString *const USER_DEFAULTS_KEY_DOWNLOAD_NOTIFICATION_TYPE = @"download_notification_type";

// Preferences for computer (/user-computer/session) related

// For login and LUG-SERVER-RELATED-SERVICES
NSString *const USER_DEFAULTS_KEY_USER_SESSION_ID = @"userSessionId";

//// For login and AA-SERVER-RELATED-SERVICES
//NSString *const USER_DEFAULTS_KEY_USER_SESSION_ID2 = @"userSessionId2";

NSString *const USER_DEFAULTS_KEY_SHOW_HIDDEN = @"showHidden";

NSString *const USER_DEFAULTS_KEY_COMPUTER_ID = @"computer-id";

NSString *const USER_DEFAULTS_KEY_COMPUTER_ADMIN_ID = @"computer-admin-id";

NSString *const USER_DEFAULTS_KEY_COMPUTER_GROUP = @"computer-group";

NSString *const USER_DEFAULTS_KEY_COMPUTER_NAME = @"computer-name";

NSString *const USER_DEFAULTS_KEY_USER_COMPUTER_ID = @"user-computer-id";

NSString *const USER_DEFAULTS_KEY_SERVER_FILE_SEPARATOR = @"fileSeparator";

NSString *const USER_DEFAULTS_KEY_SERVER_PATH_SEPARATOR = @"pathSeparator";

NSString *const USER_DEFAULTS_KEY_SERVER_LINE_SEPARATOR = @"lineSeparator";

NSString *const USER_DEFAULTS_KEY_SERVER_USER_COUNTRY = @"userCountry";

NSString *const USER_DEFAULTS_KEY_SERVER_USER_LANGUAGE = @"userLanguage";

NSString *const USER_DEFAULTS_KEY_SERVER_USER_HOME = @"userHome";

NSString *const USER_DEFAULTS_KEY_SERVER_USER_DIRECTORY = @"userDirectory";

NSString *const USER_DEFAULTS_KEY_SERVER_TEMP_DIRECTORY = @"tempDirectory";

NSString *const USER_DEFAULTS_KEY_SERVER_FILE_ENCODING = @"fileEncoding";

NSString *const USER_DEFAULTS_KEY_DESKTOP_VERSION = @"desktopVersion";

NSString *const USER_DEFAULTS_KEY_LUG_SERVER_ID = @"lug-server-id";

NSString *const USER_DEFAULTS_KEY_SHOULD_SCROLL_TO_CONNECTED_COMPUTER_AND_PROMPT = @"should-scroll-to-connected-computer-and-prompt";

NSString *const USER_DEFAULTS_KEY_SHOULD_LOGIN_WITH_ANOTHER_ACCOUNT = @"should-login-with-another-account";

NSString *const USER_DEFAULTS_KEY_NEED_RELOAD_DOWNLOAD_LIST = @"need-reload-download-list";

NSString *const USER_DEFAULTS_KEY_NEED_RELOAD_UPLOAD_LIST = @"need-reload-upload-list";

// if @YES, don't invoke [self findAvailableComputersToConnectWithTryAgainOnInvalidSession:YES connectDirectlyIfOnlyOneFound:YES addNewComputerDirectlyIfNotFound:NO];
// in viewDidAppear of SettingsViewController:
NSString *const USER_DEFAULTS_KEY_DISABLED_FIND_AVAILABLE_COMPUTERS_ON_VIEW_DID_APPEAR = @"disabledFindAvailableComputersOnViewDidAppear";

float const CONNECTION_TIME_INTERVAL = 60.0;

float const REQUEST_CONNECT_TIME_INTERVAL = 15.0;

//// Since we support resume download & upload, shrink the interval to 15 minutes to prevent too much background auto-retries.
//
//// for file transfer from desktop to device
//float const CONNECTION_TIME_INTERVAL_FOR_BACKGROUND_DOWNLOAD = 15 * 60; // 5 minutes
//
//// for file transfer from device to desktop
//float const CONNECTION_TIME_INTERVAL_FOR_BACKGROUND_UPLOAD = 15 * 60;  // 5 minutes

// set the interval of the data receiver to 3600, adding 2 more seconds to wait for timeout from server (3600 sec)

// for file transfer from desktop to device
float const CONNECTION_TIME_INTERVAL_FOR_BACKGROUND_DOWNLOAD = 3602.0;

// for file transfer from device to desktop
float const CONNECTION_TIME_INTERVAL_FOR_BACKGROUND_UPLOAD = 3602.0;

NSString *const HIERARCHICAL_MODEL_TYPE_FILE = @"FILE";

NSString *const HIERARCHICAL_MODEL_TYPE_DIRECTORY = @"DIRECTORY";

NSString *const HIERARCHICAL_MODEL_TYPE_BUNDLE_DIRECTORY_FILE = @"BUNDLE_DIRECTORY_FILE";

NSString *const HIERARCHICAL_MODEL_TYPE_MAC_ALIAS_FILE = @"MAC_ALIAS_FILE";

NSString *const HIERARCHICAL_MODEL_TYPE_MAC_ALIAS_DIRECTORY = @"MAC_ALIAS_DIRECTORY";

NSString *const HIERARCHICAL_MODEL_TYPE_WINDOWS_SHORTCUT_DIRECTORY = @"WINDOWS_SHORTCUT_DIRECTORY";

NSString *const HIERARCHICAL_MODEL_TYPE_WINDOWS_SHORTCUT_FILE = @"WINDOWS_SHORTCUT_FILE";

NSString *const HIERARCHICAL_MODEL_TYPE_UNIX_SYMBOLIC_LINK_FILE = @"UNIX_SYMBOLIC_LINK_FILE";

NSString *const HIERARCHICAL_MODEL_TYPE_UNIX_SYMBOLIC_LINK_DIRECTORY = @"UNIX_SYMBOLIC_LINK_DIRECTORY";

NSString *const HIERARCHICAL_MODEL_TYPE_SUFFIX_FILE = @"FILE";

NSString *const HIERARCHICAL_MODEL_TYPE_SUFFIX_DIRECTORY = @"DIRECTORY";

NSString *const HIERARCHICAL_MODEL_SECTION_NAME_FILE = @"file";

NSString *const HIERARCHICAL_MODEL_SECTION_NAME_DIRECTORY = @"directory";

NSString *const HIERARCHICAL_MODEL_TYPE_CONTAIN_LINK = @"LINK";

NSString *const HIERARCHICAL_MODEL_TYPE_CONTAIN_SHORTCUT = @"SHORTCUT";

NSString *const HIERARCHICAL_MODEL_TYPE_CONTAIN_ALIAS = @"ALIAS";

NSString *const CREPO_DOMAIN_ZONE_NAME = @"filelug.com";
NSString *const CREPO_CONTEXT_PATH = @"crepo";

// FOR PRODUCTION

NSString *const CREPO_DOMAIN_URL_SCHEME = @"https";
NSString *const CREPO_DOMAIN_NAME = @"repo.filelug.com";
NSUInteger const CREPO_PORT = 443;


// FOR TESTINGdirectory/ddownload, Remember to set the following to filelug-Info.plist
//<key>NSAppTransportSecurity</key>
//<dict>
//  <key>NSAllowsArbitraryLoads</key>
//  <true/>
//</dict>
//NSString *const CREPO_DOMAIN_URL_SCHEME = @"http";
//NSString *const CREPO_DOMAIN_NAME =  @"172.20.10.2"; // @"192.168.11.3"; // @"192.168.0.2"; // @"172.20.10.2"; // 192.168.1.117;
//NSUInteger const CREPO_PORT = 8080;

// Demo Account
NSString *const DEMO_ACCOUNT_SESSION_ID = @"D9C3FC9ECFACEF9D9C381814AA3FE8A1BEBED2A7E9D5E8851AB917186DCBEA275182FD0B4879C7EAA34A0D449E8C5A8B80D308AEF30681FE56224E4CC8EC7064";
//NSString *const DEMO_ACCOUNT_SESSION_ID = @"B4224035664591EEFE38B5CBE8061475D249E491F808F63EBBA04943FD9AF20FB03F78A63D5C1AEAA72DE063CFEA0E46AC8ED0B3114CB6D5EB102C7BA5973805";
NSString *const DEMO_ACCOUNT_USER_ID = @"C232AD7D7959086E1924E75A7F145424F63EC58D49278901EC25F2512CA8E1DDF747C56365D1709D6E18AEE1074DF81E2CF8AEA6289BC03116BABD548A569A36";
NSString *const DEMO_ACCOUNT_COUNTRY_ID = @"TW";
NSString *const DEMO_ACCOUNT_PHONE_NUMBER = @"968817603";
NSString *const DEMO_ACCOUNT_NICKNAME = @"cutie";
NSString *const DEMO_ACCOUNT_EMAIL = @"cutie@mail.com";

// Last date to show demo account
NSInteger const YEAR_OF_LAST_DATE_TO_SHOW_DEMO_ACCOUNT = 2018;
NSInteger const MONTH_OF_LAST_DATE_TO_SHOW_DEMO_ACCOUNT = 12;
NSInteger const DAY_OF_LAST_DATE_TO_SHOW_DEMO_ACCOUNT = 31;
NSInteger const TIME_ZONE_OF_LAST_DATE_TO_SHOW_DEMO_ACCOUNT = 28800; // TZ: "Asia/Taipei", secondes from GMT: 28800

NSString *const HTTP_HEADER_NAME_AUTHORIZATION = @"fsi";

NSString *const HTTP_HEADER_NAME_UPLOAD_KEY = @"upkey";

NSString *const HTTP_HEADER_NAME_UPLOAD_DIRECTORY = @"updir";

NSString *const HTTP_HEADER_NAME_UPLOAD_FILE_NAME = @"upname";

NSString *const HTTP_HEADER_NAME_UPLOAD_FILE_SIZE = @"upsize";

NSString *const HTTP_HEADER_NAME_FILE_RANGE = @"File-Range";

NSString *const HTTP_HEADER_NAME_FILE_LAST_MODIFIED_DATE = @"File-Last-Modified";

NSString *const HTTP_HEADER_NAME_UPLOADED_BUT_UNCONFIRMED = @"uploaded_but_uncomfirmed";

NSString *const HTTP_HEADER_NAME_ACCEPT_ENCODING = @"Accept-Encoding";

NSString *const HTTP_HEADER_NAME_CONTENT_ENCODING = @"Content-Encoding";

NSString *const CHANGE_TYPE_ADD = @"ADD";

NSString *const CHANGE_TYPE_UPDATE = @"UPDATE";

NSString *const CHANGE_TYPE_DELETE = @"DELETE";

NSString *const ERROR_DOMAIN_CLOPUCCINO = @"clopuccino";

NSString *const IS_APP_FIRST_TIME_RUN = @"FirstTimeRun";

NSString *const DATA_BASE_NAME = @"clopuccino_core_data";

NSString *const APP_NAME = @"com.filelug.filelug";

NSString *const APP_GROUP_NAME = @"group.com.filelug.filelug";

NSString *const BACKGROUND_DOWNLOAD_ID_FOR_FILELUG_PREFIX = @"download";

NSString *const BACKGROUND_DOWNLOAD_ID_FOR_DOCUMENT_PROVIDER_EXTENSION_PREFIX = @"document.provider.download";

NSString *const BACKGROUND_UPLOAD_ID_FOR_FILELUG_PREFIX = @"upload";

NSString *const BACKGROUND_UPLOAD_ID_FOR_SHARE_EXTENSION_PREFIX = @"share.upload";

NSString *const SHARED_DATA_BASE_NAME = @"clopuccino.sqlite";

NSString* const DATA_TICKLE_DIRECTORY_NAME = @"ticklefolder";

NSString *const RESPONSE_HEADER_CHANGE_TIMESTAMP = @"Change-Timestamp";

int const WAIT_RECONNECT_INTERVAL_IN_SECONDS = 20;

NSString *const DEFAULT_ROOT_DIRECTORY_NAME = @"Home";

//NSString *const FILE_TRANSFER_STATUS_COMPLETED = @"completed";

NSString *const FILE_TRANSFER_STATUS_PREPARING = @"preparing";

NSString *const FILE_TRANSFER_STATUS_PROCESSING = @"processing";

//NSString *const FILE_TRANSFER_STATUS_SUSPENDED = @"suspended";

NSString *const FILE_TRANSFER_STATUS_CANCELING = @"canceling";

NSString *const FILE_TRANSFER_STATUS_CONFIRMING = @"confirming";

NSString *const FILE_TRANSFER_STATUS_FAILED = @"failure";

NSString *const FILE_TRANSFER_STATUS_SUCCESS = @"success";

NSInteger const FILE_TRANSFER_NOTIFICATION_TYPE_NO_NOTIFICATION = 0;

NSInteger const FILE_TRANSFER_NOTIFICATION_TYPE_ON_EACH_FILE = 1;

NSInteger const FILE_TRANSFER_NOTIFICATION_TYPE_ON_ALL_FILES = 2;

NSString *const TEMP_FILE_PATH_EXTENSION = @"tmp";

NSUInteger const RECENT_FILES_FETCH_LIMITS = 10;

CGFloat DOWNLOAD_STATUS_LABEL_HEIGHT = 30;

CGFloat MAX_IMAGE_HEIGHT_FOR_FILE_UPLOAD_TABLE_VIEW_CELL = 80;

NSString *const UPLOAD_TASK_DESCRIPTION_SEPARATOR = @"|:|";

NSString *const DOWNLOAD_TASK_DESCRIPTION_SEPARATOR = @"|:|";

NSString *const TMP_UPLOAD_FILE_PREFIX = @"ftmp_";

NSString *const TMP_UPLOAD_EMPTY_FILE_SUFFIX = @"_empty";

NSString *const DATE_FORMAT_FOR_SERVER = @"yyyy/MM/dd HH:mm:ss 'GMT'Z";

NSString *const DATE_FORMAT_FOR_FILE_UPLOAD_GROUP_SUBDIRECTORY = @"yyyy-MM-dd'T'HH-mm-ssZ";

NSString *const DATE_FORMAT_FOR_FILE_UPLOAD_TABLE_VIEW_SECTION = @"yyyy/MM/dd HH:mm:ss (Z)";

NSString *const DATE_FORMAT_FOR_RANDOM_FILENAME = @"yyyyMMdd_HHmmss";

NSString *const DATE_FORMAT_FOR_HTTP_HEADER_LAST_MODIFIED = @"EEE, dd MMM yyyy HH:mm:ss 'GMT'";

NSString *const USER_ACCOUNT_DELIMITERS = @"-";

NSString *const USER_COMPUTER_DELIMITERS = @"|";

NSString *const URL_ABOUT_FILE_SHARING = @"http://support.apple.com/kb/HT4094";

int const NUMBER_OF_ACTIONS_AFTER_DOWNLOADS = 2;

NSString *const SEPARATOR_ACTIONS_AFTER_DOWNLOADS = @",";

NSString *const YES_ACTION = @"YES";

NSString *const NO_ACTION = @"NO";

NSString *const DEFAULT_COMPUTER_GROUP = @"GENERAL";

NSString *const DEFAULT_COMPUTER_NAME = @"SELF-TEST";

NSString *const PURCHASE_ID_DELIMITERS = @"|";

NSString *const AA_SERVER_ID_AS_LUG_SERVER = @"aa";

NSString *const EXTERNAL_FILE_DIRECTORY_NAME = @"filelug_external";

NSString *const DEVICE_SHARING_FOLDER_NAME = @"filelug_device_shared";

NSString *const EXTENSION_FILE_DIRECTORY_NAME = @"Inbox";

NSString *const SETTINGS_FILE_DIRECTORY_NAME = @"filelug_settings";

NSString *const PACKED_UPLOAD_DESCRIPTION_FILENAME = @"packed_upload_description.data";

NSString *const PACKED_UPLOAD_NOTIFICATION_FILENAME = @"packed_upload_notification.data";

NSString *const PACKED_UPLOAD_SUBDIRECTORY_FILENAME = @"packed_upload_subdirectory.data";

NSString *const FILELUG_URL_IN_APP_STORE = @"itms-apps://itunes.apple.com/app/id912529398";

NSString *const FILELUG_URL_TO_FEEDBACK = @"mailto://feedback_ios@filelug.com";
//NSString *const FILELUG_URL_TO_FEEDBACK = @"mailto:feedback_ios@filelug.com?subject=%@&body=✉";

NSString *const FILELUG_URL_TO_TERMS_OF_USER = @"https://filelug.com/terms_web.html";

NSString *const FILELUG_URL_TO_PRIVACY_POLICY = @"https://filelug.com/privacy_web.html";

// download/upload history types,
// also represented as the segment index in DownloadHistoryViewController/UploadHistoryViewController

NSInteger const TRANSFER_HISTORY_TYPE_LATEST_20 = 0;

NSInteger const TRANSFER_HISTORY_TYPE_LATEST_WEEK = 1;

NSInteger const TRANSFER_HISTORY_TYPE_LATEST_MONTH = 2;

NSInteger const TRANSFER_HISTORY_TYPE_ALL = 3;

NSTimeInterval const CONFIRM_UPLOAD_TIME_INTERVAL = 10.0f;

NSTimeInterval const MULTIPLE_FILE_UPLOAD_INTERVAL = 2.0f;

NSTimeInterval const DELAY_CONFIRM_UPLOAD_INTERVAL = 4.0f;

NSTimeInterval const START_UPLOAD_TIME_INTERVAL = 4.0f;

NSTimeInterval const DELAY_UPLOAD_TIMER_INTERVAL = 1.0f;

//// DEBUG: Restore when in production
//NSString *const QR_CODE_PREFIX = @"2FILELUG_";
NSString *const QR_CODE_PREFIX = @"FILELUG_";

NSString *const FILELUG_SERVICE_CONTENT_KEY_TRANSFER_KEY = @"transferKey";

NSString *const FILELUG_SERVICE_CONTENT_KEY_STATUS = @"status";

// notification messages

NSString *const NOTIFICATION_CATEGORY_FILE_UPLOAD = @"file_upload";

NSString *const NOTIFICATION_ACTION_UPLOAD_VIEW = @"upload_view";

NSString *const NOTIFICATION_CATEGORY_FILE_DOWNLOAD = @"file_download";

NSString *const NOTIFICATION_ACTION_DOWNLOAD_OPEN= @"open";

NSString *const NOTIFICATION_CATEGORY_APPLY_ACCEPTED= @"apply_accepted";

NSString *const NOTIFICATION_ACTION_APPLIED_ACCEPTED_CONNECT= @"connect";

NSString *const NOTIFICATION_CATEGORY_APPLY_TO_ADMIN= @"apply_to_admin";

NSString *const NOTIFICATION_ACTION_ADMIN_ACCEPT= @"accept";

NSString *const NOTIFICATION_ACTION_ADMIN_REJECT= @"reject";

NSString *const NOTIFICATION_ACTION_ADMIN_VIEW_DETAIL= @"detail";

NSString *const DEVICE_TOKEN_NOTIFICATION_TYPE_APNS = @"APNS";

NSString *const DEVICE_TOKEN_DEVICE_TYPE_IOS = @"IOS";

NSString *const NOTIFICATION_MESSAGE_KEY_TYPE = @"fl-type";

NSString *const NOTIFICATION_MESSAGE_TYPE_UPLOAD_FILE = @"upload-file";

NSString *const NOTIFICATION_MESSAGE_TYPE_ALL_FILES_UPLOADED_SUCCESSFULLY = @"all-files-uploaded-successfully";

NSString *const NOTIFICATION_MESSAGE_TYPE_DOWNLOAD_FILE = @"download-file";

NSString *const NOTIFICATION_MESSAGE_TYPE_ALL_FILES_DOWNLOADED_SUCCESSFULLY = @"all-files-downloaded-successfully";

NSString *const NOTIFICATION_MESSAGE_KEY_TRANSFER_KEY = @"transfer-key";

NSString *const NOTIFICATION_MESSAGE_KEY_TRANSFER_STATUS = @"transfer-status";

NSString *const NOTIFICATION_MESSAGE_KEY_APS = @"aps";

NSString *const NOTIFICATION_MESSAGE_KEY_BADGE = @"badge";

NSString *const NOTIFICATION_MESSAGE_KEY_UPLOAD_GROUP_ID = @"upload-group-id";

NSString *const NOTIFICATION_MESSAGE_KEY_DOWNLOAD_GROUP_ID = @"download-group-id";

NSString *const ALREADY_SET_EMPTY_TO_SESSION_FOR_VERSION_1_3_7 = @"empty-session-1-3-7";

int const MAX_COMPUTER_NAME_LENGTH = 20;

int const MIN_COMPUTER_NAME_LENGTH = 6;

// Customized notification name

// No more needed
//NSNotificationName const NOTIFICATION_NAME_CANCEL_ALL_FILES_DOWNLOADING = @"CancelAllFilesDownloading";

NSNotificationName const NOTIFICATION_NAME_FILE_DOWNLOAD_DID_WRITE_DATA = @"FileDownloadDidWriteData";

NSNotificationName const NOTIFICATION_NAME_FILE_DOWNLOAD_DID_RESUME = @"FileDownloadDidResume";

NSNotificationName const NOTIFICATION_NAME_FILE_DOWNLOAD_DID_FINISH = @"FileDownloadDidFinish";

NSNotificationName const NOTIFICATION_NAME_FILE_DOWNLOAD_DID_COMPLETE = @"FileDownloadDidComplete";

// Notification key used in the object when post Notification

NSString *const NOTIFICATION_KEY_DOWNLOAD_TRANSFER_KEY = @"NotificationKeyDownloadTransferKey";

NSString *const NOTIFICATION_KEY_DOWNLOAD_REAL_FILENAME = @"NotificationKeyDownloadRealFilename";

NSString *const NOTIFICATION_KEY_DOWNLOAD_TRANSFERRED_SIZE = @"NotificationKeyDownloadTransferredSize";

NSString *const NOTIFICATION_KEY_DOWNLOAD_TOTAL_SIZE = @"NotificationKeyDownloadTotalSize";

NSString *const NOTIFICATION_KEY_DOWNLOAD_PERCENTAGE = @"NotificationKeyDownloadPercentage";

NSString *const NOTIFICATION_KEY_DOWNLOAD_PERMANENT_FILE_PATH = @"NotificationKeyDownloadPermanentFilePath";

NSString *const NOTIFICATION_KEY_DOWNLOAD_STATUS = @"NotificationKeyDownloadStatus";

NSString *const NOTIFICATION_KEY_DOWNLOAD_FILE_LOCAL_PATH = @"NotificationKeyDownloadFileLocalPath";

// The time interval for UNTimeIntervalNotificationTrigger must be greater than 0
NSTimeInterval const NOTIFICATION_TRIGGER_TIME_INTERVAL = 1;

// ERROR CODES

NSInteger const ERROR_CODE_DUPLICATED_UPLOAD_KEY = 600001;

NSInteger const ERROR_CODE_DOWNLOAD_TASK_IS_ALIVE_KEY = 600002;

NSInteger const ERROR_CODE_ENTITY_NOT_FOUND_KEY = 600003;

NSInteger const ERROR_CODE_DATA_INTEGRITY_KEY = 600004;

NSInteger const ERROR_CODE_CONNECT_TO_COMPUTER_FIRST_KEY = 600005;

NSInteger const ERROR_CODE_INCORRECT_DATA_FORMAT_KEY = 600006;

NSInteger const ERROR_CODE_UNSUPPORTED_FILE_TO_UPLOAD_KEY = 600007;

NSInteger const ERROR_CODE_COPY_PARTIAL_FILE_CONTENT_KEY = 600008;

NSInteger const ERROR_CODE_INCORRECT_VERIFICATION_KEY = 600009;

NSInteger const ERROR_CODE_UNKNOW_KEY = 699999;

// ASSET FILE SOURCE TYPES

NSUInteger const ASSET_FILE_SOURCE_TYPE_UNKNOWN = 0;
NSUInteger const ASSET_FILE_SOURCE_TYPE_ALASSET = 1;
NSUInteger const ASSET_FILE_SOURCE_TYPE_PHASSET = 2;
NSUInteger const ASSET_FILE_SOURCE_TYPE_SHARED_FILE = 3;
NSUInteger const ASSET_FILE_SOURCE_TYPE_EXTERNAL_FILE = 4;

// INDEX OF TAB BAR ITEMS

NSUInteger const INDEX_OF_TAB_BAR_DOWNLOAD = 0;
NSUInteger const INDEX_OF_TAB_BAR_UPLOAD = 1;
NSUInteger const INDEX_OF_TAB_BAR_BROWSE = 2;
//NSUInteger const INDEX_OF_TAB_BAR_BOOKMARK = 3;
NSUInteger const INDEX_OF_TAB_BAR_SETTINGS = 3;

// TABLE VIEW CELL ROW HEIGHT

CGFloat const TABLE_VIEW_CELL_ROW_HEIGHT_FOR_ULTIMATE_LARGE_CONTENT_SIZE_CATEGORY = 100;
CGFloat const TABLE_VIEW_CELL_ROW_HEIGHT_FOR_XX_LARGE_CONTENT_SIZE_CATEGORY = 82;
CGFloat const TABLE_VIEW_CELL_ROW_HEIGHT_FOR_LARGE_CONTENT_SIZE_CATEGORY = 66;
CGFloat const TABLE_VIEW_CELL_ROW_HEIGHT_FOR_MEDIUM_CONTENT_SIZE_CATEGORY = 60;
CGFloat const TABLE_VIEW_CELL_ROW_HEIGHT_FOR_SMALL_CONTENT_SIZE_CATEGORY = 60;

// TYPE OF LOGIN WITH ACCOUNT KIT

NSInteger const LOGIN_REASON_LOGIN_WITH_ANOTHER_ACCOUNT = 1;
NSInteger const LOGIN_REASON_DELETE_ACCOUNT = 2;
//NSInteger const LOGIN_REASON_DELETE_COMPUTER = 3;

// TYPE OF ROOT DIRECTORY

NSString *const ROOT_DIRECTORY_TYPE_USER_HOME = @"USER_HOME";
NSString *const ROOT_DIRECTORY_TYPE_LOCAL_DISK = @"LOCAL_DISK";
NSString *const ROOT_DIRECTORY_TYPE_EXTERNAL_DISK = @"EXTERNAL_DISK";
NSString *const ROOT_DIRECTORY_TYPE_NETWORK_DISK = @"NETWORK_DISK";
NSString *const ROOT_DIRECTORY_TYPE_DVD_PLAYER = @"DVD_PLAYER";
NSString *const ROOT_DIRECTORY_TYPE_DIRECTORY = @"DIRECTORY";
NSString *const ROOT_DIRECTORY_TYPE_WINDOWS_SHORTCUT_DIRECTORY = @"WINDOWS_SHORTCUT_DIRECTORY";
NSString *const ROOT_DIRECTORY_TYPE_UNIX_SYMBOLIC_LINK_DIRECTORY = @"UNIX_SYMBOLIC_LINK_DIRECTORY";
NSString *const ROOT_DIRECTORY_TYPE_MAC_ALIAS_DIRECTORY = @"MAC_ALIAS_DIRECTORY";
NSString *const ROOT_DIRECTORY_TYPE_TIME_MACHINE = @"TIME_MACHINE";

@implementation Constants {
    
}


@end
