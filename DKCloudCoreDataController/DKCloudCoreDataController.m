//
//  DKCloudCoreDataController.m
//  DKCloudCoreDataController
//
//  Created by Daniil Konoplev on 19.03.14.
//
//

#import "DKCloudCoreDataController.h"

#define IS_iOS_7_AND_LATER (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
#define NEEDS_ASYNCHRONOUS_SETUP !IS_iOS_7_AND_LATER
#define NEW_API_AVAILABLE IS_iOS_7_AND_LATER

static void DKLog(NSString *format, ...)
{
    va_list argp;
    va_start(argp, format);
    NSLogv([NSString stringWithFormat:@"DKCloudCoreDataController: %@", format], argp);
    va_end(argp);
}

// Option keys
NSString *const DKCloudCoreDataControllerUbiquitousStoreConfigurationKey = @"_DKCloudCoreDataControllerUbiquitousStoreConfigurationKey";
NSString *const DKCloudCoreDataControllerUbiquityContainerIdentifierKey = @"_DKCloudCoreDataControllerUbiquityContainerIdentifierKey";
NSString *const DKCloudCoreDataControllerUbiquityContainerSubdirectoryKey = @"_DKCloudCoreDataControllerUbiquityContainerSubdirectoryKey";
NSString *const DKCloudCoreDataControllerLocalStoreConfigurationKey = @"_DKCloudCoreDataControllerLocalStoreConfigurationKey";
NSString *const DKCloudCoreDataControllerLocalStoreNameKey = @"_DKCloudCoreDataControllerLocalStoreNameKey";
NSString *const DKCloudCoreDataControllerLibrarySubdirectoryKey = @"_DKCloudCoreDataControllerLibrarySubdirectoryKey";

// Notification names
NSString *const DKCloudCoreDataControllerStoreWillChangeNotification = @"_DKCloudCoreDataControllerStoreWillChangeNotification";
NSString *const DKCloudCoreDataControllerStoreDidChangeNotification = @"_DKCloudCoreDataControllerStoreDidChangeNotification";
NSString *const DKCloudCoreDataControllerDidImportChangesNotification = @"_DKCloudCoreDataControllerDidImportChangesNotification";

// String constants
static NSString *const kDefaultUbiquityContainerSubdirectoryName = @"PersistentStoreLogs";
static NSString *const kDefaultLibrarySubdirectoryName = @"PersistentStores";
static NSString *const kDefaultLocalStoreName = @"localStore";
static NSString *const kDefaultNoAccountDirectoryName = @"NoAccount";
static NSString *const kDefaultFallbackDirectoryName = @"Fallback";
static NSString *const kDefaultCloudStoreDirectoryName = @"Cloud";
static NSString *const kUniqueAttributeNameKey = @"_kUniqueAttributeNameKey";
static NSString *const kUniqueAttributeValuesKey = @"_kUniqueAttributeValuesKey";

typedef enum : NSUInteger {
    DKCloudCoreDataControllerUbiquitousStoreTypeNone = 0,
    DKCloudCoreDataControllerUbiquitousStoreTypeNoAccount,
    DKCloudCoreDataControllerUbiquitousStoreTypeFallback,
    DKCloudCoreDataControllerUbiquitousStoreTypeCloud,
} DKCloudCoreDataControllerUbiquitousStoreType;

@interface DKCloudCoreDataController () {
    id _currentUbiquityToken;
    
    NSString *_ubiquitousContentName;
    NSDictionary *_options;
    NSURL *_ubiquityContainerURL;
    
    NSManagedObjectModel *_managedObjectModel;
    NSPersistentStoreCoordinator *_mainPersistentStoreCoordinator;
}

@property (nonatomic, readonly, getter = isICloudAvailable) BOOL iCloudAvailable;

@property (nonatomic) DKCloudCoreDataControllerUbiquitousStoreType currentUbiquitousStoreType;

@end

@implementation DKCloudCoreDataController

#pragma mark -
#pragma mark - Ctors

