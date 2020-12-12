//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Fri Mar 07 2005.
//  Copyright (c) 2005-2020. Jean-Etienne LAMIAUD
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
#include <string.h>
#include <pthread.h>

#ifdef GNUSTEP
#include <GNUstepBase/GSObjCRuntime.h>
#else
#include <objc/objc-class.h>
#endif

#import <AppKit/NSGraphics.h>

#include "processing_core.h"
#include "LynkeosImageBuffer.h"
#include "LynkeosImageBufferAdditions.h"

#include "LynkeosGammaCorrecter.h"

/*!
 * @abstract Compatibility class for file opening
 */
@interface LynkeosStandardImageBuffer : NSObject <NSCoding>
{
}
@end

@implementation LynkeosStandardImageBuffer

- (id) initWithCoder:(NSCoder *)decoder
{
   // Initialize a LynkeosImageBuffer instead
   [self release];
   self = (LynkeosStandardImageBuffer*)[[LynkeosImageBuffer alloc] initWithCoder:decoder];
   return self;
}

- (void) encodeWithCoder:(NSCoder *)coder
{
   // This class is only used to open files
   [self doesNotRecognizeSelector:_cmd];
}
@end

#ifdef DOUBLE_PIXELS
#define powerof(x,y) pow(x,y)
#else
#define powerof(x,y) powf(x,y)
#endif

#define K_PLANES_NUMBER_KEY     @"planes"
#define K_IMAGE_WIDTH_KEY       @"width"
#define K_IMAGE_HEIGHT_KEY      @"height"
#define K_SINGLE_PRECISION_KEY  @"float"
#define K_IMAGE_DATA_KEY	     @"data"

/*!
 * @abstract Multiply method for strategy "without vectors"
 */
static void std_image_mul_one_line(LynkeosImageBuffer *a,
                                   ArithmeticOperand_t *b,
                                   LynkeosImageBuffer *res,
                                   u_short y)
{
   u_short x, c, ct;

   for( x = 0; x < a->_w; x++ )
      for( c = 0; c < a->_nPlanes; c++ )
      {
         if ( b->term->_nPlanes == 1 )
            ct = 0;
         else
            ct = c;
         REAL r = colorValue(a,x,y,c) * colorValue(b->term,x,y,ct);
         colorValue(res,x,y,c) = r;
      }
}

#if !defined(DOUBLE_PIXELS) || defined(__SSE2__) || defined(__SSE3__)
/*!
 * @abstract Multiply method for strategy "with vectors"
 */
static void vect_image_mul_one_line(LynkeosImageBuffer *a,
                                   ArithmeticOperand_t *b,
                                   LynkeosImageBuffer *res,
                                   u_short y )
{
   u_short x, c, ct;

   for( x = 0; x < a->_w; x += 4 )
   {
      for( c = 0; c < a->_nPlanes; c++ )
      {
         REALVECT r = *((REALVECT*)&colorValue(a,x,y,c));

         if ( b->term->_nPlanes == 1 )
            ct = 0;
         else
            ct = c;

         r *= *((REALVECT*)&colorValue(b->term,x,y,ct));
         *((REALVECT*)&colorValue(res,x,y,c)) = r;
      }
   }
}
#endif

/*!
 * @abstract Scaling method for strategy "without vectors"
 */
static void std_image_scale_one_line(LynkeosImageBuffer *a,
                                   ArithmeticOperand_t *b,
                                   LynkeosImageBuffer *res,
                                   u_short y )
{
   u_short x, c;
   const REAL s =
#ifdef DOUBLE_PIXELS
   b->dscalar
#else
   b->fscalar
#endif
   ;

   for( x = 0; x < a->_w; x++ )
      for( c = 0; c < a->_nPlanes; c++ )
      {
         REAL r = colorValue(a,x,y,c) * s;
         colorValue(res,x,y,c) = r;
      }
}

/*!
 * @abstract Scaling method for strategy "with vectors"
 */
#if !defined(DOUBLE_PIXELS) || defined(__SSE2__) || defined(__SSE3__)
static void vect_image_scale_one_line(LynkeosImageBuffer *a,
                                     ArithmeticOperand_t *b,
                                     LynkeosImageBuffer *res,
                                     u_short y )
{
   const REAL s =
#ifdef DOUBLE_PIXELS
      b->dscalar
#else
      b->fscalar
#endif
      ;
   const REALVECT scalar = { s, s, s, s };
   u_short x, c;

   for( x = 0; x < a->_w; x += 4 )
      for( c = 0; c < a->_nPlanes; c++ )
      {
         REALVECT r = *((REALVECT*)&colorValue(a,x,y,c)) * scalar;
         *((REALVECT*)&colorValue(res,x,y,c)) = r;
      }
}
#endif

/*!
 * @abstract Substract and multiply method for strategy "without vectors"
 */
