//
//  WebViewController.h
//  iScreenDNS
//
//  Created by van on 6/9/11.
//  Copyright 2011 THINK GREEN LTD. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "iScreenDNSAppDelegate.h"

// Macro to turn ON/OFF debug log files in PROD/DEBUG
#ifdef DEBUG
#   define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#   define DLog(...)
#endif

@interface WebViewController : UIViewController<UIWebViewDelegate> {
	
	UIWebView* mWebView;
	
	// Toolbar items
	UIToolbar* mToolbar;
	UIBarButtonItem* mBack;
	UIBarButtonItem* mForward;
	UIBarButtonItem* mRefresh;
	UIBarButtonItem* mStop;
	UILabel* mPageTitle;
    UITextField* mAddressField;

	UIAlertView *alert;
	UIActivityIndicatorView *indicator;
}

@property (nonatomic, retain) IBOutlet UIWebView* webView;
@property (nonatomic, retain) IBOutlet UIToolbar* toolbar;
@property (nonatomic, retain) IBOutlet UIBarButtonItem* back;
@property (nonatomic, retain) IBOutlet UIBarButtonItem* forward;
@property (nonatomic, retain) IBOutlet UIBarButtonItem* refresh;
@property (nonatomic, retain) IBOutlet UIBarButtonItem* stop;
@property (nonatomic, retain) UILabel* pageTitle;
@property (nonatomic, retain) UITextField* addressField;

- (void)updateButtons;
- (void)loadAddress:(id)sender event:(UIEvent*)event;
- (void)updateTitle:(UIWebView*)aWebView;
- (void)updateAddress:(NSURLRequest*)request; // Update address bar if user follows URL
- (void)informError:(NSError*)error;
- (void)hideAlert;

@end