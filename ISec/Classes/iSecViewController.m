//
//  iSecViewController.m
//  iSec
//
//  Created by van on 3/17/11.
//  Copyright 2011 THINK GREEN LTD. All rights reserved.
//

#import "iSecViewController.h"

@implementation iSecViewController

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}

- (void)dealloc {	
    [super dealloc];
}

- (IBAction)btnSafariPressed:(id)sender
{
    NSURL *url = [NSURL URLWithString:@"http://www.apple.com"];
	
	if (![[UIApplication sharedApplication] openURL:url])
	{
		DLog(@"%@%@",@"Failed to open url:",[url description]);
	}
	else {
		DLog(@"%@%@",@"OK to open url:",[url description]);
	}	
}

- (IBAction)btnMailPressed:(id)sender
{
	NSURL *url = [NSURL URLWithString:@"mailto:dvv@csis.dk"];
	
	if (![[UIApplication sharedApplication] openURL:url])
	{
		DLog(@"%@%@",@"Failed to open url:",[url description]);
	}
	else {
		DLog(@"%@%@",@"OK to open url:",[url description]);
	}
}

- (IBAction)btnMapsPressed:(id)sender
{
	NSURL *url = [NSURL URLWithString:@"http://maps.google.com"];
	
	if (![[UIApplication sharedApplication] openURL:url])
	{
		DLog(@"%@%@",@"Failed to open url:",[url description]);
	}
	else {
		DLog(@"%@%@",@"OK to open url:",[url description]);
	}
}

- (IBAction)btnYouTubePressed:(id)sender
{
    NSURL *url = [NSURL URLWithString:@"http://www.youtube.com"];
	
	if (![[UIApplication sharedApplication] openURL:url])
	{
		DLog(@"%@%@",@"Failed to open url:",[url description]);
	}
	else {
		DLog(@"%@%@",@"OK to open url:",[url description]);
	}
}

- (IBAction)btnITunesPressed:(id)sender
{
	NSURL *url = [NSURL URLWithString:@"http://phobos.apple.com/WebObjects/MZStore.woa/wa/viewAlbum?i=156093464&id=156093462&s=143441"];
	
	if (![[UIApplication sharedApplication] openURL:url])
	{
		DLog(@"%@%@",@"Failed to open url:",[url description]);
	}
	else {
		DLog(@"%@%@",@"OK to open url:",[url description]);
	}
}

- (IBAction)btnAppStorePressed:(id)sender
{
	NSURL *url = [NSURL URLWithString:@"http://itunes.apple.com/WebObjects/MZStore.woa/wa/viewSoftware?id=294409923&mt=8"];
	
	if (![[UIApplication sharedApplication] openURL:url])
	{
		DLog(@"%@%@",@"Failed to open url:",[url description]);
	}
	else {
		DLog(@"%@%@",@"OK to open url:",[url description]);
	}
}

@end
