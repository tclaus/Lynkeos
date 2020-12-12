//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Sun Dec 12 2005.
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
 * @abstract Image alignment process class
 */
#ifndef __MYIMAGE_ALIGNER_H
#define __MYIMAGE_ALIGNER_H

#include "LynkeosCore/LynkeosFourierBuffer.h"
#include "LynkeosCore/LynkeosProcessing.h"

/*!
 * @abstract Reference string for this process
 * @ingroup Processing
 */
extern NSString * const myImageAlignerRef;

/*!
 * @abstract Key for reading/setting the alignment entry parameters.
 * @ingroup Processing
 */
extern NSString * const myImageAlignerParametersRef;

/*!
 * @abstract Key for reading/setting the alignment parameters of a specific image.
 * @ingroup Processing
 */
extern NSString * const myImageAlignerImageParametersRef;

/*!
 * @abstract Origin of alignment rectangle
 * @ingroup Processing
 */
@interface MyImageAlignerOriginV3 : NSObject <NSCopying>
{
   @public
   LynkeosIntegerPoint _alignOrigin; //!< The alignment rectangle origin
}
@end

/*!
 * @abstract Origin of alignment rectangle
 * @ingroup Processing
 */
@interface MyImageAlignerSquareV3 : MyImageAlignerOriginV3
{
   @public
   LynkeosIntegerSize    _alignSize;    //!< Size of the alignment rectangle
}
@end

/*!
 * @abstract Alignment parameters optionaly saved in the image
 * @ingroup Processing
 */
@interface MyImageAlignerImageParametersV3 : NSObject <LynkeosProcessingParameter>
{
@public
   //! Array of MyImageAlignerOriginV3 specific to this image (NSNullObject are
   //! use as placeholders for non specific squares)
   NSMutableArray     *_alignSquares;
}
@end

/*!
 * @abstract Per square related data
 * @discussion This object is embedded into list parameters, to be available for
 *    all threads but is not saved
 * @ingroup Processing
 */
@interface MyImageAlignerSquareData : NSObject
{
@public
   //! Align square origin for reference item
   LynkeosIntegerPoint   _referenceOrigin;

   //! Frequency cutoff in "discrete" unit
   u_short               _cutoff;
   //! Correlation peak standard deviation threshold in pixels unit
   double                _precisionThreshold;
   double                _valueThreshold;   //!< Peak minimum height


   //! LynkeosFourierBuffer containing the spectrum of the reference item,
   //! it is shared by all processing threads. And is not saved.<br>
   //! It shall be nil at process creation.
   LynkeosFourierBuffer *_referenceSpectrum;
}
@end

/*!
 * @abstract Alignment parameters saved at the document level (in image list)
 * @discussion The field _imageSquares contain MyImageAlignerSquareV3 objects in
 *    this class
 * @ingroup Processing
 */
@interface MyImageAlignerListParametersV3 : MyImageAlignerImageParametersV3
{
@public
   //! The item against which align is done
   id <LynkeosProcessableItem> _referenceItem;

   //! Frequency cutoff applied before corelation
   double                 _cutoff;
   //! Correlation peak standard deviation threshold, above wich the alignment
   //! is failed
   double                 _precisionThreshold;

   BOOL                  _checkAlignResult;  //!< Check for false align
   //! Wether to calculate te scale between images
   BOOL                  _computeScale;
   //! Whether to calculate the rotation
   BOOL                  _computeRotation;

   //! This lock is not saved with the document. It's sole purpose is to
   //! enforce that only one processing thread computes the
   //! reference spectrums, and that the reference spectrums are computed before
   //! any thread uses any of them
   NSLock               *_alignLock;
   BOOL                  _dataReady;

   //! Square related data for all threads.
   NSMutableArray       *_squaresData;
}
@end

/*!
 * @abstract Get the alignment squares for an item
 * @discussion It merges the squares which are specific to this item with
 *    the alignment squares common to all the items
 * @param item The item for which we need the squares
 * @param params The list params
 * @return An NSArray of MyImageAlignerSquareV3
 * @ingroup Processing
 */
extern NSArray* itemAlignSquares(id <LynkeosProcessableItem> item,
                                 MyImageAlignerListParametersV3* params);

/*!
 * @abstract Image aligner class
 * @discussion This class is able to align images in parallel threads
 * @ingroup Processing
 */
@interface MyImageAligner : NSObject <LynkeosProcessing>
{
@private
   //! The document in which we are processing (weak reference)
   id <LynkeosDocument>            _document;

   //! The aligning parameters used when none other exists.
   MyImageAlignerListParametersV3 *_rootParams;

   //! Array of per thread LynkeosFourierBuffer for Fourier transform
   NSMutableArray                 *_spectrumBuffers;
}
@end

#endif
