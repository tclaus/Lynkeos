//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Fri Nov 28 2003.
//  Copyright (c) 2003-2020. Jean-Etienne LAMIAUD
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

#include <limits.h>

#include "LynkeosFileWriter.h"

#include "MyGuiConstants.h"
#include "MyImageListWindow.h"

#include "LynkeosImageBufferAdditions.h"
#include "LynkeosGammaCorrecter.h"
#include "MyUserPrefsController.h"

#ifdef DOUBLE_PIXELS
#define powerof(x,y) pow(x,y)
#else
#define powerof(x,y) powf(x,y)
#endif

static NSString * const K_PREFERED_IMAGE_WRITER = @"Last image writer";
static NSString * const K_PREFERED_MOVIE_WRITER = @"Last movie writer";

static NSString * const K_TOOLBAR_REF = @"Processing toolbar";

static NSString * const K_WINFRAME_KEY = @"window frame";
static NSString * const K_MARGINWIDTH_KEY = @"margin width";
static NSString * const K_PROCESSHEIGHT_KEY = @"process height";
static NSString * const K_COLUMNSWIDTH_KEY = @"columns width";

static NSCursor *myWatchCursor = nil;

typedef enum { K_UP, K_DOWN } enumeration_direction_t;

/*!
 * @abstract Parameters of a processing tool
 */
@interface MyProcessViewDefinition : NSObject
{
@public
    //! The processing controller
   NSObject <LynkeosProcessingView> *_viewController;
   //! The process view
   NSView                           *_view;
   //! The current framing mode for this process
   LynkeosProcessingViewFrame_t     _currentFrame;
   //! Associated menu item (loose binding)
   NSMenuItem                       *_menuItem;
   //! Index in the processing tools
   NSInteger                         _processIndex;
   //! Processing tool title
   NSString                         *_title;
}
@end

@implementation MyProcessViewDefinition
- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _viewController = nil;
      _view = nil;
      _currentFrame = BottomTab;
      _menuItem = nil;
      _processIndex = NSNotFound;
      _title = nil;
   }

   return( self );
}

- (void) dealloc
{
   [_viewController release];
   [_title release];

   [super dealloc];
}
@end

@interface MyImageListWindow(Private)
- (void) highlightOther:(enumeration_direction_t)sense skipUnselected:(BOOL)skip;
- (void) itemChanged:(NSNotification*)notif ;
- (void) zoomChanged:(NSNotification*)notif ;
@end

@interface MyImageListWindow(SplitView)
- (void) setProcessView:(NSView*)newView
            withDisplay:(LynkeosProcessingViewFrame_t)display ;
- (void) validateSplitControls ;
@end

@implementation MyImageListWindow(Private)
- (void) highlightOther :(enumeration_direction_t)sense skipUnselected:(BOOL)skip
{
   NSEnumerator *list;
   MyImageListItem *item;
   MyImageListItem *parent;

   list = [_currentList imageEnumeratorStartAt:_highlightedItem 
                                   directSense:(sense==K_DOWN)
                                skipUnselected:skip];

   item = [list nextObject];

   if ( item == nil )
      return;

   parent = [item getParent];
   if ( parent != nil )
      [_textView expandItem:parent];

   [self highlightItem:item];
}

- (void) itemChanged:(NSNotification*)notif
{
   // Get the modified item
   MyImageListItem *item = [[notif userInfo] objectForKey:LynkeosUserInfoItem];

   if ( [item isKindOfClass:[MyImageListItem class]] )
   {
      // Redisplay it
      [_textView reloadItem:item reloadChildren:[item numberOfChildren] != 0];
      // And its parent if needed
      MyImageListItem *parent = [item getParent];
      if ( parent != nil )
         [_textView reloadItem:parent reloadChildren:NO];
   }
}

- (void) zoomChanged:(NSNotification*)notif
{
   double zoom = [_imageView getZoom];

   switch( [(MyDocument*)[self document] dataMode] )
   {
      case ResultData :
         _resultZoom = zoom;
         break;
      case ListData :
         _listZoom = zoom;
         break;
      default : NSAssert( NO, @"Inconsistent data mode" );
   }
}
@end

@implementation MyImageListWindow
- (id) init
{
   if ( (self = [super init]) == nil )
      return( self );

   _highlightedItem = nil;
   _processingViewDict = [[NSMutableDictionary dictionary] retain];
   _processingAuthorization = NULL;
   _isProcessing = NO;
   _listSelectionAuthorized = YES;
   _dataModeSelectionAuthorized = YES;
   _itemSelectionAuthorized = NO;
   _itemEditionAuthorized = NO;
   _processingViewReg = nil;
   _processingViewController = nil;
   _currentProcessDisplay = BottomTab;
   _authorizedProcessDisplays = 0;
   _displayProgress = YES;
   _listMode = ImageMode;
   _dataMode = ListData;
   _resultZoom = 1.0;
   _listZoom = 1.0;

   _toolBar = [[NSToolbar alloc] initWithIdentifier:K_TOOLBAR_REF];
   [_toolBar setAllowsUserCustomization:YES];
   [_toolBar setAutosavesConfiguration:YES];
   [_toolBar setDelegate:self];

   // Create the watch cursor
   if ( myWatchCursor == nil )
      myWatchCursor = [[NSCursor alloc] initWithImage:
                                                   [NSImage imageNamed:@"watch"]
                                              hotSpot:NSMakePoint(8,8)];

   return( [super initWithWindowNibName:@"ImageListWindow"] );
}

