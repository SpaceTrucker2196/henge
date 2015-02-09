//
//  AlmanacViewController.m
//  henge
//
//  Created by Jeff Kunzelman on 1/29/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import "AlmanacViewController.h"
#import "Parse/Parse.h"
#import "NSDate-Utilities.h"

@interface AlmanacViewController ()

@property (nonatomic,strong) NSDateFormatter *dateFormat;
@end

@implementation AlmanacViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.dateFormat = [[NSDateFormatter alloc] init];
    [_dateFormat setDateFormat:@"MMMM dd"];

    // Do any additional setup after loading the view.
    
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self loadNewMoonFromParse];
    [self loadFullMoonFromParse];
    [self loadSpringDateFromParse];
    [self loadFallDateFromParse];
    [self loadSeasonFromParse];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)loadNewMoonFromParse
{
    //Create query for all Post object by the current user
    PFQuery *postQuery = [PFQuery queryWithClassName:@"Almanac"];
    
    [postQuery whereKey:@"eventDate" greaterThanOrEqualTo:[NSDate date]];
    [postQuery whereKey:@"eventType" containsString:@"New Moon"];
    // Run the query
    [postQuery findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            //Save results and update the table
            // [PFObject pinAllObjectsInBackground:objects];
            
            PFObject *moonDateobj = [objects objectAtIndex:0];

            NSDate *moonDate = [moonDateobj objectForKey:@"eventDate"];
            _moonNewDateLabel.text = [self stringFromDate:moonDate];
        }
    }];
}


-(void)loadSeasonFromParse
{
    //Create query for all Post object by the current user
    PFQuery *postQuery = [PFQuery queryWithClassName:@"Almanac"];
    
    [postQuery whereKey:@"endDate" greaterThanOrEqualTo:[NSDate date]];
    [postQuery whereKey:@"eventCategory" containsString:@"Season"];
    // Run the query
    [postQuery findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            //Save results and update the table
            // [PFObject pinAllObjectsInBackground:objects];
            
            PFObject *seasonDateobj = [objects objectAtIndex:0];
            
            NSDate *seasonDate = [seasonDateobj objectForKey:@"beginDate"];
            NSDate *seasonEndDate = [seasonDateobj objectForKey:@"endDate"];
            
            NSString *seasonDateType = [seasonDateobj objectForKey:@"eventType"];
            
            if ([seasonDateType isEqualToString:@"Spring Equinox"])
            {
               
                _springProgressView.hidden = NO;
                NSInteger daysLeft = [[NSDate date]daysBeforeDate:seasonDate];
                NSInteger totalDays = [seasonDate daysBeforeDate:seasonEndDate];
                
                float percentDone = (daysLeft / totalDays);
                
                _springProgressView.progress = percentDone;
                
                
                
            }
            
            if ([seasonDateType isEqualToString:@"Summer Solstace"])
            {
                _summerProgressView.hidden = NO;
                float daysLeft = [[NSDate date]daysBeforeDate:seasonEndDate];
                float totalDays = [seasonDate daysBeforeDate:seasonEndDate];
                
                float percentDone = (daysLeft / totalDays);
                
                _summerProgressView.progress = percentDone;

            }
            
            if ([seasonDateType isEqualToString:@"Fall Equinox"])
            {
                
                _fallProgressView.hidden  = NO;
                float daysLeft = [[NSDate date]daysBeforeDate:seasonEndDate];
                float totalDays = [seasonDate daysBeforeDate:seasonEndDate];
                
                float percentDone = (daysLeft / totalDays);
                
                _fallProgressView.progress = percentDone;

            }
            
            if ([seasonDateType isEqualToString:@"Winter Solstace"])
            {
                 _winterProgressView.hidden = NO;
                float daysLeft = [[NSDate date]daysBeforeDate:seasonEndDate];
                float totalDays = [seasonDate daysBeforeDate:seasonEndDate];
                
                float percentDone = (daysLeft / totalDays);
                
                _winterProgressView.progress = percentDone;
            }
            
        }
    }];

}

- (void)loadFullMoonFromParse
{
    //Create query for all Post object by the current user
    PFQuery *postQuery = [PFQuery queryWithClassName:@"Almanac"];
    
    [postQuery whereKey:@"eventDate" greaterThanOrEqualTo:[NSDate date]];
    [postQuery whereKey:@"eventType" containsString:@"Full Moon"];
    // Run the query
    [postQuery findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            //Save results and update the table
            // [PFObject pinAllObjectsInBackground:objects];
            
            PFObject *moonDateobj = [objects objectAtIndex:0];

            NSDate *moonDate = [moonDateobj objectForKey:@"eventDate"];
            _moonFullDateLabel.text = [self stringFromDate:moonDate];
        }
    }];
}

- (void)loadSpringDateFromParse
{
    //Create query for all Post object by the current user
    PFQuery *postQuery = [PFQuery queryWithClassName:@"Almanac"];
    
    [postQuery whereKey:@"eventDate" greaterThanOrEqualTo:[NSDate date]];
    [postQuery whereKey:@"eventType" containsString:@"Spring Equinox"];
    // Run the query
    [postQuery findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            //Save results and update the table
            // [PFObject pinAllObjectsInBackground:objects];
            
            PFObject *moonDateobj = [objects objectAtIndex:0];

            NSDate *moonDate = [moonDateobj objectForKey:@"eventDate"];
            _springDateLabel.text = [self stringFromDate:moonDate];
        }
    }];
}

- (void)loadFallDateFromParse
{
    //Create query for all Post object by the current user
    PFQuery *postQuery = [PFQuery queryWithClassName:@"Almanac"];
    
    [postQuery whereKey:@"eventDate" greaterThanOrEqualTo:[NSDate date]];
    [postQuery whereKey:@"eventType" containsString:@"Fall Equinox"];
    // Run the query
    [postQuery findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            //Save results and update the table
            // [PFObject pinAllObjectsInBackground:objects];
            
            PFObject *moonDateobj = [objects objectAtIndex:0];
            
            NSDate *moonDate = [moonDateobj objectForKey:@"eventDate"];
            _fallDateLabel.text = [self stringFromDate:moonDate];
        }
    }];
}


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

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