- (id)initWithUbiquitousContentName:(NSString *)ubiquitousContentName options:(NSDictionary *)options
{
    self = [super init];
    if (self) {
        // Check if both the unquitous content name is defined.
        // If not, we will return nil from the ctor.
        if (ubiquitousContentName && ubiquitousContentName.length > 0) {
            NSMutableDictionary *defaultOptions = [@{DKCloudCoreDataControllerUbiquityContainerSubdirectoryKey: kDefaultUbiquityContainerSubdirectoryName,
                                                     DKCloudCoreDataControllerLocalStoreNameKey: kDefaultLocalStoreName,
                                                     DKCloudCoreDataControllerLibrarySubdirectoryKey: kDefaultLibrarySubdirectoryName} mutableCopy];
            
            // Copy passed options into default options
            for (NSString *key in options)
                if ([options[key] length] > 0)
                    defaultOptions[key] = options[key];
            
            // Save the parameters passed
            _ubiquitousContentName = ubiquitousContentName;
            _options = defaultOptions;
            
            // Set default batch size
            _batchSize = 100;
            
            // Create the Core Data stack objects
            _managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];
            _mainPersistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:_managedObjectModel];
            _mainThreadContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
            [_mainThreadContext setPersistentStoreCoordinator:_mainPersistentStoreCoordinator];
            
            // Get the current ubiquity token
            _currentUbiquityToken = [[NSFileManager defaultManager] ubiquityIdentityToken];
            
            // Subscribe to the events
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(ubiquityIdentityDidChange:)
                                                         name:NSUbiquityIdentityDidChangeNotification
                                                       object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(didImportUbiquitousContentChanges:)
                                                         name:NSPersistentStoreDidImportUbiquitousContentChangesNotification
                                                       object:_mainPersistentStoreCoordinator];
            
            // If we don't have access to the new API and handle
            // stores manually, we need to track when our app
            // enters background to update the fallback store with
            // the iCloud store.
            if (!NEW_API_AVAILABLE)
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(applicationDidEnterBackground:)
                                                             name:UIApplicationDidEnterBackgroundNotification
                                                           object:nil];
            // We only want to listen for this notifications if
            // we are running under iOS 7 and later, where there
            // is an internal fallback store and we need to refetch
            // when the persistent store changes.
            if (!NEEDS_ASYNCHRONOUS_SETUP) {
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(storesWillChange:)
                                                             name:NSPersistentStoreCoordinatorStoresWillChangeNotification
                                                           object:_mainPersistentStoreCoordinator];
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(storesDidChange:)
                                                             name:NSPersistentStoreCoordinatorStoresDidChangeNotification
                                                           object:_mainPersistentStoreCoordinator];
            }
        } else
            self = nil;
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -
#pragma mark - Properties

- (BOOL)isICloudAvailable
{
    return _currentUbiquityToken != nil;
}

#pragma mark -
#pragma mark - Public API

- (void)loadPersistentStores
{
    if (self.delegate) {
        [self loadLocalStore];
        [self loadUbiquitousStore];
    } else
        DKLog(@"Warning: you need to set delegate prior to loading persistent stores");
}

#pragma mark -
#pragma mark - Store loading

- (void)loadLocalStore
{
    if ([_options[DKCloudCoreDataControllerLocalStoreConfigurationKey] length] > 0) {
        NSError *error;
        NSDictionary *options = @{ NSInferMappingModelAutomaticallyOption : @YES,
                                   NSMigratePersistentStoresAutomaticallyOption : @YES };
        [_mainPersistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                      configuration:_options[DKCloudCoreDataControllerLocalStoreConfigurationKey]
                                                                URL:[self localStoreURL]
                                                            options:options
                                                              error:&error];
        if (error)
            DKLog(@"Error: Could not add local store: %@", error);
        else
            DKLog(@"Loaded local store");
    }
}