- (void) dealloc
{
   [[NSNotificationCenter defaultCenter] removeObserver:self];
   [_processingViewDict release];
   if ( _processingAuthorization != NULL )
      free( _processingAuthorization );
   [_listSubview release];
   [_processSubview release];
   [_marginSubview release];
   [_toolBar release];

   [super dealloc];
}

- (void) windowDidLoad
{
   // Get the document contents
   _currentList = (MyImageList*)[(MyDocument*)[self document] imageList];

   NSTableColumn *tableColumn = nil;
   NSButtonCell *buttonCell = nil;

   // Initialize the buttons in the outline first column
   tableColumn = [_textView tableColumnWithIdentifier: @"select"];
   buttonCell = [[[NSButtonCell alloc] initTextCell: @""] autorelease];
   [buttonCell setEditable: YES];
   [buttonCell setButtonType: NSSwitchButton];
   [buttonCell setAllowsMixedState: YES];
   [buttonCell setControlSize:NSSmallControlSize];
   [tableColumn setDataCell:buttonCell];
   [_textView reloadData];

   // Get the columns descriptions
   _columnsDescriptor = [LynkeosColumnDescriptor defaultColumnDescriptor];

   // Initialize dragging
   [_textView registerForDraggedTypes:
    [NSArray arrayWithObject:NSFilenamesPboardType]];

   // Initialize image view
   [_imageView setSelectionMode:NoSelection];

   // Initialize the frames
   _listSubview = [[[_listSplit subviews] objectAtIndex:0] retain];
   _processSubview = [[[_listSplit subviews] objectAtIndex:1] retain];
   _marginSubview = [[[_imageSplit subviews] objectAtIndex:0] retain];   

   // Restore the window frames
   NSDictionary *wSizes = [(MyDocument*)[self document] savedWindowSizes];
   if ( wSizes != nil )
   {
      NSString* wframe = [wSizes objectForKey:K_WINFRAME_KEY];
      if (wframe != nil )
         [[self window] setFrameFromString:wframe];
      NSSize size;
      float delta;
      NSNumber *nb = [wSizes objectForKey:K_PROCESSHEIGHT_KEY];
      if ( nb != nil )
      {
         size = [_processSubview frame].size;
         delta = [nb floatValue] - size.height;
         size.height += delta;
         [_processSubview setFrameSize:size];
         size = [_listSubview frame].size;
         size.height -= delta;
         [_listSubview setFrameSize:size];
         [_listSplit adjustSubviews];
      }
      nb = [wSizes objectForKey:K_MARGINWIDTH_KEY];
      if ( nb != nil )
      {
         size = [_marginSubview frame].size;
         delta = [nb floatValue] - size.width;
         size.width += delta;
         [_marginSubview setFrameSize:size];
         NSView *imageSubview = [[_imageSplit subviews] objectAtIndex:1];
         size = [imageSubview frame].size;
         size.width -= delta;
         [imageSubview setFrameSize:size];
         [_imageSplit adjustSubviews];
      }
      NSDictionary *colSizes = [wSizes objectForKey:K_COLUMNSWIDTH_KEY];
      if ( colSizes != nil )
      {
         NSEnumerator *sizeList = [colSizes keyEnumerator];
         id colSize;
         while( (colSize = [sizeList nextObject]) != nil )
         {
            NSTableColumn *col = [_textView tableColumnWithIdentifier:colSize];
            if ( col != nil && col != [_textView outlineTableColumn] )
               [col setWidth:[[colSizes objectForKey:colSize] floatValue]];
         }
      }
   }

   // Initialize the processing view controllers management
   NSArray *processingList =
   [[MyPluginsController defaultPluginController] getProcessingViews];
   NSUInteger i, listProcIndex = NSNotFound, nCtrl = [processingList count];
   _processingAuthorization = (unsigned int*)malloc(sizeof(unsigned int)*nCtrl);
   for( i = 0; i < nCtrl; i++ )
   {
      LynkeosProcessingViewRegistry *reg = [processingList objectAtIndex:i];
      if ( [reg->controller respondsToSelector:
            @selector(authorizedModesForConfig:)] )
         _processingAuthorization[i] = 
         [reg->controller authorizedModesForConfig:reg->config]
         | ProcessingViewAuthorized;
      else
      {
         _processingAuthorization[i] = ProcessingViewAuthorized
         |ImageMode|ListData;
         switch ( [reg->controller processingViewKindForConfig:reg->config] )
         {
            case ImageProcessingKind:
            case OtherProcessingKind:
               _processingAuthorization[i] |= ResultData;
               break;
            default: break;
         }
      }

      // Hack : use this loop to locate the registry for the list manager
      if ( reg->controller == [_listProcessing class] )
         listProcIndex = i;
   }
   [[NSNotificationCenter defaultCenter] postNotificationName:
                                              LynkeosDocumentDidOpenNotification
                                                       object:[self document]
                                                     userInfo:
    [NSDictionary dictionaryWithObject:self
                                forKey:LynkeosUserinfoWindowController]];

   // Initialize the toolbar with all the processings
   [[self window] setToolbar:_toolBar];

   // Put the list manager instance in the processing views dictionary
   MyProcessViewDefinition *def =
                           [[[MyProcessViewDefinition alloc] init] autorelease];

   // The list processing will be released with the definition, and as a Nib
   // top level object : so retain it on behalf of the definition
   def->_viewController = [_listProcessing retain];
   def->_view = [_listProcessing getProcessingView];
   def->_currentFrame = [_listProcessing preferredDisplay];
   NSAssert( listProcIndex != NSNotFound, @"List management registry not found" );
   def->_processIndex = listProcIndex;
   _processMenu = [[[NSApp mainMenu] itemWithTag:K_PROCESS_MENU_TAG] submenu];
   def->_menuItem = [_processMenu itemWithTag:def->_processIndex];
   def->_title = [[NSString stringWithString:[def->_menuItem title]] retain];

   [_processingViewDict setObject:def
                           forKey:@"LynkeosProcToolbarItem_MyListManagement"];
   _processingViewDef = def;

   // And set it as the first active view
   [self activateProcessingView:def->_menuItem];

   // Register for notifications
   NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
   [notifCenter addObserver:self
                   selector:@selector(itemChanged:)
                       name: LynkeosItemChangedNotification
                     object:[self document]];
   [notifCenter addObserver:self
                   selector:@selector(zoomChanged:)
                       name: LynkeosImageViewZoomDidChangeNotification
                     object:_imageView];

   // Update initial state
   [self documentListModeChanged:[self document]];
   [self documentDataModeChanged:[self document]];
}

