//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Fri Mar 03 2005.
//  Copyright (c) 2005-2018. Jean-Etienne LAMIAUD
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
 * @abstract Classes that read file formats directly supported by Cocoa.
 * @discussion These classes are bridges between the application and 
 *   NSImage or NSMovie.
 */
#ifndef __MYCOCOAFILEREADER_H
#define __MYCOCOAFILEREADER_H

#include <AVFoundation/AVFoundation.h>
#if !defined GNUSTEP
#include <AvailabilityMacros.h>
#ifndef AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER
#error "Pas defini"
#endif
#endif

#include "LynkeosCommon.h"
#include "LynkeosFileReader.h"

/*!
 * @class MyCocoaImageReader
 * @abstract Class for reading every Cocoa image file format.
 * @ingroup FileAccess
 */
@interface MyCocoaImageReader : NSObject <LynkeosImageFileReader>
{
@private
   NSString*          _path;            //!< Image file path
   LynkeosIntegerSize _size;            //!< Image frame size
}
@end

#if !defined GNUSTEP
typedef enum
{
   integer8,
   integer16,
   integer32,
   integer64,
   float32,
   float64
} PixelType_t;

/*!
 * @class MyQuickTimeReader
 * @abstract Class for reading QuickTime movie files.
 * @ingroup FileAccess
 */
@interface MyQuickTimeReader : NSObject <LynkeosMovieFileReader>
{
@private
   AVAsset               *_movie;           //!< The movie being read
   AVAssetImageGenerator *_imageGenerator;  //!< Movie image extractor
   CMTime                *_times;           //!< Time for each image in the movie
   u_long                 _imageNumber;     //!< Number of images in the movie
   u_long                 _currentImage;    //!< Last decoded image
   u_short                _nPlanes;         //!< Number of planes
   PixelType_t            _pixelType;       //!< Bit resolution of the movie
   BOOL                   _cgBigEndian;     //!< Endianness
   u_short                _skipFirst;       //!< Bytes to skip before the pixels
   u_short                _bytesPerPixel;   //!< Total number of bytes for all planes
   NSLock                *_avLock;          //!< Multithreading protection
   LynkeosIntegerSize     _size;            //!< Movie frame size
   NSString              *_url;             //!< Used for cache key
}
@end
#endif

#endif
