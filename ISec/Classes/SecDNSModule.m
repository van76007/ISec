//
//  SecDNSModule.m
//  LocalDNS20
//
//  Created by van on 3/8/11.
//  Copyright 2011 THINK GREEN LTD. All rights reserved.
//
#import "SecDNSModule.h"
#import <CommonCrypto/CommonDigest.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <unistd.h>
#include <fcntl.h>

// Convert from CFDataRef to NSData *
static inline id WebCFAutorelease(CFTypeRef obj)
{
	if (obj)
		CFMakeCollectable(obj);
	
	[(id)obj autorelease];
	
	return (id)obj;
}

// Returns a human readable string for the given data.
static NSString * DisplayStringFromData(NSData *data)
{
    NSMutableString *   result;
    NSUInteger          dataLength;
    NSUInteger          dataIndex;
    const uint8_t *     dataBytes;
	
    assert(data != nil);
    
    dataLength = [data length];
    dataBytes  = [data bytes];
	
    result = [NSMutableString stringWithCapacity:dataLength];
    assert(result != nil);
	
    [result appendString:@"\""];
    for (dataIndex = 0; dataIndex < dataLength; dataIndex++) {
        uint8_t     ch;
        
        ch = dataBytes[dataIndex];
        if (ch == 10) {
            [result appendString:@"\n"];
        } else if (ch == 13) {
            [result appendString:@"\r"];
        } else if (ch == '"') {
            [result appendString:@"\\\""];
        } else if (ch == '\\') {
            [result appendString:@"\\\\"];
        } else if ( (ch >= ' ') && (ch < 127) ) {
            [result appendFormat:@"%c", (int) ch];
        } else {
            [result appendFormat:@"\\x%02x", (unsigned int) ch];
        }
		//[result appendFormat:@"\\x%02x", (unsigned int) ch];
    }
    [result appendString:@"\""];
    
    return result;
}

static NSString * DisplayAddressForAddress(NSData * address)
{
    int         err;
    NSString *  result;
    char        hostStr[NI_MAXHOST];
    char        servStr[NI_MAXSERV];
    
    result = nil;
    
    if (address != nil) {
		
        // If it's a IPv4 address embedded in an IPv6 address, just bring it as an IPv4 
        // address.  Remember, this is about display, not functionality, and users don't 
        // want to see mapped addresses.
        
        if ([address length] >= sizeof(struct sockaddr_in6)) {
            const struct sockaddr_in6 * addr6Ptr;
            
            addr6Ptr = [address bytes];
            if (addr6Ptr->sin6_family == AF_INET6) {
                if ( IN6_IS_ADDR_V4MAPPED(&addr6Ptr->sin6_addr) || IN6_IS_ADDR_V4COMPAT(&addr6Ptr->sin6_addr) ) {
                    struct sockaddr_in  addr4;
                    
                    memset(&addr4, 0, sizeof(addr4));
                    addr4.sin_len         = sizeof(addr4);
                    addr4.sin_family      = AF_INET;
                    addr4.sin_port        = addr6Ptr->sin6_port;
                    addr4.sin_addr.s_addr = addr6Ptr->sin6_addr.__u6_addr.__u6_addr32[3];
                    address = [NSData dataWithBytes:&addr4 length:sizeof(addr4)];
                    assert(address != nil);
                }
            }
        }
        err = getnameinfo([address bytes], (socklen_t) [address length], hostStr, sizeof(hostStr), servStr, sizeof(servStr), NI_NUMERICHOST | NI_NUMERICSERV);
        if (err == 0) {
            result = [NSString stringWithFormat:@"%s:%s", hostStr, servStr];
            assert(result != nil);
        }
    }
	
    return result;
}

@implementation SecDNSModule
@synthesize main_sock, querryList;

- (id)init
{
    self = [super init];
    if (self != nil) {
		self.main_sock = nil;
		self.querryList = nil;
	}
    return self;
}

- (void)dealloc
{
    DLog(@"Deallocate SecDNSModule");
    [super dealloc];
}

