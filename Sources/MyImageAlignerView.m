//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Wed Nov 11 2006.
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

#include <math.h>

#include "MyUserPrefsController.h"
#include "LynkeosColumnDescriptor.h"
#include "MyImageListItem.h"
#include "MyImageAligner.h"
#include "MyImageAlignerPrefs.h"
#include "MyImageAlignerView.h"

static NSMutableDictionary *monitorDictionary = nil;

/*!
 * @abstract Lightweight object for validating and redraw
 * @discussion This object monitors the document for validating the process
 *    activation, and the window controller for drawing the outline view cells
 * @ingroup Processing
 */
@interface MyImageAlignerMonitor : NSObject
{
   NSObject <LynkeosViewDocument>      *_document; //!< Our document
   NSObject <LynkeosWindowController>  *_window;   //!< Our window controller
}

/*!
 * @abstract Process the notification of a new document creation
 * @discussion It will be used to create a monitor object for the document.
 * @param notif The notification
 */
+ (void) documentDidOpen:(NSNotification*)notif;
/*!
 * @abstract Process the notification of document closing
 * @param notif The notification
 */
+ (void) documentWillClose:(NSNotification*)notif;

/*!
 * @abstract Dedicated initializer
 * @param document The document to monitor
 * @param window The window controller to monitor
 * @result Initialized 
 */
- (id) initWithDocument:(NSObject <LynkeosViewDocument>*)document
       windowController:(NSObject <LynkeosWindowController> *)window;
/*!
 * @abstract The document current list was changed
 * @param notif The notification
 */
- (void) changeOfList:(NSNotification*)notif;
/*!
 * @abstract Process the display of aligned items
 * @param notif The notification
 */
- (void) textViewWillDisplayCell:(NSNotification*)notif;
@end

@implementation MyImageAlignerMonitor
+ (void) documentDidOpen:(NSNotification*)notif
{
   id <LynkeosViewDocument> document = [notif object];
   id <LynkeosWindowController> windowCtrl =
                [[notif userInfo] objectForKey:LynkeosUserinfoWindowController];

   // Create a monitor object for this document
   [monitorDictionary setObject:
      [[[MyImageAlignerMonitor alloc] initWithDocument:document
                                      windowController:windowCtrl] autorelease]
                         forKey:[NSData dataWithBytes:&document
                                               length:sizeof(id)]];
}

+ (void) documentWillClose:(NSNotification*)notif
{
   id <LynkeosViewDocument> document = [notif object];

   // Delete the monitor object
   [monitorDictionary removeObjectForKey:[NSData dataWithBytes:&document
                                                        length:sizeof(id)]];
}

- (id) initWithDocument:(NSObject <LynkeosViewDocument>*)document
       windowController:(NSObject <LynkeosWindowController> *)window
{
   if ( (self = [self init]) != nil )
   {
      _document = document;
      _window = window;

      NSNotificationCenter *notif = [NSNotificationCenter defaultCenter];

      // Register for outline view redraw
      [notif addObserver:self
                selector:@selector(textViewWillDisplayCell:)
                    name:LynkeosOutlineViewWillDisplayCellNotification
                  object:_window];

      // Register for list change notifications
      [notif addObserver:self
                selector:@selector(changeOfList:)
                    name: LynkeosItemAddedNotification
                  object:_document];
      [notif addObserver:self
                selector:@selector(changeOfList:)
                    name: LynkeosItemRemovedNotification
                  object:_document];

      // And set initial authorization
      [self changeOfList:nil];
   }

   return( self );
}

- (void) dealloc
{
   // Unregister for all notifications
   [[NSNotificationCenter defaultCenter] removeObserver:self];

   [super dealloc];
}

- (void) textViewWillDisplayCell:(NSNotification*)notif
{
   NSDictionary *dict = [notif userInfo];
   NSString* column = [[dict objectForKey:LynkeosOutlineViewColumn]  identifier];
   id <LynkeosProcessable> item = [dict objectForKey:LynkeosOutlineViewItem];
   id cell = [dict objectForKey:LynkeosOutlineViewCell];

   if ( [column isEqual:@"index"] || [column isEqual:@"name"] )
   {
      NSColor *color;
      if ( [item getProcessingParameterWithRef:LynkeosAlignResultRef
                                 forProcessing:LynkeosAlignRef] != nil )
         color = [NSColor greenColor];
      else
         color = [NSColor textColor];
      [cell setTextColor:color];
   }
}

- (void) changeOfList:(NSNotification*)notif
{
   [_window setProcessing:[MyImageAlignerView class] andIdent:nil
            authorization:([[[_document imageList] imageArray] count] != 0)];
}
@end

@interface MyImageAlignerView(Private)
- (void) highlightChange:(NSNotification*)notif ;
- (void) selectionRectChanged:(NSNotification*)notif ;
- (void) selectionRectDeleted:(NSNotification*)notif ;
- (void) processStarted:(NSNotification*)notif ;
- (void) processEnded:(NSNotification*)notif ;
- (void) itemChanged:(NSNotification*)notif ;
- (void) listModified:(NSNotification*)notif ;
@end

@implementation MyImageAlignerView(Private)

