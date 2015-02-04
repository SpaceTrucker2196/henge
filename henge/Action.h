//
//  Action.h
//  henge
//
//  Created by Jeff Kunzelman on 2/4/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Action : NSManagedObject

@property (nonatomic, retain) NSDate * timestamp;
@property (nonatomic, retain) NSNumber * watered;
@property (nonatomic, retain) NSNumber * amended;
@property (nonatomic, retain) NSNumber * weeded;
@property (nonatomic, retain) NSManagedObject *observation;

@end
