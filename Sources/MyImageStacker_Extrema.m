//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on 09/01/11.
//  Copyright 2011-2020 Jean-Etienne LAMIAUD. All rights reserved.
//
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
#include <objc/runtime.h>

#include "MyImageStacker_Extrema.h"

//! Private (and temporary) parameter used to recombine the stacks
static NSString * const myExtremaImageStackerResult = @"ExtremaStackerResult";

/*!
 * @abstract Result for the extrema stacking strategy
 */
@interface ExtremaImageStackerResult : NSObject <LynkeosProcessingParameter>
{
@public
   LynkeosImageBuffer* _extremum; //!< Global extremum
}
@end

@implementation ExtremaImageStackerResult
- (id) init
{
   self = [super init];
   if ( self != nil )
   {
      _extremum = nil;
   }

   return( self );
}

- (void) dealloc
{
   if ( _extremum != nil )
      [_extremum release];

   [super dealloc];
}

// This parameter is deleted at process end, it cannot be saved
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

@interface MyImageStacker_Extrema(Private)
- (void) processBuffer:(LynkeosImageBuffer*)buf
            withResult:(LynkeosImageBuffer*)res ;
@end

@implementation MyImageStacker_Extrema(Private)
- (void) processBuffer:(LynkeosImageBuffer*)buf
            withResult:(LynkeosImageBuffer*)res
{
   u_short x, y, c;
   REAL **p = (REAL**)[res colorPlanes];

   for( c = 0; c < buf->_nPlanes; c++ )
      for( y = 0; y < buf->_h; y++ )
         for( x = 0; x < buf->_w; x++ )
         {
            REAL v = stdColorValue(buf,x,y,c);
            if ( _params->_method.extremum.maxValue )
            {
               if ( v > stdColorValue(res,x,y,c) )
               {
                  SET_SAMPLE(p[c],x,y,res->_padw, v);
               }
            }
            else
            {
               if ( v < stdColorValue(res,x,y,c) )
               {
                  SET_SAMPLE(p[c],x,y,res->_padw, v);
               }
            }
         }
}
@end

@implementation MyImageStacker_Extrema

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _params = nil;
      _extremum = nil;
   }

   return( self );
}

- (id) initWithParameters: (id <NSObject>)params
                     list: (id <LynkeosImageList>)list
{
   NSAssert1( [params isMemberOfClass:[MyImageStackerParameters class]],
              @"Wrong parameter class %s for Image stacker (extrema)",
              class_getName([params class]) );

   if ( (self = [self init]) != nil )
      _params = (MyImageStackerParameters*)[params retain];

   return( self );
}

- (void) dealloc
{
   if ( _params != nil )
      [_params release];
   if ( _extremum != nil )
      [_extremum release];

   [super dealloc];
}

- (void) processImage: (LynkeosImageBuffer*)image
{
   NSAssert( _extremum == nil || _extremum->_nPlanes == [image numberOfPlanes],
            @"heterogeneous planes numbers in extremum stacking" );

   // Extract the data in a local image buffer
   LynkeosImageBuffer *buf
      = [LynkeosImageBuffer imageBufferWithNumberOfPlanes: [image numberOfPlanes]
                                                            width:[image width]
                                                           height:[image height]];
   [image convertToPlanar:[buf colorPlanes] withPlanes:buf->_nPlanes lineWidth:buf->_padw];

   // If this is the first image, create the stack buffer from it
   if ( _extremum == nil )
      _extremum = [buf retain];
   else
      [self processBuffer:buf withResult:_extremum];
}

- (void) finishOneProcessingThreadInList:(id <LynkeosImageList>)list ;
{
   if ( _extremum != nil )
   {
      // Recombine the stacks in the list
      ExtremaImageStackerResult *res
         = [list getProcessingParameterWithRef:myExtremaImageStackerResult
                                 forProcessing:myImageStackerRef];

      if ( res == nil )
      {
         res = [[[ExtremaImageStackerResult alloc] init] autorelease];

         [list setProcessingParameter:res withRef:myExtremaImageStackerResult
                        forProcessing:myImageStackerRef];
      }

      if ( res->_extremum == nil )
         res->_extremum = [_extremum retain];
      else
         [self processBuffer:_extremum withResult:res->_extremum];
   }
}

- (void) finishAllProcessingInList: (id <LynkeosImageList>)list;
{
   ExtremaImageStackerResult *res
      = [list getProcessingParameterWithRef:myExtremaImageStackerResult
                              forProcessing:myImageStackerRef];

   if ( _extremum != nil )
      [_extremum release];
   _extremum = nil;

   if ( res != nil )
      _extremum = [res->_extremum retain];

   // And get rid of the recombining parameter
   [list setProcessingParameter:nil withRef:myExtremaImageStackerResult 
                  forProcessing:myImageStackerRef];   
}

- (LynkeosImageBuffer*) stackingResult
{
   return( _extremum );
}
@end
