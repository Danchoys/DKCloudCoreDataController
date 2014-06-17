//
//  CDEContactAdditionViewController.m
//  DKCloudCoreDataControllerExample
//
//  Created by Daniil Konoplev on 6/13/14.
//
//

#import "CDEContactAdditionViewController.h"
#import "Contact.h"

@interface CDEContactAdditionViewController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITextField *firstNameTextField;

@property (weak, nonatomic) IBOutlet UITextField *lastNameTextField;

@property (weak, nonatomic) IBOutlet UITextField *phoneTextField;

@end

@implementation CDEContactAdditionViewController

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
    return YES;
}

- (IBAction)cancelButtonPressed:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)doneButtonPressed:(id)sender {
    [self.delegate contactAdditionControllerDidComplete:self];
}

- (IBAction)textFieldEditingChanged:(id)sender {
    NSString *text = [sender text];
    if (sender == self.firstNameTextField)
        self.contact.firstName = text;
    else if (sender == self.lastNameTextField)
        self.contact.lastName = text;
    else if (sender == self.phoneTextField)
        self.contact.phone = text;
}

@end