static void std_image_bias_scale_one_line(LynkeosImageBuffer *a,
                                     ArithmeticOperand_t *b,
                                     LynkeosImageBuffer *res,
                                     u_short y )
{
   u_short x, c;
   const REAL o =
#ifdef DOUBLE_PIXELS
   b[0].dscalar
#else
   b[0].fscalar
#endif
   ;
   const REAL s =
#ifdef DOUBLE_PIXELS
   b[1].dscalar
#else
   b[1].fscalar
#endif
   ;

   for( x = 0; x < a->_w; x++ )
      for( c = 0; c < a->_nPlanes; c++ )
      {
         REAL r = (colorValue(a,x,y,c) -  o) * s;
         colorValue(res,x,y,c) = r;
      }
}

/*!
 * @abstract Substract and multiply method for strategy "with vectors"
 */
#if !defined(DOUBLE_PIXELS) || defined(__SSE2__) || defined(__SSE3__)
static void vect_image_bias_scale_one_line(LynkeosImageBuffer *a,
                                      ArithmeticOperand_t *b,
                                      LynkeosImageBuffer *res,
                                      u_short y )
{
   const REAL o =
#ifdef DOUBLE_PIXELS
   b[0].dscalar
#else
   b[0].fscalar
#endif
   ;
   const REAL s =
#ifdef DOUBLE_PIXELS
   b[1].dscalar
#else
   b[1].fscalar
#endif
   ;
   const REALVECT scalar = { s, s, s, s };
   const REALVECT bias = { o, o, o, o };
   u_short x, c;

   for( x = 0; x < a->_w; x += 4 )
      for( c = 0; c < a->_nPlanes; c++ )
      {
         REALVECT r = (*((REALVECT*)&colorValue(a,x,y,c)) - bias) * scalar;
         *((REALVECT*)&colorValue(res,x,y,c)) = r;
      }
}
#endif

/*!
 * @abstract Divide method for strategy "without vectors"
 */
static void std_image_div_one_line(LynkeosImageBuffer *a,
                                   ArithmeticOperand_t *b,
                                   LynkeosImageBuffer *res,
                                   u_short y )
{
   u_short x, c, ct;

   for( x = 0; x < a->_w; x++ )
      for( c = 0; c < a->_nPlanes; c++ )
      {
         if ( b->term->_nPlanes == 1 )
            ct = 0;
         else
            ct = c;

         REAL n = colorValue(a,x,y,c), d = colorValue(b->term,x,y,ct), r;

         if ( d != 0.0 )
            r = n / d;
         else
            r = 0.0; // Arbitrary value to avoid NaN
         colorValue(res,x,y,c) = r;
      }
}

#if !defined(DOUBLE_PIXELS) || defined(__SSE2__) || defined(__SSE3__)

/*!
 * @abstract Divide method for strategy "with vectors"
 */
static void vect_image_div_one_line(LynkeosImageBuffer *a,
                                    ArithmeticOperand_t *b,
                                    LynkeosImageBuffer *res,
                                    u_short y )
{
   u_short x, c, ct;

   for( x = 0; x < a->_w; x += 4 )
   {
      for( c = 0; c < a->_nPlanes; c++ )
      {
         REALVECT n = *((REALVECT*)&colorValue(a,x,y,c));

         if ( b->term->_nPlanes == 1 )
            ct = 0;
         else
            ct = c;

         REALVECT d = *((REALVECT*)&colorValue(b->term,x,y,ct));

         *((REALVECT*)&colorValue(res,x,y,c)) = n / d;
      }
   }
}
#endif

@interface ImageTileInfo : NSObject
{
@public
   LynkeosIntegerRect rect;
   double black[4], white[4], imgMin, vmin, vmax, gain;
   LynkeosGammaCorrecter *gammaCorrect[3];
   LynkeosImageBuffer *img;
}

- (id) initInRect:(LynkeosIntegerRect)rect
        withBlack:(double*)black white:(double*)white
            imageMin:(double)imgMin valMin:(double)vmin valMax:(double)vmax
                gain:(double)gain gammaCorrecter:(LynkeosGammaCorrecter**)gammaCorrect
               image:(LynkeosImageBuffer*)img;
@end

static size_t dataProviderCallBack (void * __nullable info, void *  buffer, off_t pos, size_t cnt)
{
   ImageTileInfo *tileInfo = (ImageTileInfo*)info;
   if ([tileInfo retainCount] <= 0)
      NSLog(@"tileInfo already released");
   LynkeosImageBuffer *img = tileInfo->img;
   const size_t tileSize = 4 * tileInfo->rect.size.width * tileInfo->rect.size.height;
   const size_t end = ((size_t)pos < tileSize ? MIN(cnt, tileSize - pos) : 0);
   u_char *buf = (u_char*)buffer;
   double colorGain[3];
   size_t i;

   for (i = 0; i < img->_nPlanes; i++)
      colorGain[i] = (tileInfo->white[i] > tileInfo->black[i] ?
                      (tileInfo->vmax - tileInfo->vmin)/(tileInfo->white[i] - tileInfo->black[i]) :
                      0.0);

   for (i = 0; i < end; i++)
   {
      const size_t imgIdx = pos + i;
      const u_short x = ((imgIdx / 4) % tileInfo->rect.size.width) + tileInfo->rect.origin.x,
                    y = (imgIdx / 4 / tileInfo->rect.size.width) + tileInfo->rect.origin.y;
      const u_short c = imgIdx % 4, ic = (img->_nPlanes != 1 ? c : 0);
      u_char v;

      if (c < 3)
         v = screenCorrectedValue(tileInfo->gammaCorrect[ic],
                                  ( (colorValue(img,x,y,ic) - tileInfo->black[ic]) * colorGain[ic]
                                    + tileInfo->imgMin - tileInfo->black[img->_nPlanes] )
                                  * tileInfo->gain);
      else
         v = 255;

      buf[i] = v;
   }

   return end;
}

