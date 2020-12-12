//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Wed Feb 5 2014.
//  Copyright (c) 2014-2020. Jean-Etienne LAMIAUD
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
//

#import <XCTest/XCTest.h>

#include <LynkeosCore/LynkeosProcessing.h>
#include <LynkeosCore/LynkeosFileReader.h>

#include "LynkeosImageBufferAdditions.h"
#include "LynkeosBasicAlignResult.h"
#include "MyImageListItem.h"
#include "MyDocument.h"
#include "MyPluginsController.h"
#include "MyImageStacker.h"
#include "ProcessTestUtilities.h"

NSString * const myChromaticAlignerRef = @"MyChromaticAlignerView";
NSString * const myChromaticAlignerOffsetsRef = @"ChromaticDispersionOffsets";

NSString * const K_PREF_STACK_MULTIPROC = @"Multiprocessor stack";

// Notification flag
NSString *K_ITEM_STACKED_REF = @"ItemStackedFlag";

// Notification observer shall be separate from the test class
@interface StackTestObserver :NSObject
{
@public
   BOOL stackStarted;
   BOOL stackDone;
}
- (void) stackStarted:(NSNotification*)notif ;
- (void) itemStacked:(NSNotification*)notif ;
- (void) stackEnded:(NSNotification*)notif ;
@end

@interface ImageStackerTest : XCTestCase
{
   MyDocument                                *_doc;
   NSEnumerator <LynkeosMultiPassEnumerator> *_strider;
   MyImageStackerList                        *_listParams;
   StackTestObserver                         *_obs;
   MyImageStackerParameters                  *_params;
}
@end

@interface ItemStackedFlag : NSObject <LynkeosProcessingParameter>
{
@public
   int stacked;
}
@end

// Fake reader
@interface StackTestReader : NSObject <LynkeosImageFileReader>
{
   LynkeosImageBuffer *_image;
}
@end

// Fake chromatic offsets
@interface MyChromaticAlignParameter : NSObject
{
@public
   u_short             _numOffsets;
   NSPointArray        _offsets;
}
@end

@implementation MyChromaticAlignParameter
@end

@implementation ItemStackedFlag : NSObject
- (void)encodeWithCoder:(NSCoder *)encoder
{ [self doesNotRecognizeSelector:_cmd]; }
- (id) initWithCoder:(NSCoder *)decoder
{
   [self doesNotRecognizeSelector:_cmd];
   return( nil );
}
@end

@implementation StackTestObserver
- (id) init
{
   if ( (self = [super init]) != nil )
   {
      stackStarted = NO;
      stackDone = NO;
   }
   return( self );
}

- (void) stackStarted:(NSNotification*)notif
{
   stackStarted = YES;
}

- (void) itemStacked:(NSNotification*)notif
{
   MyImageListItem *item = [[notif userInfo] objectForKey:LynkeosUserInfoItem];
   ItemStackedFlag *param = [item getProcessingParameterWithRef:K_ITEM_STACKED_REF
                                                  forProcessing:nil];

   if ( param == nil )
   {
      // We will receive a notification for our own setProcessingParameter
      // Therefore, start at 0, the extra notif will go to 1
      ItemStackedFlag *param = [[ItemStackedFlag alloc] init];

      param->stacked = 0;
      [item setProcessingParameter:param withRef:K_ITEM_STACKED_REF
                     forProcessing:nil];
   }
   else
      param->stacked ++;
}

- (void) stackEnded:(NSNotification*)notif
{
   stackDone = YES;
   NSLog(@"Stack done");
}
@end

@implementation StackTestReader
+ (void) lynkeosFileTypes:(NSArray**)fileTypes
{
   *fileTypes = [NSArray arrayWithObject:@"stktst"];
}

- (id) init
{
   if ( (self = [super init]) != nil )
      _image = [[LynkeosImageBuffer imageBufferWithNumberOfPlanes:1
                                                                    width:2
                                                                   height:2]
                retain];

   return( self );
}

