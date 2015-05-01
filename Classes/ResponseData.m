//
//  ResponseData.m
//  iScreenDNS
//
//  Created by Dan on 7/5/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ResponseData.h"


@implementation ResponseData

@synthesize response_data = _response_data;
@synthesize blocked = _blocked;
@synthesize domain = _domain;
@synthesize tag = _tag;

- (id)init
{
	self = [super init];
	if (self) {
		_response_data = NULL;
		_blocked = FALSE;
		_domain = NULL;
		_tag = -1;
	}
	return self;
}

- (void)dealloc
{
    if (_response_data) {
		[_response_data release];
	}
	if (_domain) {
		[_domain release];
	}
	
    [super dealloc];
}

@end
