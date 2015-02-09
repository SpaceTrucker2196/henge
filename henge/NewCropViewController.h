//
//  NewCropViewController.h
//  henge
//
//  Created by Jeff Kunzelman on 2/6/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Crop.h"

@interface NewCropViewController : UIViewController
@property (weak, nonatomic) IBOutlet UITextField *cultivarNameTextField;
@property (weak, nonatomic) IBOutlet UITextField *seedVendorTextField;
@property (weak, nonatomic) IBOutlet UITextField *earlyMaturityTextField;
@property (weak, nonatomic) IBOutlet UITextField *commonMaturityTextField;
@property (weak, nonatomic) IBOutlet UITextField *lateMaturityTextField;
@property (weak, nonatomic) IBOutlet UITextField *rowYieldTextField;
@property (weak, nonatomic) IBOutlet UITextField *rowYieldUnits;
@property (weak, nonatomic) IBOutlet UITextField *acreYieldTextField;
@property (weak, nonatomic) IBOutlet UITextField *acreYieldUnits;
@property (weak, nonatomic) IBOutlet UITextField *rowSeedCountTextField;
@property (weak, nonatomic) IBOutlet UITextField *acreSeedVolumeTextField;
@property (weak, nonatomic) IBOutlet UITextField *acreSeedUnits;
@property (weak, nonatomic) IBOutlet UITextField *storageTempTextField;
@property (weak, nonatomic) IBOutlet UITextField *storageHumidityTextField;
@property (weak, nonatomic) IBOutlet UITextField *storageWeeksTextField;

@property (weak, nonatomic) Crop *cropInView;

- (IBAction)closeButtonAction:(id)sender;
- (IBAction)addAction:(id)sender;

- (IBAction)saveToHengeAction:(id)sender;
@end
