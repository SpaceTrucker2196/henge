//
//  CropHistoryTableViewCell.h
//  henge
//
//  Created by Jeff Kunzelman on 2/10/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CropHistoryTableViewCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *dateLabel;
@property (weak, nonatomic) IBOutlet UILabel *detailLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *vigorProgressView;
@property (weak, nonatomic) IBOutlet UIProgressView *diseaseProgressView;
@property (weak, nonatomic) IBOutlet UIProgressView *ripnessProgessView;
@property (weak, nonatomic) IBOutlet UIView *statsView;
@property (weak, nonatomic) IBOutlet UILabel *notesLabel;

@end