- (id) initWithURL:(NSURL*)url
{
   // Pixel values series by pixel
   const REAL imgTemplate[2][2][4] =
   {
      {
         // Same value -> no rejection
         {128.0, 128.0, 128.0, 128.0},
         // Symmetric values in two clusters -> no rejection
         {0.0, 0.0, 255.0, 255.0}
      },
      {
         // Three in a cluster, one away -> last is rejected
         {10.0, 11.0, 12.0, 80.0},
         // Two in a cluster, two symmetrically away -> outlying are rejected
         {40.0, 127.0, 129.0, 192.0}
      }
   };
   if ( (self = [self init]) != nil )
   {
      u_short idx, x, y;
      if ( [[url path] isEqual:@"/image1.stktst"] )
         idx = 0;
      else if ( [[url path] isEqual:@"/image2.stktst"] )
         idx = 1;
      else if ( [[url path] isEqual:@"/image3.stktst"] )
         idx = 2;
      else if ( [[url path] isEqual:@"/image4.stktst"] )
         idx = 3;
      else
         NSAssert(NO, @"Wrong image name");

      for( y = 0; y < 2; y++ )
      {
         for( x = 0; x < 2; x++ )
         {
            colorValue(_image,x,y,0) = imgTemplate[y][x][idx];
         }
      }
   }

   return( self );
}

- (void) dealloc
{
   [_image release];
   [super dealloc];
}

- (u_short) numberOfPlanes
{
   return( [_image numberOfPlanes] );
}

- (void) getMinLevel:(double*)vmin maxLevel:(double*)vmax
{
   *vmin = 0.0;
   *vmax = 255.0;
}

- (void) imageWidth:(u_short*)w height:(u_short*)h
{
   *w = [_image width];
   *h = [_image height];
}

- (NSDictionary*) getMetaData { return( nil ); }

- (NSImage*) getNSImage{ return( nil ); }

- (void) getImageSample:(REAL * const * const)sample
             withPlanes:(u_short)nPlanes
                    atX:(u_short)x Y:(u_short)y W:(u_short)w H:(u_short)h
              lineWidth:(u_short)lineW ;
{
   [_image extractSample:sample
                     atX:x Y:y withWidth:w height:h
              withPlanes:nPlanes lineWidth:lineW];
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
   [self doesNotRecognizeSelector:_cmd];
}

- (id)initWithCoder:(NSCoder *)decoder
{
   [self doesNotRecognizeSelector:_cmd];
   return( nil );
}
@end

@implementation ImageStackerTest

+ (void) initialize
{
   initializeProcessTests();
   // Allow multithreading
   [[NSUserDefaults standardUserDefaults] setInteger:ListThreadsOptimizations
                                              forKey:K_PREF_STACK_MULTIPROC];
}

- (void)setUp
{
    [super setUp];

   // Put setup code here. This method is called before the invocation of each test method in the class.
   // Create the document
   _doc = [[MyDocument alloc] init];

   // Add all the items to the document
   LynkeosBasicAlignResult *alignment
      = [[[LynkeosBasicAlignResult alloc] init] autorelease];
   int i;

   for ( i = 1; i <= 4; i++ )
   {
      MyImageListItem *item
         = [[MyImageListItem alloc] initWithURL:[NSURL URLWithString:
                                                   [NSString stringWithFormat:
                                                @"file:///image%d.stktst", i]]];
      [item setProcessingParameter:alignment
                           withRef:LynkeosAlignResultRef
                     forProcessing:LynkeosAlignRef];
      [_doc addEntry:item];
   }

   // Get an enumerator on the images
   _strider = [[[_doc imageList] multiPassImageEnumeratorStartAt:nil
                                                     directSense:YES
                                                  skipUnselected:YES] retain];

   // Prepare the processing input parameters
   _listParams = [[MyImageStackerList alloc] init];
   _listParams->_list = [_doc imageList];

   // And the common stacking parameters
   _params = [[MyImageStackerParameters alloc] init];
   _params->_cropRectangle = LynkeosMakeIntegerRect(0, 0, 2, 2);
   _params->_enumerator = _strider;
   _params->_monochromeStack = NO;
   _params->_stackLock = [[NSConditionLock alloc] init];

   // Set the parameters in the list
   [[_doc imageList] setProcessingParameter:_params
                                    withRef:myImageStackerParametersRef
                              forProcessing:myImageStackerRef];

   // Register for doc notifications
   _obs = [[StackTestObserver alloc] init];
   [[NSNotificationCenter defaultCenter] addObserver:_obs
                                            selector:@selector(stackStarted:)
                                                name:
                                               LynkeosProcessStartedNotification
                                              object:_doc];
   [[NSNotificationCenter defaultCenter] addObserver:_obs
                                            selector:@selector(itemStacked:)
                                                name:
                                                  LynkeosItemChangedNotification
                                              object:_doc];
   [[NSNotificationCenter defaultCenter] addObserver:_obs
                                            selector:@selector(stackEnded:)
                                                name:
                                                 LynkeosProcessEndedNotification
                                              object:_doc];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
   [[NSNotificationCenter defaultCenter] removeObserver:_obs];
   [_strider release];
   _strider = nil;
   [_obs release];
   _obs = nil;
   [_listParams release];
   _listParams = nil;
   [_doc release];
   _doc = nil;
   [_params release];
   _params = nil;

   [super tearDown];
}

