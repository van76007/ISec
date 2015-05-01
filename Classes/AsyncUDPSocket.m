//
//  AsyncUDPSocket.m
//  UDPServer
//
//  Created by VIKASH APIAH on 2/17/11.
//  Copyright 2011 THINK GREEN LTD. All rights reserved.
//

#import "AsyncUDPSocket.h"

// For BSD socket
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <unistd.h>
#include <sys/types.h>
#include <fcntl.h>

// Returns a dotted decimal string for the specified address (a (struct sockaddr) 
// within the address NSData).
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

// Returns a human readable string for the given binary data
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

static void SocketReadCallback(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *pData, void *pInfo)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	AsyncUDPSocket *udpEcho = [[(AsyncUDPSocket *)pInfo retain] autorelease];
	[udpEcho doBytesAvailable];
	[pool drain];
}

@implementation AsyncUDPSocket

@synthesize defaultDNSAddr, auxDNSAddr, dbLoggedDomain;

- (id)init
{
    self = [super init];
    if (self != nil) {
		self.defaultDNSAddr = NULL;
		self.dbLoggedDomain = NULL;
	}
    return self;
}

- (void)dealloc
{
    DLog(@"Deallocate AsyncUDPSocket");
	[self stop];
    [super dealloc];
}

- (BOOL)stop
{	
	// Hande errors
	if (sock != -1)
		DLog(@"Close socket return error %d", close(sock));
	
	if (self->_cfSocket != NULL) {
		DLog(@"CFSocketInvalidate");
        CFSocketInvalidate(self->_cfSocket);
        CFRelease(self->_cfSocket);
        self->_cfSocket = NULL;
    }
	
	// MOVED
	/*
	// Close data base of logged domains
	if (self.dbLoggedDomain != NULL) {
		sqlite3_close(self.dbLoggedDomain);
		self.dbLoggedDomain = NULL;
	}
	*/
	
	return YES;
}

// Querry 1st Default DNS server
- (BOOL)getDefaultDNS
{
	// Get DNS IPs by resolv.h
	res_init();
	
	// Check if all retrieved IPs are 0.0.0.0
	int allZero = 0;
	for (int i=0;i<MAXNS;i++)
	{       
		DLog(@"Get DNS: %s", inet_ntoa(_res.nsaddr_list[i].sin_addr));
		if (strcmp(inet_ntoa(_res.nsaddr_list[i].sin_addr), "0.0.0.0") == 0)
			allZero++;
	}
	
	// If all retrieved DNS IP are Zero, no need to reset DNS settings
	if (allZero == MAXNS) {
		DLog(@"All zero: %d", allZero);
		return NO;
	}
	
	// Prepare right DNS configuration setting: @"127.0.0.1, 192.168.230.14, 192.168.230.15"
	NSMutableString *buf = [NSMutableString stringWithString:@"127.0.0.1"];
	
	for (int i = 0; i < MAXNS -1 ; i++) {
		if ((strcmp(inet_ntoa(_res.nsaddr_list[i].sin_addr), "127.0.0.1") != 0) 
			&& (strcmp(inet_ntoa(_res.nsaddr_list[i].sin_addr), "0.0.0.0") != 0))
		{
			[buf appendString:@", "];
			[buf appendString:[NSString stringWithUTF8String:inet_ntoa(_res.nsaddr_list[i].sin_addr)]];
		}
	}
	
	if ((strcmp(inet_ntoa(_res.nsaddr_list[MAXNS -1].sin_addr), "127.0.0.1") != 0)
		&& (strcmp(inet_ntoa(_res.nsaddr_list[MAXNS-1].sin_addr), "0.0.0.0") != 0))
	{
		[buf appendString:@", "];
		[buf appendString:[NSString stringWithUTF8String:inet_ntoa(_res.nsaddr_list[MAXNS-1].sin_addr)]];
	}
	
	DLog(@"Reset system clipboard to %@", buf);
	UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
	pasteboard.string = buf;
	
	// Reset the values
	self.defaultDNSAddr = NULL;
	self.auxDNSAddr = NULL;
	unsigned long defaultDNSIP;
	
	// Must check that element 0 is 127.0.0.1 and the next element is the IP of default_DNS_server
	for (int i = 0; i < MAXNS; i++) {
		DLog(@"Found IP at index %d is %s", i, inet_ntoa(_res.nsaddr_list[i].sin_addr));		
		int found = strcmp(inet_ntoa(_res.nsaddr_list[i].sin_addr), "127.0.0.1");
		
		// First IP is 127.0.0.1
		if ((found != 0) && (i==0)) {
			DLog(@"Configuration NOT OK");
			return NO;
		}
		
		if (found != 0) {
			DLog(@"Found IP of DHCP DNS server is %s", inet_ntoa(_res.nsaddr_list[i].sin_addr));
			
			// Assign IP of addr
			if (strcmp(inet_ntoa(_res.nsaddr_list[i].sin_addr), "0.0.0.0") != 0) {
				
				struct sockaddr_in addr;
				memset(&addr, 0, sizeof(addr));
				addr.sin_len = sizeof(addr);
				addr.sin_family = AF_INET;
				addr.sin_port = htons(53);
				inet_aton( inet_ntoa(_res.nsaddr_list[i].sin_addr), (void*)&addr.sin_addr.s_addr);			
				memset(&(addr.sin_zero), 0, sizeof(addr.sin_zero));
				
				if (self.defaultDNSAddr == NULL) {
					self.defaultDNSAddr = CFDataCreate(NULL, (UInt8 *)&addr, sizeof(addr));
					defaultDNSIP = addr.sin_addr.s_addr;
					DLog(@"Assign IP of primary DNS server to %s", inet_ntoa(_res.nsaddr_list[i].sin_addr));
				} else {
					// Prevent duplicate DNS servers
					if (defaultDNSIP != addr.sin_addr.s_addr) {
						DLog(@"Assigning address of aux DNS server...");
						self.auxDNSAddr = CFDataCreate(NULL, (UInt8 *)&addr, sizeof(addr));
						DLog(@"Assign IP of aux DNS server to %s", inet_ntoa(_res.nsaddr_list[i].sin_addr));
					}
				}
			}
			
			if ( (self.defaultDNSAddr != NULL) && (self.auxDNSAddr != NULL))
				break;
		}
	}
	
	if (self.defaultDNSAddr != NULL) {
		DLog(@"Configuration is OK");
		return YES;
	} else {
		DLog(@"Configuration is NOT OK");
		return NO;
	}
	
	return YES;
}

