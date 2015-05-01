//
//  DNSResponse.m
//  iSec
//
//  Created by van on 3/8/11.
//  Copyright 2011 THINK GREEN LTD. All rights reserved.
//

#import "DNSResponse.h"

@implementation DNSResponse
@synthesize rHeader, rQuestion, rAnswer, reply_data, content;

// Default init
- (id)init
{
	self = [super init]; 
	if (self) 
	{
		// This needs for SecDNSResponse indeed. May be moved back to SecDNSResponse code to create response from rawQuerry
		self.rHeader = malloc(sizeof(dns_header_t));
		self.rQuestion = malloc(sizeof(dns_question_t));
		
		self.content = nil;
	}
	
	return self;
}

- (void)dealloc
{	
	if (self.content != nil) {
		[self.content release];
	}
	
	free(self.rHeader);
	free(self.rQuestion);
	
    [super dealloc];
}

// Init new DNSResponse object given its raw content
+ (DNSResponse *)createFromBytes:(NSData *)data
{
	DNSResponse *response = [[DNSResponse alloc] init];
	
	response.reply_data = (struct dns_reply_t*)dns_parse_packet((const char*)[data bytes], [data length]);
	response.rHeader = (struct dns_header_t*)( ((dns_reply_t*) response.reply_data)->header );
	response.rQuestion = (struct dns_question_t*) *( ((dns_reply_t*)response.reply_data)->question );
	response.rAnswer = (struct dns_resource_record_t*) *( ((dns_reply_t*)response.reply_data)->answer );
	response.content = [data retain];
	
	return [response autorelease];
}

// Get ID of response
- (int)getID
{
	int xID = (int)((dns_header_t*)self.rHeader)->xid;
	return  xID;
}

// Get type of response: A or TXT
- (int)getResponseType
{
	if (self.rAnswer == NULL)
		return 0;
	else
		return (int)((dns_resource_record_t*)(self.rAnswer ))->dnstype;
}

// Get check_string of response as TXT record
// Ref: http://www.ros.org/doc/api/libphidgets21/html/dns__sd_8h.html
- (CFStringRef)getTXT
{
	if ([self getResponseType] != kDNSServiceType_TXT)
	{
		return nil;
	}
		
	char* txt_str = (*((dns_TXT_record_t*)(((dns_resource_record_t*)self.rAnswer)->data.TXT))->strings);
	return CFStringCreateWithCString(NULL, txt_str, kCFStringEncodingUTF8);
}

// Get raw bytes presentation of DNS response, which can be sent back by socket
- (NSData *)getRaw
{
	return self.content; // May be CRASH
}

@end