static void dataProviderRelease(void * __nullable info)
{
   [(ImageTileInfo*)info release];
}

/*!
 * @abstract Phases of the parallel processing for the lock condition
 */
typedef enum
{
   OperationInited,
   OperationStarted,
   OperationEnded
} ParallelImageOperationState_t;

/*!
 * @abstract Record of data needed for parallelized multiplication
 */
@interface ParallelImageMultiplyArgs : NSObject
{
@public
   ArithmeticOperand_t *op;         //!< Operands
   LynkeosImageBuffer *res; //!< Operation result
   u_short *y;                      //!< Current line
   //! Startegy method for performing the operation on one line
   void(*processOneLine)(LynkeosImageBuffer*,
                         ArithmeticOperand_t*,
                         LynkeosImageBuffer*,
                         u_short);
   NSConditionLock *lock;           //!< Exclusive access to this object
   u_short startedThreads;         //!< Total number of started threads
   u_short livingThreads;         //!< Number of still living threads
}
@end

/*!
 * @abstract Private methods
 */
@interface LynkeosImageBuffer(Private)
/*!
 * @abstract Stacks one color plane
 * @param plane The color plane to stack
 * @param image The image to add to ourselves
 */
- (void) stackPlane:(u_short)plane fromImage:(LynkeosImageBuffer*)image ;

/*!
 * @abstract Stack the plane 0 of the argument image into our luminance channel
 * @param image The image to add to ourselves
 */
- (void) stackLRGBfromImage:(LynkeosImageBuffer*)image ;

/*!
 * @abstract "Shared" multiply method
 */
- (void) one_thread_process_image:(id)arg ;

/*!
 * @abstract Multiply method for strategy "no parallelization"
 */
- (void) std_image_process:(ArithmeticOperand_t*)op
                    result:(LynkeosImageBuffer*)res 
            processOneLine:(void(*)(LynkeosImageBuffer*,
                                    ArithmeticOperand_t*,
                                    LynkeosImageBuffer*,
                                    u_short))processOneLine ;

/*!
 * @abstract Multiply method for strategy "parallelize"
 */
- (void) parallel_image_process:(ArithmeticOperand_t*)op
                         result:(LynkeosImageBuffer*)res 
            processOneLine:(void(*)(LynkeosImageBuffer*,
                                    ArithmeticOperand_t*,
                                    LynkeosImageBuffer*,
                                    u_short))processOneLine ;
@end

@implementation ParallelImageMultiplyArgs
@end

@implementation ImageTileInfo

- (id) initInRect:(LynkeosIntegerRect)rect
        withBlack:(double*)black white:(double*)white
         imageMin:(double)imgMin valMin:(double)vmin valMax:(double)vmax
             gain:(double)gain gammaCorrecter:(LynkeosGammaCorrecter**)gammaCorrect
            image:(LynkeosImageBuffer*)img
{
   if ((self = [super init]) != nil)
   {
      for (int i = 0; i <= img->_nPlanes; i++)
      {
         self->black[i] = black[i];
         self->white[i] = white[i];
         if (i < img->_nPlanes)
            self->gammaCorrect[i] = gammaCorrect[i];
      }
      self->rect = rect;
      self->imgMin = imgMin;
      self->vmax = vmax;
      self->vmin = vmin;
      self->gain = gain;
      self->img = [img retain];
   }
   return self;
}

- (void) dealloc
{
   for (int i = 0; i < img->_nPlanes; i++)
      [gammaCorrect[i] releaseCorrecter];
   [img release];
   [super dealloc];
}
@end

@implementation LynkeosImageBuffer(Private)
/*!
 * Both layers are required to have the same size.
 */
- (void) stackPlane:(u_short)plane fromImage:(LynkeosImageBuffer*)image
{
   u_short x, y;

   for( y = 0; y < _h; y++ )
      for( x = 0; x < _w; x++ )
         colorValue(self,x,y,plane) += colorValue(image,x,y,plane);
}

/*!
 * Both layers are required to have the same size.
 */
