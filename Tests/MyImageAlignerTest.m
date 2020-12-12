//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Fri Sep 29 2006.
//  Copyright (c) 2006-2020. Jean-Etienne LAMIAUD
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
#include "ProcessTestUtilities.h"

#include "LynkeosProcessing.h"
#include "MyPluginsController.h"
#include "LynkeosThreadConnection.h"
#include "MyProcessingThread.h"
#include "MyImageAligner.h"
#include "LynkeosImageBuffer.h"
#include "LynkeosImageBufferAdditions.h"
#include "MyDocument.h"

const NSPoint K_IMG10_STARS[] =
 { {30.0, 40.0},
   {30.0, 20.0} };
const NSPoint K_IMG11_STARS[] =
 { {30.0, 40.0},
   {42.0, 24.0} };
const NSPoint K_IMG12_STARS[] =
 { {30.0, 40.0},
   {20.0, 20.0},
   {40.0, 20.0}
};
const NSPoint K_IMG13_STARS[] =
 { {34.8, 43.5},
   {18.3, 22.4},
   {41.8, 17.6}
};

@interface MyImageAlignerTest : XCTestCase
{
}
@end

static BOOL processTestInitialized = NO;

NSString * const K_PREF_END_PROCESS_SOUND = @"End of processing sound";
NSString * const K_PREF_ALIGN_MULTIPROC = @"Multiprocessor align";
NSString * const K_PREF_ALIGN_CHECK = @"Align check";

void initializeProcessTests( void )
{
   if ( !processTestInitialized )
   {
      processTestInitialized = YES;
      // Initialize vector and multiprocessor stuff
      initializeProcessing();
      // Create the plugins controller singleton, and initialize it
      [[[MyPluginsController alloc] init] awakeFromNib];
   }
}

// Notification flag
NSString *K_ITEM_ALIGNED_REF = @"ItemAlignedFlag";
@interface ItemAlignedFlag : NSObject <LynkeosProcessingParameter>
{
@public
   BOOL aligned;
}
@end

// Notification observer shall be separate from the test class
@interface TestObserver :NSObject
{
@public
   BOOL alignStarted;
   BOOL alignDone;
}
- (void) alignStarted:(NSNotification*)notif ;
- (void) itemAligned:(NSNotification*)notif ;
- (void) alignEnded:(NSNotification*)notif ;
@end

// Fake reader
@interface TestReader : NSObject <LynkeosImageFileReader>
{
   LynkeosImageBuffer *_image;
}
@end

// A fake cache prefs class
@interface MyCachePrefs : NSObject
@end

@implementation MyCachePrefs
@end

// Fake window controller
@interface MyImageListWindow : NSObject
@end

@implementation MyImageListWindow
@end

@implementation ItemAlignedFlag : NSObject
- (void)encodeWithCoder:(NSCoder *)encoder
{ [self doesNotRecognizeSelector:_cmd]; }
- (id) initWithCoder:(NSCoder *)decoder
{
   [self doesNotRecognizeSelector:_cmd];
   return( nil );
}
@end

@implementation TestObserver
- (id) init
{
   if ( (self = [super init]) != nil )
   {
      alignStarted = NO;
      alignDone = NO;
   }
   return( self );
}

- (void) alignStarted:(NSNotification*)notif
{
   alignStarted = YES;
}

- (void) itemAligned:(NSNotification*)notif
{
   MyImageListItem *item = [[notif userInfo] objectForKey:LynkeosUserInfoItem];

   // We will receive a notification for our own setProcessingParameter
   // Therefore, don't repeat it if it's done
   if ( [item getProcessingParameterWithRef:K_ITEM_ALIGNED_REF
                              forProcessing:nil] == nil )
   {
      ItemAlignedFlag *param = [[ItemAlignedFlag alloc] init];

      param->aligned = YES;
      [item setProcessingParameter:param withRef:K_ITEM_ALIGNED_REF
                     forProcessing:nil];
   }
}

- (void) alignEnded:(NSNotification*)notif
{
   alignDone = YES;
}
@end

@implementation TestReader
+ (void) lynkeosFileTypes:(NSArray**)fileTypes
{
   *fileTypes = [NSArray arrayWithObject:@"tst"];
}

- (id) init
{
   if ( (self = [super init]) != nil )
      _image = [[LynkeosImageBuffer imageBufferWithNumberOfPlanes:1 
                                                      width:60
                                                     height:60] retain];

   return( self );
}

