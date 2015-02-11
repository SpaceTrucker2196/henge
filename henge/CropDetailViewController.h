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
//!  CropDetailViewController
/*!
 This view shows a crop entity from the local data model. From this view the user can perform observations
 by setting various sliders, indicate watering, add soil amendments, and take notes.
 
 Changing the sliders or indicating an action will generate new Observation entities as needed. When making
 and observation a new enity is created only once per day. Multiple observations on the same day update
 a single observation instance.
 
 Seed and Transplant buttons open a picker that lets a user pick a date the crop was seeded or transplanted
 
 If a Henge user selects seed it's assumed they are direcly seeded in the ground. If a user selects 
 transplant the age is assumed at 4 weeks. A facility for setting transplant age or managing plant starts
 will be added later.
 */
@interface CropDetailViewController : UIViewController <CropDatePickerDelegate, UITextFieldDelegate>

@property (nonatomic,strong) Crop *cropInView;  /*! The current Crop entity in the view */
@property (strong, nonatomic) id detailItem; /*! detail object for delegate */
@property (weak, nonatomic) IBOutlet UITextField *cropNameLabel; /*! The crop name */
@property (weak, nonatomic) IBOutlet UILabel *seededDateTitle; /*! The seeded date title. This will hide when a transplant */
@property (weak, nonatomic) IBOutlet UILabel *cropDetailsLabel; /*! The cultivar name */

@property (weak, nonatomic) IBOutlet UIButton *seededDateButton; /*! Indicates Seed Date when crop is seeded. Hidden when a transplant */
@property (weak, nonatomic) IBOutlet UILabel *transplantedDateLabel;  /*! The transplant date title. This will hide when a direct seeded crop */
@property (weak, nonatomic) IBOutlet UIButton *transplantedDateButton; /*! Indicates the transplant date when crop is a transplant. This will hide when a direct seeded crop */

@property (weak, nonatomic) IBOutlet UILabel *lastWateredTable; /*! Status field showing when the crop was last watered */
@property (weak, nonatomic) IBOutlet UILabel *lastAmendLabel; /*! Status field showing when soil amendements were last added*/
@property (weak, nonatomic) IBOutlet UILabel *harvestDateLabel; /*! Estimated harvest dated based on maturity properties */
@property (weak, nonatomic) IBOutlet UISlider *vigorSlider; /*! Sets the plant vigor or how well a plant is doing */
@property (weak, nonatomic) IBOutlet UISlider *diseasePestSlider; /*! Sets the disease and pest impact */
@property (weak, nonatomic) IBOutlet UISlider *ripenessSlider; /*! sets how ripe the fruit is */
@property (weak, nonatomic) IBOutlet UIButton *closeButton; /*! closes the field and saves any changes. Hides when making changes until user is done with edit*/

- (IBAction)closeButtonAction:(id)sender;  /*! closes the field and saves any changes */
- (IBAction)vigorSliderChanged:(id)sender; /*! Handle vigor changes */
- (IBAction)ripenessSliderChanged:(id)sender; /*! Handle ripeness changes */
- (IBAction)diseasePestSliderChanged:(id)sender; /*! Handle disease/pest changes */
- (IBAction)waterAction:(id)sender; /*!  adds observation for watered*/
- (IBAction)seededButtonAction:(id)sender; /*! unused */
- (IBAction)amendButtonAction:(id)sender; /*! adds observation for soil amendment */
- (IBAction)harvestButtonAction:(id)sender; /*!  adds observation for harvest date */

-(void)datePicked:(NSDate *)date; /*! date picked by the datepicker*/

@end
