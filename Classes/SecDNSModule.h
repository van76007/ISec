//
//  SecDNSModule.h
//  LocalDNS20
//  This class will provide DNS response/ DNS block page given raw DNS querry 
//  Created by van on 3/8/11.
//  Copyright 2011 THINK GREEN LTD. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Foundation/NSObject.h>

#import "DNSQuerry.h"
#import "DNSResponse.h"
#import "SecDNSQuerry.h"
#import "SecDNSResponse.h"
#import "ResponseData.h"

// Macro to turn ON/OFF debug log files in PROD/DEBUG
#ifdef DEBUG
#   define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#   define DLog(...)
#endif

// Public interface
@interface SecDNSModule : NSObject {
	
@private
	
	// List of sec DNS querry will be created from raw data of original DNS querry
	NSMutableArray *querryList;
	
	// List of DNS responses got back from default DNS server after sending List of customized DNS querry
	//NSMutableArray *responseList;
	
	// UDP socket to communicate with main DNS server
	CFSocketRef main_sock;

}

// Property
@property(nonatomic, assign) CFSocketRef main_sock;
@property(nonatomic, assign, readwrite) NSMutableArray *querryList;

// Public
- (ResponseData *)forwardDNSQuerry:(NSData *)rawQuerry toServer:(CFDataRef)serverAddr andServer:(CFDataRef)aux_serverAddr;

// Private
- (void)buildSecDnsQueries:(CFStringRef)aDomain withSuffix:(CFStringRef)aSuffix;

@end