//
//  LKSPluginCodeSigningVerifier.m
//  Sparkle
//
//  Created by Scott Little on 12/8/13.
//
//

#import "LKSPluginCodeSigningVerifier.h"

#import <Security/CodeSigning.h>
#import "SULog.h"

@implementation LKSPluginCodeSigningVerifier

+ (BOOL)codeSignatureIsValidAtPath:(NSString *)destinationPath pluginPath:(NSString *)pluginPath error:(NSError **)error {
    
    OSStatus result;
    SecRequirementRef	requirement = NULL;
	SecStaticCodeRef	pluginCode = NULL;
    SecStaticCodeRef	destinationCode = NULL;
    
    NSBundle *pluginBundle = [NSBundle bundleWithPath:pluginPath];
    if (!pluginBundle) {
        SULog(@"Failed to load NSBundle for plugin");
        result = -1;
        goto finally;
    }
    
    result = SecStaticCodeCreateWithPath((CFURLRef)[pluginBundle executableURL], kSecCSDefaultFlags, &pluginCode);
    if (result != 0) {
        SULog(@"Failed to get plugin code %d", result);
        goto finally;
    }
    
    result = SecCodeCopyDesignatedRequirement(pluginCode, kSecCSDefaultFlags, &requirement);
    if (result != 0) {
        SULog(@"Failed to copy designated requirement %d", result);
        goto finally;
    }
    
    NSBundle *newBundle = [NSBundle bundleWithPath:destinationPath];
    if (!newBundle) {
        SULog(@"Failed to load NSBundle for update");
        result = -1;
        goto finally;
    }
    
    result = SecStaticCodeCreateWithPath((CFURLRef)[newBundle executableURL], kSecCSDefaultFlags, &destinationCode);
    if (result != 0) {
        SULog(@"Failed to get static code %d", result);
        goto finally;
    }
    
    result = SecStaticCodeCheckValidityWithErrors(destinationCode, kSecCSDefaultFlags | kSecCSCheckAllArchitectures, requirement, (CFErrorRef *)error);
    if (result != 0 && error) [*error autorelease];
    
finally:
    if (pluginCode) CFRelease(pluginCode);
    if (destinationCode) CFRelease(destinationCode);
    if (requirement) CFRelease(requirement);
    return (result == 0);
}

@end
