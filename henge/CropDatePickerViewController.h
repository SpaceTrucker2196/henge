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
//!  CropDatepicker
/*!
    A simple reusable date picker with a protocol to update 
    a date.
 */
@interface CropDatePickerViewController : UIViewController
@property (weak, nonatomic) IBOutlet UIDatePicker *datePicker; /*! The views datepicker */

@property (nonatomic, weak) id<CropDatePickerDelegate> delegate;  /*! The delegate who wants to know the date. */

- (IBAction)plantedButtonAction:(id)sender; /*! the action button which closes the view and picks the date*/

@end
