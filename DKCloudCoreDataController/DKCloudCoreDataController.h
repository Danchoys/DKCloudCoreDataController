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

- (void)cloudCoreDataController:(DKCloudCoreDataController *)controller
                   mergeContext:(NSManagedObjectContext *)fromContext
                    intoContext:(NSManagedObjectContext *)toContext;

- (NSString *)cloudCoreDataController:(DKCloudCoreDataController *)controller uniqueAttributeNameForEntityWithName:(NSString *)enityName;

- (NSString *)cloudCoreDataController:(DKCloudCoreDataController *)controller comparisonAttributeNameForEntityWithName:(NSString *)enityName;

@optional

- (NSString *)cloudCoreDataControllerDidMergeNoAccountStoreIntoCloudStore:(DKCloudCoreDataController *)controller;

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

FOUNDATION_EXTERN NSString *const DKCloudCoreDataControllerStoreWillChangeNotification;
FOUNDATION_EXTERN NSString *const DKCloudCoreDataControllerStoreDidChangeNotification;

