//
//  CDEAppDelegate.m
//  DKCloudCoreDataControllerExample
//
//  Created by Daniil Konoplev on 6/13/14.
//
//

#import "CDEAppDelegate.h"
#import <DKCloudCoreDataController/DKCloudCoreDataController.h>
#import "Contact.h"

@interface CDEAppDelegate () <DKCloudCoreDataControllerDelegate>

@property (nonatomic, strong) DKCloudCoreDataController *cloudCoreDataController;

@end

@implementation CDEAppDelegate

#pragma mark - Props

- (NSManagedObjectContext *)mainThreadContext
{
    return self.cloudCoreDataController.mainThreadContext;
}

#pragma mark - App callbacks

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.cloudCoreDataController = [[DKCloudCoreDataController alloc] initWithUbiquitousContentName:@"Store" options:nil];
    self.cloudCoreDataController.delegate = self;
    [self.cloudCoreDataController loadPersistentStores];
    // Override point for customization after application launch.
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark - Core Data controller delegate

- (void)cloudCoreDataController:(DKCloudCoreDataController *)controller
                   mergeContext:(NSManagedObjectContext *)fromContext
                    intoContext:(NSManagedObjectContext *)toContext
{
    NSError *error;
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Contact"];
    NSArray *contacts = [fromContext executeFetchRequest:request error:&error];
    if (!contacts && error)
        NSLog(@"Error: could not execute fetch request: %@", error);
    else {
        for (Contact *contact in contacts) {
            Contact *contactCopy = [NSEntityDescription insertNewObjectForEntityForName:@"Contact"
                                                                 inManagedObjectContext:toContext];
            contactCopy.firstName = contact.firstName;
            contactCopy.lastName = contact.lastName;
            contactCopy.timestamp = contact.timestamp;
            contactCopy.phone = contact.phone;
        }
    }
}

- (NSString *)cloudCoreDataController:(DKCloudCoreDataController *)controller uniqueAttributeNameForEntityWithName:(NSString *)entityName
{
    if ([entityName isEqualToString:@"Contact"])
        return @"phone";
    return nil;
}

- (NSString *)cloudCoreDataController:(DKCloudCoreDataController *)controller comparisonAttributeNameForEntityWithName:(NSString *)entityName
{
    if ([entityName isEqualToString:@"Contact"])
        return @"timestamp";
    return nil;
}

@end
