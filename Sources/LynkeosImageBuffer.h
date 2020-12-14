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

/*!
 * @header
 * @abstract Definitions for the application image buffer class.
 */
#ifndef __LynkeosImageBuffer_H
#define __LynkeosImageBuffer_H

#import <Foundation/Foundation.h>

#include <LynkeosCore/LynkeosProcessing.h>

#define RED_PLANE 0     //!< Index of the red plane in RGB buffers
#define GREEN_PLANE 1   //!< Index of the green plane in RGB buffers
#define BLUE_PLANE 2    //!< Index of the blue plane in RGB buffers

/*!
 * @abstract Internal type used for arithmetic operators.
 * @discussion Either an image or a scalar.
 * @ingroup Processing
 */
typedef union
{
   LynkeosImageBuffer *term; //!< When operator acts on an image
   float  fscalar;         //!< When operator acts on a single precision scalar
   double dscalar;         //!< When operator acts on a double precision scalar
} ArithmeticOperand_t;

/*!
 * @abstract Internal method pointer to arithmetically process one line
 */
typedef void(*ImageProcessOneLine_t)(LynkeosImageBuffer*,
                                     ArithmeticOperand_t*,
                                     LynkeosImageBuffer*,
                                     u_short);

/*!
 * @abstract Class used for floating precision images.
 * @discussion For optimization purposes, the methods for accessing pixels 
 *   value are implemented as macros
 * @ingroup Processing
 */
@interface LynkeosImageBuffer : NSObject <NSCopying, LynkeosProcessingParameter>
{
@public
   u_short   _nPlanes;     ///< Number of color planes
   u_short  _w;            ///< Image pixels width
   u_short  _h;            ///< Image pixels width
   u_short  _padw;         ///< Padded line width (>= width)
   void     *_data;        ///< Pixel buffer, the planes are consecutive
@protected
   REAL    *_planes[3];   ///< Shortcuts to the color planes
   BOOL     _freeWhenDone; ///< Whether to free the planes on dealloc
   double   _min[4];          ///< The image minimum value
   double   _max[4];          ///< The image maximum value

   //! Strategy method for multiplying a line, with vectorization, or not
   ImageProcessOneLine_t _mul_one_image_line;
   //! Strategy method for scaling a line, with vectorization, or not
   ImageProcessOneLine_t _scale_one_image_line;
   //! Strategy method for dividing a line, with vectorization, or not
   ImageProcessOneLine_t _div_one_image_line;
   //! Strategy method for substract and multiply, with vectorization, or not
   ImageProcessOneLine_t _bias_scale_one_image_line;
   //! Strategy method for processing an image, actually for debug
   SEL     _process_image_selector;
   //! Strategy method for processing an image, func pointer which is called
   void (*_process_image)(id,SEL,ArithmeticOperand_t*,
                          LynkeosImageBuffer*res,
                          ImageProcessOneLine_t);
}

/*!
 * @abstract Allocates a new empty buffer
 * @param nPlanes Number of color planes for this image
 * @param w Image pixels width
 * @param h Image pixels height
 * @result The initialized buffer.
 */
- (id) initWithNumberOfPlanes:(u_short)nPlanes 
                        width:(u_short)w height:(u_short)h ;

/*!
 * @abstract Initialize a new buffer with preexisting data
 * @param data Image data
 * @param copy Whether to copy the data
 * @param freeWhenDone Whether to free the planes on dealloc (relevant only when
 *    copy is NO)
 * @param nPlanes Number of color planes for this image
 * @param w Image pixels width
 * @param padw Padded width of the data
 * @param h Image pixels height
 * @result The initialized buffer.
 */
- (id) initWithData:(void*)data
               copy:(BOOL)copy freeWhenDone:(BOOL)freeWhenDone
     numberOfPlanes:(u_short)nPlanes 
              width:(u_short)w paddedWidth:(u_short)padw height:(u_short)h ;

