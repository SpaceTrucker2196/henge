//
//  CropHistoryViewController.h
//  henge
//
//  Created by Jeff Kunzelman on 2/10/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Crop.h"
//!  Crop History
/*!
 Lists the history of observations for the current crop.
 */
@interface CropHistoryViewController : UIViewController

@property (nonatomic,strong) Crop *cropInView; /*! The current crop we are view history for */
@property (weak, nonatomic) IBOutlet UITextField *nameTextField; /*! Crop Name */
@property (weak, nonatomic) IBOutlet UILabel *detailsTextField; /*! crop details */

- (IBAction)closeButtonAction:(id)sender; /*! close */
@end
