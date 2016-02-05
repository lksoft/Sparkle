//
//  LKSPluginHost.m
//  Sparkle
//
//  Created by Scott Little on 2/7/13.
//
//

#import "LKSPluginHost.h"

#define KEY_LIST_FOR_NUMBER		@"SUHasLaunchedBefore SUEnableAutomaticChecks SUScheduledCheckInterval SUSendProfileInfo SUAutomaticallyUpdate SUEnableSystemProfiling SUCheckAtStartup SUExpectsDSASignature SUAllowsAutomaticUpdates SUShowReleaseNotes SUPromptUserOnFirstLaunch SUKeepDownloadOnFailedInstall"
#define KEY_LIST_IS_INTEGER		@"SUScheduledCheckInterval"
#define KEY_LIST_FOR_STRING		@"SUFeedURL SUPublicDSAKeyFile SUFixedHTMLDisplaySize SUPublicDSAKey SUSkippedVersion"
#define KEY_LIST_FOR_DATE		@"SULastCheckTime SULastProfileSubmissionDate"

#define DEFAULT_RELOAD_TIMEOUT	60

static	NSDateFormatter	*dateFormatter_LKS = nil;

@interface LKSPluginHost ()

@property	(strong)	NSString		*sandboxedPrefsPath;
@property	(strong)	NSFileManager	*manager;
@property	(strong)	NSDictionary	*suFilteredDefaults;
@property	(strong)	NSDate			*lastDefaultsLoadTime;

@end

@implementation LKSPluginHost

@synthesize sandboxedPrefsPath = _sandboxedPrefsPath;
@synthesize manager = _manager;
@synthesize suFilteredDefaults =_suFilteredDefaults;
@synthesize lastDefaultsLoadTime = _lastDefaultsLoadTime;
@synthesize skipPreferenceSaves = _skipPreferenceSaves;

- (id)initWithBundle:(NSBundle *)aBundle {
	self = [super initWithBundle:aBundle];
	if (self) {
		NSRange		pathRange = [[aBundle bundlePath] rangeOfString:@"/Library/Mail/Bundles"];
		NSString	*bundleExt = [[aBundle bundlePath] pathExtension];
		if ((pathRange.location != NSNotFound) && [bundleExt isEqualToString:@"mailbundle"]) {
			NSString	*libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
			NSString	*plistName = [[aBundle bundleIdentifier] stringByAppendingPathExtension:@"plist"];
			self.sandboxedPrefsPath = [[libraryPath stringByAppendingPathComponent:@"Containers/com.apple.mail/Data/Library/Preferences"] stringByAppendingPathComponent:plistName];
			
			self.manager = [[[NSFileManager alloc] init] autorelease];
			self.suFilteredDefaults = [NSDictionary dictionary];
			self.lastDefaultsLoadTime = [NSDate dateWithTimeIntervalSince1970:1];
			
		}
	}
	return self;
}

-(void)dealloc {
	self.sandboxedPrefsPath = nil;
	self.manager = nil;
	self.suFilteredDefaults = nil;
	self.lastDefaultsLoadTime = nil;
	[super dealloc];
}

- (NSDictionary *)sparkleDefaultValues {
	if ([self.manager fileExistsAtPath:self.sandboxedPrefsPath]) {
		if ([[NSDate date] timeIntervalSince1970] > ([self.lastDefaultsLoadTime timeIntervalSince1970] + DEFAULT_RELOAD_TIMEOUT)) {
			NSMutableDictionary	__block	*newDict = [NSMutableDictionary dictionary];
			NSDictionary	*fullContents = [NSDictionary dictionaryWithContentsOfFile:self.sandboxedPrefsPath];
			[fullContents keysOfEntriesPassingTest:^BOOL(id key, id obj, BOOL *stop) {
				
				if ([key hasPrefix:@"SU"]) {
					[newDict setObject:obj forKey:key];
					return YES;
				}
				else {
					return NO;
				}
			}];
			
			self.suFilteredDefaults = [NSDictionary dictionaryWithDictionary:newDict];
		}
	}
	return self.suFilteredDefaults;
}

- (id)readDefaultValueForKey:(NSString *)defaultKey {
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:self.sandboxedPrefsPath]) {
		
		NSDictionary	*suValues = [self sparkleDefaultValues];
		if (suValues) {
			return [suValues objectForKey:defaultKey];
		}

	}
	else {
		return [super objectForUserDefaultsKey:defaultKey];
	}
	
	return nil;
}

