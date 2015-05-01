//
//  DBManager.m
//  iScreenDNS
//
//  Created by Dan on 7/7/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "DBManager.h"


@implementation DBManager

static DBManager *sharedInstance = nil;

// Get the shared instance and create it if necessary.
+ (DBManager*)sharedInstance {
    if (sharedInstance == nil) {
        sharedInstance = [[super allocWithZone:NULL] init];
    }
	
    return sharedInstance;
}

// We don't want to allocate a new instance, so return the current one.
+ (id)allocWithZone:(NSZone*)zone {
    return [[self sharedInstance] retain];
}

// Equally, we don't want to generate multiple copies of the singleton.
- (id)copyWithZone:(NSZone *)zone {
    return self;
}

// Once again - do nothing, as we don't have a retain counter for this object.
- (id)retain {
    return self;
}

// Replace the retain counter so we can never release this object.
- (NSUInteger)retainCount {
    return NSUIntegerMax;
}

// This function is empty, as we don't want to let the user release this object.
- (void)release {
	
}

//Do nothing, other than return the shared instance - as this is expected from autorelease.
- (id)autorelease {
    return self;
}

@synthesize dbLoggedDomain;

// @ToDo: Check the free diskspace before creating new
/*
 -(unsigned)getFreeDiskspacePrivate {
 NSDictionary *atDict = [[NSFileManager defaultManager] attributesOfFileSystemForPath:@"/" error:NULL];
 unsigned freeSpace = [[atDict objectForKey:NSFileSystemFreeSize] unsignedIntValue];
 NSLog(@"%s - Free Diskspace: %u bytes - %u MiB", __PRETTY_FUNCTION__, freeSpace, (freeSpace/1024)/1024);
 
 return freeSpace;
 }
 */

- (BOOL)openDB {
	
	// Open SQLite3 database for logging
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES); 
	NSString *documentsDirectory = [paths objectAtIndex:0];
	NSString *dbFilePath = [documentsDirectory stringByAppendingPathComponent:kDBFilename];
	DLog(@"About to open Database at path: %@", dbFilePath);
	
	if (sqlite3_open([dbFilePath UTF8String], &dbLoggedDomain) != SQLITE_OK) {
		sqlite3_close(dbLoggedDomain);
		DLog(@"Failed to open Database at path: %@", dbFilePath);
		return FALSE;
	}
	// Create table of blocked domains to be logged
	char *errorMsg; // Note that the continuation char on next line is not part of string...
	const char *open_stmt = "CREATE TABLE IF NOT EXISTS BLOCKEDDOMAINS(id INTEGER PRIMARY KEY AUTOINCREMENT, domain TEXT, category INTEGER, timestamp TEXT)";
	
	int ret = sqlite3_exec(dbLoggedDomain, open_stmt, NULL, NULL, &errorMsg); 
	if (ret != SQLITE_OK) { 
		sqlite3_close(dbLoggedDomain); 
		DLog(@"Error creating log block domain table: %s", errorMsg);
		return FALSE;
	} else {
		DLog("Create table OK. ret is %d", ret);
		return TRUE;
	}
}

// TEST
- (int)browseDB {
	
	int count = 0;
	NSString *query = @"SELECT id, domain, category, timestamp FROM BLOCKEDDOMAINS ORDER BY id"; 
	sqlite3_stmt *statement;
	int ret = sqlite3_prepare_v2(dbLoggedDomain, [query UTF8String], -1, &statement, nil);
	if ( ret == SQLITE_OK) {
		DLog(@"Querry logged domains database OK. ret is %d", ret);
		while (sqlite3_step(statement) == SQLITE_ROW) {
			
			count++;
			int rowNum = sqlite3_column_int(statement, 0);
			char *domain = (char *)sqlite3_column_text(statement, 1); 
			NSString *domainValue = [[NSString alloc] initWithUTF8String:domain];
			DLog(@"Row [%d] domainValue is %@", rowNum, domainValue);
			[domainValue release];
			//
			int categoryValue = sqlite3_column_int(statement, 2); 
			DLog(@"Row [%d] categoryValue is %d", rowNum, categoryValue);
			//
			char *timestamp = (char *)sqlite3_column_text(statement, 3); 
			NSString *timestampValue = [[NSString alloc] initWithUTF8String:timestamp];
			DLog(@"Row [%d] timestampValue is %@", rowNum, timestampValue);
			[timestampValue release];
		} 
		sqlite3_finalize(statement);
	} else
		DLog(@"Querry logged domains database Failed. %d", ret);
	
	return count;
}

