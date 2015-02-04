//
//  AlmanacViewController.m
//  henge
//
//  Created by Jeff Kunzelman on 1/29/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import "AlmanacViewController.h"
#import "Parse/Parse.h"

@interface AlmanacViewController ()

@end

@implementation AlmanacViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self loadNewMoonFromParse];
    [self loadFullMoonFromParse];
    [self loadSpringDateFromParse];
    [self loadFallDateFromParse];
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
            
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
            [dateFormatter setDateStyle:NSDateFormatterFullStyle];
            NSDate *moonDate = [moonDateobj objectForKey:@"eventDate"];
            _moonNewDateLabel.text = [dateFormatter stringFromDate:moonDate];
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
            
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
            [dateFormatter setDateStyle:NSDateFormatterFullStyle];
            NSDate *moonDate = [moonDateobj objectForKey:@"eventDate"];
            _moonFullDateLabel.text = [dateFormatter stringFromDate:moonDate];
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
            
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
            [dateFormatter setDateStyle:NSDateFormatterFullStyle];
            NSDate *moonDate = [moonDateobj objectForKey:@"eventDate"];
            _springDateLabel.text = [dateFormatter stringFromDate:moonDate];
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
            
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
            [dateFormatter setDateStyle:NSDateFormatterFullStyle];
            NSDate *moonDate = [moonDateobj objectForKey:@"eventDate"];
            _fallDateLabel.text = [dateFormatter stringFromDate:moonDate];
        }
    }];
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