- (void) keyDown:(NSEvent *)theEvent
{
   unichar c = [[theEvent characters] characterAtIndex:0];

   if ( !_isProcessing )
   {
      if ( _processingViewController != nil
           && [_processingViewController respondsToSelector:
                                                      @selector(handleKeyDown:)]
           && [_processingViewController handleKeyDown:theEvent] )
         return;

      BOOL nextEnabled = [[_currentList imageArray] count] != 0;

      if ((theEvent.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask
           & ~NSEventModifierFlagNumericPad & ~NSEventModifierFlagFunction) == 0)
      {
         switch( c )
         {
            case NSLeftArrowFunctionKey:
               if ( nextEnabled )
                  [self highlightPrevious:nil];
               break;
            case NSRightArrowFunctionKey :
               if ( nextEnabled )
                  [self highlightNext:nil];
               break;
            case NSDownArrowFunctionKey:
               if ( nextEnabled )
                  [self highlightOther:K_DOWN skipUnselected:NO];
               break;
            case NSUpArrowFunctionKey:
               if ( nextEnabled )
                  [self highlightOther:K_UP skipUnselected:NO];
               break;
            case NSHomeFunctionKey :
               if ( nextEnabled )
                  [self highlightItem:[_currentList firstItem]];
               break;
            case NSEndFunctionKey :
               if ( nextEnabled )
                  [self highlightItem:[_currentList lastItem]];
               break;
            case '\r' :
            case ' ' :
               if ( _highlightedItem != nil )
                  [self toggleEntrySelection:nil];
               break;
            case NSDeleteFunctionKey :
            case '\b' :
            case 127 : // Delete char
               if ( _highlightedItem != nil )
                  [self delete:nil];
               break;
            default:
               [super keyDown:theEvent];
               break;
         }
      }
      else
         [super keyDown:theEvent];
   }
   else
      [super keyDown:theEvent];
}

- (BOOL)validateMenuItem:(NSMenuItem*)menuItem
{
   NSInteger tag = [menuItem tag];
   switch ( tag )
   {
      case K_SAVE_TAG:
      case K_SAVE_AS_TAG:
      case K_REVERT_TAG:
      case K_ADD_IMAGE_TAG:
         return( ! _isProcessing );
      case K_SAVE_IMAGE_TAG:
      {
         id <LynkeosProcessableItem> item = nil;
         double b, w, g;

         switch ( _dataMode )
         {
            case ListData:
               if ( _highlightedItem != nil
                   && [_highlightedItem numberOfChildren] == 0 )
                  item = _highlightedItem;
               break;
            case ResultData: item = _currentList; break;
            default: NSAssert1( NO, @"Invalid data mode %d", _dataMode );
         }

         return( !_isProcessing && item != nil
                 && [item getBlackLevel:&b whiteLevel:&w gamma:&g] );
      }
      case K_EXPORT_MOVIE_TAG:
         return( _dataMode == ListData && !_isProcessing
                 && [[_currentList imageArray] count] != 0 );
      case K_UNDO_TAG:
      case K_REDO_TAG:
         return( !_isProcessing );
      case K_DELETE_TAG:
         return( !_isProcessing && _highlightedItem != nil );
      case K_HIDE_LIST_TAG:
         switch( _currentProcessDisplay )
      {
         case BottomTab:
            return( (_authorizedProcessDisplays & BottomTab_NoList) != 0 );
         case BottomTab_NoList:
            return( (_authorizedProcessDisplays & BottomTab) != 0 );
         case SeparateView:
            return( (_authorizedProcessDisplays & SeparateView_NoList) != 0 );
         case SeparateView_NoList:
            return( (_authorizedProcessDisplays & SeparateView) != 0 );
      }
      case K_DETACH_PROCESS_TAG:
         switch( _currentProcessDisplay )
      {
         case BottomTab:
            return( (_authorizedProcessDisplays & SeparateView) != 0 );
         case BottomTab_NoList:
            return( (_authorizedProcessDisplays & SeparateView_NoList) != 0 );
         case SeparateView:
            return( (_authorizedProcessDisplays & BottomTab) != 0 );
         case SeparateView_NoList:
            return( (_authorizedProcessDisplays & BottomTab_NoList) != 0 );
      }
         break;
      default:
         if ( [menuItem menu] == _processMenu )
         {
            unsigned int mask = ProcessingViewAuthorized|_listMode;
            return( !_isProcessing &&
                   (_processingAuthorization[tag] & mask) == mask );
         }
         break;
   }
   // Other menus sending to this controller should always be enabled
   return( YES );
}

