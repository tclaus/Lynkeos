//
//  Lynkeos
//  $Id: $
//
//  Created by Jean-Etienne LAMIAUD on Thu Oct 18 2018.
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

#include <objc/objc-class.h>

#include <LynkeosCore/LynkeosInterpolator.h>

#include "SER_ImageBuffer.h"

const NSString *WeightKey = @"weight";
const NSString *SubstractiveKey = @"substractive";

@interface SER_ImageBuffer(Private)
- (LynkeosImageBuffer *) planarImage;
@end

@implementation SER_ImageBuffer(Private)
- (LynkeosImageBuffer *) planarImage
{
   LynkeosImageBuffer *img = [LynkeosImageBuffer imageBufferWithNumberOfPlanes:3
                                                                         width:_w
                                                                        height:_h];
   [self convertToPlanar:[img colorPlanes] withPlanes:img->_nPlanes lineWidth:img->_padw];

   return img;
}
@end

@implementation SER_ImageBuffer

- (BOOL) hasCustomFormat
{
   return YES;
}

- (id) init
{
   if ( (self = [super init]) != nil)
   {
      _weight = nil;
      _accumulations = 0;
      _substractive = NO;
   }

   return self;
}

- (id) initWithData:(REAL*)data format:(ColorID_t)format
              width:(u_short)width lineW:(u_short)lineW height:(u_short)height
                atX:(u_short)x Y:(u_short)y W:(u_short)w H:(u_short)h
      withTransform:(NSAffineTransformStruct)transform
        withOffsets:(const NSPoint*)offsets
           withDark:(SER_ImageBuffer*)dark withFlat:(LynkeosImageBuffer*)flat
{
   // Allocate an RGB image buffer
   if ((self = [super initWithNumberOfPlanes:3 width:w height:h]) != nil)
   {
      u_short bayerPlanes[2][2];

      // And weight planes
      _weight = [[LynkeosImageBuffer imageBufferWithNumberOfPlanes:3 width:w height:h] retain];
      _accumulations = 1.0;

      switch (format)
      {
         case SER_BAYER_CYYM:
         case SER_BAYER_YCMY:
         case SER_BAYER_YMCY:
         case SER_BAYER_MYYC:
            _substractive = YES;
            break;
         default:
            _substractive = NO;
            break;
      }

      // Fill in the pixels in their respective planes
      switch (format)
      {
         case SER_BAYER_CYYM: // Planes in CYM order
         case SER_BAYER_RGGB:
            bayerPlanes[0][0] = 0; bayerPlanes[0][1] = 1;
            bayerPlanes[1][0] = 1; bayerPlanes[1][1] = 2;
            break;
         case SER_BAYER_YCMY: // Planes in CYM order
         case SER_BAYER_GRBG:
            bayerPlanes[0][0] = 1; bayerPlanes[0][1] = 0;
            bayerPlanes[1][0] = 2; bayerPlanes[1][1] = 1;
            break;
         case SER_BAYER_YMCY: // Planes in CYM order
         case SER_BAYER_GBRG:
            bayerPlanes[0][0] = 1; bayerPlanes[0][1] = 2;
            bayerPlanes[1][0] = 0; bayerPlanes[1][1] = 1;
            break;
         case SER_BAYER_MYYC: // Planes in CYM order
         case SER_BAYER_BGGR:
            bayerPlanes[0][0] = 2; bayerPlanes[0][1] = 1;
            bayerPlanes[1][0] = 1; bayerPlanes[1][1] = 0;
            break;
         default: // Non bayer format
            NSAssert(NO, @"Non Bayer format in SER_ImageBuffer");
            break;
      }

      // Allocate temporary images before transformation
      LynkeosImageBuffer *originalImage
         = [LynkeosImageBuffer imageBufferWithNumberOfPlanes:3 width:lineW height:height];
      LynkeosImageBuffer *originalWeight
         = [LynkeosImageBuffer imageBufferWithNumberOfPlanes:3 width:lineW height:height];

      u_short xl, yl, p;
      for (yl = 0; yl < height; yl++)
      {
         for (xl = 0; xl < width; xl++)
         {
            for (p = 0; p < 3; p++)
            {
               if (bayerPlanes[yl%2][xl%2] == p)
               {
                  stdColorValue(originalImage, xl, yl, p) = data[xl + yl*lineW];
                  stdColorValue(originalWeight, xl, yl, p) = 1.0;
               }
               else
               {
                  stdColorValue(originalImage, xl, yl, p) = 0.0;
                  stdColorValue(originalWeight, xl, yl, p) = 0.0;
               }
            }
         }
      }

      // Apply calibration frames, if any
      if (dark != nil)
      {
         [originalImage substract:dark];
         [originalWeight substract:dark->_weight];
      }

      if (flat != nil)
      {
         [self divideBy:flat result:self];
      }

      // And interpolate to fill the image and weight
      const LynkeosIntegerRect r = {{x, y}, {w, h}};
      Class interpolatorClass = [LynkeosInterpolatorManager interpolatorWithScaling:UseTransform
                                                                          transform:transform];
      id <LynkeosInterpolator> imageInterpolator
         = [[[interpolatorClass alloc] initWithImage:originalImage
                                              inRect:r
                                  withNumberOfPlanes:3
                                        withTranform:transform
                                         withOffsets:offsets
                                      withParameters:nil] autorelease];
      id <LynkeosInterpolator> weightInterpolator
         = [[[interpolatorClass alloc] initWithImage:originalWeight
                                              inRect:r
                                  withNumberOfPlanes:3
                                        withTranform:transform
                                         withOffsets:offsets
                                      withParameters:nil] autorelease];

      for (p = 0; p < 3; p++)
      {
         for (yl = 0; yl < h; yl++)
         {
            for (xl = 0; xl < w; xl++)
            {
               REAL v;
               v = [imageInterpolator interpolateInPLane:p atX:xl atY:yl];
               if (isnan(v))
                  NSLog(@"NaN pixel value at %d %d, in plane %d", xl, yl, p);
               else
                  stdColorValue(self, xl, yl, p) = v;
               v = [weightInterpolator interpolateInPLane:p atX:xl atY:yl];
               if (isnan(v))
                  NSLog(@"NaN pixel weight at %d %d, in plane %d", xl, yl, p);
               else
                  stdColorValue(_weight, xl, yl, p) = v;
            }
         }
      }
   }

   return(self);
}