- (void) highlightChange:(NSNotification*)notif
{
   if ( _isAligning && ! _imageUpdate )
      return;

   id <LynkeosProcessableItem> item = [_window highlightedItem];
   BOOL privateSquare = NO;
   NSArray *selections = nil;

   [_imageView displayItem:item];

   if ( !_isAligning )
   {
      MyImageAlignerListParametersV3 *params;

      if ( item != nil )
      {
         MyImageAlignerListParametersV3 *listParam
            = [_list getProcessingParameterWithRef:myImageAlignerParametersRef
                                     forProcessing:myImageAlignerRef];
         params =[item getProcessingParameterWithRef:myImageAlignerParametersRef
                                       forProcessing:myImageAlignerRef];
         NSAssert( params != nil, @"No alignment parameters found" );

         _numberOfSquares = [listParam->_alignSquares count];
         selections = itemAlignSquares(item, listParam);

         [_squaresTable reloadData];

         [_refCheckBox setState:
            (item==params->_referenceItem ? NSOnState : NSOffState)];
         [_refCheckBox setEnabled:YES];

         BOOL privateSquare = [params isMemberOfClass:
                                 [MyImageAlignerImageParametersV3 class]];
         [_privateSearch setState:(privateSquare ? NSOnState : NSOffState)];
         [_privateSearch setEnabled:YES];

         id <LynkeosAlignResult> align = (id <LynkeosAlignResult>)
                       [item getProcessingParameterWithRef:LynkeosAlignResultRef
                                             forProcessing:LynkeosAlignRef
                                                      goUp:NO];
         [_cancelButton setEnabled:(align != nil)];
      }
      else
      {
         [_refCheckBox setIntValue:NSOffState];
         [_refCheckBox setEnabled:NO];
         [_privateSearch setEnabled:NO];
         [_cancelButton setEnabled:YES];
      }

      // Display the selection rectangles, if there is an image for them
      if ( item != nil && [(MyImageListItem*)item numberOfChildren] == 0 )
      {
         NSEnumerator *selectionList = [selections objectEnumerator];
         NSUInteger i = 0, currentIndex = [_imageView activeSelectionIndex];
         MyImageAlignerSquareV3 *square, *currentSquare = nil;
         LynkeosIntegerRect selRect;

#warning Specific rectangles must be displayed with the alignment result taken into account
#warning In which case the "selection changed" notification have to take it into account
         // Set the selection rects
         while ( (square = [selectionList nextObject]) != nil )
         {
               selRect.origin = square->_alignOrigin;
               selRect.size = square->_alignSize;

               [_imageView setSelection:selRect
                                atIndex:i
                              resizable:!privateSquare
                                movable:YES];
            if ( i == currentIndex )
               currentSquare = square;
            i++;
         }

         // Remove excess selection squares
         const NSUInteger nSel = [selections count];
         while ([_imageView numberOfSelections] > nSel)
            [_imageView removeSelectionAtIndex:nSel];

         // Set the current selection last
         if ( currentSquare != nil )
         {
            selRect.origin = currentSquare->_alignOrigin;
            selRect.size = currentSquare->_alignSize;

            [_imageView setSelection:selRect
                             atIndex:currentIndex
                           resizable:!privateSquare
                             movable:YES];
         }
      }
   }
}

- (void) selectionRectChanged:(NSNotification*)notif
{
   NSAssert( !_isAligning, @"Search rect changed while aligning" );

   NSUInteger index = [[[notif userInfo] objectForKey:LynkeosImageViewSelectionRectIndex] integerValue];
   LynkeosIntegerRect r = [_imageView getSelectionAtIndex:index];
   id <LynkeosProcessableItem> item = [_window highlightedItem];
   NSAssert(item != nil, @"No item for selection change");
   MyImageAlignerListParametersV3 *params =
                 [item getProcessingParameterWithRef:myImageAlignerParametersRef
                                       forProcessing:myImageAlignerRef];
   const NSUInteger nSquares = [params->_alignSquares count];

   NSAssert( params != nil, @"Update of inexistent alignment parameters" );

   // Update the parameters, if needed
   if ( ![params isMemberOfClass:[MyImageAlignerImageParametersV3 class]]
        && ([_imageView getModifiers] & NSAlternateKeyMask) == 0 )
   {
      // Regular update, in the document
      MyImageAlignerSquareV3 *square;
      LynkeosIntegerRect oldSquare = {{0,0}, {0,0}};

      NSAssert( index <= nSquares, @"Selection update overflow %lu > %lu",
                (unsigned long)index, (unsigned long)nSquares );

      if ( index < nSquares )
      {
         square = [params->_alignSquares objectAtIndex:index];
         oldSquare.origin = square->_alignOrigin;
         oldSquare.size = square->_alignSize;

         square->_alignOrigin = r.origin;
         square->_alignSize = r.size;
      }
      else
      {
         square = [[[MyImageAlignerSquareV3 alloc] init] autorelease];

         square->_alignOrigin = r.origin;
         square->_alignSize = r.size;

         [params->_alignSquares addObject:square];
      }

      // Save the parameter only if selection did actually change (or it may generate a notification loop)
      if (r.origin.x != oldSquare.origin.x || r.origin.y != oldSquare.origin.y
          || r.size.width != oldSquare.size.width || r.size.height != oldSquare.size.height)
         [_list setProcessingParameter:params
                               withRef:myImageAlignerParametersRef
                         forProcessing:myImageAlignerRef];
   }
   else
   {
      // Item update
      MyImageAlignerImageParametersV3 *imageParams;
      BOOL selectionChanged = YES;

      if ( [params isMemberOfClass:[MyImageAlignerImageParametersV3 class]] )
      {
         imageParams = (MyImageAlignerImageParametersV3*)params;
         LynkeosIntegerPoint oldOrigin
            = ((MyImageAlignerOriginV3*)[imageParams->_alignSquares objectAtIndex:index])->_alignOrigin;
         selectionChanged = (r.origin.x != oldOrigin.x || r.origin.y != oldOrigin.y);
      }
      else
      {
         // Create an item param, and fill it with NSNull
         NSUInteger i;
         imageParams = [[[MyImageAlignerImageParametersV3 alloc] init] autorelease];
         for ( i = 0; i < nSquares; i++ )
            [imageParams->_alignSquares addObject:[NSNull null]];
      }

      // Update the parameter if selection actually changed (or it may cause a notification loop)
      if (selectionChanged)
      {
         // Fill in the new origin
         MyImageAlignerOriginV3 *origin = [[[MyImageAlignerOriginV3 alloc] init] autorelease];
         origin->_alignOrigin = r.origin;
         [imageParams->_alignSquares replaceObjectAtIndex:index withObject:origin];

         [item setProcessingParameter:imageParams
                              withRef:myImageAlignerParametersRef
                        forProcessing:myImageAlignerRef];
      }
   }

   [_squaresTable selectRowIndexes:[NSIndexSet indexSetWithIndex:index]
              byExtendingSelection:NO];
}