- (void)loadUbiquitousStore
{
    DKLog(@"Will load ubiquitous store");
    BOOL finished = YES;
    if (!self.iCloudAvailable) {
        // If iCloud is unavailable, lets load the noAccountStore;
        [self loadNoAccountStore];
    } else {
        if (NEEDS_ASYNCHRONOUS_SETUP) {
            // We need to perform asynchronous setup,
            // which starts with loading the fallback store.
            DKLog(@"Asynchronous setup started");
            finished = NO;
            [self loadFallbackStore];
        } else {
            [self loadCloudStore];
        }
        
        // We may have a NoAccount store with some changes
        // waiting to be merged into the current store.
        if (![self.delegate respondsToSelector:@selector(cloudCoreDataControllerShouldMergeNoAccountStoreIntoCloudStore:)] ||
            [self.delegate cloudCoreDataControllerShouldMergeNoAccountStoreIntoCloudStore:self])
            [self mergeNoAccountStoreIntoCurrentStore];
        
        // If we need the asynchronous setup,
        // lets start a queue and perform setup
        // inside it.
        if (NEEDS_ASYNCHRONOUS_SETUP) {
            dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
            dispatch_async(queue, ^{
                // Create a second persistent store coordinator to load our
                // store into.
                NSManagedObjectModel *managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];
                NSPersistentStoreCoordinator *cloudStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:managedObjectModel];
                [self loadCloudStoreIntoPersistentStoreCoordinator:cloudStoreCoordinator];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    // By this moment we may already have made changes to the fallback store.
                    // Lets merge them into the cloud store on the main thread.
                    NSManagedObjectContext *cloudStoreContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
                    [cloudStoreContext setPersistentStoreCoordinator:cloudStoreCoordinator];
                    
                    // Merge changes and resolve duplicates
                    [self mergeAndResolveDuplicatesFromContext:self.mainThreadContext intoContext:cloudStoreContext];
                    
                    // Now we need to remove the fallback store and add the cloud store instead.
                    // There is a litte hint: our currentUbiquitousStoreType property is now set to be
                    // the fallback store. So -unloadUbiquitousStore will just unload the fallback store
                    // which is desired.
                    [self unloadUbiquitousStore];
                    [self loadCloudStore];
                    
                    DKLog(@"Asynchronous setup finished");
                    [self ubiquitousStoreDidLoad];
                });
            });
        }
    }
    if (finished) [self ubiquitousStoreDidLoad];
}

- (void)loadNoAccountStore
{
    [self loadNoAccountStoreIntoPersistentStoreCoordinator:_mainPersistentStoreCoordinator];
    [self setCurrentUbiquitousStoreType:DKCloudCoreDataControllerUbiquitousStoreTypeNoAccount postNotification:YES];
}

- (void)loadFallbackStore
{
    NSError *error;
    NSDictionary *options = @{ NSInferMappingModelAutomaticallyOption : @YES,
                               NSMigratePersistentStoresAutomaticallyOption : @YES };
    [_mainPersistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                  configuration:_options[DKCloudCoreDataControllerUbiquitousStoreConfigurationKey]
                                                            URL:[self fallbackStoreURL]
                                                        options:options
                                                          error:&error];
    if (error)
        DKLog(@"Error: Could not load fallback store: %@", error);
    else
        DKLog(@"Loaded fallback store");
    [self setCurrentUbiquitousStoreType:DKCloudCoreDataControllerUbiquitousStoreTypeFallback postNotification:YES];
}

- (void)loadCloudStore
{
    [self loadCloudStoreIntoPersistentStoreCoordinator:_mainPersistentStoreCoordinator];
    [self setCurrentUbiquitousStoreType:DKCloudCoreDataControllerUbiquitousStoreTypeCloud postNotification:YES];
}

- (void)loadNoAccountStoreIntoPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator
{
    NSError *error;
    NSDictionary *options = @{ NSInferMappingModelAutomaticallyOption : @YES,
                               NSMigratePersistentStoresAutomaticallyOption : @YES };
    [coordinator addPersistentStoreWithType:NSSQLiteStoreType
                              configuration:_options[DKCloudCoreDataControllerUbiquitousStoreConfigurationKey]
                                        URL:[self noAccountStoreURL]
                                    options:options
                                      error:&error];
    if (error)
        DKLog(@"Error: Could not load no account store: %@", error);
    else
        DKLog(@"Loaded no account store");
}

- (void)loadCloudStoreIntoPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator
{
    NSError *error;
    NSURL *cloudStoreURL = [self cloudStoreURL];
    id ubiquitousContentURL = [self ubiquitousContentURL];
    
    NSMutableDictionary *options = [@{ NSPersistentStoreUbiquitousContentNameKey : _ubiquitousContentName,
                                       NSPersistentStoreUbiquitousContentURLKey : ubiquitousContentURL,
                                       NSInferMappingModelAutomaticallyOption : @YES,
                                       NSMigratePersistentStoresAutomaticallyOption : @YES } mutableCopy];
    
    // If the new API is available, we need to pass the ubiquity container identifier among the options
    // to addPersistentStoreWithType:configuration:URL:options:error:.
    if (NEW_API_AVAILABLE && _options[DKCloudCoreDataControllerUbiquityContainerIdentifierKey])
        options[NSPersistentStoreUbiquitousContainerIdentifierKey] = _options[DKCloudCoreDataControllerUbiquityContainerIdentifierKey];
    
    [coordinator addPersistentStoreWithType:NSSQLiteStoreType
                              configuration:_options[DKCloudCoreDataControllerUbiquitousStoreConfigurationKey]
                                        URL:cloudStoreURL
                                    options:options
                                      error:&error];
    if (error)
        DKLog(@"Error: Could not load cloud store: %@", error);
    else
        DKLog(@"Loaded cloud store");
}

