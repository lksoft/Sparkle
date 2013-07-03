//
//  LKSPluginUpdater.m
//  Sparkle
//
//  Created by Scott Little on 3/7/13.
//
//

#import "LKSPluginUpdater.h"
#import "LKSPluginHost.h"

#import "SUProbingUpdateDriver.h"
#import "SULog.h"


@interface SUUpdater (Private_Copy)
- (id)initForBundle:(NSBundle *)bundle;
- (void)startUpdateCycle;
- (void)checkForUpdatesWithDriver:(SUUpdateDriver *)updateDriver;
- (BOOL)automaticallyDownloadsUpdates;
- (void)scheduleNextUpdateCheck;
- (void)registerAsObserver;
- (void)unregisterAsObserver;
- (void)updateDriverDidFinish:(NSNotification *)note;
- (NSURL *)parameterizedFeedURL;

-(void)	notifyWillShowModalAlert;
-(void)	notifyDidShowModalAlert;

@property	SUHost			*myHost;
@property	SUUpdateDriver	*myDriver;
@property	NSTimer			*myCheckTimer;

@end


@implementation LKSPluginUpdater

@synthesize skipPreferenceSaves = _skipPreferenceSaves;

- (void)checkForUpdateInformation {
	if ([self updateInProgress]) { return; }
	if (self.myCheckTimer) {
		[self.myCheckTimer invalidate];
		self.myCheckTimer = nil;
	}		// UK 2009-03-16 Timer is non-repeating, may have invalidated itself, so we had to retain it.
	
	SUClearLog();
	SULog( @"===== %@ =====", [[NSFileManager defaultManager] displayNameAtPath:[self.myHost bundlePath]] );
	
	if ([self.myHost isKindOfClass:[LKSPluginHost class]]) {
		((LKSPluginHost *)self.myHost).skipPreferenceSaves = self.skipPreferenceSaves;
	}
	self.myDriver = [[[SUProbingUpdateDriver alloc] initWithUpdater:self] autorelease];
	
	NSURL	*theFeedURL = [self parameterizedFeedURL];
	if (theFeedURL) {	// Use a NIL URL to cancel quietly.
		[self.myDriver checkForUpdatesAtURL:theFeedURL host:self.myHost];
	}
	else {
		[self.myDriver abortUpdate];
	}
}

- (void)startUpdateCycle {
	
}

#pragma mark - Accessors

- (SUHost *)myHost {
	return [self valueForKey:@"host"];
}

- (void)setMyHost:(SUHost *)host {
	[self setValue:host forKey:@"host"];
}

- (SUUpdateDriver *)myDriver {
	return [self valueForKey:@"driver"];
}

- (void)setMyDriver:(SUUpdateDriver *)driver {
	[self setValue:driver forKey:@"driver"];
}

- (NSTimer *)myCheckTimer {
	return [self valueForKey:@"checkTimer"];
}

- (void)setMyCheckTimer:(NSTimer *)checkTimer {
	[self setValue:checkTimer forKey:@"checkTimer"];
}


@end
