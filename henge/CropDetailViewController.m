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
#import "CropDatePickerViewController.h"
#import "EditCropViewController.h"
#import "CropHistoryViewController.h"

@interface CropDetailViewController ()

@property (nonatomic,strong) NSDateFormatter *fancyDateFormatter;
@property (nonatomic,strong) AppDelegate *appDelegate;
@property (nonatomic,strong) Observation *currentObservation;
@property (assign)BOOL pickingTransplantDate;

@end

@implementation CropDetailViewController

///Initialize the view. Set dateformatter, textfield delegates, and reference to app delegate
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.fancyDateFormatter = [[NSDateFormatter alloc]init];
    [_fancyDateFormatter setDateStyle:NSDateFormatterFullStyle];
    self.appDelegate = (AppDelegate *)[[UIApplication sharedApplication]delegate];
    
    [_cropNameLabel setDelegate:self];
    
}

///Sets _cropInView
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
///Perform viewWillAppear get current observation and update the view.
-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.currentObservation = [self getLatestObservationForCrop:_cropInView];
    [self configureView];
}

///handle the datepicked by the datepicker and update observation for seeded or transplant
-(void)datePicked:(NSDate *)date
{
    if (self.pickingTransplantDate)
    {
        _cropInView.transplantedDate = date;
       
        if (!_cropInView.seededDate)
        {
            //default transplant age is 5 weeks
            _cropInView.seededDate =[date dateBySubtractingDays:35];
        }
        
        Observation *observation = [NSEntityDescription insertNewObjectForEntityForName:@"Observation" inManagedObjectContext:_appDelegate.managedObjectContext];
        
        observation.vigor = @0;
        observation.diseasePests = @0;
        observation.ripeness = @0;
        observation.crop = _cropInView;
        observation.timestamp =  _cropInView.transplantedDate;
        observation.actionDescription = @"Transplanted";
    }
    else
    {
        _cropInView.seededDate = date;
        
        Observation *observation = [NSEntityDescription insertNewObjectForEntityForName:@"Observation" inManagedObjectContext:_appDelegate.managedObjectContext];
        observation.timestamp = _cropInView.seededDate;
        observation.vigor = @0;
        observation.diseasePests = @0;
        observation.ripeness = @0;
        observation.crop = _cropInView;
        observation.actionDescription = @"Seeded";

  
    }
    
    //reset the year of the crop
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy"];
    _cropInView.yearGrown = [formatter stringFromDate:date];

    [_cropInView.managedObjectContext save:nil];
}
///update the view from the cropInView property.
-(void)configureView
{
    _cropNameLabel.text = _cropInView.name;
    _cropDetailsLabel.text = _cropInView.cultivar;
    
    if (_cropInView.seededDate)
    {
        _seededDateTitle.alpha = 1;
        _seededDateButton.alpha = 1;
        [_seededDateButton setTitle:[self stringFromDate:_cropInView.seededDate]forState:UIControlStateNormal];
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
        
        [_transplantedDateButton setTitle:[self stringFromDate:_cropInView.transplantedDate]forState:UIControlStateNormal];
    }
    else
    {
        if (_cropInView.seededDate)
        {
            _transplantedDateButton.alpha = 0;
            _transplantedDateLabel.alpha = 0;
        }
        else
        {
            _transplantedDateButton.alpha = 1;
            _transplantedDateLabel.alpha = 1;
            [_transplantedDateButton setTitle:@"Transplant" forState:UIControlStateNormal];
        }
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

///gets the latest observation for a crop or creates a new one if one does not exist.
-(Observation *)getLatestObservationForCrop:(Crop *)crop
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Observation" inManagedObjectContext:crop.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"((timestamp != nil) AND (crop = %@))",_cropInView];
    [fetchRequest setPredicate:pred];
    
    NSSortDescriptor *sortDescriptor1 = [[NSSortDescriptor alloc] initWithKey:@"timestamp" ascending:NO];
    
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
        
        observation.vigor = @0;
        observation.diseasePests = @0;
        observation.ripeness = @0;
        observation.timestamp = [NSDate date];
        observation.crop = _cropInView;
        
        return observation;
    }
}
///Creates a fuzzy date for when a crop will be ready for harvest like Early July or Late August.
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


#pragma mark - Navigation

/// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    
   if ([[segue identifier] isEqualToString:@"seededDatePopover"])
    {
        CropDatePickerViewController *gvc = [segue destinationViewController];
        gvc.delegate = self;
         self.pickingTransplantDate = NO;
    }
    if ([[segue identifier] isEqualToString:@"transplantedDatePopover"])
    {
        CropDatePickerViewController *gvc = [segue destinationViewController];
        gvc.delegate = self;
        self.pickingTransplantDate = YES;
    }
    if ([[segue identifier] isEqualToString:@"editCropData"])
    {
        EditCropViewController *gvc = [segue destinationViewController];
        gvc.cropInView = self.cropInView;
        [_currentObservation.managedObjectContext save:nil];
    }
    if ([[segue identifier] isEqualToString:@"historyView"])
    {
        CropHistoryViewController *gvc = [segue destinationViewController];
        gvc.cropInView = self.cropInView;
        [_currentObservation.managedObjectContext save:nil];
    }
    
}

///closes the view and saves any data model changes.
- (IBAction)closeButtonAction:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
    [_currentObservation.managedObjectContext save:nil];
}


