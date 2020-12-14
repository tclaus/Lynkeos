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

#import "SER_ReaderPrefs.h"

NSString * const K_SER_RED_KEY = @"SER red weight";
NSString * const K_SER_GREEN_KEY = @"SER green weight";
NSString * const K_SER_BLUE_KEY = @"SER blue weight";

//! DcrawReaderPrefs singleton instance
static SER_ReaderPrefs *serReaderPrefsInstance = nil;

/*!
 * @abstract Private methods of DcrawReaderPrefs
 */
@interface SER_ReaderPrefs(Private)
//! Set the preferences to their factory defaults
- (void) initPrefs;
//! Read the preferences user values
- (void) readPrefs;
//! Update the panel fields to their current values
- (void) updatePanel;
@end

@implementation SER_ReaderPrefs(Private)
- (void) initPrefs
{
   // Set the factory defaults
   _red = 1.0;
   _green = 1.0;
   _blue = 1.0;
}

- (void) readPrefs
{
   getNumericPref(&_red, K_SER_RED_KEY, 0.0, 9.9999);
   getNumericPref(&_green, K_SER_GREEN_KEY, 0.0, 9.9999);
   getNumericPref(&_blue, K_SER_BLUE_KEY, 0.0, 9.9999);
}

- (void) updatePanel
{
   [_redText setDoubleValue:_red];
   [_greenText setDoubleValue:_green];
   [_blueText setDoubleValue:_blue];
}
@end

@implementation SER_ReaderPrefs

+ (void) getPreferenceTitle:(NSString**)title
                       icon:(NSImage**)icon
                        tip:(NSString**)tip
{
   NSBundle *myBundle = [NSBundle bundleWithIdentifier: @"net.sourceforge.lynkeos.plugin.RAW"];
   *title = @"SER";
   *icon = [[[NSImage alloc] initWithContentsOfFile:
                         [myBundle pathForImageResource:@"SER"]] autorelease];
   *tip = nil;
}

+ (id <LynkeosPreferences>) getPreferenceInstance
{
   if ( serReaderPrefsInstance == nil )
      [[self alloc] init];

   return( serReaderPrefsInstance );
}

- (id) init
{
   NSAssert( serReaderPrefsInstance == nil, @"More than one creation of SER_ReaderPrefs" );

   if ( (self = [super init]) != nil )
   {
      [self initPrefs];
      if (![[NSBundle mainBundle] loadNibNamed:@"SER_ReaderPrefs" owner:self topLevelObjects:nil])
         NSLog(@"Failed to load SER Reader Prefs nib");

      // Update with database value, if any
      [self readPrefs];
      // And rewrite them to ensure correct values
      [self savePreferences:[NSUserDefaults standardUserDefaults]];

      // Finally initialize the GUI
      [self updatePanel];

      serReaderPrefsInstance = self;
   }

   return( self );
}

- (NSView*) getPreferencesView
{
   return( _prefsView );
}

- (void) savePreferences:(NSUserDefaults*)prefs
{
   [prefs setFloat:_red         forKey:K_SER_RED_KEY];
   [prefs setFloat:_green      forKey:K_SER_GREEN_KEY];
   [prefs setFloat:_blue        forKey:K_SER_BLUE_KEY];
}

- (void) revertPreferences
{
   [self readPrefs];
   [self updatePanel];
}

- (void) resetPreferences:(NSUserDefaults*)prefs
{
   [self initPrefs];
   [self savePreferences:prefs];
   [self updatePanel];
}

- (IBAction)changeRed:(id)sender
{
   _red = [sender doubleValue];
}

- (IBAction)changeGreen:(id)sender
{
   _green = [sender doubleValue];
}

- (IBAction)changeBlue:(id)sender
{
   _blue = [sender doubleValue];
}

@end
