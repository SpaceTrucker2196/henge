//
//  CropTableViewCell.h
//  henge
//
//  Created by Jeff Kunzelman on 2/3/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import <UIKit/UIKit.h>
//!  CropTableViewCell
/*!
 Custom Cell for Crop View. 
 
 */
@interface CropTableViewCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *titleLabel; /*! The Crop title. Defaults to the Cultivar Name */
@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel; /*! When the Crop Name is different this displays the cultivar name */
@property (weak, nonatomic) IBOutlet UIProgressView *timelineProgressView;  /*! The progress towards harvest */
@property (weak, nonatomic) IBOutlet UILabel *actionLabel; /*! The last action taken */
@property (weak, nonatomic) IBOutlet UILabel *plantedDate; /*! When there is no progress unhide and display the planted date */

@end