// Build array of SecDNS querries
- (void)buildSecDnsQueries:(CFStringRef)aDomain withSuffix:(CFStringRef)aSuffix
{
	// Build NSMutableArray *querryList; from domain and suffix
	
	CFArrayRef domainParts = CFStringCreateArrayBySeparatingStrings(NULL, aDomain, (CFStringRef)@".");	
	CFMutableStringRef splitDomain = CFStringCreateMutable(NULL, 512);
	CFStringAppend(splitDomain, CFArrayGetValueAtIndex(domainParts, CFArrayGetCount(domainParts)-1));
	
	unsigned char d_md5[CC_MD5_DIGEST_LENGTH];
	int len = CFArrayGetCount(domainParts) - 1;
	self.querryList = [NSMutableArray arrayWithCapacity:len];
	
	for(int i = 0; i < len; i++) {
		CFStringInsert(splitDomain, 0, (CFStringRef)@".");
		CFStringInsert(splitDomain, 0, CFArrayGetValueAtIndex(domainParts, CFArrayGetCount(domainParts)-2-i));
		
		DLog(@"splitDomain: %@", splitDomain);
		CC_MD5([(NSString*)splitDomain UTF8String], [(NSString*)splitDomain length], d_md5);
		NSString* d_md5_hex_p1 = [NSString stringWithFormat:@"%02X%02X%02X%02X%02X%02X%02X%02X",
								  d_md5[0], d_md5[1], d_md5[2], d_md5[3],
								  d_md5[4], d_md5[5], d_md5[6], d_md5[7] ];
		NSString* d_md5_hex_p2 = [NSString stringWithFormat:@"%02X%02X%02X%02X%02X%02X%02X%02X",
								  d_md5[8], d_md5[9], d_md5[10], d_md5[11],
								  d_md5[12], d_md5[13], d_md5[14], d_md5[15] ];
		
		NSString* secdnsdomain = [NSString stringWithFormat:@"%s%s", [d_md5_hex_p1 UTF8String], [(NSString*)aSuffix UTF8String]];
		
		DLog(@"d_md5_hex_p1: %@", d_md5_hex_p1);
		DLog(@"d_md5_hex_p2: %@", d_md5_hex_p2);
		DLog(@"secdnsdomain: %@", secdnsdomain);
		
		SecDNSQuerry* secDNS_querry = (SecDNSQuerry *)[SecDNSQuerry createFromDomain:(CFStringRef)secdnsdomain 
																			  ofType:kDNSServiceType_TXT 
																		withCheckStr:(CFStringRef)d_md5_hex_p2];
		[self.querryList addObject:secDNS_querry];
	}
	
	CFRelease(splitDomain);
	CFRelease(domainParts);
}

