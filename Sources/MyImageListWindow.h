//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Sat Jan 17 2004.
//  Copyright (c) 2004-2014. Jean-Etienne LAMIAUD
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

/**
 * \page libraries Libraries needed to compile Lynkeos
 * The main window uses a double slider which can be found at 
 * http://developer.snowmintcs.com/controls/smdoubleslider/
 */

/*!
 * @header
 * @abstract Definitions of the document window.
 */
#ifndef __MYIMAGELISTWINDOW_H
#define __MYIMAGELISTWINDOW_H

#import <Foundation/Foundation.h>

#include "LynkeosProcessingView.h"
#include "MyPluginsController.h"
#include "MyDocument.h"
#include "MyImageListItem.h"
#include "MyImageList.h"
#include "MyImageView.h"
#include "LynkeosColumnDescriptor.h"

/** Common prefix for all toolbar items references */
extern NSString * const toolbarProcPrefix;

/** General authorization/inhibition for a processing view */
#define ProcessingViewAuthorized 8

@class MyProcessViewDefinition;

/*!
 * @abstract The document window controler
 * @discussion This class controls the document window.
 *    There are 3 objects to control in this window :
 *    <ul>
 *      <li>The image frame,
 *      <li>The outline view where all the images are listed,
 *      <li>The "control" frame, where is displayed a view controlling the 
 *          current action, not necesarily connected to this controller.
 *    </ul>
 * @ingroup Controlers
 */
@interface MyImageListWindow : NSWindowController 
                               <LynkeosWindowController,
                                LynkeosDocumentDelegate,
                                NSOutlineViewDataSource,
                                NSOutlineViewDelegate,
                                NSToolbarDelegate>
{
@private
   // Related user interface objects
   // Views
   IBOutlet NSOutlineView*    _textView;     //!< List of movies and images
   IBOutlet NSScrollView*     _processPane;  //!< For process controls
   IBOutlet MyImageView*      _imageView;    //!< Displays the images
   IBOutlet NSPopUpButton*    _listMenu;     //!< Image/dark frame/flat field
   IBOutlet NSMatrix*         _dataModeRadio; //!< Process list or result
   IBOutlet NSSplitView*      _imageSplit;   //!< Split between image and list
   IBOutlet NSSplitView*      _listSplit;    //!< Split between list and process

   IBOutlet NSPanel*          _processWindow;   //!< Detached window for process
   IBOutlet NSScrollView*     _detachedProcessPane; //!< Detached process view

   IBOutlet NSButton*         _listMarginButton;   //!< Used to hide the margin
   IBOutlet NSButton*         _listSplitButton;    //!< Reattach the process
   IBOutlet NSButton*         _procMarginButton;   //!< Used to hide the margin
   IBOutlet NSButton*         _expandProcessButton; //!< Process uses all margin
   IBOutlet NSButton*         _processSplitButton; //!< Show the list
   //! Put the view in another window
   IBOutlet NSButton*         _detachProcessButton;
   IBOutlet NSProgressIndicator *_progress;     //!< Processing progress

   // Additional view for save panel
   //! Controls for save parameters
   IBOutlet NSView            *_fileWritersView;
   IBOutlet NSPopUpButton     *_fileWritersMenu; //!< File format menu

   //! Description of all the possible columns values (pointer on the singleton)
   LynkeosColumnDescriptor         *_columnsDescriptor;

   //! Initial pseudo processing view for list management
   IBOutlet id <LynkeosProcessingView> _listProcessing;

   // Processing view controller
   //! Current active processing view
   NSView                     *_processingView;
   //! Controller for the active processing view
   NSObject <LynkeosProcessingView> *_processingViewController;
   //! Parameters of the current controller
   LynkeosProcessingViewRegistry* _processingViewReg;
   //! Current processing characteristics
   MyProcessViewDefinition*    _processingViewDef;
   //! Flat dictionary of all the processing views
   NSMutableDictionary        *_processingViewDict;
   //! Authorized modes of display for the processes
   unsigned int               *_processingAuthorization;
   //! Current mode of display
   LynkeosProcessingViewFrame_t _currentProcessDisplay;
   //! Authorized modes of display for the current process
   unsigned int                _authorizedProcessDisplays;
   //! Wether the processing has a progress display
   BOOL                        _displayProgress;

   // Support for persistent zoom in the image view
   double                     _resultZoom;     //!< Zoom factor in result mode
   double                     _listZoom;       //!< Zoom factor in list mode

   // Support for splitviews collapsing
   NSView*                    _marginSubview;  //!< Store for the hidden margin view
   NSView*                    _processSubview; //!< Store for the hidden process view
   NSView*                    _listSubview;    //!< Store for the hidden list view

   NSMenu                     *_processMenu;   //!< The processes menu

   // Toolbar
   NSToolbar                  *_toolBar;       //!< Main window toolbar
   // Window state
   //! Item currently selected in the list
   MyImageListItem*	      _highlightedItem;
   BOOL                       _isProcessing;  //!< Is a processing in progress
   //! Wether list mode is authorized
   BOOL                       _listSelectionAuthorized;
   //! Wether data mode is authorized
   BOOL                       _dataModeSelectionAuthorized;
   //! Wether selecting items in the list is authorized
   BOOL                       _itemSelectionAuthorized;
   //! Wether items can be edited (ie: checked / unchecked)
   BOOL                       _itemEditionAuthorized;
   //! Current list (image / flat / dark) being worked on
   ListMode_t                 _listMode;
   //! Wether acting on the list or the stack
   DataMode_t                 _dataMode;

   // The current save panel
   NSSavePanel                *_savePanel;      //!< The save file dialog
   NSMutableArray             *_currentWriters; //!< List of avilable writers

   //! @abstract document contents
   //! @discussion optimisation to jump over a redirection for reads, document
   //!    is still called for writing
   id <LynkeosImageList>       _currentList;
}

/// \name Actions
/// Actions provided to the "process views"
//@{
- (void) keyDown: (NSEvent*)theEvent;

- (void) addURLs :(NSArray*)URLs ;
//@}

/// \name GUIActions
/// Actions which are target of NIB objects
//@{
   // Buttons or menu actions
- (IBAction) modeMenuAction :(id)sender ;
- (IBAction) dataModeAction :(id)sender ;

- (IBAction) addAction :(id)sender ;
- (IBAction) delete :(id)sender ;
- (IBAction) toggleEntrySelection :(id)sender ;
- (IBAction) highlightNext :(id)sender ;
- (IBAction) highlightPrevious :(id)sender ;

- (IBAction) fileWritersPopupAction : (id)sender ;

- (IBAction) hideImageMargin:(id)sender ;
- (IBAction) shareMargin:(id)sender ;

// Processing views
- (void) activateProcessingView: (id) sender ;

// Main menu actions
// Windows management
- (IBAction) showHideImageList:(id)sender;
- (IBAction) attachDetachProcessView:(id)sender;

// Input output
- (IBAction) saveStackedImage :(id)sender ;
- (IBAction) exportMovie :(id)sender ;
//@}
@end

#endif