/*!
 * @abstract The memory size occupied by this item
 * @discussion The object shall use class_getInstanceSize and add the size of
 *    any aggregated objects and "mallocated" buffers.
 * @result The item's size
 */
- (size_t) memorySize ;

/*!
 * @abstract Get the image pixels width
 * @result The image width
 */
- (u_short) width ;

/*!
 * @abstract Get the image pixels height
 * @result The image height
 */
- (u_short) height ;

/*!
 * @abstract Get the number of color planes
 * @result The number of color planes
 */
- (u_short) numberOfPlanes ;

/*!
 * @abstract Retrieve a Cocoa 24 bits RGB bitmap representation
 * @discussion The black, white and gamma are arrays of values for each plane,
 *    and a last "global" value that is applied equally on each plane.
 * @param black Black level for conversion for each plane
 * @param white White level for conversion for each plane
 * @param gamma Gamma correction exponent  for each plane (ie: 1 = no correction)
 * @result The 8 bits RGB bitmap representation of the buffer data
 */
- (CGImageRef) getImageInRect:(LynkeosIntegerRect)rect
                    withBlack:(double*)black white:(double*)white gamma:(double*)gamma;

/*!
 * @abstract Change the strategy of processing
 * @discussion The items are always created with the standard strategy (no parallelization).
 * @param strategy The new strategy
 */
- (void) setOperatorsStrategy:(ImageOperatorsStrategy_t)strategy ;

/*!
 * @abstract Add another image buffer.
 * @discussion The image to add shall be an instance of the same class as self
 *   and have the same size (method implementation can rely on this).
 * @param image The image to add
 */
- (void) add :(LynkeosImageBuffer*)image ;

/*!
 * @abstract Calibrate the image with the calibration images.
 * @discussion darkFrame and flatField, when present, are instances of the same
 *   class as self. They are "full sensor" images.
 *
 *   The darkFrame, if any, shall be substracted from the image and the result
 *   shall be divided by the flatField, if any.
 *
 *   The coordinates are specified using the same orientation as in
 *   LynkeosFileReader
 * @param darkFrame The dark frame image, nil if not present
 * @param flatField The flat field image, nil if not present
 * @param ox The X origin of our image in the full sensor frame.
 * @param oy The Y origin of our image in the full sensor frame.
 */
- (void) calibrateWithDarkFrame:(LynkeosImageBuffer*)darkFrame
                      flatField:(LynkeosImageBuffer*)flatField
                            atX:(u_short)ox Y:(u_short)oy ;

/*!
 * @abstract Multiplies all values with a scalar
 * @param factor The value by which each pixel is multiplied. If 0, the factor
 *   is taken as to set the maximum value of the resulting image to 1.0
 * @param mono If true and factor is zero, the color planes are leveled to
 *   obtain a non color biased image
 */
- (void) normalizeWithFactor:(double)factor mono:(BOOL)mono ;

/*!
 * @abstract Convert the image buffer data to a floating precision planar
 *   representation.
 * @discussion The pixels ordering is the same as in LynkeosFileReader.
 * @param planes The color planes to fill with the image data. There are as
 *   many planes as there are in this instance and their size is the same as
 *   this instance's image.
 * @param nPlanes Number of planes in the output buffer.
 * @param precision The floating precision of pixels in the output buffer.
 * @param lineW The line width of the output buffer (may be larger than this
 *   instance's image width).
 */
- (void) convertToPlanar:(REAL * const * const)planes
              withPlanes:(u_short)nPlanes
               lineWidth:(u_short)lineW ;

/*!
 * @abstract Clear the image contents ; all samples are zeroes
 */
- (void) clear ;

/*!
 * @abstract Subclasses that use a different data format must return true
 * @result Wether the image data is stored in a nonstandard format
 */
- (BOOL) hasCustomFormat;

/*!
 * @abstract Reset the min and max to unset values
 */
- (void) resetMinMax ;

/*!
 * @abstract Get the minimum and maximum pixels value
 * @param[out] vmin Minimum pixel value
 * @param[out] vmax Maximum pixel value
 */