- (void) selectionRectDeleted:(NSNotification*)notif
{
   NSAssert( !_isAligning, @"Search rect deleted while aligning" );

   MyImageAlignerListParametersV3 *listParam
      = [_list getProcessingParameterWithRef:myImageAlignerParametersRef
                               forProcessing:myImageAlignerRef];
   NSRange range = [(NSValue*)[[notif userInfo] objectForKey:
                                                 LynkeosImageViewSelectionRange]
                               rangeValue];
   NSEnumerator *imageList;
   id <LynkeosProcessableItem> item;
   MyImageAlignerImageParametersV3 *param;
   NSUInteger i;

   for ( i = range.location; i < range.location + range.length; i++ )
   {
      // Delete the square in the list parameter
      [listParam->_alignSquares removeObjectAtIndex:i];

      // Delete the square in all image specific parameters
      imageList = [_list imageEnumeratorStartAt:nil
                                    directSense:YES
                                 skipUnselected:NO];

      while ( (item = [imageList nextObject]) != nil )
      {
         param = [item getProcessingParameterWithRef:myImageAlignerParametersRef
                                        forProcessing:myImageAlignerRef];

         if ( [param isMemberOfClass:[MyImageAlignerImageParametersV3 class]] )
         {
            [param->_alignSquares removeObjectAtIndex:i];

            [item setProcessingParameter:param
                                 withRef:myImageAlignerParametersRef
                           forProcessing:myImageAlignerRef];
         }
      }
   }

   // Store the modified parameters back, for notifications
   [_list setProcessingParameter:listParam
                         withRef:myImageAlignerParametersRef
                   forProcessing:myImageAlignerRef];

   imageList = [_list imageEnumeratorStartAt:nil
                                 directSense:YES
                              skipUnselected:NO];
   while ( (item = [imageList nextObject]) != nil )
   {
      param = [item getProcessingParameterWithRef:myImageAlignerParametersRef
                                     forProcessing:myImageAlignerRef];

      if ( [param isMemberOfClass:[MyImageAlignerImageParametersV3 class]] )
      {
         [item setProcessingParameter:param
                               withRef:myImageAlignerParametersRef
                         forProcessing:myImageAlignerRef];
      }
   }
}

- (void) processStarted:(NSNotification*)notif
{
   // Change the button title
   [_alignButton setTitle:NSLocalizedString(@"Stop",@"Stop button")];
   [_alignButton setEnabled:YES];
   _isAligning = YES;
   _numberOfSquares = 0;
}

- (void) processEnded:(NSNotification*)notif
{
   // Change the button title
   [_alignButton setTitle:NSLocalizedString(@"Align",@"Align tool")];
   [_alignButton setEnabled:YES];

   // Allow modification of the selections
   [_imageView freezeSelections:NO];

   // Reset the hilight
   MyImageAlignerListParametersV3 *params =
      [_list getProcessingParameterWithRef:myImageAlignerParametersRef
                             forProcessing:myImageAlignerRef];
   [_window highlightItem:(MyImageListItem*)params->_referenceItem];

   // Register again for notifications
   [[NSNotificationCenter defaultCenter] addObserver:self
                   selector:@selector(selectionRectChanged:)
                       name:LynkeosImageViewSelectionRectDidChangeNotification
                     object:_imageView];
   [[NSNotificationCenter defaultCenter] addObserver:self
                       selector:@selector(selectionRectDeleted:)
                           name:LynkeosImageViewSelectionWasDeletedNotification
                         object:_imageView];

   // Enable all other controls
   _isAligning = NO;
   [self highlightChange:nil];

   // Clean up parameters
   [params->_squaresData removeAllObjects];
}