- (BOOL)windowShouldClose:(id)sender
{
   if ( sender == _processWindow )
   {
      NSAssert1( _currentProcessDisplay == SeparateView || 
                _currentProcessDisplay == SeparateView_NoList,
                @"Process window tries to close while in display %d",
                _currentProcessDisplay );
      return( (_currentProcessDisplay == SeparateView
               && (_authorizedProcessDisplays & BottomTab) != 0) ||
             (_currentProcessDisplay == SeparateView_NoList
              && (_authorizedProcessDisplays & BottomTab_NoList) != 0) );
   }
   else
      return( YES );
}

- (void)windowWillClose:(NSNotification *)aNotification
{
   NSWindow *w = [aNotification object];
   if ( w == _processWindow )
   {
      LynkeosProcessingViewFrame_t display = 0;

      switch( _currentProcessDisplay )
      {
         case SeparateView: display = BottomTab; break;
         case SeparateView_NoList:  display = BottomTab_NoList; break;
         default: break;
      }

      if ( display != 0 )
      {
         [self setProcessView:_processingView withDisplay:display];
         _processingViewDef->_currentFrame = display;
      }
   }
   else if ( w == [self window] )
   {
      // Stop the process in progress if any
      if ( _isProcessing )
         [(id <LynkeosDocument>)[self document] stopProcess];
      // Wait for process completion
      while ( _isProcessing )
         [[NSRunLoop currentRunLoop] runUntilDate:
          [NSDate dateWithTimeIntervalSinceNow:0.2]];
      // Deactivate any remaining processing view
      if ( _processingViewController != nil )
         [_processingViewController setActiveView:NO];
      // And notify it
      [[NSNotificationCenter defaultCenter] postNotificationName:
                                            LynkeosDocumentWillCloseNotification
                                                          object:[self document]
                                                        userInfo:
           [NSDictionary dictionaryWithObject:self
                                       forKey:LynkeosUserinfoWindowController]];      
   }
}

- (NSRect)windowWillUseStandardFrame:(NSWindow *)sender
                        defaultFrame:(NSRect)defaultFrame
{
   if ( sender == _processWindow )
   {
      NSRect content = [_processingView frame];
      NSSize maxSize = [_processWindow maxSize];

      // Add some space to be sure that the srollbars don't show up
      content.size.width += 2;
      content.size.height += 2;
      if ( content.size.width > maxSize.width )
         content.size.width = maxSize.width;
      if ( content.size.height > maxSize.height )
         content.size.height = maxSize.height;
      return( [sender frameRectForContentRect:content] );
   }
   else
      return( defaultFrame );
}

- (void)windowDidBecomeMain:(NSNotification *)aNotification
{
   NSWindow *main = [self window];
   NSWindow *sender = [aNotification object];

   NSAssert1( sender == main, @"Unexpected window becomes main : %@", sender );

   if ( _currentProcessDisplay == SeparateView
       || _currentProcessDisplay == SeparateView_NoList )
   {
      [_processWindow makeKeyAndOrderFront:self];
      [NSApp addWindowsItem:_processWindow title:[_processWindow title]
                   filename:NO];
   }

   if ( _processingViewDef != nil )
      [_processingViewDef->_menuItem setState:NSOnState];
}

- (void)windowDidResignMain:(NSNotification *)aNotification
{
   NSWindow *main = [self window];
   NSWindow *sender = [aNotification object];

   NSAssert1( sender == main, @"Unexpected window becomes main : %@", sender );

   if ( _currentProcessDisplay == SeparateView
       || _currentProcessDisplay == SeparateView_NoList )
   {
      [_processWindow orderOut:self];
      [NSApp removeWindowsItem:_processWindow];
   }

   if ( _processingViewDef != nil )
      [_processingViewDef->_menuItem setState:NSOffState];
}

#pragma mark = LynkeosDocumentDelegate protocol
- (void) documentDidLoad : (id <LynkeosDocument>)document
{
   // Select the list management tool
   MyProcessViewDefinition *def = [_processingViewDict objectForKey:
                                   @"LynkeosProcToolbarItem_MyListManagement"];

   [self activateProcessingView:def->_menuItem];
   // And force it to update
   [[NSNotificationCenter defaultCenter] postNotificationName:
                                                   LynkeosListChangeNotification
                                                       object:[self document]];
}

- (void) document:(id <LynkeosDocument>)document
  processDidStart:(Class)processClass
{
   _isProcessing = YES;
   [_listMenu setEnabled: NO];
   [_dataModeRadio setEnabled: NO];
   if ( _displayProgress )
      [_progress startAnimation:self];
}

- (void) document:(id <LynkeosDocument>)document
  processHasEnded:(Class)processingClass
{
   _isProcessing = NO;
   [_listMenu setEnabled: _listSelectionAuthorized];
   [_dataModeRadio setEnabled: _dataModeSelectionAuthorized];
   [_progress stopAnimation:self];
   [[self window] update];
}

- (void) itemWasAdded:(id <LynkeosDocument>)document
{
   [_textView reloadData];
}

- (void) itemWasRemoved:(id <LynkeosDocument>)document
{
   [_textView reloadData];
   // Force update of the hilighted item in case it was deleted
   // Because outline view does not notify (the selection is at same line)
   [self outlineViewSelectionDidChange:
      [NSNotification notificationWithName:@"LynkeosItemRemoved" object:nil]];
}

- (void) documentListModeChanged:(id <LynkeosDocument>)document
{
   ListMode_t mode = [(MyDocument*)document listMode];

   if ( _listMode != mode )
   {
      _listMode = mode;
      [_listMenu selectItemWithTag:_listMode];
   }

   _currentList = [(MyDocument*)document currentList];
   // Redisplay the outline view
   [_textView reloadData];

   if ( _dataMode == ResultData )
      // Force selection on first and only line
      [_textView selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
             byExtendingSelection:NO];
   else
      // Force notification of selection in the new list
      [self outlineViewSelectionDidChange:
         [NSNotification notificationWithName:@"LynkeosListModeChange" object:nil]];
}

