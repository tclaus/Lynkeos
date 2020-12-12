//
//  Lynkeos
//  $Id: $
//
//  Created by Jean-Etienne LAMIAUD on Fri Sep 28 2018.
//  Copyright (c) 2018-2020. Jean-Etienne LAMIAUD
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
 * @abstract Reader for SER movie format.
 */
#ifndef __SERREADER_H
#define __SERREADER_H

#include <stdio.h>

#include "LynkeosFileReader.h"

#include "SER.h"
#include "SER_ImageBuffer.h"

/*!
 * @class SER_Reader
 * @abstract Class for reading SER movie file format.
 * @ingroup FileAccess
 */
@interface SER_Reader : NSObject <LynkeosMovieFileReader, LynkeosCustomMovieFileReader>
{
@private
   FILE                *_file;           //!< The SER file descriptor
   u_short              _numberOfPlanes; //!< 1 formonochrome, 3 for color
   u_short              _width;          //!< Image width
   u_short              _height;         //!< Image height
   u_long               _numberOfFrames; //!< Number of frames in the movie
   u_short              _bytesPerPixel;  //!< Image precision
   u_short              _bytesPerRow;    //!< Line length
   ColorID_t            _format;         //!< Wether mono, RGB, bayer
   ByteOrder_t          _byteOrder;      //!< Endianness for 16 bits data
   u_short              _bayerPlanes[2][2]; //!< Bayer mosaic pattern (Y first)
   double               _whiteBalance[3]; //!< Color weights
   BOOL                 _isBayer;
   off_t                _filePos;        //!< Current position in file, used to avoid seeking
   ListMode_t           _mode;           //!< Current mode, taken into account in conversion
   SER_ImageBuffer     *_darkFrame;      //!< Dark frame in same bayer format
   LynkeosImageBuffer  *_flatField;      //!< Flat field (actually, in planar format)
   NSLock              *_mutex;          //!< To allow multithreading of movie reading
   NSMutableDictionary *_metadata;       //!< Movie metadata
}

@end

#endif
