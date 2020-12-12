//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Sun May 17 2020.
//  Copyright (c) 2020. Jean-Etienne LAMIAUD
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
//

#ifndef __SERREADERPREFS_H
#define __SERREADERPREFS_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#include "LynkeosCore/LynkeosPreferences.h"

NS_ASSUME_NONNULL_BEGIN

//! Red factor for manual white balance
extern NSString * const K_SER_RED_KEY;
//! 1st green factor for manual white balance
extern NSString * const K_SER_GREEN_KEY;
//! Blue factor for manual white balance
extern NSString * const K_SER_BLUE_KEY;

/*!
 * @abstract Preferences for RAW files conversion
 */
@interface SER_ReaderPrefs : NSObject <LynkeosPreferences>
{
   //! Our view inside the preferences window
   IBOutlet NSView*           _prefsView;
   //! Text field for manual white balance red factor
   IBOutlet NSTextField*      _redText;
   //! Text field for manual white balance 1st green factor
   IBOutlet NSTextField*      _greenText;
   //! Text field for manual white balance blue factor
   IBOutlet NSTextField*      _blueText;

   //! Red factor for manual white balance
   double                     _red;
   //! 1st green factor for manual white balance
   double                     _green;
   //! Blue factor for manual white balance
   double                     _blue;
}

/*!
 * @abstract Set automatic white balance red value
 * @param sender The GUI control sending this action
 */
- (IBAction)changeRed:(id)sender;
/*!
 * @abstract Set automatic white balance green value
 * @param sender The GUI control sending this action
 */
- (IBAction)changeGreen:(id)sender;
/*!
 * @abstract Set automatic white balance blue value
 * @param sender The GUI control sending this action
 */
- (IBAction)changeBlue:(id)sender;

@end

NS_ASSUME_NONNULL_END

#endif
