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

#include <AppKit/NSGraphics.h>

#include <LynkeosCore/LynkeosImageBuffer.h>
#include <LynkeosCore/LynkeosMetadata.h>
#include "processing_core.h"
#include "DcrawReaderPrefs.h"
#include "DcrawReader.h"

#define K_COUNTER_KEY @"ImageCount"

static NSMutableArray *rawFilesTypes = nil;

static NSCursor *watchCursor = nil;
static NSPanel *progressPanel = nil;
static NSProgressIndicator *progressIndicator = nil;
static NSModalSession progressSession = nil;
static NSMutableArray *pendingConversions = nil, *ongoingConversions = nil;
static u_short maxConversions = 0;
static NSTimer *convWaitTimer = nil;
static BOOL isWaitingConversion = NO;

/*!
 * @abstract The RAW custom image class
 * @discussion It is used to hold the dark frame, but also as a proxy for the flat and light
 * @ingroup FileAccess
 */
@interface DcrawCustomImage : LynkeosImageBuffer
{
   NSString *_pgmFilePath;
}

- (NSString*) fileName;
@end

@interface DcrawCustomImage(Private)
- (void) saveAsPgm;
@end

/*!
 * @abstract Private part of the DCRAW readder class
 * @ingroup FileAccess
 */
@interface DcrawReader(Private)
/*!
 * @abstract Extract image informations
 */
- (void) getImageInfo ;

/*!
 * @abstract Launch the conversion
 */
- (void) launchConversion ;

/*!
 * @abstract Wait for the dcraw task to complete the conversion.
 * @result None
 */
- (void) waitForConversion ;

/*!
 * @abstract Extract a data sample in the converted PPM file
 * @param data The data buffer to fill
 * @param x X coordinate of the sample
 * @param y Y coordinate of the sample
 * @param w Width of the sample
 * @param h Height of the sample
 */
- (void) getPPMsample:(u_short*)data 
                  atX:(u_short)x Y:(u_short)y 
                    W:(u_short)w H:(u_short)h;
@end

@implementation DcrawCustomImage(Private)

- (void) saveAsPgm
{
   NSUserDefaults *pref = [NSUserDefaults standardUserDefaults];
   int cnt;
   const char *tmpdir = NULL;
   FILE *pgmFile;
   u_short x, y;

   // Create a temporary filename for the PGM file
   NSString *tmpdirStr = [pref stringForKey:K_TMPDIR_KEY];
   if ( tmpdirStr != nil )
      tmpdir = [[tmpdirStr stringByExpandingTildeInPath] UTF8String];
   if ( tmpdir == NULL || *tmpdir == '\0' )
      tmpdir = getenv("TMPDIR");
   if ( tmpdir == NULL || *tmpdir == '\0' )
      tmpdir = "/tmp";
   // with a count suffix shared by all documents
   cnt = [pref integerForKey:K_COUNTER_KEY] % 10000;
   _pgmFilePath = [[NSString stringWithFormat:@"%s/dark%04d.pgm",
                    tmpdir, cnt] retain];
   cnt++;
   [pref setInteger:cnt forKey:K_COUNTER_KEY];

   pgmFile = fopen([_pgmFilePath fileSystemRepresentation], "wb");

   fprintf( pgmFile, "P5\n" );

   fprintf( pgmFile, "%d %d\n", _w, _h );
   fprintf( pgmFile, "%d\n", 65535 );

   for( y = 0; y < _h; y++ )
   {
      for( x = 0; x < _w; x++ )
      {
         REAL v = GET_SAMPLE(_data,x,y,_padw);
         u_short outValue;

         if ( v < 0.0 )
            v = 0.0;
         else if ( v > 65535.0 )
            v = 65535.0;

         outValue = NSSwapHostShortToBig((u_short)(v+0.5));

         fwrite( &outValue, 1, 2, pgmFile );
      }
   }
   
   fclose( pgmFile );
}

@end

@implementation DcrawCustomImage

- (id) init
{
   self = [super init];
   if ( self != nil )
      _pgmFilePath = nil;

   return( self );
}

- (void) dealloc
{
   NSError *err;

   if ( _pgmFilePath != nil )
   {
      if ( ![[NSFileManager defaultManager] removeItemAtURL:
                                            [NSURL fileURLWithPath:_pgmFilePath]
                                                  error:&err] )
      NSLog( @"Could not remove temporary raw saved dark image %@. %@", _pgmFilePath, [err description]);
   }

   [super dealloc];
}

