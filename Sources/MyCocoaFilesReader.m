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

/** The size by which the "time" array is enlarged. */
#define K_TIME_PAGE_SIZE 1024

#include <AppKit/NSAffineTransform.h>

#include <pthread.h>

#include "processing_core.h"
#include "MyCachePrefs.h"

#include "MyCocoaFilesReader.h"

/** Mutex used to avoid a deadlock when drawing offscreen from many threads */
static pthread_mutex_t offScreenLock;

/** Common function to retrieve a sample from an NSImage. */
static void getImageSample( REAL * const * const sample,
                            u_char nPlanes,
                            u_short atx, u_short aty, u_short atw, u_short ath, 
                            u_short width,
                            NSImage* image, LynkeosIntegerSize imageSize )
{
   NSRect cocoaRect;
   NSImageRep* srcImageRep;
   NSImage* offScreenImage;
   NSBitmapImageRep* bitMap;
   u_char *plane[5];
   int x, y, redIndex, greenIndex, blueIndex;
   u_short rowSize, pixelSize, bitsPerSample, sampleSize;
   NSBitmapFormat format;
   BOOL planar;
   float color[3];

   if ( nPlanes <= 0 || nPlanes > 3 )
   {
      NSLog( @"Invalid number of planes %d", nPlanes );
      return;
   }
   if( image == nil )
      return;

   // Convert this rectangle to Cocoa coordinates system
   cocoaRect = NSMakeRect(atx, imageSize.height - ath - aty, atw, ath );

   // Create an image to draw the NSImage in
   offScreenImage = [[[NSImage alloc] initWithSize:cocoaRect.size] autorelease];
   pthread_mutex_lock( &offScreenLock );
   [offScreenImage lockFocus];

   // Force graphic context into low resolution mode
   CGContextRef g = [NSGraphicsContext currentContext].CGContext;
   const CGAffineTransform t = CGContextGetCTM(g);
   const CGFloat det = t.a*t.d - t.b*t.c;
   if (det > 0.0)
   {
      const CGFloat scale = sqrt(det);

      NSAffineTransform * xform = [NSAffineTransform transform];
      [xform scaleBy:1.0/scale];
      [xform translateXBy: -cocoaRect.origin.x yBy: -cocoaRect.origin.y];
      [xform concat];

      srcImageRep = [image bestRepresentationForRect: NSMakeRect(0,0,imageSize.width,imageSize.height)
                                             context: nil
                                               hints: nil];
      // Force full pixel scale
      [srcImageRep drawInRect:NSMakeRect(0,0,imageSize.width,imageSize.height)];
   }
   else
      NSLog(@"Invalid transformation matrix in offscreen image");
   bitMap = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:cocoaRect] autorelease];
   [offScreenImage unlockFocus];
   pthread_mutex_unlock( &offScreenLock );

   // Access the data
   [bitMap getBitmapDataPlanes:plane];
   format = [bitMap bitmapFormat];
   rowSize = [bitMap bytesPerRow];
   bitsPerSample = [bitMap bitsPerSample];
   pixelSize = [bitMap bitsPerPixel]/8;
   if ((bitsPerSample % 8) != 0)
   {
      NSLog(@"Samples are not aligned on byte boundary : %d bits", bitsPerSample);
      return;
   }
   sampleSize = bitsPerSample/8;
   if ((format & NSBitmapFormatAlphaFirst) != 0)
   {
      redIndex = 1;
      greenIndex = 2;
      blueIndex = 3;
   }
   else
   {
      redIndex = 0;
      greenIndex = 1;
      blueIndex = 2;
   }
   planar = [bitMap isPlanar];

   for ( y = 0; y < ath; y++ )
   {
      for ( x = 0; x < atw; x++ )
      {
         u_short c;
         void *redSample, *greenSample, *blueSample;

         // Read the data in the bitmap
         if ( planar )
         {
            redSample = &plane[0][y*rowSize+x*sampleSize];
            greenSample = &plane[1][y*rowSize+x*sampleSize];
            blueSample = &plane[2][y*rowSize+x*sampleSize];
         }
         else
         {
            redSample = &plane[0][y*rowSize+x*pixelSize];
            greenSample = &plane[0][y*rowSize+x*pixelSize+sampleSize];
            blueSample = &plane[0][y*rowSize+x*pixelSize+2*sampleSize];
         }

         switch (bitsPerSample)
         {
            case 8:
               color[RED_PLANE] = (float)*(uint8_t*)redSample;
               color[GREEN_PLANE] = (float)*(uint8_t*)greenSample;
               color[BLUE_PLANE] = (float)*(uint8_t*)blueSample;
               break;
            case 16:
               if ((format & NSBitmapFormatFloatingPointSamples))
               {
                  color[RED_PLANE] = 256.0*(float)*(__fp16*)redSample;
                  color[GREEN_PLANE] = 256.0*(float)*(__fp16*)greenSample;
                  color[BLUE_PLANE] = 256.0*(float)*(__fp16*)blueSample;
               }
               else
               {
                  color[RED_PLANE] = (float)*(uint16_t*)redSample;
                  color[GREEN_PLANE] = (float)*(uint16_t*)greenSample;
                  color[BLUE_PLANE] = (float)*(uint16_t*)blueSample;
               }
               break;
            case 32:
               if ((format & NSBitmapFormatFloatingPointSamples))
               {
                  color[RED_PLANE] = *(float*)redSample;
                  color[GREEN_PLANE] = *(float*)greenSample;
                  color[BLUE_PLANE] = *(float*)blueSample;
               }
               else
               {
                  color[RED_PLANE] = (float)*(uint32_t*)redSample;
                  color[GREEN_PLANE] = (float)*(uint32_t*)greenSample;
                  color[BLUE_PLANE] = (float)*(uint32_t*)blueSample;
               }
               break;
            default:
               break;
         }
         // Convert to monochrome, if needed
         if ( nPlanes == 1 )
            color[0] = (color[RED_PLANE] 
                        + color[GREEN_PLANE] 
                        + color[BLUE_PLANE]) / 3.0;

         // Fill in the sample buffer
         for( c = 0; c < nPlanes; c++ )
            SET_SAMPLE(sample[c], x, y, width, color[c]);
      }
   }
}

