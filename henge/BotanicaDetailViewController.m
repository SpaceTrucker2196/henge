//
//  VegiCalcDetailViewController.m
//  henge
//
//  Created by Jeff Kunzelman on 1/30/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import "BotanicaDetailViewController.h"
#import "NSDate-Utilities.h"
#import "AppDelegate.h"
#import "Crop.h"
#import "GUIDCategory.h"

@interface BotanicaDetailViewController ()
@property (assign) BOOL isAcreMode;
@property (nonatomic,strong)AppDelegate *appDelegate;
@end

@implementation BotanicaDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.isAcreMode = NO;
    // Do any additional setup after loading the view.
    
    self.appDelegate = (AppDelegate *)[[UIApplication sharedApplication]delegate];
}

-(void)loadCultivarObj:(PFObject *)culitvarObject
{
    self.cultivarObject = culitvarObject;
}

- (IBAction)editedAction:(id)sender
{
    if (self.isAcreMode)
    {
        [self calcForAcre];
    }
    else
    {
        [self calcForRow];
    }
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:YES];
    [self configureView];
}

-(void)configureView
{
    NSString *cultivar = [_cultivarObject objectForKey:@"cultivarCommon"];
   
    _nameLabel.text =  cultivar;
    
    NSString *earlyMature = [_cultivarObject objectForKey:@"earlyMatureDays"];
    NSString *lateMature =  [_cultivarObject objectForKey:@"lateMatureDays"];
    NSString *commonMature =  [_cultivarObject objectForKey:@"commonMatureDays"];
    NSString *maturityString;
    
    NSDate *harvestDate;
    
    if ([commonMature length] > 0)
    {
        maturityString = [NSString stringWithFormat:@"Matures in %@ days.",commonMature];
          harvestDate = [NSDate dateWithDaysFromNow:[commonMature integerValue]];
    }
    
    if ([earlyMature length] > 0)
    {
        maturityString = [NSString stringWithFormat:@"Matures in %@  to %@ days.",earlyMature, lateMature];
        harvestDate = [NSDate dateWithDaysFromNow:[earlyMature integerValue]];
    }
    
    
    //calc maturity week
    _maturityLabel.text = maturityString;
    
    NSString *weekString;
    
    if (harvestDate.nthWeekday < 2)
    {
        weekString = [NSString stringWithFormat:@"Early"];
    }
    
    if (harvestDate.nthWeekday == 2 )
    {
        weekString = [NSString stringWithFormat:@"Middle of"];

    }
    
    if (harvestDate.nthWeekday > 2 )
    {
        weekString = [NSString stringWithFormat:@"End of"];
    }
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
    
    [dateFormatter setDateFormat:@"MMMM"];
    _harvestDateLabel.text = [NSString stringWithFormat:@"%@ %@",weekString,[dateFormatter stringFromDate:harvestDate]];

    NSString *tempString = [_cultivarObject objectForKey:@"storageTempF"];
    NSString *humidString = [_cultivarObject objectForKey:@"storageHumidityPercent"];
    NSString *holdWeeks = [_cultivarObject objectForKey:@"storageHoldWeeks"];
    
    if ([tempString length] > 0)
    {
        NSString *storageString = [NSString stringWithFormat:@"Store at %@F with %@ humidity up to %@ weeks.",tempString,humidString,holdWeeks ];
        _storageLabel.text = storageString;
    }
    else
    {
        _storageLabel.text = @"";
    }
    NSString *notesString = [_cultivarObject objectForKey:@"cultivarNotes"];
    
    _notesLabel.text = notesString;
    
    if (self.isAcreMode)
    {
        [self configureViewForAcre];
        [self calcForAcre];
    }
    else
    {
        [self configureViewForRow];
        [self calcForRow];
    }
}

-(void)configureViewForAcre
{
    _areaSizeTextField.text = @"1";
    _harvestUnits.text = [_cultivarObject objectForKey:@"acreYieldUnit"];
    
}

