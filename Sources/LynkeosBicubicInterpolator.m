//
//  Lynkeos
//  $Id:$
//
//  Created by Jean-Etienne LAMIAUD on Fri Jul 13 2018.
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

#include "LynkeosBicubicInterpolator.h"

/* Cut the coordinate to the authorized range */
static inline void range( CGFloat *v, CGFloat l )
{
   if ( *v < 0.0 )
      *v = 0.0;

   else if ( *v >= l )
      *v = l - 1.0;
}

@interface LynkeosBicubicInterpolator(Private)

- (void) cacheMatrixAtX:(int)x Y:(int)y ;

@end

@implementation LynkeosBicubicInterpolator(Private)

- (void) cacheMatrixAtX:(int)x Y:(int)y
{
   REAL * const * const data = [_image colorPlanes];
   REALVECT p[4];
   int i, j;
   u_short c;

   for ( c = 0; c < _numberOfPlanes; c++ )
   {
      // Extract the 16 pixels
      for ( j = 0; j < 4; j++ )
      {
         int yj = y + j - 1;

         if ( yj < 0 )
            yj = 0;
         else if ( yj >= _image->_h )
            yj =_image->_h - 1;

         for ( i = 0; i < 4; i++ )
         {
            int xi = x + i - 1;

            if ( xi < 0 )
               xi = 0;
            else if ( xi >= _image->_w )
               xi =_image->_w - 1;

            p[j][i] = GET_SAMPLE   (data[c], (u_short)xi, (u_short)yj,
                                    _image->_padw );
         }
      }

      // Compute the bicubic coefficients
      const REALVECT p00 = __builtin_shufflevector(p[0], p[0], 0, 0, 0, 0);
      const REALVECT p01 = __builtin_shufflevector(p[0], p[0], 1, 1, 1, 1);
      const REALVECT p02 = __builtin_shufflevector(p[0], p[0], 2, 2, 2, 2);
      const REALVECT p03 = __builtin_shufflevector(p[0], p[0], 3, 3, 3, 3);
      const REALVECT p10 = __builtin_shufflevector(p[1], p[1], 0, 0, 0, 0);
      const REALVECT p11 = __builtin_shufflevector(p[1], p[1], 1, 1, 1, 1);
      const REALVECT p12 = __builtin_shufflevector(p[1], p[1], 2, 2, 2, 2);
      const REALVECT p13 = __builtin_shufflevector(p[1], p[1], 3, 3, 3, 3);
      const REALVECT p20 = __builtin_shufflevector(p[2], p[2], 0, 0, 0, 0);
      const REALVECT p21 = __builtin_shufflevector(p[2], p[2], 1, 1, 1, 1);
      const REALVECT p22 = __builtin_shufflevector(p[2], p[2], 2, 2, 2, 2);
      const REALVECT p23 = __builtin_shufflevector(p[2], p[2], 3, 3, 3, 3);
      const REALVECT p30 = __builtin_shufflevector(p[3], p[3], 0, 0, 0, 0);
      const REALVECT p31 = __builtin_shufflevector(p[3], p[3], 1, 1, 1, 1);
      const REALVECT p32 = __builtin_shufflevector(p[3], p[3], 2, 2, 2, 2);
      const REALVECT p33 = __builtin_shufflevector(p[3], p[3], 3, 3, 3, 3);

      const REALVECT c0_01 = { 0.00, -0.50,  1.00, -0.50};
      const REALVECT c0_11 = { 1.00,  0.00, -2.50,  1.50};
      const REALVECT c0_21 = { 0.00,  0.50,  2.00, -1.50};
      const REALVECT c0_31 = { 0.00,  0.00, -0.50,  0.50};

      const REALVECT c1_00 = { 0.00,  0.25, -0.50,  0.25};
      const REALVECT c1_02 = { 0.00, -0.25,  0.50, -0.25};
      const REALVECT c1_10 = {-0.50,  0.00,  1.25, -0.75};
      const REALVECT c1_12 = { 0.50,  0.00, -1.25,  0.75};
      const REALVECT c1_20 = { 0.00, -0.25, -1.00,  0.75};
      const REALVECT c1_22 = { 0.00,  0.25,  1.00, -0.75};
      const REALVECT c1_30 = { 0.00,  0.00,  0.25, -0.25};
      const REALVECT c1_32 = { 0.00,  0.00, -0.25,  0.25};

      const REALVECT c2_00 = { 0.00, -0.50,  1.00, -0.5};
      const REALVECT c2_01 = { 0.00,  1.25, -2.50,  1.25};
      const REALVECT c2_02 = { 0.00, -1.00,  2.00, -1.00};
      const REALVECT c2_03 = { 0.00,  0.25, -0.50,  0.25};
      const REALVECT c2_10 = { 1.00,  0.00, -2.50,  1.50};
      const REALVECT c2_11 = {-2.50,  0.00,  6.25, -3.75};
      const REALVECT c2_12 = { 2.00,  0.00, -5.00,  3.00};
      const REALVECT c2_13 = {-0.50,  0.00,  1.25, -0.75};
      const REALVECT c2_20 = { 0.00,  0.50,  2.00, -1.50};
      const REALVECT c2_21 = { 0.00, -1.25, -5.00,  3.75};
      const REALVECT c2_22 = { 0.00,  1.00,  4.00, -3.00};
      const REALVECT c2_23 = { 0.00, -0.25, -1.00,  0.75};
      const REALVECT c2_30 = { 0.00,  0.00, -0.50,  0.50};
      const REALVECT c2_31 = { 0.00,  0.00,  1.25, -1.25};
      const REALVECT c2_32 = { 0.00,  0.00, -1.00,  1.00};
      const REALVECT c2_33 = { 0.00,  0.00,  0.25, -0.25};

      const REALVECT c3_00 = { 0.00,  0.25, -0.50,  0.25};
      const REALVECT c3_01 = { 0.00, -0.75,  1.50, -0.75};
      const REALVECT c3_02 = { 0.00,  0.75, -1.50,  0.75};
      const REALVECT c3_03 = { 0.00, -0.25,  0.50, -0.25};
      const REALVECT c3_10 = {-0.50,  0.00,  1.25, -0.75};
      const REALVECT c3_11 = { 1.50,  0.00, -3.75,  2.25};
      const REALVECT c3_12 = {-1.50,  0.00,  3.75, -2.25};
      const REALVECT c3_13 = { 0.50,  0.00, -1.25,  0.75};
      const REALVECT c3_20 = { 0.00, -0.25, -1.00,  0.75};
      const REALVECT c3_21 = { 0.00,  0.75,  3.00, -2.25};
      const REALVECT c3_22 = { 0.00, -0.75, -3.00,  2.25};
      const REALVECT c3_23 = { 0.00,  0.25,  1.00, -0.75};
      const REALVECT c3_30 = { 0.00,  0.00,  0.25, -0.25};
      const REALVECT c3_31 = { 0.00,  0.00, -0.75,  0.75};
      const REALVECT c3_32 = { 0.00,  0.00,  0.75, -0.75};
      const REALVECT c3_33 = { 0.00,  0.00, -0.25,  0.25};

      _a[c][0] = p01*c0_01 + p11*c0_11 + p21*c0_21 + p31*c0_31;

      _a[c][1] = p00*c1_00 + p02*c1_02 + p10*c1_10 + p12*c1_12 +
      p20*c1_20 + p22*c1_22 + p30*c1_30 + p32*c1_32;

      _a[c][2] = p00*c2_00 + p01*c2_01 + p02*c2_02 + p03*c2_03 +
      p10*c2_10 + p11*c2_11 + p12*c2_12 + p13*c2_13 +
      p20*c2_20 + p21*c2_21 + p22*c2_22 + p23*c2_23 +
      p30*c2_30 + p31*c2_31 + p32*c2_32 + p33*c2_33;

      _a[c][3] = p00*c3_00 + p01*c3_01 + p02*c3_02 + p03*c3_03 +
      p10*c3_10 + p11*c3_11 + p12*c3_12 + p13*c3_13 +
      p20*c3_20 + p21*c3_21 + p22*c3_22 + p23*c3_23 +
      p30*c3_30 + p31*c3_31 + p32*c3_32 + p33*c3_33;
   }

   // And save the cached position
   _x = x;
   _y = y;
}

