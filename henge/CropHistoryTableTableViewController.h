//
//  CropHistoryTableTableViewController.h
//  henge
//
//  Created by Jeff Kunzelman on 2/10/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Crop.h"

@interface CropHistoryTableTableViewController : UITableViewController

@property (nonatomic, strong) Crop *cropInView;
@end
