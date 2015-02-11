//
//  AlmanacViewController.h
//  henge
//
//  Created by Jeff Kunzelman on 1/29/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import <UIKit/UIKit.h>
//!  AlmanacViewController
/*!
 The AlmanacViewController is the home screen showing calendar information and embeds a tableview of the list of crops.
 Moon and Season dates are loaded from parse.
 */
@interface AlmanacViewController : UIViewController
@property (weak, nonatomic) IBOutlet UILabel *moonNewDateLabel;  /*! The current New date */
@property (weak, nonatomic) IBOutlet UILabel *moonFullDateLabel; /*! The current Full Moon date */
@property (weak, nonatomic) IBOutlet UILabel *springDateLabel; /*! This years spring date */
@property (weak, nonatomic) IBOutlet UILabel *fallDateLabel; /*! This years fall date */
@property (weak, nonatomic) IBOutlet UIProgressView *winterProgressView; /*! Season progress view segment */
@property (weak, nonatomic) IBOutlet UIProgressView *springProgressView; /*! Season progress view segment */
@property (weak, nonatomic) IBOutlet UIProgressView *summerProgressView; /*! Season progress view segment */
@property (weak, nonatomic) IBOutlet UIProgressView *fallProgressView; /*! Season progress view segment */
@end
