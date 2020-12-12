//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Thu Sep 7 2006.
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

#include "LynkeosImageBufferAdditions.h"
#include "MyPluginsController.h"
#include "LynkeosFileReader.h"
#include "MyImageListItem.h"

@interface MyImageListItemTest : XCTestCase
{
}
@end

BOOL pluginsInitialized = NO;

NSString *basePath = nil;

// ============================================================================
// The reader that the item under test will use
@interface TestReader : NSObject <LynkeosImageFileReader>
{
   LynkeosImageBuffer *buf;
}
// Test specific method
@end

@implementation TestReader
+ (void) load {}

+ (void) lynkeosFileTypes:(NSArray**)fileTypes
{ *fileTypes = [NSArray arrayWithObject:@"tsturl"]; }

- (id) initWithURL:(NSURL*)url
{
   u_short x, y, w = 0, h = 0, n = 0;
   int kind;

   if ( [[url path] isEqual:@"1.tsturl"] )
   {
      kind = 1;
      w = 31;
      h = 19;
      n = 3;
   }
   else if ( [[url path] isEqual:@"2.tsturl"] )
   {
      kind = 2;
      w = 30;
      h = 20;
      n = 1;
   }
   else
      NSAssert( NO, @"Inconsistent image kind" );

   buf = [[LynkeosImageBuffer imageBufferWithNumberOfPlanes:n
                                                              width:w
                                                             height:h] retain];

   for( y = 0; y < buf->_h; y++ )
   {
      for( x = 0; x < buf->_w; x++ )
      {
         switch ( kind )
         {
            case 1:
               colorValue(buf,x,y,0) = x/31.0;
               colorValue(buf,x,y,1) = y/19.0;
               colorValue(buf,x,y,2) = ((x+y)%10)/10.0;
               break;
            case 2:
               if ( x == 15 && y == 10 )
                  colorValue(buf,x,y,0) = 1.0;
               else
                  colorValue(buf,x,y,0) = 0.0;
               break;
         }
      }
   }

   return( self );
}

- (void) imageWidth:(u_short*)w height:(u_short*)h
{ *w = buf->_w; *h = buf->_h; }

- (u_short) numberOfPlanes { return( buf->_nPlanes ); }

- (void) getMinLevel:(double*)vmin maxLevel:(double*)vmax
{
   *vmin = 0.0;
   *vmax = 1.0;
}

- (NSDictionary*) getMetaData { return nil; }

- (NSImage*) getNSImage
{
   double black[] = {0.0, 0.0, 0.0, 0.0 },
          white[] = {1.0, 1.0, 1.0, 1.0},
          gamma[] = {1.0, 1.0, 1.0, 1.0};

   CGImageRef img = [buf getImageInRect:LynkeosMakeIntegerRect(0, 0, buf->_w, buf->_h)
                              withBlack:black white:white gamma:gamma];
   NSImage *nsImg = [[[NSImage alloc] initWithCGImage:img size:NSZeroSize] autorelease];
   CGImageRelease(img);

   return nsImg;
}

- (void) getImageSample:(REAL * const * const)sample 
             withPlanes:(u_short)nPlanes
                    atX:(u_short)x Y:(u_short)y W:(u_short)w H:(u_short)h
              lineWidth:(u_short)lineW
{
   NSAssert4( x < buf->_w && x+w <= buf->_w && y < buf->_h && y+h <= buf->_h,
                 @"Rectangle outside the image {%d,%d,%d,%d}",
                 x, y, w, h );
   [buf extractSample:sample atX:x Y:y withWidth:w height:h
           withPlanes:nPlanes lineWidth:lineW];
}

@end

// A fake cache prefs class
@interface MyCachePrefs : NSObject
@end

@implementation MyCachePrefs
@end

// ============================================================================
// The tests
@implementation MyImageListItemTest

+ (void) initialize
{
   // Create the plugins controller singleton, and initialize it
   // Only if not already done by another test class
   if ( !pluginsInitialized )
   {
      [[[MyPluginsController alloc] init] awakeFromNib];
      pluginsInitialized = YES;
   }
}

