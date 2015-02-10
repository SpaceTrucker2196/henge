//
//  VegiCalcTableViewController.m
//  henge
//
//  Created by Jeff Kunzelman on 1/29/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import "BotanicaTableViewController.h"
//#import "Parse/Parse.h"
#import "BotanicaDetailViewController.h"
#import "BotanicaTableViewCell.h"

@interface BotanicaTableViewController ()

@property (nonatomic, strong) NSArray *vegiArray;

@end

@implementation BotanicaTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    self.vegiArray = [[NSArray alloc]init];
    self.tableView.delegate = self;
   [self loadFromParse];
}

-(void)viewWillAppear:(BOOL)animated
{
   // [self loadFromParse];
    [self.tableView reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)loadFromParse
{
    //Create query for all Post object by the current user
    PFQuery *postQuery = [PFQuery queryWithClassName:@"VegiMatrix"];
    //[postQuery whereKeyExists:@"objectId"];
    
    // Run the query
    [postQuery findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            //Save results and update the table
            //[PFObject pinAllObjectsInBackground:objects];
            self.vegiArray = nil;
            self.vegiArray = [NSArray arrayWithArray:objects];
            
        }
        
        [NSTimer scheduledTimerWithTimeInterval:2.0
                                         target:self
                                       selector:@selector(refreshView)
                                       userInfo:nil
                                        repeats:NO];

        
    }];
}
-(void)refreshView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
        [self.tableView layoutSubviews];
    });
}
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"VegiCalcDetailsSegue"]) {
        
        // note that "sender" will be the tableView cell that was selected
        UITableViewCell *cell = (UITableViewCell*)sender;
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        
        BotanicaDetailViewController *vc = (BotanicaDetailViewController *)[segue destinationViewController];
        [vc loadCultivarObj:[_vegiArray objectAtIndex:indexPath.row]];
    }
}

#pragma mark - Table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [_vegiArray count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    BotanicaTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BotanicaTableViewCell" forIndexPath:indexPath];
    
    // Configure the cell...
    
    // Configure the cell...
    PFObject *vegiObject = [_vegiArray objectAtIndex:indexPath.row];

    cell.titleLabel.text =  [vegiObject objectForKey:@"cultivarCommon"];
    
    
    return cell;
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
