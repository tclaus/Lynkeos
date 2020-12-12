//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on 01/01/11.
//  Copyright 2011-2020 Jean-Etienne LAMIAUD. All rights reserved.
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

#include "MyImageStacker_Standard.h"

// Private (and temporary) parameter used to recombine the stacks
static NSString * const myStandardImageStackerResult = @"StandardStackerResult";

static LynkeosImageBuffer *getPlanarData(LynkeosImageBuffer* img)
{
   if ([img isKindOfClass:[LynkeosImageBuffer class]]
       && ![(LynkeosImageBuffer*)img hasCustomFormat])
      return img;
   else
   {
      LynkeosImageBuffer *newImg
         = [LynkeosImageBuffer imageBufferWithNumberOfPlanes:[img numberOfPlanes]
                                                               width:[img width]
                                                              height:[img height]];
      [img convertToPlanar:[newImg colorPlanes] withPlanes:newImg->_nPlanes lineWidth:newImg->_padw];
      return newImg;
   }
}

/*!
 * @abstract Result of the standard stacking strategy
 */
@interface StandardImageStackerResult : NSObject <LynkeosProcessingParameter>
{
@public
   LynkeosImageBuffer* _mono; //!< Stack of monochrome image
   LynkeosImageBuffer* _rgb;  //!< Stack of colour images
}
@end

@implementation StandardImageStackerResult
- (id) init
{
   self = [super init];
   if ( self != nil )
   {
      _mono = nil;
      _rgb = nil;
   }
   
   return( self );
}

- (void) dealloc
{
   if ( _mono != nil )
      [_mono release];
   if ( _rgb != nil )
      [_rgb release];
   
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

@implementation MyImageStacker_Standard

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _params = nil;
      _monoStack = nil;
      _rgbStack = nil;
   }

   return( self );
}

- (id) initWithParameters: (id <NSObject>)params
                     list: (id <LynkeosImageList>)list
{
   if ( (self = [self init]) != nil )
   {
      NSAssert1( [params isMemberOfClass:[MyImageStackerParameters class]],
                 @"Wrong parameter class %s for Image stacker (standard)",
                 class_getName([params class]) );
      _params = (MyImageStackerParameters*)[params retain];
   }

   return( self );
}

- (void) dealloc
{
   if ( _monoStack != nil )
      [_monoStack release];
   if ( _rgbStack != nil )
      [_rgbStack release];

   [super dealloc];
}

- (void) processImage: (LynkeosImageBuffer*)image
{
   LynkeosImageBuffer* *sum;

   if ( [image numberOfPlanes] == 1 )
      sum = &_monoStack;
   else
      sum = &_rgbStack;

   // If this is the first image, keep it as stack buffer
   if ( *sum == nil )
      *sum = [image retain];
   else
      // Accumulate
      [*sum add:image];
}

- (void) finishOneProcessingThreadInList:(id <LynkeosImageList>)list ;
{
   // Recombine the stacks in the list
   StandardImageStackerResult *res
      = [list getProcessingParameterWithRef:myStandardImageStackerResult
                              forProcessing:myImageStackerRef];

   if ( res == nil )
   {
      res = [[[StandardImageStackerResult alloc] init] autorelease];
      [list setProcessingParameter:res withRef:myStandardImageStackerResult
                     forProcessing:myImageStackerRef];
   }

   if ( _monoStack != nil )
   {
      if ( res->_mono != nil )
         [res->_mono add:_monoStack];
      else
         res->_mono = [_monoStack retain];
   }
   if ( _rgbStack != nil )
   {
      if ( res->_rgb != nil )
         [res->_rgb add:_rgbStack];
      else
         res->_rgb = [_rgbStack retain];
   }
}

- (void) finishAllProcessingInList: (id <LynkeosImageList>)list;
{
   // Recombine monochrome and RGB stacks if needed
   StandardImageStackerResult *res
      = [list getProcessingParameterWithRef:myStandardImageStackerResult
                              forProcessing:myImageStackerRef];
   LynkeosImageBuffer *stack = nil;

   if ( res->_rgb != nil )
      // Make it planar if needed
      stack = [getPlanarData(res->_rgb) retain];

   if ( res->_mono != nil )
   {
      if ( stack == nil )
         stack = [getPlanarData(res->_mono) retain];
      else
         // Add code knows how to add L with RGB
         [stack add:res->_mono];
   }

   if ( _rgbStack != nil )
      [_rgbStack release];
   _rgbStack = stack;
   if ( _monoStack != nil )
      [_monoStack release];
   _monoStack = nil;

   // And get rid of the recombining parameter
   [list setProcessingParameter:nil withRef:myStandardImageStackerResult 
                  forProcessing:myImageStackerRef];   
}

- (LynkeosImageBuffer*) stackingResult { return( _rgbStack ); }

@end