- (void) stackLRGBfromImage:(LynkeosImageBuffer*)image
{
   u_short x, y;

   /* Add the monochrome layer */
   for( y = 0; y < _h; y++ )
   {
      for( x = 0; x < _w; x++ )
      {
         REAL red = redValue(self,x,y),
              green = greenValue(self,x,y),
              blue = blueValue(self,x,y);
         REAL lratio = 1.0 + 3*(colorValue(image,x, y,0))/(red + green + blue);

         redValue(self,x,y) = red * lratio;
         greenValue(self,x,y) = green * lratio;
         blueValue(self,x,y) = blue * lratio;
      }
   }
}

- (void) one_thread_process_image:(id)arg
{
   ParallelImageMultiplyArgs * const args = arg;
   u_short ourY = 0;

   // Count up on entry
   [args->lock lock];
   if ( args->startedThreads < numberOfCpus )
      args->startedThreads++;
   else
      NSLog( @"Too much thread start in one_thread_process_image" );
   args->livingThreads++;
   if ( args->startedThreads == numberOfCpus )
      [args->lock unlockWithCondition:OperationStarted];
   else
      [args->lock unlock];

   // Process by sharing lines with other threads
   for(;;)
   {
      ourY = *(args->y);
      if ( ourY >= _h )
         break;
      if ( __sync_bool_compare_and_swap(args->y, ourY, ourY + 1) )
      {
         args->processOneLine( self, args->op, args->res, ourY );
      }
   }

   // Count down on exit
   [args->lock lockWhenCondition:OperationStarted];
   if ( args->livingThreads > 0 )
      args->livingThreads--;
   else
      NSLog( @"Too much thread end in one_thread_process_image" );

   if ( args->livingThreads == 0 )
      [args->lock unlockWithCondition:OperationEnded];
   else
      [args->lock unlock];
}

- (void) std_image_process:(ArithmeticOperand_t*)op
                    result:(LynkeosImageBuffer*)res 
            processOneLine:(void(*)(LynkeosImageBuffer*,
                                    ArithmeticOperand_t*,
                                    LynkeosImageBuffer*,
                                    u_short))processOneLine
{
   u_short y;
   for( y = 0; y < _h; y++ )
      processOneLine( self, op, res, y );
}

/*!
 * @abstract Multiply method for strategy "parallelize"
 */
- (void) parallel_image_process:(ArithmeticOperand_t*)op
                         result:(LynkeosImageBuffer*)res 
                 processOneLine:(void(*)(LynkeosImageBuffer*,
                                         ArithmeticOperand_t*,
                                         LynkeosImageBuffer*,
                                         u_short))processOneLine
{
   NSConditionLock *lock =
                    [[NSConditionLock alloc] initWithCondition:OperationInited];
   u_short y = 0;
   ParallelImageMultiplyArgs *args = [[ParallelImageMultiplyArgs alloc] init];
   int i;

   args->op = op;
   args->res = res;
   args->y = &y;
   args->lock = lock;
   args->processOneLine = processOneLine;
   args->startedThreads = 0;
   args->livingThreads = 0;

   // Start a thread for each "other processor"
   for( i =  1; i < numberOfCpus; i++ )
      [NSThread detachNewThreadSelector:@selector(one_thread_process_image:)
                               toTarget:self
                             withObject:args];

   // Do our part of the job
   [self one_thread_process_image:args];

   // Finally, wait or all threads completion
   [lock lockWhenCondition:OperationEnded];
   [lock unlock];

   [lock release];
   [args release];
}

@end

@implementation LynkeosImageBuffer

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _nPlanes = 0;
      _w = 0;
      _padw = 0;
      _h = 0;
      [self resetMinMax];
      _data = NULL;
      _freeWhenDone = NO;

      if ( hasSIMD )
      {
         _mul_one_image_line = vect_image_mul_one_line;
         _scale_one_image_line = vect_image_scale_one_line;
         _bias_scale_one_image_line = vect_image_bias_scale_one_line;
         _div_one_image_line = std_image_div_one_line;
      }
      else
      {
         _mul_one_image_line = std_image_mul_one_line;
         _scale_one_image_line = std_image_scale_one_line;
         _bias_scale_one_image_line = std_image_bias_scale_one_line;
         _div_one_image_line = vect_image_div_one_line;
      }

      _process_image_selector =
                            @selector(std_image_process:result:processOneLine:);
      _process_image = (void(*)(id,SEL,ArithmeticOperand_t*,
                         LynkeosImageBuffer*,
                         void(*)(LynkeosImageBuffer*,
                                 ArithmeticOperand_t*,
                                 LynkeosImageBuffer*,
                                 u_short)))
                               [self methodForSelector:_process_image_selector];
   }

   return( self );
}

- (id) copyWithZone:(NSZone *)zone
{
   return( [[LynkeosImageBuffer allocWithZone:zone] initWithData:_data
                                                       copy:YES
                                               freeWhenDone:YES
                                             numberOfPlanes:_nPlanes
                                                      width:_w
                                                paddedWidth:_padw
                                                     height:_h] );
}