#pragma mark -
#pragma mark - Store loaded

- (void)ubiquitousStoreDidLoad
{
    DKLog(@"Did load ubiquitous store");
}

#pragma mark -
#pragma mark - Store unloading

- (void)unloadUbiquitousStore
{
    DKLog(@"Will unload ubiquitous store");
    NSURL *storeURL = nil;
    switch (self.currentUbiquitousStoreType) {
        case DKCloudCoreDataControllerUbiquitousStoreTypeCloud:
            storeURL = [self cloudStoreURL];
            break;
        case DKCloudCoreDataControllerUbiquitousStoreTypeFallback:
            storeURL = [self fallbackStoreURL];
            break;
        case DKCloudCoreDataControllerUbiquitousStoreTypeNoAccount:
            storeURL = [self noAccountStoreURL];
            break;
        default:
            break;
    }
    if (storeURL) {
        [[NSNotificationCenter defaultCenter] postNotificationName:DKCloudCoreDataControllerStoreWillChangeNotification object:self];
        NSError *error = nil;
        NSPersistentStore *store = [_mainPersistentStoreCoordinator persistentStoreForURL:storeURL];
        if (!store || ![_mainPersistentStoreCoordinator removePersistentStore:store error:&error]) {
            DKLog(@"Error: could not remove persistent store with url: %@\n\tError:%@", storeURL, error);
        }
        self.currentUbiquitousStoreType = DKCloudCoreDataControllerUbiquitousStoreTypeNone;
    }
    DKLog(@"Did unload ubiquitous store");
}

#pragma mark -
#pragma mark - Uniquing

- (void)resolveAllDuplicatesInContext:(NSManagedObjectContext *)context
{
    [context performBlockAndWait:^{
        // Grab all entities in the ubiquitous configuration
        NSArray *ubiquitousEntities = [_mainPersistentStoreCoordinator.managedObjectModel entitiesForConfiguration:_options[DKCloudCoreDataControllerUbiquitousStoreConfigurationKey]];
        
        // For each entity we will be removing duplicates
        for (NSEntityDescription *entity in ubiquitousEntities) {
            NSString *uniqueAttributeName = [self.delegate cloudCoreDataController:self uniqueAttributeNameForEntityWithName:entity.name];
            if (uniqueAttributeName != nil) {
                // Getting the unique attribute
                NSAssert(entity.attributesByName[uniqueAttributeName], @"Assertion failed: attribute %@ not found for the entity %@", uniqueAttributeName, entity.name);
                NSDictionary *dict = @{ kUniqueAttributeNameKey : uniqueAttributeName };
                [self resolveDuplicatesOfEntityWithName:entity.name dictionary:dict inContext:context];
            }
        }
    }];
}

- (void)resolveDuplicatesOfObjectsWithIDs:(NSSet *)objectIDs inContext:(NSManagedObjectContext *)context
{
    [context performBlockAndWait:^{
        NSMutableSet *objects = [NSMutableSet set];
        for (NSManagedObjectID *objectID in objectIDs) {
            NSManagedObject *object = [context objectWithID:objectID];
            [objects addObject:object];
        }
        [self resolveDuplicatesOfObjects:objects inContext:context];
    }];
}

