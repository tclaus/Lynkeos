//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Sun Jun 17 2007.
//  Copyright (c) 2007-2020. Jean-Etienne LAMIAUD
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

#include "MyUserPrefsController.h"
#include "MyChromaticAlignerView.h"
#include "MyImageStackerPrefs.h"
#include "MyImageStacker.h"

#include "MyImageStacker_Standard.h"
#include "MyImageStacker_SigmaReject.h"
#include "MyImageStacker_Extrema.h"
#include "MyImageStacker_Calibration.h"

static NSString * const K_CROP_RECTANGLE_KEY = @"crop";
static NSString * const K_TRANSFORM_KEY = @"transform";
static NSString * const K_MONOFLAT_KEY       = @"monoflat";
static NSString * const K_STACK_METHOD_KEY   = @"method";
static NSString * const K_SIGMA_THRESHOLD_KEY= @"sigmaThreshold";
static NSString * const K_MIN_MAX_KEY        = @"extremumMinMax";
// V2 compatibility
static NSString * const K_SIZE_FACTOR_KEY    = @"sizef";

NSString * const myImageStackerRef = @"MyImageStacker";
NSString * const myImageStackerParametersRef = @"StackerParams";
NSString * const myImageStackerListRef = @"ListToStack";

@implementation MyImageStackerParameters
- (id) init
{
   self = [super init];
   if ( self != nil )
   {
      _cropRectangle = LynkeosMakeIntegerRect(0,0,0,0);
      _transform = [[NSAffineTransform transform] retain];
      _stackMethod = Stacking_Standard;
      _postStack = NoPostStack;
      _monochromeStack = NO;
      _livingThreads = 0;
      _imagesStacked = 0;
      _stackLock = nil;
   }

   return( self );
}