- (BOOL)writeDefaultValue:(id)value forKey:(NSString *)defaultKey {
	
	
	//	If the prefs file and it's parent folder don't exist, then use the super, which will probably write in the wrong place, but what can I do?
	if (![self.manager fileExistsAtPath:self.sandboxedPrefsPath]) {
		if (![self.manager fileExistsAtPath:[self.sandboxedPrefsPath stringByDeletingLastPathComponent]]) {
			[super setObject:value forUserDefaultsKey:defaultKey];
			return YES;
		}
	}
	
	//	Otherwise let defaults create the file

	NSString	*valueType = @"-bool";
	NSString	*valueString = nil;
	
	if ([value isKindOfClass:[NSNumber class]]) {
		if ([KEY_LIST_FOR_NUMBER rangeOfString:defaultKey].location != NSNotFound) {
			if ([KEY_LIST_IS_INTEGER rangeOfString:defaultKey].location != NSNotFound) {
				valueType = @"-int";
				valueString = [(NSNumber *)value stringValue];
			}
			else {
				valueString = [value boolValue]?@"YES":@"NO";
			}
		}
	}
	else if ([value isKindOfClass:[NSString class]]) {
		if ([KEY_LIST_FOR_STRING rangeOfString:defaultKey].location != NSNotFound) {
			valueType = @"-string";
			valueString = value;
		}
	}
	else if ([value isKindOfClass:[NSDate class]]) {
		if ([KEY_LIST_FOR_DATE rangeOfString:defaultKey].location != NSNotFound) {
			valueType = @"-date";
			valueString = [[[self class] formatter] stringFromDate:value];
		}
	}
	
	if (valueString == nil) {
		NSLog(@"Error trying to write a default value for key '%@' – not valid value extracted from %@", defaultKey, value);
		return NO;
	}
	
	NSTask *writeDefaultTask = [[[NSTask alloc] init] autorelease];
	[writeDefaultTask setLaunchPath:@"/usr/bin/defaults"];
	[writeDefaultTask setArguments:@[@"write", self.sandboxedPrefsPath, defaultKey, valueType, valueString]];
	
	[writeDefaultTask launch];
	[writeDefaultTask waitUntilExit];
	
	if ([writeDefaultTask terminationStatus] == 0) {
		//	Send a distributed notice to give the plugin a chance to reload defaults if necessary
		self.lastDefaultsLoadTime = [NSDate dateWithTimeIntervalSince1970:1];
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"LKSSUPluginDefaultsChanged" object:nil userInfo:@{@"pluginIdentifier": [self.bundle bundleIdentifier]} deliverImmediately:YES];
	}
	
	return ([writeDefaultTask terminationStatus] == 0);
}


- (id)objectForUserDefaultsKey:(NSString *)defaultName {
	
	if (self.sandboxedPrefsPath == nil) {
		return [super objectForUserDefaultsKey:defaultName];
	}
	
	return [self readDefaultValueForKey:defaultName];
}

- (void)setObject:(id)value forUserDefaultsKey:(NSString *)defaultName {
	
	if (self.skipPreferenceSaves) {
		return;
	}
	
	if (self.sandboxedPrefsPath == nil) {
		[super setObject:value forUserDefaultsKey:defaultName];
	}
	
	[self writeDefaultValue:value forKey:defaultName];
}

- (BOOL)boolForUserDefaultsKey:(NSString *)defaultName {
	
	if (self.sandboxedPrefsPath == nil) {
		return [super boolForUserDefaultsKey:defaultName];
	}
	
	NSNumber	*value = [self readDefaultValueForKey:defaultName];
	return [value boolValue];
}

- (void)setBool:(BOOL)value forUserDefaultsKey:(NSString *)defaultName {
	
	if (self.skipPreferenceSaves) {
		return;
	}
	
	if (self.sandboxedPrefsPath == nil) {
		[super setBool:value forUserDefaultsKey:defaultName];
	}
	
	NSNumber	*newValue = [NSNumber numberWithBool:value];
	[self writeDefaultValue:newValue forKey:defaultName];
}

+ (NSDateFormatter *)formatter {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		dateFormatter_LKS = [[NSDateFormatter alloc] init];
		[dateFormatter_LKS setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
		[dateFormatter_LKS setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
	});
	return dateFormatter_LKS;
}

@end
