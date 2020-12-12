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

#include <LynkeosCore/LynkeosProcessing.h>
#include <LynkeosCore/LynkeosMetadata.h>

#include "SER_ReaderPrefs.h"
#include "SER_Reader.h"

/*!
 * @abstract Internals of the SER reader
 * @discussion
 * @ingroup FileAccess
 */
@interface SER_Reader(Private)
@end

@implementation SER_Reader(Private)
@end

@implementation SER_Reader

+ (void) load  // Only to force the runtime to load the class
{
}

+ (void) lynkeosFileTypes:(NSArray**)fileTypes
{
   // This reader has priority over non specialized SER readers such as FFMpeg
   *fileTypes = [NSArray arrayWithObjects: [NSNumber numberWithInt:1], @"ser",nil];
}

- (id) init
{
   self = [super init];
   if ( self != nil )
   {
      NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
      _file = NULL;
      _numberOfFrames = 0;
      _numberOfPlanes = 0;
      _width = 0;
      _height = 0;
      _bytesPerPixel = 0;
      _bytesPerRow = 0;
      _filePos = 0;
      _format = SER_MONO;
      _byteOrder = SER_LITTLE_ENDIAN;
      _isBayer = NO;
      double rw = [prefs doubleForKey:K_SER_RED_KEY];
      _whiteBalance[RED_PLANE] = (rw > 0.0 ? rw : 1.0);
      double rg = [prefs doubleForKey:K_SER_GREEN_KEY];
      _whiteBalance[GREEN_PLANE] = (rg > 0.0 ? rg : 1.0);
      double rb = [prefs doubleForKey:K_SER_BLUE_KEY];
      _whiteBalance[BLUE_PLANE] = (rb > 0.0 ? rb : 1.0);
      _mode = ImageMode;
      _darkFrame = nil;
      _flatField = nil;
      _metadata = [[NSMutableDictionary alloc] init];
      _mutex = [[NSLock alloc] init];
   }
   return( self );
}

- (id) initWithURL:(NSURL*)url
{
   int          ret;
   SER_Header_t ser;

   self = [self init];

   if ( self != nil )
   {
      // Open video file
      _file = fopen([[url path] fileSystemRepresentation], "rb");
      if ( _file == NULL )
      {
         NSLog( @"Could not open file %@", [url absoluteString] );
         [self release];
         return( nil );
      }

      // Retrieve stream information
      ret = SER_read_header(_file, &ser);
      if ( ret < 0 )
      {
         NSLog( @"Could not read SER header");
         [self release];
         return( nil );
      }

      _numberOfFrames = ser.FrameCount;
      _width = ser.ImageWidth;
      _height = ser.ImageHeight;
      _bytesPerPixel = (ser.PixelDepthPerPlane + 7)/8;
      _format = ser.ColorID;
      _byteOrder = ser.LittleEndian;
      switch (_format)
      {
         case SER_MONO:
            _numberOfPlanes = 1;
            _bytesPerRow = _width * _bytesPerPixel;
            break;

         case SER_BAYER_RGGB:
         case SER_BAYER_GRBG:
         case SER_BAYER_GBRG:
         case SER_BAYER_BGGR:
         case SER_BAYER_CYYM:
         case SER_BAYER_YCMY:
         case SER_BAYER_YMCY:
         case SER_BAYER_MYYC:
            _numberOfPlanes = 3;
            _bytesPerRow = _width * _bytesPerPixel;
            _isBayer = YES;
            switch (_format)
            {
               case SER_BAYER_CYYM: // Planes in CYM order
               case SER_BAYER_RGGB:
                  _bayerPlanes[0][0] = 0; _bayerPlanes[0][1] = 1;
                  _bayerPlanes[1][0] = 1; _bayerPlanes[1][1] = 2;
                  break;
               case SER_BAYER_YCMY: // Planes in CYM order
               case SER_BAYER_GRBG:
                  _bayerPlanes[0][0] = 1; _bayerPlanes[0][1] = 0;
                  _bayerPlanes[1][0] = 2; _bayerPlanes[1][1] = 1;
                  break;
               case SER_BAYER_YMCY: // Planes in CYM order
               case SER_BAYER_GBRG:
                  _bayerPlanes[0][0] = 1; _bayerPlanes[0][1] = 2;
                  _bayerPlanes[1][0] = 0; _bayerPlanes[1][1] = 1;
                  break;
               case SER_BAYER_MYYC: // Planes in CYM order
               case SER_BAYER_BGGR:
                  _bayerPlanes[0][0] = 2; _bayerPlanes[0][1] = 1;
                  _bayerPlanes[1][0] = 1; _bayerPlanes[1][1] = 0;
                  break;
               default: // Non bayer format will not occur here
                  break;
            }
            break;

         case SER_RGB:
         case SER_BGR:
            _numberOfPlanes = 3;
            _bytesPerRow = _width * _bytesPerPixel * _numberOfPlanes;
            break;

         default:
            NSLog(@"Unknown pixel format %d", _format);
            [self release];
            return( nil );
            break;
      }

      // Retrieve metadata
      if (strnlen(ser.Observer, SER_STRING_LENGTH) != 0)
         [_metadata setObject:[NSString stringWithCString:ser.Observer encoding:NSUTF8StringEncoding]
                       forKey:LynkeosMD_Authors()];
      if (strnlen(ser.Instrument, SER_STRING_LENGTH) != 0)
         [_metadata setObject:[NSString stringWithCString:ser.Instrument encoding:NSUTF8StringEncoding]
                       forKey:LynkeosMD_CameraModel()];
      if (strnlen(ser.Telescope, SER_STRING_LENGTH) != 0)
         [_metadata setObject:[NSString stringWithCString:ser.Telescope encoding:NSUTF8StringEncoding]
                       forKey:LynkeosMD_Telescope()];
      if (ser.DateTime_UTC >= 0)
         [_metadata setObject:[NSDate dateWithTimeIntervalSinceReferenceDate:
                                  (NSTimeInterval)(ser.DateTime_UTC - SER_DATE_ORIGIN)*SER_DATE_TIMEBASE]
                       forKey:LynkeosMD_CaptureDate()];
   }

   return( self );
}

