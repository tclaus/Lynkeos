//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on 03/01/11.
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
#include <stdlib.h>
#include <objc/runtime.h>

#include "MyImageStacker_SigmaReject.h"

// Private (and temporary) parameter used to recombine the stacks
static NSString * const mySigmaRejectImageStackerResult
                           = @"SigmaRejectStackerResult";

/*!
 * @abstract Result for the sigma reject stacking strategy
 */
@interface SigmaRejectImageStackerResult : NSObject <LynkeosProcessingParameter,
                                             LynkeosMultiPassEnumeratorDelegate>
{
@public
   LynkeosImageBuffer* _sum;          //!< Sum (all passes)
   LynkeosImageBuffer* _sum2;         //!< square sum
   u_short                     _nStacked;     //!< Number of images in pass 1
   LynkeosImageBuffer* _mean;         //!< Mean pixel value
   LynkeosImageBuffer* _sigma;        //!< Standard deviation
   u_short*                    _count;        //!< Buffer of pixels count during pass2
   NSConditionLock*            _syncLock;     //!< Synchronisation barrier
}
@end

@interface MyImageStacker_SigmaReject(Private)
- (void) startNewPass ;
@end

@implementation SigmaRejectImageStackerResult
- (id) init
{
   self = [super init];
   if ( self != nil )
   {
      _sum = nil;
      _sum2 = nil;
      _nStacked = 0;
      _mean = nil;
      _sigma = nil;
      _count = NULL;
      _syncLock = [[NSConditionLock alloc] initWithCondition:0];
   }

   return( self );
}

- (void) dealloc
{
   if ( _sum != nil )
      [_sum release];
   if ( _sum2 != nil )
      [_sum2 release];
   if ( _mean != nil )
      [_mean release];
   if ( _sigma != nil )
      [_sigma release];
   if ( _count != NULL )
      free( _count );

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

#pragma mark = LynkeosMultiPassEnumeratorDelegate protocol
- (BOOL) shouldPerformOneMorePass:(id<LynkeosMultiPassEnumerator>)enumerator
{
   return( [enumerator pass] == 1 );
}
@end

@implementation MyImageStacker_SigmaReject(Private)

- (void) startNewPass
{
   const u_short maxThread = ([MyImageStacker supportParallelization] ? numberOfCpus : 1);
   SigmaRejectImageStackerResult *res = (SigmaRejectImageStackerResult*)
      [_list getProcessingParameterWithRef:mySigmaRejectImageStackerResult
                             forProcessing:myImageStackerRef];
   REAL **p;
   u_short x, y, c;
   u_short nThread;

   NSAssert(res != nil, @"Nil temporary result in sigma reject stacker");

   [res->_syncLock lock];
   // Performed for each thread
   if ( _sum != nil )
   {
      // Recombine the stacks in the list
      if ( res->_sum == nil )
         res->_sum = [_sum retain];
      else
         [res->_sum add:_sum];
      [_sum release];
      _sum = nil;

      if ( res->_sum2 == nil )
         res->_sum2 = [_sum2 retain];
      else
         [res->_sum2 add:_sum2];
      [_sum2 release];
      _sum2 = nil;

      res->_nStacked += _nbStacked;
      _nbStacked = 0;
   }
   nThread = [res->_syncLock condition] + 1;

   // Performed after complete recombination
   if ( nThread == maxThread )
   {
      // Compute the mean
      REAL s = 1.0/(REAL)res->_nStacked;
      [res->_sum multiplyWithScalar:s];
      res->_mean = res->_sum;
      res->_sum = nil;

      // The variance
      [res->_sum2 multiplyWithScalar:s];
      LynkeosImageBuffer *buf
         = [LynkeosImageBuffer imageBufferWithNumberOfPlanes:
                                                            res->_mean->_nPlanes
                                                           width:res->_mean->_w
                                                          height:res->_mean->_h];
      [res->_mean multiplyWith:res->_mean result:buf];
      [res->_sum2 substract:buf];

      // Then the standard deviation from the variance
      p = (REAL**)[res->_sum2 colorPlanes];
      for( c = 0; c < res->_sum2->_nPlanes; c++ )
         for( y = 0; y < res->_sum2->_h; y++ )
            for( x = 0; x < res->_sum2->_w; x++ )
            {
               REAL v = sqrt(stdColorValue(res->_sum2, x, y, c));
               SET_SAMPLE(p[c], x, y, res->_sum2->_padw, v);
            }
      res->_sigma = res->_sum2;
      res->_sum2 = nil;

      // Finally, reset the enumerator
      [_params->_enumerator reset];
   }
   [res->_syncLock unlockWithCondition:nThread];

   NSAssert(nThread <= maxThread, @"More thread than maximum in sigma reject");

   if ( nThread != maxThread )
   {
      // Wait for complete recombination
      [res->_syncLock lockWhenCondition:maxThread];
      [res->_syncLock unlock];
   }
}

@end

@implementation MyImageStacker_SigmaReject

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _params = nil;
      _sum = nil;
      _sum2 = nil;
      _nbStacked = 0;
      _count = NULL;
      _list = nil;
   }

   return( self );
}

