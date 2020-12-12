//
//  Lynkeos
//  $Id: $
//
//  Created by Jean-Etienne LAMIAUD on Thu Sep 27 2018.
//
//  Copyright (c) 2018. Jean-Etienne LAMIAUD
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

#ifndef __SER_H
#define __SER_H

#include <stdio.h>

#define SER_ID_LENGTH 14
#define SER_STRING_LENGTH 40
#define SER_START_OF_IMAGES 178

#define SER_DATE_TIMEBASE 100.0e-9
#define SER_DATE_ORIGIN 631139040000000000

typedef enum
{
   SER_MONO       =   0,
   SER_BAYER_RGGB =   8,
   SER_BAYER_GRBG =   9,
   SER_BAYER_GBRG =  10,
   SER_BAYER_BGGR =  11,
   SER_BAYER_CYYM =  16,
   SER_BAYER_YCMY =  17,
   SER_BAYER_YMCY =  18,
   SER_BAYER_MYYC =  19,
   SER_RGB        = 100,
   SER_BGR        = 101
} ColorID_t;

typedef enum
{
   SER_LITTLE_ENDIAN = 0, // Inverse of the SER documentation in hand, but compliant with FireCapture
   SER_BIG_ENDIAN    = 1
} ByteOrder_t;

typedef struct
{
   char        FileID[SER_ID_LENGTH];         //!< Fixed content "LUCAM-RECORDER"
   int32_t     LuID;                      //!< Unused, content 0
   ColorID_t   ColorID;                   //!< Color encoding, use ColorID_t enum
   ByteOrder_t LittleEndian;              //!< Byte order in 16 bits image data, 0 Big endian, 1 Little endian
   int32_t     ImageWidth;                //!< Width of image in pixel
   int32_t     ImageHeight;               //!< Height of image in rows
   int32_t     PixelDepthPerPlane;        //!< True bit depth per pixel per plane
   int32_t     FrameCount;                //!< Number of image frames in SER file
   char        Observer[SER_STRING_LENGTH+1];   //!< Identification of the observer
   char        Instrument[SER_STRING_LENGTH+1]; //!< Identification of the camera
   char        Telescope[SER_STRING_LENGTH+1];  //!< Identification of the telescope
   int64_t     DateTime;                  //!< Date and time in local time zone
   int64_t     DateTime_UTC;              //!< Date and time in UTC
} SER_Header_t;

/*!
 * @abstract Read the header of a SER file
 * @param ser The FILE descriptor of the ser file.
 * @param[out] hdr The SER header, filled on output, if the result is 0
 * @result 0 upon succes, otherwise, the header is not filled
 * @ingroup FileAccess
 */
extern int SER_read_header(FILE *ser,  SER_Header_t *hdr);

#endif
