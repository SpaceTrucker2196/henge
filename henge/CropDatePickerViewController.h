//
//  CropDatePickerViewController.h
//  henge
//
//  Created by Jeff Kunzelman on 2/4/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol CropDatePickerDelegate <NSObject>
@required
-(void)datePicked:(NSDate *)date;
@end

@interface CropDatePickerViewController : UIViewController
@property (weak, nonatomic) IBOutlet UIDatePicker *datePicker;

@property (nonatomic, weak) id<CropDatePickerDelegate> delegate;

- (IBAction)plantedButtonAction:(id)sender;

@end
