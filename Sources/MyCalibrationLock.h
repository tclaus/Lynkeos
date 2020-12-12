// 
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Mon Aug 16 2004.
//  Copyright (c) 2004-2014. Jean-Etienne LAMIAUD
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
 * @abstract Definitions for the locking of images characteristics with 
 *   respect to the use of calibration frames.
 */
#ifndef __MYCALIBRATIONLOCK_H
#define __MYCALIBRATIONLOCK_H

#import <Foundation/Foundation.h>

#include "LynkeosFileReader.h"

#include "LynkeosCommon.h"
#include "MyImageListItem.h"

typedef struct
{
   NSMutableArray    *list;             //!< Array of calibration readers
   LynkeosIntegerSize size;             //!< Size of calibration frames
   u_short            nPlanes;          //!< Depth of calibration frames
} CalibrationData_t;

/*!
 * @class MyCalibrationLock
 * @abstract This class locks the use of image/movie depending on the 
 *   state of calibration data.
 * @discussion This class enforces the use of images or movies compatible for 
 *   calibration purpose.
 * @ingroup Controlers
 */
@interface MyCalibrationLock : NSObject 
{
@private
   CalibrationData_t    _darkFrame;    //!< List of all dark frame readers
   CalibrationData_t    _flatField;    //!< List of all flat field readers
   CalibrationData_t    _image;        //!< List of all "calibrable" readers
}

/*!
 * @method addDarkFrameItem:
 * @abstract Add a new dark frame item
 * @param item The new dark frame
 * @result Did the add succeeded ?
 */
- (BOOL) addDarkFrameItem :(MyImageListItem*)item ;

/*!
 * @method addFlatFieldItem:
 * @abstract Add a new flat field item
 * @param item The new flat field
 * @result Did the add succeeded ?
 */
- (BOOL) addFlatFieldItem :(MyImageListItem*)item ;

/*!
 * @method addImageItem:
 * @abstract Add a new image item to the list
 * @param item The new item
 * @result Did the add succeeded ?
 */
- (BOOL) addImageItem :(MyImageListItem*)item ;

/*!
 * @method removeItem:
 * @abstract Remove one item from the list.
 * @param item The item to be removed
 */
- (void) removeItem :(MyImageListItem*)item ;

/*!
 * @method calibrationLock
 * @abstract Constructor
 * @result An initialized instance of MyCalibrationLock
 */
+ (id) calibrationLock ;

@end

#endif
