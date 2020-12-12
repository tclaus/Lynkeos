//
//  Lynkeos
//  $Id:$
//
//  Created by Jean-Etienne LAMIAUD on Tue Sep 18 2018.
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

#include "LynkeosLanczosInterpolator.h"

const NSString *axParameters = @"aX";
const NSString *ayParameters = @"aY";
const NSString *scaleParameters = @"scale";

static inline void range( CGFloat *v, CGFloat l )
{
   if ( *v < 0.0 )
      *v = 0.0;

   else if ( *v >= l )
      *v = l - 1.0;
}

static double lanczosKernel(double x, double a)
{
   if (x == 0.0)
      return 1.0;
   else if ( -a <= x && x < a)
      return a*sin(M_PI*x)*sin(M_PI*x/a)/M_PI/M_PI/x/x;
   else
      return 0.0;
}

@implementation LynkeosLanczosInterpolator

+ (void) load
{
   // Nothing to do, but needed to get it into the link edition
}

+ (NSString*) name { return( @"Lanczos" ); }

+ (int) isCompatibleWithScaling:(Scaling_t)scaling withTransform:(NSAffineTransformStruct)transform
{
   // Lanczos is suited for general use
   return(50);
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
      _ax = 0.0;
      _ay = 0.0;
   }
   return(self);
}

- (id) initWithItem:(NSObject <LynkeosProcessableItem> *)item
             inRect:(LynkeosIntegerRect)rect
 withNumberOfPlanes:(u_short)nPlanes
       withTranform:(NSAffineTransformStruct)transform
        withOffsets:(const NSPoint*)offsets
     withParameters:(NSDictionary*)params
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
      withParameters:(NSDictionary*)params
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

   // Compute best values for ax and ay (same, until I find a way to distinguish x and y)
   _scale = sqrt(transform.m11 * transform.m22 - transform.m12 * transform.m21);
   if ( _scale <= 1.0)
   {
      // Downsampling, use a 1 kernel, without lobes, scaled to a diameter of 1 in the destination
      _scale *= 2.0; // Diameter 1 => radius 1/2
      _ax = 1.0;
      _ay = 1.0;
   }
   else
   {
      // Upsampling, use a 3 kernel, and scale to 1 in the source
      _ax = 3.0;
      _ay = 3.0;
      _scale = 1.0;
   }

   // And replace by dictionary values when applicable
   if (params != nil)
   {
      NSNumber *value;

      value = [params objectForKey:axParameters];
      if (value != nil)
         _ax = [value doubleValue];

      value = [params objectForKey:ayParameters];
      if (value != nil)
         _ay = [value doubleValue];

      value = [params objectForKey:scaleParameters];
      if (value != nil)
         _scale = [value doubleValue];
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

   // Convolute with the kernel
   REAL * const * const data = [_image colorPlanes];
   double fxi = ceil(interpolationPoint.x - _ax/_scale), lxi = floor(interpolationPoint.x + _ax/_scale);
   double fyi = ceil(interpolationPoint.y - _ay/_scale), lyi = floor(interpolationPoint.y + _ay/_scale);
   double xi, yi;
   double v = 0.0, n = 0.0;
   range(&fxi, (CGFloat)_image->_w);
   range(&lxi, (CGFloat)_image->_w);
   range(&fyi, (CGFloat)_image->_h);
   range(&lyi, (CGFloat)_image->_h);
   for (yi = fyi; yi <= lyi; yi += 1.0)
   {
      for (xi = fxi; xi <= lxi; xi += 1.0)
      {
         const double w = lanczosKernel((interpolationPoint.x - xi)*_scale, _ax)
                          * lanczosKernel((interpolationPoint.y - yi)*_scale, _ay);
         n += w;
         v += w*GET_SAMPLE(data[plane], (u_short)xi, (u_short)yi, _image->_padw);
      }
   }

   return( n == 0.0 ? 0.0 : v/n );
}

- (REALVECT) interpolateVectInPLane:(u_short)plane atX:(double)x atY:(double)y
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