- (void) itemChanged:(NSNotification*)notif
{
   if ( _isAligning )
   {
      MyImageListItem *item =
                            [[notif userInfo] objectForKey:LynkeosUserInfoItem];
      if ( item != nil )
         [_window highlightItem:item];
   }
   else
   {
      id <LynkeosProcessableItem> curItem = [_window highlightedItem];
      id <LynkeosProcessableItem> item =
                            [[notif userInfo] objectForKey:LynkeosUserInfoItem];
      MyImageAlignerListParametersV3 *listParams
         = [_list getProcessingParameterWithRef:myImageAlignerParametersRef
                                  forProcessing:myImageAlignerRef];
      MyImageAlignerImageParametersV3 *param
         = [item getProcessingParameterWithRef:myImageAlignerParametersRef
                                  forProcessing:myImageAlignerRef];
      const BOOL privateSquare
         = [param isMemberOfClass:[MyImageAlignerImageParametersV3 class]];
      NSArray *squares = itemAlignSquares( item, listParams );
      const NSUInteger nSquares = [squares count];

      NSAssert( listParams != nil, @"Update of align item without parameters" );

      [_alignButton setEnabled:(nSquares != 0)];

      // Allow to compute rotation and scaling when the number of selection
      // reaches 2
      if ( nSquares < 2 )
      {
         listParams->_computeRotation = NO;
         listParams->_computeScale = NO;
      }
      else if ( _numberOfSquares < 2 )
      {
         // We crossed the 2 squares limit
         listParams->_computeRotation = YES;
         listParams->_computeScale = YES;
      }
      _numberOfSquares = nSquares;

      [_rotateButton setState:
                       (listParams->_computeRotation ? NSOnState : NSOffState)];
      [_rotateButton setEnabled:(nSquares > 1)];
      [_scaleButton setState:
                          (listParams->_computeScale ? NSOnState : NSOffState)];
      [_scaleButton setEnabled:(nSquares > 1)];

      [_squaresTable reloadData];

      // Make reference item coherent if needed
      if ( [(MyImageListItem*)listParams->_referenceItem getSelectionState] !=
                                                                     NSOnState )
         listParams->_referenceItem = [_list firstItem];

      // And update the reference checkbox
      int state
         = (curItem == listParams->_referenceItem ? NSOnState : NSOffState);
      if ( [_refCheckBox state] != state )
         [_refCheckBox setState:state];

      [_privateSearch setIntValue:(privateSquare ? NSOnState : NSOffState)];

      NSEnumerator *squaresList = [squares objectEnumerator];
      MyImageAlignerSquareV3 *square;
      SelectionIndex_t i = 0;
      while ( (square = [squaresList nextObject]) != nil )
      {
         // Update the selection in the image view if needed
         LynkeosIntegerRect r = {{0,0},{0,0}};
         if (i < [_imageView numberOfSelections])
            r = [_imageView getSelectionAtIndex:i];

         if ( r.origin.x != square->_alignOrigin.x ||
              r.origin.y != square->_alignOrigin.y ||
              r.size.width != square->_alignSize.width ||
              r.size.height != square->_alignSize.height )
         {
            r.origin = square->_alignOrigin;
            r.size = square->_alignSize;
            [_imageView setSelection:r atIndex:i
                           resizable:!privateSquare movable:YES];
         }
         i++;
      }
      // Remove excess selection squares
      while ([_imageView numberOfSelections] > nSquares)
         [_imageView removeSelectionAtIndex:nSquares];
   }
}

- (void) listModified:(NSNotification*)notif
{
   MyImageAlignerListParametersV3 *params =
            [_list getProcessingParameterWithRef:myImageAlignerParametersRef
                                       forProcessing:myImageAlignerRef];
   id <LynkeosProcessableItem> ref = nil;

   NSAssert( params != nil, @"Update without parameter" );

   // Modify the list of allowed values in the size popup
   NSEnumerator* list;
   MyImageListItem* item;
   long limit = -1;
   int side;

   // Check the minimum size from the list (and try to find the reference)
   if ( _list != nil )
   {
      ref = [_list firstItem];

      list = [[_list imageArray] objectEnumerator];
      while ( (item = [list nextObject]) != nil )
      {
         LynkeosIntegerSize size = [item imageSize];
         if ( size.width < limit || limit < 0 )
            limit = size.width;
         if ( size.height < limit )
            limit = size.height;

         if ( item == params->_referenceItem ||
              ( [item numberOfChildren] != 0 &&
                [item indexOfItem:
                     (MyImageListItem*)params->_referenceItem] != NSNotFound ) )
            ref = params->_referenceItem;
      }
   }

   // Optimization : reconstruct only on size change
   if (    (unsigned)limit <= _sideMenuLimit/2
        || (unsigned)limit >= _sideMenuLimit*2 )
   {
      [_sizeField removeAllItems];
      for ( side = 16; side <= limit; side *= 2 )
      {
         NSNumber* label = [NSNumber numberWithInt:side];
         [_sizeField addItemWithObjectValue:label];
      }
      _sideMenuLimit = side/2;

      //[_searchSideMenu setEnabled:(_sideMenuLimit > 0)];

      [_alignButton setEnabled:([params->_alignSquares count] != 0)];
   }

   // Update reference item if needed
   if ( params->_referenceItem != ref )
   {
      params->_referenceItem = ref;
      [_list setProcessingParameter:params
                            withRef:myImageAlignerParametersRef
                      forProcessing:myImageAlignerRef];
   }
}
@end

@implementation MyImageAlignerView

+ (void) initialize
{
   // Register the monitor for document notifications
   NSNotificationCenter *notif = [NSNotificationCenter defaultCenter];

   monitorDictionary = [[NSMutableDictionary alloc] initWithCapacity:1];

   [notif addObserver:[MyImageAlignerMonitor class]
             selector:@selector(documentDidOpen:)
                 name:LynkeosDocumentDidOpenNotification
               object:nil];
   [notif addObserver:[MyImageAlignerMonitor class]
             selector:@selector(documentWillClose:)
                 name:LynkeosDocumentWillCloseNotification
               object:nil];

   // Register the result as displayable in a column
   [[LynkeosColumnDescriptor defaultColumnDescriptor] registerColumn:@"dx"
                                                     forProcess:LynkeosAlignRef
                                                parameter:LynkeosAlignResultRef
                                                          field:@"dx"
                                                         format:@"%.1f"];
   [[LynkeosColumnDescriptor defaultColumnDescriptor] registerColumn:@"dy"
                                                     forProcess:LynkeosAlignRef
                                                parameter:LynkeosAlignResultRef
                                                          field:@"dy"
                                                         format:@"%.1f"];
   [[LynkeosColumnDescriptor defaultColumnDescriptor] registerColumn:@"rotation"
                                                          forProcess:LynkeosAlignRef
                                                           parameter:LynkeosAlignResultRef
                                                               field:@"rotation"
                                                              format:@"%.1f"];
   [[LynkeosColumnDescriptor defaultColumnDescriptor] registerColumn:@"scale"
                                                          forProcess:LynkeosAlignRef
                                                           parameter:LynkeosAlignResultRef
                                                               field:@"scale"
                                                              format:@"%.1f"];
}

