//
//  CropGrowingNotesViewController.m
//  henge
//
//  Created by Jeff Kunzelman on 2/9/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import "EditCropGrowingNotesViewController.h"

@interface EditCropGrowingNotesViewController ()

@end

@implementation EditCropGrowingNotesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    // register for keyboard notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWasShown:) name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillBeHidden:) name:UIKeyboardDidHideNotification object:nil];
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:YES];
    
    _cultivarName.text = _cropInView.cultivar;
    _growingNotesTextView.text = _cropInView.cultivarNotes;
    
    if ([_cropInView.cultivarNotes length] < 1)
    {
        [_growingNotesTextView becomeFirstResponder];
    }
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/



#pragma mark - Keyboard handling

-(void)keyboardWasShown:(NSNotification *)notif
{
    CGRect keyboardRect = [[notif.userInfo objectForKey:UIKeyboardFrameBeginUserInfoKey]CGRectValue];
    _textViewBottomSpaceConstraint.constant = keyboardRect.size.height ;
    [self.view layoutIfNeeded];
    
}

-(void)keyboardWillBeHidden:(NSNotification *)notif
{
    _textViewBottomSpaceConstraint.constant = 0;
    // [self.view layoutIfNeeded];
}

- (IBAction)closeButton:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end
