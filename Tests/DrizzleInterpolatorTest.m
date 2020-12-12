//
//  Lynkeos
//  $Id:$
//
//  Created by Jean-Etienne LAMIAUD on Wed Nov 5 2014.
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

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#include "ProcessTestUtilities.h"

#include "LynkeosDrizzleInterpolator.h"
#include "LynkeosImageBuffer.h"
#include "LynkeosImageBufferAdditions.h"
#include "MyImageListItem.h"

static LynkeosImageBuffer *sourceImage = nil;

@interface DrizzleInterpolatorTest : XCTestCase
{
   LynkeosImageBuffer *_img;
   LynkeosIntegerRect _r;
}
@end

@implementation InterpolatorTestReader
+ (void) lynkeosFileTypes:(NSArray**)fileTypes
{
   *fileTypes = [NSArray arrayWithObject:@"itptst"];
}

- (id) initWithURL:(NSURL*)url
{
   self = [self init];

   return( self );
}

- (u_short) numberOfPlanes
{
   return( [sourceImage numberOfPlanes] );
}

- (void) getMinLevel:(double*)vmin maxLevel:(double*)vmax
{
   *vmin = 0.0;
   *vmax = 255.0;
}

- (void) imageWidth:(u_short*)w height:(u_short*)h
{
   *w = [sourceImage width];
   *h = [sourceImage height];
}

- (NSDictionary*) getMetaData { return( nil ); }

- (NSImage*) getNSImage{ return( nil ); }

- (void) getImageSample:(REAL * const * const)sample
             withPlanes:(u_short)nPlanes
                    atX:(u_short)x Y:(u_short)y W:(u_short)w H:(u_short)h
              lineWidth:(u_short)lineW ;
{
   [sourceImage extractSample:sample
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

+ (void) setImage:(LynkeosImageBuffer*)image
{
   sourceImage = image;
}
@end

@implementation DrizzleInterpolatorTest

+ (void) initialize
{
   initializeProcessTests();
}

- (void)setUp
{
   [super setUp];

   // This method is called before the invocation of each test method in the class.

   // Create an image
   int i;
   _img = [[LynkeosImageBuffer alloc] initWithNumberOfPlanes:1
                                                              width:30
                                                             height:30];
   _r = LynkeosMakeIntegerRect(10, 10, 4, 4);
   for ( i = 0; i < 16; i++ )
      colorValue( _img, (i%_r.size.width) + _r.origin.x,
                        i/_r.size.height + _r.origin.y, 0) = (REAL)i;
}

- (void)tearDown
{
   // This method is called after the invocation of each test method in the class.

   // Get rid of the interpolator
   // And the image
   [_img release];

   [super tearDown];
}

- (void)testTranlate_0_5
{
   // Create the interpolator
   NSAffineTransformStruct t = {1.0, 0.0, 0.0, 1.0, 0.5, 0.5};
   LynkeosDrizzleInterpolator *interp
      = [[[LynkeosDrizzleInterpolator alloc] initWithImage:_img
                                                    inRect:_r
                                        withNumberOfPlanes:1
                                              withTranform:t
                                               withOffsets:nil
                                            withParameters:nil]
         autorelease];

   // Test the interpolator
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:0 atY:0],
                              0.0, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:1 atY:0],
                              0.25, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:2 atY:0],
                              0.75, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:3 atY:0],
                              1.25, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:0 atY:1],
                              1.0, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:1 atY:1],
                              2.5, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:2 atY:1],
                              3.5, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:3 atY:1],
                              4.5, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:0 atY:2],
                              3.0, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:1 atY:2],
                              6.5, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:2 atY:2],
                              7.5, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:3 atY:2],
                              8.5, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:0 atY:3],
                              5.0, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:1 atY:3],
                              10.5, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:2 atY:3],
                              11.5, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:3 atY:3],
                              12.5, 1e-6);
}

- (void)testTranlate_0_25_0_75
{
   // Create the interpolator
   NSAffineTransformStruct t = {1.0, 0.0, 0.0, 1.0, 0.25, 0.75};
   LynkeosDrizzleInterpolator *interp
      = [[[LynkeosDrizzleInterpolator alloc] initWithImage:_img
                                                    inRect:_r
                                        withNumberOfPlanes:1
                                              withTranform:t
                                               withOffsets:nil
                                            withParameters:nil]
      autorelease];

   // Test the interpolator
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:0 atY:0],
                              0.0, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:1 atY:0],
                              0.1875, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:2 atY:0],
                              0.4375, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:3 atY:0],
                              0.6875, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:0 atY:1],
                              0.75, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:1 atY:1],
                              1.75, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:2 atY:1],
                              2.75, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:3 atY:1],
                              3.75, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:0 atY:2],
                              3.75, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:1 atY:2],
                              5.75, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:2 atY:2],
                              6.75, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:3 atY:2],
                              7.75, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:0 atY:3],
                              6.75, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:1 atY:3],
                              9.75, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:2 atY:3],
                              10.75, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:3 atY:3],
                              11.75, 1e-6);
}