- (NSString*) fileName
{
   if ( _pgmFilePath == nil )
      [self saveAsPgm];

   return( _pgmFilePath );
}

- (void) calibrateWithDarkFrame:(LynkeosImageBuffer*)darkFrame
                      flatField:(LynkeosImageBuffer*)flatField
                            atX:(u_short)ox Y:(u_short)oy
{
   // Dark frame is already applied
   if ( flatField != nil )
      [super calibrateWithDarkFrame:nil flatField:flatField atX:ox Y:oy];
}

@end

@implementation DcrawReader(Private)
- (void) delayedLaunch:(NSTimer*)timer
{
   _conversionTimer = nil;
   [self launchConversion];
}

- (void) getImageInfo
{
   NSAssert(_mode != UnsetListMode, @"Attempt to get image info without mode set");

   // Prepare a task
   NSTask *infoTask = [[NSTask alloc] init];

   NSAssert(infoTask != nil, @"Failed to create a task to get RAW info");

   // Set its executable path to dcraw in our ressources
   NSString *dcrawPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"dcraw"
                                                                          ofType:nil];
   [infoTask setLaunchPath:dcrawPath];

   // Connect its output to a pipe
   NSPipe *infoPipe = [NSPipe pipe];
   [infoTask setStandardOutput:infoPipe];

   // Options : "verbose informations"
   NSMutableArray *args = [NSMutableArray arrayWithObjects: @"-i", @"-v", nil];
   // And maybe no image rotation
   if ( _mode == DarkFrameMode ||
        ![[NSUserDefaults standardUserDefaults] boolForKey:K_ROTATION_KEY] )
   {
      [args addObject:@"-t"];
      [args addObject:@"0"];
   }

   // The last arg is the file to convert
   [args addObject:[_url path]];

   [infoTask setArguments:args];

   // Run to get the information
   [infoTask launch];

   // Read the output
   NSData *info = [[infoPipe fileHandleForReading] readDataToEndOfFile];

   while ([infoTask isRunning])
   {
      if (progressSession != nil)
         [NSApp runModalSession:progressSession];
      [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
   }

   NSAssert( [infoTask terminationStatus] == 0,
             @"Could not get information on %@", _url );
   [infoTask release];

   // Scan the output to find the image information
   NSScanner *scan = [NSScanner scannerWithString:
                         [[[NSString alloc] initWithData:info
                                                encoding:NSUTF8StringEncoding]
                                                                  autorelease]];
   [scan setCharactersToBeSkipped:[NSCharacterSet whitespaceCharacterSet]];
   BOOL success = YES;
   int w = 0, h = 0;
   while ( success && ![scan isAtEnd] )
   {
      NSString *token, *marker = @":";

      // Get to the start of the next token
      [scan scanUpToCharactersFromSet:[NSCharacterSet alphanumericCharacterSet]
                           intoString:NULL];

      success = [scan scanUpToString:marker intoString:&token];
      if ( success )
         success = [scan scanString:marker intoString:NULL];

      if ( success )
      {
         if ( [token isEqualToString:@"Output size"] )
         {
            if ( [scan scanInt:&w]
                 && [scan scanString:@"x" intoString:NULL]
                 && [scan scanInt:&h] )
            {
               _width = w;
               _height = h;
            }
         }
         else if ( [token isEqualToString:@"Image size"] )
         {
            if ( [scan scanInt:&w]
                 && [scan scanString:@"x" intoString:NULL]
                 && [scan scanInt:&h] )
            {
               _baseWidth = w;
               _baseHeight = h;
            }
         }
         else if ( [token isEqualToString:@"Camera"] )
         {
            NSString *camera;
            if ([scan scanUpToCharactersFromSet: [NSCharacterSet newlineCharacterSet]
                                     intoString: &camera])
               [_metadata setObject: camera forKey: LynkeosMD_CameraModel()];
         }
         else if ( [token isEqualToString:@"Shutter"] )
         {
            double numerator, denominator;
            if ( [scan scanDouble: &numerator] )
            {
               if ( [scan scanString:@"/" intoString:NULL] )
               {
                  if ( ![scan scanDouble: &denominator] )
                     // Invalid format
                     denominator = 0.0;
               }
               else
                  denominator = 1.0;
               if (denominator != 0.0)
                  [_metadata setObject: [NSNumber numberWithDouble: numerator/denominator]
                                forKey: LynkeosMD_ExposureTime()];
            }
         }
         else if ( [token isEqualToString:@"Aperture"] )
         {
            if ( [scan scanString:@"f/" intoString:NULL] )
            {
               double aperture;
               if ( [scan scanDouble: &aperture] )
                  [_metadata setObject: [NSNumber numberWithDouble: aperture]
                                forKey: LynkeosMD_Aperture()];
            }
         }
         else if ( [token isEqualToString:@"ISO speed"] )
         {
            int iso;
            if ( [scan scanInt:&iso] )
                [_metadata setObject: [NSNumber numberWithInt:iso] forKey: LynkeosMD_ISOSpeed()];
         }
         // TODO : get the remaining info

         [scan scanUpToCharactersFromSet: [NSCharacterSet newlineCharacterSet]
                              intoString: NULL];
      }
   }
}