- (void) testSimpleRead
{
   // Create an item
   MyImageListItem *item = [MyImageListItem imageListItemWithURL:
                                             [NSURL URLWithString:@"1.tsturl"]];

   // Read a sample
   LynkeosImageBuffer *testBuf = nil;
   [item getImageSample:&testBuf inRect:LynkeosMakeIntegerRect(10,5,10,10)];

   XCTAssertNotNil( testBuf, @"Test image not read" );

   u_short x, y;
   for( y = 0; y < 5; y++ )
   {
      for( x = 0; x < 10; x++ )
      {
         XCTAssertEqualWithAccuracy((double)colorValue(testBuf,x,y,0),
                                    (x+10)/31.0,1e-5,
                                    @"red at %d,%d", x, y );
         XCTAssertEqualWithAccuracy((double)colorValue(testBuf,x,y,1),
                                    (y+5)/19.0, 1e-5,
                                    @"green at %d,%d", x, y );
         XCTAssertEqualWithAccuracy((double)colorValue(testBuf,x,y,2),
                                    ((x+y+15)%10)/10.0,1e-5,
                                    @"blue at %d,%d", x, y );
      }
   }  
}

- (void) testReadOutside
{
   // Create an item
   MyImageListItem *item = [MyImageListItem imageListItemWithURL:
                                             [NSURL URLWithString:@"1.tsturl"]];

   // Read a sample enclosing the image
   LynkeosImageBuffer *testBuf = nil;
   [item getImageSample:&testBuf inRect:LynkeosMakeIntegerRect(-5,-4,40,30)];

   XCTAssertNotNil( testBuf, @"Test image not read" );

   u_short x, y;
   for( y = 0; y < 30; y++ )
   {
      for( x = 0; x < 40; x++ )
      {
         if ( (x >= 5 && x < 36) && (y >= 4 && y < 23) )
         {
            XCTAssertEqualWithAccuracy((double)colorValue(testBuf,x,y,0),
                                       (x-5)/31.0,1e-5,
                                       @"red at %d,%d", x, y );
            XCTAssertEqualWithAccuracy((double)colorValue(testBuf,x,y,1),
                                       (y-4)/19.0, 1e-5,
                                       @"green at %d,%d", x, y );
            XCTAssertEqualWithAccuracy((double)colorValue(testBuf,x,y,2),
                                       ((x+y-9)%10)/10.0,1e-5,
                                       @"blue at %d,%d", x, y );
         }
         else
         {
            XCTAssertEqual( (double)colorValue(testBuf,x,y,0), 0.0,
                            @"red at %d,%d", x, y );
            XCTAssertEqual( (double)colorValue(testBuf,x,y,1), 0.0,
                            @"green at %d,%d", x, y );
            XCTAssertEqual( (double)colorValue(testBuf,x,y,2), 0.0,
                            @"blue at %d,%d", x, y );
         }
      }
   }  
}

// Test for a bug discovered in V2
- (void) testReadDisjoint
{
   // Create an item
   MyImageListItem *item = [MyImageListItem imageListItemWithURL:
                                             [NSURL URLWithString:@"1.tsturl"]];

   // Read samples totally outside the image
   short ox, oy;
   for( oy = -50 ; oy <= 50; oy += 50 )
   {
      for( ox = -40; ox <= 40; ox += 40 )
      {
         if ( ox == 0 && oy == 0 )
            continue;

         LynkeosImageBuffer *testBuf = nil;
         [item getImageSample:&testBuf inRect:LynkeosMakeIntegerRect(ox,oy,40,30)];

         XCTAssertNotNil( testBuf, @"Test image not read" );

         u_short x, y, c;
         for( c = 0; c < 3; c++ )
            for( y = 0; y < 30; y++ )
               for( x = 0; x < 40; x++ )
                  XCTAssertEqualWithAccuracy((double)colorValue(testBuf,x,y,c),
                                             0.0,1e-5,
                                             @"color %d at %d,%d", c, x, y );
      }
   }  
}

