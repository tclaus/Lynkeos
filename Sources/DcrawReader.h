//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Wed Apr 27 2005.
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

/*!
 * @header
 * @abstract Reader for image formats supported by DCRAW
 */
#ifndef __DCRAWREADER_H
#define __DCRAWREADER_H

#include <stdio.h>

#include "LynkeosFileReader.h"

/**
 * \page libraries Libraries needed to compile Lynkeos
 * The Dcraw plugin needs a dcraw compiled executable to be put in the build 
 * folder.
 * It can be found at http://www.cybercom.net/~dcoffin/dcraw/
 */

/*!
 * @class DcrawReader
 * @abstract Class for reading digital cameras raw image file formats.
 * @discussion This reader uses an external program, dcraw for converting the
 *   raw file into a temporary PPM file, and retrieve the data from this PPM
 *   file.
 *
 *   The conversion is started in the background when the reader is created.
 *   When the reader gets called, it waits for conversion end if needed, before
 *   accessing the PPM file data.
 * @ingroup FileAccess
 */
@interface DcrawReader : NSObject <LynkeosCustomImageFileReader>
{
@private
   NSURL        *_url;             //!< The RAW file to read
   NSTask       *_dcrawTask;       //!< The converter task
   NSString     *_ppmFilePath;     //!< Converted PPM file path
   u_short      _numberOfPlanes;   //!< Cached number of planes
   u_short      _width;            //!< Cached width
   u_short      _height;           //!< Cached height
   NSMutableDictionary *_metadata; //!< Meta data dictionary
   u_short      _baseWidth;        //!< Width of image before any rotation
   u_short      _baseHeight;       //!< Width of image before any rotation
   u_long       _ppmDataOffset;    //!< Offset of image data in PPM file
   u_short      _dataMax;          //!< Maximum pixel value
   ListMode_t   _mode;             //!< Image mode for this instance
   LynkeosImageBuffer* _dark;  //!< The dark frame (weak ref)
   NSTimer     *_conversionTimer;  //!< Used to delay the start of conversion
}

@end

#endif