- (void)resolveDuplicatesOfObjects:(NSSet *)objects inContext:(NSManagedObjectContext *)context
{
    [context performBlockAndWait:^{
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        // During the first pass we will determine all the entities
        // involved.
        NSMutableSet *entities = [NSMutableSet set];
        for (NSManagedObject *object in objects)
            [entities addObject:object.entity];
        // During the second pass we will populate dict with only
        // that entities, which have unique attributes.
        for (NSEntityDescription *entity in entities) {
            NSString *uniqueAttributeName = [self.delegate cloudCoreDataController:self uniqueAttributeNameForEntityWithName:entity.name];
            if (uniqueAttributeName) {
                NSAssert(entity.attributesByName[uniqueAttributeName], @"Assertion failed: attribute %@ not found for the entity %@", uniqueAttributeName, entity.name);
                dict[entity.name] = @{kUniqueAttributeNameKey : uniqueAttributeName,
                                      kUniqueAttributeValuesKey : [NSMutableSet set]};
            }
        }
        // During the third pass we will populate dict with unique
        // attribute values from the objects of interest.
        for (NSManagedObject *object in objects) {
            if (dict[object.entity.name]) {
                NSObject *uniqueAttributeValue = [object valueForKey:dict[object.entity.name][kUniqueAttributeNameKey]];
                [dict[object.entity.name][kUniqueAttributeValuesKey] addObject:uniqueAttributeValue];
            }
        }
        
        // Finally resolve duplicates
        for (NSString *entityName in dict) {
            [self resolveDuplicatesOfEntityWithName:entityName dictionary:dict[entityName] inContext:context];
        }
    }];
}

- (void)resolveDuplicatesOfEntityWithName:(NSString *)entityName dictionary:(NSDictionary *)dictionary inContext:(NSManagedObjectContext *)context
{
    @autoreleasepool {
        NSError *error = nil;
        NSEntityDescription *entity = context.persistentStoreCoordinator.managedObjectModel.entitiesByName[entityName];
        NSString *uniqueAttributeName = dictionary[kUniqueAttributeNameKey];
        NSSet *uniqueAttributeValues = dictionary[kUniqueAttributeValuesKey];
        
        // Creating the count expression
        NSExpression *countExpr = [NSExpression expressionWithFormat:@"count:(%K)", uniqueAttributeName];
        NSExpressionDescription *countExprDesc = [[NSExpressionDescription alloc] init];
        countExprDesc.name = @"count";
        countExprDesc.expression = countExpr;
        countExprDesc.expressionResultType = NSInteger64AttributeType;
        
        // Get the attribute description
        NSAttributeDescription *uniqueAttribute = entity.attributesByName[uniqueAttributeName];
        
        // Creating the fetch request to get all objects grouped by the unique attribute
        NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName:entity.name];
        [fr setIncludesPendingChanges:NO];
        [fr setFetchBatchSize:self.batchSize];
        [fr setPropertiesToFetch:@[uniqueAttribute, countExprDesc]];
        [fr setPropertiesToGroupBy:@[uniqueAttribute]];
        [fr setResultType:NSDictionaryResultType];
        // If we have unique attribute values of interest, scope our request by this list
        if (uniqueAttributeValues.count > 0) {
            NSPredicate *scopingPredicate = [NSPredicate predicateWithFormat:@"%K IN %@", uniqueAttributeName, uniqueAttributeValues];
            [fr setPredicate:scopingPredicate];
        }
        
        // Get all attribute values which refer to objects with duplicates
        NSMutableArray *uniqueAttributeValuesWithDups = [NSMutableArray array];
        NSArray *countDictionaries = [context executeFetchRequest:fr error:&error];
        if (!countDictionaries && error)
            DKLog(@"Error: could not execute fetch request: %@", error);
        for (NSDictionary *countDictionary in countDictionaries)
            if ([countDictionary[@"count"] integerValue] > 1)
                [uniqueAttributeValuesWithDups addObject:countDictionary[uniqueAttributeName]];
        
        // Preparing the fetch request to get all duplicate objects
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K IN (%@)", uniqueAttributeName, uniqueAttributeValuesWithDups];
        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:uniqueAttributeName ascending:YES];
        fr = [NSFetchRequest fetchRequestWithEntityName:entity.name];
        [fr setIncludesPendingChanges:NO];
        [fr setPredicate:predicate];
        [fr setSortDescriptors:@[sortDescriptor]];
        [fr setFetchBatchSize:self.batchSize];
        
        // Resolve duplicates
        NSArray *duplicates = [context executeFetchRequest:fr error:&error];
        if (!duplicates && error)
            DKLog(@"Error: could not execute fetch request: %@", error);
        NSString *comparisonAttributeName = [self.delegate cloudCoreDataController:self comparisonAttributeNameForEntityWithName:entity.name];
        NSAssert(entity.attributesByName[comparisonAttributeName], @"Assertion failed: attribute %@ not found for the entity %@", comparisonAttributeName, entity.name);
        NSAssert([NSClassFromString([entity.attributesByName[comparisonAttributeName] attributeValueClassName]) instancesRespondToSelector:@selector(compare:)],
                 @"Assertion failed: attribute %@ of entity %@ cannot be used as a comparison attribute: it must be of one of the following types: NSString, NSNumber, NSDate", comparisonAttributeName, entity.name);
        NSManagedObject *prevObject = nil;
        NSUInteger i = 1;
        for (NSManagedObject *object in duplicates) {
            if (prevObject) {
                if ([[object valueForKey:uniqueAttributeName] isEqual:[prevObject valueForKey:uniqueAttributeName]]) {
                    if ([[object valueForKey:comparisonAttributeName] compare:[prevObject valueForKey:comparisonAttributeName]] == NSOrderedAscending) {
                        [context deleteObject:object];
                    } else {
                        [context deleteObject:prevObject];
                        prevObject = object;
                    }
                } else {
                    prevObject = object;
                }
            } else {
                prevObject = object;
            }
            
            if (0 == (i % self.batchSize)) {
                //save the changes after each batch, this helps control memory pressure by turning previously examined objects back in to faults
                if ([context save:&error]) {
                    DKLog(@"Saved successfully after uniquing");
                } else {
                    DKLog(@"Error saving unique results: %@", error);
                }
            }
            i++;
        }
        
        // Save changes
        if ([context save:&error]) {
            DKLog(@"Saved successfully after uniquing");
        } else {
            DKLog(@"Error saving unique results: %@", error);
        }
    }
}