- (void) testMonochromeRead
{
   // Create an item
   MyImageListItem *item = [MyImageListItem imageListItemWithURL:
                                             [NSURL URLWithString:@"1.tsturl"]];

   // Read a sample
   LynkeosImageBuffer *testBuf = [LynkeosImageBuffer imageBufferWithNumberOfPlanes:1
                                                                   width:10
                                                                  height:10];
   [item getImageSample:&testBuf inRect:LynkeosMakeIntegerRect(10,5,10,10)];

   XCTAssertNotNil( testBuf, @"Test image not read" );

   u_short x, y;
   for( y = 0; y < 5; y++ )
   {
      for( x = 0; x < 10; x++ )
      {
         XCTAssertEqualWithAccuracy((double)colorValue(testBuf,x,y,0),
                                    (x+10)/93.0+(y+5)/57.0+((x+y+15)%10)/30.0,
                                    1e-5,
                                    @"monochrome at %d,%d", x, y );
      }
   }  
}

- (void) testCalibratedRead
{
   // Create an item
   MyImageListItem *item = [MyImageListItem imageListItemWithURL:
                                             [NSURL URLWithString:@"1.tsturl"]];
   // And calibration frames
   LynkeosImageBuffer *dark = [LynkeosImageBuffer imageBufferWithNumberOfPlanes:3
                                                                width:31
                                                               height:19];
   LynkeosImageBuffer *flat = [LynkeosImageBuffer imageBufferWithNumberOfPlanes:3
                                                                width:31
                                                               height:19];
   u_short x, y;

   // Fill the calibration frames
   // Dark frame doubles the "glide" and adds an offset
   for( y = 0; y < 19; y++ )
   {
      for( x = 0; x < 31; x++ )
      {
         colorValue(dark,x,y,0) = -1.0-x/31.0;
         colorValue(dark,x,y,1) = -1.0-y/19.0;
         colorValue(dark,x,y,2) = -1.0-((x+y)%10)/10.0;
      }
   }
   // Flat field makes the result a uniform 3
   for( y = 0; y < 19; y++ )
   {
      for( x = 0; x < 31; x++ )
      {
         colorValue(flat,x,y,0) = (1.0+2.0*x/31.0)/3.0;
         colorValue(flat,x,y,1) = (1.0+2.0*y/19.0)/3.0;
         colorValue(flat,x,y,2) = (1.0+2.0*((x+y)%10)/10.0)/3.0;
      }
   }

   // Attach the calibration frames to the item
   [item setProcessingParameter:dark withRef:myImageListItemDarkFrame
                  forProcessing:nil];
   [item setProcessingParameter:flat withRef:myImageListItemFlatField
                  forProcessing:nil];

   // Read a sample
   LynkeosImageBuffer *testBuf = nil;
   [item getImageSample:&testBuf inRect:LynkeosMakeIntegerRect(10,5,10,10)];

   XCTAssertNotNil( testBuf, @"Test image not read" );

   for( y = 0; y < 5; y++ )
   {
      for( x = 0; x < 10; x++ )
      {
         XCTAssertEqualWithAccuracy((double)colorValue(testBuf,x,y,0),
                                    3.0,1e-5,
                                    @"red at %d,%d", x, y );
         XCTAssertEqualWithAccuracy((double)colorValue(testBuf,x,y,1),
                                    3.0, 1e-5,
                                    @"green at %d,%d", x, y );
         XCTAssertEqualWithAccuracy((double)colorValue(testBuf,x,y,2),
                                    3.0,1e-5,
                                    @"blue at %d,%d", x, y );
      }
   }  
}

