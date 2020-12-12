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

#include <AVFoundation/AVFoundation.h>
#import <AppKit/NSGraphics.h>

#include <libavutil/imgutils.h>

#include <LynkeosCore/LynkeosProcessing.h>
#include "MyCachePrefs.h"

#include "FFmpegReader.h"

#ifdef DOUBLE_PIXELS
   #error This reader is not able to run with double precision reals
#endif

#define K_TIME_PAGE_SIZE 256

/*!
 * @abstract ObjC container for a FFMpeg AVFrame
 */
@interface MyAVFrameContainer : NSObject
{
@public
   AVFrame *_frame; //!< The AVFrame we wrap around
}
//! Dedicated initializer
- (id) initWithAVFrame:(AVFrame*)frame ;
@end

@implementation MyAVFrameContainer
- (id) initWithAVFrame:(AVFrame*)frame
{
   if ( (self = [self init]) != nil )
      _frame = frame;
   return( self );
}

- (void) dealloc
{
   av_frame_free(&_frame);
   [super dealloc];
}
@end

/*!
 * @category FFmpegReader(Private)
 * @abstract Internals of the FFmpeg reader
 * @discussion This code is supposed to seek to the nearest previous key frame
 *   if needed, then to step through the frames up to the required frame.
 *   Due to some unpredictable behaviour in the key frames reporting and their
 *   time tagging : when a problem is detected, the key frame control structure
 *   is filled with only the first sequence frame. It is much slower, but (knock
 *   on wood) works.
 * @ingroup FileAccess
 */
@interface FFmpegReader(Private)

/*!
 * @method nextFrame
 * @abstract Access the next frame in the movie.
 * @result Wether a frame was succesfully read
 */
- (BOOL) nextFrame ;

/*!
 * @method getFrame:
 * @abstract Get the needed frame
 * @param index The index of the frame to get
 */
- (AVFrame*) getFrame :(u_long) index ;

@end

@implementation FFmpegReader(Private)

- (BOOL) nextFrame
{
   int ret;
   BOOL frameFinished = NO;

   // Decode packets until we have decoded a complete frame
   while ( !frameFinished )
   {
      if (_decoderState == DataNeeded)
      {
         // Read the next packet, skipping all packets that aren't for this stream
         do
         {
            // Free old packet content
            av_packet_unref( &_packet );

            // Read new packet
            ret = av_read_frame(_pFormatCtx, &_packet);

         } while( ret >= 0 && (_packet.stream_index != _videoStream ) );

         if ( ret < 0 )
         {
            // Obviously, the stream must be at end
            _decoderState = EndOfFile;
         }
      }

      // Decode the next chunk of data
      if (_decoderState != Flushing)
      {
         AVPacket *pk = NULL;

         switch (_decoderState )
         {
            case DataNeeded:
            case DataRepeat:
               pk = &_packet;
               break;
            case EndOfFile:
               // We will send a *last* NULL packet
               _decoderState = Flushing;
               break;
            default:
               break;
         }
         ret = avcodec_send_packet(_pCodecCtx, pk);

         if ( ret < 0 )
         {
            if (errno == EAGAIN)
            {
               _decoderState = DataRepeat;
               ret = 0;
            }
            else
            {
               NSLog( @"Error while decoding frame" );
            }
         }
         else
         {
            if (_decoderState == DataRepeat)
               _decoderState = DataNeeded;
         }
      }

      av_frame_unref(_pCurrentFrame);
      ret = avcodec_receive_frame(_pCodecCtx, _pCurrentFrame);

      if (ret == 0)
         frameFinished = YES;
      else
      {
         if (ret == AVERROR_EOF)
         {
//            NSLog(@"Finished to decode stream");
            break;
         }
//       else
//          NSLog(@"FFMpeg error : %s", av_err2str(ret));
      }
   }

   if ( frameFinished )
      _nextIndex ++;

   return( frameFinished );
}