- (void) dealloc
{
   if (_file != NULL)
      fclose(_file);
   if (_darkFrame != nil)
      [_darkFrame release];
   if (_flatField != nil)
      [_flatField release];
   [_metadata release];
   [_mutex release];

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
                                                samplesPerPixel:_numberOfPlanes
                                                       hasAlpha:NO
                                                       isPlanar:NO
                                                 colorSpaceName: _numberOfPlanes == 1 ?
                                                                    NSCalibratedWhiteColorSpace :
                                                                    NSCalibratedRGBColorSpace
                                                    bytesPerRow:0
                                                   bitsPerPixel:0]
             autorelease];

   if ( bitmap != nil )
   {
      u_char *pixels = (u_char*)[bitmap bitmapData];
      int bpr = (int)[bitmap bytesPerRow];
      int bpp = (int)[bitmap bitsPerPixel]/8;
      const size_t imageSize = _height*_bytesPerRow;
      void *buffer = malloc(imageSize);
      const off_t imageOffset = SER_START_OF_IMAGES + index*imageSize;
      u_short x, y, p;
      int ret = 0;
      size_t nread = 0;

      [_mutex lock];

      if (_filePos != imageOffset)
         ret = fseeko(_file, imageOffset, SEEK_SET);
      if (ret == 0)
         nread = fread(buffer, _bytesPerRow, _height, _file);
      if (nread == _height)
         _filePos = imageOffset + imageSize;

      [_mutex unlock];

      if (nread == _height)
      {
         for( y = 0; y < _height; y++ )
         {
            void *linePtr = buffer + y*_bytesPerRow;
            for( x = 0; x < _width; x++ )
            {
               void *pixPtr = linePtr + x*_bytesPerPixel;
               u_char v;
               for ( p = 0 ; p < _numberOfPlanes; p++ )
               {
                  if (_isBayer)
                  {
                     if (_bayerPlanes[y%2][x%2] == p)
                     {
                        if (_bytesPerPixel == 2)
                        {
                           uint16 iv;
                           iv = ((uint16*)pixPtr)[0];
                           if (_byteOrder == SER_BIG_ENDIAN)
                              v = (double)CFSwapInt16BigToHost(iv)/256.0;
                           else
                              v = (double)CFSwapInt16LittleToHost(iv)/256.0;
                        }
                        else
                        {
                           v = (double)((uint8*)pixPtr)[0];
                        }
                        double vf = (double)v * _whiteBalance[p];
                        v = (vf < 256.0 ? (u_char)v : 255);
                     }
                     else
                     {
                        // Perform a simple linear interpolation
                        const u_short mxl = (x < _width - 1 ? x + 1 : _width - 1);
                        const u_short myl = (y < _height - 1 ? y + 1 : _height - 1);
                        const u_short sxl = (x < 1 ? 0 : x - 1), syl = (y < 1 ? 0 : y - 1);
                        u_short xl, yl;
                        double sum = 0.0, weight = 0.0, vf;
                        for ( yl = syl; yl <= myl; yl++)
                        {
                           void *interpolationLinePtr = buffer + yl*_bytesPerRow;
                           for ( xl = sxl; xl <= mxl; xl++)
                           {
                              void *interpolationPixPtr = interpolationLinePtr + xl*_bytesPerPixel;
                              if (_bayerPlanes[yl%2][xl%2] == p)
                              {
                                 if (_bytesPerPixel == 2)
                                 {
                                    uint16 iv;
                                    iv = ((uint16*)interpolationPixPtr)[0];
                                    if (_byteOrder == SER_BIG_ENDIAN)
                                       vf = (double)CFSwapInt16BigToHost(iv)/256.0 * _whiteBalance[p];
                                    else
                                       vf = (double)CFSwapInt16LittleToHost(iv)/256.0 * _whiteBalance[p];
                                    if (vf >= 256.0)
                                       vf = 65535.0/256.0;
                                 }
                                 else
                                 {
                                    vf = (double)((uint8*)interpolationPixPtr)[0] * _whiteBalance[p];
                                    if (vf > 255.0)
                                       vf = 255.0;
                                 }
                                 sum += vf;
                                 weight += 1.0;
                              }
                           }
                        }
                        v = (u_char)(sum/weight);
                     }
                  }
                  else
                  {
                     if (_bytesPerPixel == 2)
                     {
                        uint16 iv;
                        if (_format == SER_BGR)
                           iv = ((uint16*)pixPtr)[2-p];
                        else
                           iv = ((uint16*)pixPtr)[p];
                        if (_byteOrder == SER_BIG_ENDIAN)
                           v = CFSwapInt16BigToHost(iv)/256;
                        else
                           v = CFSwapInt16LittleToHost(iv)/256;
                     }
                     else
                     {
                        if (_format == SER_BGR)
                           v = ((uint8*)pixPtr)[2-p];
                        else
                           v = ((uint8*)pixPtr)[p];
                     }
                  }
                  pixels[y*bpr+x*bpp+p] = v;
               }
            }
         }
      }

      free(buffer);

      image = [[[NSImage alloc] initWithSize:NSMakeSize(_width, _height)] autorelease];

      if ( image != nil )
         [image addRepresentation:bitmap];
   }

   return( image );
}

