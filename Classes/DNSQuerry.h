//
//  DNSQuerry.h
//  iSec

//  Normal DNS querry sent by process e.g. Safari

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

@interface DNSQuerry : NSObject {

@protected
	struct dns_header_t *qHeader;
	struct dns_question_t *qQuestion;
}

@property(nonatomic, readwrite) struct dns_header_t *qHeader;
@property(nonatomic, readwrite) struct dns_question_t *qQuestion;

// Default init
- (id)init;

// Utility method: Init new DNSQuerry object given its raw content.
+ (DNSQuerry *)initWithBytes:(NSData *)data;

// Get ID of querry
- (int)getID;

// Get Domain from querry
- (CFStringRef)getDomain;

// Get raw byte representation of DNS querry
- (CFDataRef)getRaw;

@end