- (BOOL)start
{
	
	int err = 0;
	const CFSocketContext   context = { 0, self, NULL, NULL, NULL };
	CFRunLoopSourceRef      rls;
	
	// Create BSD socket
	sock = socket(AF_INET, SOCK_DGRAM, 0);
	
	// Create address
	struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;
    addr.sin_port = htons(53);
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
	memset(&(addr.sin_zero), 0, sizeof(addr.sin_zero));
	
	//Bind socket to address
	err = bind(sock, (struct sockaddr *)&addr, addr.sin_len);
	if (err == 0)
	{
		int flags = fcntl(sock, F_GETFL);
		err = fcntl(sock, F_SETFL, flags | O_NONBLOCK);
		
		int set=1;
		setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, (void *)&set, sizeof(set));
		
		int reuseOn = 1; 
		setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuseOn, sizeof(reuseOn));
		
		DLog(@"Bind socket to address OK");
	} else {
		DLog(@"Bind socket to address failed with error %d", err);
	    err = close(sock);
	}
	
	// Create CFSocketRef
	if (err == 0)
	{
		self->_cfSocket = CFSocketCreateWithNative(NULL, sock, kCFSocketReadCallBack, (CFSocketCallBack)&SocketReadCallback, &context);
		
		// Close the native socket when invalidating self->_cfSocket
		CFSocketSetSocketFlags(self->_cfSocket, kCFSocketCloseOnInvalidate);
				
		rls = CFSocketCreateRunLoopSource(NULL, self->_cfSocket, 0);
		assert(rls != NULL);
		
		CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopDefaultMode);
		CFRelease(rls);
		
		/* Debug to see listening port */
		NSData *addr_debug = [(NSData *)CFSocketCopyAddress(self->_cfSocket) autorelease];
		struct sockaddr_in addr4;
		memcpy(&addr4, [addr_debug bytes], [addr_debug length]);
		uint16_t port_debug = ntohs(addr4.sin_port);
		
		DLog(@"Socket listening on port %d\n", port_debug);
	}
	
	DLog(@"Native socket is %d", sock);
	
	// Open SQLite3 database for logging
	DBManager *dbManager = [DBManager sharedInstance];
	[dbManager openDB];
	
	// TEST BROWSE
	int count = [dbManager browseDB];
	
	// TEST EXTRACT
	if (count > 0) {
		[dbManager extractDomainsByTag:1];
	}
	
	return (err == 0);
}