@implementation MyCocoaImageReader

+ (void) initialize
{
   pthread_mutex_init( &offScreenLock, NULL );
}

+ (void) lynkeosFileTypes:(NSArray**)fileTypes
{
   *fileTypes = [NSImage imageFileTypes];
}

- (id) initWithURL:(NSURL*)url
{
   self = [super init];

   if ( self != nil )
   {
      NSImage *image;

      _path = [[url path] retain];

      image = [self getNSImage];
      if ( image != nil )
      {
         NSRect r = {{0.0, 0.0}, [image size]};
         NSImageRep *rep = [image bestRepresentationForRect:r
                                                    context:nil
                                                      hints:nil];

         _size = LynkeosMakeIntegerSize([rep pixelsWide],[rep pixelsHigh]);
      }
      else
      {
         [self release];
         self = nil;
      }
   }

   return( self );
}

- (void) dealloc
{
   [_path release];
   [super dealloc];
}

- (void) imageWidth:(u_short*)w height:(u_short*)h
{
   *w = _size.width;
   *h = _size.height;
}

// We deal only with RGB images
- (u_short) numberOfPlanes
{
   return( 3 );
}

- (void) getMinLevel:(double*)vmin maxLevel:(double*)vmax
{
   *vmin = 0.0;
   *vmax = 255.0;
}

- (NSImage*) getNSImage
{
   return( [[[NSImage alloc] initWithContentsOfFile: _path] autorelease] );
}

- (void) getImageSample:(REAL * const * const)sample
             withPlanes:(u_short)nPlanes
                    atX:(u_short)x Y:(u_short)y W:(u_short)w H:(u_short)h
              lineWidth:(u_short)width
{
   getImageSample( sample, nPlanes, x, y, w, h, width, [self getNSImage], _size );
}

- (NSDictionary*) getMetaData
{
   return( nil );
}

@end

#if !defined GNUSTEP
/*!
 * @abstract ObjC container for a CVPixelBuffer
 */
@interface MyCGImageContainer : NSObject
{
@public
   CGImageRef _img; //!< The pixel buffer we wrap around
}
//! Dedicated initializer
- (id) initWithImage:(CGImageRef)pixbuf ;
@end

@implementation MyCGImageContainer
- (id) initWithImage:(CGImageRef)pixbuf
{
   if ( (self = [self init]) != nil )
   {
      _img = pixbuf;
      CGImageRetain( _img );
   }
   return( self );
}

- (void) dealloc
{
   CGImageRelease(_img);
   [super dealloc];
}
@end

/*!
 * @abstract Private methods of MyQuickTimeReader
 */
