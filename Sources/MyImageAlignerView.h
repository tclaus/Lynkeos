//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Sat Nov 4 2006.
//  Copyright (c) 2006-2018. Jean-Etienne LAMIAUD
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
 * @abstract Definitions of the "align" view.
 */
#ifndef __MYIMAGEALIGNERVIEW_H
#define __MYIMAGEALIGNERVIEW_H

#import <AppKit/AppKit.h>

#include "LynkeosProcessingView.h"

/*!
 * @abstract Aligner view controller class
 * @ingroup Processing
 */
@interface MyImageAlignerView : NSObject <LynkeosProcessingView,
                                          LynkeosImageViewDelegate>
{
   IBOutlet NSTableView*      _squaresTable;   //!< Table of search squares
   //! Active when the selected image is the reference
   IBOutlet NSButton*         _refCheckBox;
   IBOutlet NSButton*         _privateSearch;  //!< Square private to the item
   IBOutlet NSButton*	      _cancelButton;   //!< Delete selected align result
   IBOutlet NSButton*         _scaleButton;    //!< Whether to scale images
   IBOutlet NSButton*         _rotateButton;   //!< Whether to rotate images
   IBOutlet NSButton*	      _alignButton;    //!< Start alignment
   IBOutlet NSView*           _panel;          //!< Our view

   id <LynkeosWindowController> _window;       //!< Our window controller
   id <LynkeosViewDocument>   _document;       //!< Our document
   id <LynkeosImageList>      _list;           //!< The current list

   id <LynkeosImageView>      _imageView;      //!< For displaying the images

   // Cells for the table view
   //! Button to delete or add a square
   NSButtonCell              *_modifyButton;
   NSTextFieldCell           *_xField;         //!< Cell for x origin
   NSTextFieldCell           *_yField;         //!< Cell for y origin
   NSComboBoxCell            *_sizeField;      //!< Cell for size dropdown
   NSCell                    *_emptyCell;      //!< Cell without user interaction

   unsigned int               _sideMenuLimit;  //!< Upper limit for square side
   //! Number of squares in the current item, used only for detecting adds
   SelectionIndex_t           _numberOfSquares;
   BOOL                       _isAligning;     //!< Alignment is under process
   //! Whether to update image display after aligning each item
   BOOL                       _imageUpdate;
}

/*!
 * @abstract The option to compute rotation was changed
 * @param sender The control which value was changed
 */
- (IBAction) computeRotationChange :(id)sender ;
/*!
 * @abstract The option to compute rotation was changed
 * @param sender The control which value was changed
 */
- (IBAction) computeScaleChange :(id)sender ;
/*!
 * @abstract The reference item was changed
 * @param sender The control which value was changed
 */
- (IBAction) referenceAction :(id)sender ;
/*!
 * @abstract The search becomes or is no more specific to the selected item
 * @param sender The control which value was changed
 */
- (IBAction) specificSquareChange: (id)sender ;
/*!
 * @abstract Delete the selected item's align result
 * @param sender The button
 */
- (IBAction) cancelAction :(id)sender ;
/*!
 * @abstract Start aligning
 * @param sender The button
 */
- (IBAction) alignAction :(id)sender ;

@end

#endif
