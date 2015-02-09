//
//  CropDetailViewController.h
//  henge
//
//  Created by Jeff Kunzelman on 2/4/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Crop.h"
#import "CropDatePickerViewController.h"

@interface CropDetailViewController : UIViewController <CropDatePickerDelegate, UITextFieldDelegate>

@property (nonatomic,strong) Crop *cropInView;
@property (strong, nonatomic) id detailItem;
@property (weak, nonatomic) IBOutlet UITextField *cropNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *seededDateTitle;
@property (weak, nonatomic) IBOutlet UILabel *cropDetailsLabel;

@property (weak, nonatomic) IBOutlet UIButton *seededDateButton;
@property (weak, nonatomic) IBOutlet UILabel *transplantedDateLabel;
@property (weak, nonatomic) IBOutlet UIButton *transplantedDateButton;
@property (weak, nonatomic) IBOutlet UILabel *lastWateredTable;
@property (weak, nonatomic) IBOutlet UILabel *lastAmendLabel;
@property (weak, nonatomic) IBOutlet UILabel *harvestDateLabel;
@property (weak, nonatomic) IBOutlet UISlider *vigorSlider;
@property (weak, nonatomic) IBOutlet UISlider *diseasePestSlider;
@property (weak, nonatomic) IBOutlet UISlider *ripenessSlider;
@property (weak, nonatomic) IBOutlet UIButton *closeButton;

- (IBAction)closeButtonAction:(id)sender;
- (IBAction)vigorSliderChanged:(id)sender;
- (IBAction)ripenessSliderChanged:(id)sender;
- (IBAction)diseasePestSliderChanged:(id)sender;
- (IBAction)waterAction:(id)sender;
- (IBAction)seededButtonAction:(id)sender;

-(void)datePicked:(NSDate *)date;

@end
