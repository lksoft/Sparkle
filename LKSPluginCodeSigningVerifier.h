//
//  LKSPluginCodeSigningVerifier.h
//  Sparkle
//
//  Created by Scott Little on 12/8/13.
//
//

#import "SUCodeSigningVerifier.h"

@interface LKSPluginCodeSigningVerifier : SUCodeSigningVerifier
+ (BOOL)codeSignatureIsValidAtPath:(NSString *)destinationPath pluginPath:(NSString *)pluginPath error:(NSError **)error;
@end