- (void)testTranlate_m0_25_m0_75_Scale_2
{
   // Create the interpolator (translation is scaled)
   NSAffineTransformStruct t = {2.0, 0.0, 0.0, 2.0, -0.5, -1.5};
   // Rectangle is also scaled
   _r.origin.x = 20;
   _r.origin.y = 20;
   LynkeosDrizzleInterpolator *interp
      = [[[LynkeosDrizzleInterpolator alloc] initWithImage:_img
                                                    inRect:_r
                                        withNumberOfPlanes:1
                                              withTranform:t
                                               withOffsets:nil
                                            withParameters:nil]
         autorelease];

   // Test the interpolator
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:0 atY:0],
                              2.0, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:1 atY:0],
                              2.5, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:2 atY:0],
                              3.0, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:3 atY:0],
                              3.5, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:0 atY:1],
                              4.0, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:1 atY:1],
                              4.5, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:2 atY:1],
                              5.0, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:3 atY:1],
                              5.5, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:0 atY:2],
                              6.0, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:1 atY:2],
                              6.5, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:2 atY:2],
                              7.0, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:3 atY:2],
                              7.5, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:0 atY:3],
                              8.0, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:1 atY:3],
                              8.5, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:2 atY:3],
                              9.0, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:3 atY:3],
                              9.5, 1e-6);
}

- (void)testVectorTranlate_m0_25_m0_75_Scale_2
{
   // Create the interpolator
   NSAffineTransformStruct t = {2.0, 0.0, 0.0, 2.0, -0.5, -1.5};
   _r.origin.x = 20;
   _r.origin.y = 20;
   LynkeosDrizzleInterpolator *interp
      = [[[LynkeosDrizzleInterpolator alloc] initWithImage:_img
                                                    inRect:_r
                                        withNumberOfPlanes:1
                                              withTranform:t
                                               withOffsets:nil
                                            withParameters:nil]
         autorelease];
   REALVECT v;

   // Test the interpolator
   v = [interp interpolateVectInPLane:0 atX:0 atY:0];
   XCTAssertEqualWithAccuracy(v[0], 2.0, 1e-6);
   XCTAssertEqualWithAccuracy(v[1], 2.5, 1e-6);
   XCTAssertEqualWithAccuracy(v[2], 3.0, 1e-6);
   XCTAssertEqualWithAccuracy(v[3], 3.5, 1e-6);
   v = [interp interpolateVectInPLane:0 atX:0 atY:1];
   XCTAssertEqualWithAccuracy(v[0], 4.0, 1e-6);
   XCTAssertEqualWithAccuracy(v[1], 4.5, 1e-6);
   XCTAssertEqualWithAccuracy(v[2], 5.0, 1e-6);
   XCTAssertEqualWithAccuracy(v[3], 5.5, 1e-6);
   v = [interp interpolateVectInPLane:0 atX:0 atY:2];
   XCTAssertEqualWithAccuracy(v[0], 6.0, 1e-6);
   XCTAssertEqualWithAccuracy(v[1], 6.5, 1e-6);
   XCTAssertEqualWithAccuracy(v[2], 7.0, 1e-6);
   XCTAssertEqualWithAccuracy(v[3], 7.5, 1e-6);
   v = [interp interpolateVectInPLane:0 atX:0 atY:3];
   XCTAssertEqualWithAccuracy(v[0], 8.0, 1e-6);
   XCTAssertEqualWithAccuracy(v[1], 8.5, 1e-6);
   XCTAssertEqualWithAccuracy(v[2], 9.0, 1e-6);
   XCTAssertEqualWithAccuracy(v[3], 9.5, 1e-6);
}

- (void)testItemTranlate_m0_25_m0_75_Scale_2
{
   // Create an item from the image
   [InterpolatorTestReader setImage: _img];
   MyImageListItem *item
      = [[[MyImageListItem alloc] initWithURL:[NSURL URLWithString:
                                           @"file:///image01.itptst"]]
          autorelease];
   // Create the interpolator (translation is scaled)
   NSAffineTransformStruct t = {2.0, 0.0, 0.0, 2.0, -0.5, -1.5};
   // Rectangle is also scaled
   _r.origin.x = 20;
   _r.origin.y = 20;
   LynkeosDrizzleInterpolator *interp
   = [[[LynkeosDrizzleInterpolator alloc] initWithItem:item
                                                 inRect:_r
                                     withNumberOfPlanes:1
                                           withTranform:t
                                            withOffsets:nil
                                              withParameters:nil]
      autorelease];

   // Test the interpolator
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:0 atY:0],
                              2.0, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:1 atY:0],
                              2.5, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:2 atY:0],
                              3.0, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:3 atY:0],
                              3.5, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:0 atY:1],
                              4.0, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:1 atY:1],
                              4.5, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:2 atY:1],
                              5.0, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:3 atY:1],
                              5.5, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:0 atY:2],
                              6.0, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:1 atY:2],
                              6.5, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:2 atY:2],
                              7.0, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:3 atY:2],
                              7.5, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:0 atY:3],
                              8.0, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:1 atY:3],
                              8.5, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:2 atY:3],
                              9.0, 1e-6);
   XCTAssertEqualWithAccuracy([interp interpolateInPLane:0 atX:3 atY:3],
                              9.5, 1e-6);
}
@end
