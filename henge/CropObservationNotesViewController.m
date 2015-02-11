//
//  CropObservationNotesViewController.m
//  henge
//
//  Created by Jeff Kunzelman on 2/11/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import "CropObservationNotesViewController.h"
#import "Observation.h"

@interface CropObservationNotesViewController ()

@end

@implementation CropObservationNotesViewController

- (void)viewDidLoad
{
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

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:YES];
    [self configureView];
    
    if (!_observationInView)
    {
        [_notesTextView becomeFirstResponder];
    }
}

-(void)configureView
{
    _cropNameTextField.text = _cropInView.name;
    NSDateFormatter *dateformatter = [[NSDateFormatter alloc] init];
    [dateformatter setDateFormat:@"MMMM dd"];
    _detailsLabel.text = [dateformatter stringFromDate:[NSDate date]];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Keyboard handling
//Handle KeyboardWasShown and change the size of the text view in proportion
-(void)keyboardWasShown:(NSNotification *)notif
{
    CGRect keyboardRect = [[notif.userInfo objectForKey:UIKeyboardFrameBeginUserInfoKey]CGRectValue];
    _textViewBottomSpaceConstraint.constant = keyboardRect.size.height ;
    [self.view layoutIfNeeded];
    
}

//Handle KeyboardWillBeHidden and reset textView
-(void)keyboardWillBeHidden:(NSNotification *)notif
{
    _textViewBottomSpaceConstraint.constant = 0;
    // [self.view layoutIfNeeded];
}

- (IBAction)closeButtonAction:(id)sender
{
    if ([_notesTextView.text length] > 0)
    {
        Observation *observation = [NSEntityDescription insertNewObjectForEntityForName:@"Observation" inManagedObjectContext:_cropInView.managedObjectContext];

        observation.timestamp = [NSDate date];
        observation.actionDescription = @"Note";
        observation.note = _notesTextView.text;
        observation.crop = _cropInView;
        
        [_cropInView.managedObjectContext save:nil];
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end
