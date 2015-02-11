//
//  CropHistoryTableTableViewController.h
//  henge
//
//  Created by Jeff Kunzelman on 2/10/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Crop.h"
#import "AppDelegate.h"

@interface CropHistoryTableTableViewController : UITableViewController <NSFetchedResultsControllerDelegate>

@property (nonatomic, strong) Crop *cropInView;
@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (strong, nonatomic) AppDelegate *appDelegate;



@end