-(void)calcForAcre
{
    _harvestQuantity.alpha = 0;
    _areaLengthTextField.alpha = 0;
    _areaSizeTextField.alpha = 0;
    _areaLengthLabel.alpha = 0;
    _areaLabel.alpha = 0;
    _seedUnits.alpha = 0;
    _seedQuantity.alpha = 0;
    _harvestUnits.alpha = 0;
    _seedsLabel.alpha = 0;
    _harvestLabel.alpha = 0;

    NSString *acresString = _areaSizeTextField.text;
    NSString *acreSeedCountString = [_cultivarObject objectForKey:@"seedWeightAcre"];
    NSString *acreYieldString = [_cultivarObject objectForKey:@"acreYield"];
    
    if ([acreSeedCountString floatValue])
    {
        _areaSizeTextField.alpha = 1;
        _areaLabel.alpha = 1;
        _seedUnits.alpha = 1;
        _seedQuantity.alpha = 1;
        _seedsLabel.alpha = 1;
        _harvestLabel.alpha = 1;
        _harvestUnits.alpha = 1;
        _harvestQuantity.alpha = 1;
        
        float seedcount = [acreSeedCountString floatValue];
        float acres = [acresString floatValue];
        float acreYield = [acreYieldString floatValue];

        float yieldTotal = (acres * acreYield);
        float seedTotal = (acres * seedcount);
        
        NSNumber *totalYieldNumber = [NSNumber numberWithFloat:yieldTotal];
        
        NSNumberFormatter *numFormater = [[NSNumberFormatter alloc]init];
        
        [numFormater setNumberStyle:NSNumberFormatterDecimalStyle];
        [numFormater setMaximumFractionDigits:2];
        
        NSNumber *totalSeedNumber = [NSNumber numberWithFloat:seedTotal];
        
        NSNumberFormatter *numFormater2 = [[NSNumberFormatter alloc]init];
        
        [numFormater2 setNumberStyle:NSNumberFormatterDecimalStyle];
        [numFormater2 setMaximumFractionDigits:0];
        
        _harvestQuantity.text = [numFormater stringFromNumber:totalYieldNumber];
        _seedQuantity.text = [numFormater2 stringFromNumber:totalSeedNumber];
        
        _seedUnits.text = [_cultivarObject objectForKey:@"seedWeightAcreUnit"];
        _harvestUnits.text = [_cultivarObject objectForKey:@"acreYieldUnit"];
    }
}

-(void)configureViewForRow
{
    _areaSizeTextField.text = @"1";
    _areaLengthTextField.text = @"10";
    _seedUnits.text = @"seeds";
    _harvestUnits.text = [_cultivarObject objectForKey:@"commonRowYieldUnit"];
}\

-(void)calcForRow
{
    _harvestQuantity.alpha = 0;
    _areaLengthTextField.alpha = 0;
    _areaSizeTextField.alpha = 0;
    _areaLengthLabel.alpha = 0;
    _areaLabel.alpha = 0;
    _seedUnits.alpha = 0;
    _seedQuantity.alpha = 0;
    _harvestUnits.alpha = 0;
    _seedsLabel.alpha = 0;
    _harvestLabel.alpha = 0;
    
    NSString *rowsString = _areaSizeTextField.text;
    NSString *rowLengthString = _areaLengthTextField.text;
    NSString *rowSeedCountString = [_cultivarObject objectForKey:@"commonRowSeedCount"];
    
    if ([rowSeedCountString integerValue])
    {
        _areaLengthTextField.alpha = 1;
        _areaSizeTextField.alpha = 1;
        _areaLengthLabel.alpha = 1;
        _areaLabel.alpha = 1;
        _seedUnits.alpha = 1;
        _seedQuantity.alpha = 1;
        _seedsLabel.alpha = 1;
    }
    
    NSInteger rows;
    NSInteger rowLength;
    NSInteger rowSeedCount;

    if (([rowsString integerValue]) &&
        ([rowLengthString integerValue]) &&
        ([rowSeedCountString integerValue]))
    {
        
        
        rows = [rowsString integerValue];
        rowLength = [rowLengthString integerValue];
        
        //seed count is for 100ft row
        rowSeedCount = [rowSeedCountString integerValue] / 100;
        
        NSLog(@"rowSeedCount: %li",(long)rowSeedCount);
        NSInteger seedsNeeded = rowSeedCount * rowLength * rows;
        
        _seedQuantity.text = [NSString stringWithFormat:@"%li",(long)seedsNeeded];
        
        NSString *yieldString = [_cultivarObject objectForKey:@"commonRowYield"];
        
        if ([yieldString integerValue])
        {
            _harvestQuantity.alpha = 1;
            _harvestUnits.alpha = 1;
            _harvestLabel.alpha = 1;
            
            float yield = [yieldString floatValue];
            float yieldFoot = yield / 100;
            float yieldTotal = ((yieldFoot * rowLength) * rows);

            NSNumber *totalYieldNumber = [NSNumber numberWithFloat:yieldTotal];
            
            NSNumberFormatter *numFormater = [[NSNumberFormatter alloc]init];
            
            [numFormater setNumberStyle:NSNumberFormatterDecimalStyle];
            [numFormater setMaximumFractionDigits:2];
            
            _harvestQuantity.text = [numFormater stringFromNumber:totalYieldNumber];
        }
    }
    
    [self.areaLengthTextField setNeedsDisplay];
}