- (void) setMode:(ListMode_t)mode { _mode = mode; }

- (void) setDarkFrame:(LynkeosImageBuffer*)dark
{
   if (_darkFrame != nil)
   {
      [_darkFrame release];
      _darkFrame = nil;
   }
   NSAssert(dark == nil || _mode == ImageMode || _mode == UnsetListMode,
            @"Bad reader mode to set dark frame %d", _mode);
   NSAssert(dark == nil || [dark isKindOfClass:[SER_ImageBuffer class]],
            @"SER dark frame is not in SER format");
   _darkFrame = (SER_ImageBuffer*)[dark copy];

   if (_darkFrame != nil)
   {
      // Weight will be substracted, therefore, set all weight to zero, except for dead pixels
      // Start by getting mean and standard deviation of pixels in the bayer matrix
      u_short c, x, y;
      double s = 0.0, s2 = 0.0, n = 0.0;
      for (y = 0; y < _darkFrame->_h; y++)
      {
         for (x = 0; x < _darkFrame->_w; x++)
         {
            for (c = 0; c < _darkFrame->_nPlanes; c++)
            {
               double w = stdColorValue(_darkFrame->_weight, x, y, c);
               double v = w*stdColorValue(_darkFrame, x, y, c);
               s += v;
               s2 += v*v;
               n += w;
            }
         }
      }
      double mean = s/n;
      double sigma = sqrt(s2/n - mean*mean);
      for (y = 0; y < _darkFrame->_h; y++)
      {
         for (x = 0; x < _darkFrame->_w; x++)
         {
            for (c = 0; c < _darkFrame->_nPlanes; c++)
            {
               if (stdColorValue(_darkFrame->_weight, x, y, c) <= 0.0
                   || (stdColorValue(_darkFrame, x, y, c) - mean) < 3.0*sigma)
                  // Correct pixel, weight shall not change in calibrated image
                  stdColorValue(_darkFrame->_weight, x, y, c) = 0.0;
               // Otherwise, it is a dead pixel, keep the weight, in order to null it in the  calibrated image
//               else
//                  NSLog(@"Dead pixel at %d,%d in plane %d, value %f weight %f",
//                        x, y, c, stdColorValue(_darkFrame, x, y, c),
//                        stdColorValue(_darkFrame->_weight, x, y, c));
            }
         }
      }
   }
}

