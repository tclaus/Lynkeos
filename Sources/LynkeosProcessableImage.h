//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Sat Aug 11 2007.
//  Copyright (c) 2007-2020. Jean-Etienne LAMIAUD
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
 * @abstract Root class for image processing
 */
#ifndef __LYNKEOSPROCESSABLEIMAGE_H
#define __LYNKEOSPROCESSABLEIMAGE_H

#import <Foundation/Foundation.h>

#include <LynkeosCore/LynkeosProcessing.h>
#include <LynkeosCore/LynkeosImageBuffer.h>
#include <LynkeosCore/LynkeosFourierBuffer.h>
#include <LynkeosCore/LynkeosProcessingParameterMgr.h>

/*!
 * @abstract This root class is inherited by the classes which contain an image
 */
@interface LynkeosProcessableImage : NSObject <LynkeosProcessableItem,NSCoding>
{
@protected
   LynkeosImageBuffer* _originalImage;          //!< Stored original image
   LynkeosImageBuffer* _processedImage;         //!< Stored processed image
   LynkeosFourierBuffer*       _processedSpectrum;      //!< Processed spectrum if any
   u_long                      _imageSequenceNumber;    //!< Sequence number of the image
   u_long                      _originalSequenceNumber; //!< Original image seq nb
   //! Aggregate class for parameters
   LynkeosProcessingParameterMgr* _parameters;

   LynkeosIntegerSize          _size;                   //!< Cached image size
   u_short                     _nPlanes;                //!< Cached number of planes

   BOOL             _planeLevelsAreSet;   //!< Whether the user has chaged them
   double          *_black;  //!< Black level for displaying the processed image
   double          *_white;  //!< White level for displaying the processed image
   double          *_gamma;  //!< Gamma correction for displaying

   ImageOperatorsStrategy_t  _strategy;             //!< The strategy for parallel processing
}

/*!
 * @abstract Get the sequence number of the original image
 * @result The original image sequence number
 */
- (u_long) originalImageSequence ;

/*!
 * @abstract Get the current image or processed spectrum
 */
- (LynkeosImageBuffer*) getResult ;

/*!
 * @abstract Save the result as the processed image or spectrum
 */
- (void) setResult:(LynkeosImageBuffer*)result ;

@end

#endif
