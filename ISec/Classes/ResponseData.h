//
//  ResponseData.h
//  iScreenDNS
//
//  Created by Dan on 7/5/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ResponseData : NSObject {
	NSData *_response_data;
	BOOL _blocked;
	NSString *_domain;
	int _tag;
}

@property(nonatomic, assign, readwrite) NSData *response_data;
@property(nonatomic, readwrite) BOOL blocked;
@property(nonatomic, assign, readwrite) NSString *domain;
@property(nonatomic, readwrite) int tag;

// Default init
- (id)init;

@end