// PROD: Querry SecDNS server
- (ResponseData *)forwardDNSQuerry:(NSData *)rawQuerry toServer:(CFDataRef)serverAddr andServer:(CFDataRef)aux_serverAddr
{
	// Start timer
	NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
	
	// Flag to indicate whether we should serve
	// the 'normal' response or the blocked one
	bool blocked = false;
	//NSData* response_data = NULL; // To be replaced by a ResponseData *answer
	ResponseData *answer = [[ResponseData alloc] init];
	
	NSTimeInterval elapsedTime = 0;
	NSTimeInterval endTime = 0;
	
	// Build the orignal query Data into an object for manipulation
	DNSQuerry *orig_querry = [DNSQuerry initWithBytes:rawQuerry];
	CFStringRef orig_domain = [orig_querry getDomain];
	int orignal_id = [orig_querry getID];
	
	// 1b. Build array of SecDNSQuerries from original querry.
	// Split the domain string
	CFStringRef secdns_suffix = CFSTR(".mobility.screendns.com");
	[self buildSecDnsQueries:orig_domain withSuffix:secdns_suffix];
	
	CFRelease(secdns_suffix);
	//CFRelease(orig_domain);
	
	int num_secquerry = [self.querryList count];
	int num_queries = 0;
	CFSocketError err;
	int native_sock;
	
	fd_set fds;
	FD_ZERO(&fds);
	
	//2. Send array of querries to default DNS server.
	// Open socket 
	@try 
	{
		self.main_sock = CFSocketCreate(NULL, PF_INET , SOCK_DGRAM, IPPROTO_UDP, 0, 0, NULL);
		native_sock = CFSocketGetNative(self.main_sock);
				
		// Send sec querries first
		for (int i = 0; i < num_secquerry; i++)
		{
			// Send SecDNS requests
			// Dont really have to forward hashed queries to aux
			CFDataRef raw = [(SecDNSQuerry *)[self.querryList objectAtIndex: i] getRaw];
			err = CFSocketSendData(self.main_sock, serverAddr, raw, 0.0);
			CFRelease(raw);
			
			if( err != kCFSocketSuccess)
				@throw [NSException exceptionWithName:NSLocalizedString(@"[%d].Could not send hash query to main socket %d", orignal_id) 
											   reason:NSLocalizedString(@"%@ ", err) userInfo:nil];
			else
				num_queries++;
		}
		
		// Send original querry
		err = CFSocketSendData(self.main_sock, serverAddr, (CFDataRef)rawQuerry, 0.0);
		if( err != kCFSocketSuccess)
			@throw [NSException exceptionWithName:NSLocalizedString(@"[%d]. Could not send original query %d to main socket %d", orignal_id) 
										   reason:NSLocalizedString(@"%@ ", err) userInfo:nil];
		else
			num_queries++;
		
		if(aux_serverAddr != NULL)
		{
			DLog(@"aux_serverAddr not NULL");
			
			// Send sec querries
			for (int i = 0; i < num_secquerry; i++)
			{
				// Send SecDNS requests
				// Dont really have to forward hashed queries to aux
				CFDataRef raw = [(SecDNSQuerry *)[self.querryList objectAtIndex: i] getRaw];			
				err = CFSocketSendData(self.main_sock, aux_serverAddr, raw, 0.0);
				CFRelease(raw);
				
				if( err != kCFSocketSuccess)
					@throw [NSException exceptionWithName:NSLocalizedString(@"[%d].Could not send hash query to aux socket %d", orignal_id) 
												   reason:NSLocalizedString(@"%@ ", err) userInfo:nil];
				else
					num_queries++;
			}
			
			// Send original querry
			err = CFSocketSendData(self.main_sock, aux_serverAddr, (CFDataRef)rawQuerry, 0.0);
			if( err != kCFSocketSuccess)
				@throw [NSException exceptionWithName:NSLocalizedString(@"[%d].Couldnt send original query to auxiliary socket %d", orignal_id) 
											   reason:NSLocalizedString(@"%@ ", err) userInfo:nil];
			else
				num_queries++;
		}
		
		// Monitor native sock
		FD_SET(native_sock, &fds);
	} 
	@catch (NSException* e) 
	{
		DLog(@"(SecDNSModule::forwardDNSQuerry) Exception %@ reason %@", [e name], [e reason]);
		return NULL;
	}		
	
	int ready = 0;
	int num_ans = 0; // max is NUM_QUERRIES;
	
	// Max of file descriptor
	int numfds = native_sock;
	
	DLog(@"num_secquerry is %d. Expect %d responses", num_secquerry, num_queries);
	while ((!blocked) && (elapsedTime < 2000) && (num_ans < num_queries))
	{
		struct timeval tv;
		tv.tv_sec = 2;
		tv.tv_usec = 0;
		
		// Call to select
		if ( (ready = select(numfds+1, &fds, NULL, NULL, &tv)) < 0 )
		{
			DLog(@"select error %d, ready is %d", errno, ready);
			// Calculate elapsed time
			endTime = [NSDate timeIntervalSinceReferenceDate];
			// Get the elapsed time in milliseconds
			elapsedTime = (endTime - startTime) * 1000;
			continue; // Back to while
		} else {
			DLog(@"select error %d, ready is %d", errno, ready);
		}
		
		int nobr = 0;
		char inbuff[512];
		
		if (FD_ISSET(native_sock, &fds)) {
			//nobr = recv(native_sock, inbuff, 512, 0);
			
			struct sockaddr_storage addr;
			socklen_t addrLen = sizeof(addr);
			nobr = recvfrom(native_sock, inbuff, sizeof(inbuff), 0, (struct sockaddr *) &addr, &addrLen);
			DLog(@"Main socket get datagram len %d", nobr);
			
			if (nobr > 0) {
				num_ans++;
				
				NSData * addrObj = [NSData dataWithBytes:&addr  length:addrLen  ];
				DLog(@"Receive number of bytes %d from address %@", nobr, DisplayAddressForAddress(addrObj));
				
				DNSResponse* response = (DNSResponse *)[DNSResponse createFromBytes:[NSData dataWithBytes:inbuff length:nobr]];
				
				// Browse list of querries to see if this is block response
				for(int j=0; j < [self.querryList count]; j++)
				{	
					CFStringRef recv_check_str = [response getTXT];
					
					// Our DNS server for blocking malicious sites
					// returns data in TXT only
					// So we check for blocked only when response is in TXT
					if (recv_check_str != NULL) 
					{
						SecDNSQuerry* querry_tmp = [self.querryList objectAtIndex:j];
						
						// Debug
						if([response getResponseType] == kDNSServiceType_TXT)
						{
							DLog(@"recv_check_str is %@", recv_check_str);
							DLog(@"recv_check_str len is %d", CFStringGetLength(recv_check_str));
							DLog(@"querry_tmp.check_str is %@", querry_tmp.check_str);
							DLog(@"Found range %d", CFStringFind(recv_check_str, querry_tmp.check_str, kCFCompareCaseInsensitive).location);
							
							if (CFStringGetLength(recv_check_str) == 17) {
								CFStringRef tag = CFStringCreateWithSubstring (kCFAllocatorDefault, recv_check_str,
																			   CFRangeMake(CFStringGetLength(recv_check_str) - 1, CFStringGetLength(recv_check_str)));
								DLog(@"Get Tag is %@__", tag); // Dangerous, must trim but CRASHED
								CFRelease(tag);												
							}
						}
						
						// Action
						blocked = ([response getResponseType] == kDNSServiceType_TXT) && (CFStringGetLength(recv_check_str) == 17)
								&& (CFStringFind(recv_check_str, querry_tmp.check_str, kCFCompareCaseInsensitive).location == 0 );
						
						// Check Tag
						int tag = 0;
						if (blocked) {
							CFStringRef WhiteList_tag = CFSTR("0");
							// WhiteList
							if (CFStringFindWithOptions(
								recv_check_str,
								WhiteList_tag,
								CFRangeMake(CFStringGetLength(recv_check_str) - 1, CFStringGetLength(recv_check_str)), 
								kCFCompareBackwards, 
								//&r // //CFRange r;
								NULL
								)) {
								DLog(@"Reset blocked to FALSE");
								blocked = FALSE;
								tag = 0;
							}
							
							CFStringRef Abusive_tag = CFSTR("1");
							if (CFStringFindWithOptions(
														recv_check_str,
														Abusive_tag,
														CFRangeMake(CFStringGetLength(recv_check_str) - 1, CFStringGetLength(recv_check_str)), 
														kCFCompareBackwards, 
														//&r // //CFRange r;
														NULL
														)) {
								DLog(@"Get tag Abusive");
								tag = 1;
							}
							
							CFStringRef DriveBy_tag = CFSTR("2");
							if (CFStringFindWithOptions(
														recv_check_str,
														DriveBy_tag,
														CFRangeMake(CFStringGetLength(recv_check_str) - 1, CFStringGetLength(recv_check_str)), 
														kCFCompareBackwards, 
														//&r // //CFRange r;
														NULL
														)) {
								DLog(@"Get tag DriveBy");
								tag = 2;
							}
							
							CFStringRef Backdoor_tag = CFSTR("3");
							if (CFStringFindWithOptions(
														recv_check_str,
														Backdoor_tag,
														CFRangeMake(CFStringGetLength(recv_check_str) - 1, CFStringGetLength(recv_check_str)), 
														kCFCompareBackwards, 
														//&r // //CFRange r;
														NULL
														)) {
								DLog(@"Get tag Backdoor");
								tag = 3;
							}
							
							CFStringRef Malware_tag = CFSTR("4");
							if (CFStringFindWithOptions(
														recv_check_str,
														Malware_tag,
														CFRangeMake(CFStringGetLength(recv_check_str) - 1, CFStringGetLength(recv_check_str)), 
														kCFCompareBackwards, 
														//&r // //CFRange r;
														NULL
														)) {
								DLog(@"Get tag Malware");
								tag = 4;
							}
							
							CFStringRef Trojan_tag = CFSTR("5");
							if (CFStringFindWithOptions(
														recv_check_str,
														Trojan_tag,
														CFRangeMake(CFStringGetLength(recv_check_str) - 1, CFStringGetLength(recv_check_str)), 
														kCFCompareBackwards, 
														//&r // //CFRange r;
														NULL
														)) {
								DLog(@"Get tag Trojan");
								tag = 5;
							}
							
							CFStringRef Typosquatting_tag = CFSTR("6");
							if (CFStringFindWithOptions(
														recv_check_str,
														Typosquatting_tag,
														CFRangeMake(CFStringGetLength(recv_check_str) - 1, CFStringGetLength(recv_check_str)), 
														kCFCompareBackwards, 
														//&r // //CFRange r;
														NULL
														)) {
								DLog(@"Get tag Typosquatting");
								tag = 6;
							}
							
							CFStringRef Unknown_tag = CFSTR("7");
							if (CFStringFindWithOptions(
														recv_check_str,
														Unknown_tag,
														CFRangeMake(CFStringGetLength(recv_check_str) - 1, CFStringGetLength(recv_check_str)), 
														kCFCompareBackwards, 
														//&r // //CFRange r;
														NULL
														)) {
								DLog(@"Get tag Unknown");
								tag = 7;
							}
							
							CFStringRef Phishing_tag = CFSTR("8");
							if (CFStringFindWithOptions(
														recv_check_str,
														Phishing_tag,
														CFRangeMake(CFStringGetLength(recv_check_str) - 1, CFStringGetLength(recv_check_str)), 
														kCFCompareBackwards, 
														//&r // //CFRange r;
														NULL
														)) {
								DLog(@"Get tag Phishing");
								tag = 8;
							}
						}
						
						CFRelease(recv_check_str);
						
						if (blocked) {
							DLog(@"Querry[%d].Received block response.\n", orignal_id);
														
							// Create & return SecDNS response object
							// SecDNSResponse is basically an object representation of the raw byte array
							// SecDNSResponse simply enables us to work more easily with the array
							SecDNSResponse *client_response = [SecDNSResponse createBlockPage:rawQuerry];
							
							// Set our response content to point to the block page
							answer.response_data = [client_response getContent];
							answer.blocked = TRUE;
							answer.tag = tag;
							answer.domain = (NSString *)orig_domain;
							DLog(@"Out of for loop querries");
							break; // Out of for(int j=0; j < [self.querryList count]; j++)						
						}
					}
				}
				
				// If not yet block, try to match ID of response and original querry
				if (!blocked)
				{
					if([orig_querry getID] == [response getID]) {
						DLog(@"Main. Matching ID of response and orig querry is TRUE. Domain is %@", [orig_querry getDomain]);
						// Get the raw socket data this will be forwarded to the socket
						answer.response_data = [response getRaw];
					}
				}
			} // end if(nobr > 0)
		}
		
		// Calculate elapsed time
		endTime = [NSDate timeIntervalSinceReferenceDate];
		// Get the elapsed time in milliseconds
		elapsedTime = (endTime - startTime) * 1000;
		// Send it to the Console
		DLog(@"After reading from socket: %f", elapsedTime);	
	}
	
	DLog(@"Receive number of answer is %d", num_ans);
	CFRelease(orig_domain);
	
	// Handling exception
	if ([answer response_data] == NULL) {
		DLog(@"Response data is NULL. Forwarding NULL ans for domain %@", [orig_querry getDomain]);
	}
	else {
		if(blocked)
		{
			DLog(@"Response data is not NULL. Forwarding blocked response for domain %@", [orig_querry getDomain]);
		}
		else
		{
			DLog(@"Response data is not NULL. Forwarding clear response for domain %@", [orig_querry getDomain]);
		}
	}
	
	return answer;
}

@end