@end

@implementation LynkeosBicubicInterpolator

+ (void) load
{
   // Nothing to do, but needed to get it into the link edition
}

+ (NSString*) name { return( @"Bicubic" ); }

+ (int) isCompatibleWithScaling:(Scaling_t)scaling withTransform:(NSAffineTransformStruct)transform
{
   double scale = transform.m11*transform.m22 - transform.m12*transform.m21;

   if (scaling == VariableUpScaling || scaling == ConstantUpScaling
       || (scaling == UseTransform && scale >= 1.0))
      return(100);
   else if (scaling == ConstantDownScaling || scaling == VariableDownScaling
            || (scaling == UseTransform && scale < 1.0))
      return(10);
   else
      return(0);
}

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _image = nil;
      _numberOfPlanes = 0;
      _inverseTransform = nil;
      _offsets = NULL;
      _origin = NSZeroPoint;
      _x = INT_MIN;
      _y = INT_MIN;
   }

   return( self );
}

- (id) initWithItem:(NSObject <LynkeosProcessableItem> *)item
             inRect:(LynkeosIntegerRect)rect
 withNumberOfPlanes:(u_short)nPlanes
       withTranform:(NSAffineTransformStruct)transform
        withOffsets:(const NSPoint*)offsets
     withParameters:(NSDictionary*)params // No dictionary expected
{
   // As the transform can be arbitrary, use the entire image
   LynkeosIntegerRect r = {{0, 0}, [item imageSize]};

   LynkeosImageBuffer *image
      = [[[LynkeosImageBuffer alloc] initWithNumberOfPlanes:nPlanes
                                                              width:r.size.width
                                                             height:r.size.height]
         autorelease];
   [item getImageSample:&image inRect:r];
   NSAssert( image != nil, @"Failed to get the image sample to interpolate");

   return([self initWithImage:image inRect:rect withNumberOfPlanes:nPlanes
                 withTranform:transform withOffsets:offsets withParameters:params]);
}