- (void) launchConversion
{
   NSAssert(_mode != UnsetListMode, @"Cannot convert without the mode");

   // Abort ongoing conversion, if any
   if (_dcrawTask != nil && [_dcrawTask isRunning] )
   {
      [_dcrawTask terminate];
      [_dcrawTask waitUntilExit];
      [_dcrawTask release];
      _dcrawTask = nil;
      [ongoingConversions removeObject:self];
   }

   // Start the conversion if one cpu is available
   if (ongoingConversions.count < maxConversions)
   {
      // OK go on
      // Prepare a task for the conversion
      _dcrawTask = [[NSTask alloc] init];

      if ( _dcrawTask != nil )
      {
         NSFileManager *fileMgr = [NSFileManager defaultManager];
         NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

         // Set its executable path to dcraw in our ressources
         NSString *dcrawPath
            = [[NSBundle bundleForClass:[self class]] pathForResource:@"dcraw"
                                                               ofType:nil];
         [_dcrawTask setLaunchPath:dcrawPath];

         // Create an empty file by this name
         [fileMgr createFileAtPath:_ppmFilePath contents:nil attributes:nil];
         [_dcrawTask setStandardOutput: [NSFileHandle fileHandleForWritingAtPath:_ppmFilePath]];

         // Common option to DCRAW is : "output on stdout, 16 bits" PPM"
         NSMutableArray *args = [NSMutableArray arrayWithObjects: @"-c", @"-4", nil];

         switch ( _mode )
         {
            case DarkFrameMode:
               // Dark frames are extracted without rotation,
               [args addObject:@"-t"];
               [args addObject:@"0"];
               // in "raw document mode"
               [args addObject:@"-D"];
               break;

            case ImageMode:
               if ( _dark != nil )
               {
                  // Dark frame option
                  [args addObject:@"-K"];
                  [args addObject:[(DcrawCustomImage*)_dark fileName]];
               }

               // Fall through to options common with flat field
            
            case FlatFieldMode:
               // User preferences options

               // Image rotation
               if ( ![prefs boolForKey:K_ROTATION_KEY] )
               {
                  // Or not
                  [args addObject:@"-t"];
                  [args addObject:@"0"];
               }

               if ( [prefs boolForKey:K_MANUALWB_KEY] )
               {
                  // Custom white balance
                  [args addObject:@"-r"];
                  [args addObject:[prefs stringForKey:K_RED_KEY]];
                  [args addObject:[prefs stringForKey:K_GREEN1_KEY]];
                  [args addObject:[prefs stringForKey:K_BLUE_KEY]];
                  [args addObject:[prefs stringForKey:K_GREEN2_KEY]];
               }
               else
                  [args addObject:@"-w"];    // Camera white balance

               if ( [prefs boolForKey:K_LEVELS_KEY] )
               {
                  // Custom dark and saturation levels
                  [args addObject:@"-k"];
                  [args addObject:[prefs stringForKey:K_DARK_KEY]];
                  [args addObject:@"-S"];
                  [args addObject:[prefs stringForKey:K_SATURATION_KEY]];
               }
               break;
            default:
               NSAssert(NO, @"Invalid image mode %d", _mode );
               break;
         }

         // The last arg is the file to convert
         [args addObject:[_url path]];

         [_dcrawTask setArguments:args];

         // Start the conversion
         [_dcrawTask launch];

         [ongoingConversions addObject:self];

         NSAssert( _dcrawTask != nil && ([_dcrawTask isRunning] || [_dcrawTask terminationStatus] == 0),
                  @"Could not start the conversion of %@", _url );
      }
   }
   else
   {
      // Nope, queue it for later processing
      [pendingConversions addObject:self];
   }

   // Schedule waiting for conversion end, but letting time to coalesce several conversions
   if ( !isWaitingConversion )
   {
      if (convWaitTimer != nil)
         [convWaitTimer invalidate];

      convWaitTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:NO block:
                       ^(NSTimer *timer)
                       {
                          isWaitingConversion = YES;
                          convWaitTimer = nil;

                          [progressIndicator stopAnimation:self];
                          progressIndicator.indeterminate = NO;

                          while (ongoingConversions.count > 0)
                          {
                             DcrawReader *firstConv = [ongoingConversions objectAtIndex:0];
                             [firstConv waitForConversion];
                          }

                          isWaitingConversion = NO;
                       }];
   }
}

