//
//  VegiCalcDetailViewController.h
//  henge
//
//  Created by Jeff Kunzelman on 1/30/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Parse/Parse.h"
//!  Botanica Detail Controller
/*!
  Shows the details of a cultivar in parse. Uses data from parse to perform calculations for seeding and 
 potential crop yeilds based on area.
 */
@interface BotanicaDetailViewController : UIViewController <UITextFieldDelegate>

@property (strong, nonatomic) PFObject  *cultivarObject;

@property (weak, nonatomic) IBOutlet UILabel *nameLabel; /*! The Cultivar Name */
@property (weak, nonatomic) IBOutlet UILabel *maturityLabel; /*! The Cultivar Name */
@property (weak, nonatomic) IBOutlet UISegmentedControl *sizeSelector/*! Selects between rows and acres */;

@property (weak, nonatomic) IBOutlet UILabel *areaLabel; /*! Name of area rows or acres */
@property (weak, nonatomic) IBOutlet UITextField *areaSizeTextField; /*! Size of the area for rows or acres */
@property (weak, nonatomic) IBOutlet UILabel *areaLengthLabel; /*! Used for Row Length */
@property (weak, nonatomic) IBOutlet UITextField *areaLengthTextField; /*! Used for Row Length */
@property (weak, nonatomic) IBOutlet UITextField *seedQuantity; /*! Quanity of seeds Needed */
@property (weak, nonatomic) IBOutlet UILabel *seedUnits; /*! measurement units */
@property (weak, nonatomic) IBOutlet UITextField *harvestQuantity; /*! Estimated Harvest Size */
@property (weak, nonatomic) IBOutlet UILabel *harvestUnits;  /*! measurement units */
@property (weak, nonatomic) IBOutlet UILabel *harvestDateLabel;
@property (weak, nonatomic) IBOutlet UILabel *storageLabel;
@property (weak, nonatomic) IBOutlet UILabel *seedsLabel;
@property (weak, nonatomic) IBOutlet UILabel *harvestLabel;
@property (weak, nonatomic) IBOutlet UILabel *notesLabel;


- (IBAction)closeButtonAction:(id)sender; /*! Close the View */
- (IBAction)addButtonAction:(id)sender; /*! Creates a new Crop in the local datamodel */
- (IBAction)areaFactorChanged:(id)sender; /*! Switch for Rows and Acre calculator */

-(void)loadCultivarObj:(PFObject *)culitvarObject;  /*! Loads a new cultivar in the detail view */

- (IBAction)editedAction:(id)sender;  /*! action for handing edit changes. Recalculates the seed and harvest quantities. */


@end