- (void) getMinLevel:(double*)vmin maxLevel:(double*)vmax ;

/*!
 * @abstract Get the minimum and maximum pixels value for a given plane
 * @param[out] vmin Minimum pixel value
 * @param[out] vmax Maximum pixel value
 * @param plane he plane for which min and max will be returned
 */
- (void) getMinLevel:(double*)vmin maxLevel:(double*)vmax
            forPlane:(u_short)plane;
/*!
 * @abstract Access to the color planes
 * @result An array of pointer to the color planes
 */
- (REAL * const * const) colorPlanes ;

/*!
 * @abstract Access to one color component of a pixel
 * @discussion This method is implemented as a macro for speed purpose
 * @param buf An instance of LynkeosImageBuffer
 * @param x Pixel's x coordinate
 * @param y Pixel's y coordinate
 * @param c Color plane
 * @result The access for this pixel (it can be used as an lvalue)
 * @relates LynkeosImageBuffer
 * @ingroup Processing
 */
#define stdColorValue(buf,x,y,c) \
      (((REAL*)(buf)->_data)[((y)+(c)*(buf)->_h)*(buf)->_padw+(x)])

/*!
 * @abstract Extract a rectangle in the image
 */
- (void) extractSample:(REAL * const * const)planes
                   atX:(u_short)x Y:(u_short)y
             withWidth:(u_short)w height:(u_short)h
            withPlanes:(u_short)nPlanes
             lineWidth:(u_short)lineW ;

/*!
 * @abstract Substract an image from another
 * @param image The other image to substract
 */
- (void) substract:(LynkeosImageBuffer*)image ;

/*!
 * @abstract Multiplication
 * @discussion Term shall either have the same number of planes as the receiver
 *    or only one plane. In the latter case, the plane is applied to each planes
 *    of the receiver.
 * @param term other term
 * @param result where the result is stored, can be one of the terms.
 */
- (void) multiplyWith:(LynkeosImageBuffer*)term
                               result:(LynkeosImageBuffer*)result ;

/*!
 * @abstract Substract and multiply with scalars
 * @param bias The bias to substract
 * @param scale The scalar by which all pixels are multiplied
 */
- (void) substractBias:(double)bias andScale:(double)scale;

/*!
 * @abstract Multiplication with a scalar
 * @param scalar The scalar by wich all pixels are multiplied
 */
- (void) multiplyWithScalar:(double)scalar ;

/*!
 * @abstract Division
 * @discussion term shall either have the same number of planes as the receiver
 *    or only one plane. In the latter case, the plane is applied to each planes
 *    of the receiver.
 * @param denom Denominator of the division
 * @param result where the result is stored, can be one of the terms
 */
- (void) divideBy:(LynkeosImageBuffer*)denom
                               result:(LynkeosImageBuffer*)result ;

/*!
 * @abstract Convenience empty image buffer creator
 * @param nPlanes Number of color planes for this image
 * @param w Image pixels width
 * @param h Image pixels height
 * @result The allocated and initialized LynkeosImageBuffer.
 */
+ (LynkeosImageBuffer*) imageBufferWithNumberOfPlanes:(u_short)nPlanes 
                               width:(u_short)w height:(u_short)h ;

/*!
 * @abstract Convenience initialized image buffer creator
 * @param data Image data
 * @param copy Wether to copy the data
 * @param freeWhenDone Whether to free the planes on dealloc (relevant only when
 *    copy is NO)
 * @param nPlanes Number of color planes for this image
 * @param w Image pixels width
 * @param padw Padded width of the data
 * @param h Image pixels height
 * @result The allocated and initialized LynkeosImageBuffer.
 */
+ (LynkeosImageBuffer*) imageBufferWithData:(void*)data
                               copy:(BOOL)copy  freeWhenDone:(BOOL)freeWhenDone
                               numberOfPlanes:(u_short)nPlanes 
                               width:(u_short)w paddedWidth:(u_short)padw
                               height:(u_short)h ;
@end

#endif