- (void) waitForConversion
{
   // If the conversion is not finished, wait for its completion
   if (  _dcrawTask != nil )
   {
      FILE * ppmFile;

      if ( [_dcrawTask isRunning] )
      {
         // For a reason not fully understood, we shall wait a bit before
         // setting the cursor to a watch icon
         [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
         [watchCursor push];

         while ([_dcrawTask isRunning])
         {
            if (progressSession != nil)
               [NSApp runModalSession:progressSession];
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
         }

         [NSCursor pop];
      }

      // When succesful, initialize the PPM file info
      if ( [_dcrawTask terminationStatus] == 0 )
      {
         char line[40];
         u_short w, h;

         ppmFile = fopen( [_ppmFilePath fileSystemRepresentation], "rb" );

         fgets( line, 40, ppmFile ); // First line of input "P5" or "P6"
         if ( strcmp( "P5\n", line ) == 0 )
            NSAssert( _numberOfPlanes == 1,
                      @"Number of planes inconsistent after conversion" );
         else if ( strcmp( "P6\n", line ) == 0 )
            NSAssert( _numberOfPlanes == 3,
                      @"Number of planes inconsistent after conversion" );

         fgets( line, 40, ppmFile ); // Second line "w h"
         NSAssert( sscanf( line, "%hu %hu", &w, &h ) == 2,
                   @"Cannot read image size after conversion" );
         NSAssert( w == _width && h == _height,
                   @"Image size inconsistent after conversion" );
         fgets( line, 40, ppmFile ); // Third line "max"
         if ( sscanf( line, "%hu", &_dataMax ) != 1 )
            _dataMax = 0;

         _ppmDataOffset = ftell( ppmFile );

         // Don(t keep the file open, it may overflow the maximum number of open
         // file descriptors
         fclose( ppmFile );
      }

      // Anyway, the task has ended
      [_dcrawTask release];
      _dcrawTask = nil;

      [ongoingConversions removeObject:self];
      progressIndicator.doubleValue += 1.0;

      // Find the next image to convert, if any
      DcrawReader *nextReader = nil;
      if ([pendingConversions count] != 0)
      {
         nextReader = (DcrawReader*)[pendingConversions objectAtIndex:0];
         [pendingConversions removeObjectAtIndex:0];
      }
      // Start the next conversion, if any
      if (nextReader != nil)
         [nextReader launchConversion];

      // When finished, remove the loading progress panel
      if (ongoingConversions.count == 0 && pendingConversions.count == 0)
      {
//         [NSApp runModalSession:progressSession];
//         [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
         if (progressSession != nil)
         {
            [NSApp endModalSession:progressSession];
            progressSession = nil;
         }
         [progressPanel close];
      }
   }
}

- (void) getPPMsample:(u_short*)data 
                  atX:(u_short)x Y:(u_short)y 
                    W:(u_short)w H:(u_short)h
{
   FILE * ppmFile;

   [self waitForConversion];

   // Open and close the file at each read, to keep open file descriptors number low
   ppmFile = fopen( [_ppmFilePath fileSystemRepresentation], "rb");
   if( ppmFile != NULL )
   {
      u_short ys;

      // Transfer "w" pixels from "h" lines
      for( ys = 0; ys < h; ys++ )
      {
         // Jump to the line start
         fseek( ppmFile,
                _ppmDataOffset + sizeof(u_short)*_numberOfPlanes*((y+ys)*_width+x),
                SEEK_SET );
         fread( &data[ys*w*_numberOfPlanes], _numberOfPlanes*sizeof(u_short), w, ppmFile );
      }

      fclose( ppmFile );
   }
}
@end

@implementation DcrawReader

+ (void) load
{
   // Nothing to do, this is just to force the runtime to load this class
}

+ (void) initialize
{
   if ( watchCursor == nil )
      watchCursor = [[NSCursor alloc] initWithImage:
                       [NSImage imageNamed:@"watch"]
                                              hotSpot:NSMakePoint(8,8)];

   pendingConversions = [[NSMutableArray alloc] init];
   ongoingConversions = [[NSMutableArray alloc] init];
   maxConversions = numberOfCpus + 1;

   progressPanel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0.0, 0.0, 250.0, 50.0)
                                              styleMask:NSWindowStyleMaskTitled
                                                backing:NSBackingStoreBuffered
                                                  defer:YES];
   progressPanel.title = @"Converting RAW image";
   progressPanel.releasedWhenClosed = NO;
   progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0.0, 0.0, 250.0, 50.0)];
   progressIndicator.style = NSProgressIndicatorBarStyle;
   progressIndicator.minValue = 0.0;
   progressIndicator.usesThreadedAnimation = YES;
   progressPanel.contentView = progressIndicator;
}

