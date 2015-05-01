//
//  FirstViewController.m
//  iScreenDNS
//
//  Created by van on 6/9/11.
//  Copyright 2011 THINK GREEN LTD. All rights reserved.
//

#import "LogViewController.h"

static const CGFloat kMargin = 5.0f;

@implementation LogViewController

//@synthesize logView = mLogView;
@synthesize masterView, detailView;
@synthesize category, visits;

// The designated initializer. Override to perform setup that is required before the view is loaded.
/*
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (self) {
        // Custom initialization
		//self.visits = NULL;
    }
    return self;
}
*/

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
}
*/

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
	// Prepare the data source for each views
	// Read entire data from source when view did load. But it is not good as data will become obsolete
	// Better when we refresh the data, we querry the table by index as row
	// After finishing extract data, remember to call [table reloadData];
	NSMutableArray *array = [[NSArray alloc] initWithObjects:@"Abusive", @"Drive-by", @"Backdoor", @"Malware", 
							 @"Trojan", @"Typosquatting", @"Unknown", @"Fishing", nil];
	self.category = array;
	[array release];
	
	// TEST
	//[self readVisitsByTag:1];

	// Add Views
	CGRect currentViewFrame = self.view.bounds;
	
	// Create the first view: Master view
	CGRect masterViewRect = CGRectMake(kMargin, kMargin,
									   currentViewFrame.size.width - 2*kMargin,
									   (currentViewFrame.size.height -3*kMargin) / 2.0f);
	
	UITableView *tableViewMaster = [[UITableView alloc]
							  initWithFrame:masterViewRect style:UITableViewStylePlain];
	
	self.masterView = tableViewMaster;
	[tableViewMaster release];
	
	self.masterView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[[self.masterView layer] setCornerRadius:5];
	//[self.masterView setClipsToBounds:YES];
	[[self.masterView layer] setBorderWidth:1];
	
	[self.view addSubview:self.masterView];
	self.masterView.dataSource = self;
	self.masterView.delegate = self;

	// Create the second view: Detail view
	CGRect detailViewRect = CGRectMake(kMargin,
									   (currentViewFrame.size.height + kMargin) / 2.0f,
									   currentViewFrame.size.width - 2*kMargin,
									   (currentViewFrame.size.height - 3*kMargin) / 2.0f);
	
	UITableView *tableViewDetail = [[UITableView alloc]
									 initWithFrame:detailViewRect style:UITableViewStylePlain];
	
	self.detailView = tableViewDetail;
	[tableViewDetail release];
	
	self.detailView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
	
	[[self.detailView layer] setCornerRadius:5];
	[self.detailView setClipsToBounds:YES];
	[[self.detailView layer] setBorderWidth:1];
	
	[self.view addSubview:self.detailView];
	self.detailView.dataSource = self;
	self.detailView.delegate = self;
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    //return (interfaceOrientation == UIInterfaceOrientationPortrait);
	return YES;
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
	self.masterView = nil;
	self.detailView = nil;
	if (self.visits) {
		self.visits = NULL;
	}
}

- (void)dealloc {
    [super dealloc];
}

// Extract list of visited URLs based on category
// HINT: http://stackoverflow.com/questions/3835464/iphone-return-nsmutablearray-in-method-while-still-releasing
- (BOOL)readVisitsByTag:(NSInteger)tag {
	
	// Extract data from SQLite DB. Passing it around
	DBManager *dbManager = [DBManager sharedInstance];
	self.visits = [dbManager extractDomainsByTag:tag];
	
	if (self.visits) {
		numBlockedVisit = [self.visits count];
		DLog(@"readVisitsByTag OK. num of element %d", numBlockedVisit);
		// TEST
		for (int i = 0; i < [self.visits count]; i++) {
			BlockedVisit *visit = (BlockedVisit *)[self.visits objectAtIndex:i];
			DLog(@"Item[%d] domain is %@", i, [visit domain]);
			DLog(@"Item[%d] timestamp is %@", i, [visit timestamp]);
		}
		// Remember to call [self.visits release] when DONE with it
		return TRUE;
	} else {
		DLog(@"readVisitsByTag Failed");
		return FALSE;
	}
}

- (void)showDetails:(UIButton *)paramSender {
	
	UITableViewCell *ownerCell = (UITableViewCell*)paramSender.superview;
	
	if (ownerCell != nil){
		/* Now we will retrieve the index path of the cell which contains the section and the row of the cell */
		NSIndexPath *ownerCellIndexPath = [self.masterView indexPathForCell:ownerCell];
		if (ownerCellIndexPath.section == 0) {
			// Populate data
			DLog("Querry DB by tag %d", (ownerCellIndexPath.row + 1));
			if (self.visits) {
				DLog(@"Clearing prev visits ...");
				[self.visits release];
			} else {
				DLog(@"visits is NULL ...");
			}

			[self readVisitsByTag:(ownerCellIndexPath.row + 1)];
			[self.detailView reloadData];
			// Update button label
			if (numBlockedVisit > 0) {
				[paramSender setTitle:[NSString stringWithFormat:@"%d hits", numBlockedVisit] forState:UIControlStateHighlighted];
				[paramSender setTitle:[NSString stringWithFormat:@"%d hits", numBlockedVisit] forState:UIControlStateNormal];
			}
		}
	}
}

