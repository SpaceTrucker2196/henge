//
//  MasterViewController.h
//  henge
//
//  Created by Jeff Kunzelman on 1/28/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import "AppDelegate.h"

@interface CropTableViewController : UITableViewController <NSFetchedResultsControllerDelegate>

@property (nonatomic,strong) AppDelegate *appDelegate;
@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;


@end

