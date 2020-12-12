// 
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Fri Jun 8 2007.
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

#ifndef __MYIMAGEANALYZER_PREFS_H
#define __MYIMAGEANALYZER_PREFS_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#import "SMDoubleSlider.h"

#include "LynkeosProcessing.h"
#include "LynkeosPreferences.h"

//! Lower frequency cutoff
extern NSString * const K_PREF_ANALYSIS_LOWER_CUTOFF;
//! Upper frequency cutoff
extern NSString * const K_PREF_ANALYSIS_UPPER_CUTOFF;
//! Wether to redisplay the images once analyzed
extern NSString * const K_PREF_ANALYSIS_IMAGE_UPDATING;
//! What kind of multiprocessor optimization to use for analysis
extern NSString * const K_PREF_ANALYSIS_MULTIPROC;

/*!
 * @abstract User preferences for the analysis
 */
@interface MyImageAnalyzerPrefs : NSObject <LynkeosPreferences>
{
   //! The view inside the preferences window
   IBOutlet NSView*           _prefsView;
   //! Slider for the lower and upper cuttoff values
   IBOutlet SMDoubleSlider*   _analysisCutoffSlider;
   //! Text field for the lower cutoff
   IBOutlet NSTextField*      _analysisLowerCutoffText;
   //! Text field for the upper cutoff
   IBOutlet NSTextField*      _analysisUpperCutoffText;
   //! Checkbox for the image updating during analysis
   IBOutlet NSButton*         _analysisImageUpdatingButton;
   //! Popup for selecting the multiprocessor optimization
   IBOutlet NSPopUpButton*    _analysisMultiProcPopup;   

   double                     _analysisLowerCutoff;   //!< Lower frequency cutoff
   double                     _analysisUpperCutoff;   //!< Upper frequency cutoff
   //! Wether to redisplay the images once analyzed
   BOOL                       _analysisImageUpdating;
   //! What kind of multiprocessor optimization to use for analysis
   ParallelOptimization_t     _analysisMultiProc;   
}

/*!
 * @abstract Set the analysis low / high frequency
 * @param sender The slider or the text field
 */
- (IBAction)changeAnalysisCutoff:(id)sender;

/*!
 * @abstract Set wether to redisplay the image when analyzed.
 * @param sender The checkbox
 */
- (IBAction)changeAnalysisImageUpdating:(id)sender;

/*!
 * @abstract Set the multiprocessor optimization to use for analysis.
 * @param sender The popup
 */
- (IBAction)changeAnalysisMultiProc:(id)sender;

@end

#endif
