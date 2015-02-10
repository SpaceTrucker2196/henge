//
//  VegiCalcDetailViewController.h
//  henge
//
//  Created by Jeff Kunzelman on 1/30/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Parse/Parse.h"

@interface BotanicaDetailViewController : UIViewController <UITextFieldDelegate>

@property (strong, nonatomic) PFObject  *cultivarObject;

@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *maturityLabel;
@property (weak, nonatomic) IBOutlet UISegmentedControl *sizeSelector;

@property (weak, nonatomic) IBOutlet UILabel *areaLabel;
@property (weak, nonatomic) IBOutlet UITextField *areaSizeTextField;
@property (weak, nonatomic) IBOutlet UILabel *areaLengthLabel;
@property (weak, nonatomic) IBOutlet UITextField *areaLengthTextField;
@property (weak, nonatomic) IBOutlet UITextField *seedQuantity;
@property (weak, nonatomic) IBOutlet UILabel *seedUnits;
@property (weak, nonatomic) IBOutlet UITextField *harvestQuantity;
@property (weak, nonatomic) IBOutlet UILabel *harvestUnits;
@property (weak, nonatomic) IBOutlet UILabel *harvestDateLabel;
@property (weak, nonatomic) IBOutlet UILabel *storageLabel;
@property (weak, nonatomic) IBOutlet UILabel *seedsLabel;
@property (weak, nonatomic) IBOutlet UILabel *harvestLabel;
@property (weak, nonatomic) IBOutlet UILabel *notesLabel;

- (IBAction)closeButtonAction:(id)sender;
- (IBAction)addButtonAction:(id)sender;
- (IBAction)areaFactorChanged:(id)sender;

-(void)loadCultivarObj:(PFObject *)culitvarObject;

- (IBAction)editedAction:(id)sender;

@end
