//
//  AlmanacViewController.h
//  henge
//
//  Created by Jeff Kunzelman on 1/29/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AlmanacViewController : UIViewController
@property (weak, nonatomic) IBOutlet UILabel *moonNewDateLabel;
@property (weak, nonatomic) IBOutlet UILabel *moonFullDateLabel;
@property (weak, nonatomic) IBOutlet UILabel *springDateLabel;
@property (weak, nonatomic) IBOutlet UILabel *fallDateLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *winterProgressView;
@property (weak, nonatomic) IBOutlet UIProgressView *springProgressView;
@property (weak, nonatomic) IBOutlet UIProgressView *summerProgressView;
@property (weak, nonatomic) IBOutlet UIProgressView *fallProgressView;

@end
