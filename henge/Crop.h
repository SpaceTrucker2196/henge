//
//  Crop.h
//  henge
//
//  Created by Jeff Kunzelman on 2/3/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Crop : NSManagedObject

@property (nonatomic, retain) NSDecimalNumber * cost;
@property (nonatomic, retain) NSString * cropId;
@property (nonatomic, retain) NSString * cultivar;
@property (nonatomic, retain) NSString * field;
@property (nonatomic, retain) NSNumber * matureEarlyDays;
@property (nonatomic, retain) NSNumber * matureLateDays;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSDate * seededDate;
@property (nonatomic, retain) NSDate * transplantedDate;
@property (nonatomic, retain) NSString * vendor;

@end