+ (void) lynkeosFileTypes:(NSArray**)fileTypes
{
   // Read the file extensions in the configuration file
   if ( rawFilesTypes == nil )
   {
      NSNumber *pri = [NSNumber numberWithInt:1];
      NSString *cfgFile;
      NSArray *cfgFileTypes;
      cfgFile = [[NSBundle bundleForClass:[self class]] pathForResource:
                                                        @"dcraw_file_extensions"
                                                               ofType:@"plist"];
      NSData *plistData;
      NSString *error;
      NSPropertyListFormat format;
      NSMutableDictionary *dict;
      plistData = [NSData dataWithContentsOfFile:cfgFile];
      dict = [NSPropertyListSerialization propertyListFromData:plistData
                                mutabilityOption:NSPropertyListMutableContainers
                                                        format:&format
                                              errorDescription:&error];
      NSAssert( dict != nil, @"Failed to read RAW files configuration" );
      cfgFileTypes = [dict objectForKey:@"extensions"];
      NSAssert( cfgFileTypes != nil,
               @"Failed to access to RAW files extensions" );

      rawFilesTypes =
             [[NSMutableArray arrayWithCapacity:[cfgFileTypes count]*2] retain];

      NSEnumerator *list;
      NSString *fileType;
      for( list = [cfgFileTypes objectEnumerator];
           (fileType = [list nextObject]) != nil ; )
      {
         [rawFilesTypes addObject:pri];
         [rawFilesTypes addObject:fileType];
      }

   }
   *fileTypes = rawFilesTypes;
}

- (id) init
{
   self = [super init];
   if ( self != nil )
   {
      _url = nil;
      _dcrawTask = nil;
      _ppmFilePath = nil;
      _ppmDataOffset = 0;
      _dataMax = 0;
      _width = 0;
      _height = 0;
      _baseWidth = 0;
      _baseHeight = 0;
      _numberOfPlanes = 0;
      _mode = UnsetListMode;
      _dark = nil;
      _metadata = [[NSMutableDictionary dictionary] retain];
      _conversionTimer = nil;
   }
   return( self );
}

- (id) initWithURL:(NSURL*)url
{
   NSFileManager *fileMgr = [NSFileManager defaultManager];

   if ( [fileMgr isReadableFileAtPath:[url path]] )
      self = [self init];

   else
   {
      [self release];
      self = nil;
   }

   if ( self != nil )
   {
      _url = [url retain];

      // If not yet done, pop the load progress panel
      if ( progressSession == nil )
      {
         progressIndicator.maxValue = 0.0;
         progressIndicator.doubleValue = 0.0;
         progressIndicator.indeterminate = YES;
         [progressIndicator startAnimation:self];
         progressSession = [NSApp beginModalSessionForWindow: progressPanel];
         [progressIndicator sizeToFit];
      }
      else
         [NSApp runModalSession:progressSession];

      // Count the ongoing conversions
      progressIndicator.maxValue += 1.0;
   }

   return( self );
}

