    //
//  WebViewController.m
//  iScreenDNS
//
//  Created by van on 6/9/11.
//  Copyright 2011 THINK GREEN LTD. All rights reserved.
//

#import "WebViewController.h"

static const CGFloat kNavBarHeight = 52.0f;
static const CGFloat kLabelHeight = 14.0f;
static const CGFloat kMargin = 10.0f;
static const CGFloat kSpacer = 2.0f;
static const CGFloat kLabelFontSize = 12.0f;
static const CGFloat kAddressHeight = 26.0f;

@implementation WebViewController

@synthesize webView = mWebView;
@synthesize toolbar = mToolbar;
@synthesize back = mBack;
@synthesize forward = mForward;
@synthesize refresh = mRefresh;
@synthesize stop = mStop;
@synthesize pageTitle = mPageTitle;
@synthesize addressField = mAddressField;

// The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization.
		alert = nil;
    }
    return self;
}


/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
}
*/


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
	self.webView.delegate = self;
    self.webView.scalesPageToFit = YES;
	
	// Creates a UINavigationBar
	CGRect navBarFrame = self.view.bounds;
    navBarFrame.size.height = kNavBarHeight;
    UINavigationBar *navBar = [[UINavigationBar alloc] initWithFrame:navBarFrame];
    navBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	
	// Add the title label to this navigation bar
	CGRect labelFrame = CGRectMake(kMargin, kSpacer,
								   navBar.bounds.size.width - 2*kMargin, kLabelHeight);
	UILabel *label = [[UILabel alloc] initWithFrame:labelFrame];
	label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	label.backgroundColor = [UIColor clearColor];
	label.font = [UIFont systemFontOfSize:12];
	label.textAlignment = UITextAlignmentCenter;
	[navBar addSubview:label];
	self.pageTitle = label;
	[label release];
	
	// Creating the text field for address bar
	CGRect addressFrame = CGRectMake(kMargin, kSpacer*2.0 + kLabelHeight,
									 labelFrame.size.width, kAddressHeight);
	UITextField *address = [[UITextField alloc] initWithFrame:addressFrame];
	address.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	address.borderStyle = UITextBorderStyleRoundedRect;
	address.font = [UIFont systemFontOfSize:17];
	// Twist keyboard for typing URL
	address.keyboardType = UIKeyboardTypeURL;
	[address setReturnKeyType:UIReturnKeyGo];
	address.autocapitalizationType = UITextAutocapitalizationTypeNone;
	address.autocorrectionType = UITextAutocorrectionTypeNo;
	address.clearButtonMode = UITextFieldViewModeWhileEditing;
	
	// End twist
	[address addTarget:self
			 action:@selector(loadAddress:event:)
			 forControlEvents:UIControlEventEditingDidEndOnExit];
	
	[navBar addSubview:address];
	self.addressField = address;
	[address release];
	
	// Add the navigation bar to the view controllers view
	[self.view addSubview:navBar];
	[navBar release];
	
	// Adjust the frame of the web view to ensure that it is not partially covered by the navigation bar.
	CGRect webViewFrame = self.webView.frame;
	webViewFrame.origin.y = navBarFrame.origin.y + navBarFrame.size.height;
	webViewFrame.size.height = self.toolbar.frame.origin.y - webViewFrame.origin.y;
	self.webView.frame = webViewFrame;
	
	// 
	[self updateButtons];
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations.
    //return (interfaceOrientation == UIInterfaceOrientationPortrait);
	return YES;
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}

- (void)viewDidUnload {
	
	self.webView = nil;
    self.toolbar = nil;
    self.back = nil;
    self.forward = nil;
    self.refresh = nil;
    self.stop = nil;
	self.pageTitle = nil;
    self.addressField = nil;
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (void)dealloc {
	
    [mWebView release];
    [mToolbar release];
    [mBack release];
    [mForward release];
    [mRefresh release];
    [mStop release];
	[mPageTitle release];
    [mAddressField release];
	
	[alert dismissWithClickedButtonIndex:0 animated:YES];
    [alert release];
    [super dealloc];
}

// MARK: -
// MARK: UIWebViewDelegate protocol
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    [self updateAddress:request];
	return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [self hideAlert];
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    [self updateButtons];
}
- (void)webViewDidFinishLoad:(UIWebView *)webView
{
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [self updateButtons];
    [self updateTitle:webView];
	NSURLRequest* request = [webView request];
    [self updateAddress:request];
	
	// Improving zoom feature
	NSString *path = [[NSBundle mainBundle] pathForResource:@"IncreaseZoomFactor" ofType:@"txt"];
	DLog(@"Path to js code %@", path);
	NSString *jsCode = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
	DLog(@"Read js code %@", jsCode);
	
	[webView stringByEvaluatingJavaScriptFromString:jsCode];
	[webView stringByEvaluatingJavaScriptFromString:@"increaseMaxZoomFactor()"];	
}
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [self updateButtons];
	[self informError:error];
}
- (void)updateButtons
{
    self.forward.enabled = self.webView.canGoForward;
    self.back.enabled = self.webView.canGoBack;
    self.stop.enabled = self.webView.loading;
}