- (void) documentDataModeChanged:(id <LynkeosDocument>)document
{
   DataMode_t mode = [(MyDocument*)document dataMode];

   if ( _dataMode != mode )
   {
      _dataMode = mode;
      [_dataModeRadio selectCellWithTag:_dataMode];
      // Redisplay the outline view
      [_textView reloadData];
      // Reset the bounds of the image view, which were adapted to the "other" mode
      [_imageView resetBounds];

      if ( _dataMode == ResultData )
         // Force selection on first and only line
         [_textView selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
                byExtendingSelection:NO];

      if ( _processingViewController == nil
          || ![[_processingViewController class] respondsToSelector:
               @selector(handleImageViewZoom)]
          || ![[_processingViewController class] handleImageViewZoom] )
         [_imageView setZoom:(_dataMode == ResultData ?
                              _resultZoom : _listZoom)];

      // In case the outline view did not notify, do it ourselves
      [self outlineViewSelectionDidChange:
         [NSNotification notificationWithName:@"LynkeosDataModeChange" object:nil]];
   }
}

#pragma mark = LynkeosWindowController protocol
- (NSDictionary*) windowSizes
{
   // Get the columns
   NSArray *columns = [_textView tableColumns];
   NSMutableDictionary *columnSizes =
                   [NSMutableDictionary dictionaryWithCapacity:[columns count]];
   NSEnumerator *colList = [columns objectEnumerator];
   NSTableColumn *col;
   while ( (col = [colList nextObject]) != nil )
   {
      if ( col != [_textView outlineTableColumn] )
         [columnSizes setObject:[NSNumber numberWithFloat:[col width]]
                                                   forKey:[col identifier]];
   }

   return( [NSDictionary dictionaryWithObjectsAndKeys:
                  [[self window] stringWithSavedFrame],
                  K_WINFRAME_KEY,
                  [NSNumber numberWithFloat:[_marginSubview frame].size.width],
                  K_MARGINWIDTH_KEY,
                  [NSNumber numberWithFloat:[_processSubview frame].size.height],
                  K_PROCESSHEIGHT_KEY,
                  columnSizes,
                  K_COLUMNSWIDTH_KEY,
                  nil] );
}

- (id <LynkeosImageView>) getImageView { return( _imageView ); }
- (id <LynkeosImageView>) getRealImageView { return( _imageView ); }

// Accessors
- (id <LynkeosProcessableItem>) highlightedItem
{
   return( _highlightedItem );
}

- (void) highlightItem :(id <LynkeosProcessableItem>)item
{
   if ( item == nil )
      [_textView deselectAll:self];

   else
   {
      NSInteger row;
      MyImageListItem *parent = nil;
      if ( [item isKindOfClass:[MyImageListItem class]] )
         parent = [(MyImageListItem*)item getParent];

      // Expand father (won't do anything if already expanded)
      if ( parent != nil )
	 [_textView expandItem:parent];

      row = [_textView rowForItem:item];

      // Don't change highlight if item is not in the list
      if ( row < 0 )
	 return;

      // Set the hilight
      [_textView selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
             byExtendingSelection:NO];
      [_textView scrollRowToVisible:row];
   }
}

- (void) setListSelectionAuthorization: (BOOL)auth
{
   _listSelectionAuthorized = auth;
   [_listMenu setEnabled: (auth && !_isProcessing)];
}

- (void) setDataModeSelectionAuthorization: (BOOL)auth
{
   _dataModeSelectionAuthorized = auth;
   [_dataModeRadio setEnabled: (auth && !_isProcessing)];
}

- (void) setItemSelectionAuthorization: (BOOL)auth
{
   _itemSelectionAuthorized = auth;
}

- (void) setItemEditionAuthorization: (BOOL)auth
{
   _itemEditionAuthorized = auth;
}

- (void) setProcessing:(Class)c andIdent:(NSString*)ident
         authorization: (BOOL)auth
{
   NSEnumerator *list = [[[MyPluginsController defaultPluginController]
                                          getProcessingViews] objectEnumerator];
   LynkeosProcessingViewRegistry *reg = nil;
   NSUInteger tag = NSNotFound, i = 0;
   while( (reg = [list nextObject]) != nil )
   {
      if ( reg->controller == c && reg->ident == ident )
      {
         tag = i;
         break;
      }
      i++;
   }
   NSAssert( tag != NSNotFound, @"Unknown process to authorize" );
   if ( auth )
      _processingAuthorization[tag] |= ProcessingViewAuthorized;
   else
      _processingAuthorization[tag] &= ~ProcessingViewAuthorized;
}

- (void) getItemToProcess:(LynkeosProcessableImage**)item
             andParameter:(LynkeosImageProcessingParameter**)param
                  forView:(id <LynkeosProcessingView>)sender
{
   switch ( _dataMode )
   {
      case ListData:
         if ( [_highlightedItem numberOfChildren] == 0 )
            *item = _highlightedItem; // Movies are not really processable
         break;
      case ResultData:
         *item = (LynkeosProcessableImage*)_currentList;
         break;
      default:
         NSAssert1( NO, @"Invalid data mode %d", _dataMode );
   }

   *param = nil;  // Default value

   // Get the topmost processing if handled by this process controller
   if ( *item != nil )
   {
      NSMutableArray *stack =
                      (NSMutableArray*)[*item getProcessingParameterWithRef:
                                                             K_PROCESS_STACK_REF
                                                              forProcessing:nil
                                                                       goUp:NO];
      if ( stack != nil && [stack count] > 0 )
      {
         LynkeosImageProcessingParameter *lastParam = [stack lastObject];
         id <NSObject> dummy;
         if ( [[sender class] isViewControllingProcess:
                                                     [lastParam processingClass]
                                            withConfig:&dummy] )
         {
            *param = lastParam;
            [lastParam setExcluded:NO];   // Force it in case of reselection
         }
      }
   }
}

