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

#include "MyCalibrationLock.h"

@interface MyCalibrationLock(Private)
- (void) initCalibrationData:(CalibrationData_t*)data;
- (void) removeReader:(id <LynkeosFileReader>)reader
             fromData:(CalibrationData_t*)data;
- (BOOL) addCalibrationReader:(id <LynkeosFileReader>)reader
                      forMode:(ListMode_t)mode;
- (BOOL) checkImageReader:(id <LynkeosFileReader>)reader
                  forMode:(ListMode_t)mode;
@end

@implementation MyCalibrationLock(Private)
- (void) initCalibrationData:(CalibrationData_t*)data
{
   data->list = [[NSMutableArray array] retain];
   data->size = LynkeosMakeIntegerSize(0,0);
   data->nPlanes = 0;
}

- (void) removeReader:(id <LynkeosFileReader>)reader
             fromData:(CalibrationData_t*)data
{
   [data->list removeObjectIdenticalTo:reader];

   if ( [data->list count] == 0 )
   {
      // No more frames, reset the "geometry"
      data->size = LynkeosMakeIntegerSize(0,0);
      data->nPlanes = 0;
   }
}

- (BOOL) addCalibrationReader:(id <LynkeosFileReader>)reader
                      forMode:(ListMode_t)mode
{
   NSEnumerator *iter = [_image.list objectEnumerator];
   CalibrationData_t *calData
      = (mode == DarkFrameMode ? &_darkFrame : &_flatField);
   const BOOL firstCalibration = ([calData->list count] == 0);
   id <LynkeosFileReader> imageReader;
   LynkeosIntegerSize calSize;
   u_short np;

   [reader imageWidth:&calSize.width height:&calSize.height];
   np = [reader numberOfPlanes];

   // If there are already some calibration frames, verify "geometrical
   // compatibility"
   if ( !firstCalibration
        && ( calSize.width != calData->size.width
            || calSize.height != calData->size.height
            || np != calData->nPlanes) )
      return( NO );

   // Check against every image
   while ( (imageReader = [iter nextObject]) != nil )
   {
      if ( [[imageReader class] conformsToProtocol:
                                   @protocol(LynkeosCustomFileReader)] )
      {
         if ( ![(id <LynkeosCustomFileReader>)imageReader
                                         canBeCalibratedBy:reader asMode:mode] )
            return( NO );
      }

      // If there are not any calibration images yet, verify "geometrical
      // compatibility" with each image
      else if ( firstCalibration )
      {
         LynkeosIntegerSize imageSize;

         [imageReader imageWidth:&imageSize.width height:&imageSize.height];

         if ( imageSize.width != calSize.width
             || imageSize.height != calSize.height
             || [imageReader numberOfPlanes] != np )
            return( NO );
      }
   }

   if ( firstCalibration )
   {
      // First calibration image
      calData->size = calSize;
      calData->nPlanes = np;
   }

   [calData->list addObject:reader];

   return( YES );
}

- (BOOL) checkImageReader:(id <LynkeosFileReader>)reader
                  forMode:(ListMode_t)mode
{
   CalibrationData_t *calData
      = (mode == DarkFrameMode ? &_darkFrame : &_flatField);
   LynkeosIntegerSize imageSize;
   u_short np;

   [reader imageWidth:&imageSize.width height:&imageSize.height];
   np = [reader numberOfPlanes];

   // Nothing to check if there are no calibration frames
   if ( [calData->list count] != 0 )
   {
      NSEnumerator *iter = [calData->list objectEnumerator];
      id <LynkeosFileReader> calibrationReader;
      BOOL customImage = [[reader class] conformsToProtocol:
                                            @protocol(LynkeosCustomFileReader)];

      if ( customImage )
      {
         // Check "custom compatibility" against every calibration frame
         while ( (calibrationReader = [iter nextObject]) != nil )
         {
            if ( ![(id <LynkeosCustomFileReader>)reader
                                             canBeCalibratedBy:calibrationReader
                                                        asMode:mode] )
               return( NO );
         }
      }
       // Otherwise verify "geometrical compatibility"
      else if ( imageSize.width != calData->size.width ||
                imageSize.height != calData->size.height ||
                np != calData->nPlanes )
         return( NO );
      

   }

   return( YES );
}
@end

@implementation MyCalibrationLock

/*!
 * @discussion A dark frame item can be added if it is able to calibrate all
 *   the images in the "calibrable" list..
 */
- (BOOL) addDarkFrameItem :(MyImageListItem*)item ;
{
   return( [self addCalibrationReader:[item getReader]
                              forMode:DarkFrameMode] );
}

/*!
 * @discussion A flat field item can be added if it is able to calibrate all
 *   the images in the "calibrable" list..
 */
- (BOOL) addFlatFieldItem :(MyImageListItem*)item
{
   return( [self addCalibrationReader:[item getReader]
                              forMode:FlatFieldMode] );
}

/*!
 * @discussion An image item can be added if it can be calibrated by all 
 *   the images in the "calibration" lists..
 */
- (BOOL) addImageItem :(MyImageListItem*)item 
{
   const BOOL firstImage = ([_image.list count] == 0);
   id <LynkeosFileReader> imageReader = [item getReader];
   LynkeosIntegerSize imageSize;
   u_short np;

   [imageReader imageWidth:&imageSize.width height:&imageSize.height];
   np = [imageReader numberOfPlanes];

   // Check geometry consistency (if calibration frames are used)
   if ( !firstImage
        && ([_darkFrame.list count] != 0 || [_flatField.list count] != 0)
        && (imageSize.width != _image.size.width
            || imageSize.height != _image.size.height
            || np != _image.nPlanes) )
      return( NO );

   if ( ! [self checkImageReader:imageReader forMode:DarkFrameMode] )
      return( NO );
   if ( ! [self checkImageReader:imageReader forMode:FlatFieldMode] )
      return( NO );

   if ( firstImage )
   {
      _image.size = imageSize;
      _image.nPlanes = np;
   }
   [_image.list addObject:imageReader];

   return( YES );
}

- (void) removeItem :(MyImageListItem*)item ;
{
   id <LynkeosFileReader> reader = [item getReader];

   // Try to remove from each of the lists, it will succeed in one only
   [self removeReader:reader fromData:&_darkFrame];
   [self removeReader:reader fromData:&_flatField];
   [self removeReader:reader fromData:&_image];
}

// Constructors
- (id) init
{
   self = [super init];

   if ( self != nil )
   {
      [self initCalibrationData:&_darkFrame];
      [self initCalibrationData:&_flatField];
      [self initCalibrationData:&_image];
   }

   return( self );
}

- (void) dealloc
{
   [_darkFrame.list release];
   [_flatField.list release];
   [_image.list release];

   [super dealloc];
}

+ (id) calibrationLock
{
   return( [[[self alloc] init] autorelease] );
}

@end
