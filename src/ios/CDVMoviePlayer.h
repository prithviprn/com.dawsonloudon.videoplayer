//
//  CDVMoviePlayer.h
//  OUAnywhere
//

#import <Cordova/CDV.h>

@class CDVMoviePlayer;

@protocol CDVMoviePlayerDelegate

-(void)CDVMoviePlayer:(CDVMoviePlayer *)moviePlayer initializeWithMovie:(NSString *)fileName;
-(void)CDVMoviePlayer:(CDVMoviePlayer *)moviePlayer updateCaptionWithString:(NSString *)caption;

@end

@interface CDVMoviePlayer : CDVPlugin

@property (nonatomic, assign) id<CDVMoviePlayerDelegate>delegate;

-(void)playMovie:(CDVInvokedUrlCommand *)command;

@end