- (id) initWithURL:(NSURL*)url
{
   if ( (self = [self init]) != nil )
   {
      u_short x, y, n, i;
      double dx[3], dy[3];
      if ( [[url path] isEqual:@"/image1.tst"] )
      { dx[0] = 15.0; dy[0] = 15.0; n = 1; }
      else if ( [[url path] isEqual:@"/image2.tst"] )
      { dx[0] = 15.25; dy[0] = 15.0; n = 1; }
      else if ( [[url path] isEqual:@"/image3.tst"] )
      { dx[0] = 15.0; dy[0] = 15.5; n = 1; }
      else if ( [[url path] isEqual:@"/image4.tst"] )
      { dx[0] = 14.0; dy[0] = 14.0; n = 1; }
      else if ( [[url path] isEqual:@"/image5.tst"] )
      { dx[0] = 35.0; dy[0] = 35.0; n = 1; }
      else if ( [[url path] isEqual:@"/image6.tst"] )
      { dx[0] = 15.0; dy[0] = 35.0; n = 1; }
      else if ( [[url path] isEqual:@"/image7.tst"] )
      { dx[0] = 35.0; dy[0] = 15.0; n = 1; }
      else if ( [[url path] isEqual:@"/image10.tst"] )
      {
         n = 2;
         for (i = 0; i < n; i++)
         {
            dx[i] = K_IMG10_STARS[i].x;
            dy[i] = _image->_h - K_IMG10_STARS[i].y;
         }
      }
      else if ( [[url path] isEqual:@"/image11.tst"] )
      {
         n = 2;
         for (i = 0; i < n; i++)
         {
            dx[i] = K_IMG11_STARS[i].x;
            dy[i] = _image->_h - K_IMG11_STARS[i].y;
         }
      }
      else if ( [[url path] isEqual:@"/image12.tst"] )
      {
         n = 3;
         for (i = 0; i < n; i++)
         {
            dx[i] = K_IMG12_STARS[i].x;
            dy[i] = _image->_h - K_IMG12_STARS[i].y;
         }
      }
      else if ( [[url path] isEqual:@"/image13.tst"] )
      {
         n = 3;
         for (i = 0; i < n; i++)
         {
            dx[i] = K_IMG13_STARS[i].x;
            dy[i] = _image->_h - K_IMG13_STARS[i].y;
         }
      }

      // Build a pseudo star
      for( y = 0; y < 60; y++ )
      {
         for( x = 0; x < 60; x++ )
         {
            REAL v = 0.0;
            int i;

            for ( i = 0; i < n; i++ )
               v += exp( -(((double)x - dx[i]) * ((double)x - dx[i])
                          +((double)y - dy[i]) * ((double)y - dy[i]))
                       /2.0 );

            colorValue(_image,x,y,0) = v;
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
   *vmax = 1.0;
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
   [_image extractSample:sample atX:x Y:y withWidth:w height:h withPlanes:nPlanes lineWidth:lineW];
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

@implementation MyImageAlignerTest
+ (void) initialize
{
   initializeProcessTests();
}

- (void) testAlign_0_025_050_1
{
   // Create the document
   MyDocument *doc = [[MyDocument alloc] init];

   // Prepare the parameters
   MyImageAlignerListParametersV3 *listParams =
                                  [[MyImageAlignerListParametersV3 alloc] init];
   listParams->_referenceItem = [[MyImageListItem alloc] initWithURL:
                                   [NSURL URLWithString:@"file:///image1.tst"]];
   MyImageAlignerSquareV3 *pt
      = [[[MyImageAlignerSquareV3 alloc] init] autorelease];
   pt->_alignOrigin = LynkeosMakeIntegerPoint(11,42);
   pt->_alignSize = LynkeosMakeIntegerSize(7,7);
   [listParams->_alignSquares addObject:pt];
   listParams->_cutoff = 0.707;
   listParams->_precisionThreshold = 0.125;
   listParams->_checkAlignResult = NO;

   // Add all the items to the document
   [doc addEntry:(MyImageListItem*)listParams->_referenceItem];
   [doc addEntry:[[MyImageListItem alloc] initWithURL:
                                  [NSURL URLWithString:@"file:///image2.tst"]]];
   [doc addEntry:[[MyImageListItem alloc] initWithURL:
                                  [NSURL URLWithString:@"file:///image3.tst"]]];
   MyImageListItem *item = [[MyImageListItem alloc] initWithURL:
                                   [NSURL URLWithString:@"file:///image4.tst"]];
   [item setSelected:NO];
   [doc addEntry:item];
   [doc addEntry:[[MyImageListItem alloc] initWithURL:
                                  [NSURL URLWithString:@"file:///image4.tst"]]];

   // Set the parameters in the list
   [[doc imageList] setProcessingParameter:listParams
                                   withRef:myImageAlignerParametersRef
                             forProcessing:myImageAlignerRef];

   // Register for doc notifications
   TestObserver *obs = [[TestObserver alloc] init];
   [[NSNotificationCenter defaultCenter] addObserver:obs
                                            selector:@selector(alignStarted:)
                                                name:
                                             LynkeosProcessStartedNotification
                                              object:doc];
   [[NSNotificationCenter defaultCenter] addObserver:obs
                                            selector:@selector(itemAligned:)
                                                name:
                                             LynkeosItemChangedNotification
                                              object:doc];
   [[NSNotificationCenter defaultCenter] addObserver:obs
                                            selector:@selector(alignEnded:)
                                                name:
                                             LynkeosProcessEndedNotification
                                              object:doc];

   obs->alignDone = NO;

   // Get an enumerator on the images
   NSEnumerator *strider =[[doc imageList] imageEnumeratorStartAt:nil
                                                       directSense:YES
                                                    skipUnselected:YES];

   // Ask the doc to align
   [doc startProcess:[MyImageAligner class] withEnumerator:strider
          parameters:listParams];

   // Wait for process end
   NSDate *timeout = [NSDate dateWithTimeIntervalSinceNow:2.0];
   while ( [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                    beforeDate:timeout]
           && [timeout compare:[NSDate date]] == NSOrderedDescending
           && ! obs->alignDone )
      ;

   // Verify the results
   XCTAssertTrue( obs->alignStarted, @"No notification of align start" );
   XCTAssertTrue( obs->alignDone, @"Align not performed after delay" );

   strider = [[doc imageList] imageEnumerator];

   // First item
   item = [strider nextObject];

   ItemAlignedFlag *alignFlag =
                          [item getProcessingParameterWithRef:K_ITEM_ALIGNED_REF
                                                forProcessing:nil];
   XCTAssertNotNil( alignFlag, @"No notification flag for item 0" );
   if ( alignFlag != nil )
      XCTAssertTrue( alignFlag->aligned, @"Bad notification flag state for item 0" );

   id <LynkeosAlignResult> res =
      (id <LynkeosAlignResult>)[item getProcessingParameterWithRef:
                                                         LynkeosAlignResultRef
                                                     forProcessing:
                                                        LynkeosAlignRef];
   XCTAssertNotNil( res, @"No alignment result for item 0" );
   if ( res != nil )
   {
      NSAffineTransformStruct m = [[res alignTransform] transformStruct];
      XCTAssertEqualWithAccuracy( (double)m.tX, 0.0, 1e-2,
                                  @"x item 0" );
      XCTAssertEqualWithAccuracy( (double)m.tY, 0.0, 1e-2,
                                  @"y item 0" );
   }

   // Second item
   item = [strider nextObject];

   alignFlag = [item getProcessingParameterWithRef:K_ITEM_ALIGNED_REF
                                     forProcessing:nil];
   XCTAssertNotNil( alignFlag, @"No notification flag for item 1" );
   if ( alignFlag != nil )
      XCTAssertTrue( alignFlag->aligned, @"Bad notification flag state for item 1" );

   res = (id <LynkeosAlignResult>)
                       [item getProcessingParameterWithRef:LynkeosAlignResultRef
                                             forProcessing:LynkeosAlignRef];
   XCTAssertNotNil( res, @"No alignment result for item 1" );
   if ( res != nil )
   {
      NSAffineTransformStruct m = [[res alignTransform] transformStruct];
      XCTAssertEqualWithAccuracy( (double)m.tX, -0.25, 1e-2,
                                  @"x item 1" );
      XCTAssertEqualWithAccuracy( (double)m.tY, 0.0, 1e-2,
                                  @"y item 1" );
   }

   // Third item
   item = [strider nextObject];

   alignFlag = [item getProcessingParameterWithRef:K_ITEM_ALIGNED_REF
                                     forProcessing:nil];
   XCTAssertNotNil( alignFlag, @"No notification flag for item 2" );
   if ( alignFlag != nil )
      XCTAssertTrue( alignFlag->aligned, @"Bad notification flag state for item 2" );

   res = (id <LynkeosAlignResult>)
                       [item getProcessingParameterWithRef:LynkeosAlignResultRef
                                             forProcessing:LynkeosAlignRef];
   XCTAssertNotNil( res, @"No alignment result for item 2" );
   if ( res != nil )
   {
      NSAffineTransformStruct m = [[res alignTransform] transformStruct];
      XCTAssertEqualWithAccuracy( (double)m.tX, 0.0, 1e-2,
                                  @"x item 2" );
      XCTAssertEqualWithAccuracy( (double)m.tY, 0.5, 1e-2,
                                  @"y item 2" );
   }

   // Fourth item (not selected)
   item = [strider nextObject];

   alignFlag = [item getProcessingParameterWithRef:K_ITEM_ALIGNED_REF
                                     forProcessing:nil];
   XCTAssertNil( alignFlag, @"No notification flag for item 3" );

   res = (id <LynkeosAlignResult>)
                       [item getProcessingParameterWithRef:LynkeosAlignResultRef
                                             forProcessing:LynkeosAlignRef];
   XCTAssertNil( res, @"Unexpected alignment result for item 3" );

   // Fifth and last item
   item = [strider nextObject];

   alignFlag = [item getProcessingParameterWithRef:K_ITEM_ALIGNED_REF
                                     forProcessing:nil];
   XCTAssertNotNil( alignFlag, @"No notification flag for item 4" );
   if ( alignFlag != nil )
      XCTAssertTrue( alignFlag->aligned, @"Bad notification flag state for item 4" );

   res = (id <LynkeosAlignResult>)
                       [item getProcessingParameterWithRef:LynkeosAlignResultRef
                                             forProcessing:LynkeosAlignRef];
   XCTAssertNotNil( res, @"No alignment result for item 4" );
   if ( res != nil )
   {
      NSAffineTransformStruct m = [[res alignTransform] transformStruct];
      XCTAssertEqualWithAccuracy( (double)m.tX, 1.0, 1e-2,
                                  @"x item 4" );
      XCTAssertEqualWithAccuracy( (double)m.tY, -1.0, 1e-2,
                                  @"y item 4" );
   }

   [[NSNotificationCenter defaultCenter] removeObserver:obs];
   [obs release];
   [doc release];
}

// Verify offset greater than half size
- (void) testSpuriousAlign
{
   // Create the document
   MyDocument *doc = [[MyDocument alloc] init];

   // Prepare the parameters
   MyImageAlignerListParametersV3 *listParams
                                = [[MyImageAlignerListParametersV3 alloc] init];
   listParams->_referenceItem = [[MyImageListItem alloc] initWithURL:
                                   [NSURL URLWithString:@"file:///image1.tst"]];
   MyImageAlignerSquareV3 *pt
      = [[[MyImageAlignerSquareV3 alloc] init] autorelease];
   pt->_alignOrigin = LynkeosMakeIntegerPoint(10,20);
   pt->_alignSize = LynkeosMakeIntegerSize(30,30);
   [listParams->_alignSquares addObject:pt];
   listParams->_cutoff = 0.707;
   listParams->_precisionThreshold = 0.125;
   listParams->_checkAlignResult = YES;

   // Add all the items to the document
   [doc addEntry:(MyImageListItem*)listParams->_referenceItem];
   [doc addEntry:[[MyImageListItem alloc] initWithURL:
                                  [NSURL URLWithString:@"file:///image5.tst"]]];
   [doc addEntry:[[MyImageListItem alloc] initWithURL:
                                  [NSURL URLWithString:@"file:///image6.tst"]]];
   [doc addEntry:[[MyImageListItem alloc] initWithURL:
                                  [NSURL URLWithString:@"file:///image7.tst"]]];

   // Set the parameters in the list
   [[doc imageList] setProcessingParameter:listParams
                                   withRef:myImageAlignerParametersRef
                             forProcessing:myImageAlignerRef];

   // Register for doc notifications
   TestObserver *obs = [[TestObserver alloc] init];
   [[NSNotificationCenter defaultCenter] addObserver:obs
                                            selector:@selector(alignStarted:)
                                                name:
                                               LynkeosProcessStartedNotification
                                              object:doc];
   [[NSNotificationCenter defaultCenter] addObserver:obs
                                            selector:@selector(itemAligned:)
                                                name:
                                                  LynkeosItemChangedNotification
                                              object:doc];
   [[NSNotificationCenter defaultCenter] addObserver:obs
                                            selector:@selector(alignEnded:)
                                                name:
                                                 LynkeosProcessEndedNotification
                                              object:doc];

   obs->alignDone = NO;

   // Get an enumerator on the images
   NSEnumerator *strider =[[doc imageList] imageEnumeratorStartAt:nil
                                                      directSense:YES
                                                   skipUnselected:YES];

   // Ask the doc to align
   [doc startProcess:[MyImageAligner class] withEnumerator:strider
          parameters:listParams];

   // Wait for process end
   NSDate *timeout = [NSDate dateWithTimeIntervalSinceNow:2.0];
   while ( [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                    beforeDate:timeout]
           && [timeout compare:[NSDate date]] == NSOrderedDescending
           && ! obs->alignDone )
      ;

   // Verify the results
   XCTAssertTrue( obs->alignStarted, @"No notification of align start" );
   XCTAssertTrue( obs->alignDone, @"Align not performed after delay" );

   strider = [[doc imageList] imageEnumerator];

   // First item
   MyImageListItem *item = [strider nextObject];

   ItemAlignedFlag *alignFlag =
      [item getProcessingParameterWithRef:K_ITEM_ALIGNED_REF
                            forProcessing:nil];
   XCTAssertNotNil( alignFlag, @"No notification flag for item 0" );
   if ( alignFlag != nil )
      XCTAssertTrue( alignFlag->aligned,
                    @"Bad notification flag state for item 0" );

   id <LynkeosAlignResult> res =
      (id <LynkeosAlignResult>)[item getProcessingParameterWithRef:
                                                         LynkeosAlignResultRef
                                                     forProcessing:
                                                             LynkeosAlignRef];
   XCTAssertNotNil( res, @"No alignment result for item 0" );
   if ( res != nil )
   {
      NSAffineTransformStruct m = [[res alignTransform] transformStruct];
      XCTAssertEqualWithAccuracy( (double)m.tX, 0.0, 1e-2,
                                  @"x item 0" );
      XCTAssertEqualWithAccuracy( (double)m.tY, 0.0, 1e-2,
                                  @"y item 0" );
   }

   // Second item
   item = [strider nextObject];

   alignFlag = [item getProcessingParameterWithRef:K_ITEM_ALIGNED_REF
                                     forProcessing:nil];
   XCTAssertNotNil( alignFlag, @"No notification flag for item 1" );
   if ( alignFlag != nil )
      XCTAssertTrue( alignFlag->aligned,
                    @"Bad notification flag state for item 1" );

   res = (id <LynkeosAlignResult>)
                       [item getProcessingParameterWithRef:LynkeosAlignResultRef
                                             forProcessing:LynkeosAlignRef];
   XCTAssertNotNil( res, @"No alignment result for item 1" );
   if ( res != nil )
   {
      NSAffineTransformStruct m = [[res alignTransform] transformStruct];
      XCTAssertEqualWithAccuracy( (double)m.tX, -20.0, 1e-2,
                                  @"x item 1" );
      XCTAssertEqualWithAccuracy( (double)m.tY, 20.0, 1e-2,
                                  @"y item 1" );
   }

   // Third item
   item = [strider nextObject];

   alignFlag = [item getProcessingParameterWithRef:K_ITEM_ALIGNED_REF
                                     forProcessing:nil];
   XCTAssertNotNil( alignFlag, @"No notification flag for item 2" );
   if ( alignFlag != nil )
      XCTAssertTrue( alignFlag->aligned,
                    @"Bad notification flag state for item 2" );

   res = (id <LynkeosAlignResult>)
                       [item getProcessingParameterWithRef:LynkeosAlignResultRef
                                             forProcessing:LynkeosAlignRef];
   XCTAssertNotNil( res, @"No alignment result for item 2" );
   if ( res != nil )
   {
      NSAffineTransformStruct m = [[res alignTransform] transformStruct];
      XCTAssertEqualWithAccuracy( (double)m.tX, 0.0, 1e-2,
                                  @"x item 2" );
      XCTAssertEqualWithAccuracy( (double)m.tY, 20.0, 1e-2,
                                  @"y item 2" );
   }

   // Fourth and last item
   item = [strider nextObject];

   alignFlag = [item getProcessingParameterWithRef:K_ITEM_ALIGNED_REF
                                     forProcessing:nil];
   XCTAssertNotNil( alignFlag, @"No notification flag for item 3" );
   if ( alignFlag != nil )
      XCTAssertTrue( alignFlag->aligned,
                    @"Bad notification flag state for item 3" );

   res = (id <LynkeosAlignResult>)
                       [item getProcessingParameterWithRef:LynkeosAlignResultRef
                                             forProcessing:LynkeosAlignRef];
   XCTAssertNotNil( res, @"No alignment result for item 3" );
   if ( res != nil )
   {
      NSAffineTransformStruct m = [[res alignTransform] transformStruct];
      XCTAssertEqualWithAccuracy( (double)m.tX, -20.0, 1e-2,
                                  @"x item 3" );
      XCTAssertEqualWithAccuracy( (double)m.tY, -0.0, 1e-2,
                                  @"y item 3" );
   }

   [[NSNotificationCenter defaultCenter] removeObserver:obs];
   [obs release];
   [doc release];
}

- (void) testAlign_rotate_2pt
{
   // Create the document
   MyDocument *doc = [[MyDocument alloc] init];

   // Prepare the parameters
   MyImageAlignerListParametersV3 *listParams =
   [[MyImageAlignerListParametersV3 alloc] init];
   listParams->_referenceItem = [[MyImageListItem alloc] initWithURL:
                                 [NSURL URLWithString:@"file:///image10.tst"]];
   MyImageAlignerSquareV3 *pt
      = [[[MyImageAlignerSquareV3 alloc] init] autorelease];
   pt->_alignOrigin = LynkeosMakeIntegerPoint(15,5);
   pt->_alignSize = LynkeosMakeIntegerSize(30,30);
   [listParams->_alignSquares addObject:pt];
   pt = [[[MyImageAlignerSquareV3 alloc] init] autorelease];
   pt->_alignOrigin = LynkeosMakeIntegerPoint(20,30);
   pt->_alignSize = LynkeosMakeIntegerSize(20,20);
   [listParams->_alignSquares addObject:pt];
   listParams->_cutoff = 0.707;
   listParams->_precisionThreshold = 0.125;
   listParams->_checkAlignResult = NO;
   listParams->_computeRotation = YES;
   listParams->_computeScale = YES;

   // Add all the items to the document
   [doc addEntry:(MyImageListItem*)listParams->_referenceItem];
   [doc addEntry:[[MyImageListItem alloc] initWithURL:
                  [NSURL URLWithString:@"file:///image11.tst"]]];

   // Set the parameters in the list
   [[doc imageList] setProcessingParameter:listParams
                                   withRef:myImageAlignerParametersRef
                             forProcessing:myImageAlignerRef];

   // Register for doc notifications
   TestObserver *obs = [[TestObserver alloc] init];
   [[NSNotificationCenter defaultCenter] addObserver:obs
                                            selector:@selector(alignStarted:)
                                                name:
    LynkeosProcessStartedNotification
                                              object:doc];
   [[NSNotificationCenter defaultCenter] addObserver:obs
                                            selector:@selector(itemAligned:)
                                                name:
    LynkeosItemChangedNotification
                                              object:doc];
   [[NSNotificationCenter defaultCenter] addObserver:obs
                                            selector:@selector(alignEnded:)
                                                name:
    LynkeosProcessEndedNotification
                                              object:doc];

   obs->alignDone = NO;

   // Get an enumerator on the images
   NSEnumerator *strider =[[doc imageList] imageEnumeratorStartAt:nil
                                                      directSense:YES
                                                   skipUnselected:YES];

   // Ask the doc to align
   [doc startProcess:[MyImageAligner class] withEnumerator:strider
          parameters:listParams];

   // Wait for process end
   NSDate *timeout = [NSDate dateWithTimeIntervalSinceNow:2.0];
   while ( [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                    beforeDate:timeout]
          && [timeout compare:[NSDate date]] == NSOrderedDescending
          && ! obs->alignDone )
      ;

   // Verify the results
   XCTAssertTrue( obs->alignStarted, @"No notification of align start" );
   XCTAssertTrue( obs->alignDone, @"Align not performed after delay" );

   strider = [[doc imageList] imageEnumerator];

   // First item
   MyImageListItem *item = [strider nextObject];

   ItemAlignedFlag *alignFlag =
   [item getProcessingParameterWithRef:K_ITEM_ALIGNED_REF
                         forProcessing:nil];
   XCTAssertNotNil( alignFlag, @"No notification flag for item 0" );
   if ( alignFlag != nil )
      XCTAssertTrue( alignFlag->aligned, @"Bad notification flag state for item 0" );

   id <LynkeosAlignResult> res =
   (id <LynkeosAlignResult>)[item getProcessingParameterWithRef:
                             LynkeosAlignResultRef
                                                  forProcessing:
                             LynkeosAlignRef];
   XCTAssertNotNil( res, @"No alignment result for item 0" );
   if ( res != nil )
   {
      NSAffineTransformStruct m = [[res alignTransform] transformStruct];
      XCTAssertEqualWithAccuracy( (double)m.m11, 1.0, 1e-3,
                                 @"m11 item 0" );
      XCTAssertEqualWithAccuracy( (double)m.m12, 0.0, 1e-3,
                                 @"m11 item 0" );
      XCTAssertEqualWithAccuracy( (double)m.m21, 0.0, 1e-3,
                                 @"m11 item 0" );
      XCTAssertEqualWithAccuracy( (double)m.m22, 1.0, 1e-3,
                                 @"m11 item 0" );
      XCTAssertEqualWithAccuracy( (double)m.tX, 0.0, 1e-2,
                                 @"tx item 0" );
      XCTAssertEqualWithAccuracy( (double)m.tY, 0.0, 1e-2,
                                 @"ty item 0" );
   }

   // Second item
   item = [strider nextObject];

   alignFlag = [item getProcessingParameterWithRef:K_ITEM_ALIGNED_REF
                                     forProcessing:nil];
   XCTAssertNotNil( alignFlag, @"No notification flag for item 1" );
   if ( alignFlag != nil )
      XCTAssertTrue( alignFlag->aligned, @"Bad notification flag state for item 1" );

   res = (id <LynkeosAlignResult>)
   [item getProcessingParameterWithRef:LynkeosAlignResultRef
                         forProcessing:LynkeosAlignRef];
   XCTAssertNotNil( res, @"No alignment result for item 1" );
   if ( res != nil )
   {
      NSAffineTransform *t = [res alignTransform];
      NSAffineTransformStruct m = [t transformStruct];
      XCTAssertEqualWithAccuracy( (double)m.m11, 0.8, 1e-3,
                                 @"m11 item 1" );
      XCTAssertEqualWithAccuracy( (double)m.m12, -0.6, 1e-3,
                                 @"m11 item 1" );
      XCTAssertEqualWithAccuracy( (double)m.m21, 0.6, 1e-3,
                                 @"m11 item 1" );
      XCTAssertEqualWithAccuracy( (double)m.m22, 0.8, 1e-3,
                                 @"m11 item 1" );
      XCTAssertEqualWithAccuracy( (double)m.tX, -18.0, 1e-3,
                                 @"tx item 1" );
      XCTAssertEqualWithAccuracy( (double)m.tY, 26.0, 1e-3,
                                 @"ty item 1" );

      // And check that the transform realigns correctly the stars
      u_long i;
      for (i = 0; i < sizeof(K_IMG10_STARS)/sizeof(NSPoint); i++)
      {
         const NSPoint realigned = [t transformPoint:K_IMG11_STARS[i]];
         XCTAssertEqualWithAccuracy(realigned.x, K_IMG10_STARS[i].x, 1e-3, @"Realigned star X");
         XCTAssertEqualWithAccuracy(realigned.y, K_IMG10_STARS[i].y, 1e-3, @"Realigned star Y");
      }
   }

   [[NSNotificationCenter defaultCenter] removeObserver:obs];
   [obs release];
   [doc release];
}

- (void) testAlign_rotate_scale_3pt
{
   // Create the document
   MyDocument *doc = [[MyDocument alloc] init];

   // Prepare the parameters
   MyImageAlignerListParametersV3 *listParams =
   [[MyImageAlignerListParametersV3 alloc] init];
   listParams->_referenceItem = [[MyImageListItem alloc] initWithURL:
                                 [NSURL URLWithString:@"file:///image12.tst"]];
   MyImageAlignerSquareV3 *pt
      = [[[MyImageAlignerSquareV3 alloc] init] autorelease];
   pt->_alignOrigin = LynkeosMakeIntegerPoint(20,30);
   pt->_alignSize = LynkeosMakeIntegerSize(20,20);
   [listParams->_alignSquares addObject:pt];
   pt = [[[MyImageAlignerSquareV3 alloc] init] autorelease];
   pt->_alignOrigin = LynkeosMakeIntegerPoint(10,10);
   pt->_alignSize = LynkeosMakeIntegerSize(20,20);
   [listParams->_alignSquares addObject:pt];
   pt = [[[MyImageAlignerSquareV3 alloc] init] autorelease];
   pt->_alignOrigin = LynkeosMakeIntegerPoint(30,10);
   pt->_alignSize = LynkeosMakeIntegerSize(20,20);
   [listParams->_alignSquares addObject:pt];
   listParams->_cutoff = 0.707;
   listParams->_precisionThreshold = 0.125;
   listParams->_checkAlignResult = NO;
   listParams->_computeRotation = YES;
   listParams->_computeScale = YES;

   // Add all the items to the document
   [doc addEntry:(MyImageListItem*)listParams->_referenceItem];
   [doc addEntry:[[MyImageListItem alloc] initWithURL:
                  [NSURL URLWithString:@"file:///image13.tst"]]];

   // Set the parameters in the list
   [[doc imageList] setProcessingParameter:listParams
                                   withRef:myImageAlignerParametersRef
                             forProcessing:myImageAlignerRef];

   // Register for doc notifications
   TestObserver *obs = [[TestObserver alloc] init];
   [[NSNotificationCenter defaultCenter] addObserver:obs
                                            selector:@selector(alignStarted:)
                                                name:
                                               LynkeosProcessStartedNotification
                                              object:doc];
   [[NSNotificationCenter defaultCenter] addObserver:obs
                                            selector:@selector(itemAligned:)
                                                name:
                                                  LynkeosItemChangedNotification
                                              object:doc];
   [[NSNotificationCenter defaultCenter] addObserver:obs
                                            selector:@selector(alignEnded:)
                                                name:
                                                 LynkeosProcessEndedNotification
                                              object:doc];

   obs->alignDone = NO;

   // Get an enumerator on the images
   NSEnumerator *strider =[[doc imageList] imageEnumeratorStartAt:nil
                                                      directSense:YES
                                                   skipUnselected:YES];

   // Ask the doc to align
   [doc startProcess:[MyImageAligner class] withEnumerator:strider
          parameters:listParams];

   // Wait for process end
   NSDate *timeout = [NSDate dateWithTimeIntervalSinceNow:2.0];
   while ( [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                    beforeDate:timeout]
          && [timeout compare:[NSDate date]] == NSOrderedDescending
          && ! obs->alignDone )
      ;

   // Verify the results
   XCTAssertTrue( obs->alignStarted, @"No notification of align start" );
   XCTAssertTrue( obs->alignDone, @"Align not performed after delay" );

   strider = [[doc imageList] imageEnumerator];

   // First item
   MyImageListItem *item = [strider nextObject];

   ItemAlignedFlag *alignFlag =
   [item getProcessingParameterWithRef:K_ITEM_ALIGNED_REF
                         forProcessing:nil];
   XCTAssertNotNil( alignFlag, @"No notification flag for item 0" );
   if ( alignFlag != nil )
      XCTAssertTrue( alignFlag->aligned, @"Bad notification flag state for item 0" );

   id <LynkeosAlignResult> res =
   (id <LynkeosAlignResult>)[item getProcessingParameterWithRef:
                             LynkeosAlignResultRef
                                                  forProcessing:
                             LynkeosAlignRef];
   XCTAssertNotNil( res, @"No alignment result for item 0" );
   if ( res != nil )
   {
      NSAffineTransformStruct m = [[res alignTransform] transformStruct];
      XCTAssertEqualWithAccuracy( (double)m.m11, 1.0, 1e-3,
                                 @"m11 item 0" );
      XCTAssertEqualWithAccuracy( (double)m.m12, 0.0, 1e-3,
                                 @"m11 item 0" );
      XCTAssertEqualWithAccuracy( (double)m.m21, 0.0, 1e-3,
                                 @"m11 item 0" );
      XCTAssertEqualWithAccuracy( (double)m.m22, 1.0, 1e-3,
                                 @"m11 item 0" );
      XCTAssertEqualWithAccuracy( (double)m.tX, 0.0, 1e-2,
                                 @"tx item 0" );
      XCTAssertEqualWithAccuracy( (double)m.tY, 0.0, 1e-2,
                                 @"ty item 0" );
   }

   // Second item
   item = [strider nextObject];

   alignFlag = [item getProcessingParameterWithRef:K_ITEM_ALIGNED_REF
                                     forProcessing:nil];
   XCTAssertNotNil( alignFlag, @"No notification flag for item 1" );
   if ( alignFlag != nil )
      XCTAssertTrue( alignFlag->aligned, @"Bad notification flag state for item 1" );

   res = (id <LynkeosAlignResult>)
   [item getProcessingParameterWithRef:LynkeosAlignResultRef
                         forProcessing:LynkeosAlignRef];
   XCTAssertNotNil( res, @"No alignment result for item 1" );
   if ( res != nil )
   {
      NSAffineTransform *t = [res alignTransform];
      NSAffineTransformStruct m = [t transformStruct];
      // Small uncertainties in alignment give larger errors in the rotation,
      // because the image is small
      XCTAssertEqualWithAccuracy( (double)m.m11, 0.82, 8e-2,
                                 @"m11 item 1" );
      XCTAssertEqualWithAccuracy( (double)m.m12, 0.17, 1e-2,
                                 @"m12 item 1" );
      XCTAssertEqualWithAccuracy( (double)m.m21, -0.17, 1e-2,
                                 @"m21 item 1" );
      XCTAssertEqualWithAccuracy( (double)m.m22, 0.82, 8e-2,
                                 @"m22 item 1" );
      XCTAssertEqualWithAccuracy( (double)m.tX, 8.8, 2.5e-1,
                                 @"tx item 1" );
      XCTAssertEqualWithAccuracy( (double)m.tY, -1.3, 2.5e-1,
                                 @"ty item 1" );

      // And check that the transform realigns correctly the stars
      u_long i;
      for (i = 0; i < sizeof(K_IMG12_STARS)/sizeof(NSPoint); i++)
      {
         const NSPoint realigned = [t transformPoint:K_IMG13_STARS[i]];
         XCTAssertEqualWithAccuracy(realigned.x, K_IMG12_STARS[i].x, 2.0e-1, @"Realigned star X");
         XCTAssertEqualWithAccuracy(realigned.y, K_IMG12_STARS[i].y, 2.0e-1, @"Realigned star Y");
      }
   }

   [[NSNotificationCenter defaultCenter] removeObserver:obs];
   [obs release];
   [doc release];
}
@end
