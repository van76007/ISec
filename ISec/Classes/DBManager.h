//  To synchronize access to database. Singleton pattern
//
//  DBManager.h
//  iScreenDNS
//
//  Created by Dan on 7/7/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>
#import "ResponseData.h"
#import "BlockedVisit.h"

// Macro to turn ON/OFF debug log files in PROD/DEBUG
#ifdef DEBUG
#   define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#   define DLog(...)
#endif

#define kDBFilename	@"loggedDomain.sqlite3"

@interface DBManager : NSObject {
	sqlite3 * dbLoggedDomain;
}

@property(nonatomic, assign) sqlite3 * dbLoggedDomain;

+ (id)sharedInstance; // Implement Singleton pattern
- (BOOL)openDB;
- (int)browseDB; // Browse data base for list of items
- (BOOL)insertItem:(ResponseData *)answer; // Log a blocked domain
- (NSMutableArray *)extractDomainsByTag:(NSInteger)tag; // Extract list of blocked domains by category
- (BOOL)closeDB;

@end
