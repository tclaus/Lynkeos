//
//  Lynkeos
//  $Id:$
//
//  Created by Jean-Etienne LAMIAUD on Fri Sep 21 2018.
//  Copyright (c) 2018-2020. Jean-Etienne LAMIAUD
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

#include "LynkeosImageBuffer.h"
#include "LynkeosLanczosInterpolator.h"

@interface LanczosInterpolatorTest : XCTestCase
{
   LynkeosLanczosInterpolator *_interpol;
   NSAffineTransform          *_transform;
   LynkeosIntegerRect          _rect;
}
@end

static void fillImage( LynkeosImageBuffer *img, TestImagePolynomial *poly )
{
   u_short x, y;

   for (y = 0; y < img->_h; y++)
   {
      for (x = 0; x < img->_w; x++)
      {
         stdColorValue(img, x, y, 0) = [poly valueAtPoint:CGPointMake((CGFloat)x, (CGFloat)y)];
      }
   }
}

// Assumption is that a Lanczos interpolator is able to approximate a second degree polynomial
@implementation LanczosInterpolatorTest

+ (void) initialize
{
   initializeProcessTests();
}

- (void)setUp
{
   [super setUp];
   _interpol = nil;
   _transform = nil;
   _rect = LynkeosMakeIntegerRect(0, 0, 0, 0);
}

- (void)tearDown
{
   // This method is called after the invocation of each test method in the class.
   [super tearDown];
}

- (void) checkInterpolationWithPolynomial:(TestImagePolynomial*)poly
{
   NSAffineTransform *inverse = [[NSAffineTransform alloc] initWithTransform:_transform];
   [inverse invert];
   u_short x, y;

   // For upscaling, verify that interpolation on "source" points is equal to the value on that point
   NSAffineTransformStruct ts = [_transform transformStruct];
   if (ts.m11*ts.m22 - ts.m12*ts.m21 >= 1.0)
   {
      NSPoint oldPoint = {-HUGE, -HUGE};
      for (y = 0; y < _rect.size.height; y++)
      {
         for (x = 0; x < _rect.size.width; x++)
         {
            // Get the closest integer point in the source image
            NSPoint dstP = {(CGFloat)(x + _rect.origin.x), (CGFloat)(y + _rect.origin.y)};
            NSPoint srcP = [inverse transformPoint:dstP];
            srcP = NSMakePoint(floor(srcP.x + 0.5), floor(srcP.y + 0.5));
            dstP = [_transform transformPoint:srcP];
            dstP.x -= (CGFloat)_rect.origin.x;
            dstP.y -= (CGFloat)_rect.origin.y;

            if (srcP.x != oldPoint.x || srcP.y != oldPoint.y)
            {
               oldPoint = srcP;
               const double interpolated = [_interpol interpolateInPLane:0 atX:dstP.x atY:dstP.y];
               const double original = [poly valueAtPoint:srcP];
               XCTAssertEqualWithAccuracy(interpolated, original, 0.01,
                                          @"Changed value at origin point x=%.0f y=%.0f", srcP.x, srcP.y);
            }
         }
      }
   }

   // Verify that the interpolator reconstructs the polynomial image in between
   for (y = 0; y < _rect.size.height; y++)
   {
      for (x = 0; x < _rect.size.width; x++)
      {
         NSPoint dstP = {(CGFloat)(x + _rect.origin.x), (CGFloat)(y + _rect.origin.y)};
         NSPoint srcP = [inverse transformPoint:dstP];
         dstP.x -= (CGFloat)_rect.origin.x;
         dstP.y -= (CGFloat)_rect.origin.y;

         const double interpolated = [_interpol interpolateInPLane:0 atX:dstP.x atY:dstP.y];
         const double original = [poly valueAtPoint:srcP];
         XCTAssertEqualWithAccuracy(interpolated, original, 0.01,
                                    @"Bad reconstruction at point x=%d y=%d", x, y);
      }
   }
}

- (void)testLanczosFlatImage
{
   // Create a flat image
   const LynkeosIntegerSize size = {10, 10};
   LynkeosImageBuffer *img
   = [LynkeosImageBuffer imageBufferWithNumberOfPlanes:1 width:size.width height:size.height];
   CGPoint offsets[1] = {CGPointZero};
   TestImagePolynomial *flat = [[[TestImagePolynomial alloc] initWithFirstZero:CGPointMake(0.0, 0.0)
                                                                    secondZero:CGPointMake(1.0, 1.0)
                                                                        factor:CGPointMake(0.0, 0.0)
                                                                        offset:1.0]
                                autorelease];
   fillImage(img, flat);

   // Create the interpolator
   _transform = [NSAffineTransform transform];
   _rect = LynkeosMakeIntegerRect(3, 3, 4, 4);
   _interpol = [[[LynkeosLanczosInterpolator alloc] initWithImage:img
                                                           inRect:_rect
                                               withNumberOfPlanes:1
                                                     withTranform:[_transform transformStruct]
                                                      withOffsets:offsets
                                                   withParameters:nil]
                autorelease];

   [self checkInterpolationWithPolynomial:flat];
}