- (BOOL)insertItem:(ResponseData *)answer {
	
	int ret;
	// Get the current date
	NSDate *date = [NSDate date];
	NSDateFormatter *dateFormat = [[NSDateFormatter alloc]init];
	[dateFormat setDateFormat:@"HH:mm:ss zzz"];
	NSString *dateString = [dateFormat stringFromDate:date];
	
	NSString *insertSQL = [NSString stringWithFormat: 
						   @"INSERT INTO BLOCKEDDOMAINS (domain, category, timestamp) VALUES (\"%@\", %d, \"%@\")", 
						   [answer domain], [answer tag], dateString];
	
	DLog(@"About to insert block domain into database: domain %@ tag %d time %@", [answer domain], [answer tag], dateString);
	const char *insert_stmt = [insertSQL UTF8String];
	sqlite3_stmt    *statement;
	sqlite3_prepare_v2(dbLoggedDomain, insert_stmt, -1, &statement, NULL);
	ret = sqlite3_step(statement);
	// free up memory
	[dateFormat release];
	
	if (ret == SQLITE_DONE)
	{
		DLog(@"Insert OK. ret is %d", ret);
		return TRUE;
	} else {
		DLog(@"Insert Failed. ret is %d", ret);
		return FALSE;
	}
}

- (NSMutableArray *)extractDomainsByTag:(NSInteger)tag {
	
	NSString *query = [NSString stringWithFormat:
					   @"SELECT id, domain, category, timestamp FROM BLOCKEDDOMAINS WHERE category=\"%d\" ORDER BY id", tag]; 
	sqlite3_stmt *statement;
	int ret = sqlite3_prepare_v2(dbLoggedDomain, [query UTF8String], -1, &statement, nil);
	if ( ret == SQLITE_OK) {
		DLog(@"Extract items from logged domains database OK. ret is %d", ret);
		
		NSMutableArray *result = [[NSMutableArray alloc] init];
		
		while (sqlite3_step(statement) == SQLITE_ROW) {
			
			// Add object
			int rowNum = sqlite3_column_int(statement, 0);
			char *domain = (char *)sqlite3_column_text(statement, 1); 
			NSString *domainValue = [[NSString alloc] initWithUTF8String:domain];
			DLog(@"Row [%d] domainValue is %@", rowNum, domainValue);

			char *timestamp = (char *)sqlite3_column_text(statement, 3); 
			NSString *timestampValue = [[NSString alloc] initWithUTF8String:timestamp];
			DLog(@"Row [%d] timestampValue is %@", rowNum, timestampValue);
			
			BlockedVisit *visit = [[BlockedVisit alloc] initWithDomain:domainValue andTimestamp:timestampValue];
			[result addObject:visit];
			
			// CRASH
			/*
			[domainValue release];
			[timestampValue release];
			[visit release];
			 */
		} 
		sqlite3_finalize(statement);
		return result;
	} else {
		DLog(@"Extract items from logged domains database Failed. ret is %d", ret);
		return NULL;
	}
}

- (BOOL)closeDB {
	
	int ret;
	// Close data base of logged domains
	if (self.dbLoggedDomain != NULL)
		ret = sqlite3_close(self.dbLoggedDomain);
	if (ret == SQLITE_OK) {
		return TRUE;
	} else {
		return FALSE;
	}
}

@end
