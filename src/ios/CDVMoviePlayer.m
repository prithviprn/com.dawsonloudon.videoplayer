//
//  CDVMoviePlayer.m
//  OUAnywhere
//

#import "CDVMoviePlayer.h"
#import "MainViewController.h"
#import "PJHCaption.h"
#import "Defines.h"
#import "SMXMLDocument.h"
#import <MediaPlayer/MPMoviePlayerController.h>

static inline double radians (double degrees) {return degrees * M_PI/180;}

@implementation CDVMoviePlayer {
    CDVPluginResult *pluginResult;
    NSString *callbackID;
    MPMoviePlayerController *player;
    UIView *movieView;
    UIView *closedCaptionsView;
    UILabel *closedCaptionsLabel;
    NSMutableArray *closedCaptionsArray;
}

-(void)playMovie:(CDVInvokedUrlCommand *)command {
    callbackID = command.callbackId;

    // register for device rotations that MainViewController will post
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRotate:) name:kDeviceDidRotateNotification object:nil];
    
    // get the path to users Documents folder
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    // split array out by /
    NSArray *components = [[command.arguments objectAtIndex:0] componentsSeparatedByString:@"/"];
    
    // build the full path to video
    NSString *fName = [NSString stringWithFormat:@"%@/%@/%@",[components objectAtIndex:components.count-3],[components objectAtIndex:components.count-2], [components objectAtIndex:components.count-1]];
    
    NSString *fNameFullPath = [documentsDirectory stringByAppendingPathComponent:fName];

    // reference MainViewController for captions use
    // refer to MainViweController.m
    MainViewController *controller = (MainViewController*)[super viewController];
    
    // if 3 arguments present and 3rd is not empty we have captions
    // need to ask Nigel does JS pass in 3 values even when no captions required
    // would have expected only 2 when no captions present?
    if (command.arguments.count == 2 && [[command.arguments objectAtIndex:1] length] > 0) {
        // split out by /
        components = [[command.arguments objectAtIndex:1] componentsSeparatedByString:@"/"];
        
        // get path to XML file
        fName = [NSString stringWithFormat:@"%@/%@/%@",[components objectAtIndex:components.count-3],[components objectAtIndex:components.count-2], [components objectAtIndex:components.count-1]];
        
        // extract out captions
        [self extractCloseCaptionsFromFile:[documentsDirectory stringByAppendingPathComponent:fName]];
  
        // create movieView ready sized for captions inclusion
        movieView = [[UIView alloc] initWithFrame: CGRectMake(0, 0, controller.view.frame.size.width, controller.view.frame.size.height-100)];
    } else {
        // create movie view full screen
        movieView = [[UIView alloc] initWithFrame: controller.view.frame];
    }
    
    // MainViewController will use this tag to remove movie player from view when video is done with
    movieView.tag = 999;
    
    [controller.view addSubview:movieView];
   
    // if we actually have a video file
	if ([[NSFileManager defaultManager] fileExistsAtPath:fNameFullPath]) {
        // load in the required media into player
        player = [[MPMoviePlayerController alloc] initWithContentURL:[NSURL fileURLWithPath:fNameFullPath]];
		
        // set player view to sit inside movie view
        player.view.frame = movieView.frame;
        
        // place players view inside movie view
		[movieView addSubview:player.view];
        
		// start the movie playing
		[player play];
        
        // force full screen
        [player setFullscreen:YES animated:NO];
        
        // same as above, would not expect to receive 3 arguments from JS when no captions present?
        if (command.arguments.count == 2 && [[command.arguments objectAtIndex:1] length] > 0) {
            // create the view that will display closed captions
            closedCaptionsView = [[UIView alloc] initWithFrame:CGRectMake(player.view.frame.origin.x,
                                                                          player.view.frame.size.height + 40,
                                                                          player.view.frame.size.width, 80)];
        
            // has to be clear....der!
            closedCaptionsView.backgroundColor = [UIColor clearColor];
        
            // must be disabled so as not to affect video controls
            closedCaptionsView.userInteractionEnabled = NO;
        
            // MainViewController will use this tag for tidy up process
            closedCaptionsView.tag = 998;
            
            // create and configure label that will hold closed caption text
            closedCaptionsLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, closedCaptionsView.frame.size.width, closedCaptionsView.frame.size.height)];
            
            closedCaptionsLabel.backgroundColor = [UIColor clearColor];
            
            closedCaptionsLabel.textColor = [UIColor whiteColor];
            
            closedCaptionsLabel.textAlignment = NSTextAlignmentCenter;
            
            closedCaptionsLabel.numberOfLines = 4;
            
            [closedCaptionsView addSubview:closedCaptionsLabel];
            
            // grab the top most view in window
            //
            // as movie player is full screen adding an overlay to it does not get displayed
            // so we hack it by pusing the view to the top most view in window
            UIView *topView = [[[UIApplication sharedApplication] windows] objectAtIndex:0];
        
            // and add closed captions view to it
            [topView addSubview:closedCaptionsView];
        
            // and force to front
            [topView bringSubviewToFront:closedCaptionsView];
            
            // upon first onpening if device was in landscape the captions view does not pick up on this so just call a rotation check and tis done..
            [self didRotate:nil];
        }
    } else {
        // tell called we bombed
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"NO"];

        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackID];
	}
}

