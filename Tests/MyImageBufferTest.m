//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Sat Apr 9 2005.
//  Copyright (c) 2005-2020. Jean-Etienne LAMIAUD
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

#include "processing_core.h"
#include "LynkeosImageBuffer.h"
#include "LynkeosImageBufferAdditions.h"

@interface MyImageBufferTest : XCTestCase
{
}
@end

BOOL testInitialized;

@interface MyImageBufferTest(Utilities)
- (void) testMulWithVect:(BOOL)vect withThreads:(BOOL)thread ;
- (void) testScaleWithVect:(BOOL)vect withThreads:(BOOL)thread ;
- (void) testDivWithVect:(BOOL)vect withThreads:(BOOL)thread ;
@end

@implementation MyImageBufferTest(Utilities)
- (void) testMulWithVect:(BOOL)vect withThreads:(BOOL)thread
{
   u_short x, y, c;
   BOOL reallyHasSIMD = hasSIMD;

   if ( vect )
   {
      if ( ! hasSIMD )
      {
         NSLog( @"This machine has no vector, skipping test" );
         return;
      }
   }
   else
      hasSIMD = NO;

   LynkeosImageBuffer *image1 =
                 [LynkeosImageBuffer imageBufferWithNumberOfPlanes:3
                                                                     width:640
                                                                    height:480];
   LynkeosImageBuffer *image2 =
                 [LynkeosImageBuffer imageBufferWithNumberOfPlanes:3
                                                                     width:640
                                                                    height:480];

   // Prepare the test images
   for( y = 0; y < 480; y++ )
   {
      for( x = 0; x < 640; x++ )
      {
         for( c = 0; c < 3; c++ )
         {
            colorValue(image1,x,y,c) = x/6.4 + y/48.0 + (REAL)c;
            colorValue(image2,x,y,c) = (640-x)/6.4 + (480-y)/48.0 + 3.0 - (REAL)c;
         }
      }
   }

   if ( thread )
      [image1 setOperatorsStrategy:ParallelizedStrategy];

   NSDate *start = [NSDate date];
   [image1 multiplyWith:image2 result:image1];
   NSLog( @"Processing time %f", -[start timeIntervalSinceNow] );

   for( y = 0; y < 480; y++ )
   {
      for( x = 0; x < 640; x++ )
      {
         for( c = 0; c < 3; c++ )
         {
            REAL v = colorValue(image1,x,y,c);

            XCTAssertEqualWithAccuracy(v, (REAL)(x/6.4+y/48.0+c)
                                  *(REAL)((640-x)/6.4+(480-y)/48.0+3.0-(REAL)c),
                                       1e-5, @"at %d,%d", x, y );
         }
      }
   }

   if ( ! vect )
      hasSIMD = reallyHasSIMD;
}

- (void) testScaleWithVect:(BOOL)vect withThreads:(BOOL)thread
{
   u_short x, y, c;
   BOOL reallyHasSIMD = hasSIMD;

   if ( vect )
   {
      if ( ! hasSIMD )
      {
         NSLog( @"This machine has no vector, skipping test" );
         return;
      }
   }
   else
      hasSIMD = NO;

   LynkeosImageBuffer *image =
                 [LynkeosImageBuffer imageBufferWithNumberOfPlanes:3
                                                                     width:640
                                                                    height:480];
   // Prepare the test images
   for( y = 0; y < 480; y++ )
      for( x = 0; x < 640; x++ )
         for( c = 0; c < 3; c++ )
            colorValue(image,x,y,c) = x/6.4 + y/48.0 + (REAL)c;

   if ( thread )
      [image setOperatorsStrategy:ParallelizedStrategy];

   NSDate *start = [NSDate date];
   [image multiplyWithScalar:2.0];
   NSLog( @"Processing time %f", -[start timeIntervalSinceNow] );

   for( y = 0; y < 480; y++ )
   {
      for( x = 0; x < 640; x++ )
      {
         for( c = 0; c < 3; c++ )
         {
            REAL v = colorValue(image,x,y,c);

            XCTAssertEqualWithAccuracy(v, (REAL)(x/6.4+y/48.0+c)*2.0f, 1e-5,
                                       @"at %d,%d", x, y );
         }
      }
   }

   if ( ! vect )
      hasSIMD = reallyHasSIMD;
}

