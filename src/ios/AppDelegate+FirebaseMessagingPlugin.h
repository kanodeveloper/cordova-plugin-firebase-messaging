#import "AppDelegate.h"

@import Firebase;

@interface AppDelegate (FirebaseMessagingPlugin) <FIRMessagingDelegate>

- (void)postNotification:(NSDictionary*) userInfo background:(BOOL) value;

@property (nonatomic, retain) NSDictionary* savedNotification;

@end
