//
//  CropDetailViewController.m
//  henge
//
//  Created by Jeff Kunzelman on 2/4/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import "CropDetailViewController.h"
#import "NSDate-Utilities.h"
#import "GUIDCategory.h"
#import "AppDelegate.h"
#import "Action.h"
#import "Observation.h"

@interface CropDetailViewController ()

@property (nonatomic,strong) NSDateFormatter *fancyDateFormatter;
@property (nonatomic,strong) AppDelegate *appDelegate;
@property (nonatomic,strong) Observation *currentObservation;

@end

@implementation CropDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.fancyDateFormatter = [[NSDateFormatter alloc]init];
    [_fancyDateFormatter setDateStyle:NSDateFormatterFullStyle];
}

- (void)setDetailItem:(id)newDetailItem {
    if (_cropInView != newDetailItem)
    {
        _cropInView = newDetailItem;
        // Update the view.
       // [self configureView];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.currentObservation = [self getLatestObservationForCrop:_cropInView];
    [self configureView];
}

-(void)datePicked:(NSDate *)date
{
    
}

-(void)configureView
{
    _cropNameLabel.text = _cropInView.name;
    _cropDetailsLabel.text = _cropInView.cultivar;
    
    if (_cropInView.seededDate)
    {
        _seededDateTitle.alpha = 1;
        _seededDateButton.alpha = 1;
        
        _seededDateButton.titleLabel.text = [_fancyDateFormatter stringFromDate:_cropInView.seededDate];
    }
    else
    {
        if (_cropInView.transplantedDate)
        {
            _seededDateTitle.alpha = 0;
            _seededDateButton.alpha = 0;
        }
        else
        {
            [_seededDateButton setTitle:@"Plant Seeds" forState:UIControlStateNormal];
        }
    }
    
    
    
    if (_cropInView.transplantedDate)
    {
        _transplantedDateLabel.alpha = 1;
        _transplantedDateButton.alpha = 1;
        
        _transplantedDateLabel.text = [_fancyDateFormatter stringFromDate:_cropInView.transplantedDate];
    }
    else
    {
        _transplantedDateButton.alpha = 0;
        _transplantedDateLabel.alpha = 0;
    }
    
    [_vigorSlider setValue:[_currentObservation.vigor floatValue] animated:YES];
    [_diseasePestSlider setValue:[_currentObservation.diseasePests floatValue] animated:YES];
    [_ripenessSlider setValue:[_currentObservation.ripeness floatValue] animated:YES];
    
    _lastWateredTable.text = @"Never Watered";
    _lastAmendLabel.text = @"No Ammendments Applied";
    _harvestDateLabel.text = [self getHarvestStringForCrop:_cropInView];
    
    //_vigorSlider;
    //_diseasePestSlider;
    //_ripenessSlider;
}

-(Observation *)getLatestObservationForCrop:(Crop *)crop
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Observation" inManagedObjectContext:crop.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"((timestamp != nil) AND (crop = %@))",_cropInView];
    [fetchRequest setPredicate:pred];
    
    NSSortDescriptor *sortDescriptor1 = [[NSSortDescriptor alloc] initWithKey:@"timestamp" ascending:YES];
    
    NSArray *sortDescriptors = @[sortDescriptor1];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    NSArray *results = [crop.managedObjectContext executeFetchRequest:fetchRequest error:nil];
    
    if ([results count] > 0)
    {
        Observation *observation = [results objectAtIndex:0];
        
        return observation;
    }
    else
    {
        Observation *observation = [NSEntityDescription insertNewObjectForEntityForName:@"Observation" inManagedObjectContext:crop.managedObjectContext];
        
        observation.vigor = @50;
        observation.diseasePests = @50;
        observation.ripeness = @0;
        observation.timestamp = [NSDate date];
        observation.crop = _cropInView;
        
        return observation;
    }
}

-(NSString *)getHarvestStringForCrop:(Crop *)crop
{
    NSDate *harvestDate;
    
    if ([_cropInView.matureEarlyDays isEqualToNumber:crop.matureLateDays])
    {
        harvestDate = [NSDate dateWithDaysFromNow:[_cropInView.matureEarlyDays integerValue]];
    }
    else
    {
        harvestDate = [NSDate dateWithDaysFromNow:[crop.matureEarlyDays integerValue]];
    }
    
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
    
    return  [NSString stringWithFormat:@"%@ %@",weekString,[dateFormatter stringFromDate:harvestDate]];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)closeButtonAction:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)vigorSliderChanged:(id)sender
{
    if ([_currentObservation.timestamp isToday])
    {
        _currentObservation.vigor = [NSNumber numberWithFloat:_vigorSlider.value];
    }
    else
    {
        Observation *observation = [NSEntityDescription insertNewObjectForEntityForName:@"Observation" inManagedObjectContext:_currentObservation.managedObjectContext];
        
        observation.vigor = [NSNumber numberWithFloat:_vigorSlider.value];
        observation.diseasePests = _currentObservation.diseasePests;
        observation.ripeness = _currentObservation.ripeness;
        observation.crop = _cropInView;
    }
    
    [_currentObservation.managedObjectContext save:nil];
}

- (IBAction)ripenessSliderChanged:(id)sender
{

    if ([_currentObservation.timestamp isToday])
    {
        _currentObservation.ripeness = [NSNumber numberWithFloat:_ripenessSlider.value];
    }
    else
    {
        Observation *observation = [NSEntityDescription insertNewObjectForEntityForName:@"Observation" inManagedObjectContext:_currentObservation.managedObjectContext];
        observation.vigor = _currentObservation.vigor;
        observation.diseasePests = _currentObservation.diseasePests;
        observation.ripeness = [NSNumber numberWithFloat:_ripenessSlider.value];
        observation.crop = _cropInView;
    }
    
    [_currentObservation.managedObjectContext save:nil];
}

- (IBAction)diseasePestSliderChanged:(id)sender
{
    if ([_currentObservation.timestamp isToday])
    {
        _currentObservation.diseasePests = [NSNumber numberWithFloat:_diseasePestSlider.value];
    }
    else
    {
        Observation *observation = [NSEntityDescription insertNewObjectForEntityForName:@"Observation" inManagedObjectContext:_currentObservation.managedObjectContext];
        observation.vigor = _currentObservation.vigor;
        observation.diseasePests = [NSNumber numberWithFloat:_diseasePestSlider.value];
        observation.ripeness = _currentObservation.ripeness;
        observation.crop = _cropInView;
    }
    
    [_currentObservation.managedObjectContext save:nil];
    
}

- (IBAction)waterAction:(id)sender
{

}

- (IBAction)seededButtonAction:(id)sender {
}
@end
