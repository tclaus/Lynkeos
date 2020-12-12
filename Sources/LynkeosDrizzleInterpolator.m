//
//  Lynkeos
//  $Id:$
//
//  Created by Jean-Etienne LAMIAUD on Thu Oct 30 2014.
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

#include "LynkeosImageBufferAdditions.h"
#include "LynkeosDrizzleInterpolator.h"

/* Cut the coordinate to the authorized range */
static inline short range( long i, short l )
{
   if ( i < 0 )
      i = 0;

   else if ( i >= l )
      i = l-1;

   return( i );
}

@interface LynkeosDrizzleInterpolator(Private)
- (id) initWithTranform:(NSAffineTransformStruct)transform
            withOffsets:(const NSPoint*)offsets andPlanes:(u_short)nPlanes
                 inRect:(LynkeosIntegerRect)rect ;
@end

@implementation LynkeosDrizzleInterpolator(Private)

- (id) initWithTranform:(NSAffineTransformStruct)transform
            withOffsets:(const NSPoint*)offsets andPlanes:(u_short)nPlanes
                 inRect:(LynkeosIntegerRect)rect
{
   if ( (self = [self init]) != nil )
   {
      const double max_offset = 1e-2;
      const double epsilon = max_offset / sqrt(rect.size.width*rect.size.width
                                               + rect.size.height*rect.size.height);

      // Get the scale from the transform
      double scale = transform.m11*transform.m22 - transform.m12*transform.m21;

      NSAssert(scale > 0.0, @"Transform determinant is negative");
      scale = sqrt( scale );

      if ( fabs( scale - 1.0) < epsilon )
         _expand = 1;
      else if ( fabs( scale - 2.0) < epsilon )
         _expand = 2;
      else
         NSAssert( NO, @"Incompatible scale %f for drizzling", scale );

      // Check that there is no rotation
      NSAssert( fabs( sqrt( rect.size.width*rect.size.width
                            + rect.size.height*rect.size.height)
                      * transform.m12) < max_offset,
                @"Drizzling is incompatible with a rotation" );

      // Initialize the pixels weights
      _nPlanes = nPlanes;

      int n;

      for ( n = 0; n < nPlanes; n++ )
      {
         NSPoint o = {transform.tX, transform.tY};

         if ( offsets != NULL )
         {
            o.x += offsets[n].x;
            o.y += offsets[n].y;
         }

         /* Separate the image shift in an integer and a positive fractionary part. */
         _integerOffset[n].x = (short)o.x;
         _weight[n].left = o.x - (REAL)_integerOffset[n].x;
         if ( _weight[n].left < 0 )
         {
            _integerOffset[n].x --;
            _weight[n].left += 1.0;
         }

         _integerOffset[n].y = (short)o.y;
         _weight[n].top = o.y - (REAL)_integerOffset[n].y;
         if ( _weight[n].top < 0 )
         {
            _integerOffset[n].y --;
            _weight[n].top += 1.0;
         }

         u_int i;

         for ( i = 0; i < sizeof(REALVECT)/sizeof(REAL); i++ )
         {
            _vectorWeight[n].left[i] = _weight[n].left;
            _vectorWeight[n].right[i] = 1.0 - _weight[n].left;
            _vectorWeight[n].top[i] = _weight[n].top;
            _vectorWeight[n].bottom[i] = 1.0 - _weight[n].top;
         }
      }
   }

   return( self );
}

@end

@implementation LynkeosDrizzleInterpolator

+ (void) load
{
   // Nothing to do, but needed to get it into the link edition
}

+ (NSString*) name { return( @"Drizzling" ); }

+ (int) isCompatibleWithScaling:(Scaling_t)scaling withTransform:(NSAffineTransformStruct)transform
{
   if ((scaling == ConstantUpScaling || scaling == UseTransform)
       && transform.m11 == transform.m22 && transform.m12 == 0.0 && transform.m21 == 0.0
       && (fabs(transform.m11 - 1.0) < 1e-6 || fabs(transform.m11 - 2.0) < 1e-6))
      return (1000);
   else
      return (0);
}

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      int i;
      u_int j;

      _expand = 0;
      _origin.x = 0.0;
      _origin.y = 0.0;
      _nPlanes = 0;
      for ( i = 0; i < 3; i++ )
      {
         _weight[i].left = 0.0;
         _weight[i].top = 0.0;
         for ( j = 0; j < sizeof(REALVECT)/sizeof(REAL); j++ )
         {
            _vectorWeight[i].left[j] = 0.0;
            _vectorWeight[i].right[j] = 0.0;
            _vectorWeight[i].top[j] = 0.0;
            _vectorWeight[i].bottom[j] = 0.0;
         }
         _integerOffset[i].x = 0;
         _integerOffset[i].y = 0;
      }
      _sample = nil;
   }

   return( self );
}

- (void) dealloc
{
   if ( _sample )
      [_sample release];

   [super dealloc];
}