- (void) dealloc
{
   [_transform release];
   if ( _stackLock != nil )
      [_stackLock release];

   [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
   [encoder encodeRect: NSRectFromIntegerRect(_cropRectangle) 
                forKey: K_CROP_RECTANGLE_KEY];
   [encoder encodeObject:_transform forKey:K_TRANSFORM_KEY];
   [encoder encodeBool:_monochromeStack forKey:K_MONOFLAT_KEY];
   [encoder encodeInt:(int)_stackMethod forKey:K_STACK_METHOD_KEY];
   switch ( _stackMethod )
   {
      case Stacking_Standard:
      case Stacking_Calibration:
         // No parameters
         break;
      case Stacking_Sigma_Reject:
         [encoder encodeFloat:_method.sigma.threshold forKey:K_SIGMA_THRESHOLD_KEY];
         break;
      case Stacking_Extremum:
         [encoder encodeBool:_method.extremum.maxValue
                      forKey:K_MIN_MAX_KEY];
         break;
      default:
         NSAssert( NO, @"Invalid stacking mode" );
   }
}

- (id)initWithCoder:(NSCoder *)decoder
{
   self = [self init];

   if ( self != nil )
   {
      _cropRectangle = LynkeosIntegerRectFromNSRect(
                               [decoder decodeRectForKey:K_CROP_RECTANGLE_KEY]);
      if ( [decoder containsValueForKey:K_TRANSFORM_KEY] )
      {
         [_transform release];
         _transform = [[decoder decodeObjectForKey:K_TRANSFORM_KEY] retain];
      }
      else if ( [decoder containsValueForKey:K_SIZE_FACTOR_KEY] )
      {
         double factor = [decoder decodeDoubleForKey:K_SIZE_FACTOR_KEY];
         NSAffineTransformStruct t = {factor, 0.0, 0.0, factor, 0.0, 0.0};
         [_transform setTransformStruct:t];
      }
      _monochromeStack = [decoder decodeBoolForKey:K_MONOFLAT_KEY];
      _stackMethod = [decoder decodeIntForKey:K_STACK_METHOD_KEY];
      switch ( _stackMethod )
      {
         case Stacking_Standard:
         case Stacking_Calibration:
            // No parameters
            break;
         case Stacking_Sigma_Reject:
            _method.sigma.threshold =
               [decoder decodeFloatForKey:K_SIGMA_THRESHOLD_KEY];
            break;
         case Stacking_Extremum:
            _method.extremum.maxValue =
               [decoder decodeBoolForKey:K_MIN_MAX_KEY];
            break;
      }
      _stackLock = [[NSConditionLock alloc] init];
   }

   return( self );
}
@end

@implementation MyImageStackerList
- (id) init
{
   self = [super init];
   if ( self != nil )
      _list = nil;

   return( self );
}
@end

@implementation MyImageStacker

+ (ParallelOptimization_t) supportParallelization
{
   return( [[NSUserDefaults standardUserDefaults] integerForKey:
                                                         K_PREF_STACK_MULTIPROC]
           & ListThreadsOptimizations);
}

- (id <LynkeosProcessing>) initWithDocument: (id <LynkeosDocument>)document
                                 parameters:(id <NSObject>)params
{
   NSAssert( params != nil && [params isKindOfClass:[MyImageStackerList class]],
             @"No list argument for stack start" );
   self = [self init];
   if ( self == nil )
      return( self );

   _document = document;
   _list = ((MyImageStackerList*)params)->_list;
   NSAssert( _list != nil, @"Failed to find which list to stack" );
   _params = [_list getProcessingParameterWithRef:myImageStackerParametersRef
                                    forProcessing:myImageStackerRef];
   NSAssert( _params != nil, @"Failed to find stack parameters" );
   _imagesStacked = 0;

   // Allocate the strategy
   switch ( _params->_stackMethod )
   {
      case Stacking_Standard:
         _stackingStrategy =
            [[MyImageStacker_Standard alloc] initWithParameters:_params
                                                           list:_list];
         break;
      case Stacking_Sigma_Reject:
         _stackingStrategy =
            [[MyImageStacker_SigmaReject alloc] initWithParameters:_params
                                                              list:_list];
         break;
      case Stacking_Extremum:
         _stackingStrategy =
            [[MyImageStacker_Extrema alloc] initWithParameters:_params
                                                          list:_list];
         break;
      case Stacking_Calibration:
         _stackingStrategy =
            [[MyImageStacker_Calibration alloc]  initWithParameters:_params
                                                               list:_list];
         break;
      default:
         NSAssert( NO, @"Invalid stacking method" );
   }

   [_params->_stackLock lock];
   _params->_livingThreads++;
   [_params->_stackLock unlockWithCondition:_params->_livingThreads];

   return( self );
}

- (void) dealloc
{
   [_stackingStrategy release];

   [super dealloc];
}

- (void) processItem :(id <LynkeosProcessableItem>)item
{
   // When in multipass, the enumerator returns a NSNull at end of one pass
   if ([item isKindOfClass:[NSNull class]])
   {
      [_stackingStrategy processImage:(LynkeosImageBuffer*)item];
   }
   else
   {
      LynkeosImageBuffer* image = nil;
      NSPoint offsets[3] = {0.0, 0.0, 0.0};
      LynkeosIntegerRect r = _params->_cropRectangle;

      id <LynkeosAlignResult> alignRes
         = (id <LynkeosAlignResult>)[item getProcessingParameterWithRef: LynkeosAlignResultRef
                                                          forProcessing: LynkeosAlignRef];

      if ( alignRes != nil )
      {
         NSAffineTransform *transform
            = [[[NSAffineTransform alloc] initWithTransform:[alignRes alignTransform]] autorelease];
         NSAffineTransformStruct t;
         u_short c;

         // Take expansion into account, and convert to bitmap coordinate system
         [transform appendTransform:_params->_transform];
         t = [transform transformStruct];
         const CGFloat factor = sqrt( t.m11*t.m22 - t.m12*t.m21 );
         const CGFloat imgHeight = [item imageSize].height;
         t.tX += t.m21*imgHeight;
         t.tY = (factor - t.m22)*imgHeight - t.tY;
         t.m12 *= -1.0;
         t.m21 *= -1.0;

         r.origin.y =  imgHeight*factor - r.origin.y - r.size.height;

         // Take the chromatic dispersion correction into account
         MyChromaticAlignParameter *chroma
            = [item getProcessingParameterWithRef:myChromaticAlignerOffsetsRef
                                    forProcessing:myChromaticAlignerRef];

         // Prepare the offsets, with conversion to the bitmap coordinate system
         for( c = 0; c < [item numberOfPlanes]; c++ )
         {
            if ( chroma != nil )
            {
               offsets[c].x += chroma->_offsets[c].x * factor;
               offsets[c].y -= chroma->_offsets[c].y * factor;
            }
         }

         // Try first to get a custom calibrated image
         image = [item getCustomImageSampleinRect:r withTransform:t withOffsets:offsets];
         // Otherwise, get a standard one
         if (image == nil)
            [item getImageSample:&image inRect:r withTransform:t withOffsets:offsets];
         if (image == nil)
            NSLog(@"Could not get sample from image");
      }

      if ( image != nil )
      {
         // Accumulate
         [_stackingStrategy processImage:image];
         _imagesStacked++;

         // As the item is not modified, force a notification
         [_document itemWasProcessed:item];
      }
   }
}

- (void) finishProcessing
{
   const NSInteger maxThreads
      = ([[self class] supportParallelization] ? numberOfCpus : 1);

   // Take control of the list (but only when all threads have started)
   [_params->_stackLock lockWhenCondition:maxThreads];

   // Finish the processing for this thread
   [_stackingStrategy finishOneProcessingThreadInList:_list];

   _params->_imagesStacked += _imagesStacked;   

   // Finalize everything if we are the last thread
   _params->_livingThreads--;
   if ( _params->_livingThreads == 0 )
   {
      double b = 0.0, w = -1.0;

      [_stackingStrategy finishAllProcessingInList:_list];

      // Maybe, all this was for nothing !...
      LynkeosImageBuffer* stack = [_stackingStrategy stackingResult];
      if ( stack != nil )
      {
         // Well... maybe not
         // Perform any postprocessing
         switch( _params->_postStack )
         {
            case NoPostStack:
               // "Monochromize" the stack if required
               if ( _params->_monochromeStack && [stack numberOfPlanes] != 1 )
                  [stack normalizeWithFactor:1.0
                                        mono:_params->_monochromeStack];
               break;
            case MeanStack:
               [stack normalizeWithFactor:1.0/(double)_params->_imagesStacked
                                     mono:_params->_monochromeStack];
               break;
            case NormalizeStack:
               // Normalize the stack to max = 1.0
               [stack normalizeWithFactor:0.0 mono:_params->_monochromeStack];
               b = 0.0;
               w = 1.0;
               break;
            default:
               NSAssert1( NO, @"Invalid post stack action : %d", _params->_postStack );
         }
      }

      // Put the stack in the list
      [_list setOriginalImage:stack];
      if ( w > b )
         [_list setBlackLevel:b whiteLevel:w gamma:1.0];
   }

   [_params->_stackLock unlock];
}
@end