- (nullable instancetype) initWithCoder:(nonnull NSCoder *)aDecoder
{
   if ((self = [super initWithCoder:aDecoder]) != nil)
   {
      _weight = [[aDecoder decodeObjectForKey:(NSString*)WeightKey] retain];
      _accumulations = 1.0;
      _substractive = [aDecoder decodeBoolForKey:(NSString*)SubstractiveKey];
   }

   return self;
}

- (nonnull id) copyWithZone:(nullable NSZone *)zone
{
   SER_ImageBuffer *other = [[SER_ImageBuffer allocWithZone:zone] initWithData:_data
                                                                          copy:YES
                                                                  freeWhenDone:YES
                                                                numberOfPlanes:_nPlanes
                                                                         width:_w
                                                                   paddedWidth:_padw
                                                                        height:_h];
   if (other != nil)
   {
      other->_weight = [_weight copyWithZone:zone];
      other->_accumulations = _accumulations;
      other->_substractive = _substractive;
   }

   return other;
}

- (void) dealloc
{
   [_weight release];
   [super dealloc];
}

- (size_t) memorySize
{
   return([super memorySize] + [_weight memorySize]);
}

- (u_short) width {return _w;}

- (u_short) height {return _h;}

- (u_short) numberOfPlanes {return 3;}

- (CGImageRef) getImageInRect:(LynkeosIntegerRect)r
                    withBlack:(double*)black white:(double*)white gamma:(double*)gamma
{
   LynkeosImageBuffer *img = [self planarImage];

   return [img getImageInRect:r withBlack:black white:white gamma:gamma];
}

- (void) add :(LynkeosImageBuffer*)image
{
   NSAssert([image isKindOfClass:[self class]], @"SER_ImageBuffer can only add with itself");
   SER_ImageBuffer *other = (SER_ImageBuffer*)image;
   [super add:image];
   [_weight add:other->_weight];
   _accumulations += other->_accumulations;
}

- (void) calibrateWithDarkFrame:(LynkeosImageBuffer*)darkFrame
                      flatField:(LynkeosImageBuffer*)flatField
                            atX:(u_short)ox Y:(u_short)oy
{
   // Nothing to do. Calibration occurs in the reader
}

