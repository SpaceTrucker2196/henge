//
//  NewCropViewController.h
//  henge
//
//  Created by Jeff Kunzelman on 2/6/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Crop.h"
//!  EditCropViewController
/*!
 This view creates a new crop or edits an existing one. This view sets cultivar
 information used for calculations. it's accessable either from create new crop 
 or the info button in crop details.

 This view cooresponds with Botanica Class in parse. 
 Crop information can also be uploaded to an incoming parse
 Class if the user picks upload to Henge.
 */
@interface EditCropViewController : UIViewController

@property (weak, nonatomic) IBOutlet UILabel *titleLabel; /*! The view title. indicating if we are creating a new or editing existing */


@property (weak, nonatomic) IBOutlet UITextField *cultivarNameTextField; /*! The crop title */
@property (weak, nonatomic) IBOutlet UITextField *seedVendorTextField; /*! The seed source */
@property (weak, nonatomic) IBOutlet UITextField *earlyMaturityTextField; /*! the estimated days to harvest for early varities */
@property (weak, nonatomic) IBOutlet UITextField *commonMaturityTextField; /*! the estimated days to harvest */
@property (weak, nonatomic) IBOutlet UITextField *lateMaturityTextField;  /*! the estimated days to harvest for late varities*/
@property (weak, nonatomic) IBOutlet UITextField *rowYieldTextField;  /*! the estimated 100ft row yield */
@property (weak, nonatomic) IBOutlet UITextField *rowYieldUnits; /*! measurement units */
@property (weak, nonatomic) IBOutlet UITextField *acreYieldTextField; /*! estimated yield for 1 acre */
@property (weak, nonatomic) IBOutlet UITextField *acreYieldUnits; /*! measurement units */
@property (weak, nonatomic) IBOutlet UITextField *rowSeedCountTextField; /*! 100ft row seed counts */
@property (weak, nonatomic) IBOutlet UITextField *acreSeedVolumeTextField; /*! seed volume for acre */
@property (weak, nonatomic) IBOutlet UITextField *acreSeedUnits; /*! measurement units */
@property (weak, nonatomic) IBOutlet UITextField *storageTempTextField; /*! Optimal Storage Temp */
@property (weak, nonatomic) IBOutlet UITextField *storageHumidityTextField; /*! Optimal Humidity Temp */
@property (weak, nonatomic) IBOutlet UITextField *storageWeeksTextField; /*! Optimal Weeks in Storage */

@property (weak, nonatomic) IBOutlet UIButton *growingNotesButton; /*! Growing Notes Button */
@property (weak, nonatomic) IBOutlet UIButton *addToSeasonButton; /*! Add to Season Button */
@property (weak, nonatomic) IBOutlet UIButton *updateHengeButton; /*! Update to Henge Button */


@property (weak, nonatomic) Crop *cropInView;  /*! The current Crop */

- (IBAction)closeButtonAction:(id)sender; /*! Closes the View and Saves Changes */
- (IBAction)addAction:(id)sender; /*! add Button action to add to current growing season */
- (IBAction)saveToHengeAction:(id)sender; /*! Create and upload a new parse Object to the incoming class in parse */
@end