@interface MyQuickTimeReader(Private)
//! Get a pixel buffer for the specified image, in cache or in the movie
//! The returned image is owned by the caller
- (CGImageRef) getCGImageAtIndex:(u_long)index ;
@end

@implementation MyQuickTimeReader(Private)
- (CGImageRef) getCGImageAtIndex:(u_long)index
{
   NSString *key = [_url stringByAppendingFormat:@"&%06ld",index];
   LynkeosObjectCache *movieCache = [LynkeosObjectCache movieCache];
   MyCGImageContainer *pix;
   CGImageRef img;
   NSError *err;

   if ( movieCache != nil &&
        (pix=(MyCGImageContainer*)[movieCache getObjectForKey:key]) != nil )
   {
      return( CGImageRetain(pix->_img) );
   }

   NSAssert( index < _imageNumber, @"Access outside the movie" );

   // Go to the required time
   // Try to avoid skipping frames because of multiprocessing
   [_avLock lock];
   BOOL doSkip = ( movieCache == nil
                   || index < _currentImage
                   || index > (_currentImage+numberOfCpus+1) );
   do
   {
      if ( index != _currentImage )
      {
         if ( doSkip )
            _currentImage = index;
         else
            _currentImage++;  // This fills the cache with images in between
      }

      // And get the pixel buffer content
      img = [_imageGenerator copyCGImageAtTime:_times[_currentImage] actualTime:nil error:&err];
      if ( img == NULL )
         NSLog( @"Error reading movie image, %@", err != nil ? [err localizedDescription] : @"" );

      else if ( movieCache != nil )
         [movieCache setObject:
            [[[MyCGImageContainer alloc] initWithImage:img] autorelease]
                        forKey:[_url stringByAppendingFormat:@"&%06ld",_currentImage]];
   } while ( index != _currentImage );
   [_avLock unlock];

   return( img );
}
@end

@implementation MyQuickTimeReader

+ (void) load
{
   // Nothing to do, this is just to force the runtime to load this class
}

+ (void) initialize
{
   // Things to do before first instantiation
}

+ (void) lynkeosFileTypes:(NSArray**)fileTypes
{
   *fileTypes = [NSArray arrayWithObjects: [NSNumber numberWithInteger: 1], AVFileTypeQuickTimeMovie,
                                           [NSNumber numberWithInteger: 1], AVFileTypeMPEG4,
                                           [NSNumber numberWithInteger: 1], AVFileTypeAppleM4V,
                                           nil];
}