- (void)doBytesAvailable
{	
	// Read/Write using recvfrm() and writeto()
	int                     r_sock;
	struct sockaddr_storage addr;
	socklen_t               addrLen;
	uint8_t                 buffer[512];
	ssize_t                 bytesRead;
		
	r_sock = CFSocketGetNative(self->_cfSocket);
	assert(r_sock >= 0);
		
	addrLen = sizeof(addr);
	bytesRead = recvfrom(r_sock, buffer, sizeof(buffer), 0, (struct sockaddr *) &addr, &addrLen);
	
	// Write back to the same socket if byteRead > 0
	if (bytesRead < 0) {
		
		DLog(@"doBytesAvailable. Error in receiving bytes: %d", errno);
		switch (errno) {
			case EBADF:
				DLog(@"The argument socket is an invalid descriptor");
				break;
			case ECONNRESET:
				DLog(@"The connection is closed by the peer during a receive attempt on a socket");
				break;
			case EFAULT:
				DLog(@"The receive buffer pointer(s) point outside the process's address space");
				break;
			case EINTR:
				DLog(@"The receive was interrupted by delivery of a signal before any data were available");
				break;
			case EINVAL:
				DLog(@"MSG_OOB is set, but no out-of-band data is available");
				break;
			case ENOBUFS:
				DLog(@"An attempt to allocate a memory buffer fails");
				break;
			case ENOTCONN:
				DLog(@"The socket is associated with a connection-oriented protocol and has not been connected");
				break;
			case ENOTSOCK:
				DLog(@"The argument socket does not refer to a socket.");
				break;
			case EOPNOTSUPP:
				DLog(@"The type and/or protocol of socket do not support the option(s) specified in flags.");
				break;
			case ETIMEDOUT:
				DLog(@"The connection timed out.");
				break;
			default:
				DLog(@"Unknown");
				break;
		}
	} else if (bytesRead == 0) {
		NSData * addrObj = [NSData dataWithBytes:&addr  length:addrLen  ];
		DLog(@"doBytesAvailable: UDP socket receive 0 bytes from source %@", DisplayAddressForAddress(addrObj));
	} else {
		
		NSData *    dataObj;
		NSData *    addrObj;
		
		dataObj = [NSData dataWithBytes:buffer length:bytesRead];
		addrObj = [NSData dataWithBytes:&addr  length:addrLen  ];
				
		DLog(@"doBytesAvailable: UDP socket receive datagram from source %@ is %@", DisplayAddressForAddress(addrObj), DisplayStringFromData(dataObj));
		
		// PROD: This will solve the blocking issue when doing concurrent DNS querry: High prior queue using 2, Default queue using 0
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [self sendData:dataObj toAddress:addrObj];
        });
		
		// DEV: Dont dispatch the processing request code in seperate thread
		//[self sendData:dataObj toAddress:addrObj];
	}
		
	// Tell the cfSocket ready to accept new data again
	CFSocketEnableCallBacks(self->_cfSocket, kCFSocketReadCallBack | kCFSocketWriteCallBack);
}

- (void)sendData:(NSData *)data toAddress:(NSData *)addr
{
	
    int                     w_sock;
    ssize_t                 bytesWritten;
    const struct sockaddr * addrPtr;
    socklen_t               addrLen;
	
    assert( (addr == nil) || ([addr length] <= sizeof(struct sockaddr_storage)) );
	
    w_sock = CFSocketGetNative(self->_cfSocket);
    assert(w_sock >= 0);
	
    addrPtr = [addr bytes];
	addrLen = (socklen_t) [addr length];
	
	// DEV: Echo back data received
	//bytesWritten = sendto(sock, [data bytes], [data length], 0, addrPtr, addrLen);
	
	// PROD: Ask SecDNS module
	if (self.defaultDNSAddr != NULL) {
		SecDNSModule *secDNSModule = [[SecDNSModule alloc] init];
		
		// Benchmark
		// Start timer
		NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];		
		
		// Execute DNS Request
		if (dbLoggedDomain == NULL) {
			DLog(@"dbLoggedDomain is NULL");
		}
		
		ResponseData *answer = [secDNSModule forwardDNSQuerry:data toServer:self.defaultDNSAddr andServer:self.auxDNSAddr];
		
		// Stop timer
		NSTimeInterval endTime = [NSDate timeIntervalSinceReferenceDate];
		
		// Get the elapsed time in milliseconds
		NSTimeInterval elapsedTime = (endTime - startTime) * 1000;
		
		// Send it to the Console
		DLog(@"Time taken to perform query in ms is: %f", elapsedTime);		
		
		if ([answer response_data] != NULL) {
			bytesWritten = sendto(w_sock, [[answer response_data]  bytes], [[answer response_data] length], 0, addrPtr, addrLen);
			
			if (bytesWritten < 0) {
				DLog(@"bytesWritten < 0");
			} else  if (bytesWritten == 0) {
				DLog(@"bytesWritten == 0");
			} else {
				DLog(@"Server echo back Number of bytes: %d to source %@", bytesWritten, DisplayAddressForAddress(addr));
			}
			
			// Log to database if this is blocked domain
			if ([answer blocked] == TRUE) {
				DBManager *dbManager = [DBManager sharedInstance];
				[dbManager insertItem:answer];
			}
		}
		
		//[answer release]; // MEM LEAK?
		[secDNSModule release];
	}
}

@end
