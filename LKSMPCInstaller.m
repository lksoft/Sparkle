//
//  LKSMPCInstaller.m
//  Sparkle
//
//  Created by Little Known on 21/05/15.
//
//

#import "LKSMPCInstaller.h"


NSString *LKMPCInstallerHostKey = @"LKMPCInstallerHost";
NSString *LKMPCInstallerDelegateKey = @"LKMPCInstallerDelegate";
NSString *LKMPCInstallerCommandKey = @"LKMPCInstallerCommandKey";
NSString *LKMPCInstallerArgumentsKey = @"LKMPCInstallerArgumentsKey";
NSString *LKMPCInstallerInstallationPathKey = @"LKMPCInstallerInstallationPathKey";

NSString *LKMPCErrorDomain = @"LKSMPTSparkleInstallerDomain";

typedef NS_ENUM(NSUInteger, LKMPCErrorCode) {
	LKMPCErrorCodeInvalidInstallFile = 4001,
	LKMPCErrorCodeInvalidInstallFileFormat
};



@implementation LKSMPCInstaller

+ (void)performInstallationWithInfo:(NSDictionary *)info {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSTask *installer = [NSTask launchedTaskWithLaunchPath:info[LKMPCInstallerCommandKey] arguments:info[LKMPCInstallerArgumentsKey]];
	[installer waitUntilExit];
	
	//	Just wait 3 seconds for it to finish
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:3.0f]];
	
	// Known bug: if the installation fails or is canceled, Sparkle goes ahead and restarts, thinking everything is fine.
	if ([NSThread isMainThread]) {
		[self finishInstallationToPath:info[LKMPCInstallerInstallationPathKey] withResult:YES host:info[LKMPCInstallerHostKey] error:nil delegate:info[LKMPCInstallerDelegateKey]];
	}
	else {
		dispatch_sync(dispatch_get_main_queue(), ^{
			[self finishInstallationToPath:info[LKMPCInstallerInstallationPathKey] withResult:YES host:info[LKMPCInstallerHostKey] error:nil delegate:info[LKMPCInstallerDelegateKey]];
		});
	}
	
	[pool drain];
}

+ (void)performInstallationToPath:(NSString *)installationPath fromPath:(NSString *)path host:(SUHost *)host delegate:delegate synchronously:(BOOL)synchronously versionComparator:(id <SUVersionComparison>)comparator {

	NSError				*error = nil;
	NSURL				*installerURL = [NSURL fileURLWithPath:path];
	
	
	if ((installerURL == nil) && ![[NSWorkspace sharedWorkspace] isFilePackageAtPath:installerURL.path]) {
		//	Error message
		NSString	*errorString = [NSString stringWithFormat:NSLocalizedString(@"The installation file [%@] is not valid.", @""), path];
		error = [NSError errorWithDomain:LKMPCErrorDomain code:LKMPCErrorCodeInvalidInstallFile userInfo:@{NSLocalizedDescriptionKey: errorString}];
	}
	else {
		NSArray	*deliveryItems = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:installerURL includingPropertiesForKeys:nil options:(NSDirectoryEnumerationSkipsHiddenFiles & NSDirectoryEnumerationSkipsPackageDescendants & NSDirectoryEnumerationSkipsSubdirectoryDescendants) error:&error];
		
		NSString	*manifestFilePath = nil;
		for (NSURL *deliveryItem in deliveryItems) {
			if ([[deliveryItem lastPathComponent] isEqualToString:@"mpm-manifest.plist"]) {
				manifestFilePath = [deliveryItem path];
				break;
			}
		}
		//	If we don't have a manifest file..
		if ((error == nil) && (manifestFilePath == nil)) {
			NSString	*errorString = [NSString stringWithFormat:NSLocalizedString(@"The installation file [%@] does not have a proper manifest file.", @""), installerURL];
			error = [NSError errorWithDomain:LKMPCErrorDomain code:LKMPCErrorCodeInvalidInstallFileFormat userInfo:@{NSLocalizedDescriptionKey: errorString}];
		}
	}
	
	//	If we have an error, then show it
	if (error != nil) {
		[self finishInstallationToPath:installationPath withResult:NO host:host error:error delegate:delegate];
	}
	else {
		
		//	/usr/bin/open -a [path_to_MPT] --args -install [bundle_path_to_replace] [mpinstall_file_path]
		
		// The -W and -n options were added to the 'open' command in 10.5
		// -W = wait until the app has quit.
		// -n = Open another instance if already open.
		// -b = app bundle identifier
		NSString	*pluginToolPath = [installationPath stringByAppendingPathComponent:@"/Contents/Resources/MailPluginTool.app"];
		pluginToolPath = @"/Users/testing/Library/Developer/Xcode/DerivedData/MailPluginManager-awzptkybbxtathdbrfwrddbxaebv/Build/Products/Debug/MailPluginTool.app";
		NSString	*command = @"/usr/bin/open";
		NSArray		*args = @[@"-W", @"-a", pluginToolPath, @"--args", @"-install", installationPath, path];
		
		NSDictionary *info = @{LKMPCInstallerHostKey: host, LKMPCInstallerDelegateKey: delegate, LKMPCInstallerInstallationPathKey: installationPath, LKMPCInstallerCommandKey: command, LKMPCInstallerArgumentsKey: args};
		
		if (synchronously) {
			[self performInstallationWithInfo:info];
		}
		else {
			[NSThread detachNewThreadSelector:@selector(performInstallationWithInfo:) toTarget:self withObject:info];
		}
	}
}

@end