- (void) testStackStandard
{
   _params->_stackMethod = Stacking_Standard;
   _params->_postStack = MeanStack;

   // Ask the doc to align
   [_doc startProcess:[MyImageStacker class] withEnumerator:_strider
          parameters:_listParams];

   // Wait for process end
   NSDate *timeout = [NSDate dateWithTimeIntervalSinceNow:2.0];
   while ( [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                    beforeDate:timeout]
           && [timeout compare:[NSDate date]] == NSOrderedDescending
           && ! _obs->stackDone )
      ;

   // Verify the results
   XCTAssertTrue( _obs->stackStarted, @"No notification of stack start" );
   XCTAssertTrue( _obs->stackDone, @"Stack not performed after delay" );

   NSEnumerator *listEnum = [[_doc imageList] imageEnumerator];

   // First item
   MyImageListItem *item = [listEnum nextObject];

   ItemStackedFlag *stackedFlag =
      [item getProcessingParameterWithRef:K_ITEM_STACKED_REF
                            forProcessing:nil];
   XCTAssertNotNil( stackedFlag, @"No notification flag for item 0" );
   if ( stackedFlag != nil )
      XCTAssertTrue( stackedFlag->stacked,
                    @"Bad notification flag state for item 0" );

   LynkeosImageBuffer *img = [[_doc imageList] getImage];
   XCTAssertNotNil( img, @"No stacking result for item 0" );
   if ( img != nil )
   {
      XCTAssertEqualWithAccuracy( colorValue(img,0,0,0), 128.0, 1e-2,
                                  @"Incorrect stacking at 0,0" );
      XCTAssertEqualWithAccuracy( colorValue(img,1,0,0), 127.5, 1e-2,
                                 @"Incorrect stacking at 1,0" );
      XCTAssertEqualWithAccuracy( colorValue(img,0,1,0), 28.25, 1e-2,
                                 @"Incorrect stacking at 1,0" );
      XCTAssertEqualWithAccuracy( colorValue(img,1,1,0), 122.0, 1e-2,
                                 @"Incorrect stacking at 1,1" );
   }
}

- (void) testStackSigmaReject
{
   _params->_stackMethod = Stacking_Sigma_Reject;
   _params->_method.sigma.threshold = 1.0;
   _params->_postStack = NoPostStack;

   // Ask the doc to stack
   [_doc startProcess:[MyImageStacker class] withEnumerator:_strider
           parameters:_listParams];

   // Wait for process end
   NSDate *timeout = [NSDate dateWithTimeIntervalSinceNow:2.0];
   while ( [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                    beforeDate:timeout]
          && [timeout compare:[NSDate date]] == NSOrderedDescending
          && ! _obs->stackDone )
      ;

   // Verify the results
   XCTAssertTrue( _obs->stackStarted, @"No notification of stack start" );
   XCTAssertTrue( _obs->stackDone, @"Stack not performed after delay" );

   NSEnumerator *listEnum = [[_doc imageList] imageEnumerator];

   // First item
   MyImageListItem *item = [listEnum nextObject];

   ItemStackedFlag *stackedFlag =
      [item getProcessingParameterWithRef:K_ITEM_STACKED_REF
                            forProcessing:nil];
   XCTAssertNotNil( stackedFlag, @"No notification flag for item 0" );
   if ( stackedFlag != nil )
      XCTAssertTrue( stackedFlag->stacked,
                    @"Bad notification flag state for item 0" );

   LynkeosImageBuffer *img = [[_doc imageList] getImage];
   XCTAssertNotNil( img, @"No stacking result for item 0" );
   if ( img != nil )
   {
      XCTAssertEqualWithAccuracy( colorValue(img,0,0,0), 128.0, 1e-2,
                                 @"Incorrect stacking at 0,0" );
      XCTAssertEqualWithAccuracy( colorValue(img,1,0,0), 127.5, 1e-2,
                                 @"Incorrect stacking at 1,0" );
      XCTAssertEqualWithAccuracy( colorValue(img,0,1,0), 11.0, 1e-2,
                                 @"Incorrect stacking at 0,1" );
      XCTAssertEqualWithAccuracy( colorValue(img,1,1,0), 128.0, 1e-2,
                                 @"Incorrect stacking at 1,1" );
   }
}