- (AVFrame*) getFrame :(u_long) index
{
   NSString *key = [NSString stringWithFormat:@"%s&%06ld", _pFormatCtx->url, index];
   LynkeosObjectCache *movieCache = [LynkeosObjectCache movieCache];
   MyAVFrameContainer *pix;

   if ( movieCache != nil &&
        (pix = (MyAVFrameContainer*)[movieCache getObjectForKey:key]) != nil )
      return( pix->_frame );

   int ret;
   BOOL success;

   // Do not move if the frame already read is asked
   if ( index == (_nextIndex - 1) )
      return( _pCurrentFrame );

//   for( ;; )
//   {
      // Go to the previous key frame if needed
      if ( index < _nextIndex
          || _times[index].keyFrame != _times[_nextIndex].keyFrame )
      {
         // Reset the decoder
         if ( _packet.data != NULL )
            av_packet_unref( &_packet );
         _packet.size = 0;
         avcodec_flush_buffers(_pCodecCtx);
         _decoderState = DataNeeded;

//         NSLog(@"Seeking FFMpeg stream to frame %lu", _times[index].keyFrame);
         ret = av_seek_frame( _pFormatCtx, _videoStream,
                             _times[index].timestamp,
                             AVSEEK_FLAG_BACKWARD );

         if ( ret == 0 )
            _nextIndex = _times[index].keyFrame;
         else
            _nextIndex = _numberOfFrames + 1;
      }
      else
         ret = 0;

      if ( ret == 0 )
      {
         success = YES;
         while ( _nextIndex <= index && success )
         {
            success = [self nextFrame];

            // Keep the last frames in cache for list processing
            if ( success && ( _nextIndex == index+1
                              || (movieCache != nil && _nextIndex+numberOfCpus > index) ) )
            {
               if ( movieCache != nil )
               {
                  AVFrame *frameCopy = av_frame_alloc();
                  av_frame_ref(frameCopy, _pCurrentFrame);
                  [movieCache setObject:
                     [[[MyAVFrameContainer alloc] initWithAVFrame: frameCopy] autorelease]
                                 forKey:
                     [NSString stringWithFormat:@"%s&%06ld", _pFormatCtx->url,_nextIndex-1]];
               }
            }
         }
      }
      else
         NSLog( @"Seek to frame failed" );

//      if ( (! success || ret <= 0)
//          && (_times[index].keyFrame != 0 || _times[index].timestamp != 0) )
//      { // Hack to try to read buggy sequences (or which makes FFmpeg bug ;o)
//         unsigned int i;
//         NSLog( @"Trying to revert to sequential read" );
//         for( i = 1; i < _numberOfFrames; i++ )
//         {
//            _times[i].keyFrame = 0;
//            _times[i].timestamp = 0;
//         }
//         _nextIndex = _numberOfFrames;
//      }
//      else
//         // Succeeded or hopeless
//         break;
//   }

   return( _pCurrentFrame );
}

@end

@implementation FFmpegReader

+ (void) load  // It has the added benefit to force the runtime to load the class
{
   // Register all formats and codecs
   av_register_all();
}   

+ (void) lynkeosFileTypes:(NSArray**)fileTypes
{
   const AVInputFormat *fmt;
   void *opaque = NULL;

   // Start the list with obvious file types, in case the introspection would fail
   *fileTypes = [NSMutableArray arrayWithObjects: @"avi",@"mpeg",@"mpg",@"mp4",@"wmv",@"mov",
                 AVFileTypeQuickTimeMovie, AVFileTypeMPEG4, AVFileTypeAppleM4V, nil];
   while ((fmt = av_demuxer_iterate(&opaque)))
   {
      if (fmt->extensions != NULL)
      {
         // Filtering only the formats with video capacity did not work... get them all
         NSString *extensions = [NSString stringWithUTF8String:fmt->extensions];
         NSArray<NSString *> *extList = [extensions componentsSeparatedByString:@","];
         NSEnumerator *extEnum = [extList objectEnumerator];
         NSString *ext;
         while( (ext = [extEnum nextObject]) != nil )
         {
            if (![*fileTypes containsObject:ext])
               [(NSMutableArray*)*fileTypes addObject:ext];
         }
      }
   }
}

