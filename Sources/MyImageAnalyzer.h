//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Wed jun 6 2007.
//  Copyright (c) 2007-2013. Jean-Etienne LAMIAUD
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
 * @abstract Image analysis process class
 */
#ifndef __MYIMAGE_ANALYZER_H
#define __MYIMAGE_ANALYZER_H

#include "LynkeosFourierBuffer.h"
#include "LynkeosProcessing.h"

/*!
 * @abstract Reference string for this process
 * @ingroup Processing
 */
extern NSString * const myImageAnalyzerRef;

/*!
 * @abstract Reference for reading/setting the analysis entry parameters.
 * @ingroup Processing
 */
extern NSString * const myImageAnalyzerParametersRef;

/*!
 * @abstract Reference for reading/setting the analysis result.
 * @ingroup Processing
 */
extern NSString * const myImageAnalyzerResultRef;

/*!
 * @abstract Reference for reading/setting the autoselect parameter.
 * @ingroup Processing
 */
extern NSString * const myAutoselectParameterRef;

/*!
 * @enum MyAnalysisMethod
 * @abstract Analysis method enumeration
 * @ingroup Processing
 */
typedef enum
{
   EntropyAnalysis,
   SpectrumAnalysis
} MyAnalysisMethod;

/*!
 * @abstract General entry parameters for image quality analysis
 * @ingroup Processing
 */
@interface MyImageAnalyzerParameters : NSObject <LynkeosProcessingParameter>
{
@public
   LynkeosIntegerRect   _analysisRect;    //!< The analysis rectangle
   MyAnalysisMethod     _method;          //!< Analysis method used
   double               _lowerCutoff;     //!< Lower frequency cutoff
   double               _upperCutoff;     //!< Upper frequency cutoff
}
@end

/*!
 * @abstract Result of the analysis process (entry data for further processing)
 * @ingroup Processing
 */
@interface MyImageAnalyzerResult : NSObject <LynkeosProcessingParameter>
{
@public
   double          _quality;        //!< Result of analysis!
}

/*!
 * @abstract Accessor to the quality
 */
- (NSNumber*) quality;

@end

/*!
 * @abstract Autoselect parameters
 * @discussion The process view controller uses a process parameter to store
 *    the autoselect parameters, which are unknown to the process itself
 * @ingroup Processing
 */
@interface MyAutoselectParams : NSObject <LynkeosProcessingParameter>
{
@public
   //! The quality level below which images are not selected
   double _qualityThreshold;
}
@end

/*!
 * @abstract Image analysis processing class
 * @ingroup Processing
 */
@interface MyImageAnalyzer : NSObject <LynkeosProcessing>
{
@private
   id <LynkeosDocument> _document;  //!< The document in which we are processing
   MyImageAnalyzerParameters *_params;    //!< Parameters of analysis
   double               _lowerCutoff;     //!< Lower frequency cutoff
   double               _upperCutoff;     //!< Upper frequency cutoff
   //! Per thread buffer for Fourier transform
   LynkeosFourierBuffer      *_bufferSpectrum;
}

@end

/*!
 * @abstract Filter the image with the filter used for analysis
 * @discussion This is used for previewing the analysis filter effect
 * @param[in,out] image The image to filter
 * @param down Lower frequency cutoff
 * @param up Upper frequency cutoff
 */
extern void filterImageForAnalysis( LynkeosFourierBuffer *image,
                                    double down,
                                    double up );
#endif
