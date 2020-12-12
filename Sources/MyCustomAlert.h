//
//  Lynkeos 
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Mon Mar 24 2008.
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

/*!
 * @header
 * @abstract Definitions of a custom alert panel.
 */
#ifndef __MYCUSTOMALERT_H
#define __MYCUSTOMALERT_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

/*!
 * @abstract Custom alert panel
 */
@interface MyCustomAlert : NSObject
{
   IBOutlet NSPanel*     _panel;      //!< The panel itself
   IBOutlet NSTextView*  _text;       //!< Text displayed in the alert panel
   IBOutlet NSButton*    _okButton;   //!< The OK (and only) button
}

/*!
 * @abstract Display the alert panel, and run modal until dialog end
 * @param title Alert window title
 * @param text Text to display in the alert panel
 */
+ (void) runAlert:(NSString*)title withText:(NSString*)text ;

/*!
 * @abstract Called when the OK button is pressed
 * @param sender The button which called this action
 */
- (IBAction) confirmAction:(id)sender ;
@end

#endif