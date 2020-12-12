//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Wed Sep 24 2008.
//  Copyright (c) 2008-2013. Jean-Etienne LAMIAUD
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

#ifndef __DCRAWREADERPREFS_H
#define __DCRAWREADERPREFS_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#include "LynkeosCore/LynkeosPreferences.h"

//! Temporary directory used for image conversion
extern NSString * const K_TMPDIR_KEY;
//! Wether to use manual or automatic white balance
extern NSString * const K_MANUALWB_KEY;
//! Wether to rotate images according to their setting
extern NSString * const K_ROTATION_KEY;
//! Red factor for manual white balance
extern NSString * const K_RED_KEY;
//! 1st green factor for manual white balance
extern NSString * const K_GREEN1_KEY;
//! Blue factor for manual white balance
extern NSString * const K_BLUE_KEY;
//! 2nd green factor for manual white balance
extern NSString * const K_GREEN2_KEY;
//! Wether to use manual or automatic black and white levels
extern NSString * const K_LEVELS_KEY;
//! Manual dark (black) level
extern NSString * const K_DARK_KEY;
//! Manual saturation (white) level
extern NSString * const K_SATURATION_KEY;

/*!
 * @abstract Preferences for RAW files conversion
 */
@interface DcrawReaderPrefs : NSObject <LynkeosPreferences>
{
   //! Our view inside the preferences window
   IBOutlet NSView*           _prefsView;
   //! Text field for setting the temporary directory
   IBOutlet NSTextField*      _tmpDirText;
   //! Check box for auto/manual white balance
   IBOutlet NSButton*         _manualWbButton;
   //! Checkbox for auto image rotation
   IBOutlet NSButton*         _autoRotationButton;
   //! Text field for manual white balance red factor
   IBOutlet NSTextField*      _redText;
   //! Text field for manual white balance 1st green factor
   IBOutlet NSTextField*      _green1Text;
   //! Text field for manual white balance blue factor
   IBOutlet NSTextField*      _blueText;
   //! Text field for manual white balance 2nd green factor
   IBOutlet NSTextField*      _green2Text;
   //! Check box for auto/manual min and max levels
   IBOutlet NSButton*         _manualLevelsButton;
   //! Text field for the dark level
   IBOutlet NSTextField*      _darkText;
   //! Text field for the saturation level
   IBOutlet NSTextField*      _saturationText;

   //! Temporary directory used for image conversion
   NSString*                  _tmpDir;
   //! Wether to use manual or automatic white balance
   BOOL                       _manualWB;
   //! Wether to rotate images according to their setting
   BOOL                       _autoRotation;
   //! Red factor for manual white balance
   double                     _red;
   //! 1st green factor for manual white balance
   double                     _green1;
   //! Blue factor for manual white balance
   double                     _blue;
   //! 2nd green factor for manual white balance
   double                     _green2;
   //! Wether to use manual or automatic black and white levels
   BOOL                       _manualLevels;
   //! Manual dark (black) level
   double                     _dark;
   //! Manual saturation (white) level
   double                     _saturation;
}

/*!
 * @abstract Set the temporary directory
 * @param sender The GUI control sending this action
 */
- (IBAction)changeTmpDir:(id)sender;
/*!
 * @abstract Set auto or manual white balance
 * @param sender The GUI control sending this action
 */
- (IBAction)changeManualWB:(id)sender;
/*!
 * @abstract Set automatic image rotation or not
 * @param sender The GUI control sending this action
 */
- (IBAction)changeAutoRotation:(id)sender;
/*!
 * @abstract Set automatic white balance red value
 * @param sender The GUI control sending this action
 */
- (IBAction)changeRed:(id)sender;
/*!
 * @abstract Set automatic white balance 1st green value
 * @param sender The GUI control sending this action
 */
- (IBAction)changeGreen1:(id)sender;
/*!
 * @abstract Set automatic white balance blue value
 * @param sender The GUI control sending this action
 */
- (IBAction)changeBlue:(id)sender;
/*!
 * @abstract Set automatic white balance 2nd green value
 * @param sender The GUI control sending this action
 */
- (IBAction)changeGreen2:(id)sender;
/*!
 * @abstract Set automatic or manual levels
 * @param sender The GUI control sending this action
 */
- (IBAction)changeManualLevels:(id)sender;
/*!
 * @abstract Set the dark level value
 * @param sender The GUI control sending this action
 */
- (IBAction)changeDark:(id)sender;
/*!
 * @abstract Set the sturation level
 * @param sender The GUI control sending this action
 */
- (IBAction)changeSaturation:(id)sender;

@end

#endif /* __DCRAWREADERPREFS_H */