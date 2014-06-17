//
//  Contact.h
//  DKCloudCoreDataControllerExample
//
//  Created by Daniil Konoplev on 6/13/14.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Contact : NSManagedObject

@property (nonatomic, retain) NSString * firstName;
@property (nonatomic, retain) NSString * lastName;
@property (nonatomic, retain) NSString * phone;
@property (nonatomic, retain) NSDate * timestamp;

@end