+ (BOOL) isStandardProcessingViewController { return(YES); }

+ (ProcessingViewKind_t) processingViewKindForConfig:(id <NSObject>)config
{
   NSAssert( config == nil, @"Image aligner does not support configuration" );
   return(ListProcessingKind);
}

+ (BOOL) isViewControllingProcess:(Class)processingClass
                       withConfig:(id <NSObject>*)config
{
   *config = nil;
   return( NO );
}

+ (void) getProcessingTitle:(NSString**)title
                  toolTitle:(NSString**)toolTitle
                        key:(NSString**)key
                       icon:(NSImage**)icon
                        tip:(NSString**)tip
                  forConfig:(id <NSObject>)config
{
   NSAssert( config == nil, @"Image aligner does not support configuration" );
   *title = NSLocalizedString(@"Align",@"Align tool");
   *toolTitle = NSLocalizedString(@"Align",@"Align tool");
   *key = @"a";
   *icon = [NSImage imageNamed:@"Align"];
   *tip = NSLocalizedString(@"AlignTip",@"Align tooltip");;
}

+ (unsigned int) allowedDisplaysForConfig:(id <NSObject>)config
{
   NSAssert( config == nil, @"Image aligner does not support configuration" );
   return( BottomTab|SeparateView );
}

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _document = nil;
      _list = nil;
      _imageView = nil;
      _numberOfSquares = 0;
      _sideMenuLimit = -1;
      _isAligning = NO;

      // Prepare the table view cells
      _modifyButton = [[NSButtonCell alloc] initTextCell:@""];
      [_modifyButton setButtonType: NSMomentaryPushInButton];
      [_modifyButton setBezelStyle:NSCircularBezelStyle];
      [_modifyButton setControlSize:NSSmallControlSize];

      _xField = [[NSTextFieldCell alloc] init];
      NSNumberFormatter *xFormat = [[NSNumberFormatter alloc] init];
      [xFormat setFormatterBehavior:NSNumberFormatterBehavior10_4];
      [xFormat setAllowsFloats:NO];
      [xFormat setMinimum:[NSNumber numberWithInt:0]];
      [_xField setFormatter:xFormat];
      [_xField setEditable:YES];

      _yField = [[NSTextFieldCell alloc] init];
      NSNumberFormatter *yFormat = [[NSNumberFormatter alloc] init];
      [yFormat setFormatterBehavior:NSNumberFormatterBehavior10_4];
      [yFormat setAllowsFloats:NO];
      [yFormat setMinimum:[NSNumber numberWithInt:0]];
      [_yField setFormatter:yFormat];
      [_yField setEditable:YES];

      _sizeField = [[NSComboBoxCell alloc] init];
      NSNumberFormatter *sizeFormat = [[NSNumberFormatter alloc] init];
      [sizeFormat setFormatterBehavior:NSNumberFormatterBehavior10_4];
      [sizeFormat setAllowsFloats:NO];
      [sizeFormat setMinimum:[NSNumber numberWithInt:2]];
      [_sizeField setFormatter:sizeFormat];
      [_sizeField setControlSize:NSSmallControlSize];
      [_sizeField setEditable:YES];

      _emptyCell = [[NSCell alloc] initTextCell:@""];

      NSAssert([NSBundle loadNibNamed:@"MyImageAligner" owner:self],
               @"Failed to load Image Aligner NIB");
   }

   return( self );
}

- (id) initWithWindowController: (id <LynkeosWindowController>)window
                       document: (id <LynkeosViewDocument>)document
                  configuration: (id <NSObject>)config
{
   NSAssert( config == nil, @"Image aligner does not support configuration" );
   NSAssert( window != nil && document != nil,
             @"Image aligner initialized without window or document" );

   if ( (self = [self init]) != nil )
   {
      _window = window;
      _imageView = [_window getImageView];

      _document = document;
      _list = [document imageList];

      // Create the align parameters if needed
      MyImageAlignerListParametersV3 *params =
                [_list getProcessingParameterWithRef:myImageAlignerParametersRef
                                       forProcessing:myImageAlignerRef];

      if ( params == nil )
      {
         params = [[[MyImageAlignerListParametersV3 alloc] init] autorelease];

         [_list setProcessingParameter:params
                               withRef:myImageAlignerParametersRef
                         forProcessing:myImageAlignerRef];
      }
   }

   return( self );
}

- (void) dealloc
{
   [[_xField formatter] release];
   [_xField release];
   [[_yField formatter] release];
   [_yField release];
   [[_sizeField formatter] release];
   [_sizeField release];
   [_emptyCell release];

   [super dealloc];
}

- (NSView*) getProcessingView
{
   return( _panel );
}

- (Class) processingClass
{
   return( nil );
}