- (void) testModifiedItem
{
   // Create an item
   MyImageListItem *item = [MyImageListItem imageListItemWithURL:
                                             [NSURL URLWithString:@"1.tsturl"]];
   // And an image
   LynkeosImageBuffer *image = [LynkeosImageBuffer imageBufferWithNumberOfPlanes:3
                                                                 width:31
                                                                height:19];
   u_short x, y;

   // Fill the image
   for( y = 0; y < 19; y++ )
   {
      for( x = 0; x < 31; x++ )
      {
         colorValue(image,x,y,0) = (30-x)/31.0;
         colorValue(image,x,y,1) = (18-y)/19.0;
         colorValue(image,x,y,2) = ((48-x-y)%10)/10.0;
      }
   }

   // Set the image as the item modified image
   [item setImage:image];

   // Read a sample
   LynkeosImageBuffer *testBuf = nil;
   [item getImageSample:&testBuf inRect:LynkeosMakeIntegerRect(10,5,10,10)];

   XCTAssertNotNil( testBuf, @"Test image not read" );

   for( y = 0; y < 5; y++ )
   {
      for( x = 0; x < 10; x++ )
      {
         XCTAssertEqualWithAccuracy((double)colorValue(testBuf,x,y,0),
                                    (20-x)/31.0,1e-5,
                                    @"red at %d,%d", x, y );
         XCTAssertEqualWithAccuracy((double)colorValue(testBuf,x,y,1),
                                    (13-y)/19.0, 1e-5,
                                    @"green at %d,%d", x, y );
         XCTAssertEqualWithAccuracy((double)colorValue(testBuf,x,y,2),
                                    ((33-x-y)%10)/10.0,1e-5,
                                    @"blue at %d,%d", x, y );
      }
   }

   // Revert the item to "original"
   [item revertToOriginal];

   // Read again the sample
   testBuf = nil;
   [item getImageSample:&testBuf inRect:LynkeosMakeIntegerRect(10,5,10,10)];

   XCTAssertNotNil( testBuf, @"Test image not read" );

   for( y = 0; y < 5; y++ )
   {
      for( x = 0; x < 10; x++ )
      {
         XCTAssertEqualWithAccuracy((double)colorValue(testBuf,x,y,0),
                                    (x+10)/31.0,1e-5,
                                    @"red at %d,%d", x, y );
         XCTAssertEqualWithAccuracy((double)colorValue(testBuf,x,y,1),
                                    (y+5)/19.0, 1e-5,
                                    @"green at %d,%d", x, y );
         XCTAssertEqualWithAccuracy((double)colorValue(testBuf,x,y,2),
                                    ((x+y+15)%10)/10.0,1e-5,
                                    @"blue at %d,%d", x, y );
      }
   }  
}

- (void) testShift0Plane1
{
   NSAffineTransformStruct t = {2.0, 0.0, 0.0, 2.0, 0.0, 0.0};
   LynkeosIntegerRect r = {{0.0, 0.0}, {60.0, 40.0}};
   u_short x, y;
   MyImageListItem *item
      = [[[MyImageListItem alloc] initWithURL:[NSURL URLWithString:@"2.tsturl"]]
         autorelease];
   LynkeosImageBuffer *image1 = nil;
   LynkeosImageBuffer *image2
      = [LynkeosImageBuffer imageBufferWithNumberOfPlanes:1
                                                       width:r.size.width
                                                      height:r.size.height];

   // Prepare the test images
   [item getImageSample:&image1 inRect:r withTransform:t withOffsets:NULL];
   for( y = 0; y < 40; y++ )
   {
      for( x = 0; x < 60; x++ )
      {
         if ( x == 30 && y == 20 )
            colorValue(image2,x,y,0) = 1.0;
         else
            colorValue(image2,x,y,0) = 0.0;
      }
   }

   [image2 add:image1];

   for( y = 0; y < 40; y++ )
   {
      for( x = 0; x < 60; x++ )
      {
         double v = colorValue(image2,x,y,0);

         if ( x == 30 && y == 20 )
            XCTAssertEqualWithAccuracy( v, 2.0, 1e-5,
                                       @"at %d,%d", x, y );
         else if ( (y == 20 || y == 21) &&
                  (x == 30 || x == 31) )
            XCTAssertEqualWithAccuracy( v, 1.0, 1e-5,
                                       @"at %d,%d", x, y );
         else
            XCTAssertEqualWithAccuracy( v, 0.0, 1e-5,
                                       @"at %d,%d", x, y );
      }
   }
}

