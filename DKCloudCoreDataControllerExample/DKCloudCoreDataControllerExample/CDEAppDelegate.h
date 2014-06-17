//
//  CDEAppDelegate.h
//  DKCloudCoreDataControllerExample
//
//  Created by Daniil Konoplev on 6/13/14.
//
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface CDEAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (nonatomic, readonly) NSManagedObjectContext *mainThreadContext;

@end