#pragma mark -
#pragma mark - Private API

- (void)mergeNoAccountStoreIntoCurrentStore
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:[[self noAccountStoreURL] path]]) {
        DKLog(@"Will merge no account store into current store");
        
        NSManagedObjectContext *cloudContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [cloudContext setPersistentStoreCoordinator:_mainPersistentStoreCoordinator];
        
        // Creating the persistent store coordinator for
        // the no account persistent store
        NSManagedObjectModel *managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];
        NSPersistentStoreCoordinator *noAccountCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:managedObjectModel];
        [self loadNoAccountStoreIntoPersistentStoreCoordinator:noAccountCoordinator];
        NSManagedObjectContext *noAccountContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [noAccountContext setPersistentStoreCoordinator:noAccountCoordinator];
        
        // Merge, save and resolve duplicates
        [self mergeAndResolveDuplicatesFromContext:noAccountContext intoContext:cloudContext];
        
        // Perform the cleanup and delete the no account store
        cloudContext = nil;
        noAccountContext = nil;
        noAccountCoordinator = nil;
        [self removeNoAccountStore];
        DKLog(@"Did merge no account store into current store");
        
        // Tell the delegate that the NoAccount store's data was merged into the Cloud store
        if ([self.delegate respondsToSelector:@selector(cloudCoreDataControllerDidMergeNoAccountStoreIntoCloudStore:)])
            [self.delegate cloudCoreDataControllerDidMergeNoAccountStoreIntoCloudStore:self];
    }
}

- (void)mergeAndResolveDuplicatesFromContext:(NSManagedObjectContext *)fromContext intoContext:(NSManagedObjectContext *)toContext
{
    [toContext performBlockAndWait:^{
        [self.delegate cloudCoreDataController:self mergeContext:fromContext intoContext:toContext];
        NSMutableSet *interestingObjects = [NSMutableSet set];
        [interestingObjects unionSet:toContext.insertedObjects];
        [interestingObjects unionSet:toContext.updatedObjects];
        [self saveContext:toContext];
        [self resolveDuplicatesOfObjects:interestingObjects inContext:toContext];
    }];
}

- (void)saveMainThreadContext
{
    [self saveContext:self.mainThreadContext];
}

- (void)saveContext:(NSManagedObjectContext *)context
{
    [context performBlockAndWait:^{
        NSError *error;
        if (![context save:&error]) {
            DKLog(@"Error: Could not save context: %@", error);
        }
    }];
}

- (void)invalidateUbiquityContainerURL
{
    _ubiquityContainerURL = nil;
}