- (id) initWithData:(void*)data
               copy:(BOOL)copy  freeWhenDone:(BOOL)freeWhenDone
     numberOfPlanes:(u_short)nPlanes 
              width:(u_short)w paddedWidth:(u_short)padw height:(u_short)h
{
   u_short c;

   NSAssert( nPlanes == 1 || nPlanes == 3, 
             @"MyImageBuffer handles only monochrome or RGB images" );

   if ( (self = [self init]) != nil )
   {
      u_long dataSize;

      _nPlanes = nPlanes;
      _w = w;
      _padw = padw;
      _h = h;

      if ( copy )
      {
         dataSize = _padw*_h*_nPlanes*sizeof(REAL);
         _data = malloc( dataSize );
         NSAssert1(_data != NULL,
            @"Failed to allocate a LynkeosImageBuffer of %ld bytes",
            dataSize);

         if (data != NULL )
            memcpy( _data, data, dataSize );
         else
            memset( _data, 0, dataSize );
         _freeWhenDone = YES;
      }
      else
      {
         _data = data;
         _freeWhenDone = freeWhenDone;
      }

      // Vectorized instructions are only usable if aligned
      if ( (padw % sizeof(REALVECT)) != 0
           || ((u_long)_data % sizeof(REALVECT)) != 0 )
      {
         _mul_one_image_line = std_image_mul_one_line;
         _scale_one_image_line = std_image_scale_one_line;
      }

      for( c = 0; c < nPlanes; c++ )
         _planes[c] = &((REAL*)_data)[c*_h*_padw];
   }

   return( self );
}

- (id) initWithNumberOfPlanes:(u_short)nPlanes 
                        width:(u_short)w height:(u_short)h
{
   return( [self initWithData:NULL copy:YES freeWhenDone:YES
               numberOfPlanes:nPlanes width:w
                  paddedWidth: // Padded for SIMD
                     sizeof(REALVECT)*((w+sizeof(REALVECT)-1)/sizeof(REALVECT))
                       height:h] );
}

