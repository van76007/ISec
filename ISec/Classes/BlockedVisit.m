//
//  BlockedVisit.m
//  iScreenDNS
//
//  Created by Dan on 7/7/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "BlockedVisit.h"


@implementation BlockedVisit

@synthesize domain, timestamp;

-(id)initWithDomain:(NSString *)domain andTimestamp:(NSString *)timestamp {
	self.domain = domain;
	self.timestamp = timestamp;
}

- (void)dealloc {
	if (self.domain) {
		[self.domain release];
	}
	
	if (self.timestamp) {
		[self.timestamp release];
	}
	
	[super dealloc];
}

@end
