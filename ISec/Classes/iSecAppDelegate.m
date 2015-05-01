//
//  iSecAppDelegate.m
//  iSec
//
//  Created by van on 3/17/11.
//  Copyright 2011 THINK GREEN LTD. All rights reserved.
//

#import "iSecAppDelegate.h"
#import "iSecViewController.h"

#import <UIKit/UIKit.h> // For checking application state
#include <unistd.h> // For sleep() & redirectStdErrToFile
#import <CoreFoundation/CoreFoundation.h> // For CFNotificationCenter Reference
#include <notify.h> // For CFNotificationCenter Reference

// converts mins to seconds
#define MINS(N) N * 60
// number of minutes until the critical or warning UIAlert is displayed
#define PROXY_BG_TIME_CRITICAL_MINS 2
// interval of seconds to poll/check the time remaining for the background task
#define PROXY_BG_TIME_CHECK_SECS 10

@implementation iSecAppDelegate

@synthesize window;
@synthesize viewController;
@synthesize echo      = _echo;
@synthesize internetReachable;
@synthesize stdErrRedirected;
static int savedStdErr = 0;

// Turn ON Redirect error log from console to file
- (void)redirectStdErrToFile
{
	if (!stdErrRedirected)
	{
		stdErrRedirected = YES;
		savedStdErr = dup(STDERR_FILENO);
		NSString *cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
		NSString *logPath = [cachesDirectory stringByAppendingPathComponent:@"iSec.log"];
		freopen([logPath cStringUsingEncoding:NSASCIIStringEncoding], "a+", stderr);
	}
}

// Turn OFF Redirect error log from console to file 
- (void)restoreStdErr
{
	if (stdErrRedirected)
	{
		stdErrRedirected = NO;
		fflush(stderr);
		dup2(savedStdErr, STDERR_FILENO);
		close(savedStdErr);
		savedStdErr = 0;
	}
}

#pragma mark -
#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    
    // Add the view controller's view to the window and display.
    [self.window addSubview:viewController.view];
    [self.window makeKeyAndVisible];
	
	// Override point for customization after application launch.
	[self redirectStdErrToFile];
	DLog(@"application didFinishLaunchingWithOptions");
	application.idleTimerDisabled = YES; // Prevent your iPhone from going to sleep
	
	// Check application state
	UIApplication*    app = [UIApplication sharedApplication];
	UIApplicationState state = [app applicationState];
	if (state == UIApplicationStateBackground )
	{
		DLog(@"Application is in background");
	} else {
		DLog(@"Application is not in background");
	}
	
	// Check if the Internet is available. Init new object
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(handleNetworkChange:) 
												 name:kReachabilityChangedNotification object:nil];
	self.internetReachable = [[Reachability reachabilityForInternetConnection] retain];
	[self.internetReachable startNotifier];
	_bgTimer = NULL;
	_criticalTimeAlertShown = NO;
    
	// Redirect std to file
	// File name will be found here : <Application_Home>/Documents folder
	[self redirectStdErrToFile];
	
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
	DLog(@"applicationWillResignActive");
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, called instead of applicationWillTerminate: when the user quits.
     */
	DLog(@"applicationDidEnterBackground");
	
	// Background task: Start a timer to show notification after 10mins or so on
	_criticalTimeAlertShown = NO;
	
	if (!_bgTimer) {
		_bgTimer = [NSTimer scheduledTimerWithTimeInterval:PROXY_BG_TIME_CHECK_SECS
													target:self
												  selector:@selector(checkBackgroundTimeRemaining:)
												  userInfo:nil
												   repeats:YES];
	}
	
    __block UIBackgroundTaskIdentifier ident;	
    ident = [application beginBackgroundTaskWithExpirationHandler: ^{
        DLog(@"Background task expiring!");
		
		[self.echo stop];
		self.echo._LISTENING = NO;
        [application endBackgroundTask: ident];
    }];	
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    /*
     Called as part of  transition from the background to the inactive state: here you can undo many of the changes made on entering the background.
     */
	DLog(@"applicationWillEnterForeground");
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
	DLog(@"application didBecomeActive");
	
	// Check if network available. If not, no need to do anything
	if (![self checkInternet])
	{
		UIAlertView *myAlert = [ [ UIAlertView alloc ] initWithTitle:@"Alert" message:@"You are not connected to the Internet" 
															delegate:self
												   cancelButtonTitle: nil otherButtonTitles: @"OK", nil];
		[myAlert show];
		return;
	}
	
	// Check/re-check the DNS settings again
	// If the settting is not OK, remind user and stop socket
	if ([self checkDNSSettings]) {
		[UIApplication sharedApplication].applicationIconBadgeNumber = 0;
		UIAlertView *myAlert = [ [ UIAlertView alloc ] initWithTitle:@"Alert" message:@"You are protected by iSec" 
															delegate:self
												   cancelButtonTitle: nil otherButtonTitles: @"OK", nil];
		[myAlert show];
		
		// If the setting is OK. Restart the socket
		[self startUDPSocket];	
	} else {
		DLog(@"To show warning");
		// Pop up alert view
		UIAlertView *myAlert = [ [ UIAlertView alloc ] initWithTitle:@"Alert" message:@"You are not protected by iSec! Please refer to the manual to change your network settings and try again" 
															delegate:self
															cancelButtonTitle: nil otherButtonTitles: @"OK", nil];
		[myAlert show];
	}
}