- (void)hideAlert 
{
    if (alert) {
		DLog(@"Alert is not null");
		[alert dismissWithClickedButtonIndex:0 animated:YES];
		
		//[alert release]; // CRASH due to BAD ACCESS
		alert = nil;
		DLog(@"End release Alert is not null");
	}
}

- (void)loadAddress:(id)sender event:(UIEvent *)event
{	
	iScreenDNSAppDelegate *appDelegate = (iScreenDNSAppDelegate *)[[UIApplication sharedApplication] delegate];
	if ([appDelegate toggleDNSSettings]) {
		
		DLog(@"Toggling DNSSettings from YES to NO...");
		appDelegate.toggleDNSSettings = NO;
		
		if (alert)
			return;
		
		alert = [[[UIAlertView alloc] initWithTitle:@"Initializing AvauntGuard\nPlease Wait..." 
										   message:nil delegate:self 
								 cancelButtonTitle:nil otherButtonTitles: nil] autorelease];
		[alert show];
		
		indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
		// Adjust the indicator so it is up a few pixels from the bottom of the alert
		indicator.center = CGPointMake(alert.bounds.size.width / 2, alert.bounds.size.height - 50);
		[indicator startAnimating];
		[alert addSubview:indicator];
		[indicator release];
		
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			// Wait for 55s
			[NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow:55]];
			
			NSString* urlString = self.addressField.text;
			NSURL* url = [NSURL URLWithString:urlString];
			if(!url.scheme)
			{
				NSString* modifiedURLString = [NSString stringWithFormat:@"http://%@", urlString];
				url = [NSURL URLWithString:modifiedURLString];
			}
			NSURLRequest* request = [NSURLRequest requestWithURL:url];
			
			DLog(@"Loading address ...%@", urlString);
			[self.webView loadRequest:request];
		});
		
	} else {
		// Normal case
		NSString* urlString = self.addressField.text;
		NSURL* url = [NSURL URLWithString:urlString];
		if(!url.scheme)
		{
			NSString* modifiedURLString = [NSString stringWithFormat:@"http://%@", urlString];
			url = [NSURL URLWithString:modifiedURLString];
		}
		NSURLRequest* request = [NSURLRequest requestWithURL:url];
		
		DLog(@"Loading address ...%@", urlString);
		[self.webView loadRequest:request];
	}
}
- (void)updateTitle:(UIWebView*)aWebView
{
    NSString* pageTitle = [aWebView stringByEvaluatingJavaScriptFromString:@"document.title"];
    self.pageTitle.text = pageTitle;
}
- (void)updateAddress:(NSURLRequest*)request
{
    NSURL* url = [request mainDocumentURL];
    NSString* absoluteString = [url absoluteString];
    self.addressField.text = absoluteString;
}
- (void)informError:(NSError *)error
{
    // Ignore error code -999
	if (error.code == NSURLErrorCancelled){
		NSString* localizedDescription = [error localizedDescription];
		DLog(@"Error open URL %@ with error %@", [NSURL URLWithString:self.addressField.text], localizedDescription);
	} else {
		NSString* localizedDescription = [error localizedDescription];
		DLog(@"Error open URL %@ with error %@", [NSURL URLWithString:self.addressField.text], localizedDescription);
		
		UIAlertView* alertView = [[UIAlertView alloc]
								  initWithTitle:@"Error"
								  message:localizedDescription delegate:nil
								  cancelButtonTitle:@"OK"
								  otherButtonTitles:nil];
		[alertView show];
		[alertView release];
	}
}

@end
