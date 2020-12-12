//
//  Lynkeos
//  $Id$
//
//  Based on ffmpeg_access.c by Christophe JALADY.
//  Created by Jean-Etienne LAMIAUD on Mon Jun 27 2005.
//
//  Copyright (c) 2004-2005. Christophe JALADY
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
 * @abstract Reader for image formats supported by the FFmpeg library.
 */
#ifndef __FFMPEGREADER_H
#define __FFMPEGREADER_H

#include "LynkeosFileReader.h"

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>

/**
 * \page libraries Libraries needed to compile Lynkeos
 * The FFmpeg reader class needs the FFmpeg library.
 * It can be found at http://ffmpeg.mplayerhq.hu/
 */

/*!
 * @struct KeyFrames_t
 * @abstract Structure used to retain the key frames position.
 * @discussion It is used to speed the seeking in the sequence.
 */
typedef struct
{
   u_long  keyFrame;       //!< Frame number of the key frame
   int64_t timestamp;      //!< Timestamp of the key frame
} KeyFrames_t;

typedef enum {DataNeeded, DataRepeat, EndOfFile, Flushing} DecoderState_t;

/*!
 * @class FFmpegReader
 * @abstract Class for reading movie file formats non supported by Cocoa.
 * @ingroup FileAccess
 */
@interface FFmpegReader : NSObject <LynkeosMovieFileReader>
{
@private
   u_short            _width;               //!< Displayed width
   u_short            _height;              //!< Displayed height
   u_short            _numberOfPlanes;      //!< Number of color components
   AVFormatContext   *_pFormatCtx;          //!< FFMpeg file format
   AVCodecContext    *_pCodecCtx;           //!< FFMpeg codec
   AVFrame           *_pCurrentFrame;       //!< Decoded frame
   struct SwsContext *_displayConverter;    //!< Context for NSImage conversion
   struct SwsContext *_procConverter;       //!< Context for processing conversion
   u_short           *_convBuffer;          //!< Temporary buffer for conversion
   int                _bufLineLength;       //<! Temporary buffer line length for each plane
   int               _videoStream;          //!< Index of the selected video stream
   AVPacket          _packet;               //!< Last packet read
   DecoderState_t    _decoderState;         //! State of the decoder with respect to packet data
   u_long            _numberOfFrames;       //!< Number of image frames in the movie
   KeyFrames_t      *_times;                //!< Times of key frames
   NSLock           *_mutex;                //!< Mutex to allow reading from multiple threads
   u_long	         _nextIndex;            //!< Index of the next frame to decode
}

@end

#endif