- (void) setActiveView:(BOOL)active
{
   NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];

   if ( active )
   {
      // Authorize the selections
      [_window setListSelectionAuthorization:NO];
      [_window setDataModeSelectionAuthorization:NO];
      [_window setItemSelectionAuthorization:YES];
      [_window setItemEditionAuthorization:YES];

      [_imageView removeAllSelections];
      [_imageView setSelectionMode:MultiSelection];

      // Become delegate for the image view
      [_imageView setSelectionDelegate:self];

      // Register for notifications
      [notifCenter addObserver:self
                     selector:@selector(highlightChange:)
                         name: LynkeosHilightedItemDidChangeNotification
                       object:_window];
      [notifCenter addObserver:self
                      selector:@selector(selectionRectChanged:)
                          name:LynkeosImageViewSelectionRectDidChangeNotification
                        object:_imageView];
      [notifCenter addObserver:self
                      selector:@selector(selectionRectDeleted:)
                          name:LynkeosImageViewSelectionWasDeletedNotification
                        object:_imageView];
      [notifCenter addObserver:self
                      selector:@selector(processStarted:)
                          name: LynkeosProcessStartedNotification
                        object:_document];
      [notifCenter addObserver:self
                      selector:@selector(processEnded:)
                          name: LynkeosProcessEndedNotification
                        object:_document];
      [notifCenter addObserver:self
                      selector:@selector(itemChanged:)
                          name: LynkeosItemChangedNotification
                        object:_document];
      [notifCenter addObserver:self
                      selector:@selector(listModified:)
                          name: LynkeosItemAddedNotification
                        object:_document];
      [notifCenter addObserver:self
                      selector:@selector(listModified:)
                          name: LynkeosItemRemovedNotification
                        object:_document];

      // Synchronize the display
      [self highlightChange:nil];
      [self listModified:nil];

      _isAligning = NO;
   }
   else
   {
      [_window setListSelectionAuthorization:YES];

      // Resign delegate for the image view
      [_imageView setSelectionDelegate:nil];

      // Stop receiving notifications
      [notifCenter removeObserver:self];
   }
}

- (LynkeosProcessingViewFrame_t) preferredDisplay { return( BottomTab ); }

- (id <LynkeosProcessingParameter>) getCurrentParameters
{
   // This is a list processing, the parameters are spread on the list
   return( nil );
}

- (IBAction) computeRotationChange :(id)sender
{
   MyImageAlignerListParametersV3 *listParams
      = [_list getProcessingParameterWithRef:myImageAlignerParametersRef
                               forProcessing:myImageAlignerRef];

   listParams->_computeRotation = ([sender state] == NSOnState);

   [_list setProcessingParameter:listParams
                         withRef:myImageAlignerParametersRef
                   forProcessing:myImageAlignerRef];
}

- (IBAction) computeScaleChange :(id)sender
{
   MyImageAlignerListParametersV3 *listParams
      = [_list getProcessingParameterWithRef:myImageAlignerParametersRef
                               forProcessing:myImageAlignerRef];

   listParams->_computeScale = ([sender state] == NSOnState);

   [_list setProcessingParameter:listParams
                         withRef:myImageAlignerParametersRef
                   forProcessing:myImageAlignerRef];
}

- (IBAction) referenceAction :(id)sender
{
   MyImageAlignerListParametersV3 *listParams =
                [_list getProcessingParameterWithRef:myImageAlignerParametersRef
                                       forProcessing:myImageAlignerRef];

   if ( [sender state] == NSOnState )
      listParams->_referenceItem = [_window highlightedItem];
   else if ( _list != nil )
      listParams->_referenceItem = [_list firstItem];
   else
      listParams->_referenceItem = nil;

   [_list setProcessingParameter:listParams
                        withRef:myImageAlignerParametersRef
                  forProcessing:myImageAlignerRef];
}

- (IBAction) specificSquareChange: (id)sender
{
   id <LynkeosProcessableItem> item = [_window highlightedItem];
   NSAssert(item != nil, @"No item for specific square");
   MyImageAlignerImageParametersV3 *params
      = [item getProcessingParameterWithRef:myImageAlignerParametersRef
                              forProcessing:myImageAlignerRef];
   MyImageAlignerListParametersV3 *listParams
      = [_list getProcessingParameterWithRef:myImageAlignerParametersRef
                               forProcessing:myImageAlignerRef];
   const NSInteger nSquares = (NSInteger)[listParams->_alignSquares count];

   if( [sender integerValue] == NSOnState )
   {
      // Make alignment square specific if it is not
      if ( ![params isMemberOfClass:[MyImageAlignerImageParametersV3 class]] )
      {
         // New specific parameter
         NSInteger i;
         params = [[[MyImageAlignerImageParametersV3 alloc] init] autorelease];
         // Fill it with NSNull objects
         for ( i = 0; i < nSquares; i++ )
            [params->_alignSquares addObject:[NSNull null]];
      }
   }
   else
   {
      // Delete specific search square if any
      params = nil;
   }

   [item setProcessingParameter:params
                        withRef:myImageAlignerParametersRef
                  forProcessing:myImageAlignerRef];
}

- (IBAction) cancelAction :(id)sender
{
   id <LynkeosProcessableItem> item = [_window highlightedItem];

   // Cancel selected alignment
   if ( item != nil )
      [item setProcessingParameter:nil
                           withRef:LynkeosAlignResultRef
                     forProcessing:LynkeosAlignRef];

   else
   {
      NSEnumerator *list = [_list imageEnumeratorStartAt:nil
                                             directSense:YES
                                          skipUnselected:NO];

      // Delete any align result in the list
      while( (item = [list nextObject]) != nil )
      {
         id <LynkeosAlignResult> res = (id <LynkeosAlignResult>)
                       [item getProcessingParameterWithRef:LynkeosAlignResultRef
                                             forProcessing:LynkeosAlignRef
                                                      goUp:NO];

         if ( res != nil )
            [item setProcessingParameter:nil withRef:LynkeosAlignResultRef
                           forProcessing:LynkeosAlignRef];
      }

      // And delete the list level align result, if any
      [_list setProcessingParameter:nil
                            withRef:LynkeosAlignResultRef
                      forProcessing:LynkeosAlignRef];
   }

   // Redisplay the modified data
   [_window reloadData];
   if (item != nil )
      [_imageView displayItem:item];
}

