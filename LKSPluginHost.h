//
//  LKSPluginHost.h
//  Sparkle
//
//  Created by Scott Little on 2/7/13.
//
//

#import "SUHost.h"

@interface LKSPluginHost : SUHost {
	NSString		*_sandboxedPrefsPath;
	NSFileManager	*_manager;
	NSDictionary	*_suFilteredDefaults;
	NSDate			*_lastDefaultsLoadTime;
	BOOL			_skipPreferenceSaves;
}

@property	(assign)	BOOL	skipPreferenceSaves;

@end
