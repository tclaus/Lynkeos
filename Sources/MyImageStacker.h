//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Sun Jun 17 2007.
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
 * @abstract Definitions of the "stacking" process.
 */
#ifndef __MYIMAGESTACKER_H
#define __MYIMAGESTACKER_H

#import <Foundation/Foundation.h>

#include "LynkeosProcessing.h"

#include "MyImageList.h"

/*!
 * @abstract Reference string for this process
 * @ingroup Processing
 */
extern NSString * const myImageStackerRef;

/*!
 * @abstract Reference for reading/setting the stacking parameters.
 * @ingroup Processing
 */
extern NSString * const myImageStackerParametersRef;

/*!
 * @abstract Mode of stacking
 * @ingroup Processing
 */
typedef enum
{
   Stacking_Standard,
   Stacking_Sigma_Reject,
   Stacking_Extremum,
   Stacking_Calibration
} Stack_Mode_t;

/*!
 * @abstract Kind of postprocessing after stacking (for calibration frames)
 * @ingroup Processing
 */
typedef enum
{
   NoPostStack,         //!< Leave stack as it is
   MeanStack,           //!< Pixel value is the mean of all images
   NormalizeStack       //!< Normalize so that max value = 1
} PostStack_t;

/*!
 * @abstract Stacking parameters
 * @discussion The parameters are stored at list level.
 * @ingroup Processing
 */
@interface MyImageStackerParameters : NSObject <LynkeosProcessingParameter>
{
@public
   LynkeosIntegerRect        _cropRectangle; //!< The rectangle to stack
   NSAffineTransform*        _transform;  //!< Additional transform for stacking
   PostStack_t          _postStack;       //!< Post stack action
   BOOL                 _monochromeStack; //!< Whether to stack in monochrome
   Stack_Mode_t         _stackMethod;       //!< Stacking variant
   union method //!< Parameters for each mode
   {
      struct sigma    //!< Parameters for "standard deviation rejection" mode
      {
         float          threshold;       //!< Standard deviation rejection thr.
      } sigma;
      struct extremum //!< Parameters for "extremum (min/max)" mode
      {
         BOOL           maxValue;        //!< Wether to keep min or max
      } extremum;
   }                    _method;

   NSEnumerator <LynkeosMultiPassEnumerator> *
                        _enumerator;      //!< Enumerator of the images to stack
   NSConditionLock*     _stackLock;       //!< Lock for orderly recombination
   unsigned             _livingThreads;   //!< How many stacking threads
   unsigned long        _imagesStacked;   //!< Total number of images stacked
}
@end

/*!
 * @abstract Strategy for the stacking mode
 * @ingroup Processing
 */
@protocol MyImageStackerModeStrategy
/*!
 * @abstract Dedicated initializer
 * @param params the stacking parameters
 * @param list The list to stack
 */
- (id) initWithParameters: (id <NSObject>)params
                     list: (id <LynkeosImageList>)list;
/*!
 * @abstract Add one image to the stack
 * @param image The image to add
 */
- (void) processImage: (LynkeosImageBuffer*)image ;
/*!
 * @abstract Process the end of stacking for the current thread
 * @param list The list which is stacked
 */
- (void) finishOneProcessingThreadInList:(id <LynkeosImageList>)list ;
/*!
 * @abstract Process the complete end of stacking 
 * @param list the list which is stacked
 */
- (void) finishAllProcessingInList: (id <LynkeosImageList>)list;
/*!
 * @abstract Access to the stacking result
 * @result The last stacking result
 */
- (LynkeosImageBuffer*) stackingResult ;
@end

/*!
 * @abstract Call param which indicates which list to process
 * @discussion It is stored at document level
 * @ingroup Processing
 */
@interface MyImageStackerList : NSObject
{
@public
   id <LynkeosImageList> _list; //!< The list to stack
}
@end

/*!
 * @abstract Stacker class
 * @discussion This class is able to stack on parallel threads.<br>
 *    It stacks separately monochrome and RGB images, the stacked buffers
 *    (ie: one mono and one RGB per thread) are all recombined at the end.
 * @ingroup Processing
 */
@interface MyImageStacker : NSObject <LynkeosProcessing>
{
@private
   id <LynkeosDocument> _document;  //!< The document in which we are processing
   id <LynkeosImageList> _list;     //!< The list to stack
   //! Strategy for the selected stacking method
   NSObject <MyImageStackerModeStrategy> *_stackingStrategy;
   MyImageStackerParameters   *_params;     //!< Stacking parameters
   unsigned long               _imagesStacked; //!< Nb stacked in this thread
}
@end

#endif