- (IBAction) alignAction :(id)sender
{
   MyImageAlignerListParametersV3 *listParams=
            [_list getProcessingParameterWithRef:myImageAlignerParametersRef
                                       forProcessing:myImageAlignerRef];

   [sender setEnabled:NO];

   if ( _isAligning )
      [_document stopProcess];

   else
   {
      // Disable all controls
      [_cancelButton setEnabled:NO];
      [_refCheckBox setEnabled: NO];
      [_privateSearch setEnabled:NO];
      [_rotateButton setEnabled:NO];
      [_scaleButton setEnabled:NO];

      // Stop receiving some notifications
      [[NSNotificationCenter defaultCenter] removeObserver:self
                        name:LynkeosImageViewSelectionRectDidChangeNotification
                                                    object:_imageView];
      [[NSNotificationCenter defaultCenter] removeObserver:self
                        name:LynkeosImageViewSelectionWasDeletedNotification
                                                    object:_imageView];

      // Freeze the selection rectangles
      [_imageView freezeSelections:YES];

      // Initialize the align parameters
      NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
      listParams->_cutoff =[defaults floatForKey:K_PREF_ALIGN_FREQUENCY_CUTOFF];
      listParams->_precisionThreshold = [defaults floatForKey:
                                              K_PREF_ALIGN_PRECISION_THRESHOLD];
      listParams->_checkAlignResult = [defaults boolForKey:K_PREF_ALIGN_CHECK];

      _imageUpdate = [defaults boolForKey:K_PREF_ALIGN_IMAGE_UPDATING];

      // Get an enumerator on the images
      NSEnumerator *strider = [_list imageEnumeratorStartAt:nil
                                                directSense:YES
                                             skipUnselected:YES];

      // Ask the doc to align
      [_document startProcess:[MyImageAligner class] withEnumerator:strider
                   parameters:listParams];
   }
}

#pragma mark = LynkeosImageViewDelegate

- (BOOL) validateSelection :(LynkeosIntegerRect*)selection
                    atIndex:(SelectionIndex_t)index
{
   // Adjust the size to the power of 2, 3, 5, 7 which yields the closest surface
   u_short size = adjustFFTside((u_short)sqrt((double)selection->size.width
                                              * (double)selection->size.height));
   selection->size.width = size;
   selection->size.height = size;

   return(YES);
}

#pragma mark = Table View Delegate

- (NSCell *)tableView:(NSTableView *)tableView
dataCellForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row
{
   if ( tableColumn == nil )
      return( nil );

   id columnId = [tableColumn identifier];
   MyImageAlignerListParametersV3 *listParams
      = [_list getProcessingParameterWithRef:myImageAlignerParametersRef
                               forProcessing:myImageAlignerRef];
   SelectionIndex_t nSel = [listParams->_alignSquares count];
   NSCell *modButton;
   BOOL addOnly = NO;

   // Adjust the button in the first column
   if ( nSel == 0 )
      // No selection at all, the only row is to fill the new selection
      modButton = _emptyCell;

   else
   {
      modButton = _modifyButton;
      if ( (SelectionIndex_t)row < nSel )
         // Existing selection, it's a delete button
         [_modifyButton setTitle:@"-"];

      else
      {
         // Extra line, with only an add button
         [_modifyButton setTitle:@"+"];
         addOnly = YES;
      }
   }

   if ( [columnId isEqual:@"modify"] )
      return( modButton );

   else if ( [columnId isEqual:@"x"] )
      return( addOnly ? _emptyCell : _xField );

   else if ( [columnId isEqual:@"y"] )
      return( addOnly ? _emptyCell : _yField );

   else if ( [columnId isEqual:@"size"] )
      return( addOnly ? _emptyCell : _sizeField );

   else
      return( nil );
}

- (BOOL)tableView:(NSTableView *)aTableView
shouldEditTableColumn:(NSTableColumn *)aTableColumn
              row:(NSInteger)rowIndex
{
   id columnId = [aTableColumn identifier];
   id <LynkeosProcessableItem> item = [_window highlightedItem];
   MyImageAlignerImageParametersV3 *params
      = [item getProcessingParameterWithRef:myImageAlignerParametersRef
                              forProcessing:myImageAlignerRef];

   return( !_isAligning &&
           (![params isMemberOfClass:[MyImageAlignerImageParametersV3 class]] ||
            ![columnId isEqualToString:@"size"]) );
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
   // Make the new selection active
   id <LynkeosProcessableItem> item = [_window highlightedItem];
   MyImageAlignerListParametersV3 *listParams
      = [_list getProcessingParameterWithRef:myImageAlignerParametersRef
                               forProcessing:myImageAlignerRef];
   MyImageAlignerImageParametersV3 *params
      = [item getProcessingParameterWithRef:myImageAlignerParametersRef
                              forProcessing:myImageAlignerRef];
   NSInteger index = [_squaresTable selectedRow];

   if ( index >= 0 )
   {
      if ((SelectionIndex_t)index == [_imageView activeSelectionIndex] )
         // No selection to update
         return;

      // A new line was selected, but watch out, there can be a line without
      // any selection
      if ( (NSUInteger)index < [listParams->_alignSquares count] )
      {
         MyImageAlignerSquareV3 *square
            = [itemAlignSquares(item, listParams) objectAtIndex:index];
         LynkeosIntegerRect r = {square->_alignOrigin, square->_alignSize};

         [_imageView setSelection:r atIndex:index
                        resizable:[params isMemberOfClass:
                                       [MyImageAlignerImageParametersV3 class]]
                          movable:YES];
      }
   }
   else
   {
      SelectionIndex_t idx = [_imageView activeSelectionIndex];
      // No line selected, set it to the the image active selection
      if ( idx != NSNotFound )
         [_squaresTable selectRowIndexes:
                           [NSIndexSet indexSetWithIndex:idx]
                    byExtendingSelection:NO];
   }
}