- (id) initWithItem:(NSObject <LynkeosProcessableItem> *)item
             inRect:(LynkeosIntegerRect)rect
 withNumberOfPlanes:(u_short)nPlanes
       withTranform:(NSAffineTransformStruct)transform
        withOffsets:(const NSPoint*)offsets
     withParameters:(NSDictionary*)params // No dictionary expected
{
   if ( (self = [self initWithTranform:transform
                           withOffsets:offsets
                             andPlanes:nPlanes
                                inRect:rect]) != nil )
   {
      // Extract the sample
      LynkeosIntegerRect r;
      u_int i;
      short minx = INT16_MAX, miny = INT16_MAX,
            maxx = INT16_MIN, maxy = INT16_MIN;

      for ( i = 0; i < nPlanes; i++ )
      {
         if ( minx > _integerOffset[i].x )
            minx = _integerOffset[i].x;
         if ( maxx < _integerOffset[i].x )
            maxx = _integerOffset[i].x;
         if ( miny > _integerOffset[i].y )
            miny = _integerOffset[i].y;
         if ( maxy < _integerOffset[i].y )
            maxy = _integerOffset[i].y;
      }

      r.origin.x = (rect.origin.x - minx - 1) / _expand;
      r.origin.y = (rect.origin.y - miny - 1) / _expand;
      r.size.width = (rect.size.width + (maxx - minx) + _expand) / _expand;
      r.size.height = (rect.size.height + (maxy - miny) + _expand) / _expand;

      _origin.x = rect.origin.x - r.origin.x * _expand;
      _origin.y = rect.origin.y - r.origin.y * _expand;

      _sample = [[LynkeosImageBuffer alloc] initWithNumberOfPlanes:nPlanes
                                                                     width:r.size.width
                                                                    height:r.size.height];
      [item getImageSample:&_sample inRect:r];
      NSAssert( _sample != nil,
                @"Failed to get the image sample to interpolate");
   }

   return( self );
}

- (id) initWithImage:(LynkeosImageBuffer *)image
              inRect:(LynkeosIntegerRect)rect
  withNumberOfPlanes:(u_short)nPlanes
        withTranform:(NSAffineTransformStruct)transform
         withOffsets:(const NSPoint*)offsets
      withParameters:(NSDictionary*)params // No dictionary expected
{
   if ( (self = [self initWithTranform:transform
                           withOffsets:offsets
                             andPlanes:[image numberOfPlanes]
                                inRect:rect]) != nil )
   {
      // Keep the image
      _sample = [image retain];

      _origin.x = rect.origin.x;
      _origin.y = rect.origin.y;
   }

   return( self );
}

- (REAL) interpolateInPLane:(u_short)plane atX:(double)x atY:(double)y
{
   // Pixel coordinate in the source image
   long ix, iy;
   // Offset inside the source image pixel
   u_short xp0, xp1, yp0, yp1;
   REAL ax, ay, v;

   // Get the coordinates in the source image
   ix = x + _origin.x - _integerOffset[plane].x;
   iy = y + _origin.y - _integerOffset[plane].y;
   xp0 = range( (ix - 1) / _expand, _sample->_w );
   xp1 = range( ix / _expand, _sample->_w );
   yp0 = range( (iy - 1) / _expand, _sample->_h );
   yp1 = range( iy / _expand, _sample->_h );

   // Determine the pixels weight
   ax = _weight[plane].left;
   ay = _weight[plane].top;

   /* First quadrant */
   v = colorValue(_sample, xp0, yp0, plane) * ax * ay;

   /* Second quadrant */
   v += colorValue(_sample, xp1, yp0, plane) * (1.0 - ax) * ay;

   /* Third quadrant */
   v += colorValue(_sample, xp0, yp1, plane) * ax * (1.0 - ay);

   /* Fourth and last quadrant */
   v += colorValue(_sample, xp1, yp1, plane) * (1.0 - ax) * (1.0 - ay);
   
   return( v );
}

- (REALVECT) interpolateVectInPLane:(u_short)plane
                                atX:(double)x atY:(double)y
{
   const Pixels_Weight_Vector_t weight = _vectorWeight[plane];
   // Pixel coordinate in the source image
   long ix, iy;
   // Offset inside the source image pixel
   u_short xp0, xp1, yp0, yp1;
   REALVECT v1, v2, v3, v4;
   u_int i;

   // Get the coordinates in the source image
   ix = x + _origin.x - _integerOffset[plane].x;
   iy = y + _origin.y - _integerOffset[plane].y;
   yp0 = range( (iy - 1) / _expand, _sample->_h );
   yp1 = range( iy / _expand, _sample->_h );

   for ( i = 0; i < sizeof(REALVECT)/sizeof(REAL); i++ )
   {
      // Read the pixels vectors
      xp0 = range( (ix + i - 1) / _expand, _sample->_w );
      xp1 = range( (ix + i) / _expand, _sample->_w );

      // First quadrant
      v1[i] = colorValue(_sample, xp0, yp0, plane);
      // Second quadrant
      v2[i] = colorValue(_sample, xp1, yp0, plane);
      // Third quadrant
      v3[i] = colorValue(_sample, xp0, yp1, plane);
      // Fourth and last quadrant
      v4[i] = colorValue(_sample, xp1, yp1, plane);
   }

   return( v1 * weight.left * weight.top
           + v2 * weight.right * weight.top
           + v3 * weight.left * weight.bottom
           + v4 * weight.right * weight.bottom );
}
@end