- (id) initWithParameters: (id <NSObject>)params
                     list: (id <LynkeosImageList>)list
{
   if ( (self = [self init]) != nil )
   {
      SigmaRejectImageStackerResult *res;

      NSAssert1( [params isMemberOfClass:[MyImageStackerParameters class]],
                @"Wrong parameter class %s for Image stacker (sigma reject)",
                class_getName([params class]) );
      _params = (MyImageStackerParameters*)[params retain];
      _list = list;

      // First thread initialization
      [_params->_stackLock lock];

      res = (SigmaRejectImageStackerResult*)
         [_list getProcessingParameterWithRef:mySigmaRejectImageStackerResult
                                forProcessing:myImageStackerRef];
      if ( res == nil )
      {
         res = [[[SigmaRejectImageStackerResult alloc] init] autorelease];

         [_list setProcessingParameter:res
                               withRef:mySigmaRejectImageStackerResult
                         forProcessing:myImageStackerRef];

         // It cannot be predicted which thread will finish last, therefore
         // the parameter is the delegate, as it lives as long as the longest
         [_params->_enumerator setDelegate:res];
      }
      [_params->_stackLock unlock];
   }
   
   return( self );
}

- (void) dealloc
{
   if ( _params != nil )
      [_params release];
   if ( _sum != nil )
      [_sum release];
   if ( _sum2 != nil )
      [_sum2 release];
   if ( _count != NULL )
      free( _count );

   [super dealloc];
}

