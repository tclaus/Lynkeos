//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Sat Jun 9 2007.
//  Copyright (c) 2007-2014. Jean-Etienne LAMIAUD
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
 * @abstract Image analysis process view class
 */
#ifndef __MYIMAGE_ANALYZER_VIEW_H
#define __MYIMAGE_ANALYZER_VIEW_H

#import <AppKit/AppKit.h>

#import "SMDoubleSlider.h"

#include "LynkeosProcessableImage.h"
#include "LynkeosProcessingView.h"

/*!
 * @abstract View controller of the wavelet processing
 * @ingroup Processing
 */
@interface MyImageAnalyzerView : NSObject <LynkeosProcessingView,
                                           LynkeosImageViewDelegate>
{
   IBOutlet NSView*           _panel;                //!< Our view
   IBOutlet NSTextField*      _analyzeFieldX;        //!< X analysis rect origin
   IBOutlet NSTextField*      _analyzeFieldY;        //!< Y analysis rect origin
   IBOutlet NSComboBox*    _analyzeSideMenu;      //!< Analysis square side
   IBOutlet NSButton*	      _analyzeButton;        //!< Start analyzing
   IBOutlet NSPopUpButton*    _analyzeMethodMenu;    //!< Analysis algo choice
   IBOutlet NSSlider*	      _selectThresholdSlide; //!< Auto threshold slider
   IBOutlet NSTextField*      _selectThresholdText;  //!< Auto threshold text
   IBOutlet NSTextField*      _minQualityText;       //!< Minimum quality value
   IBOutlet NSTextField*      _maxQualityText;       //!< Maximum quality value
   IBOutlet NSTextField*      _numSelectedText;      //!< Nb of selected images
   IBOutlet NSTextField*      _numSelectedTail;      //!< Text to show/hide
   IBOutlet SMDoubleSlider*   _cutoffFreqSlider;     //!< Lo and hi frequencies
   IBOutlet NSTextField*      _lowFreqCutoffText;    //!< Low freq cutoff
   IBOutlet NSTextField*      _highFreqCutoffText;   //!< High freq cutoff
   IBOutlet NSButton*         _previewButton;        //!< Filtered image preview

   id <LynkeosWindowController> _window;             //!< Our window controller
   id <LynkeosViewDocument>   _document;             //!< Our document
   id <LynkeosImageList>      _list;                 //!< The current list

   id <LynkeosImageView>      _imageView;            //!< To display the images

   LynkeosProcessableImage*   _filteredImage;        //!< For preview
   //! Basis for the preview, weak binding
   id <LynkeosProcessableItem> _unfilteredItem;

   unsigned int               _sideMenuLimit;   //!< Upper limit for square side
   double                     _minQuality;           //!< Minimum quality level
   double                     _maxQuality;           //!< Maximum quality level
   double                     _qualityThreshold;     //!< Auto select threshold
   BOOL                       _isAnalyzing;     //!< Is analysis being processed
   //! Whether to redisplay each image after analysis
   BOOL                       _imageUpdate;
   BOOL                       _filteredPreview;   //!< Display filtered or plain
}

/*!
 * @abstract The origin of the analysis square was changed
 * @param sender The control which value was changed
 */
- (IBAction) analyzeSquareChange:(id)sender ;
/*!
 * @abstract The size of the analysis square was changed
 * @param sender The control which value was changed
 */
- (IBAction) analysisSquareSizeChange:(id)sender ;
/*!
 * @abstract The analysis algorithm was changed
 * @param sender The control which value was changed
 */
- (IBAction) analyzeMethodChange:(id)sender ;
/*!
 * @abstract Select/deselect images based on their quality
 * @param sender The button
 */
- (IBAction) autoSelectAction:(id)sender ;
/*!
 * @abstract Start analyzing
 * @param sender The button
 */
- (IBAction) analyzeAction:(id)sender ;

/*!
 * @abstract Change the cutoff frequencies
 * @param sender Double slider or text field
 */
- (IBAction) cutoffFrequenciesChange:(id)sender;

/*!
 * @abstract Toggle the preview of the filtered image
 * @param sender The button
 */
- (IBAction) previewChange:(id)sender;
@end

#endif