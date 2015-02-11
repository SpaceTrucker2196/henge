//
//  AppDelegate.h
//  henge
//
//  Created by Jeff Kunzelman on 1/28/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//



#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import <Parse/Parse.h>
//!  Henge
/*!
    Henge is an agricultural calendar and crop calculator. It uses Parse to share a common database of vegitable cultivars amoung all app users. 
    A Henge user can use the Botanica database to import crop information to a local store and then track that crop through out the growing season.
 */
@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext; ///< Managed object context used by the Main Thread.
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel; ///< Apps Managed object model
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator; ///< Persistant store coordinator used by all Threads.

- (void)saveContext; ///< save the current Main Thread context

- (NSURL *)applicationDocumentsDirectory; ///< Retrieves the URL of the Apps Document directory.


@end

