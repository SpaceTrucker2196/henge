//
//  CropHistoryViewController.m
//  henge
//
//  Created by Jeff Kunzelman on 2/10/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import "CropHistoryViewController.h"
#import "CropHist

@interface CropHistoryViewController ()

@end

@implementation CropHistoryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)viewWillAppear:(BOOL)animated
{
    [self configureView];
}
#pragma mark - Navigation

 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 
     if ([[segue identifier] isEqualToString:@"seededDatePopover"])
     {
         CropDatePickerViewController *gvc = [segue destinationViewController];
         gvc.delegate = self;
       
     }
}

-(void)configureView
{
    _detailsTextField.text = _cropInView.cultivar;
    _nameTextField.text = _cropInView.name;
}

- (IBAction)closeButtonAction:(id)sender
{

    [self dismissViewControllerAnimated:YES completion:nil];
}
@end
