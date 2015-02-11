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
//!  Crop History Table
/*!
 Lists the history of observations for the current crop.
 */
@interface CropHistoryTableTableViewController : UITableViewController <NSFetchedResultsControllerDelegate>

@property (nonatomic, strong) Crop *cropInView;




@end