- (void)applicationWillTerminate:(UIApplication *)application {
    /*
     Called when the application is about to terminate.
     See also applicationDidEnterBackground:.
     */
	DLog(@"applicationWillTerminate");
	
	[self.echo release];
	DLog(@"self.echo released ...");
	
	[self.internetReachable release];
	DLog(@"self.internetReachable released ...");
	
	// Reenable device sleep mode on exit
	[UIApplication sharedApplication].idleTimerDisabled = NO;
	DLog(@"UIApplication sharedApplication].idleTimerDisabled");
	
	// Delete all notifications
	[[UIApplication sharedApplication] cancelAllLocalNotifications];
	DLog(@"[UIApplication sharedApplication] cancelAllLocalNotifications");
	
	// Stop checking network reachability
	[self.internetReachable stopNotifier];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	DLog(@"Stop checking network reachability");
}

#pragma mark -
#pragma mark Memory management
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    /*
     Free up as much memory as possible by purging cached data objects that can be recreated (or reloaded from disk) later.
     */
	DLog(@"applicationDidReceiveMemoryWarning");
}

- (void)dealloc {
	
	DLog(@"Dealloc ...");
	
    [viewController release];
    DLog(@"viewController released ...");
	
	[window release];
    DLog(@"window released ...");
	
	[super dealloc];
}

#pragma mark -
#pragma mark Show Notification
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	DLog(@"Button %d pressed", buttonIndex); 
	[ alertView release ];	
}

- (void)checkBackgroundTimeRemaining:(NSTimer *)tmr
{	
	NSTimeInterval timeLeft = [UIApplication sharedApplication].backgroundTimeRemaining;
	DLog(@"Background time remaining: %.0f seconds (~%d mins)", timeLeft, (int)timeLeft / 60);
	
	UILocalNotification *notif = nil;
	
	if ( (timeLeft <= MINS(PROXY_BG_TIME_CRITICAL_MINS)) && (_criticalTimeAlertShown == NO) )
	{
		DLog(@"Set _criticalTimeAlertShown is NO");
		// Check if connect to the Internet
		BOOL needProtection = [self checkInternet];
		
		// Check if any of networking processes are running
		// Name of network processes need to be checked if running
		BOOL networkProcessRunning = NO;
		NSString *safari = @"MobileSafari";
		NSString *mail = @"MobileMail";
		NSString *map = @"Maps~iphone";
		
		NSArray * processes = [self runningProcesses];
		for (NSDictionary * dict in processes){
			DLog(@"%@ - %@", [dict objectForKey:@"ProcessID"], [dict
																objectForKey:@"ProcessName"]);
		}
		for (NSDictionary * dict in processes){
			
			NSString *process_name = [dict objectForKey:@"ProcessName"];
			networkProcessRunning = ([process_name isEqualToString:safari]) || ([process_name isEqualToString:mail])
			|| ([process_name isEqualToString:map]);
			if (networkProcessRunning) {
				DLog(@"Is running: %@", process_name);
				break;
			}
		}
		
		needProtection = needProtection && networkProcessRunning;
		
		if (needProtection) {
			DLog(@"Set _criticalTimeAlertShown = YES");
			_criticalTimeAlertShown = YES;
			NSString *msg = NSLocalizedString(@"Critical: iSecDNS expiring in %.0f seconds", nil);
			// build the UIAlert to be displayed
			notif = [UILocalNotification new];
			notif.alertBody = [NSString stringWithFormat:msg, timeLeft];
			notif.applicationIconBadgeNumber = 1;
			notif.alertAction = NSLocalizedString(@"Renew iSecDNS", nil);
			[[UIApplication sharedApplication] presentLocalNotificationNow:notif];
			[notif release];
		}
	} else if (timeLeft > MINS(PROXY_BG_TIME_CRITICAL_MINS)) {
		DLog(@"Set _criticalTimeAlertShown = NO");	
		_criticalTimeAlertShown = NO;
	}
}