- (void) testDivWithVect:(BOOL)vect withThreads:(BOOL)thread
{
   u_short x, y, c;
   BOOL reallyHasSIMD = hasSIMD;

   if ( vect )
   {
      if ( ! hasSIMD )
      {
         NSLog( @"This machine has no vector, skipping test" );
         return;
      }
   }
   else
      hasSIMD = NO;

   LynkeosImageBuffer *image1 =
                 [LynkeosImageBuffer imageBufferWithNumberOfPlanes:3
                                                                     width:640
                                                                    height:480];
   LynkeosImageBuffer *image2 =
                 [LynkeosImageBuffer imageBufferWithNumberOfPlanes:3
                                                                     width:640
                                                                    height:480];

   // Prepare the test images
   for( y = 0; y < 480; y++ )
   {
      for( x = 0; x < 640; x++ )
      {
         for( c = 0; c < 3; c++ )
         {
            colorValue(image1,x,y,c) = x/6.4 + y/48.0 + (REAL)c;
            colorValue(image2,x,y,c) = (640-x)/6.4 + (480-y)/48.0 + 3.0 - (REAL)c;
         }
      }
   }

   if ( thread )
      [image1 setOperatorsStrategy:ParallelizedStrategy];

   NSDate *start = [NSDate date];
   [image1 divideBy:image2 result:image1];
   NSLog( @"Processing time %f", -[start timeIntervalSinceNow] );

   for( y = 0; y < 480; y++ )
   {
      for( x = 0; x < 640; x++ )
      {
         for( c = 0; c < 3; c++ )
         {
            REAL v = colorValue(image1,x,y,c);

            XCTAssertEqualWithAccuracy(v, (REAL)(x/6.4+y/48.0+c)
                                  /(REAL)((640-x)/6.4+(480-y)/48.0+3.0-(REAL)c),
                                       1e-5, @"at %d,%d", x, y );
         }
      }
   }

   if ( ! vect )
      hasSIMD = reallyHasSIMD;
}
@end

@implementation MyImageBufferTest

+ (void) initialize
{
   if ( !testInitialized )
   {
      testInitialized = YES;
      // Initialize vector and multiprocessor stuff
      initializeProcessing();
   }
}

- (void) testLRGB1
{
   u_short x, y;
   LynkeosImageBuffer *image1 = [LynkeosImageBuffer imageBufferWithNumberOfPlanes:3
                                                                  width:30
                                                                 height:24];
   LynkeosImageBuffer *image2 = [LynkeosImageBuffer imageBufferWithNumberOfPlanes:1
                                                                  width:30
                                                                 height:24];

   // Prepare the test images
   for( y = 0; y < 24; y++ )
   {
      for( x = 0; x < 30; x++ )
      {
         if ( y < 8 )
         {
            colorValue(image1,x,y,0) = (8.0-y)/8.0;
            colorValue(image1,x,y,1) = y/8.0;
            colorValue(image1,x,y,2) = 0.0;
         }
         else if ( y < 16 )
         {
            colorValue(image1,x,y,0) = 0;
            colorValue(image1,x,y,1) = (16.0-y)/8.0;
            colorValue(image1,x,y,2) = (y-8.0)/8.0;
         }
         else
         {
            colorValue(image1,x,y,0) = (y-16.0)/8.0;
            colorValue(image1,x,y,1) = 0;
            colorValue(image1,x,y,2) = (24.0-y)/8.0;
         }

         colorValue(image2,x,y,0) = x/30.0;
      }
   }

   [image1 add:image2];

   for( y = 0; y < 24; y++ )
   {
      for( x = 0; x < 30; x++ )
      {
         double r = colorValue(image1,x,y,0);
         double v = colorValue(image1,x,y,1);
         double b = colorValue(image1,x,y,2);

         if ( y < 8 )
         {
            XCTAssertEqualWithAccuracy( r, (1.0+x/10.0)*(8.0-y)/8.0, 1e-5,  
                                        @"at %d,%d", x, y );
            XCTAssertEqualWithAccuracy( v, (1.0+x/10.0)*y/8.0, 1e-5,  
                                        @"at %d,%d", x, y );
            XCTAssertEqualWithAccuracy( b, 0.0, 1e-5,  
                                        @"at %d,%d", x, y );
         }
         else if ( y < 16 )
         {
            XCTAssertEqualWithAccuracy( r, 0.0, 1e-5,  
                                        @"at %d,%d", x, y );
            XCTAssertEqualWithAccuracy( v, (1.0+x/10.0)*(16.0-y)/8.0, 1e-5,  
                                        @"at %d,%d", x, y );
            XCTAssertEqualWithAccuracy( b, (1.0+x/10.0)*(y-8.0)/8.0, 1e-5,  
                                        @"at %d,%d", x, y );
         }
         else
         {
            XCTAssertEqualWithAccuracy( r, (1.0+x/10.0)*(y-16.0)/8.0, 1e-5,  
                                        @"at %d,%d", x, y );
            XCTAssertEqualWithAccuracy( v, 0.0, 1e-5,  
                                        @"at %d,%d", x, y );
            XCTAssertEqualWithAccuracy( b, (1.0+x/10.0)*(24.0-y)/8.0, 1e-5,  
                                        @"at %d,%d", x, y );
         }
      }
   }
}

