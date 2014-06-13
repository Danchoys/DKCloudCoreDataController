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
 of the attribute has to be one of these: NSString, NSNumber, NSDate.
 */
- (NSString *)cloudCoreDataController:(DKCloudCoreDataController *)controller comparisonAttributeNameForEntityWithName:(NSString *)entityName;

@optional

/**
 This method is called when the iCloud store becomes available. Return YES if you want
 to merge data from no-account store into the iCloud store. After the data is merged, no-account store
 is removed. Return NO to leave the no-account store untouched. Default behaviour is YES.
 */
- (BOOL)cloudCoreDataControllerShouldMergeNoAccountStoreIntoCloudStore:(DKCloudCoreDataController *)controller;

/**
 Use this method to notify the user that his data from the no-account store has been merged into the Cloud store and that
 it will not be available when he logs off from his current iCloud account.
 */
- (void)cloudCoreDataControllerDidMergeNoAccountStoreIntoCloudStore:(DKCloudCoreDataController *)controller;

@end

@interface DKCloudCoreDataController : NSObject

@property (nonatomic, readonly) NSManagedObjectContext *mainThreadContext;

@property (nonatomic, weak) id<DKCloudCoreDataControllerDelegate> delegate;

@property (nonatomic) NSUInteger batchSize;

// Designated initializer
- (instancetype)initWithUbiquitousContentName:(NSString *)ubiquitousContentName
                                      options:(NSDictionary *)options;

/**
 Loads persistent store. Call this method once after you specify delegate.
 */
- (void)loadPersistentStores;

@end

// Possible keys for the options dictionary
FOUNDATION_EXTERN NSString *const DKCloudCoreDataControllerUbiquitousStoreConfigurationKey;     // Name of the ubiquitous store Core Data configuration
FOUNDATION_EXTERN NSString *const DKCloudCoreDataControllerUbiquityContainerIdentifierKey;      // Ubiquity container identifier
FOUNDATION_EXTERN NSString *const DKCloudCoreDataControllerUbiquityContainerSubdirectoryKey;    // Name of the subdirectory inside ubiquity container for log files
FOUNDATION_EXTERN NSString *const DKCloudCoreDataControllerLocalStoreConfigurationKey;          // Name of the local store Core Data configuration
FOUNDATION_EXTERN NSString *const DKCloudCoreDataControllerLocalStoreNameKey;                   // Name of the local store file
FOUNDATION_EXTERN NSString *const DKCloudCoreDataControllerLibrarySubdirectoryKey;              // Name of the subdirectory inside Library directory

// Notification names
FOUNDATION_EXTERN NSString *const DKCloudCoreDataControllerStoreWillChangeNotification;
FOUNDATION_EXTERN NSString *const DKCloudCoreDataControllerStoreDidChangeNotification;
FOUNDATION_EXTERN NSString *const DKCloudCoreDataControllerDidImportChangesNotification;