- (void) saveImage:(LynkeosImageBuffer*)image withBlack:(double*)black
             white:(double*)white
             gamma:(double*)gamma
{
   NSEnumerator *list;
   Class writerClass;
   id <LynkeosImageFileWriter> writer;
   NSInteger selectedIndex = -1;

   // Construct the writers list
   _currentWriters = [NSMutableArray array];
   if ( [_fileWritersMenu numberOfItems] != 0 )
      [_fileWritersMenu removeAllItems];
   for( list = [[[MyPluginsController defaultPluginController]
                 getImageWriters] objectEnumerator];
       (writerClass = [list nextObject]) != nil; )
   {
      if ( [writerClass canSaveDataWithPlanes:image->_nPlanes 
                                        width:image->_w height:image->_h
                                     metaData:nil] )
      {
         [_currentWriters addObject:writerClass];
         [_fileWritersMenu addItemWithTitle:[writerClass writerName]];
      }
   }

   // Select the last used, if any ; otherwise, select the first
   NSString *prefWriter = [[NSUserDefaults standardUserDefaults] 
                           stringForKey:K_PREFERED_IMAGE_WRITER];
   if ( prefWriter != nil )
      selectedIndex = [_fileWritersMenu indexOfItemWithTitle:prefWriter];
   if ( selectedIndex == -1 )
      selectedIndex = 0;
   [_fileWritersMenu selectItemAtIndex:selectedIndex];

   _savePanel = [NSSavePanel savePanel];
   [_savePanel setTitle:NSLocalizedString(@"Save image",
                                          @"Save image window title")];
   [_savePanel setCanSelectHiddenExtension:YES];
   [_savePanel setAccessoryView:_fileWritersView];
   writerClass = [_currentWriters objectAtIndex:selectedIndex];
   [_savePanel setAllowedFileTypes:[NSArray arrayWithObject:[writerClass fileExtension]]];

   if ( [_savePanel runModal] == NSFileHandlingPanelOKButton )
   {
      // The user gave a filename, save the image in it
      NSURL *url = [_savePanel URL];

      selectedIndex = [_fileWritersMenu indexOfSelectedItem];
      writerClass = [_currentWriters objectAtIndex: selectedIndex];

      // Allocate a writer instance
      writer = (id <LynkeosImageFileWriter>)[writerClass 
                                             writerForURL:url 
                                             planes:image->_nPlanes 
                                             width:image->_w
                                             height:image->_h
                                             metaData:nil];

      // Let the user fine tune the writer's options
      if ( [NSApp runModalForWindow:[writer configurationPanel]] == NSOKButton )
      {
         // Set the watch cursor
         [myWatchCursor push];

         // And save at last
         LynkeosImageBuffer *copy = [image copy];
         const u_short nPlanes = copy->_nPlanes;
         u_short x, y, c;
         double vmin, vmax, a;
         a = 1.0/(white[nPlanes] - black[nPlanes]);
         [copy getMinLevel:&vmin maxLevel:&vmax];

         for( c = 0; c < nPlanes; c++ )
         {
            double ac = (vmax - vmin)/(white[c] - black[c]);
            LynkeosGammaCorrecter *gammaCorrect = 
                                 [LynkeosGammaCorrecter getCorrecterForGamma:
                                                      gamma[nPlanes]*gamma[c]];

            for( y = 0; y < copy->_h; y++ )
            {
               for( x = 0; x < copy->_w; x++ )
               {
                  colorValue(copy,x,y,c) = 
                     correctedValue( gammaCorrect,
                                       ( (colorValue(copy,x,y,c) - black[c])*ac
                                         + vmin - black[nPlanes]) * a);
               }
            }
            [gammaCorrect releaseCorrecter];
         }

         [writer saveImageAtURL:url
                       withData:(const REAL*const*const)[copy colorPlanes]
                     blackLevel:black[nPlanes] whiteLevel:white[nPlanes]
                     withPlanes:image->_nPlanes
                          width:image->_w lineWidth:image->_padw
                         height:image->_h
                       metaData:nil];
         [copy release];

         // Remember the writer's name
         [[NSUserDefaults standardUserDefaults] 
          setObject:[writerClass writerName]
          forKey:K_PREFERED_IMAGE_WRITER];

         // Revert the cursor to its normal state when we finished saving
         [NSCursor pop];
      }
   }
}