- (id) init
{
   self = [super init];
   if ( self != nil )
   {
      _width = 0;
      _height = 0;
      _numberOfPlanes = 0;
      _pFormatCtx = NULL;
      _pCodecCtx = NULL;
      _pCurrentFrame = NULL;
      _displayConverter = NULL;
      _procConverter = NULL;
      _convBuffer = NULL;
      _bufLineLength = 0;
      _videoStream = -1;
      av_init_packet(&_packet);
      _packet.data = NULL;
      _packet.size = 0;
      _decoderState = DataNeeded;
      _numberOfFrames = 0;
      _nextIndex = 0;
      _mutex = [[NSLock alloc] init];
      _times = NULL;
   }
   return( self );
}

- (id) initWithURL:(NSURL*)url
{
   unsigned int       i;
   int                ret;
   AVCodec           *pCodec;
   AVCodecParameters *codecParams;
   u_long             arraySize;
   BOOL               validFrame;
   int64_t         /* startTime, timestamp,*/ keyTimestamp;
   u_long             keyIndex;

   self = [self init];

   if ( self != nil )
   {
      // Open video file
      ret = avformat_open_input( &_pFormatCtx,
                                [[url path] fileSystemRepresentation],
//                                [[url absoluteString] UTF8String],
                                NULL, NULL );
      if ( ret < 0 )
      {
         NSLog( @"Could not open file %@\n%s", [url absoluteString], av_err2str(ret) );
         [self release];
         return( nil );
      }

      // Retrieve stream information
      ret = avformat_find_stream_info(_pFormatCtx, NULL);
      if ( ret < 0 )
      {
         NSLog( @"Could not find any stream info");
         [self release];
         return( nil );
      }

      // Find the first video stream
      _videoStream = -1;
      for ( i = 0; i < _pFormatCtx->nb_streams; i++ )
      {
         if( _pFormatCtx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO )
         {
            _videoStream = i;
            codecParams = _pFormatCtx->streams[i]->codecpar;
            break;
         }
      }

      if( _videoStream == -1 )
      {
         NSLog( @"Could not find a video stream");
         [self release];
         return( nil );
      }

      // Find the decoder for the video stream
      pCodec = avcodec_find_decoder(codecParams->codec_id);
      if ( pCodec == NULL )
      {
         NSLog( @"Codec not found");
         [self release];
         return( nil );
      }

      // Allocate a codec context for the video stream
      _pCodecCtx = avcodec_alloc_context3(pCodec);

      // Inform the codec that we can handle truncated bitstreams -- i.e.,
      // bitstreams where frame boundaries can fall in the middle of packets
      if ( pCodec->capabilities & AV_CODEC_CAP_TRUNCATED )
         _pCodecCtx->flags |= AV_CODEC_FLAG_TRUNCATED;

      // Open codec
      if (   avcodec_parameters_to_context(_pCodecCtx, codecParams) < 0
          || avcodec_open2(_pCodecCtx, pCodec, NULL) < 0)
      {
         NSLog( @"Can't open the codec" );
         [self release];
         return( nil );
      }

      AVRational aspect = _pCodecCtx->sample_aspect_ratio;
      if (aspect.num == 0 || aspect.den == 0)
      {
         _width = _pCodecCtx->width;
         _height = _pCodecCtx->height;
      }
      else if (aspect.num >= aspect.den)
      {
         _width = (_pCodecCtx->width * aspect.num) / aspect.den;
         _height = _pCodecCtx->height;
      }
      else
      {
         _width = _pCodecCtx->width;
         _height = (_pCodecCtx->height * aspect.num) / aspect.den;
      }
      const AVPixFmtDescriptor *fmtDesc = av_pix_fmt_desc_get(_pCodecCtx->pix_fmt);
      if (fmtDesc == nil)
      {
         NSLog( @"Unknown pixel format" );
         [self release];
         return( nil );
      }
      _numberOfPlanes = (fmtDesc->nb_components == 1 ? 1 : 3);

      // Allocate video frame
      _pCurrentFrame = av_frame_alloc();

      // Allocate a RGB converter for NSImage conversion
      _displayConverter = sws_getContext(_pCodecCtx->width, _pCodecCtx->height,
                                         _pCodecCtx->pix_fmt,
                                         _width, _height,
                                         AV_PIX_FMT_RGBA, SWS_LANCZOS,
                                         NULL, NULL, NULL);

      // And allocate another for getImageSample
      _procConverter = sws_getContext(_pCodecCtx->width, _pCodecCtx->height,
                                      _pCodecCtx->pix_fmt,
                                      _width, _height,
                                      _numberOfPlanes == 3 ? AV_PIX_FMT_RGB48 : AV_PIX_FMT_GRAY16,
                                      SWS_LANCZOS, NULL, NULL, NULL);

      // Allocate also the conversion buffer
      const int vectSize = sizeof(u_short __attribute__  ((vector_size (8))));
      _bufLineLength = (_width * _numberOfPlanes * sizeof(u_short) + vectSize - 1) / vectSize;
      _bufLineLength *= vectSize;
      _convBuffer = (u_short*)malloc(_bufLineLength * _height);

      if(_displayConverter == NULL || _procConverter == NULL)
      {
         NSLog(@"Cannot initialize the conversion context!");
         [self release];
         return( nil );
      }

      // Get the frames times
      arraySize = 0;
//      startTime = _pFormatCtx->streams[_videoStream]->start_time;
      //frameDuration = (int64_t)
      //          ((double)_pFormatCtx->streams[_videoStream]->r_frame_rate.den
      //	  / (double)_pFormatCtx->streams[_videoStream]->r_frame_rate.num
      //	  * (double)_pFormatCtx->streams[_videoStream]->time_base.den
      //	  / (double)_pFormatCtx->streams[_videoStream]->time_base.num
      //	  + 0.5 );
//      timestamp = startTime;
      keyIndex = 0;
      keyTimestamp = 0/*startTime*/;
      for( validFrame = YES; validFrame; )
      {
         validFrame = [self nextFrame];

         if ( validFrame )
         {
            if ( _numberOfFrames >= arraySize )
            {
               arraySize += K_TIME_PAGE_SIZE;
               _times = (KeyFrames_t*)realloc( _times, arraySize*sizeof(KeyFrames_t) );
            }
/*
            if ( _pCurrentFrame->key_frame )
            {
               keyTimestamp = timestamp;
               keyIndex = _numberOfFrames;
            }
 */
            _times[_numberOfFrames].timestamp = keyTimestamp;
            _times[_numberOfFrames].keyFrame = keyIndex;

            _numberOfFrames ++;
//            timestamp = _pFormatCtx->streams[_videoStream]->cur_dts;
         }
      }
      // We are now pointing beyond sequence end
      _nextIndex = _numberOfFrames + 1;
   }

   return( self );
}