- (void) processImage: (LynkeosImageBuffer*)image
{
   // Take into account the end of pass
   if ( [image isKindOfClass:[NSNull class]] )
   {
      [self startNewPass];
   }
   else
   {
      NSAssert( _sum == nil || _sum->_nPlanes == [image numberOfPlanes],
               @"heterogeneous planes numbers in sigma reject stacking" );

      // Extract the data in a local image buffer
      LynkeosImageBuffer *buf
         = [LynkeosImageBuffer imageBufferWithNumberOfPlanes: [image numberOfPlanes]
                                                               width: [image width]
                                                              height: [image height]];
      [image convertToPlanar:[buf colorPlanes] withPlanes:buf->_nPlanes lineWidth:buf->_padw];

      // If this is the first image, create the empty stack buffer with the same
      // number of planes (taking into account the expansion factor)
      if ( _sum == nil )
         _sum = [[LynkeosImageBuffer imageBufferWithNumberOfPlanes: buf->_nPlanes
                                                                     width: buf->_w
                                                                    height: buf->_h]
                 retain];


      if ( [_params->_enumerator pass] == 1 )
      {
         // Allocate the square sum buffer if needed
         if ( _sum2 == nil )
            _sum2 = [[LynkeosImageBuffer imageBufferWithNumberOfPlanes: buf->_nPlanes
                                                                         width: buf->_w
                                                                        height: buf->_h]
                     retain];

         // Accumulate
         [_sum add:buf];

         // And accumulate the square values
         [buf multiplyWith:buf result:buf];
         [_sum2 add:buf];
         _nbStacked ++;
      }
      else
      {
         u_short x, y, c;
         REAL **p = (REAL**)[_sum colorPlanes];
         SigmaRejectImageStackerResult *res
            = (SigmaRejectImageStackerResult*)[_list getProcessingParameterWithRef:
                                                                               mySigmaRejectImageStackerResult
                                                                     forProcessing:myImageStackerRef];

         // Allocate the count buffer if needed
         if ( _count == NULL )
            _count = (u_short*)calloc( buf->_nPlanes*buf->_w*buf->_h,
                                      sizeof(u_short) );

         // Perform pixel addition only when below the standard deviation threshold
         for( c = 0; c < buf->_nPlanes; c++ )
         {
            for( y = 0; y < buf->_h; y++ )
            {
               for( x = 0; x < buf->_w; x++ )
               {
                  REAL v = stdColorValue(buf, x, y, c);
                  REAL m = stdColorValue(res->_mean, x, y, c);
                  REAL s = stdColorValue(res->_sigma, x, y, c);
                  if ( fabs(v - m) <= s*_params->_method.sigma.threshold )
                  {
                     v += stdColorValue(_sum, x, y, c);
                     SET_SAMPLE(p[c], x, y, _sum->_padw, v);
                     _count[(c*buf->_h + y)*buf->_w + x]++;
                  }
               }
            }
         }
      }
   }
}

- (void) finishOneProcessingThreadInList:(id <LynkeosImageList>)list ;
{
   if ( _sum != nil )
   {
      u_short x, y, c;

      // Recombine the stacks in the list
      SigmaRejectImageStackerResult *res = (SigmaRejectImageStackerResult*)
         [list getProcessingParameterWithRef:mySigmaRejectImageStackerResult
                               forProcessing:myImageStackerRef];
      NSAssert(res != nil,
               @"Nil temporary result in sigma reject last recombining");

      if ( res->_sum == nil )
         res->_sum = [_sum retain];
      else
         [res->_sum add:_sum];

      if ( res->_count == NULL )
         res->_count = (u_short*)calloc(_sum->_nPlanes*_sum->_w*_sum->_h,
                                        sizeof(u_short));

      for( c = 0; c < _sum->_nPlanes; c++ )
         for( y = 0; y < _sum->_h; y++ )
            for( x = 0; x < _sum->_w; x++ )
               res->_count[(c*_sum->_h + y)*_sum->_w + x] +=
                                          _count[(c*_sum->_h + y)*_sum->_w + x];
   }
}

- (void) finishAllProcessingInList: (id <LynkeosImageList>)list;
{
   REAL **p;
   u_short x, y, c;

   // Calculate the stats
   SigmaRejectImageStackerResult *res = (SigmaRejectImageStackerResult*)
      [list getProcessingParameterWithRef:mySigmaRejectImageStackerResult
                            forProcessing:myImageStackerRef];
   NSAssert( res != nil, @"No stacking result at sigma reject pass end" );

   // Compute the second pass mean, and store it
   p = (REAL**)[res->_sum colorPlanes];
   for( c = 0; c < res->_sum->_nPlanes; c++ )
      for( y = 0; y < res->_sum->_h; y++ )
         for( x = 0; x < res->_sum->_w; x++ )
         {
            REAL v;
            u_short n = res->_count[(c*res->_sum->_h + y)*res->_sum->_w + x];
            if ( n == 0 )
               v = 0.0;
            else
               v = stdColorValue(res->_sum, x, y, c)
                   / (REAL)n;
            SET_SAMPLE(p[c], x, y, res->_sum->_padw, v);
         }
   if ( _sum != nil )
      [_sum release];
   _sum = [res->_sum retain];

   // And get rid of the recombining parameter
   [list setProcessingParameter:nil withRef:mySigmaRejectImageStackerResult
                  forProcessing:myImageStackerRef];
}

- (LynkeosImageBuffer*) stackingResult { return( _sum ); }
@end