- (void)setCurrentUbiquitousStoreType:(DKCloudCoreDataControllerUbiquitousStoreType)ubiquitousStoreType postNotification:(BOOL)shouldPostNotification
{
    self.currentUbiquitousStoreType = ubiquitousStoreType;
    if (shouldPostNotification)
        [[NSNotificationCenter defaultCenter] postNotificationName:DKCloudCoreDataControllerStoreDidChangeNotification object:self];
}

- (void)removeNoAccountStore
{
    NSAssert(self.currentUbiquitousStoreType != DKCloudCoreDataControllerUbiquitousStoreTypeNoAccount, @"Assertion failed: store cannot be removed if it is loaded into the main coordinator");
    [self removeStoreAtURL:[self noAccountStoreURL]];
}

- (void)removeFallbackStore
{
    NSAssert(self.currentUbiquitousStoreType != DKCloudCoreDataControllerUbiquitousStoreTypeFallback, @"Assertion failed: store cannot be removed if it is loaded into the main coordinator");
    [self removeStoreAtURL:[self fallbackStoreURL]];
}

- (void)removeCloudStore
{
    NSAssert(self.currentUbiquitousStoreType != DKCloudCoreDataControllerUbiquitousStoreTypeCloud, @"Assertion failed: store cannot be removed if it is loaded into the main coordinator");
    [self removeStoreAtURL:[self cloudStoreURL]];
}

- (void)removeStoreAtURL:(NSURL *)url
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:[url path]]) {
        NSError *error = nil;
        if (![[NSFileManager defaultManager] removeItemAtURL:url error:&error]) {
            DKLog(@"Could not remove the store at path: %@\n\tError: %@", url.path, error);
        }
    }
}

- (void)createDirectoryIfNeededWithURL:(NSURL *)url
{
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    if (![fileManager fileExistsAtPath:[url path]]) {
        NSError *error;
        if (![fileManager createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:&error])
            DKLog(@"Error: Could not create path: %@\n\tError: %@,", [url path], error);
    }
}

#pragma mark -
#pragma mark - Notification handlers

- (void)ubiquityIdentityDidChange:(NSNotification *)notification
{
    // Get the new ubiquity identity token
    id oldUbiquityToken = _currentUbiquityToken;
    _currentUbiquityToken = [[NSFileManager defaultManager] ubiquityIdentityToken];
    
    // If new API is available then the system will handle
    // such transitions for us. The only difference happens
    // when we transition between iCloud and NoAccount stores
    // since we provide our own store for the case of iCloud
    // being not available.
    if (NEEDS_ASYNCHRONOUS_SETUP || ((!oldUbiquityToken|| !_currentUbiquityToken) && oldUbiquityToken != _currentUbiquityToken)) {
        // We need to unload the current ubiquitous store first
        [self unloadUbiquitousStore];
        
        // Lets remove the account-specific stores
        [self removeFallbackStore];
        [self removeCloudStore];
        
        // Invalidate current ubiquity container URL
        [self invalidateUbiquityContainerURL];
        
        // After all we must load the store
        [self loadUbiquitousStore];
    }
}

- (void)didImportUbiquitousContentChanges:(NSNotification *)notification
{
    [self.mainThreadContext mergeChangesFromContextDidSaveNotification:notification];
    NSMutableSet *interestingObjectIDs = [NSMutableSet set];
    // Updating and inserting could potentially cause introduction
    // of duplicates, so we must resolve duplicates.
    [interestingObjectIDs unionSet:notification.userInfo[NSInsertedObjectsKey]];
    [interestingObjectIDs unionSet:notification.userInfo[NSUpdatedObjectsKey]];
    [self resolveDuplicatesOfObjectsWithIDs:interestingObjectIDs inContext:self.mainThreadContext];
    // Send notification that we have imported new content
    [[NSNotificationCenter defaultCenter] postNotificationName:DKCloudCoreDataControllerDidImportChangesNotification object:self];
}

- (void)storesWillChange:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] postNotificationName:DKCloudCoreDataControllerStoreWillChangeNotification object:self];
}