#pragma mark -
#pragma mark TableView data source methods

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *cellText = @"Tara";
    UIFont *cellFont = [UIFont fontWithName:@"Helvetica" size:17.0];
    CGSize constraintSize = CGSizeMake(280.0f, MAXFLOAT);
    CGSize labelSize = [cellText sizeWithFont:cellFont constrainedToSize:constraintSize lineBreakMode:UILineBreakModeWordWrap];	
    return labelSize.height + 20;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	DLog(@"cellForRowAtIndexPath");
	
	UITableViewCell* cell = nil;
	if ([tableView isEqual:self.masterView]) {
		
		DLog(@"MasterView Cell creating ...");
		static NSString *MyCellIdentifier = @"MasterCell";
		/* We will try to retrieve an existing cell with the given identifier */
		cell = [tableView dequeueReusableCellWithIdentifier:MyCellIdentifier];
		if (cell == nil){ 
			/* If a cell with the given identifier does not
			 exist, we will create the cell with the identifier and hand it to the table view 
			 */
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
											 reuseIdentifier:MyCellIdentifier] autorelease];
		}
		
		cell.textLabel.text = [self.category objectAtIndex:[indexPath row]];
		
		UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect]; 
		// Check size of button
		button.frame = CGRectMake(0.0, 0.0, 125.0, 25.0);
		
		[button setShowsTouchWhenHighlighted:YES];
		// Change background color: http://stackoverflow.com/questions/2808888/is-it-even-possible-to-change-a-uibuttons-background-color
		[button setTitle:@"Details" forState:UIControlStateNormal];
		
		[button addTarget:self 
				   action:@selector(showDetails:)
				   forControlEvents:UIControlEventTouchUpInside]; 
				
		cell.accessoryView = button;
	}
	
	if ([tableView isEqual:self.detailView]) {
		
		DLog(@"DetailView Cell creating ...");
		static NSString *MyCellIdentifier = @"DetailCell";
		/* We will try to retrieve an existing cell with the given identifier */
		cell = [tableView dequeueReusableCellWithIdentifier:MyCellIdentifier];
		if (cell == nil){ 
			/* If a cell with the given identifier does not
			 exist, we will create the cell with the identifier and hand it to the table view 
			 */
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
											 reuseIdentifier:MyCellIdentifier] autorelease];
		}
		
		cell.textLabel.lineBreakMode = UILineBreakModeWordWrap;
		cell.textLabel.numberOfLines = 0;
		cell.textLabel.font = [UIFont fontWithName:@"Helvetica" size:17.0];
		
		BlockedVisit *visit = [self.visits objectAtIndex:[indexPath row]];
		cell.textLabel.text = [NSString stringWithFormat:@"%@\nAt %@", [visit domain], [visit timestamp]];
	}
	
	return cell;
}

// Both Master and Slave have 1 section only
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

// Number of rows depends on master/detail view
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	
	NSInteger numRows = 0;
	// LILO between 2 table views as sender by this comparision 	
	if ([tableView isEqual:self.masterView]) {
		DLog(@"Call numberOfRowsInSection for master cell");
		numRows = 8;
	}
	// if ([tableView isEqual:self.detailView] == YES)
	if ([tableView isEqual:self.detailView]) {
		DLog(@"Call numberOfRowsInSection for detail cell");
		numRows = numBlockedVisit;
	}
	
	return numRows;
}

#pragma mark -
#pragma mark TableViewDelegate methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	
	DLog(@"didSelectRowAtIndexPath");
	
	if ([tableView isEqual:self.masterView]) {
		DLog(@"A rows in master view is selected");
		[self readVisitsByTag:(indexPath.row + 1)];
		[self.detailView reloadData];
		// Update button label
		if (numBlockedVisit > 0) {
			[[[self.masterView cellForRowAtIndexPath:indexPath] accessoryView] setTitle:[NSString stringWithFormat:@"%d hits", numBlockedVisit] forState:UIControlStateHighlighted];
			[[[self.masterView cellForRowAtIndexPath:indexPath] accessoryView] setTitle:[NSString stringWithFormat:@"%d hits", numBlockedVisit] forState:UIControlStateNormal];
		}

	}
	
	if ([tableView isEqual:self.detailView]) {
		// Do nothing for now
		DLog(@"A rows in detail view is selected");
	}
}

@end
