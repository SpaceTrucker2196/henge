//
//  NewCropViewController.m
//  henge
//
//  Created by Jeff Kunzelman on 2/6/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import "EditCropViewController.h"
#import "EditCropGrowingNotesViewController.h"

//#import "Crop.m"
#import "AppDelegate.h"

@interface EditCropViewController ()

@property (nonatomic,strong)AppDelegate *appDelegate;

@end

@implementation EditCropViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
     self.appDelegate = (AppDelegate *)[[UIApplication sharedApplication]delegate];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self configureView];
    
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    
    if ([segue.identifier isEqualToString:@"growingNotes"])
    {
        EditCropGrowingNotesViewController *growingNotesViewController = segue.destinationViewController;
        growingNotesViewController.cropInView = self.cropInView;
    }
}


-(BOOL)inputFieldsAreValid
{
    if ([_cultivarNameTextField.text length]>0)
    {
            return YES;
    }
    
    return NO;
}

-(BOOL)inputFieldsAreValidForParse
{
    if (([_cultivarNameTextField.text length]>0) &&
        ([_seedVendorTextField.text length] >0))
    {
        if (([_earlyMaturityTextField.text length]>0) ||
            ([_lateMaturityTextField.text length]>0)   ||
            ([_commonMaturityTextField.text length]>0))
        {
            return YES;
        }
        
    }
    
    
    UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"Henge" message:@"Please include at least the Seed Name and Vendor. We'll use this to gather additional information from the seed company." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];

    [alert show];
    
    return NO;
}

-(void)configureView
{
    if (_cropInView)
    {
        //buttons
        _growingNotesButton.hidden = NO;
        _updateHengeButton.hidden = NO;
        _addToSeasonButton.hidden = NO;
        
        //data
        _titleLabel.text = @"Edit Crop";
        _cultivarNameTextField.text = _cropInView.cultivar;
        _seedVendorTextField.text = _cropInView.vendor;
        _earlyMaturityTextField.text = [_cropInView.matureEarlyDays stringValue];
        _commonMaturityTextField.text = [_cropInView.matureDaysCommon stringValue];
        _lateMaturityTextField.text = [_cropInView.matureLateDays stringValue];
        
        
        _rowYieldTextField.text = [_cropInView.commonRowYield stringValue];
        _rowYieldUnits.text = _cropInView.commonRowYieldUnit;
        _acreYieldTextField.text = [_cropInView.acreYield stringValue];
        _acreYieldUnits.text = _cropInView.acreYieldUnit;
        _rowSeedCountTextField.text = [_cropInView.seedCountCommonRow stringValue];
        _acreSeedVolumeTextField.text = [_cropInView.seedWeightAcre stringValue];
        _acreSeedUnits.text = _cropInView.seedWeightAcreUnit;
        _storageTempTextField.text = [_cropInView.storageTempF stringValue];
        _storageHumidityTextField.text = [_cropInView.storageHumidityPercent stringValue];
        _storageWeeksTextField.text = [_cropInView.storageHoldWeeks stringValue];
    }
    else
    {
        _titleLabel.text = @"Create A New Crop";
        _growingNotesButton.hidden = YES;
        _updateHengeButton.hidden = YES;
        _addToSeasonButton.hidden = NO;
    }
}

