//
//  CropHistoryViewController.h
//  henge
//
//  Created by Jeff Kunzelman on 2/10/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Crop.h"

@interface CropHistoryViewController : UIViewController

@property (nonatomic,strong) Crop *cropInView;
@property (weak, nonatomic) IBOutlet UITextField *nameTextField;
@property (weak, nonatomic) IBOutlet UILabel *detailsTextField;

- (IBAction)closeButtonAction:(id)sender;
@end