- (void) testStackMinimum
{
   _params->_stackMethod = Stacking_Extremum;
   _params->_method.extremum.maxValue = NO;
   _params->_postStack = NoPostStack;

   // Ask the doc to align
   [_doc startProcess:[MyImageStacker class] withEnumerator:_strider
           parameters:_listParams];

   // Wait for process end
   NSDate *timeout = [NSDate dateWithTimeIntervalSinceNow:2.0];
   while ( [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                    beforeDate:timeout]
          && [timeout compare:[NSDate date]] == NSOrderedDescending
          && ! _obs->stackDone )
      ;

   // Verify the results
   XCTAssertTrue( _obs->stackStarted, @"No notification of stack start" );
   XCTAssertTrue( _obs->stackDone, @"Stack not performed after delay" );

   NSEnumerator *listEnum = [[_doc imageList] imageEnumerator];

   // First item
   MyImageListItem *item = [listEnum nextObject];

   ItemStackedFlag *stackedFlag =
      [item getProcessingParameterWithRef:K_ITEM_STACKED_REF
                            forProcessing:nil];
   XCTAssertNotNil( stackedFlag, @"No notification flag for item 0" );
   if ( stackedFlag != nil )
      XCTAssertTrue( stackedFlag->stacked,
                    @"Bad notification flag state for item 0" );

   LynkeosImageBuffer *img = [[_doc imageList] getImage];
   XCTAssertNotNil( img, @"No stacking result for item 0" );
   if ( img != nil )
   {
      XCTAssertEqualWithAccuracy( colorValue(img,0,0,0), 128.0, 1e-2,
                                 @"Incorrect stacking at 0,0" );
      XCTAssertEqualWithAccuracy( colorValue(img,1,0,0), 0.0, 1e-2,
                                 @"Incorrect stacking at 1,0" );
      XCTAssertEqualWithAccuracy( colorValue(img,0,1,0), 10.0, 1e-2,
                                 @"Incorrect stacking at 1,0" );
      XCTAssertEqualWithAccuracy( colorValue(img,1,1,0), 40.0, 1e-2,
                                 @"Incorrect stacking at 1,1" );
   }
}

- (void) testStackMaximum
{
   _params->_stackMethod = Stacking_Extremum;
   _params->_method.extremum.maxValue = YES;
   _params->_postStack = NoPostStack;

   // Ask the doc to align
   [_doc startProcess:[MyImageStacker class] withEnumerator:_strider
           parameters:_listParams];

   // Wait for process end
   NSDate *timeout = [NSDate dateWithTimeIntervalSinceNow:2.0];
   while ( [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                    beforeDate:timeout]
          && [timeout compare:[NSDate date]] == NSOrderedDescending
          && ! _obs->stackDone )
      ;

   // Verify the results
   XCTAssertTrue( _obs->stackStarted, @"No notification of stack start" );
   XCTAssertTrue( _obs->stackDone, @"Stack not performed after delay" );

   NSEnumerator *listEnum = [[_doc imageList] imageEnumerator];

   // First item
   MyImageListItem *item = [listEnum nextObject];

   ItemStackedFlag *stackedFlag =
      [item getProcessingParameterWithRef:K_ITEM_STACKED_REF
                            forProcessing:nil];
   XCTAssertNotNil( stackedFlag, @"No notification flag for item 0" );
   if ( stackedFlag != nil )
      XCTAssertTrue( stackedFlag->stacked,
                    @"Bad notification flag state for item 0" );

   LynkeosImageBuffer *img = [[_doc imageList] getImage];
   XCTAssertNotNil( img, @"No stacking result for item 0" );
   if ( img != nil )
   {
      XCTAssertEqualWithAccuracy( colorValue(img,0,0,0), 128.0, 1e-2,
                                 @"Incorrect stacking at 0,0" );
      XCTAssertEqualWithAccuracy( colorValue(img,1,0,0), 255.0, 1e-2,
                                 @"Incorrect stacking at 1,0" );
      XCTAssertEqualWithAccuracy( colorValue(img,0,1,0), 80.0, 1e-2,
                                 @"Incorrect stacking at 1,0" );
      XCTAssertEqualWithAccuracy( colorValue(img,1,1,0), 192.0, 1e-2,
                                 @"Incorrect stacking at 1,1" );
   }
}
@end
