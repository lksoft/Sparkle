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


static	NSDateFormatter	*dateFormatter_LKS = nil;

@interface LKSPluginHost ()

@property	(strong)	NSString	*sandboxedPrefsPath;

@end

@implementation LKSPluginHost

@synthesize sandboxedPrefsPath = _sandboxedPrefsPath;

- (id)initWithBundle:(NSBundle *)aBundle {
	self = [super initWithBundle:aBundle];
	if (self) {
		NSRange		pathRange = [[aBundle bundlePath] rangeOfString:@"/Library/Mail/Bundles"];
		NSString	*bundleExt = [[aBundle bundlePath] pathExtension];
		if ((pathRange.location != NSNotFound) && [bundleExt isEqualToString:@"mailbundle"]) {
			NSString	*libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
			NSString	*plistName = [[aBundle bundleIdentifier] stringByAppendingPathExtension:@"plist"];
			self.sandboxedPrefsPath = [[libraryPath stringByAppendingPathComponent:@"Containers/com.apple.mail/Data/Library/Preferences"] stringByAppendingPathComponent:plistName];
		}
	}
	return self;
}

-(void)dealloc {
	self.sandboxedPrefsPath = nil;
	[super dealloc];
}

- (id)readDefaultValueForKey:(NSString *)defaultKey {
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:self.sandboxedPrefsPath]) {

		NSTask *readDefaultTask = [[NSTask alloc] init];
		[readDefaultTask setLaunchPath:@"/usr/bin/defaults"];
		[readDefaultTask setArguments:@[@"read", self.sandboxedPrefsPath, defaultKey]];
		
		NSPipe *pipe = [NSPipe pipe];
		[readDefaultTask setStandardOutput:pipe];
		NSFileHandle *file = [pipe fileHandleForReading];
		
		[readDefaultTask launch];
		[readDefaultTask waitUntilExit];

		NSString *tempString = [[NSString alloc] initWithData:[file readDataToEndOfFile] encoding:NSUTF8StringEncoding];
		NSString *cleanedString = [tempString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

		[readDefaultTask release];
		[tempString release];
		
		//	If it is a string value just return it
		if ([KEY_LIST_FOR_STRING rangeOfString:defaultKey].location != NSNotFound) {
			return cleanedString;
		}
		
		//	If the key is for a number, convert to a number
		if ([KEY_LIST_FOR_NUMBER rangeOfString:defaultKey].location != NSNotFound) {
			return [NSNumber numberWithInteger:[cleanedString integerValue]];
		}
		
		//	Otherwise make it a date, if that is the right choice
		if ([KEY_LIST_FOR_DATE rangeOfString:defaultKey].location != NSNotFound) {
			return [[[self class] formatter] dateFromString:cleanedString];
		}
		else {
			NSLog(@"Could not find the proper type for default:%@", defaultKey);
		}
		
	}
	else {
		return [super objectForUserDefaultsKey:defaultKey];
	}
	
	return nil;
}

- (BOOL)writeDefaultValue:(id)value forKey:(NSString *)defaultKey {
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:self.sandboxedPrefsPath]) {
		
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
			NSLog(@"Error trying to write a default value – not valid value extracted from %@", value);
			return NO;
		}
		
		NSTask *writeDefaultTask = [[[NSTask alloc] init] autorelease];
		[writeDefaultTask setLaunchPath:@"/usr/bin/defaults"];
		[writeDefaultTask setArguments:@[@"write", self.sandboxedPrefsPath, defaultKey, valueType, valueString]];
		
		[writeDefaultTask launch];
		[writeDefaultTask waitUntilExit];
		
		if ([writeDefaultTask terminationStatus] == 0) {
			//	Send a distributed notice to give the plugin a chance to reload defaults if necessary
			[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"LKSSUPluginDefaultsChanged" object:nil userInfo:@{@"pluginIdentifier": [self.bundle bundleIdentifier]} deliverImmediately:YES];
		}
		
		return ([writeDefaultTask terminationStatus] == 0);
	}
	else {
		[super setObject:value forUserDefaultsKey:defaultKey];
		return YES;
	}
	
	return NO;
}


- (id)objectForUserDefaultsKey:(NSString *)defaultName {
	
	if (self.sandboxedPrefsPath == nil) {
		return [super objectForUserDefaultsKey:defaultName];
	}
	
	return [self readDefaultValueForKey:defaultName];
}

- (void)setObject:(id)value forUserDefaultsKey:(NSString *)defaultName {
	
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
	
	if (self.sandboxedPrefsPath == nil) {
		[super setBool:value forUserDefaultsKey:defaultName];
	}
	
	NSNumber	*newValue = [NSNumber numberWithBool:value];
	[self writeDefaultValue:newValue forKey:defaultName];
}

+ (NSDateFormatter *)formatter {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		dateFormatter_LKS = [[NSDateFormatter alloc] initWithDateFormat:@"yyyy-MM-dd'T'HH:mm:ssz" allowNaturalLanguage:NO];
	});
	return dateFormatter_LKS;
}

@end
