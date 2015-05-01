//
//  BlockedVisit.h
//  iScreenDNS
//
//  Created by Dan on 7/7/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BlockedVisit : NSObject {
	NSString *domain;
	NSString *timestamp;
}

@property(nonatomic, assign, readwrite) NSString *domain;
@property(nonatomic, assign, readwrite) NSString *timestamp;

-(id)initWithDomain:(NSString *)domain andTimestamp:(NSString *)timestamp;

@end