//All slider changed actions update the current observation if one exists for the current day. If one doesn't
//exist a new one is created copying the previous observations to the new. This way if a user only changes vigor
// the other slider values are not defaulted to 0.
- (IBAction)vigorSliderChanged:(id)sender
{
    if ([_currentObservation.timestamp isToday])
    {
        _currentObservation.vigor = [NSNumber numberWithFloat:_vigorSlider.value];
    }
    else
    {
        Observation *observation = [NSEntityDescription insertNewObjectForEntityForName:@"Observation" inManagedObjectContext:_appDelegate.managedObjectContext];
        
        observation.vigor = [NSNumber numberWithFloat:_vigorSlider.value];
        observation.diseasePests = _currentObservation.diseasePests;
        observation.ripeness = _currentObservation.ripeness;
        observation.crop = _cropInView;
        observation.timestamp = [NSDate date];
         _currentObservation = observation;
    }
    
   // [_currentObservation.managedObjectContext save:nil];
}

- (IBAction)ripenessSliderChanged:(id)sender
{

    if ([_currentObservation.timestamp isToday])
    {
        _currentObservation.ripeness = [NSNumber numberWithFloat:_ripenessSlider.value];
    }
    else
    {
        Observation *observation = [NSEntityDescription insertNewObjectForEntityForName:@"Observation" inManagedObjectContext:_appDelegate.managedObjectContext];
        observation.vigor = _currentObservation.vigor;
        observation.diseasePests = _currentObservation.diseasePests;
        observation.ripeness = [NSNumber numberWithFloat:_ripenessSlider.value];
        observation.timestamp = [NSDate date];
        observation.crop = _cropInView;
        
         _currentObservation = observation;
    }
    
   // [_currentObservation.managedObjectContext save:nil];
}

- (IBAction)diseasePestSliderChanged:(id)sender
{
    if ([_currentObservation.timestamp isToday])
    {
        _currentObservation.diseasePests = [NSNumber numberWithFloat:_diseasePestSlider.value];
    }
    else
    {
        Observation *observation = [NSEntityDescription insertNewObjectForEntityForName:@"Observation" inManagedObjectContext:_appDelegate.managedObjectContext];
        observation.vigor = _currentObservation.vigor;
        observation.diseasePests = [NSNumber numberWithFloat:_diseasePestSlider.value];
        observation.ripeness = _currentObservation.ripeness;
        observation.crop = _cropInView;
        observation.timestamp = [NSDate date];
        
        _currentObservation = observation;
    }
    
 //   [_currentObservation.managedObjectContext save:nil];
    
}
//Make a date in the 31st or 16th format
-(NSString *)stringFromDate:(NSDate *)DateLocal
{
    
    NSDateFormatter *prefixDateFormatter = [[NSDateFormatter alloc] init];
    [prefixDateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
    [prefixDateFormatter setDateFormat:@"MMMM d."];//June 13th, 2013
    NSString * prefixDateString = [prefixDateFormatter stringFromDate:DateLocal];
    NSDateFormatter *monthDayFormatter = [[NSDateFormatter alloc] init];
    [monthDayFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
    [monthDayFormatter setDateFormat:@"d"];
    int date_day = [[monthDayFormatter stringFromDate:DateLocal] intValue];
    NSString *suffix_string = @"|st|nd|rd|th|th|th|th|th|th|th|th|th|th|th|th|th|th|th|th|th|st|nd|rd|th|th|th|th|th|th|th|st";
    NSArray *suffixes = [suffix_string componentsSeparatedByString: @"|"];
    NSString *suffix = [suffixes objectAtIndex:date_day];
    
    prefixDateString = [prefixDateString stringByReplacingOccurrencesOfString:@"." withString:suffix];
    NSString *dateString =prefixDateString;
    //  NSLog(@"%@", dateString);
    return dateString;
}

//All actions create new observations regardless if there is a current observation.
- (IBAction)waterAction:(id)sender
{
    Observation *observation = [NSEntityDescription insertNewObjectForEntityForName:@"Observation" inManagedObjectContext:_appDelegate.managedObjectContext];
    observation.vigor = _currentObservation.vigor;
    observation.diseasePests = _currentObservation.diseasePests;
    observation.ripeness = _currentObservation.ripeness;
    observation.crop = _cropInView;
    observation.timestamp = [NSDate date];
    observation.actionDescription = @"Watered";
    
    
    [_appDelegate.managedObjectContext save:nil];
}

- (IBAction)seededButtonAction:(id)sender
{
}

- (IBAction)amendButtonAction:(id)sender
{
    Observation *observation = [NSEntityDescription insertNewObjectForEntityForName:@"Observation" inManagedObjectContext:_appDelegate.managedObjectContext];
    observation.vigor = _currentObservation.vigor;
    observation.diseasePests = _currentObservation.diseasePests;
    observation.ripeness = _currentObservation.ripeness;
    observation.crop = _cropInView;
    observation.timestamp = [NSDate date];
    observation.actionDescription = @"Ammended";
    
    [_appDelegate.managedObjectContext save:nil];
}

- (IBAction)harvestButtonAction:(id)sender
{
    Observation *observation = [NSEntityDescription insertNewObjectForEntityForName:@"Observation" inManagedObjectContext:_appDelegate.managedObjectContext];
    observation.vigor = _currentObservation.vigor;
    observation.diseasePests = _currentObservation.diseasePests;
    observation.ripeness = _currentObservation.ripeness;
    observation.crop = _cropInView;
    observation.timestamp = [NSDate date];
    observation.actionDescription = @"Harvest";
    
    [_appDelegate.managedObjectContext save:nil];
}

#pragma mark - text field delegate methods
- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    [_closeButton setHidden:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.cropNameLabel) {
        [textField resignFirstResponder];
        
        _cropInView.name = _cropNameLabel.text;
        [_cropInView.managedObjectContext save:nil];
        
          [_closeButton setHidden:NO];
        
        return NO;
    }
    return YES;
}
@end
