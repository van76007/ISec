//
//  DNSQuerry.m
//  LocalDNS20
//
//  Created by van on 3/8/11.
//  Copyright 2011 THINK GREEN LTD. All rights reserved.
//

#import "DNSQuerry.h"

@implementation DNSQuerry
/*
 @synthesize You use the @synthesize keyword to tell the compiler that 
 it should synthesize the setter and/or getter methods for the property 
 if you do not supply them within the @implementation block.
 */
@synthesize qHeader, qQuestion;

// Default init
- (id)init
{
	self = [super init]; 
	if (self) 
	{
		self.qHeader = malloc(sizeof(dns_header_t));
		self.qQuestion = malloc(sizeof(dns_question_t));
	}
	
	return self;
}

- (void)dealloc
{
    free(self.qHeader);
	if (self.qQuestion != NULL)
		dns_free_question((dns_question_t *)self.qQuestion);
	
    [super dealloc];
}

// Utility method: Init new DNSQuerry object given its raw content
// @ToDo: Review casting pointer
+ (DNSQuerry *)initWithBytes:(NSData *)data
{
	DNSQuerry *query = [[DNSQuerry alloc] init];
	
	CFDataRef rawBytes = CFDataCreate(NULL, [data bytes], [data length]);
	CFDataGetBytes(rawBytes, CFRangeMake(0, sizeof(dns_header_t)), (UInt8*)query.qHeader);
	
	// Need to convert value from network byte order to host byte order for internal storage
	((dns_header_t*)query.qHeader)->xid = ntohs(((dns_header_t*)query.qHeader)->xid);
	((dns_header_t*)query.qHeader)->flags = ntohs(((dns_header_t*)query.qHeader)->flags);
	((dns_header_t*)query.qHeader)->qdcount = ntohs(((dns_header_t*)query.qHeader)->qdcount);
	((dns_header_t*)query.qHeader)->ancount = ntohs(((dns_header_t*)query.qHeader)->ancount);
	((dns_header_t*)query.qHeader)->nscount = ntohs(((dns_header_t*)query.qHeader)->nscount);
	((dns_header_t*)query.qHeader)->arcount = ntohs(((dns_header_t*)query.qHeader)->arcount);
	
	DLog(@"Query xid: %08x", ((dns_header_t*)query.qHeader)->xid);
	//@ToDo: Implement handling of multiple questions 
	if ( ((dns_header_t*)query.qHeader)->qdcount > 1) {
		DLog(@"Warning: Dns query has more than 1 question, only checking the first!" ); 
	}
	
	//@ToDo: Review casting logic here
	query.qQuestion =
		dns_parse_question((const char*)(CFDataGetBytePtr(rawBytes) + sizeof(dns_header_t)), 
						   CFDataGetLength(rawBytes) - sizeof(dns_header_t));
	CFRelease(rawBytes);
	
	return [query autorelease];
}

// Get raw byte representation of DNS querry
// @ToDo: Review casting pointers
- (CFDataRef)getRaw
{
	CFMutableDataRef raw = CFDataCreateMutable(NULL, 512);
	
	//////////////// HEADER /////////////////
	dns_header_t header_net;
	header_net.xid = htons(((dns_header_t*)self.qHeader)->xid);
	header_net.flags = htons(((dns_header_t*)self.qHeader)->flags);
	header_net.qdcount = htons(((dns_header_t*)self.qHeader)->qdcount);
	header_net.ancount = htons(((dns_header_t*)self.qHeader)->ancount);
	header_net.nscount = htons(((dns_header_t*)self.qHeader)->nscount);
	header_net.arcount = htons(((dns_header_t*)self.qHeader)->arcount);
	CFDataAppendBytes(raw, (const UInt8*) &header_net, sizeof(dns_header_t));
	
	//////////////// QUESTION /////////////////
	CFMutableDataRef rawDomain = CFDataCreateMutable(NULL, 0);
	
	CFStringRef domain = CFStringCreateWithCString(NULL, (((dns_question_t*)self.qQuestion)->name), kCFStringEncodingUTF8);
	
	NSArray* parts = [(NSString*)domain componentsSeparatedByString:@"."];
	for (int i=0; i < [parts count]; i++) {
		unsigned char len = [[parts objectAtIndex:i] length]; //*** TODO: Implement security measure (len cant be bigger than a byte)
		CFDataAppendBytes(rawDomain, &len, 1);
		CFDataAppendBytes(rawDomain, (const void*)[[parts objectAtIndex:i] UTF8String],
						  [[parts objectAtIndex:i] length]);
	}
	unsigned char aNull = 0;
	CFDataAppendBytes(rawDomain, &aNull, 1);
	
	CFDataAppendBytes(raw, CFDataGetBytePtr(rawDomain), CFDataGetLength(rawDomain));
	CFRelease(rawDomain);
	CFRelease(domain);
	
	dns_question_t question_net;
	question_net.dnstype = htons(((dns_question_t*)self.qQuestion)->dnstype);
	question_net.dnsclass = htons(((dns_question_t*)self.qQuestion)->dnsclass);
	CFDataAppendBytes(raw, (const UInt8*) &( question_net.dnstype ), 4);
	
	return raw;
}

// Get ID of querry
- (int)getID
{
	int xID = (int)((dns_header_t*)self.qHeader)->xid;
	DLog(@"Get querry xID %d", xID);
	return  xID;
}

// Get Domain from querry
- (CFStringRef)getDomain
{
	CFStringRef domain = CFStringCreateWithCString(NULL, 
												   ((dns_question_t*)self.qQuestion)->name, 
												   kCFStringEncodingUTF8);
	return domain;
}

/*
- (NSString *)getDomain
{
	return [NSString stringWithUTF8String:((dns_question_t*)self.qQuestion)->name];
}
*/
@end