- (void) setFlatField:(LynkeosImageBuffer*)flat
{
   if (_flatField != nil)
   {
      [_flatField release];
      _flatField = nil;
   }
   NSAssert(_flatField == nil || _mode == ImageMode || _mode == UnsetListMode,
            @"Bad reader mode to set flat field %d", _mode);
   _flatField = [flat retain];
}

- (BOOL) canBeCalibratedBy:(id <LynkeosFileReader>)reader asMode:(ListMode_t)mode
{
   return [reader isKindOfClass:[self class]];
}

- (void) getImageSample:(REAL * const * const)sample atIndex:(u_long)index
             withPlanes:(u_short)nPlanes
                    atX:(u_short)x Y:(u_short)y W:(u_short)w H:(u_short)h
              lineWidth:(u_short)lineW
{
   const NSAffineTransformStruct ident = {1.0, 0.0, 0.0, 1.0, 0.0, 0.0};
   const NSPoint still[3] = {{0.0, 0.0}, {0.0, 0.0}, {0.0, 0.0}};
   LynkeosImageBuffer* customImage = [self getCustomImageSampleAtIndex:index atX:x Y:y W:w H:h
                                                             withTransform:ident withOffsets:still];
   [customImage convertToPlanar:sample withPlanes:nPlanes lineWidth:lineW];
}

- (LynkeosImageBuffer*) getCustomImageSampleAtIndex:(u_long)index
                                                    atX:(u_short)x Y:(u_short)y
                                                      W:(u_short)w H:(u_short)h
                                          withTransform:(NSAffineTransformStruct)transform
                                            withOffsets:(const NSPoint*)offsets
{
   // Read the data
   const size_t imageSize = _height*_bytesPerRow;
   void *buffer = malloc(imageSize);
   u_short nPlanes = (_isBayer ? 1 : _numberOfPlanes);
   REAL *imageData = (REAL*)malloc(_width*_height*nPlanes*sizeof(REAL));
   const off_t imageOffset = SER_START_OF_IMAGES + index*imageSize;
   int ret = 0;
   size_t nread = 0;
   LynkeosImageBuffer* image = nil;
   u_short xl, yl, p;
   REAL v;

   [_mutex lock];

   if (_filePos != imageOffset)
      ret = fseeko(_file, imageOffset, SEEK_SET);
   if (ret == 0)
      nread = fread(buffer, _bytesPerRow, _height, _file);
   if (nread == _height)
      _filePos = imageOffset + imageSize;

   [_mutex unlock];

   if (nread == _height)
   {
      for( yl = 0; yl < _height; yl++ )
      {
         void *linePtr = buffer + yl*_bytesPerRow;
         for( xl = 0; xl < _width; xl++ )
         {
            void *pixPtr = linePtr + xl*_bytesPerPixel;

            for ( p = 0 ; p < nPlanes; p++ )
            {
               if (_bytesPerPixel == 2)
               {
                  uint16 iv;
                  if (_format == SER_BGR)
                     iv = ((uint16*)pixPtr)[2-p];
                  else
                     iv = ((uint16*)pixPtr)[p];
                  if (_byteOrder == SER_BIG_ENDIAN)
                     v = CFSwapInt16BigToHost(iv)/256;
                  else
                     v = CFSwapInt16LittleToHost(iv)/256;
                  if (_isBayer)
                     v *= _whiteBalance[_bayerPlanes[yl%2][xl%2]];
                  else
                     v *= _whiteBalance[p];
                  if (v >= 256.0)
                     v = 65535.0/256.0;
               }
               else
               {
                  if (_format == SER_BGR)
                     v = ((uint8*)pixPtr)[2-p];
                  else
                     v = ((uint8*)pixPtr)[p];
                  if (_isBayer)
                     v *= _whiteBalance[_bayerPlanes[yl%2][xl%2]];
                  else
                     v *= _whiteBalance[p];
                  if (v > 255.0)
                     v = 255.0;
               }
               imageData[xl+_width*(yl+p*_height)] = v;
            }
         }
      }
   }

   free(buffer);

   if (_isBayer)
   {
      image = [[[SER_ImageBuffer alloc] initWithData:imageData format:_format
                                               width:_width lineW:_width height:_height
                                                 atX:x Y:y W:w H:h
                                       withTransform:transform withOffsets:offsets
                                            withDark: _darkFrame withFlat:_flatField] autorelease];
      free(imageData);
   }
   else
      image = [[[LynkeosImageBuffer alloc] initWithData:imageData copy:YES freeWhenDone:YES
                                                 numberOfPlanes:_numberOfPlanes
                                                          width:_width paddedWidth:_width height:_height]
               autorelease];
#warning Non bayer image is not the correct origin and size, neither has transform applied
   return image;
}

- (NSDictionary*) getMetaData 
{
   return( _metadata );
}

@end
