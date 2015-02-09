//
//  NewCropViewController.m
//  henge
//
//  Created by Jeff Kunzelman on 2/6/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import "NewCropViewController.h"
//#import "Crop.m"
#import "AppDelegate.h"

@interface NewCropViewController ()

@property (nonatomic,strong)AppDelegate *appDelegate;

@end

@implementation NewCropViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
     self.appDelegate = (AppDelegate *)[[UIApplication sharedApplication]delegate];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

-(BOOL)inputFieldsAreValid
{
    if ([_cultivarNameTextField.text length]>0)
    {
            return YES;
    }
    
    return NO;
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
}

- (IBAction)saveToHengeAction:(id)sender
{
    if ([self inputFieldsAreValid])
    {
        [self newCropFromInputFields];
    }

}
@end