// Same in reverse order
- (void) testLRGB2
{
   u_short x, y;
   LynkeosImageBuffer *image1 = [LynkeosImageBuffer imageBufferWithNumberOfPlanes:3
                                                                  width:30
                                                                 height:24];
   LynkeosImageBuffer *image2 = [LynkeosImageBuffer imageBufferWithNumberOfPlanes:1
                                                                  width:30
                                                                 height:24];

   // Prepare the test images
   for( y = 0; y < 24; y++ )
   {
      for( x = 0; x < 30; x++ )
      {
         if ( y < 8 )
         {
            colorValue(image1,x,y,0) = (8.0-y)/8.0;
            colorValue(image1,x,y,1) = y/8.0;
            colorValue(image1,x,y,2) = 0.0;
         }
         else if ( y < 16 )
         {
            colorValue(image1,x,y,0) = 0;
            colorValue(image1,x,y,1) = (16.0-y)/8.0;
            colorValue(image1,x,y,2) = (y-8.0)/8.0;
         }
         else
         {
            colorValue(image1,x,y,0) = (y-16.0)/8.0;
            colorValue(image1,x,y,1) = 0;
            colorValue(image1,x,y,2) = (24.0-y)/8.0;
         }

         colorValue(image2,x,y,0) = x/30.0;
      }
   }

   [image2 add:image1];

   // The number of planes should have changed
   XCTAssertEqual( image2->_nPlanes, (u_short)3);

   for( y = 0; y < 24; y++ )
   {
      for( x = 0; x < 30; x++ )
      {
         double r = colorValue(image2,x,y,0);
         double v = colorValue(image2,x,y,1);
         double b = colorValue(image2,x,y,2);

         if ( y < 8 )
         {
            XCTAssertEqualWithAccuracy( r, (1.0+x/10.0)*(8.0-y)/8.0, 1e-5,  
                                        @"at %d,%d", x, y );
            XCTAssertEqualWithAccuracy( v, (1.0+x/10.0)*y/8.0, 1e-5,  
                                        @"at %d,%d", x, y );
            XCTAssertEqualWithAccuracy( b, 0.0, 1e-5,  
                                        @"at %d,%d", x, y );
         }
         else if ( y < 16 )
         {
            XCTAssertEqualWithAccuracy( r, 0.0, 1e-5,  
                                        @"at %d,%d", x, y );
            XCTAssertEqualWithAccuracy( v, (1.0+x/10.0)*(16.0-y)/8.0, 1e-5,  
                                        @"at %d,%d", x, y );
            XCTAssertEqualWithAccuracy( b, (1.0+x/10.0)*(y-8.0)/8.0, 1e-5,  
                                        @"at %d,%d", x, y );
         }
         else
         {
            XCTAssertEqualWithAccuracy( r, (1.0+x/10.0)*(y-16.0)/8.0, 1e-5,  
                                        @"at %d,%d", x, y );
            XCTAssertEqualWithAccuracy( v, 0.0, 1e-5,  
                                        @"at %d,%d", x, y );
            XCTAssertEqualWithAccuracy( b, (1.0+x/10.0)*(24.0-y)/8.0, 1e-5,  
                                        @"at %d,%d", x, y );
         }
      }
   }
}

- (void) testMul_noVect_noThread
{
   [self testMulWithVect:NO withThreads:NO];
}

- (void) testMul_noVect_withThread
{
   [self testMulWithVect:NO withThreads:YES];
}

- (void) testMul_withVect_noThread
{
   [self testMulWithVect:YES withThreads:NO];
}

- (void) testMul_withVect_withThread
{
   [self testMulWithVect:YES withThreads:YES];
}

- (void) testDiv_noVect_noThread
{
   [self testDivWithVect:NO withThreads:NO];
}

- (void) testDiv_noVect_withThread
{
   [self testDivWithVect:NO withThreads:YES];
}

- (void) testDiv_withVect_noThread
{
   [self testDivWithVect:YES withThreads:NO];
}

- (void) testDiv_withVect_withThread
{
   [self testDivWithVect:YES withThreads:YES];
}

- (void) testScale_noVect_noThread
{
   [self testScaleWithVect:NO withThreads:NO];
}

- (void) testScale_noVect_withThread
{
   [self testScaleWithVect:NO withThreads:YES];
}

- (void) testScale_withVect_noThread
{
   [self testScaleWithVect:YES withThreads:NO];
}

- (void) testScale_withVect_withThread
{
   [self testScaleWithVect:YES withThreads:YES];
}
@end