- (void)storesDidChange:(NSNotification *)notification
{
    NSNumber *transitionType = notification.userInfo[NSPersistentStoreUbiquitousTransitionTypeKey];
    if (transitionType) {
        if (transitionType.integerValue == NSPersistentStoreUbiquitousTransitionTypeInitialImportCompleted)
            [self resolveAllDuplicatesInContext:self.mainThreadContext];
        [[NSNotificationCenter defaultCenter] postNotificationName:DKCloudCoreDataControllerStoreDidChangeNotification object:self];
    }
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    // When our app enters background it's a good idea to
    // save our context and copy the cloud store (if available)
    // to the fallback store.
    if (self.currentUbiquitousStoreType == DKCloudCoreDataControllerUbiquitousStoreTypeCloud) {
        NSError *error = nil;
        [self saveMainThreadContext];
        NSURL *cloudStoreURL = [self cloudStoreURL];
        NSURL *fallbackStoreURL = [self fallbackStoreURL];
        [self removeFallbackStore];
        if (![[NSFileManager defaultManager] copyItemAtURL:cloudStoreURL toURL:fallbackStoreURL error:&error]) {
            DKLog(@"Error: could not copy cloud store to the fallback store: %@", error);
        }
    }
}

#pragma mark -
#pragma mark - URLs

- (NSURL *)cloudStoreURL
{
    NSURL *url = [self sandboxPersistentStoresURL];
    url = [url URLByAppendingPathComponent:kDefaultCloudStoreDirectoryName isDirectory:YES];
    
    // Create the path if it does not exist
    [self createDirectoryIfNeededWithURL:url];
    
    return [[url URLByAppendingPathComponent:_ubiquitousContentName] URLByAppendingPathExtension:@"sqlite"];
}

- (NSURL *)fallbackStoreURL
{
    NSURL *url = [self sandboxPersistentStoresURL];
    url = [url URLByAppendingPathComponent:kDefaultFallbackDirectoryName isDirectory:YES];
    
    // Create the path if it does not exist
    [self createDirectoryIfNeededWithURL:url];
    
    return [[url URLByAppendingPathComponent:_ubiquitousContentName] URLByAppendingPathExtension:@"sqlite"];
}

- (NSURL *)noAccountStoreURL
{
    NSURL *url = [self sandboxPersistentStoresURL];
    url = [url URLByAppendingPathComponent:kDefaultNoAccountDirectoryName isDirectory:YES];
    
    // Create the path if it does not exist
    [self createDirectoryIfNeededWithURL:url];
    
    return [[url URLByAppendingPathComponent:_ubiquitousContentName] URLByAppendingPathExtension:@"sqlite"];
}

- (NSURL *)localStoreURL
{
    NSURL *url = [self sandboxPersistentStoresURL];
    
    NSString *localStoreName = _options[DKCloudCoreDataControllerLocalStoreNameKey];
    
    return [[url URLByAppendingPathComponent:localStoreName] URLByAppendingPathExtension:@"sqlite"];
}

#pragma mark -

- (id)ubiquitousContentURL
{
    id retVal = nil;
    
    // Get the ubiquity container's subdirectory name
    NSString *containerSubdirectory = _options[DKCloudCoreDataControllerUbiquityContainerSubdirectoryKey];
    
    if (NEW_API_AVAILABLE) {
        retVal = containerSubdirectory;
    } else {
        NSURL *url = [self ubiquityContainerURL];
        NSAssert(url, @"Assertion failed: Ubiquity container's url is nil!");
        
        url = [url URLByAppendingPathComponent:containerSubdirectory isDirectory:YES];
        
        // Create the path if it does not exist
        [self createDirectoryIfNeededWithURL:url];
        
        retVal = url;
    }
    
    return retVal;
}

- (NSURL *)sandboxPersistentStoresURL
{
    NSURL *url = [self libraryDirectoryURL];
    
    NSString *librarySubdirectory = _options[DKCloudCoreDataControllerLibrarySubdirectoryKey];
    
    url = [url URLByAppendingPathComponent:librarySubdirectory isDirectory:YES];
    
    // Create the path if it does not exist
    [self createDirectoryIfNeededWithURL:url];
    
    return url;
}

#pragma mark -

- (NSURL *)libraryDirectoryURL
{
    return [NSURL fileURLWithPath:[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject] isDirectory:YES];
}

- (NSURL *)ubiquityContainerURL
{
    if (!_ubiquityContainerURL) {
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        _ubiquityContainerURL = [fileManager URLForUbiquityContainerIdentifier:_options[DKCloudCoreDataControllerUbiquityContainerIdentifierKey]];
    }
    return _ubiquityContainerURL;
}

@end