- (void) dealloc
{
   if ( _freeWhenDone )
      free( _data );
   [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
#ifndef DOUBLE_PIXELS
#define SwappedReal NSSwappedFloat
#define ConvertHostToSwappedReal NSConvertHostFloatToSwapped
#else
#define SwappedReal NSSwappedDouble
#define ConvertHostToSwappedReal NSConvertHostDoubleToSwapped
#endif
   NSMutableData *dataWrapper = nil;
   u_short x, y, c;
   SwappedReal *buf;
   u_long i;

   [encoder encodeInt:_nPlanes forKey:K_PLANES_NUMBER_KEY];
   [encoder encodeInt:_w forKey:K_IMAGE_WIDTH_KEY];
   [encoder encodeInt:_h forKey:K_IMAGE_HEIGHT_KEY];

   // Encode data
   dataWrapper = [NSMutableData dataWithLength:
                                            _w*_h*_nPlanes*sizeof(SwappedReal)];

   buf = [dataWrapper mutableBytes];
   for( c = 0, i = 0; c < _nPlanes; c++ )
   {
      for( y = 0; y < _h; y++ )
      {
         for( x = 0; x < _w; x++ )
         {         
            // Data is always archived as planar         
            buf[i] = ConvertHostToSwappedReal(colorValue(self,x,y,c));
            i++;
         }
      }
   }

   [encoder encodeBool:
#ifndef DOUBLE_PIXELS
      YES
#else
      NO
#endif
                forKey:K_SINGLE_PRECISION_KEY];
   [encoder encodeObject:dataWrapper forKey:K_IMAGE_DATA_KEY];
}

- (id)initWithCoder:(NSCoder *)decoder
{
   NSData *dataWrapper = [decoder decodeObjectForKey:K_IMAGE_DATA_KEY];
   u_short planes = [decoder decodeIntForKey:K_PLANES_NUMBER_KEY];
   u_short w = [decoder decodeIntForKey:K_IMAGE_WIDTH_KEY];
   u_short h = [decoder decodeIntForKey:K_IMAGE_HEIGHT_KEY];
   BOOL isFloat = [decoder decodeBoolForKey:K_SINGLE_PRECISION_KEY];

   if ( dataWrapper == nil || planes == 0 || w == 0 || h == 0 )
   {
      [self release];
      self = nil;
   }

   if ( self != nil )
      // Allocate our buffer
      self = [self initWithNumberOfPlanes:planes width:w height:h];

   if ( self != nil )
   {
      // And copy the data in it
      u_short x, y, c;
      const void *buf;
      u_long i;

      buf = [dataWrapper bytes];
      for( c = 0, i=0; c < planes; c++ )
      {
         for( y = 0; y < h; y++ )
         {
            for( x = 0; x < w; x++ )
            {
               REAL v;

               // Data is always archived as planar
               if (isFloat )
                  v = NSConvertSwappedFloatToHost( ((NSSwappedFloat*)buf)[i] );
               else
                  v = NSConvertSwappedDoubleToHost( ((NSSwappedDouble*)buf)[i] );
               i++;

               colorValue(self,x,y,c) = v;
            }
         }
      }
   }

   return( self );
}

- (size_t) memorySize
{
   return( class_getInstanceSize([self class])
           + _nPlanes*_padw*_h*sizeof(REAL) );
}

- (void) setOperatorsStrategy:(ImageOperatorsStrategy_t)strategy
{
   switch( strategy )
   {
      case StandardStrategy:
         _process_image_selector =
                            @selector(std_image_process:result:processOneLine:);
         _process_image = (void(*)(id,SEL,ArithmeticOperand_t*,
                                   LynkeosImageBuffer*,
                                   void(*)(LynkeosImageBuffer*,
                                           ArithmeticOperand_t*,
                                           LynkeosImageBuffer*,
                                           u_short)))
                               [self methodForSelector:_process_image_selector];
         break;
      case ParallelizedStrategy:
         _process_image_selector =
                       @selector(parallel_image_process:result:processOneLine:);
         _process_image = (void(*)(id,SEL,ArithmeticOperand_t*,
                                   LynkeosImageBuffer*,
                                   void(*)(LynkeosImageBuffer*,
                                           ArithmeticOperand_t*,
                                           LynkeosImageBuffer*,
                                           u_short)))
                               [self methodForSelector:_process_image_selector];
         break;
      default:
         NSAssert1( NO, @"Unknown strategy %d in LynkeosImageBuffer",
                    strategy);
         break;
   }
}

- (BOOL) hasCustomFormat {return NO;}

- (void) resetMinMax
{
   u_short c;
   for( c = 0; c <= 3; c++ )
   {
      _min[c] = 0.0;
      _max[c] = -1.0;
   }
}

- (void) getMinLevel:(double*)vmin maxLevel:(double*)vmax
{
   if ( _min[_nPlanes] >= _max[_nPlanes] )
   {
      int x, y, c;

      for( c = 0; c <= _nPlanes; c++ )
      {
         _min[c] = HUGE;
         _max[c] = -HUGE;
      }
      for( c = 0; c < _nPlanes; c++ )
      {
         for( y = 0; y < _h; y++ )
         {
            for( x = 0; x < _w; x++ )
            {
               double v = colorValue(self,x,y,c);
               if ( _min[c] > v )
                  _min[c] = v;
               if ( _max[c] < v )
                  _max[c] = v;
            }
         }
         if ( _min[_nPlanes] > _min[c] )
            _min[_nPlanes] = _min[c];
         if ( _max[_nPlanes] < _max[c] )
            _max[_nPlanes] = _max[c];
      }
   }

   *vmin = _min[_nPlanes];
   *vmax = _max[_nPlanes];
}

- (void) getMinLevel:(double*)vmin maxLevel:(double*)vmax
            forPlane:(u_short)plane
{
   double notused;

   if ( _min[plane] >= _max[plane] )
      [self getMinLevel:&notused maxLevel:&notused];

   *vmin = _min[plane];
   *vmax = _max[plane];
}

- (u_short) width { return( _w ); }
- (u_short) height { return( _h ); }
- (u_short) numberOfPlanes { return( _nPlanes ); }

- (REAL * const * const) colorPlanes
{
   return( (REAL * const * const)_planes );
}

- (CGImageRef) getImageInRect:(LynkeosIntegerRect)rect
                    withBlack:(double*)black white:(double*)white gamma:(double*)gamma
{
   const u_short nPlanes = (_nPlanes <= 3 ? _nPlanes : 3);
   const double a = (white[nPlanes] > black[nPlanes] ? 1.0/(white[nPlanes] - black[nPlanes]) : 0.0);
   const int bpp = 4, bpr = bpp * rect.size.width;
   u_short c;
   double vmin, vmax;
   LynkeosGammaCorrecter *gammaCorrect[3];

   [self getMinLevel:&vmin maxLevel:&vmax];
   for( c = 0; c < nPlanes; c++ )
      gammaCorrect[c] = [LynkeosGammaCorrecter getCorrecterForGamma:gamma[_nPlanes]*gamma[c]];

   ImageTileInfo *tileInfo = [[ImageTileInfo alloc] initInRect:rect
                                                     withBlack:black white:white
                                                         imageMin:_min[_nPlanes] valMin:vmin valMax:vmax
                                                             gain:a gammaCorrecter:gammaCorrect image:self];

   CGDataProviderDirectCallbacks callbacks = {
      .getBytePointer = NULL,
      .releaseBytePointer = NULL,
      .getBytesAtPosition = dataProviderCallBack,
      .releaseInfo = dataProviderRelease
   };
   CGDataProviderRef provider = CGDataProviderCreateDirect((void*)tileInfo,
                                                           bpp * rect.size.width * rect.size.height,
                                                           &callbacks);
   CGImageRef img = CGImageCreate(rect.size.width, rect.size.height, 8, bpp*8, bpr,
                                  CGColorSpaceCreateDeviceRGB(), (CGBitmapInfo)kCGImageAlphaLast,
                                  provider, NULL, YES, kCGRenderingIntentPerceptual);
   CGDataProviderRelease(provider);

   return( img );
}

- (void) substract:(LynkeosImageBuffer*)image
{
   u_short x, y, c;

   for( c = 0; c < _nPlanes; c++ )
      for( y = 0; y < _h; y++ )
         for( x = 0; x < _w; x++ )
            colorValue(self,x,y,c) -= colorValue(image,x,y,c);
}

/*!
 * Only images of the same size can be added
 */
- (void) add:(LynkeosImageBuffer*)image
{
   u_short destPlanes = [image numberOfPlanes];
   NSAssert( _w == [image width] && _h == [image height],
             @"Stack with different sizes" );

   [self resetMinMax];

   if ( _nPlanes == destPlanes )
   {
      // Same structure, simply add plane by plane
      u_short plane;

      for( plane = 0; plane < _nPlanes; plane++ )
         [self stackPlane:plane fromImage:image];
   }
   else
   {
      if ( destPlanes == 1 )
      {
         NSAssert( _nPlanes == 3,
                   @"Inconsistent image planes %d & %d for addition",
                  _nPlanes, destPlanes );

         // Composite: add the monochrome plane into the luminance channel
         [self stackLRGBfromImage:image];
      }

      else
      {
         NSAssert( _nPlanes == 1 && destPlanes == 3,
                   @"Inconsistent image planes %d & %d for addition",
                   _nPlanes, destPlanes );

         u_short plane;

         // Copy ourselves in a temporary image buffer
         LynkeosImageBuffer *monoImage =
                           [LynkeosImageBuffer imageBufferWithData:_data
                                                   copy:NO freeWhenDone:YES
                                                   numberOfPlanes:_nPlanes
                                                   width:_w
                                                   paddedWidth:_padw
                                                   height:_h];

         // Make this image become RGB (don't free the buffer, it was moved)
         _nPlanes = destPlanes;
         _data = malloc( _padw*_h*_nPlanes*sizeof(REAL) );
         for( plane = 0; plane < _nPlanes; plane++ )
            _planes[plane] = &((REAL*)_data)[plane*_h*_padw];

         // Add the image to this null image
         memset( _data, 0, _padw*_h*_nPlanes*sizeof(REAL) );
         for( plane = 0; plane < _nPlanes; plane++ )
            [self stackPlane:plane fromImage:image];

         // And add the former (ourself) monochrome
         [self stackLRGBfromImage:monoImage];
      }
   }
}

- (void) multiplyWith:(LynkeosImageBuffer*)term
               result:(LynkeosImageBuffer*)result
{
   NSAssert( (_nPlanes == term->_nPlanes || term->_nPlanes == 1)
            && _nPlanes == result->_nPlanes 
            && _w == term->_w && _h == term->_h
            && _w == result->_w && _h == result->_h,
            @"Incompatible terms in multiplication" );
   ArithmeticOperand_t op = { .term=term };

   [self resetMinMax];
   _process_image( self, _process_image_selector, &op, result,
                   _mul_one_image_line );
}

- (void) substractBias:(double)bias andScale:(double)scale
{
   ArithmeticOperand_t op[2] = {
#ifdef DOUBLE_PIXELS
   { .dscalar=bias }
#else
   { .fscalar=bias }
#endif
   ,
#ifdef DOUBLE_PIXELS
   { .dscalar=scale }
#else
   { .fscalar=scale }
#endif
   };

   [self resetMinMax];
   _process_image( self, _process_image_selector, op, self,
                  _bias_scale_one_image_line );
}

- (void) multiplyWithScalar:(double)scalar
{
   ArithmeticOperand_t op =
#ifdef DOUBLE_PIXELS
   { .dscalar=scalar }
#else
   { .fscalar=scalar }
#endif
   ;

   [self resetMinMax];
   _process_image( self, _process_image_selector, &op, self,
                   _scale_one_image_line );
}

- (void) divideBy:(LynkeosImageBuffer*)denom result:(LynkeosImageBuffer*)result
{   
   NSAssert( (_nPlanes == denom->_nPlanes || denom->_nPlanes == 1)
            && _nPlanes == result->_nPlanes 
            && _w == denom->_w && _h == denom->_h
            && _w == result->_w && _h == result->_h,
            @"Incompatible terms in division" );
   ArithmeticOperand_t op = { .term=denom };
   ImageProcessOneLine_t div_one_line;
   double min, max;

   [self getMinLevel:&min maxLevel:&max];
   if ( min > 0.0 )
      div_one_line = _div_one_image_line;
   else
      div_one_line = std_image_div_one_line;

   [self resetMinMax];
   _process_image( self, _process_image_selector, &op, result,
                  _div_one_image_line );
}


- (void) calibrateWithDarkFrame:(LynkeosImageBuffer*)darkFrame
                      flatField:(LynkeosImageBuffer*)flatField
                             atX:(u_short)ox Y:(u_short)oy
{
   LynkeosImageBuffer *dark = darkFrame, *flat = flatField;
   u_short x, y, c;

   NSAssert( ( darkFrame == nil 
               || [darkFrame isKindOfClass:[LynkeosImageBuffer class]] )
             && ( flatField == nil
              || [flatField isKindOfClass:[LynkeosImageBuffer class]] ),
             @"Calibration with heterogenous classes" );
   NSAssert( ( dark == nil || _nPlanes == dark->_nPlanes )
             && ( flat == nil || _nPlanes == flat->_nPlanes ),
             @"Inconsistent calibration frames depth" );

   [self resetMinMax];
   for( c = 0; c < _nPlanes; c++ )
   {
      for( y = 0; y < _h; y++ )
      {
         for( x = 0; x < _w; x++ )
         {
            REAL v = colorValue(self,x,y,c);
            if ( dark != nil )
               v -= colorValue(dark,x+ox,y+oy,c);
            if ( flat != nil )
               v /= colorValue(flat,x+ox,y+oy,c);

            colorValue(self,x,y,c) = v;
         }
      }
   }
}

- (void) normalizeWithFactor:(double)factor mono:(BOOL)mono
{
   double s;
   u_short x, y, c;

   // Calculate max values if needed
   if ( factor == 0.0 )
   {
      double max = -HUGE;

      // The factor shall be 1/max
      for( y = 0; y < _h; y++ )
      {
         for( x = 0; x < _w; x++ )
         {
            if ( mono )
            {
               REAL v = 0.0;

               // Convert first each plane to a copy of the monochrome image
               for( c = 0; c < _nPlanes; c++ )
                  v += colorValue(self,x,y,c);

               v /= (REAL)_nPlanes;

               for( c = 0; c < _nPlanes; c++ )
                  colorValue(self,x,y,c) = v;

               if ( v > max )
                  max = v;
            }
            else
            {
               for( c = 0; c < _nPlanes; c++ )
               {
                  REAL v = colorValue(self,x,y,c);

                  if ( v > max )
                     max = v;
               }
            }
         }
      }
      s = 1.0/max;
   }
   else
      s = factor;

   // Apply the factor
   for( c = 0; c <= _nPlanes; c++ )
   {
      _min[c] = HUGE;
      _max[c] = -HUGE;
   }
   for( c = 0; c < _nPlanes; c++ )
   {
      for( y = 0; y < _h; y++ )
      {
         for( x = 0; x < _w; x++ )
         {
            REAL v = colorValue(self,x,y,c) * s;
            colorValue(self,x,y,c) = v;
            if ( _min[c] > v )
               _min[c] = v;
            if ( _max[c] < v )
               _max[c] = v;
         }
      }
      if ( _min[_nPlanes] > _min[c] )
         _min[_nPlanes] = _min[c];
      if ( _max[_nPlanes] < _max[c] )
         _max[_nPlanes] = _max[c];
   }
}

- (void) extractSample:(REAL * const * const)planes 
                   atX:(u_short)x Y:(u_short)y
             withWidth:(u_short)w height:(u_short)h
            withPlanes:(u_short)nPlanes
             lineWidth:(u_short)lineW
{
   u_short xi, yi, c;

   for( c = 0; c < nPlanes; c++ )
   {
      for( yi = 0; yi < h; yi++ )
      {
         for( xi = 0; xi < w; xi++ )
         {
            REAL v;

            if ( nPlanes == 1 )
            {
               u_short p;

               // Convert to monochrome
               for ( p = 0, v = 0; p < _nPlanes; p++ )
                  v += colorValue(self,xi+x,yi+y,p);
               v /= (REAL)_nPlanes;
            }
            else
            {
               if ( c < _nPlanes )
                  v = colorValue(self,xi+x,yi+y,c);
               else
                  v = 0;
            }

            SET_SAMPLE(planes[c],xi,yi,lineW,v);
         }
      }
   }
}

- (void) convertToPlanar:(REAL * const * const)planes
              withPlanes:(u_short)nPlanes
               lineWidth:(u_short)lineW
{
   [self extractSample:(REAL*const*const)planes atX:0 Y:0 withWidth:_w height:_h
            withPlanes:nPlanes lineWidth:lineW];
}

- (void) clear
{
   u_short x, y, c;

   [self resetMinMax];
   for( c = 0; c < _nPlanes; c++ )
      for( y = 0; y < _h; y++ )
         for( x = 0; x < _w; x++ )
            colorValue(self,x,y,c) = 0.0;
}

+ (LynkeosImageBuffer*) imageBufferWithData:(void*)data
                                  copy:(BOOL)copy freeWhenDone:(BOOL)freeWhenDone
                        numberOfPlanes:(u_short)nPlanes 
                                 width:(u_short)w paddedWidth:(u_short)padw 
                                height:(u_short)h
{
   return( [[[self alloc] initWithData:data copy:copy freeWhenDone:freeWhenDone
                        numberOfPlanes:nPlanes width:w paddedWidth:padw
                                height:h] autorelease] );
}

+ (LynkeosImageBuffer*) imageBufferWithNumberOfPlanes:(u_short)nPlanes 
                                           width:(u_short)w height:(u_short)h
{
   return( [[[self alloc] initWithNumberOfPlanes:nPlanes width:w height:h]
                                                                autorelease] );
}

@end
