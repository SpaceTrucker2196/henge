//
//  Crop.h
//  henge
//
//  Created by Jeff Kunzelman on 2/8/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Observation;

@interface Crop : NSManagedObject

@property (nonatomic, retain) NSDecimalNumber * seedCost;
@property (nonatomic, retain) NSString * cropId;
@property (nonatomic, retain) NSString * cultivar;
@property (nonatomic, retain) NSString * field;
@property (nonatomic, retain) NSNumber * matureEarlyDays;
@property (nonatomic, retain) NSNumber * matureLateDays;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSDate * seededDate;
@property (nonatomic, retain) NSDate * transplantedDate;
@property (nonatomic, retain) NSString * vendor;
@property (nonatomic, retain) NSString * yearGrown;
@property (nonatomic, retain) NSDecimalNumber * seedCountCommonRow;
@property (nonatomic, retain) NSDecimalNumber * seedWeightAcre;
@property (nonatomic, retain) NSString * seedWeightAcreUnit;
@property (nonatomic, retain) NSDecimalNumber * seedCountAcre;
@property (nonatomic, retain) NSString * seedCountAcreUnit;
@property (nonatomic, retain) NSDecimalNumber * commonRowYield;
@property (nonatomic, retain) NSString * commonRowYieldUnit;
@property (nonatomic, retain) NSDecimalNumber * acreYield;
@property (nonatomic, retain) NSString * acreYieldUnit;
@property (nonatomic, retain) NSDecimalNumber * storageHumidityPercent;
@property (nonatomic, retain) NSDecimalNumber * storageTempF;
@property (nonatomic, retain) NSDecimalNumber * storageHoldWeeks;
@property (nonatomic, retain) NSString * cultivarNotes;
@property (nonatomic, retain) NSDecimalNumber * rowCountPlanted;
@property (nonatomic, retain) NSDecimalNumber * rowLengthPlanted;
@property (nonatomic, retain) NSString * acrePlanted;
@property (nonatomic, retain) NSString * acreSeedsPlanted;
@property (nonatomic, retain) NSNumber * rowSeedsPlanted;
@property (nonatomic, retain) NSDecimalNumber * transplantsPlanted;
@property (nonatomic, retain) NSNumber * matureDaysCommon;
@property (nonatomic, retain) NSSet *observations;
@end

@interface Crop (CoreDataGeneratedAccessors)

- (void)addObservationsObject:(Observation *)value;
- (void)removeObservationsObject:(Observation *)value;
- (void)addObservations:(NSSet *)values;
- (void)removeObservations:(NSSet *)values;

@end
