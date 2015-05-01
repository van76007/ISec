//
//  AsyncUDPSocket.h
//  Local UDPServer listening on port 53 of localhost
//
//  Created by van on 2/17/11.
//  Copyright 2011 THINK GREEN LTD. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CFNetwork/CFNetwork.h>
//#import <sqlite3.h>

#import "DBManager.h"
#import "SecDNSModule.h"
#include <resolv.h>

// Macro to turn ON/OFF debug log files in PROD/DEBUG
#ifdef DEBUG
#   define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#   define DLog(...)
#endif

#define kDBFilename	@"loggedDomain.sqlite3"

@interface AsyncUDPSocket : NSObject {

@private
	
	// Native BSD socket
	int sock;
	
	// Wrapper of BSD socket listening on port 53
    CFSocketRef      _cfSocket;
	
	// Address of the 1st default DNS
	CFDataRef defaultDNSAddr;
	
	// Address of the 2nd default DNS
	CFDataRef auxDNSAddr;
	
	// SQL Lite3 database of blocked domain
	//sqlite3 * dbLoggedDomain;
}

// Public
- (BOOL)getDefaultDNS;
- (BOOL)start;
- (BOOL)stop;

// Private
- (void)sendData:(NSData *)data toAddress:(NSData *)addr;
- (void)doBytesAvailable;

// Property
@property(nonatomic, assign) CFDataRef defaultDNSAddr;
@property(nonatomic, assign) CFDataRef auxDNSAddr;
@property(nonatomic, assign) sqlite3 * dbLoggedDomain; 

@end