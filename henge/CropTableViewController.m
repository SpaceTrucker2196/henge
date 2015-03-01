//
//  MasterViewController.m
//  henge
//
//  Created by Jeff Kunzelman on 1/28/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import "CropTableViewController.h"
#import "DetailViewController.h"

#import "Crop.h"
#import "CropTableViewCell.h"
#import "NSDate-Utilities.h"
#import "CropHeaderTableViewCell.h"

@interface CropTableViewController ()
@property (nonatomic,strong) AppDelegate *appDelegate;
@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@end

@implementation CropTableViewController

- (void)awakeFromNib {
    [super awakeFromNib];
}
// Initialize the view and get appDelegate and managedObjectContext references
- (void)viewDidLoad {
    [super viewDidLoad];

    self.appDelegate = (AppDelegate *)[[UIApplication sharedApplication]delegate];
    self.managedObjectContext  = _appDelegate.managedObjectContext;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if ([[_fetchedResultsController sections]count] < 1)
    {
        NSLog(@"First Launch");
        
        UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"Welcome to Henge" message:@"Henge tracks your growing seaons! Get started by picking a new crop in the Botanica tab." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        
        [alert show];
        
    }
    
}


#pragma mark - Segues
//Handle segues
//showCropDetails: Set crop in the crop details controller.
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"showCropDetails"])
    {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        Crop *object = [[self fetchedResultsController] objectAtIndexPath:indexPath];
        [[segue destinationViewController] setDetailItem:object];
    }
}

#pragma mark - Table View
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [[self.fetchedResultsController sections] count];
}
//cell size set to 30px
-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 30.0;
}

//Create a custom section header with the section name.
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *sectionHeaderView = [[UIView alloc] initWithFrame:
                                 CGRectMake(0, 0, tableView.frame.size.width, 30.0)];
    sectionHeaderView.backgroundColor = [UIColor clearColor];
    
    UILabel *headerLabel = [[UILabel alloc] initWithFrame:
                            CGRectMake(0, 8, sectionHeaderView.frame.size.width, 15.0)];
    
    sectionHeaderView.backgroundColor = [UIColor colorWithRed:0.023f green:0.247f blue:0.043f alpha:1.00f];
    headerLabel.textAlignment = NSTextAlignmentCenter;
    [headerLabel setFont:[UIFont fontWithName:@"IowanOldStyle-Roman" size:14.0]];
    headerLabel.textColor =  [UIColor whiteColor];
    
     id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    headerLabel.text = [NSString stringWithFormat:@"%@ Season",[sectionInfo name]];
    [sectionHeaderView addSubview:headerLabel];
    
//    UIView *borderView = [[UIView alloc] initWithFrame:
//                                 CGRectMake(0, 29, tableView.frame.size.width, 1.0)];
//    borderView.backgroundColor = [UIColor whiteColor];
//   // [sectionHeaderView addSubview:borderView];
    
     return sectionHeaderView;

}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CropTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CropCell" forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        [context deleteObject:[self.fetchedResultsController objectAtIndexPath:indexPath]];
            
        NSError *error = nil;
        if (![context save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

//Configure a cell for view. Set title, details and progress information.
- (void)configureCell:(CropTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    Crop *crop = [self.fetchedResultsController objectAtIndexPath:indexPath];
   
    cell.titleLabel.text = crop.name;
    cell.plantedDate.hidden = YES;
    
    //set the seeded date or indicate plant
    if (crop.seededDate)
    {
        cell.actionLabel.text  = @"Seeded";
    }
    else
    {
        cell.actionLabel.text = @"Plant";
    }
    
    if ([crop.cultivar isEqualToString:crop.name])
    {
        cell.descriptionLabel.hidden = YES;
    }
    else
    {
         cell.descriptionLabel.hidden =  NO;
        cell.descriptionLabel.text = crop.cultivar;
    }
    
    //cell.descriptionLabel.text = [NSString stringWithFormat:@"Growing days remain %@",[self numberOfGrowingDaysLeftForCrop:crop]];
    
    if ([[self numberOfGrowingDaysLeftForCrop:crop]floatValue] > 0)
    {
        cell.timelineProgressView.hidden = NO;
        float daysLeft = [[self numberOfGrowingDaysLeftForCrop:crop]floatValue];
        float totalDays = [crop.matureEarlyDays floatValue];
        float percentLeft = daysLeft / totalDays;
        float percentComplete = 1 - percentLeft;
    //cell.timelineProgressView.progress = .5;
        [cell.timelineProgressView setProgress:percentComplete animated:YES];
        cell.plantedDate.hidden = YES;
    }
    else
    {
        cell.timelineProgressView.hidden = YES;
        
        if (crop.seededDate)
        {
            cell.plantedDate.hidden = NO;
            
            NSString *weekString;
            if (crop.seededDate.nthWeekday < 2)
            {
                weekString = [NSString stringWithFormat:@"Early"];
            }
            
            if (crop.seededDate.nthWeekday == 2 )
            {
                weekString = [NSString stringWithFormat:@"Mid"];
                
            }
            
            if (crop.seededDate.nthWeekday > 2 )
            {
                weekString = [NSString stringWithFormat:@"End of"];
            }
            
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
            
            [dateFormatter setDateFormat:@"MMM"];
            cell.plantedDate.text = [NSString stringWithFormat:@"%@ %@ Direct Seed",weekString,[dateFormatter stringFromDate:crop.seededDate]];
        }
        
        if (crop.transplantedDate)
        {
            cell.plantedDate.hidden = NO;
            
            NSString *weekString;
            if (crop.transplantedDate.nthWeekday < 2)
            {
                weekString = [NSString stringWithFormat:@"Early"];
            }
            
            if (crop.transplantedDate.nthWeekday == 2 )
            {
                weekString = [NSString stringWithFormat:@"Mid"];
                
            }
            
            if (crop.transplantedDate.nthWeekday > 2 )
            {
                weekString = [NSString stringWithFormat:@"End of"];
            }
            
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
            
            [dateFormatter setDateFormat:@"MMM"];
            cell.plantedDate.text = [NSString stringWithFormat:@"%@ %@ Transplant",weekString,[dateFormatter stringFromDate:crop.seededDate]];
        }

    }
}

-(NSNumber *)numberOfGrowingDaysLeftForCrop:(Crop *)crop
{
    NSDate *matureDate = [[crop seededDate]dateByAddingDays:[crop.matureEarlyDays integerValue]];
    
    NSInteger daysLeft = [[NSDate date]daysBeforeDate:matureDate];
    
    if (daysLeft >= 0)
    {
     
        return [NSNumber numberWithInteger:daysLeft];
    }
    else
    {
        return @0;
    }
}



#pragma mark - Fetched results controller
- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Crop" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"yearGrown" ascending:YES];
    NSSortDescriptor *sortDescriptor2 = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
    NSArray *sortDescriptors = @[sortDescriptor,sortDescriptor2];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:@"yearGrown" cacheName:@"Master"];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
	NSError *error = nil;
	if (![self.fetchedResultsController performFetch:&error]) {
	     // Replace this implementation with code to handle the error appropriately.
	     // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
	    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
	    abort();
	}
    
    return _fetchedResultsController;
}    

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        default:
            return;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    UITableView *tableView = self.tableView;
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
}

/*
// Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed. 
 
 - (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    // In the simplest, most efficient, case, reload the table view.
    [self.tableView reloadData];
}
 */

@end