// This is used only on callibration frames
- (void) normalizeWithFactor:(double)factor mono:(BOOL)mono
{
   if (factor == 0 || mono)
   {
      // We need to debayer first
      LynkeosImageBuffer *buf
         = [[LynkeosImageBuffer alloc] initWithNumberOfPlanes:_nPlanes width:_w height:_h];
      [self convertToPlanar:[buf colorPlanes] withPlanes:_nPlanes lineWidth:buf->_padw];
      [buf extractSample:_planes atX:0 Y:0 withWidth:_w height:_h withPlanes:_nPlanes lineWidth:_padw];
      // Set a constant one weight
      _accumulations = 1.0;
      REALVECT one = {1.0, 1.0, 1.0, 1.0};
      for (u_short p = 0; p < _nPlanes; p++)
      {
         for (u_short y = 0; y < _h; y++)
         {
            for (u_short x = 0; x < _w; x+= sizeof(REALVECT)/sizeof(REAL))
               *((REALVECT*)&_planes[p][y*_padw+x]) = one;
         }
      }
      // And normalize
      [super normalizeWithFactor:factor mono:mono];
   }
   else
   {
      // Apply the normalization on the image and weights
      [super normalizeWithFactor:factor mono:mono];
      [_weight normalizeWithFactor:factor mono:mono];
      _accumulations *= factor;
   }
}

- (void) convertToPlanar:(REAL * const * const)planes
              withPlanes:(u_short)nPlanes
               lineWidth:(u_short)lineW
{
   u_short x, y, p;

#warning Take into account the parallel strategy
   for (y = 0; y < _h; y++)
   {
      for (x = 0; x < _w; x++)
      {
         REAL pixel[3];

         for (p = 0; p < 3; p++)
         {
            double localWeight = stdColorValue(_weight, x, y, p) / _accumulations;
            // Above a wheight threshold, keep the pixels unchanged
            if ( localWeight >= 0.25)
               pixel[p] = stdColorValue(self, x, y, p) / localWeight;

            // Otherwise interpolate with neighbours having a better weight
            else
            {
               const u_short mxl = (x < _w - 1 ? x + 1 : _w - 1);
               const u_short myl = (y < _h - 1 ? y + 1 : _h - 1);
               const u_short sxl = (x < 1 ? 0 : x - 1), syl = (y < 1 ? 0 : y - 1);
               u_short xl, yl;
               double sum = 0.0, weight = 0.0;
               for ( yl = syl; yl <= myl; yl++)
               {
                  for ( xl = sxl; xl <= mxl; xl++)
                  {
                     double pixelValue = stdColorValue(self, xl, yl, p);
                     if (xl == x && yl == y)
                     {
                        sum += pixelValue;
                        weight += localWeight;
                     }
                     else
                     {
                        double otherWeight = stdColorValue(_weight, xl, yl, p)/_accumulations;
                        double interpolationWeight = otherWeight - localWeight;

                        if (interpolationWeight > 0.0)
                        {
                           sum += (pixelValue / otherWeight) * interpolationWeight;
                           weight += interpolationWeight;
                        }
                     }
                  }
               }
               pixel[p] = (weight != 0.0 ? sum / weight : 0.0);
            }
         }
         if (nPlanes == 1)
            // Convert to monochrome
            planes[0][x+lineW*y] = (pixel[0]+pixel[1]+pixel[2])/3.0;
         else
         {
#warning Convert CMY to RGB when needed
            for (p = 0; p < nPlanes; p++)
               planes[p][x+lineW*y] = pixel[p];
         }
      }
   }
}

- (void) clear
{
   [super clear];
   [_weight clear];
}

- (void)setOperatorsStrategy:(ImageOperatorsStrategy_t)strategy
{ 
   [super setOperatorsStrategy:strategy];
   [_weight setOperatorsStrategy:strategy];
}

- (void) encodeWithCoder:(nonnull NSCoder *)aCoder
{
   // Set the accumulations number to one
   const double factor = 1.0 / _accumulations;
   [self multiplyWithScalar:factor];
   [_weight multiplyWithScalar:factor];
   // And save the object
   [super encodeWithCoder:aCoder];
   [aCoder encodeObject:_weight forKey:(NSString*)WeightKey];
   [aCoder encodeBool:_substractive forKey:(NSString*)SubstractiveKey];
}
@end
