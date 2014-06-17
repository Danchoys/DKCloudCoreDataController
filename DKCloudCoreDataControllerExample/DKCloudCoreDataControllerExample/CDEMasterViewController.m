//
//  CDEMasterViewController.m
//  DKCloudCoreDataControllerExample
//
//  Created by Daniil Konoplev on 6/13/14.
//
//

#import "CDEMasterViewController.h"
#import "CDEContactAdditionViewController.h"
#import "CDEAppDelegate.h"
#import "Contact.h"
#import <CoreData/CoreData.h>

static NSString *const kAdditionControllerSegueIdentifier = @"Addition controller segue";
static NSString *const kCellReuseIdentifier = @"Cell";

@interface CDEMasterViewController () <CDEContactAdditionControllerDelegate, NSFetchedResultsControllerDelegate>

@property (nonatomic, readonly) NSManagedObjectContext *mainThreadContext;

@property (nonatomic, strong) NSManagedObjectContext *contactAdditionContext;

@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsContoller;

@end

@implementation CDEMasterViewController

#pragma mark - Props

- (NSManagedObjectContext *)mainThreadContext
{
    CDEAppDelegate *appDelegate = (CDEAppDelegate *)[[UIApplication sharedApplication] delegate];
    return appDelegate.mainThreadContext;
}

#pragma mark - View controller view's lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSError *error;
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Contact"];
    fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO]];
    
    self.fetchedResultsContoller = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                       managedObjectContext:self.mainThreadContext
                                                                         sectionNameKeyPath:nil
                                                                                  cacheName:nil];
    self.fetchedResultsContoller.delegate = self;
    [self.fetchedResultsContoller performFetch:&error];
    if (error)
        NSLog(@"Error: could not perform fetch: %@", error);
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [[self.fetchedResultsContoller sections] count];
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    if ([[self.fetchedResultsContoller sections] count] > 0) {
        id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsContoller sections] objectAtIndex:section];
        return [sectionInfo numberOfObjects];
    } else
        return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:kCellReuseIdentifier forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

#pragma mark - Private API

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    Contact *contact = [self.fetchedResultsContoller objectAtIndexPath:indexPath];
    cell.textLabel.text = contact.firstName;
}

#pragma mark - Fetched results controller delegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}


- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {
    
    UITableView *tableView = self.tableView;
    
    switch(type) {
            
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath]
                    atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}


- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView endUpdates];
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:kAdditionControllerSegueIdentifier]) {
        UINavigationController *navigationController = segue.destinationViewController;
        CDEContactAdditionViewController *controller = navigationController.viewControllers[0];
        controller.delegate = self;
        
        // Creating child context which will be saved only if the controller returns with completion
        self.contactAdditionContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [self.contactAdditionContext setParentContext:self.mainThreadContext];
        controller.contact = [NSEntityDescription insertNewObjectForEntityForName:@"Contact"
                                                         inManagedObjectContext:self.mainThreadContext];
    }
}

#pragma mark - Contact addition controller delegate

- (void)contactAdditionControllerDidComplete:(CDEContactAdditionViewController *)controller
{
    NSError *error;
    Contact *contact = controller.contact;
    contact.timestamp = [NSDate date];
    
    if (![self.contactAdditionContext save:&error])
        NSLog(@"Error saving context: %@", error);
    else if (![self.mainThreadContext save:&error])
        NSLog(@"Error saving context: %@", error);
    else
        NSLog(@"Contexts saved successfully");
    
    self.contactAdditionContext = nil;
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