#pragma mark -
#pragma mark Backgrounded socket
- (void)handleNetworkChange:(NSNotification *)notice
{
	BOOL connected = YES;
	NetworkStatus internetStatus = [self.internetReachable currentReachabilityStatus];
	
	switch (internetStatus)
	{
		case NotReachable:
		{
			DLog(@"handleNetworkChange. The internet is down.");
			connected = NO;
			break;
		}
		case ReachableViaWiFi:
		{
			DLog(@"handleNetworkChange. The internet is working via WIFI.");
			break;
		}
		case ReachableViaWWAN:
		{
			DLog(@"handleNetworkChange. The internet is working via WWAN.");
			break;
		}
	}
	
	if (connected) {
		NSLog(@"handleNetworkChange. Connected ...");
		if (![self checkDNSSettings]) {
			DLog(@"To show warning");
			
			// Pop up notification immediately
			UILocalNotification *notif = nil;
			notif = [UILocalNotification new];
			notif.alertBody = @"Network changed!You are not protected by iSec! Please refer to the manual to change your network settings and try again";
			notif.hasAction = NO;
			[[UIApplication sharedApplication] presentLocalNotificationNow:notif];
			[notif release];	
		}
	}
}

- (BOOL)checkInternet
{
	BOOL ok = YES;
	NetworkStatus internetStatus = [self.internetReachable currentReachabilityStatus];
	
	switch (internetStatus)
	{
		case NotReachable:
		{
			DLog(@"The internet is down.");
			ok = NO;
			break;
		}
		case ReachableViaWiFi:
		{
			DLog(@"The internet is working via WIFI.");
			ok = YES;
			break;
		}
		case ReachableViaWWAN:
		{
			DLog(@"The internet is working via WWAN.");
			ok = YES;
			break;
		}
	}
	
	return ok;
}

- (BOOL)checkDNSSettings
{
	BOOL ok = NO;
	if (self.echo == nil) 
	{
		DLog(@"Initializing self.echo ... ");
		
		self.echo = [[[AsyncUDPSocket alloc] init] autorelease];
		assert(self.echo != nil);
	}
	
	// Get DNS server. Must do this check again everytime we launch application in the background
	ok = [self.echo getDefaultDNS];
	
	return ok;
}

- (void)startUDPSocket
{
	// Start socket
	if (self.echo != nil) 
	{
		// Start listening to port 53
		DLog(@"self.echo start listening... ");
		[self.echo start];
	}
}

#pragma mark Swiss utils
- (NSArray *)runningProcesses {
	
	int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
	size_t miblen = 4;
	
	size_t size;
	int st = sysctl(mib, miblen, NULL, &size, NULL, 0);
	
	struct kinfo_proc * process = NULL;
	struct kinfo_proc * newprocess = NULL;
	
	do {
		
		size += size / 10;
		newprocess = realloc(process, size);
		
		if (!newprocess){
			
			if (process){
				free(process);
			}
			
			return nil;
		}
		
		process = newprocess;
		st = sysctl(mib, miblen, process, &size, NULL, 0);
		
	} while (st == -1 && errno == ENOMEM);
	
	if (st == 0){
		
		if (size % sizeof(struct kinfo_proc) == 0){
			int nprocess = size / sizeof(struct kinfo_proc);
			
			if (nprocess){
				
				NSMutableArray * array =
				[[NSMutableArray alloc] init];
				
				for (int i = nprocess - 1; i >= 0; i--){
					
					NSString * processID =
					[[NSString alloc] initWithFormat:@"%d", process[i].kp_proc.p_pid];
					NSString * processName =
					[[NSString alloc] initWithFormat:@"%s", process[i].kp_proc.p_comm];
					
					NSDictionary * dict =
					[[NSDictionary alloc] initWithObjects:[NSArray
														   arrayWithObjects:processID, processName, nil]
					 
					 
												  forKeys:[NSArray arrayWithObjects:@"ProcessID", @"ProcessName",
														   nil]];
					[processID release];
					[processName release];
					[array addObject:dict];
					[dict release];
				}
				
				free(process);
				return [array autorelease];
			}
		}
	}
	
	return nil;
}

@end