-(BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
   // [self calcForRow];
    return YES;
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

- (IBAction)closeButtonAction:(id)sender {
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)addButtonAction:(id)sender
{
    Crop *crop = [NSEntityDescription insertNewObjectForEntityForName:@"Crop" inManagedObjectContext:_appDelegate.managedObjectContext];
    
    crop.cropId = [NSString stringWithUUID];
    crop.cultivar = [_cultivarObject objectForKey:@"cultivarCommon"];
    crop.matureEarlyDays = [NSNumber numberWithInteger:[[_cultivarObject objectForKey:@"earlyMatureDays"]integerValue]];
    crop.matureLateDays =  [NSNumber numberWithInteger:[[_cultivarObject objectForKey:@"lateMatureDays"]integerValue]];
    
    NSDate *now = [NSDate date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy"];
    crop.yearGrown = [formatter stringFromDate:now];

    NSString *commonMature =  [_cultivarObject objectForKey:@"commonMatureDays"];
    
    if ([commonMature length] > 0)
    {
         crop.matureEarlyDays = [NSNumber numberWithInteger:[[_cultivarObject objectForKey:@"commonMatureDays"]integerValue]];
         crop.matureLateDays = [NSNumber numberWithInteger:[[_cultivarObject objectForKey:@"commonMatureDays"]integerValue]];
    }
    
    crop.name = [_cultivarObject objectForKey:@"cultivarCommon"];
    
    
    crop.vendor = [_cultivarObject objectForKey:@"seedVendor"];
    
    crop.seedCountCommonRow = [[NSDecimalNumber alloc]initWithInteger:[[_cultivarObject objectForKey:@"commonRowSeedCount"]integerValue]];
    crop.seedWeightAcre = [[NSDecimalNumber alloc]initWithInteger:[[_cultivarObject objectForKey:@"seedWeightAcre"]integerValue]];
    crop.seedWeightAcreUnit = [_cultivarObject objectForKey:@"seedWeightAcreUnit"];
    crop.seedCountAcre = [[NSDecimalNumber alloc]initWithInteger:[[_cultivarObject objectForKey:@"seedCountAcre"]integerValue]];
    crop.seedCountAcreUnit = [_cultivarObject objectForKey:@"seedCountAcreUnit"];
    crop.commonRowYield = [[NSDecimalNumber alloc]initWithInteger:[[_cultivarObject objectForKey:@"commonRowYield"]integerValue]];
    crop.commonRowYieldUnit = [_cultivarObject objectForKey:@"commonRowYieldUnit"];
    crop.acreYield = [[NSDecimalNumber alloc]initWithInteger:[[_cultivarObject objectForKey:@"acreYield"]integerValue]];
    crop.acreYieldUnit = [_cultivarObject objectForKey:@"acreYieldUnit"];
    crop.storageHumidityPercent = [[NSDecimalNumber alloc]initWithInteger:[[_cultivarObject objectForKey:@"storageHumidityPercent"]integerValue]];
    crop.storageTempF = [[NSDecimalNumber alloc]initWithFloat:[[_cultivarObject objectForKey:@"storageTempF"]floatValue]];
    crop.storageHoldWeeks = [[NSDecimalNumber alloc]initWithFloat:[[_cultivarObject objectForKey:@"storageHoldWeeks"]floatValue]];
    crop.cultivarNotes = [_cultivarObject objectForKey:@"cultivarNotes"];

    
    [crop.managedObjectContext save:nil];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)areaFactorChanged:(id)sender
{
    switch (self.sizeSelector.selectedSegmentIndex)
    {
        case 0:
            self.isAcreMode = NO;
            [self configureView];
             break;
        case 1:
            self.isAcreMode = YES;
            [self configureView];
            break;
        default: 
            break; 
    }

}
@end
