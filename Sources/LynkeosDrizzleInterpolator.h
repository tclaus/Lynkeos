//
//  Lynkeos
//  $Id:$
//
//  Created by Jean-Etienne LAMIAUD on Thu Oct 30 2014.
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
 * @abstract Class for the drizzling interpolator, used in Lynkeos < v3.
 */
#ifndef __LYNKEOSDRIZZLEINTERPOLATOR_H
#define __LYNKEOSDRIZZLEINTERPOLATOR_H

#import <Foundation/Foundation.h>

#include "processing_core.h"
#include "LynkeosCore/LynkeosInterpolator.h"

/*!
 * @abstract Pixels weight.
 */
typedef struct
{
   REAL left;     //!< Weight of left pixel half
   REAL top;      //!< Weight of upper pixel half
} Pixels_Weight_t;

/*!
 * @abstract Vectors of pixels weight.
 */
typedef struct
{
   REALVECT left;     //!< Weight of left pixel half
   REALVECT right;    //!< Weight of right pixel half
   REALVECT top;      //!< Weight of upper pixel half
   REALVECT bottom;   //!< Weight of lower pixel half
} Pixels_Weight_Vector_t;

@interface LynkeosDrizzleInterpolator : NSObject <LynkeosInterpolator>
{
   @private
   u_short                     _expand;           //!< Scaling factor
   LynkeosIntegerPoint         _integerOffset[3]; //!< Integer part of the offsets
   Pixels_Weight_t             _weight[3];        //!< Weight of pixel parts
   Pixels_Weight_Vector_t      _vectorWeight[3];  //!< Weights for vectors
   u_short                     _nPlanes;          //!< Number of planes

   //! Origin of the rectangle to interpolate, inside the sample
   LynkeosIntegerPoint         _origin;
   LynkeosImageBuffer *_sample;           //!< Image sample to interpolate
}
@end

#endif
