//
//  SecDNSResponse.h
//  iSec
//  SecDNS response to serve the block page. Inherited from DNSResponse class
//  Created by van on 3/10/11.
//  Copyright 2011 THINK GREEN LTD. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Foundation/NSObject.h>
#import "DNSResponse.h"

// Macro to turn ON/OFF debug log files in PROD/DEBUG
#ifdef DEBUG
#   define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#   define DLog(...)
#endif

@interface SecDNSResponse : DNSResponse {

}

// Default init
- (id)init;

// Add answer record to serve the block IP page
+ (SecDNSResponse *)createBlockPage:(NSData *)rawQuerry;

// Get raw bytes presentation of DNS response, which can be sent back by socket
- (NSData *)getContent;

@end
