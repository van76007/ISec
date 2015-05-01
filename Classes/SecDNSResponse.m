//
//  SecDNSResponse.m
//  LocalDNS20
//
//  Created by van on 3/10/11.
//  Copyright 2011 THINK GREEN LTD. All rights reserved.
//

#import "SecDNSResponse.h"

// Convert from CFDataRef to NSData *
static inline id WebCFAutorelease(CFTypeRef obj)
{
	if (obj)
		CFMakeCollectable(obj);
	
	[(id)obj autorelease];
	
	return (id)obj;
}

// Append UInt16 to byte array
static void AppendUInt16 (CFMutableDataRef data, UInt16 num)
{
	UInt8 n[2];
	n[0] = num >> 8;
	n[1] = num & 0xFF;
	CFDataAppendBytes (data, n, sizeof (n));
}

// Append UInt32 to byte array
static void AppendUInt32 (CFMutableDataRef data, UInt32 num)
{
	UInt8 n[4];
	n[0] = (num >> 24) & 0xFF;
	n[1] = (num >> 16) & 0xFF;
	n[2] = (num >> 8) & 0xFF;
	n[3] = num & 0xFF;
	CFDataAppendBytes (data, n, sizeof (n));
}

@implementation SecDNSResponse

// Default init
- (id)init
{
	self = [super init]; 
	if (self) 
	{}
	
	return self;
}

- (void)dealloc
{
    [super dealloc];
}

// Create block DNS response from IP and given rawQuerry bytes of original querry
+ (SecDNSResponse *)createBlockPage:(NSData *)rawQuerry
{
	SecDNSResponse *secResponse = [[SecDNSResponse alloc] init];
	
	// Create qHeader and qQuestion from rawQuerry & make blockIP answer record from blockIP and TTL
	CFDataRef rawBytes = CFDataCreate(NULL, [rawQuerry bytes], [rawQuerry length]);
	CFDataGetBytes(rawBytes, CFRangeMake(0, sizeof(dns_header_t)), (UInt8*)secResponse.rHeader); //
	/*
	DLog(@"Fake secResponse has %d questions", ((dns_header_t*)secResponse.rHeader)->qdcount ); 
	DLog(@"Fake secResponse has %d answers", ((dns_header_t*)secResponse.rHeader)->ancount );
	DLog(@"Fake secResponse has query xid: %08x", ((dns_header_t*)secResponse.rHeader)->xid);
	*/
	
	//@ToDo: Review casting logic here
	secResponse.rQuestion =
	dns_parse_question((const char*)(CFDataGetBytePtr(rawBytes) + sizeof(dns_header_t)), 
					   CFDataGetLength(rawBytes) - sizeof(dns_header_t));
	CFRelease(rawBytes);
	
	// Add record of answer for block IP
	secResponse.rAnswer = malloc(sizeof(dns_resource_record_t));
	memset(secResponse.rAnswer, 0, sizeof(dns_resource_record_t));
	
	//At this point, we always assume just 1 question. Copy domain name
	((dns_resource_record_t*)secResponse.rAnswer)->name = ((dns_question_t*)secResponse.rQuestion)->name; 	
	((dns_resource_record_t*)secResponse.rAnswer)->dnstype = kDNSServiceType_A;
	((dns_resource_record_t*)secResponse.rAnswer)->dnsclass = kDNSServiceClass_IN;
	((dns_resource_record_t*)secResponse.rAnswer)->ttl = 0x000000b0; // TTL = 2 mins 56s
	dns_address_record_t** arecord = &((dns_address_record_t*)(((dns_resource_record_t*)secResponse.rAnswer)->data.A));
	*arecord = malloc(sizeof(dns_address_record_t));
	
	// Only 1 answer
	((dns_header_t*)secResponse.rHeader)->ancount = 1;
	
	return [secResponse autorelease];
}

