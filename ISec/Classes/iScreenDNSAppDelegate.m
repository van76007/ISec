//
//  iScreenDNSAppDelegate.m
//  iScreenDNS
//
//  Created by van on 6/9/11.
//  Copyright 2011 THINK GREEN LTD. All rights reserved.
//

#import "iScreenDNSAppDelegate.h"

#import <UIKit/UIKit.h> // For checking application state
#include <unistd.h> // For sleep() & redirectStdErrToFile

@implementation iScreenDNSAppDelegate

@synthesize window;
@synthesize tabBarController;
//
@synthesize echo      = _echo;
@synthesize internetReachable;
@synthesize stdErrRedirected;
@synthesize toggleDNSSettings;
static int savedStdErr = 0;

// Turn ON Redirect error log from console to file
- (void)redirectStdErrToFile
{
	if (!stdErrRedirected)
	{
		stdErrRedirected = YES;
		savedStdErr = dup(STDERR_FILENO);
		NSString *cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
		NSString *logPath = [cachesDirectory stringByAppendingPathComponent:@"iScreenDNS.log"];
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
    
    // Override point for customization after application launch.

    // Add the tab bar controller's view to the window and display.
    [self.window addSubview:tabBarController.view];
    [self.window makeKeyAndVisible];
	
	// Override point for customization after application launch
	DLog(@"application didFinishLaunchingWithOptions");
	
	// Check if the Internet is available. Init new object
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(handleNetworkChange:) 
												 name:kReachabilityChangedNotification object:nil];
	self.internetReachable = [[Reachability reachabilityForInternetConnection] retain];
	[self.internetReachable startNotifier];
    
	// Redirect std to file
	// File name will be found here : <Application_Home>/Documents folder
	[self redirectStdErrToFile];
	
	toggleDNSSettings = NO;

    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
	DLog(@"applicationWillResignActive");
	[self stopUDPSocket];
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, called instead of applicationWillTerminate: when the user quits.
     */
	DLog(@"applicationDidEnterBackground");
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
		
		// If the setting is OK. Restart the socket
		[self startUDPSocket];
		// NO MORE FOR NOW
		/*
		[UIApplication sharedApplication].applicationIconBadgeNumber = 0;
		UIAlertView *myAlert = [ [ UIAlertView alloc ] initWithTitle:@"Alert" message:@"You are protected by AvauntGuard" 
															delegate:self
												   cancelButtonTitle: nil otherButtonTitles: @"OK", nil];
		[myAlert show];
		*/	
	} else {
		DLog(@"To show warning");
		// Pop up alert view
		UIAlertView *myAlert = [ [ UIAlertView alloc ] initWithTitle:@"Alert" message:@"You are not protected by AvauntGuard! Please refer to the manual to change your network settings and try again" 
															delegate:self
												   cancelButtonTitle: nil otherButtonTitles: @"OK", nil];
		[myAlert show];
		toggleDNSSettings = TRUE;
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
#pragma mark UITabBarControllerDelegate methods

/*
// Optional UITabBarControllerDelegate method.
- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
}
*/

/*
// Optional UITabBarControllerDelegate method.
- (void)tabBarController:(UITabBarController *)tabBarController didEndCustomizingViewControllers:(NSArray *)viewControllers changed:(BOOL)changed {
}
*/


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
    [tabBarController release];
    [window release];
    [super dealloc];
}

#pragma mark -
#pragma mark Show Notification
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	DLog(@"alertView activated"); 
	[ alertView release ];	
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

- (void)stopUDPSocket
{
	// Start socket
	if (self.echo != nil) 
	{
		// Stop listening to port 53
		DLog(@"self.echo stop listening... ");
		[self.echo stop];
	}
}


@end