- (id) initWithURL:(NSURL*)url
{
   NSError *qtErr = nil;
   u_long arraySize = K_TIME_PAGE_SIZE;
   CGImageRef img;

   if ( (self = [self init]) == nil )
      return( self );

   // Initialize the variables and open the movie
   _avLock = [[NSLock alloc] init];
   _times = (CMTime*)malloc( arraySize*sizeof(CMTime) );
   _imageNumber = 0;
   _movie = [[AVURLAsset alloc] initWithURL: url
                                    options: [NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:YES],
                                                AVURLAssetPreferPreciseDurationAndTimingKey,
                                                nil]];

   if ( _movie == nil )
   {
      NSLog( @"Error creating QTMovie, %@",
             qtErr != nil ? [qtErr localizedDescription] : @"" );
      [self release];
      return( nil );
   }

   _imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:_movie];
   if (_imageGenerator == nil)
   {
      NSLog(@"Could not allocate an image generator");
      [self release];
      return( nil );
   }

   _url = [[url absoluteString] retain];

   // Extract the time of each frame
   const CMTime duration = [_movie duration];
   AVAssetTrack *track = [[_movie tracksWithMediaType:AVMediaTypeVideo] firstObject];
   if (track == nil)
   {
      NSLog( @"Could not access to the track" );
      [self release];
      return( nil );
   }
   AVSampleCursor *cursor = [track makeSampleCursorAtFirstSampleInDecodeOrder];
   if (cursor == nil)
   {
      NSLog( @"Movie does not provide cursors" );
      [self release];
      return( nil );
   }

   // Find the last image time, as the cursor tends to iterate past the real movie end...
   CMTime lastImageTime = duration;
   img = [_imageGenerator copyCGImageAtTime:duration actualTime:&lastImageTime error:NULL];
   if (img != nil)
      CGImageRelease(img);


   CMTime movieTime = cursor.decodeTimeStamp;
   for (;;)
   {
      if ( _imageNumber >= arraySize )
      {
         arraySize += K_TIME_PAGE_SIZE;
         _times = (CMTime*)realloc( _times, arraySize*sizeof(CMTime) );
      }

      _times[_imageNumber] = movieTime;
      _imageNumber++;

      if ([cursor stepInDecodeOrderByCount:1] == 0)
         // At movie end
         break;
      movieTime = cursor.decodeTimeStamp;

      if (CMTimeCompare(movieTime, lastImageTime) == NSOrderedDescending)
         break; // Past last frame
   }

   _currentImage = _imageNumber;

   if ( _imageNumber == 0 )
   {
      NSLog( @"No image found in movie %@", url );
      [self release];
      return nil;
   }

   const CMTime frameDuration = [track minFrameDuration];
   const CMTime lastPlusOne = CMTimeAdd(movieTime, frameDuration);
   if ( CMTimeCompare(duration, lastPlusOne) == NSOrderedDescending )
   {
      // The reader failed to read all the movie, let FFMpeg try do to better
      NSLog( @"Failed to read entire movie %@", url );
      [self release];
      return nil;
   }

   _imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
   _imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;

   // Extract the first image and check its characteristics
   img = [_imageGenerator copyCGImageAtTime:_times[0] actualTime:nil error:&qtErr];
   if ( img == NULL )
   {
      NSLog( @"Error reading movie characteristic image, %@",
             qtErr != nil ? [qtErr localizedDescription] : @"" );
      [self release];
      return( nil );
   }

   const size_t bpp = CGImageGetBitsPerPixel(img);
   const size_t bpc = CGImageGetBitsPerComponent(img);
   if ((bpp % 8) == 0 && (bpc % 8) == 0)
   {
      const CGBitmapInfo bmInfo = CGImageGetBitmapInfo(img);

      switch (CGColorSpaceGetModel(CGImageGetColorSpace(img)))
      {
         case kCGColorSpaceModelMonochrome:
            _nPlanes = 1;
            break;
         case kCGColorSpaceModelRGB:
            _nPlanes = 3;
            break;
         default:
            NSLog(@"Unsupported color space");
            _nPlanes = 0;
            break;
      }

      _bytesPerPixel = bpp/8;

      switch (bpc)
      {
         case 8:
            _pixelType = integer8;
            break;
         case 16:
            _pixelType = integer16;
            break;
         case 32:
            if (bmInfo & kCGBitmapFloatInfoMask)
               _pixelType = float32;
            else
               _pixelType = integer32;
            break;
         case 64:
            if (bmInfo & kCGBitmapFloatInfoMask)
               _pixelType = float64;
            else
               _pixelType = integer64;
            break;
      }

      switch (bmInfo & kCGBitmapByteOrderMask)
      {
         case kCGBitmapByteOrderDefault:
            _cgBigEndian = YES;
            break;
         case kCGBitmapByteOrder16Big:
            _cgBigEndian = YES;
            break;
         case kCGBitmapByteOrder16Little:
            _cgBigEndian = NO;
            break;
         case kCGBitmapByteOrder32Big:
            _cgBigEndian = YES;
            break;
         case kCGBitmapByteOrder32Little:
            _cgBigEndian = NO;
            break;
         default:
            _cgBigEndian = YES;
            break;
      }

      switch (CGImageGetAlphaInfo(img))
      {
         case kCGImageAlphaNone:
         case kCGImageAlphaPremultipliedLast:
         case kCGImageAlphaLast:
         case kCGImageAlphaNoneSkipLast:
            _skipFirst = 0;
            break;
         case kCGImageAlphaPremultipliedFirst:
         case kCGImageAlphaFirst:
         case kCGImageAlphaNoneSkipFirst:
            _skipFirst = bpp - _nPlanes*bpc;
            break;
         case kCGImageAlphaOnly:
            NSLog(@"Alpha only movieisnotsupported");
            _nPlanes = 0;
            break;
      }
   }
   else
   {
      NSLog(@"Non byte aligned pixels are not supported");
      _nPlanes = 0;
   }

   if ( _nPlanes == 0 )
   {
      NSLog( @"Unsupported movie format" );
      [self release];
      return( nil );
   }

   _size = LynkeosMakeIntegerSize(CGImageGetWidth(img), CGImageGetHeight(img));

   CGImageRelease(img);

   return( self );
}

- (void) dealloc
{
   free( _times );
   [_avLock release];
   [_movie release];
   [_url release];

   [super dealloc];
}