- (void) dealloc
{
   [_mutex release];
   if ( _pCodecCtx != NULL )
      avcodec_close(_pCodecCtx);
   // Deallocate the current frame only if it is not already in the cache (otherwise, the cache will free it)
   if ( _pCurrentFrame != NULL )
      av_free(_pCurrentFrame);
   if ( _displayConverter != NULL )
      sws_freeContext( _displayConverter );
   if ( _procConverter != NULL )
      sws_freeContext( _procConverter );
   if (_convBuffer != NULL)
      free(_convBuffer);
   if ( _packet.data != NULL )
      av_packet_unref( &_packet );
   if ( _pFormatCtx != NULL )
      avformat_close_input( &_pFormatCtx );
   if ( _times != NULL )
      free( _times );

   [super dealloc];
}

- (void) imageWidth:(u_short*)w height:(u_short*)h
{   
   *w = _width;
   *h = _height;
}

- (u_short) numberOfPlanes
{
   return( _numberOfPlanes );
}

- (void) getMinLevel:(double*)vmin maxLevel:(double*)vmax
{
   *vmin = 0.0;
   *vmax = 255.0;
}

- (u_long) numberOfFrames
{
   return( _numberOfFrames );
}

- (NSImage*) getNSImageAtIndex:(u_long)index
{
   NSImage *image = nil;
   NSBitmapImageRep* bitmap;

   NSAssert( index < _numberOfFrames, @"Access beyond sequence end" );

   // Create a RGB bitmap
   bitmap = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                   pixelsWide:_width
                                                   pixelsHigh:_height
                                                  bitsPerSample:8
                                                samplesPerPixel:4
                                                       hasAlpha:YES
                                                       isPlanar:NO
                                                 colorSpaceName:NSCalibratedRGBColorSpace
                                                    bytesPerRow:0
                                                   bitsPerPixel:32]
             autorelease];

   if ( bitmap != nil )
   {
      u_char *pixels = (u_char*)[bitmap bitmapData];
      int bpr = (int)[bitmap bytesPerRow];
      AVFrame *frame;
      int ret;

      [_mutex lock];

      frame = [self getFrame:index];

      if ( frame != NULL )
      {
         ret = sws_scale(_displayConverter, (const uint8_t *const *)frame->data, frame->linesize,
                         0, _height, &pixels, &bpr);
      }

      [_mutex unlock];

      image = [[[NSImage alloc] initWithSize:NSMakeSize(_width, _height)]
               autorelease];

      if ( image != nil )
         [image addRepresentation:bitmap];
   }

   return( image );
}

