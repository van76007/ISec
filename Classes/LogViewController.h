//
//  FirstViewController.h
//  iScreenDNS
//
//  Created by van on 6/9/11.
//  Copyright 2011 THINK GREEN LTD. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "ResponseData.h"
#import "DBManager.h"

@interface LogViewController : UIViewController
							   <UITableViewDataSource, UITableViewDelegate> {
	
	//UIView *mLogView;							   
	UITableView *masterView; // Show category of blocked domain
	UITableView *detailView; // Show list of blocked domain for each category
    
	int numBlockedVisit;
	NSArray *category; // Category of blocked domains
	NSMutableArray *visits; // Array of logged blocked visits
}

//@property (nonatomic, retain) IBOutlet UIView* logView;
@property(nonatomic, retain) UITableView *masterView;
@property(nonatomic, retain) UITableView *detailView;
 
@property(nonatomic, retain) NSArray *category;
@property(nonatomic, retain) NSMutableArray *visits;

// Read list of blocked domains from DB based on category
- (BOOL)readVisitsByTag:(NSInteger)tag; 

// Populate detailView with list of blocked domains
- (void)showDetails:(UIButton *)paramSender;

@end