- (void) dealloc
{
   NSError *err;

   if ( _dcrawTask != nil )
   {
      if ( [_dcrawTask isRunning] )
         [_dcrawTask terminate];
      [_dcrawTask release];
   }

   if ( _ppmFilePath != nil )
   {
      if ( ![[NSFileManager defaultManager] removeItemAtURL:
                                            [NSURL fileURLWithPath:_ppmFilePath]
                                                      error:&err] )
         NSLog( @"Could not remove temporary raw converted image %@. %@", _ppmFilePath, [err description]);
   }

   [_metadata release];
   if ( _url != nil )
      [_url release];

   if (_conversionTimer != nil)
      [_conversionTimer invalidate];
   [super dealloc];
}

- (void) setMode:(ListMode_t)mode
{
   NSFileManager *fileMgr = [NSFileManager defaultManager];
   NSUserDefaults *pref = [NSUserDefaults standardUserDefaults];
   int cnt;
   const char *tmpdir = NULL;

   _mode = mode;

   // Create a temporary filename for the converted PPM
   NSString *tmpdirStr = [pref stringForKey:K_TMPDIR_KEY];
   if ( tmpdirStr != nil )
      tmpdir = [[tmpdirStr stringByExpandingTildeInPath] UTF8String];
   if ( tmpdir == NULL || *tmpdir == '\0' )
      tmpdir = getenv("TMPDIR");
   if ( tmpdir == NULL || *tmpdir == '\0' )
      tmpdir = "/tmp";
   // with a count suffix shared by all documents
   cnt = [pref integerForKey:K_COUNTER_KEY] % 10000;
   _ppmFilePath = [[NSString stringWithFormat:@"%s/%@%04d.%s",
                                        tmpdir,
                                        [fileMgr displayNameAtPath:[_url path]],
                                        cnt,
                                        (mode == DarkFrameMode ? "pgm" : "ppm")]
                   retain];
   cnt++;
   [pref setInteger:cnt forKey:K_COUNTER_KEY];

   // Retrieve image information
   [self getImageInfo];
   _numberOfPlanes = (mode == DarkFrameMode ? 1 : 3);
   _dataMax = 65535;

   // Schedule the conversion, letting time for the dark frame if not aleady set
   if ( _dark == nil )
      _conversionTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                          target:self
                                                        selector:@selector(delayedLaunch:)
                                                        userInfo:nil
                                                         repeats:NO];
   else
      [self launchConversion];
}

- (void) setDarkFrame:(LynkeosImageBuffer*)dark
{
   NSAssert( dark == nil || _mode == ImageMode || _mode == UnsetListMode,
             @"Inconsistent combination of image mode and calibration frames" );

   _dark = dark;

   if ( _mode != UnsetListMode )
   {
      // We got the dark frame, and the mode is set : convert
      // But don't forget to cancel the scheduled conversion, if any
      if (_conversionTimer != nil)
      {
         [_conversionTimer invalidate];
         _conversionTimer = nil;
      }
      [self launchConversion];
   }
}

- (void) setFlatField:(LynkeosImageBuffer*)flat
{
   // We don't care ;o)
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
   if ( _numberOfPlanes == 1 )
      *vmax = 65535.0;    // Dark frames are not scaled
   else
      *vmax = 255.0;
}

- (NSImage*) getNSImage
{
   NSImage *image = nil;
   NSBitmapImageRep* bitmap;

   // Create a RGB bitmap
   bitmap =
      [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil
                                               pixelsWide:_width
                                               pixelsHigh:_height
                                            bitsPerSample:8
                                          samplesPerPixel:_numberOfPlanes
                                                 hasAlpha:NO
                                                 isPlanar:NO
                                           colorSpaceName:
                                              (_numberOfPlanes == 1 ?
                                               NSCalibratedWhiteColorSpace :
                                               NSCalibratedRGBColorSpace)
                                             bitmapFormat:0
                                              bytesPerRow:0
                                             bitsPerPixel:8*_numberOfPlanes]
          autorelease];

   if ( bitmap != nil )
   {
      u_char *pixels = (u_char*)[bitmap bitmapData];
      u_short *sample = (u_short*)malloc( sizeof(u_short)*_numberOfPlanes*_width*_height );
      u_long x, y, p;
      double scale =  256.0 / ((double)_dataMax + 1.0);
      int bpp = (int)[bitmap bitsPerPixel];
      int bpr = (int)[bitmap bytesPerRow];

      NSAssert( (bpp%8) == 0, @"Hey, I do not intend to work on non byte boudaries" );
      bpp /= 8;

      [self getPPMsample:sample atX:0 Y:0 W:_width H:_height];

      for( y = 0; y < _height; y++ )
      {
         for( x = 0; x < _width; x++ )
         {
            u_short *v = &sample[(y*_width+x)*_numberOfPlanes];

            for ( p = 0 ; p < _numberOfPlanes; p++ )
               pixels[y*bpr+x*bpp+p] = CFSwapInt16BigToHost(v[p])*scale;
         }
      }

      free( sample );

      image = [[[NSImage alloc] initWithSize:NSMakeSize(_width,_height)]
                                                                   autorelease];

      if ( image != nil )
         [image addRepresentation:bitmap];
   }

   return( image );
}

