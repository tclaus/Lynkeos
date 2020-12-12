//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Thu May 8 2008.
//  Copyright (c) 2008-2018. Jean-Etienne LAMIAUD
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

#include "LynkeosBasicAlignResult.h"

/* For compatibility, we keep the same string as MyImageAligner */
NSString * const LynkeosAlignRef = @"MyImageAligner";
NSString * const LynkeosAlignResultRef = @"AlignResult";

#define K_ALIGN_OFFSET        @"offset"
#define K_ALIGN_TRANSFORM     @"transform"

@implementation LynkeosBasicAlignResult(Private)
- (void) cacheValues
{
   NSAffineTransformStruct m = [_transform transformStruct];

   // As the determinant is a surface ratio, and the scaling is homothetic,
   // the scale is its square root
   _scale = sqrt(m.m11*m.m22 - m.m12*m.m21);

   // The "unscaled" matrix is a pure rotation matrix, therefore, the rotation
   // angle is extracted from its transform of the X unit vector
   _rotation = atan2(m.m21/_scale, m.m11/_scale)/M_PI*180.0;
}
@end

@implementation LynkeosBasicAlignResult
- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _transform = [[NSAffineTransform transform] retain];
      _scale = 1.0;
      _rotation = 0.0;
   }

   return( self );
}

- (id) initWithCoder:(NSCoder *)decoder
{
   self = [self init];

   if ( self != nil )
   {
      if ( [decoder containsValueForKey:K_ALIGN_OFFSET] )
      {
         _offset = [decoder decodePointForKey:K_ALIGN_OFFSET];
      }

      if ( [decoder containsValueForKey:K_ALIGN_TRANSFORM] )
      {
         // Replace the transform
         [_transform release];
         _transform = [[decoder decodeObjectForKey:K_ALIGN_TRANSFORM] retain];
      }
      else
         // V2 document
         [_transform translateXBy:_offset.x yBy:_offset.y];
   }
   [self cacheValues];

   return( self );
}

- (void) dealloc
{
   [_transform release];

   [super dealloc];
}
- (void)encodeWithCoder:(NSCoder *)encoder
{
   [encoder encodeObject:_transform forKey: K_ALIGN_TRANSFORM];
   [encoder encodePoint:_offset forKey:K_ALIGN_OFFSET];
}

- (void) setTransformStruct:(NSAffineTransformStruct)m
{
   [_transform setTransformStruct:m];
   [self cacheValues];
}

- (void) setOffset:(NSPoint)offset
{
   _offset = offset;
}

- (NSNumber*) dx
{
   return( [NSNumber numberWithDouble:_offset.x] );
}

- (NSNumber*) dy
{
   return( [NSNumber numberWithDouble:_offset.y] );
}

- (NSAffineTransform*) alignTransform
{
   return( _transform );
}

- (NSNumber*)rotation
{
   return( [NSNumber numberWithDouble:_rotation] );
}

- (NSNumber*)scale
{
   return( [NSNumber numberWithDouble:_scale] );
}
@end

/*!
* @abstract Class for reading files up to V2.2
 */
@interface MyImageAlignerResult : NSObject <LynkeosProcessingParameter>
{
}
@end

@implementation MyImageAlignerResult
- (id) init
{
   [self release];
   self = (MyImageAlignerResult*)[[LynkeosBasicAlignResult alloc] init];
   return( self );
}

- (void)encodeWithCoder:(NSCoder *)encoder
{ [self doesNotRecognizeSelector:_cmd]; }

- (id) initWithCoder:(NSCoder *)decoder
{
   [self release];
   self = (MyImageAlignerResult*)[[LynkeosBasicAlignResult alloc] initWithCoder:decoder];
   return( self );
}

@end