- (void)testLanczosSaddleImage
{
   // Create a sadle curve image
   const LynkeosIntegerSize size = {10, 10};
   LynkeosImageBuffer *img
   = [LynkeosImageBuffer imageBufferWithNumberOfPlanes:1 width:size.width height:size.height];
   CGPoint offsets[1] = {CGPointZero};
   TestImagePolynomial *saddle = [[[TestImagePolynomial alloc] initWithFirstZero:CGPointMake(3.0, 3.0)
                                                                      secondZero:CGPointMake(7.0, 7.0)
                                                                          factor:CGPointMake(1.0, -1.0)
                                                                          offset:4.0]
                                  autorelease];
   fillImage(img, saddle);

   // Create the interpolator
   _transform = [NSAffineTransform transform];
   [_transform scaleBy:2.0];
   [_transform translateXBy:-3.0 yBy:-3.0];
   _rect = LynkeosMakeIntegerRect(0, 0, 8, 8);
   _interpol = [[[LynkeosLanczosInterpolator alloc] initWithImage:img
                                                           inRect:_rect
                                               withNumberOfPlanes:1
                                                     withTranform:[_transform transformStruct]
                                                      withOffsets:offsets
                                                   withParameters:nil]
                autorelease];

   [self checkInterpolationWithPolynomial:saddle];
}

- (void)testLanczosSaddleImageDownScale
{
   // Create a sadle curve image
   const LynkeosIntegerSize size = {10, 10};
   LynkeosImageBuffer *img
      = [LynkeosImageBuffer imageBufferWithNumberOfPlanes:1 width:size.width height:size.height];
   CGPoint offsets[1] = {CGPointZero};
   TestImagePolynomial *saddle = [[[TestImagePolynomial alloc] initWithFirstZero:CGPointMake(3.0, 3.0)
                                                                      secondZero:CGPointMake(7.0, 7.0)
                                                                          factor:CGPointMake(1.0, -1.0)
                                                                          offset:4.0]
                                  autorelease];
   fillImage(img, saddle);

   // Create the interpolator
   _transform = [NSAffineTransform transform];
   [_transform scaleBy:0.5];
   [_transform translateXBy:-1.0 yBy:-1.0];
   _rect = LynkeosMakeIntegerRect(2, 2, 3, 3);
   _interpol = [[[LynkeosLanczosInterpolator alloc] initWithImage:img
                                                           inRect:_rect
                                               withNumberOfPlanes:1
                                                     withTranform:[_transform transformStruct]
                                                      withOffsets:offsets
                                                   withParameters:nil]
                autorelease];

   [self checkInterpolationWithPolynomial:saddle];
}

- (void)testLanczosSaddleImageWithRotation
{
   // Create a sadle curve image
   const LynkeosIntegerSize size = {50, 50};
   LynkeosImageBuffer *img
   = [LynkeosImageBuffer imageBufferWithNumberOfPlanes:1 width:size.width height:size.height];
   CGPoint offsets[1] = {CGPointZero};
   TestImagePolynomial *saddle = [[[TestImagePolynomial alloc] initWithFirstZero:CGPointMake(15.0, 15.0)
                                                                      secondZero:CGPointMake(35.0, 35.0)
                                                                          factor:CGPointMake(1.0/25.0, -1.0/25.0)
                                                                          offset:4.0]
                                  autorelease];
   fillImage(img, saddle);

   // Create the interpolator
   _transform = [NSAffineTransform transform];
   [_transform rotateByDegrees:30.0];
   [_transform scaleBy:0.2];
   [_transform translateXBy:-1.0 yBy:-1.0];
   _rect = LynkeosMakeIntegerRect(2, 6, 4, 4);
   _interpol = [[[LynkeosLanczosInterpolator alloc] initWithImage:img
                                                           inRect:_rect
                                               withNumberOfPlanes:1
                                                     withTranform:[_transform transformStruct]
                                                      withOffsets:offsets
                                                         withParameters:nil]
                autorelease];

   [self checkInterpolationWithPolynomial:saddle];
}

@end