#pragma mark = Table view data source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
   MyImageAlignerListParametersV3 *listParams = nil;
   NSUInteger n;

   if ( _list != nil )
      listParams = [_list getProcessingParameterWithRef:myImageAlignerParametersRef
                                          forProcessing:myImageAlignerRef];

   if ( listParams != nil )
      n = [listParams->_alignSquares count] + 1;
   else
      n = 0;

   return( n );
}

- (id)tableView:(NSTableView *)aTableView
objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(NSInteger)rowIndex
{
   id columnId = [aTableColumn identifier];
   id <LynkeosProcessableItem> item = [_window highlightedItem];
   MyImageAlignerListParametersV3 *listParams =
                [_list getProcessingParameterWithRef:myImageAlignerParametersRef
                                       forProcessing:myImageAlignerRef];
   SelectionIndex_t nSel = [listParams->_alignSquares count];
   MyImageAlignerSquareV3 *square = nil;

   if ( nSel != 0 && rowIndex < (NSInteger)nSel )
      square = [itemAlignSquares(item, listParams) objectAtIndex:rowIndex];

   if ( [columnId isEqual:@"modify"] )
      return( nSel != 0 ? [NSNumber numberWithInt:NSOffState] : nil );

   else if ( [columnId isEqual:@"x"] )
      return( square != nil ?
             [NSNumber numberWithInt:square->_alignOrigin.x ] : nil );

   else if ( [columnId isEqual:@"y"] )
      return( square != nil ?
             [NSNumber numberWithInt:square->_alignOrigin.y] : nil );

   else if ( [columnId isEqual:@"size"] )
      return( square != nil ?
             [NSNumber numberWithInt:square->_alignSize.width] : nil);

   else
      return( nil );
}

- (void)tableView:(NSTableView *)aTableView
   setObjectValue:(id)anObject
   forTableColumn:(NSTableColumn *)aTableColumn
              row:(NSInteger)rowIndex
{
   id columnId = [aTableColumn identifier];
   id <LynkeosProcessableItem> item = [_window highlightedItem];
   NSAssert(item != nil, @"No item to change the square");
   MyImageAlignerImageParametersV3 *params =
                 [item getProcessingParameterWithRef:myImageAlignerParametersRef
                                       forProcessing:myImageAlignerRef];
   MyImageAlignerListParametersV3 *listParams =
                [_list getProcessingParameterWithRef:myImageAlignerParametersRef
                                       forProcessing:myImageAlignerRef];
   const NSInteger nSquares = (NSInteger)[listParams->_alignSquares count];
   id <LynkeosProcessable> dest;
   LynkeosIntegerRect r = {{0, 0}, {0, 0}};

   NSAssert(rowIndex <= nSquares,
            @"Selection index %ld is beyond bound %ld",
            (long)rowIndex, (long)nSquares );

   if ( rowIndex < nSquares )
   {
      MyImageAlignerSquareV3 *square
         = [itemAlignSquares(item, listParams) objectAtIndex:rowIndex];
      r.origin = square->_alignOrigin;
      r.size = square->_alignSize;
   }

   if ( [columnId isEqualToString:@"modify"] )
   {
      if ( rowIndex < nSquares )
         // This is a deletion
         [_imageView removeSelectionAtIndex:rowIndex];

      else
      {
         // This is an addition, use the same size as the last square
         MyImageAlignerSquareV3 *square
            = [[listParams->_alignSquares objectAtIndex:rowIndex-1] copy];

         square->_alignOrigin.x = 0;
         square->_alignOrigin.y = 0;

         [listParams->_alignSquares addObject:[square autorelease]];

         // Add a NSNull at the end of all items with specific squares
         NSEnumerator *items = [_list imageEnumeratorStartAt:nil
                                                 directSense:NO
                                              skipUnselected:NO];
         while ( (item = [items nextObject]) != nil )
         {
            params
               = [item getProcessingParameterWithRef:myImageAlignerParametersRef
                                       forProcessing:myImageAlignerRef];

            if ( [params isMemberOfClass:
                            [MyImageAlignerImageParametersV3 class]] )
               [params->_alignSquares addObject:[NSNull null]];
         }
      }
      // Parameter is not modified (it will be upon selection notification)
      return;
   }

   else if ( [columnId isEqualToString:@"x"] )
      r.origin.x = [anObject intValue];

   else if ( [columnId isEqualToString:@"y"] )
      r.origin.y = [anObject intValue];

   else if ( [columnId isEqualToString:@"size"] )
   {
      r.size.width = [anObject intValue];
      r.size.height = r.size.width;
   }

   else
      NSAssert( NO, @"Unexpected table view column in setObjectValue" );

   if ( params != nil &&
        [params isMemberOfClass:[MyImageAlignerImageParametersV3 class]] )
   {
      MyImageAlignerOriginV3 *o
         = [[[MyImageAlignerOriginV3 alloc] init] autorelease];

      o->_alignOrigin = r.origin;

      [params->_alignSquares replaceObjectAtIndex:rowIndex withObject:o];
   }
   else
   {
      MyImageAlignerSquareV3 *square
         = [[[MyImageAlignerSquareV3 alloc] init] autorelease];

      square->_alignOrigin = r.origin;
      square->_alignSize = r.size;

      if ( rowIndex < nSquares )
         [listParams->_alignSquares replaceObjectAtIndex:rowIndex
                                              withObject:square];
      else
         [listParams->_alignSquares addObject:square];
   }

   if ( params == nil ||
        [params isMemberOfClass:[MyImageAlignerImageParametersV3 class]] )
      dest = item;
   else
      dest = _list;
   [dest setProcessingParameter:params
                        withRef:myImageAlignerParametersRef
                  forProcessing:myImageAlignerRef];
}

@end