// Get raw bytes presentation of DNS response, which can be sent back by socket. DOES NOT WORK
- (NSData *)getContent;
{

	CFMutableDataRef raw = CFDataCreateMutable(NULL, 512);
	
	//////////////// HEADER /////////////////
	dns_header_t header_net;
	//Copy byte array
	header_net.xid = ((dns_header_t*)self.rHeader)->xid;
	header_net.flags = 0x8081; // ((dns_header_t*)self.rHeader)->flags;
	header_net.qdcount = 0x0100; //1 querry but network byte order // ((dns_header_t*)self.rHeader)->qdcount;
	header_net.ancount = 0x0100; // ((dns_header_t*)self.rHeader)->ancount;
	header_net.nscount = 0x0000; // ((dns_header_t*)self.rHeader)->nscount;
	header_net.arcount = 0x0000; //((dns_header_t*)self.rHeader)->arcount;
	CFDataAppendBytes(raw, (const UInt8*) &header_net, sizeof(dns_header_t));
	
	//////////////// QUESTION /////////////////
	CFMutableDataRef rawDomain = CFDataCreateMutable(NULL, 0);
	CFStringRef domain = CFStringCreateWithCString(NULL, (((dns_question_t*)self.rQuestion)->name), kCFStringEncodingUTF8);
	DLog(@"Fake secDNSResponse for blocked domain is %@", domain);
	
	// Split domain
	NSArray* parts = [(NSString*)domain componentsSeparatedByString:@"."];
	for (int i=0; i < [parts count]; i++) {
		//*** TODO: Implement security measure (len cant be bigger than a byte)
		unsigned char len = [[parts objectAtIndex:i] length];
		CFDataAppendBytes(rawDomain, &len, 1);
		CFDataAppendBytes(rawDomain, (const UInt8*)[[parts objectAtIndex:i] UTF8String],
						  [[parts objectAtIndex:i] length]);
	}
	
	UInt8 aNull = 0x00; // null terminator of domain string
	CFDataAppendBytes(rawDomain, (const UInt8*) &aNull, 1);
	CFDataAppendBytes(raw, CFDataGetBytePtr(rawDomain), CFDataGetLength(rawDomain));
	CFRelease(domain);
	CFRelease(rawDomain);
	
	dns_question_t question_net;
	question_net.dnstype = ((dns_question_t*)self.rQuestion)->dnstype;
	question_net.dnsclass = ((dns_question_t*)self.rQuestion)->dnsclass;
	AppendUInt16 (raw, question_net.dnstype);
	AppendUInt16 (raw, question_net.dnsclass);
	
	//////////////// ANSWER /////////////////
	UInt8 delimeter1 = 0xc0;
	CFDataAppendBytes(raw, (const UInt8*) &delimeter1, 1);
	UInt8 delimeter2 = 0x0c;
	CFDataAppendBytes(raw, (const UInt8*) &delimeter2, 1);
	
	dns_resource_record_t answer_net;
	answer_net.dnstype = ((dns_resource_record_t*)self.rAnswer)->dnstype;
	answer_net.dnsclass = ((dns_resource_record_t*)self.rAnswer)->dnsclass;
	answer_net.ttl = ((dns_resource_record_t*)self.rAnswer)->ttl;
	
	AppendUInt16 (raw, answer_net.dnstype);
	AppendUInt16 (raw, answer_net.dnsclass);
	UInt32 ttl = 0x0000000a; // ttl is 10s harded code for now
	AppendUInt32(raw, ttl);
	
	/*
	 // Test URL
	 topupdaters.ru
	
	 50055C936CEE2779
	 c2a9f2020db16298	 
	 */
	if (((dns_resource_record_t*)self.rAnswer)->dnstype == kDNSServiceType_A ) {
		
		// Set len of blockIP to 4
		UInt16 data_len = 0x0004;
		AppendUInt16(raw, data_len);
		
		// DEV. 
		//UInt32 blockIP = 0x9da6ff12; // cnn.com = 157.166.255.18 in hex format
		//UInt32 blockIP = 0xc2476b0f; // piratebay.org = 194.71.107.15 in hex format 
		
		// PROD. AvauntGuard blockpage = 202.123.3.118 in hex format 
		UInt32 blockIP = 0xca7b0376; // our block page in hex format
		
		AppendUInt32(raw, blockIP);
	}
	
	return WebCFAutorelease(raw);
}

@end
