//
//  CropGrowingNotesViewController.h
//  henge
//
//  Created by Jeff Kunzelman on 2/9/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Crop.h"

@interface EditCropGrowingNotesViewController : UIViewController
@property (weak, nonatomic) Crop *cropInView;
@property (weak, nonatomic) IBOutlet UILabel *cultivarName;
@property (weak, nonatomic) IBOutlet UITextView *growingNotesTextView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *textViewBottomSpaceConstraint;

- (IBAction)closeButton:(id)sender;

@end
