//
//  iSecViewController.h
//  iSec
//
//  Created by van on 3/17/11.
//  Copyright 2011 THINK GREEN LTD. All rights reserved.
//

#import <UIKit/UIKit.h>

// Macro to turn ON/OFF debug log files in PROD/DEBUG
#ifdef DEBUG
#   define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#   define DLog(...)
#endif

@interface iSecViewController : UIViewController 
{}

- (IBAction)btnSafariPressed:(id)sender;
- (IBAction)btnMailPressed:(id)sender;
- (IBAction)btnMapsPressed:(id)sender;
- (IBAction)btnYouTubePressed:(id)sender;
- (IBAction)btnITunesPressed:(id)sender;
- (IBAction)btnAppStorePressed:(id)sender;

@end

