//
//  Lynkeos
//  $Id:$
//
//  Created by Jean-Etienne LAMIAUD on Mon Oct 27 2014.
//  Copyright (c) 2014-2020. Jean-Etienne LAMIAUD
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

/*!
 * @header
 * @abstract Protocol for interpolator classes.
 */
#ifndef __LYNKEOSINTERPOLATOR_H
#define __LYNKEOSINTERPOLATOR_H

#import <Foundation/Foundation.h>

//#include "LynkeosCore/processing_core.h"
#include "LynkeosCore/LynkeosProcessing.h"
#include "LynkeosCore/LynkeosImageBuffer.h"

/*!
 * @abstract Type of scaling, for stating interpolator capability
 */
typedef enum
{
   VariableDownScaling, // This is not an affine transform
   ConstantDownScaling,
   UseTransform,        // Use transform to determine the scaling
   ConstantUpScaling,
   VariableUpScaling    // This is not an affine transform
} Scaling_t;

/*!
 * @abstract Protocol for interpolators
 */
@protocol LynkeosInterpolator

/*!
 * @abstract Accessor to the interpolator name
 * @result The interpolator name
 */
+ (NSString*) name ;

/*!
 * @abstract Geometry compatibility check
 * @param scaling The requested kind of scaling
 * @param transform The applied affine transform, if any
 * @result The compatibility level (highest is better, 0 is incompatible)
 */
+ (int) isCompatibleWithScaling:(Scaling_t)scaling
                  withTransform:(NSAffineTransformStruct)transform;

/*!
 * @abstract Initializer for interpolating from an item
 * @discussion If the parameter offsets is nil, no additional offsets per plane
 *    will be applied.
 *    The transform is relative to the bitmap coordinate system.
 * @param item The item to interpolate
 * @param rect The rectangle wich will be extracted
 * @param transform The transform to apply to the image before extraction
 * @param offsets An optional array of offsets (one per item image plane)
 * @param dictionary Parameters dictionary, keys depends on the interpolator
 * @result The initialized interpolator
 */
- (id) initWithItem:(NSObject <LynkeosProcessableItem> *)item
             inRect:(LynkeosIntegerRect)rect
 withNumberOfPlanes:(u_short)nPlanes
       withTranform:(NSAffineTransformStruct)transform
        withOffsets:(const NSPoint*)offsets
     withParameters:(NSDictionary*)params;

/*!
 * @abstract Initializer for interpolating from an image
 * @discussion If the parameter offsets is NULL, no additional offsets per plane
 *    will be applied.
 *    The transform is relative to the bitmap coordinate system.
 * @param image The image to interpolate
 * @param rect The rectangle wich will be extracted
 * @param transform The transform to apply to the image before extraction
 * @param offsets An optional array of offsets (one per item image plane)
 * @param dictionary Parameters dictionary, keys depends on the interpolator
 * @result The initialized interpolator
 */
- (id) initWithImage:(LynkeosImageBuffer *)image
              inRect:(LynkeosIntegerRect)rect
  withNumberOfPlanes:(u_short)nPlanes
        withTranform:(NSAffineTransformStruct)transform
         withOffsets:(const NSPoint*)offsets
      withParameters:(NSDictionary*)params;

/*!
 * @abstract Interpolate one point
 * @param plane The plane in which to interpolate
 * @param x The x coordinate (relative in the rect) of the point to interpolate
 * @param y The y coordinate (relative in the rect) of the point to interpolate
 * @result The interpolated value
 */
- (REAL) interpolateInPLane:(u_short)plane atX:(double)x atY:(double)y;

/*!
 * @abstract Interpolate a vector of points
 * @discussion The first point to interpolate is given by (x, y), other points
 *    are at consecutive x coordinates.
 * @param plane The plane in which to interpolate
 * @param x The x coordinate (relative in the rect) of the 1st point to interpolate
 * @param y The y coordinate (relative in the rect) of the 1st point to interpolate
 * @result The interpolated vector
 */
- (REALVECT) interpolateVectInPLane:(u_short)plane atX:(double)x atY:(double)y;

@end

@interface LynkeosInterpolatorManager : NSObject

/*!
 * @abstract Retrieve the interpolator class best suited for a transformation
 * @param scaling The scaling factor applied to the item
 * @param transform The affine transform applied to the item
 * @result The interpolator class
 */
+ (Class) interpolatorWithScaling:(Scaling_t)scaling transform:(NSAffineTransformStruct)transform ;

/*!
 * @abstract Retrieve an interpolator class by its name
 * @param name The interpolator registered name
 * @result The interpolator class
 */
+ (Class) interpolatorWithName:(NSString*)name;

@end

#endif
