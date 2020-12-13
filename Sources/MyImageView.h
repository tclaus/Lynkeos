//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Wed Sep 24 2003.
//  Copyright (c) 2003-2019. Jean-Etienne LAMIAUD
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
 * @abstract Definitions for the custom image view
 */
#ifndef __MYIMAGEVIEW_H
#define __MYIMAGEVIEW_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#include "SMDoubleSlider.h"

#include "LynkeosCommon.h"
#include "LynkeosProcessingView.h"

/*!
 * @abstract Position of a selection side or corner.
 * @discussion Preceding side is left or bottom and following is right or top.
 */
typedef enum
{
   PrecedingSide  = -1,
   MiddlePosition =  0,
   FollowingSide  =  1
} SelectionPosition_t;

/*!
 * @abstract Selection management model object
 */
@interface MyImageSelection : NSObject
{
@public
   BOOL                _resizable;   //!< Wether the selection is resizable
   BOOL                _movable;     //!< Wether the selection is movable
   LynkeosIntegerRect  _rect;        //!< Selection rectangle
 	// Cursor rectangles
   NSRect              _left;        //!< Left side cursor rectangle
   NSRect              _right;       //!< Right side cursor rectangle
   NSRect              _top;         //!< Top side cursor rectangle
   NSRect              _bottom;      //!< Bttom side cursor rectangle
   NSRect              _topLeft;     //!< Top left corner cursor rectangle
   NSRect              _topRight;    //!< Top right side corner rectangle
   NSRect              _bottomLeft;  //!< Bottom left side corner rectangle
   NSRect              _bottomRight; //!< Bottom right side corner rectangle
   NSRect              _inside;      //!< Interior cursor rectangle
}

/*!
 * @abstract Dedicated initializer
 * @param rect Selection rectangle
 * @param move Wether the selection is can be resized
 * @param resize Wether the selection is moved
 * @result The new initialized selection
 */
- (id) initWithRect:(LynkeosIntegerRect)rect movable:(BOOL)move resizable:(BOOL)resize;

/*!
 * @abstract Set a specific cursor rectangle
 * @param[out] r The cursor rectangle
 * @param cur The cursor associated to this rectangle
 * @param s width, height or side of the rectangle (or square)
 * @param hPos Horizontal order of this rectangle
 * @param vPos Vertical order of this rectangle
 * @param v Visible rectangle for this view
 * @param view The view in which to place the cursor
 */
- (void) processCursorRect:(NSRect*)r cursor:(NSCursor*)cur size:(float)s
           horizontalOrder:(SelectionPosition_t)hPos
             verticalOrder:(SelectionPosition_t)vPos
                   visible:(NSRect)v view:(NSView*)view;
@end

/*!
 * @abstract Selection dragging mode
 */
typedef enum { SelNone, SelNormal, SelH, SelV, SelMove } SelectionDraggingMode_t;

/*!
 * @abstract The custom image view.
 * @ingroup Views
 */
@interface MyImageView : NSView <LynkeosImageView>
{
@private
   // For IB
   IBOutlet NSSlider*         _zoomSlider;       //!< Slider controlling the zoom
   IBOutlet NSTextField*      _zoomField;        //!< Zoom text value

   IBOutlet SMDoubleSlider*   _blackWhiteSlider; //!< Black and white levels
   IBOutlet NSSlider*         _gammaSlider;      //!< Level exponent
   IBOutlet NSTextField*      _blackText;        //!< Black level text value
   IBOutlet NSTextField*      _whiteText;        //!< White level text value
   IBOutlet NSTextField*      _gammaText;        //!< Gamma level text value

   IBOutlet id                _delegate;         //!< The view delegate
   id <LynkeosImageViewDelegate> _selectionDelegate; //!< The selection delegate

   id <LynkeosProcessableItem> _item;            //!< The item to display
   //!< The displayed item modification sequence number
   u_long                     _itemSequenceNumber;
   LynkeosIntegerSize         _itemSize;         //<! The size of the displayed item

   // Image management
   NSAffineTransform*         _imageTransform;   //!< Additional transform
   NSRect                     _canvasRect;       //!< Rectangle in which the image fits after transformation
   NSOperationQueue*          _tilesQueue;       //!< Operation queue used to retrieve the image tiles
   CGContextRef               _layerContext;     //!< Bitmap context for the layer
   CGLayerRef                 _imageLayer;       //!< Layer accumulating the successive tiles

   // Zoom control
   double                     _zoom;             //!< Current zoom value
   // Selection management
   SelectionMode_t            _selectionMode;    //!< No, Single or Multi
   SelectionMode_t            _savedSelectionMode;  //!< Saved during freezing
   u_int                      _freezeCounter; //!< Take care of recursive freeze
   //! Array of MyImageSelection objects
   NSMutableArray            *_selection;
   //! Selection being modified
   LynkeosIntegerRect         _inProgressSelection;
   SelectionIndex_t           _currentSelectionIndex;
   SelectionIndex_t           _previousSelectionIndex;
   LynkeosIntegerPoint        _selectionOrigin, _lastPoint;
   unsigned int               _modifiers;
   NSCursor                                             // Cursors
                             *_topLeftCursor, *_topRightCursor,
                             *_bottomLeftCursor, *_bottomRightCursor,
                             *_insideCursor;
   SelectionDraggingMode_t    _draggingMode;
   NSTimer                   *_autoscrollTimer;
   BOOL                       _isNotifying;
}

//! \name IBActions
//! Methods connected to Interface builder actions
//!@{
/*!
 * @abstract Set the zoom according to the slider value
 * @param sender The slider.
 */
- (IBAction)doZoom:(id)sender;

/*!
 * @abstract Zoom in
 * @param sender The button.
 */
- (IBAction)moreZoom:(id)sender;

/*!
 * @abstract Zoom out
 * @param sender The button.
 */
- (IBAction)lessZoom:(id)sender;

/*!
 * @abstract Set the black and white levels for the image
 * @param sender the control that was changed
 */
- (IBAction) blackWhiteChange :(id)sender ;

/*!
 * @abstract Set the gamma correction exponent for the image
 * @param sender the control that was changed
 */
- (IBAction) gammaChange :(id)sender ;

//!@}

/*!
 * @abstract Retrieve the displayed image size
 * @result The image size
 */
- (NSSize) imageSize ;
@end

/*!
 * @abstract Selection handling in MyImageView
 */
@interface MyImageView(Selection)

/*!
 * @abstract Get all the details of a selection
 * @param index The index of the required selection
 * @param rect [out] the selection rectangle
 * @param resize [out] wether the selection is resizable
 * @param move [out] wether the selection is movable
 * @result None 
 */
- (void) getSelectionAtIndex:(SelectionIndex_t)index
                        rect:(LynkeosIntegerRect*)rect
                   resizable:(BOOL*)resize
                     movable:(BOOL*)move;

/*!
 * @abstract Initialize all the selection related cursors
 * @result None 
 */
- (void) initCursors ;

@end

#endif