- (void) getImageSample:(REAL * const * const)sample atIndex:(u_long)index
             withPlanes:(u_short)nPlanes
                    atX:(u_short)x Y:(u_short)y W:(u_short)w H:(u_short)h
              lineWidth:(u_short)lineW
{
   u_short xs, ys, cs;
   int ret;

   NSAssert( index < _numberOfFrames, @"Access beyond sequence end" );
   NSAssert( x+w <= _width && y+h <= _height,
             @"Sample at least partly outside the image" );

   [_mutex lock];

   AVFrame *frame;
   frame = [self getFrame:index];

   if ( frame == NULL )
   {
      [_mutex unlock];
      NSAssert( NO, @"Could not access FFMpeg frame" );
   }

   // Convert the whole image, as only a slice seems to fail
   ret = sws_scale(_procConverter, (const uint8_t *const *)frame->data, frame->linesize,
                   0, _height,
                   (uint8_t *const *)&_convBuffer, &_bufLineLength);
   if ( ret < 0 )
   {
      NSLog( @"Could not convert image : %s", av_err2str(ret) );
      [_mutex unlock];
      return;
   }

   const u_short samplesPerLine = _bufLineLength / sizeof(u_short);
   for ( ys = 0; ys < h; ys++ )
   {
      const u_short yy = y + ys;

      for( xs = 0; xs < w; xs++ )
      {
         const u_short xx = x + xs;
         REAL v;

         if ( nPlanes != _numberOfPlanes && nPlanes == 1 )
         {
            // Convert to monochrome
            v = 0;
            for (cs = 0; cs < _numberOfPlanes; cs++)
               v += _convBuffer[samplesPerLine*yy + xx * _numberOfPlanes + cs];
            SET_SAMPLE( sample[0], xs, ys, lineW, v/(REAL)_numberOfPlanes/256.0 );
         }
         else
         {
            for( cs = 0; cs < nPlanes; cs++ )
            {
               v = (REAL)_convBuffer[samplesPerLine*yy + xx * _numberOfPlanes + cs];
               SET_SAMPLE( sample[cs], xs, ys, lineW, v/256.0);
            }
         }
      }
   }

   [_mutex unlock];
}

- (NSDictionary*) getMetaData 
{
   return( nil );
}

@end
