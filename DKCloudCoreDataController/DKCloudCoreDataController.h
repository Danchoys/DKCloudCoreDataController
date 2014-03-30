//
//  DKCloudCoreDataController.h
//  DKCloudCoreDataController
//
//  Created by Daniil Konoplev on 19.03.14.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DKCloudCoreDataController;

@protocol DKCloudCoreDataControllerDelegate <NSObject>

@required

/**
 This method is used to merge data from one context into another. You typically have to iterate through
 data inside the fromContext and create same objects inside the toContext. You shouldn't worry much about possible
 duplicates: the controller will perform duplicate resolving itself after this method is executed.
 */
- (void)cloudCoreDataController:(DKCloudCoreDataController *)controller
                   mergeContext:(NSManagedObjectContext *)fromContext
                    intoContext:(NSManagedObjectContext *)toContext;

/**
 From this method you need to return the attribute name which uniquely identifies an object of the given entity. If
 this entity does not have unique attributes, you need to return nil.
 */
- (NSString *)cloudCoreDataController:(DKCloudCoreDataController *)controller uniqueAttributeNameForEntityWithName:(NSString *)entityName;

/**
 From this method you need to return the attribute name which allows for comparing objects of the given entity. The type
 of the attribute has to be one of this: NSString, NSNumber, NSDate.
 */
- (NSString *)cloudCoreDataController:(DKCloudCoreDataController *)controller comparisonAttributeNameForEntityWithName:(NSString *)entityName;

@optional

/**
 Use this method to notify the user that his data from the NoAccount store has been merged into the Cloud store and that
 it is no longer available when he logs off from his current iCloud account.
 */
- (void)cloudCoreDataControllerDidMergeNoAccountStoreIntoCloudStore:(DKCloudCoreDataController *)controller;

@end

@interface DKCloudCoreDataController : NSObject

@property (nonatomic, readonly) NSManagedObjectContext *mainThreadContext;

@property (nonatomic, weak) id<DKCloudCoreDataControllerDelegate> delegate;

@property (nonatomic) NSUInteger batchSize;

- (instancetype)initWithUbiquitousContentName:(NSString *)ubiquitousContentName
                                      options:(NSDictionary *)options;
- (void)loadPersistentStores;

@end

// Possible keys for the options dictionary
FOUNDATION_EXTERN NSString *const DKCloudCoreDataControllerUbiquitousStoreConfigurationKey;
FOUNDATION_EXTERN NSString *const DKCloudCoreDataControllerUbiquityContainerIdentifierKey;
FOUNDATION_EXTERN NSString *const DKCloudCoreDataControllerUbiquityContainerSubdirectoryKey;
FOUNDATION_EXTERN NSString *const DKCloudCoreDataControllerLocalStoreConfigurationKey;
FOUNDATION_EXTERN NSString *const DKCloudCoreDataControllerLocalStoreNameKey;
FOUNDATION_EXTERN NSString *const DKCloudCoreDataControllerLibrarySubdirectoryKey;

// Notification names
FOUNDATION_EXTERN NSString *const DKCloudCoreDataControllerStoreWillChangeNotification;
FOUNDATION_EXTERN NSString *const DKCloudCoreDataControllerStoreDidChangeNotification;
FOUNDATION_EXTERN NSString *const DKCloudCoreDataControllerDidImportChangesNotification;

