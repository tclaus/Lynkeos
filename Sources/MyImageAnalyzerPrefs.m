// 
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Fri Jun 8 2007.
//  Copyright (c) 2007-2018. Jean-Etienne LAMIAUD
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

#include "MyUserPrefsController.h"
#include "MyImageAnalyzerPrefs.h"

NSString * const K_PREF_ANALYSIS_LOWER_CUTOFF = @"Analysis lower cutoff 2";
NSString * const K_PREF_ANALYSIS_UPPER_CUTOFF = @"Analysis upper cutoff 2";
NSString * const K_PREF_ANALYSIS_IMAGE_UPDATING = @"Analysis image updating";
NSString * const K_PREF_ANALYSIS_MULTIPROC = @"Multiprocessor analysis";

//! MyImageAnalyzerPrefs singleton instance
static MyImageAnalyzerPrefs *myImageAnalyzerPrefsInstance = nil;

@interface MyImageAnalyzerPrefs(Private)
- (void) initPrefs ;
- (void) readPrefs;
- (void) updatePanel;
@end

@implementation MyImageAnalyzerPrefs(Private)
- (void) initPrefs
{
   // Set the factory defaults
   _analysisLowerCutoff = 0.08;
   _analysisUpperCutoff = 0.3;
   _analysisImageUpdating = NO;
   _analysisMultiProc = ListThreadsOptimizations;
}

- (void) readPrefs
{
   NSUserDefaults *user = [NSUserDefaults standardUserDefaults];
   ParallelOptimization_t opt;

   getNumericPref(&_analysisLowerCutoff, K_PREF_ANALYSIS_LOWER_CUTOFF,
                  0.0, 0.71);
   getNumericPref(&_analysisUpperCutoff, K_PREF_ANALYSIS_UPPER_CUTOFF,
                  0.0, 0.71);
   if ( [user objectForKey:K_PREF_ANALYSIS_IMAGE_UPDATING] != nil )
      _analysisImageUpdating = [user boolForKey:K_PREF_ANALYSIS_IMAGE_UPDATING];
   if ( [user objectForKey:K_PREF_ANALYSIS_MULTIPROC] != nil )
   {
      opt = (ParallelOptimization_t)[user integerForKey:K_PREF_ANALYSIS_MULTIPROC];
      // Compatibility with old prefs : FFTW3 threads is converted to none
      if ( opt == FFTW3ThreadsOptimization)
         _analysisMultiProc = NoParallelOptimization;
      else
         _analysisMultiProc = opt;
   }
}

- (void) updatePanel
{
   [_analysisCutoffSlider setDoubleLoValue: _analysisLowerCutoff*10.0];
   [_analysisCutoffSlider setDoubleHiValue: _analysisUpperCutoff*10.0];
   [_analysisLowerCutoffText setDoubleValue: _analysisLowerCutoff];
   [_analysisUpperCutoffText setDoubleValue: _analysisUpperCutoff];
   [_analysisImageUpdatingButton setState: 
      (_analysisImageUpdating ? NSOnState : NSOffState)];
   [_analysisMultiProcPopup selectItemWithTag: _analysisMultiProc];
}
@end

@implementation MyImageAnalyzerPrefs
+ (void) getPreferenceTitle:(NSString**)title
                       icon:(NSImage**)icon
                        tip:(NSString**)tip
{
   *title = @"Analyse";
   *icon = [NSImage imageNamed:@"Analysis"];
   *tip = nil;
}

+ (id <LynkeosPreferences>) getPreferenceInstance
{
   if ( myImageAnalyzerPrefsInstance == nil )
      [[self alloc] init];

   return( myImageAnalyzerPrefsInstance );
}


- (id) init
{
   NSAssert( myImageAnalyzerPrefsInstance == nil,
             @"More than one creation of MyImageAnalyzerPrefs" );

   if ( (self = [super init]) != nil )
   {
      [self initPrefs];

      myImageAnalyzerPrefsInstance = self;
   }

   return( self );
}

- (void) awakeFromNib
{
   // Update with database value, if any
   [self readPrefs];
   // And rewrite them to ensure correct values
   [self savePreferences:[NSUserDefaults standardUserDefaults]];

   // Finally initialize the GUI
   [self updatePanel];
}

- (NSView*) getPreferencesView
{
   return( _prefsView );
}

- (void) savePreferences:(NSUserDefaults*)prefs
{
   [prefs setFloat:_analysisLowerCutoff forKey:K_PREF_ANALYSIS_LOWER_CUTOFF];
   [prefs setFloat:_analysisUpperCutoff forKey:K_PREF_ANALYSIS_UPPER_CUTOFF];
   [prefs setBool:_analysisImageUpdating forKey:K_PREF_ANALYSIS_IMAGE_UPDATING];
   [prefs setInteger:_analysisMultiProc forKey:K_PREF_ANALYSIS_MULTIPROC];
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

- (IBAction)changeAnalysisCutoff:(id)sender
{
   if ( sender == _analysisCutoffSlider )
   {
      _analysisLowerCutoff = [sender doubleLoValue]/ 10.0;
      _analysisUpperCutoff = [sender doubleHiValue]/ 10.0;

      [_analysisLowerCutoffText setDoubleValue: _analysisLowerCutoff];
      [_analysisUpperCutoffText setDoubleValue: _analysisUpperCutoff];
   }

   else if ( sender == _analysisLowerCutoffText )
   {
      _analysisLowerCutoff = [sender doubleValue];

      // Enforce consistency
      if ( _analysisLowerCutoff > _analysisUpperCutoff )
         _analysisLowerCutoff = _analysisUpperCutoff;

      [_analysisCutoffSlider setDoubleLoValue: _analysisLowerCutoff*10.0];
   }

   else if ( sender == _analysisUpperCutoffText )
   {
      _analysisUpperCutoff = [sender doubleValue];

      // Enforce consistency
      if ( _analysisUpperCutoff < _analysisLowerCutoff )
         _analysisUpperCutoff = _analysisLowerCutoff;

      [_analysisCutoffSlider setDoubleHiValue: _analysisLowerCutoff*10.0];
   }
}

- (IBAction)changeAnalysisImageUpdating:(id)sender
{
   _analysisImageUpdating = ([sender state] == NSOnState);
}

- (IBAction)changeAnalysisMultiProc:(id)sender
{
   _analysisMultiProc = (ParallelOptimization_t)[[sender selectedItem] tag];
}
@end