- (id) initWithImage:(LynkeosImageBuffer *)image
              inRect:(LynkeosIntegerRect)rect
  withNumberOfPlanes:(u_short)nPlanes
        withTranform:(NSAffineTransformStruct)transform
         withOffsets:(const NSPoint*)offsets
      withParameters:(NSDictionary*)params // No dictionary expected
{
   if ( (self = [self init]) != nil )
   {
      int i;

      _image = [image retain];
      _numberOfPlanes = nPlanes;
      _inverseTransform = [[NSAffineTransform alloc] init];
      _inverseTransform.transformStruct = transform;
      [_inverseTransform invert];
      _origin = NSPointFromIntegerPoint(rect.origin);

      _offsets = (NSPoint*)malloc(nPlanes*sizeof(NSPoint));
      for (i = 0; i < nPlanes; i++)
      {
         _offsets[i] = (offsets != NULL ? offsets[i] : NSZeroPoint);
      }
   }

   return( self );
}

- (void) dealloc
{
   [_image release];
   if (_offsets != NULL)
      free(_offsets);
   if (_inverseTransform != nil)
      [_inverseTransform release];

   [super dealloc];
}

- (REAL) interpolateInPLane:(u_short)plane atX:(double)x atY:(double)y
{
   // Convert the coordinates to the saved image coordinates
   NSPoint interpolationPoint = NSMakePoint(x + _origin.x, y + _origin.y);

   // Taking into account the offsets
   interpolationPoint.x -= _offsets[plane].x;
   interpolationPoint.y -= _offsets[plane].y;
   interpolationPoint = [_inverseTransform transformPoint:interpolationPoint];
   range(&interpolationPoint.x, (CGFloat)_image->_w);
   range(&interpolationPoint.y, (CGFloat)_image->_h);

   const int x0 = (int)floor(interpolationPoint.x), y0 = (int)floor(interpolationPoint.y);
   const double dx = interpolationPoint.x - (double)x0, dy = interpolationPoint.y - (double)y0;
   const double dx2 = dx * dx, dx3 = dx2 * dx;
   const REALVECT vy = {1.0, dy, dy*dy, dy*dy*dy};
   REALVECT v0, v1, v2, v3;

   if ( x0 != _x || y0 != _y )
      [self cacheMatrixAtX:x0 Y:y0];

   v0 = _a[plane][0] * vy;
   v1 = _a[plane][1] * vy;
   v2 = _a[plane][2] * vy;
   v3 = _a[plane][3] * vy;

   double v = (  (v0[0] + v0[1] + v0[2] + v0[3])
          + (v1[0] + v1[1] + v1[2] + v1[3]) * dx
          + (v2[0] + v2[1] + v2[2] + v2[3]) * dx2
          + (v3[0] + v3[1] + v3[2] + v3[3]) * dx3);

   if (isnan(v))
      v = 0.0;

   return( v );
}

- (REALVECT) interpolateVectInPLane:(u_short)plane
                                atX:(double)x atY:(double)y
{
   // Pending a better implementation
   u_long i;
   REALVECT result;
   for (i = 0; i < sizeof(REALVECT)/sizeof(REAL); i++)
   {
      result[i] = [self interpolateInPLane:plane atX:x+(u_short)i atY:y];
   }
   return (result);
}
@end