- (void) testShiftM05Plane1
{
   NSAffineTransformStruct t = {2.0, 0.0, 0.0, 2.0, -0.5, -0.5};
   LynkeosIntegerRect r = {{0.0, 0.0}, {60.0, 40.0}};
   u_short x, y;
   MyImageListItem *item
   = [[[MyImageListItem alloc] initWithURL:[NSURL URLWithString:@"2.tsturl"]]
      autorelease];
   LynkeosImageBuffer *image1 = nil;
   LynkeosImageBuffer *image2
   = [LynkeosImageBuffer imageBufferWithNumberOfPlanes:1
                                                         width:r.size.width
                                                        height:r.size.height];

   // Prepare the test images
   [item getImageSample:&image1 inRect:r withTransform:t withOffsets:NULL];
   for( y = 0; y < 40; y++ )
   {
      for( x = 0; x < 60; x++ )
      {
         if ( x == 30 && y == 20 )
            colorValue(image2,x,y,0) = 1.0;
         else
            colorValue(image2,x,y,0) = 0.0;
      }
   }

   [image2 add:image1];

   for( y = 0; y < 40; y++ )
   {
      for( x = 0; x < 60; x++ )
      {
         double v = colorValue(image2,x,y,0);

         if ( (x == 29 || x == 31) && (y == 19 || y == 21) )
            XCTAssertEqualWithAccuracy( v, 0.25, 1e-5,
                                       @"at %d,%d", x, y );
         else if ( (x == 30 && (y == 19 || y == 21)) ||
                  (y == 20 && (x == 29 || x == 31)) )
            XCTAssertEqualWithAccuracy( v, 0.5, 1e-5,
                                       @"at %d,%d", x, y );
         else if ( x == 30 && y == 20 )
            XCTAssertEqualWithAccuracy( v, 2.0, 1e-5,
                                       @"at %d,%d", x, y );
         else
            XCTAssertEqualWithAccuracy( v, 0.0, 1e-5,
                                       @"at %d,%d", x, y );
      }
   }
}

- (void) testShift125Plane1
{
   NSAffineTransformStruct t = {2.0, 0.0, 0.0, 2.0, 1.25, 1.25};
   LynkeosIntegerRect r = {{0.0, 0.0}, {60.0, 40.0}};
   u_short x, y;
   MyImageListItem *item
      = [[[MyImageListItem alloc] initWithURL:[NSURL URLWithString:@"2.tsturl"]]
         autorelease];
   LynkeosImageBuffer *image1 = nil;
   LynkeosImageBuffer *image2
      = [LynkeosImageBuffer imageBufferWithNumberOfPlanes:1
                                                            width:r.size.width
                                                          height:r.size.height];

   // Prepare the test images
   [item getImageSample:&image1 inRect:r withTransform:t withOffsets:NULL];
   for( y = 0; y < 40; y++ )
   {
      for( x = 0; x < 60; x++ )
      {
         if ( x == 30 && y == 20 )
            colorValue(image2,x,y,0) = 1.0;
         else
            colorValue(image2,x,y,0) = 0.0;
      }
   }

   [image2 add:image1];

   for( y = 0; y < 40; y++ )
   {
      for( x = 0; x < 60; x++ )
      {
         double v = colorValue(image2,x,y,0);

         if ( (x == 30 && y == 20) || (x == 32 && y == 22) )
            XCTAssertEqualWithAccuracy( v, 1.0, 1e-5,
                                       @"at %d,%d", x, y );
         else if ( (x == 31 && y == 22) || (x == 32 && y == 21) )
            XCTAssertEqualWithAccuracy( v, 0.75, 1e-5,
                                       @"at %d,%d", x, y );
         else if ( (x == 31 && y == 23) || (x == 33 && y == 21) )
            XCTAssertEqualWithAccuracy( v, 0.1875, 1e-5,
                                       @"at %d,%d", x, y );
         else if ( (x == 32 && y == 23) || (x == 33 && y == 22) )
            XCTAssertEqualWithAccuracy( v, 0.25, 1e-5,
                                       @"at %d,%d", x, y );
         else if ( x == 31 && y == 21 )
            XCTAssertEqualWithAccuracy( v, 0.5625, 1e-5,
                                       @"at %d,%d", x, y );
         else if ( x == 33 && y == 23 )
            XCTAssertEqualWithAccuracy( v, 0.0625, 1e-5,
                                       @"at %d,%d", x, y );
         else
            XCTAssertEqualWithAccuracy( v, 0.0, 1e-5,  
                                       @"at %d,%d", x, y );
      }
   }
}

@end
