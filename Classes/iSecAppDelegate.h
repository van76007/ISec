//
//  iSecAppDelegate.h
//  iSec
//
//  Created by van on 3/17/11.
//  Copyright 2011 THINK GREEN LTD. All rights reserved.
//

#import <UIKit/UIKit.h>
#include <notify.h>
#import <sys/sysctl.h>

#import "AsyncUDPSocket.h"
#import "Reachability.h"

// Macro to turn ON/OFF debug log files in PROD/DEBUG
#ifdef DEBUG
#   define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#   define DLog(...)
#endif

@class iSecViewController;

@interface iSecAppDelegate : NSObject <UIApplicationDelegate> {
    
	UIWindow *window;
    iSecViewController *viewController;
	
	// DNS socket listening on port 53
	AsyncUDPSocket *echo;
	AsyncUDPSocket * _echo;
	
	// Alert user
	NSInteger _networkingCount;
	NSTimer	*_bgTimer;
	BOOL _criticalTimeAlertShown;
	
	// Check if the Internet is available
	Reachability* internetReachable;
	
	// Decide if redirect error to log file or not
	BOOL stdErrRedirected;
}

// Private
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;
- (void)handleNetworkChange:(NSNotification *)notice;
- (BOOL)checkInternet;
- (BOOL)checkDNSSettings;
- (void)startUDPSocket;
- (void)redirectStdErrToFile;
- (void)restoreStdErr;

// Public
- (NSArray *)runningProcesses; // list of running processes

// Declare properties
@property (nonatomic, retain, readwrite) AsyncUDPSocket *echo;
@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet iSecViewController *viewController;
@property (nonatomic, retain, readwrite) Reachability* internetReachable;
@property (nonatomic, assign) BOOL stdErrRedirected;

@end