-(void)extractCloseCaptionsFromFile:(NSString *)fileName {
    
    // only if the XML file exists
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:fileName]) {
    
        // load XML into data
        
        NSData *data = [NSData dataWithContentsOfFile:fileName];
        
        NSError *error = nil;
        
        // parse data into SMXML document
        
        SMXMLDocument *doc = [SMXMLDocument documentWithData:data error:&error];
        
        // if no error (note if error just carry on, nothing will be displayed and video will continue to play)
        
        if (!error) {
        
            // grab the body tag
            
            SMXMLElement *body = [doc childNamed:@"body"];
            
            // grab the div tag out of body element
            
            SMXMLElement *div = [body childNamed:@"div"];
            
            // create array to hold Caption objects
            
            closedCaptionsArray = [NSMutableArray array];
            
            // create a date formatter to be used when compareing time intervals in showCaptions
            
            NSDateFormatter *formatter = [[NSDateFormatter alloc]init];
            
            [formatter setDateFormat:@"yyyy/mm/dd hh:mm:ss"];
            
            // base date to append times to
            
            NSString *base = @"2001/01/01";
            
            // for each paragraph tag
            
            for (SMXMLElement *p in [div childrenNamed:@"p"]) {
                
                // get begin time less hundreths of seconds (they break data maker)
                
                NSString *begin = [[p attributeNamed:@"begin"] stringByDeletingPathExtension];
                
                // get end time less hundreths of seconds (they break data maker)
                
                NSString *end = [[p attributeNamed:@"end"] stringByDeletingPathExtension];
                
                // build a full begin date string
                
                NSString *theDate = [NSString stringWithFormat:@"%@ %@", base, begin];
            
                // and create a begin date and time with it
                
                NSDate *beginDate = [formatter dateFromString:theDate];
                
                // build a full end date string
                
                theDate = [NSString stringWithFormat:@"%@ %@", base, end];
                
                // and create an end date and time with it
                
                NSDate *endDate = [formatter dateFromString:theDate];
                
                // extract out the interval for beginning
                
                NSTimeInterval beginInterval = [beginDate timeIntervalSinceReferenceDate];
               
                // extract out the interval for ending
                
                NSTimeInterval endInterval = [endDate timeIntervalSinceReferenceDate];
                
                // create a caption object with the begin, end and text data
                
                PJHCaption *caption = [[PJHCaption alloc] initWithBegin:beginInterval end:endInterval text:[p value]];
         
                // and save it into the captions array
                
                [closedCaptionsArray addObject:caption];
            }
            
            // reference MainViewController
            
            MainViewController *controller = (MainViewController*)[ super viewController ];
            
            // and use it timer to control the update of captions to screen
            
            controller.closedCaptionsTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                                                              target:self
                                                                            selector:@selector(showNextCaption)
                                                                            userInfo:nil
                                                                             repeats:YES];
        }
    }
}

-(void)showNextCaption {
    
    // will save last displayed text
    
    static NSString *lastText;
    
    // grab where movie time is right now
    
    NSTimeInterval interval = player.currentPlaybackTime;

    // cycle the captions in the captions array
    
    for (PJHCaption *caption in closedCaptionsArray) {
    
        // test if we have a caption to display
        
        if (interval >= caption.begin && interval <= caption.end) {
        
            // and if so only write to screen if text has changed
            
            if (![lastText isEqualToString:caption.text]) {
            
                // save text we are writing to screen
                
                lastText = caption.text;
            
                // update screen
                
                [closedCaptionsLabel setText: caption.text];
            }
        }
    }
}

-(void)didRotate:(NSNotification *)notification {
   
    // uncomment to see caption view placement
    //closedCaptionsView.backgroundColor = [UIColor redColor];
    
    // just to make life simple...
    
    float x, y, w, h;
    
    // grab current orientation of device
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    
    // simples...no?
    //
    // dependant on orientaion transform the captions view and the captions label so they are positioned and in correct orientation
    
    if (orientation == UIInterfaceOrientationLandscapeLeft) { // home button to left
     
        closedCaptionsView.transform = CGAffineTransformMakeRotation( radians(-90));
     
        x = ([[UIScreen mainScreen] bounds].size.width / 2) + 80;
        y = 0;
        w = 80;
        h = [[UIScreen mainScreen] bounds].size.height;
     
        closedCaptionsView.frame = CGRectMake(x,y,w, h);
         
        closedCaptionsLabel.frame = CGRectMake(0, 0, closedCaptionsView.frame.size.height, closedCaptionsView.frame.size.width);
    }
    else if (orientation == UIInterfaceOrientationLandscapeRight) { // home button to right
       
        closedCaptionsView.transform = CGAffineTransformMakeRotation( radians(90));
        
        x = 0;
        y = 0;
        w = 80;
        h = [[UIScreen mainScreen] bounds].size.height;
        
        closedCaptionsView.frame = CGRectMake(x,y,w, h);
        
        closedCaptionsLabel.frame = CGRectMake(0, 0, closedCaptionsView.frame.size.height, closedCaptionsView.frame.size.width);
    }
    else if (orientation == UIInterfaceOrientationPortrait) { // home button to bottom
       
        x = 0;
        y = [[UIScreen mainScreen] bounds].size.height - 80;
        w = [[UIScreen mainScreen] bounds].size.width;
        h = 80;
        
        closedCaptionsView.transform = CGAffineTransformIdentity; // CGAffineTransformMakeRotation(radians(90));
        
        closedCaptionsView.frame = CGRectMake(x,y,w,h);
        
        closedCaptionsLabel.frame = CGRectMake(0, 0, closedCaptionsView.frame.size.width, closedCaptionsView.frame.size.height);
    }
    else if (orientation == UIInterfaceOrientationPortraitUpsideDown) { // home button to top
       
        // oddly this does not get called so device and more importantly video playback remains in last landscape orientation 
    }
}

@end
