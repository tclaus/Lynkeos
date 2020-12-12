//
//  Lynkeos
//  $Id:$
//
//  Created by Jean-Etienne LAMIAUD on 15/01/2014.
//  Copyright 2014-2020 Jean-Etienne LAMIAUD. All rights reserved.
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

#include "MyImageStacker_Calibration.h"

static NSString * const myCalibrationImageStackerResult = @"CalibrationStackerResult";

/*!
 * @abstract Result of the standard stacking strategy
 */
@interface CalibrationImageStackerResult : NSObject <LynkeosProcessingParameter>
{
@public
   LynkeosImageBuffer* _stack; //!< Stack of calibration images
}
@end

@implementation CalibrationImageStackerResult
- (id) init
{
   self = [super init];
   if ( self != nil )
      _stack = nil;

   return( self );
}

- (void) dealloc
{
   if ( _stack != nil )
      [_stack release];

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


@implementation MyImageStacker_Calibration

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _params = nil;
      _stack = nil;
   }

   return( self );
}

- (id) initWithParameters: (id <NSObject>)params
                     list: (id <LynkeosImageList>)list
{
   if ( (self = [self init]) != nil )
   {
      NSAssert1( [params isMemberOfClass:[MyImageStackerParameters class]],
                @"Wrong parameter class %s for Image stacker (calibration)",
                class_getName([params class]) );
      _params = (MyImageStackerParameters*)[params retain];
   }

   return( self );
}

- (void) dealloc
{
   if ( _stack != nil )
      [_stack release];

   [super dealloc];
}

- (void) processImage: (LynkeosImageBuffer*)image
{
   // If this is the first image, set it into the stack
   if ( _stack == nil )
      _stack = [image retain];

   // Otherwise accumulate
   else
      [_stack add:image];
}

- (void) finishOneProcessingThreadInList:(id <LynkeosImageList>)list ;
{
   if ( _stack != nil )
   {
      // Accumulate intermediate results in the list
      CalibrationImageStackerResult *res
         = [list getProcessingParameterWithRef:myCalibrationImageStackerResult
                                 forProcessing:myImageStackerRef];

      if ( res == nil )
      {
         res = [[[CalibrationImageStackerResult alloc] init] autorelease];
         res->_stack = [_stack retain];
         [list setProcessingParameter:res withRef:myCalibrationImageStackerResult
                        forProcessing:myImageStackerRef];
      }
      else
         [res->_stack add:_stack];
   }
}

- (void) finishAllProcessingInList: (id <LynkeosImageList>)list;
{
   // Retrieve the final stack
   CalibrationImageStackerResult *res
      = [list getProcessingParameterWithRef:myCalibrationImageStackerResult
                              forProcessing:myImageStackerRef];
   if ( _stack != nil )
      [_stack release];
   _stack = [res->_stack retain];

   // And get rid of the recombining parameter
   [list setProcessingParameter:nil withRef:myCalibrationImageStackerResult
                  forProcessing:myImageStackerRef];
}

- (LynkeosImageBuffer*) stackingResult { return( _stack ); }

@end