- (LynkeosImageBuffer*) loadImage
{
   LynkeosImageBuffer *image = nil;
   NSOpenPanel* panel = [NSOpenPanel openPanel];
   NSDictionary *fileTypes =
   [[MyPluginsController defaultPluginController] getImageReaders];
   NSArray *files;

   [panel setAllowedFileTypes:[fileTypes allKeys]];
   if ( [panel runModal] == NSFileHandlingPanelOKButton )
   {
      files = [panel URLs];

      if ( [files count] != 0 )
      {
         NSURL *url = [files objectAtIndex:0];

         // Find the reader class which declares this file type, 
         // and accepts to open this file
         NSMutableArray *readers = [NSMutableArray array];
         NSEnumerator *list;
         LynkeosReaderRegistry *item;
         id <LynkeosImageFileReader> reader = nil;

         NSString *ext = [[[url path] pathExtension] lowercaseString];

         [readers addObjectsFromArray:[fileTypes objectForKey:ext]];
#if !defined GNUSTEP
         [readers addObjectsFromArray:[fileTypes objectForKey:
                                       NSHFSTypeOfFile([url path])]];
#endif

         // Try the readers until one accepts
         list = [readers objectEnumerator];
         while( (item = [list nextObject]) != nil )
         {
            if ( (reader = [[[item->reader alloc] initWithURL:url] autorelease])
                 != nil )
               // Found it
               break;
         }

         if ( reader != nil )
         {
            u_short w, h, n;
            [reader imageWidth:&w height:&h];
            n = [reader numberOfPlanes];
            image = [[[LynkeosImageBuffer alloc] initWithNumberOfPlanes:n
                                                             width:w
                                                            height:h] autorelease];
            [reader getImageSample:[image colorPlanes]
                        withPlanes:n atX:0 Y:0 W:w H:h lineWidth:image->_padw];
         }
         else
            // Bad luck
            NSLog( @"Unable to load file %@", [url absoluteString] );
      }
   }

   return( image );
}

#pragma mark = Processing views management
- (void) activateProcessingView: (id) sender
{
   NSInteger tag = [sender tag];
   NSArray *procList = [[MyPluginsController defaultPluginController] getProcessingViews];

   // Ignore activation if the process is not authorized
   const unsigned int mask = ProcessingViewAuthorized|_listMode;   
   if ( _isProcessing || (_processingAuthorization[tag] & mask) != mask )
   {
      // Reset the selection
      NSAssert( _processingViewReg != nil, @"Current process view has no registry" );
      NSMutableString *curIdent = [NSMutableString stringWithString:toolbarProcPrefix];
      [curIdent appendString: [_processingViewReg->controller className]];
      if ( _processingViewReg->ident != nil )
         [curIdent appendString:_processingViewReg->ident];
      [_toolBar setSelectedItemIdentifier:curIdent];
      return;
   }

   // Switch data mode if the current one is not compatible with the process
   if ( (_processingAuthorization[tag] & _dataMode) == 0 )
      [(MyDocument*)[self document] setDataMode: (_dataMode == ListData ? ResultData : ListData)];

   // Retrieve the controller
   LynkeosProcessingViewRegistry *reg = [procList objectAtIndex:tag];
   NSAssert( reg != nil, @"Could not find process view registry" );

   if ( _processingViewReg != nil && _processingViewReg == reg )
      // The selection did not change
      return;

   // And get the cached view controller, if any
   NSMutableString *procIdent = [NSMutableString stringWithString:toolbarProcPrefix];
   [procIdent appendString:[reg->controller className]];
   if ( reg->ident != nil )
      [procIdent appendString:reg->ident];
   MyProcessViewDefinition *def = [_processingViewDict objectForKey:procIdent];

   if ( def == nil )
   {
      // Allocate a new controller as it was not in the cache
      def = [[[MyProcessViewDefinition alloc] init] autorelease];

      def->_viewController =
               [[reg->controller alloc] initWithWindowController:self
                                                        document:[self document]
                                                   configuration:reg->config];
      def->_view = [def->_viewController getProcessingView];
      def->_currentFrame = [def->_viewController preferredDisplay];
      def->_processIndex = tag;
      def->_menuItem = [_processMenu itemWithTag: tag];
      def->_title = [[NSString stringWithString:[def->_menuItem title]] retain];

      [_processingViewDict setObject:def forKey:procIdent];
   }

   // Uncheck the previous process in the menu
   if ( _processingViewController != nil )
   {
      [_processingViewController setActiveView:NO];
      NSMenuItem *oldItem = [_processMenu itemWithTag:[procList indexOfObject: _processingViewReg]];
      [oldItem setState: NSOffState];
   }

   // Clean up any selections left by the previous controller, if any
   [_imageView removeAllSelections];
   [_imageView setSelectionMode:NoSelection];

   // Change the name of the separate window to reflect the new process
   [_processWindow setTitle: def->_title];

   // Note if we shall display the progress
   if ( [reg->controller respondsToSelector:@selector(hasProgressIndicator)]
        && [reg->controller hasProgressIndicator] )
      _displayProgress = NO;
   else
      _displayProgress = YES;

   [self setProcessView: def->_view withDisplay: def->_currentFrame];

   [def->_viewController setActiveView: YES];
   [[self window] makeFirstResponder: def->_view];

   _processingViewController = def->_viewController;
   _processingViewReg = reg;
   _processingViewDef = def;
   _authorizedProcessDisplays = [reg->controller allowedDisplaysForConfig: reg->config];
   [self validateSplitControls];

   // Set the selections
   if ( ![sender isMemberOfClass: [NSToolbarItem class]] )
      [_toolBar setSelectedItemIdentifier: procIdent];

   [[_processMenu itemWithTag:tag] setState: NSOnState];
}

#pragma mark = NIB Actions
- (void) highlightNext :(id)sender
{
   [self highlightOther:K_DOWN skipUnselected:YES];
}

- (void) highlightPrevious :(id)sender
{
   [self highlightOther:K_UP skipUnselected:YES];
}

// Buttons or menu actions
- (void) modeMenuAction :(id)sender
{
   _highlightedItem = nil; // Hilight may be inconsistent until notified back
   [(MyDocument*)[self document] setListMode:(int)[sender selectedTag]];
}

- (IBAction) dataModeAction :(id)sender
{
   _highlightedItem = nil; // Hilight may be inconsistent until notified back
   [(MyDocument*)[self document] setDataMode:(int)[sender selectedTag]];
}

