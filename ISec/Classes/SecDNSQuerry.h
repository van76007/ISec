//
//  SecDNSQuerry.h
//  iSec
//  SecDNS version of DNS querry from daemon e.g. Safari. Inherited from DNSQuerry class
//  Created by van on 3/10/11.
//  Copyright 2011 THINK GREEN LTD. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Foundation/NSObject.h>
#import "DNSQuerry.h"

// Macro to turn ON/OFF debug log files in PROD/DEBUG
#ifdef DEBUG
#   define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#   define DLog(...)
#endif

@interface SecDNSQuerry : DNSQuerry {
	CFStringRef check_str;
}
@property(nonatomic, readwrite) CFStringRef check_str;

// Default init
- (id)init;

// Init new SecDNSQuerry object given the Domain and Type
+ (SecDNSQuerry *)createFromDomain:(CFStringRef)aDomain ofType:(int)aType withCheckStr:(CFStringRef)aStr;

@end