/*! Pixels values are scaled to remain with a 256 maximum while retaining
 * 16 bits precision (because they are floating precision numbers)
 * But not for dark frames (mono) which are not scaled
 */
- (void) getImageSample:(REAL * const * const)sample
             withPlanes:(u_short)nPlanes
                    atX:(u_short)x Y:(u_short)y W:(u_short)w H:(u_short)h
              lineWidth:(u_short)lineW
{
   const double scale = (_numberOfPlanes == 1 ? 1.0 : 1.0/256.0);
   u_short xs, ys, cs;
   u_short *ppmData;

   NSAssert( x+w <= _width && y+h <= _height, 
             @"Sample at least partly outside the image" );

   ppmData = (u_short*)malloc( sizeof(u_short)*_numberOfPlanes*w*h );

   [self getPPMsample:ppmData atX:x Y:y W:w H:h];

   for ( ys = 0; ys < h; ys++ )
   {
      for( xs = 0; xs < w; xs++ )
      {
         if ( nPlanes == 1 && _numberOfPlanes != 1 )
         {
            u_short *v = &ppmData[(ys*w+xs)*_numberOfPlanes];

            // Convert to monochrome
            SET_SAMPLE( sample[0],xs,ys,lineW,
                        (CFSwapInt16BigToHost(v[0])
                         +CFSwapInt16BigToHost(v[1])
                         +CFSwapInt16BigToHost(v[2]))/3.0*scale );
         }
         else
         {
            for( cs = 0; cs < nPlanes; cs++ )
               SET_SAMPLE( sample[cs],xs,ys,lineW,
                           CFSwapInt16BigToHost(
                              ppmData[(ys*w+xs)*_numberOfPlanes+cs])*scale );
         }
      }
   }

   free( ppmData );
}

- (NSDictionary*) getMetaData 
{
   return( (NSDictionary*)_metadata );
}

- (LynkeosImageBuffer*) getCustomImageSampleAtX:(u_short)x Y:(u_short)y 
                                                  W:(u_short)w H:(u_short)h
                                      withTransform:(NSAffineTransformStruct)transform
                                        withOffsets:(const NSPoint*)offsets
{
   // Only allow non-transformed image, LynkeosCore will re-call us without transformation,
   // and use an interpolator
   if (transform.m11 != 1.0 || transform.m12 != 0.0 || transform.m21 != 0.0 || transform.m22 != 1.0
       || transform.tX != 0.0 || transform.tY != 0.0)
      return(nil);
   if (offsets != NULL)
   {
      u_short p;
      for (p = 0; p < _numberOfPlanes; p++)
         if (offsets[p].x != 0.0 || offsets[p].y != 0.0)
            return(nil);
   }

   DcrawCustomImage *img
      = [[[DcrawCustomImage alloc] initWithNumberOfPlanes:_numberOfPlanes width:w height:h] autorelease];

   [self getImageSample:[img colorPlanes]
             withPlanes:_numberOfPlanes atX:x Y:y W:w H:h lineWidth:img->_padw];

   return( img );
}

- (BOOL) canBeCalibratedBy:(id <LynkeosFileReader>)reader
                    asMode:(ListMode_t)mode
{
   u_short w, h, n, nref;
   NSString *camera
      = [[reader getMetaData] objectForKey:LynkeosMD_CameraModel()];

   if ( mode == DarkFrameMode )
      nref = 1;
   else
      nref = _numberOfPlanes;

   n = [reader numberOfPlanes];
   [reader imageWidth:&w height:&h];

   return( [reader isKindOfClass:[self class]]
           && [[_metadata objectForKey:LynkeosMD_CameraModel()]
                                                         isEqualToString:camera]
           && n == nref && w == _baseWidth && h == _baseHeight );
}

@end
