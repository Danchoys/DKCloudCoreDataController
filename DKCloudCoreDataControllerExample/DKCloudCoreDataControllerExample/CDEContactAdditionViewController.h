//
//  CDEContactAdditionViewController.h
//  DKCloudCoreDataControllerExample
//
//  Created by Daniil Konoplev on 6/13/14.
//
//

#import <UIKit/UIKit.h>

@class Contact, CDEContactAdditionViewController;

@protocol CDEContactAdditionControllerDelegate <NSObject>

- (void)contactAdditionControllerDidComplete:(CDEContactAdditionViewController *)controller;

@end

@interface CDEContactAdditionViewController : UITableViewController

@property (nonatomic, weak) id<CDEContactAdditionControllerDelegate> delegate;

@property (nonatomic, strong) Contact *contact;

@end