-(void)newCropFromInputFields
{
    self.cropInView = [NSEntityDescription insertNewObjectForEntityForName:@"Crop" inManagedObjectContext:_appDelegate.managedObjectContext];
    
    _cropInView.cultivar = _cultivarNameTextField.text;
    _cropInView.vendor = _seedVendorTextField.text;
    _cropInView.name = _cultivarNameTextField.text;
    
    NSDate *now = [NSDate date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy"];
    _cropInView.yearGrown = [formatter stringFromDate:now];
    
    //maturity
    _cropInView.matureEarlyDays = [NSNumber numberWithInteger:[_earlyMaturityTextField.text integerValue]];
    _cropInView.matureLateDays = [NSNumber numberWithInteger:[_lateMaturityTextField.text integerValue]];
    _cropInView.matureDaysCommon = [NSNumber numberWithInteger:[_commonMaturityTextField.text integerValue]];
    
    //common row lenth is 100ft UI Asks for 10ft
    //yield
    float shortRowYield = [_rowSeedCountTextField.text floatValue];
    _cropInView.commonRowYield = [[NSDecimalNumber alloc]initWithFloat:(shortRowYield *10)];
    _cropInView.commonRowYieldUnit = _rowYieldUnits.text;
    _cropInView.acreYield = [[NSDecimalNumber alloc]initWithFloat:[_acreYieldTextField.text floatValue]];
    _cropInView.acreYieldUnit = _acreYieldUnits.text;
    
    //seeds
    float shortRowSeedCount = [_rowSeedCountTextField.text floatValue];
    _cropInView.seedCountCommonRow = [[NSDecimalNumber alloc]initWithFloat:(shortRowSeedCount *10)];
    _cropInView.commonRowYieldUnit = _rowYieldUnits.text;
    _cropInView.seedWeightAcre = [[NSDecimalNumber alloc]initWithFloat:[_acreSeedVolumeTextField.text floatValue]];
    _cropInView.seedCountAcreUnit = _acreSeedUnits.text;
    
    //storage
    _cropInView.storageTempF = [[NSDecimalNumber alloc]initWithFloat:[_storageTempTextField.text floatValue]];
    _cropInView.storageHoldWeeks = [[NSDecimalNumber alloc]initWithFloat:[_storageWeeksTextField.text floatValue]];
    _cropInView.storageHumidityPercent = [[NSDecimalNumber alloc]initWithFloat:[_storageHumidityTextField.text floatValue]];
    
    [_appDelegate.managedObjectContext save:nil];
    
}

-(void)newParseObjectForCrop:(Crop *)crop
{
    PFObject *uploadObject = [PFObject objectWithClassName:@"VegiMatrixIncoming"];
    // cultivarCommon,commonRowSeedCount,seedWeightAcre,seedWeightAcreUnit,seedCountAcre,commonRowYield,commonRowYieldUnit,acreYield,acreYieldUnit,earlyMat ureDays,commonMatureDays,lateMatureDays,storageTempF,storageHumidityPercent,storageHoldWeeks,cultivarNotes

    uploadObject[@"cultivarCommon"] = crop.cultivar;
    uploadObject[@"seedVendor"] = crop.vendor;
    
    if (crop.seedCountAcre)
    {
        uploadObject[@"seedCountAcre"] = [crop.seedCountAcre stringValue];
    }
    if (crop.seedCountAcreUnit)
    {
        uploadObject[@"seedCountAcreUnit"] = crop.seedCountAcreUnit;
        
    }
    if (crop.seedWeightAcre)
    {
        uploadObject[@"seedWeightAcre"] = crop.seedWeightAcre;
        
    }
    if (crop.seedWeightAcreUnit)
    {
        uploadObject[@"seedWeightAcreUnit"] = crop.seedWeightAcreUnit;
        
    }
    
    if (crop.seedCountCommonRow)
    {
        uploadObject[@"commonRowSeedCount"] = [crop.seedCountCommonRow stringValue];
    }
    
    if (crop.commonRowYieldUnit )
    {
       uploadObject[@"commonRowYieldUnit"] = crop.commonRowYieldUnit;
    }
    
    if (crop.commonRowYield)
    {
        uploadObject[@"commonRowYield"] = [crop.commonRowYield stringValue];
    }
    
    if (crop.acreYield)
    {
        uploadObject[@"acreYield"] = [crop.acreYield stringValue];
    }
    
    if (crop.acreYieldUnit)
    {
        uploadObject[@"acreYieldUnit"] = crop.acreYieldUnit;
    }
    
    if (crop.matureEarlyDays)
    {
        uploadObject[@"earlyMatureDays"] = [crop.matureEarlyDays stringValue];
    }
    
    if (crop.matureDaysCommon)
    {
        uploadObject[@"commonMatureDays"] = [crop.matureDaysCommon stringValue];
    }
    
    if(crop.matureLateDays)
    {
        uploadObject[@"lateMatureDays"] = [crop.matureLateDays stringValue];
    }
    
    if (crop.storageTempF)
    {
        uploadObject[@"storageTempF"] = [crop.storageTempF stringValue];
    }
    
    if (crop.storageHumidityPercent)
    {
        uploadObject[@"storageHumidityPercent"] = [crop.storageHumidityPercent stringValue];
    }
    
    if (crop.storageHoldWeeks)
    {
        uploadObject[@"storageHoldWeeks"] = [crop.storageHoldWeeks stringValue];
    }
    
    if (crop.cultivarNotes)
    {
        uploadObject[@"cultivarNotes"] = crop.cultivarNotes;
    }
    
    [uploadObject saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            // The object has been saved.
        } else {
            // There was a problem, check error.description
            
            //NSLog(error.description);
        }
    }];
    
}


- (IBAction)closeButtonAction:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)addAction:(id)sender
{
    if ([self inputFieldsAreValid])
    {
        [self newCropFromInputFields];
    }
    else
    {
        UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"Henge" message:@"To track your growing season, lease include at least the crop name." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        
        [alert show];
    }
}

- (IBAction)saveToHengeAction:(id)sender
{
    if ([self inputFieldsAreValid])
    {
        if ([self inputFieldsAreValidForParse])
        {
            [self newCropFromInputFields];
            [self newParseObjectForCrop:_cropInView];
        }
    }

}
@end