- (void) addAction :(id)sender
{
   // Ask the user to choose some images/movies
   NSOpenPanel* panel = [NSOpenPanel openPanel];
   NSArray *URLs;

   [panel setAllowedFileTypes:[MyImageListItem imageListItemFileTypes]];
   [panel setAllowsMultipleSelection:YES];
   if ( [panel runModal] == NSFileHandlingPanelOKButton )
   {
      URLs = [panel URLs];

      // And add their objects to the document
      [self addURLs:URLs];
   }
}

- (void) delete:(id)sender
{
   NSInteger sel = [_textView selectedRow];
   id item = [_textView itemAtRow:sel];

   [(MyDocument*)[self document] deleteEntry:item];
}

- (void) addURLs :(NSArray*)URLs
{
   NSEnumerator* list;
   NSURL *url;

   // Set the watch cursor
   [[self window] disableCursorRects];
   [myWatchCursor push];

   // Add their objects to the document
   list = [URLs objectEnumerator];
   while ( (url = [list nextObject]) != nil )
   {
      MyImageListItem *item;

      item = [MyImageListItem imageListItemWithURL: url];

      if ( item != nil )
      {
         [item setMode:_listMode];
         [(MyDocument*)[self document] addEntry: item];
      }
      else
         NSRunAlertPanel(NSLocalizedString(@"BadFileTitle",
                                          @"Bad format file alert panel title"),
                         NSLocalizedString(@"BadFile",
                                          @"Message of bad file alert message"),
                         nil, nil, nil, [url absoluteString] );
   }

   // Revert the cursor to its normal state when we finished adding
   [NSCursor pop];
   [[self window] enableCursorRects];
}

- (void) reloadData
{
   [_textView reloadData];
}

- (void) reloadItem:(id<LynkeosProcessableItem>)item
{
   [_textView reloadItem:item reloadChildren:YES];
}

- (void) toggleEntrySelection :(id)sender
{
   if( _highlightedItem != nil )
      [(MyDocument*)[self document] changeEntrySelection :_highlightedItem
                     value:([_highlightedItem getSelectionState] != NSOnState)];
}

- (void) fileWritersPopupAction : (id)sender
{
   Class writer = [_currentWriters objectAtIndex:[sender indexOfSelectedItem]];
   [_savePanel setAllowedFileTypes:[NSArray arrayWithObject:[writer fileExtension]]];
}

- (IBAction) hideImageMargin:(id)sender
{
   NSAssert1( _currentProcessDisplay != SeparateView_NoList,
             @"Hide margin pressed in display mode %d", _currentProcessDisplay );

   [self setProcessView:_processingView withDisplay:SeparateView_NoList];
   _processingViewDef->_currentFrame = SeparateView_NoList;
}

- (IBAction) shareMargin:(id)sender
{
   NSAssert1( _currentProcessDisplay == BottomTab_NoList
              || _currentProcessDisplay == SeparateView,
              @"Hide margin pressed in display mode %d",
              _currentProcessDisplay );

   [self setProcessView:_processingView withDisplay:BottomTab];
   _processingViewDef->_currentFrame = BottomTab;
}

- (void) showHideImageList:(id)sender
{
   LynkeosProcessingViewFrame_t display;

   switch( _currentProcessDisplay )
   {
      case BottomTab:            display = BottomTab_NoList; break;
      case BottomTab_NoList:     display = BottomTab; break;
      case SeparateView:         display = SeparateView_NoList; break;
      case SeparateView_NoList:  display = SeparateView; break;
      default:
         NSAssert( NO, @"Invalid process display state" );
   }

   [self setProcessView:_processingView withDisplay:display];
   _processingViewDef->_currentFrame = display;
}

- (void) attachDetachProcessView:(id)sender
{
   LynkeosProcessingViewFrame_t display;

   switch( _currentProcessDisplay )
   {
      case BottomTab:            display = SeparateView; break;
      case BottomTab_NoList:     display = SeparateView_NoList; break;
      case SeparateView:         display = BottomTab; break;
      case SeparateView_NoList:  display = BottomTab_NoList; break;
      default:
         NSAssert( NO, @"Invalid process display state" );
   }

   [self setProcessView:_processingView withDisplay:display];
   _processingViewDef->_currentFrame = display;
}

- (void) saveStackedImage :(id)sender
{
   id <LynkeosProcessableItem> item = nil;
   LynkeosImageBuffer *img;

   // Get the active item
   switch ( _dataMode )
   {
       case ListData:
          if ( _highlightedItem != nil
              && [_highlightedItem numberOfChildren] == 0 )
             item = _highlightedItem;
          break;
       case ResultData: item = _currentList; break;
       default: NSAssert1( NO, @"Invalid data mode %d", _dataMode );
   }

   NSAssert( item != nil, @"Attempt to save a nil item" );

   // Retrieve the image
   img = [item getImage];
   NSAssert( img != nil, @"Attempt to save a nil image" );
   const u_short nPlanes = [item numberOfPlanes];
   double black[nPlanes+1], white[nPlanes+1], gamma[nPlanes+1];
   u_short i;

   [item getBlackLevel:&black[nPlanes] whiteLevel:&white[nPlanes]
                 gamma:&gamma[nPlanes]];
   for( i = 0; i < nPlanes; i++ )
      [item getBlackLevel:&black[i] whiteLevel:&white[i] gamma:&gamma[i]
                 forPlane:i];

   // Save it
   [self saveImage:img withBlack:black white:white gamma:gamma];
}

- (void) exportMovie :(id)sender
{
}

@end
