//
//  CropObservationNotesViewController.h
//  henge
//
//  Created by Jeff Kunzelman on 2/11/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Crop.h"

@interface CropObservationNotesViewController : UIViewController

@property (weak, nonatomic) IBOutlet UITextField *cropNameTextField;
@property (weak, nonatomic) IBOutlet UILabel *detailsLabel;
@property (weak, nonatomic) IBOutlet UITextView *notesTextView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *textViewBottomSpaceConstraint;
@property (strong, nonatomic) Crop *cropInView;
@property (strong, nonatomic) Observation *observationInView;


- (IBAction)closeButtonAction:(id)sender;

@end
