#import "AppDelegate+FirebaseMessagingPlugin.h"
#import "FirebaseMessagingPlugin.h"
#import <objc/runtime.h>

static char savedNotificationKey;

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@import UserNotifications;

// Implement UNUserNotificationCenterDelegate to receive display notification via APNS for devices
// running iOS 10 and above. Implement FIRMessagingDelegate to receive data message via FCM for
// devices running iOS 10 and above.
@interface AppDelegate () <UNUserNotificationCenterDelegate, FIRMessagingDelegate>
@end
#endif

#define kApplicationInBackgroundKey @"applicationInBackground"

@implementation AppDelegate (FirebaseMessagingPlugin)

- (void)postNotification:(NSDictionary*)userInfo background:(BOOL)background {

    NSDictionary *mutableUserInfo = [userInfo mutableCopy];

    NSLog(@"FirebaseMessagingDelegate postNotification %@", mutableUserInfo);

    if (background) {

        if( FirebaseMessagingPlugin.firebaseMessagingPlugin )
        {
            [FirebaseMessagingPlugin.firebaseMessagingPlugin sendBackgroundNotification:mutableUserInfo];
        }
        else
        {
            NSLog(@"FirebaseMessagingDelegate saving notification");
            self.savedNotification = mutableUserInfo;
        }

    } else {
        [FirebaseMessagingPlugin.firebaseMessagingPlugin sendNotification:mutableUserInfo];
    }
}

+ (void)load {
    Method original = class_getInstanceMethod(self, @selector(application:didFinishLaunchingWithOptions:));
    Method swizzled = class_getInstanceMethod(self, @selector(application:swizzledDidFinishLaunchingWithOptions:));
    method_exchangeImplementations(original, swizzled);
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {

    if( self.savedNotification )
    {
        [self postNotification:self.savedNotification background:YES];
    }
}

- (BOOL)application:(UIApplication *)application swizzledDidFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // [START set_messaging_delegate]
    [FIRMessaging messaging].delegate = self;
    // [END set_messaging_delegate]

    NSDictionary *userInfo = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];

    if (userInfo) {
        [self postNotification:userInfo background:YES];
    }

    return [self application:application swizzledDidFinishLaunchingWithOptions:launchOptions];
}

// [START receive_message]
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    BOOL value = application.applicationState != UIApplicationStateActive;

    [self postNotification:userInfo background:value];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
    fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    BOOL value = application.applicationState != UIApplicationStateActive;

    [self postNotification:userInfo background:value];

    completionHandler(UIBackgroundFetchResultNewData);
}
// [END receive_message]

// [START ios_10_message_handling]
// Receive displayed notifications for iOS 10 devices.
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
// Handle incoming notification messages while app is in the foreground.
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    NSDictionary *userInfo = notification.request.content.userInfo;

    [self postNotification:userInfo background:NO];
    // Change this to your preferred presentation option
    completionHandler(UNNotificationPresentationOptionNone);
}

// Handle notification messages after display notification is tapped by the user.
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)())completionHandler {
    NSDictionary *userInfo = response.notification.request.content.userInfo;

    [self postNotification:userInfo background:YES];

    completionHandler();
}
#endif
// [END ios_10_message_handling]

// [START refresh_token]
- (void)messaging:(nonnull FIRMessaging *)messaging didRefreshRegistrationToken:(nonnull NSString *)fcmToken {
    // Note that this callback will be fired everytime a new token is generated, including the first
    // time. So if you need to retrieve the token as soon as it is available this is where that
    // should be done.
    NSLog(@"FirebaseMessagingDelegate refreshed token: %@", fcmToken);

    [FirebaseMessagingPlugin.firebaseMessagingPlugin refreshToken:fcmToken];
}
// [END refresh_token]

// [START ios_10_data_message]
// Receive data messages on iOS 10+ directly from FCM (bypassing APNs) when the app is in the foreground.
// To enable direct data messages, you can set [Messaging messaging].shouldEstablishDirectChannel to YES.
- (void)messaging:(FIRMessaging *)messaging didReceiveMessage:(FIRMessagingRemoteMessage *)remoteMessage {
    NSDictionary *userInfo = remoteMessage.appData;

    NSLog(@"FirebaseMessagingDelegate Received data message: %@", userInfo);

    [FirebaseMessagingPlugin.firebaseMessagingPlugin sendNotification:userInfo];
}
// [END ios_10_data_message]

/*
- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    FirebaseMessagingPlugin* fmPlugin = [self.viewController getCommandInstance:@"FirebaseMessaging"];

    [fmPlugin registerNotifications:nil];
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSString *)deviceToken {
    FirebaseMessagingPlugin* fmPlugin = [self.viewController getCommandInstance:@"FirebaseMessaging"];

    [fmPlugin registerNotifications:deviceToken];
}
*/

// [START register_token]
- (void)messaging:(FIRMessaging *)messaging didReceiveRegistrationToken:(NSString *)fcmToken {
    // Note that this callback will be fired everytime a new token is generated, including the first
    // time. So if you need to retrieve the token as soon as it is available this is where that
    // should be done.
    NSLog(@"FirebaseMessagingDelegate registration token: %@", fcmToken);

    [FirebaseMessagingPlugin.firebaseMessagingPlugin registerNotifications:fcmToken];
}
// [END register_token]


- (NSMutableArray *)savedNotification
{
    return objc_getAssociatedObject(self, &savedNotificationKey);
}

- (void)setSavedNotification:(NSDictionary *)aDictionary
{
    objc_setAssociatedObject(self, &savedNotificationKey, aDictionary, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)dealloc
{
    self.savedNotification = nil;
}

@end
