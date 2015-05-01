//
//  DNSResponse.h
//  iSec

//  Normal DNS response received from DNS server

//  Created by van on 3/8/11.
//  Copyright 2011 THINK GREEN LTD. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Foundation/NSObject.h>
#import <dns_util.h>
#import <dns_sd.h>

// Macro to turn ON/OFF debug log files in PROD/DEBUG
#ifdef DEBUG
#   define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#   define DLog(...)
#endif

@interface DNSResponse : NSObject {

@protected
	struct dns_header_t* rHeader;
	struct dns_question_t* rQuestion;
	struct dns_resource_record_t* rAnswer; // pointer or pointer to pointer
	
	// Result of dns_parse_packet
	struct dns_reply_t* reply_data;
	
	// Raw byte content
	NSData *content;
}

@property(nonatomic, readwrite, assign) struct dns_header_t* rHeader;
@property(nonatomic, readwrite, assign) struct dns_question_t* rQuestion;
@property(nonatomic, readwrite, assign) struct dns_resource_record_t* rAnswer;
@property(nonatomic, readwrite, assign) struct dns_reply_t* reply_data;
@property(nonatomic, readwrite, assign) NSData *content;

// Default init
- (id)init;

// Utility method: Init new DNSResponse object given its raw content
+ (DNSResponse *)createFromBytes:(NSData *)data;

// Get ID of response
- (int)getID;

// Get type of response
- (int)getResponseType;

// Get check_string of response as TXT record
- (CFStringRef)getTXT;

// Get raw bytes presentation of DNS response, which can be sent back by socket
- (NSData *)getRaw;

@end
