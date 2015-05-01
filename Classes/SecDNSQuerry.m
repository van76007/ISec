//
//  SecDNSQuerry.m
//  LocalDNS20
//
//  Created by van on 3/10/11.
//  Copyright 2011 THINK GREEN LTD. All rights reserved.
//

#import "SecDNSQuerry.h"

@implementation SecDNSQuerry
@synthesize check_str;

// Default init
- (id)init
{
	self = [super init]; 
	if (self) 
	{
		self.check_str = nil;
	}
	
	return self;
}

- (void)dealloc
{	
	if (self.check_str != nil) {
		CFRelease(self.check_str);
	}
	
    [super dealloc];
}

// Init new SecDNSQuerry object given the Domain and Type
+ (SecDNSQuerry *)createFromDomain:(CFStringRef)aDomain ofType:(int)aType withCheckStr:(CFStringRef)aStr
{
	SecDNSQuerry *secQuerry = [[SecDNSQuerry alloc] init];
	
	((dns_header_t*)secQuerry.qHeader)->xid = 200+(arc4random() % 65000);
	((dns_header_t*)secQuerry.qHeader)->flags = 0x0100;
	((dns_header_t*)secQuerry.qHeader)->qdcount = 0;
	((dns_header_t*)secQuerry.qHeader)->ancount = 0;
	((dns_header_t*)secQuerry.qHeader)->nscount = 0;
	((dns_header_t*)secQuerry.qHeader)->arcount = 0;
	((dns_header_t*)secQuerry.qHeader)->qdcount = 1;
	
	CFStringRef in_domain = (CFStringRef)CFRetain(aDomain);
	int len = CFStringGetLength(in_domain);
	((dns_question_t*)secQuerry.qQuestion)->name = malloc(len + 1);
	CFStringGetCString(in_domain, ((dns_question_t*)secQuerry.qQuestion)->name, len + 1, kCFStringEncodingUTF8);
	((dns_question_t*)secQuerry.qQuestion)->dnstype = aType;
	((dns_question_t*)secQuerry.qQuestion)->dnsclass = kDNSServiceClass_IN;
	secQuerry.check_str = (CFStringRef)CFRetain(aStr);
	
	return [secQuerry autorelease];
}

@end