- (void) imageWidth:(u_short*)w height:(u_short*)h
{
   *w = _size.width;
   *h = _size.height;
}

// We deal only with RGB images
- (u_short) numberOfPlanes
{
   return( _nPlanes );
}

- (void) getMinLevel:(double*)vmin maxLevel:(double*)vmax
{
   *vmin = 0.0;
   *vmax = 255.0;
}

- (u_long) numberOfFrames
{
   return( _imageNumber );
}

- (NSImage*) getNSImageAtIndex:(u_long)index
{
   CGImageRef img = [self getCGImageAtIndex:index];
   NSImage *res = [[[NSImage alloc] initWithCGImage:img size:NSSizeFromIntegerSize(_size)] autorelease];

   CGImageRelease(img);
   return(res);
}

- (void) getImageSample:(REAL * const * const)sample atIndex:(u_long)index
             withPlanes:(u_short)nPlanes
                    atX:(u_short)x Y:(u_short)y W:(u_short)w H:(u_short)h
              lineWidth:(u_short)width
{
   CGImageRef img = [self getCGImageAtIndex: index];
   CGColorSpaceRef colorSpace;
   u_short         dx, dy, p;

   if (img == NULL)
      return;

   colorSpace = CGColorSpaceCreateWithName(nPlanes == 3 ? kCGColorSpaceExtendedLinearSRGB
                                                        : kCGColorSpaceExtendedLinearGray);
   if (colorSpace == NULL)
   {
      CGImageRelease(img);
      fprintf(stderr, "Error allocating color space for reading movie image\n");
      return;
   }

   const u_short nComponents = (nPlanes == 3 ? 4 : 1);
   const int rowSamples = nComponents * w;
   const size_t rowSize = rowSamples * sizeof(float);
   const size_t bitmapByteCount = rowSize * h;
   float *bitmapData = (float*)malloc( bitmapByteCount );
   if (bitmapData == NULL)
   {
      NSLog (@"Could not allocate buffer for reading movie image");
      CGColorSpaceRelease( colorSpace );
      CGImageRelease(img);
      return;
   }

   CGContextRef context = CGBitmapContextCreate (bitmapData,
                                    w,
                                    h,
                                    sizeof(float) * 8,
                                    rowSize,
                                    colorSpace,
                                    kCGBitmapFloatComponents | kCGBitmapByteOrder32Host |
                                     (nPlanes == 3 ? kCGImageAlphaNoneSkipLast : 0));
   if (context == NULL)
   {
      free (bitmapData);
      CGColorSpaceRelease( colorSpace );
      CGImageRelease(img);
      fprintf (stderr, "Could not create context for reading movie image");
      return;
   }

   // Draw the image as to retrieve the sample in the bitmap (coordinates are Cocoa oriented)
   CGRect r = {.origin = {-(CGFloat)x, (CGFloat)y + (CGFloat)h - _size.height},
               .size = {(CGFloat)_size.width, (CGFloat)_size.height}};
   CGContextSetBlendMode(context, kCGBlendModeCopy);
   CGContextDrawImage(context, r, img);
   CGContextFlush(context);

   if (nComponents == sizeof(REALVECT)/sizeof(REAL))
   {
      for ( dy = 0; dy < h; dy++ )
      {
         REAL * const linePtr = &bitmapData[dy*rowSamples];
         for ( dx = 0; dx < w; dx ++ )
         {
            REALVECT v = *((REALVECT*)&linePtr[dx*nComponents]);
            for( p = 0; p < nPlanes; p++ )
            {
               // Read the data in the bitmap
               SET_SAMPLE(sample[p], dx, dy, width, v[p] * 256.0);
            }
         }
      }
   }
   else
   {
      for ( dy = 0; dy < h; dy++ )
      {
         REAL * const linePtr = &bitmapData[dy*rowSamples];
         for ( dx = 0; dx < w; dx ++ )
         {
            REAL * const pixPtr = &linePtr[dx*nComponents];
            for( p = 0; p < nPlanes; p++ )
            {
               // Read the data in the bitmap
               SET_SAMPLE(sample[p], dx, dy, width, pixPtr[p] * 256.0);
            }
         }
      }
   }

   free (bitmapData);
   CGColorSpaceRelease( colorSpace );
   CGContextRelease(context);
   CGImageRelease(img);
}

- (NSDictionary*) getMetaData
{
   return( nil );
}

@end
#endif
