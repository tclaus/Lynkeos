// 
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Wed May 16 2007.
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

#ifndef __MYGENERALPREFS_H
#define __MYGENERALPREFS_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#include "LynkeosProcessing.h"
#include "LynkeosPreferences.h"

//! Wether to adjust the FFT size to optimize FFTW processing time
extern NSString * const K_PREF_ADJUST_FFT_SIZES;
//! Multiprocessing optimization strategy for image processing
extern NSString * const K_PREF_IMAGEPROC_MULTIPROC;
//! The sound to play at end of processing
extern NSString * const K_PREF_END_PROCESS_SOUND;

/*!
 * @abstract General preferences
 */
@interface MyGeneralPrefs : NSObject <LynkeosPreferences>
{
   //! Our view inside the preferences window
   IBOutlet NSView*           _prefsView;
   //! Checkbox for adjusting size for FFT algorithm
   IBOutlet NSButton*         _adjustFFTSizesButton;
   //! Popup for choosing the multiprocessing optimization strategy
   IBOutlet NSPopUpButton*    _imageProcOptimPopup;
   //! Popup for choosing the end of process sound
   IBOutlet NSPopUpButton*    _soundPopup;

   //! List of available sounds
   NSMutableArray*            _soundsNames;

   // Preferences
   //! Wether to adjust the FFT size to optimize FFTW processing time
   BOOL                       _adjustFFTSizes;
   //! Multiprocessing optimization strategy for image processing
   ParallelOptimization_t     _imageProcOptim;
   //! The sound to play at end of processing
   NSString                   *_sound;
}

/*!
 * @abstract Set wether the application should alter the rectangle size for FFT
 *   optimization.
 * @param sender The checkbox
 */
- (IBAction)changeAdjustFFTSizes:(id)sender;

/*!
 * @abstract Set how to use multiprocessors for image processing.
 * @param sender The popup
 */
- (IBAction)changeImageProcOptim:(id)sender;

   /*!
 * @abstract Set which sound to play at end of list processing.
 * @param sender The popup
 */
- (IBAction)changeEndProcessingSound:(id)sender;

@end

#endif
