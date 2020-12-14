//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Sat Jun 9 2007.
//  Copyright (c) 2007-2019. Jean-Etienne LAMIAUD
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

#include "MyImageListItem.h"
#include "LynkeosColumnDescriptor.h"
#include "MyImageAnalyzer.h"
#include "MyImageAnalyzerPrefs.h"
#include "MyImageAnalyzerView.h"

NSString * const myAutoselectParameterRef = @"AutoselectParam";

NSString * const K_SELECT_THRESHOLD_KEY = @"selectthr";

static NSMutableDictionary *monitorDictionary = nil;

/*!
 * @abstract Lightweight object for validating
 * @discussion This object monitors the document for validating the process
 *    activation
 * @ingroup Processing
 */
@interface MyImageAnalyzerMonitor : NSObject
{
   NSObject <LynkeosViewDocument>      *_document;  //!< Our document
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
@end

@implementation MyImageAnalyzerMonitor
+ (void) documentDidOpen:(NSNotification*)notif
{
   id <LynkeosViewDocument> document = [notif object];
   id <LynkeosWindowController> windowCtrl =
      [[notif userInfo] objectForKey:LynkeosUserinfoWindowController];

   // Create a monitor object for this document
   [monitorDictionary setObject:
      [[[MyImageAnalyzerMonitor alloc] initWithDocument:document
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

- (void) changeOfList:(NSNotification*)notif
{
   [_window setProcessing:[MyImageAnalyzerView class] andIdent:nil
            authorization:([[[_document imageList] imageArray] count] != 0)];
}
@end

@implementation MyAutoselectParams
- (void)encodeWithCoder:(NSCoder *)encoder
{
   [encoder encodeDouble:_qualityThreshold forKey:K_SELECT_THRESHOLD_KEY];
}

- (id)initWithCoder:(NSCoder *)decoder
{
   if ( (self = [self init]) != nil )
      _qualityThreshold = [decoder decodeDoubleForKey:K_SELECT_THRESHOLD_KEY];

   return( self );
}
@end

@interface MyImageAnalyzerView(Private)
- (void) highlightChange:(NSNotification*)notif ;
- (void) selectionRectChanged:(NSNotification*)notif ;
- (void) processStarted:(NSNotification*)notif ;
- (void) processEnded:(NSNotification*)notif ;
- (void) updateAutoselect ;
- (void) updateNumSelectedAndMinMax:(BOOL)minMax ;
- (void) itemChanged:(NSNotification*)notif ;
- (void) listModified:(NSNotification*)notif ;
@end

@implementation MyImageAnalyzerView(Private)

- (void) highlightChange:(NSNotification*)notif
{
   if ( _isAnalyzing && ! _imageUpdate )
      return;

   id <LynkeosProcessableItem> item = [_window highlightedItem];
   LynkeosIntegerRect selRect = LynkeosMakeIntegerRect(0,0,0,0);

   if ( item != nil && [item hasImage] )
   {
      // Highlight is valid
      MyImageAnalyzerParameters *params =
               [_list getProcessingParameterWithRef:myImageAnalyzerParametersRef
                                      forProcessing:myImageAnalyzerRef];
      selRect = params->_analysisRect;

      // Provide a preview of the filter, if requested
      if ( _filteredPreview )
      {
         if ( item != _unfilteredItem )
         {
            LynkeosIntegerSize imgsize = [item imageSize];
            LynkeosFourierBuffer *buf =
               [[[LynkeosFourierBuffer alloc] initWithNumberOfPlanes:1
                                                   width:imgsize.width
                                                  height:imgsize.height
                                                withGoal:FOR_DIRECT|FOR_INVERSE]
             autorelease];

            _unfilteredItem = item;
            if ( _filteredImage == nil )
               _filteredImage = [[LynkeosProcessableImage alloc] init];
            [item getImageSample:&buf
                          inRect:LynkeosMakeIntegerRect(0, 0,
                                                        imgsize.width,
                                                        imgsize.height)];
            filterImageForAnalysis(buf, params->_lowerCutoff,
                                   params->_upperCutoff);
            [_filteredImage setOriginalImage:buf];
         }
         item = _filteredImage;
      }
   }

   [_imageView displayItem:item];

   // Display the current selection
   [_imageView setSelection:selRect resizable:YES movable:YES];
}

- (void) selectionRectChanged:(NSNotification*)notif
{
   NSAssert( !_isAnalyzing, @"Analysis rect changed while analyzing" );

   LynkeosIntegerRect r = [_imageView getSelection];

   // Update the parameters
   MyImageAnalyzerParameters *params =
            [_list getProcessingParameterWithRef:myImageAnalyzerParametersRef
                                       forProcessing:myImageAnalyzerRef];

   NSAssert( params != nil, @"Update of inexistent analysis parameters" );

   params->_analysisRect = r;

   [_list setProcessingParameter:params
                             withRef:myImageAnalyzerParametersRef
                       forProcessing:myImageAnalyzerRef];
}

- (void) processStarted:(NSNotification*)notif
{
   // Change the button title
   [_analyzeButton setTitle:NSLocalizedString(@"Stop",@"Stop button")];
   [_analyzeButton setEnabled:YES];

   [_cutoffFreqSlider setEnabled:NO];
   [_lowFreqCutoffText setEnabled:NO];
   [_highFreqCutoffText setEnabled:NO];
   [_previewButton setState:NSOffState];
   [_previewButton setEnabled:NO];
   _filteredPreview = NO;

   _isAnalyzing = YES;

   // Rest quality extrema
   _minQuality = HUGE;
   _maxQuality = -1.0;
}

- (void) processEnded:(NSNotification*)notif
{
   // Change the button title
   [_analyzeButton setTitle:NSLocalizedString(@"AnalyseTool",@"Analysis tool")];
   [_analyzeButton setEnabled:YES];

   _isAnalyzing = NO;

   [self updateAutoselect];

   // Reset the hilight
   [_window highlightItem:[_list firstItem]];

   // Reauthorize selection change
   MyImageAnalyzerParameters *params =
      [_list getProcessingParameterWithRef:myImageAnalyzerParametersRef
                                 forProcessing:myImageAnalyzerRef];
   [_imageView setSelection:params->_analysisRect resizable:YES movable:YES];

   // Register again for notifications
   [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(selectionRectChanged:)
                                                name:LynkeosImageViewSelectionRectDidChangeNotification
                                              object:_imageView];

   // Enable all other controls
   [_analyzeFieldX setEnabled: YES];
   [_analyzeFieldY setEnabled: YES];
   [_analyzeMethodMenu setEnabled: YES];
   [_analyzeSideMenu setEnabled:(_sideMenuLimit > 0)];
   [_cutoffFreqSlider setEnabled:YES];
   [_lowFreqCutoffText setEnabled:YES];
   [_highFreqCutoffText setEnabled:YES];
   [_previewButton setEnabled:YES];
   [_window setItemSelectionAuthorization:YES];
   [_window setItemEditionAuthorization:YES];
}

- (void) updateAutoselect
{
   // Retrieve the autoselect parameter
   MyAutoselectParams *params =
               [_list getProcessingParameterWithRef:myAutoselectParameterRef
                                         forProcessing:myImageAnalyzerRef];

   if ( params == nil )
   {
      params = [[[MyAutoselectParams alloc] init] autorelease];
      params->_qualityThreshold = _qualityThreshold;
      [_list setProcessingParameter:params withRef:myAutoselectParameterRef
                          forProcessing:myImageAnalyzerRef];
   }
   else if ( _qualityThreshold != params->_qualityThreshold )
      _qualityThreshold = params->_qualityThreshold;

   // Update the autoselect slider
   if ( _minQuality > _maxQuality )
   {
      [_minQualityText setStringValue:@""];
      [_maxQualityText setStringValue:@""];
      [_selectThresholdText setStringValue:@""];
   }
   else
   {
      [_minQualityText setDoubleValue:_minQuality];
      [_selectThresholdSlide setMinValue:_minQuality];
      [_maxQualityText setDoubleValue:_maxQuality];
      [_selectThresholdSlide setMaxValue:_maxQuality];
      if ( _qualityThreshold < _minQuality )
         _qualityThreshold = _minQuality;
      if ( _qualityThreshold > _maxQuality )
         _qualityThreshold = _maxQuality;
      if ( [_selectThresholdSlide doubleValue] != _qualityThreshold )
         [_selectThresholdSlide setDoubleValue:_qualityThreshold];
      if ( [_selectThresholdText doubleValue] != _qualityThreshold )
         [_selectThresholdText setDoubleValue:_qualityThreshold];
   }
   [_selectThresholdSlide setEnabled:(_minQuality < _maxQuality)];
   [_selectThresholdText setEnabled:(_minQuality < _maxQuality)];
}

- (void) updateNumSelectedAndMinMax:(BOOL)minMax
{
   NSEnumerator* list = [_list imageEnumerator];
   int numSel = 0, numImages = 0;
   MyImageListItem* item;

   if ( minMax )
   {
      _minQuality = HUGE;
      _maxQuality = 0.0;
   }

   while ( (item = [list nextObject]) != nil )
   {
      numImages++;
      if ( [item getSelectionState] == NSOnState )
         numSel++;

      if ( minMax )
      {
         MyImageAnalyzerResult *res = [item getProcessingParameterWithRef:
                                                        myImageAnalyzerResultRef
                                                            forProcessing:
                                                       myImageAnalyzerRef];
         if ( res != nil )
         {
            if ( res->_quality < _minQuality )
               _minQuality = res->_quality;
            if ( res->_quality > _maxQuality )
               _maxQuality = res->_quality;
         }
      }
   }

   if ( numImages != 0 )
   {
      [_numSelectedTail setHidden:NO];
      [_numSelectedText setIntValue:numSel];
   }
   else
   {
      [_numSelectedTail setHidden:YES];
      [_numSelectedText setStringValue:@""];
   }
}

- (void) itemChanged:(NSNotification*)notif
{
   id <LynkeosProcessableItem> item =
                            [[notif userInfo] objectForKey:LynkeosUserInfoItem];

   if ( _isAnalyzing )
   {
      if ( item != nil )
      {
         MyImageAnalyzerResult *res = [item getProcessingParameterWithRef:
                                                        myImageAnalyzerResultRef
                                                         forProcessing:
                                                       myImageAnalyzerRef];
         if ( res != nil )
         {
            if ( res->_quality < _minQuality )
               _minQuality = res->_quality;
            if ( res->_quality > _maxQuality )
               _maxQuality = res->_quality;
         }

         [_window highlightItem:item];
      }
   }
   else if ( item == _list )
   {
      MyImageAnalyzerParameters *params =
            [_list getProcessingParameterWithRef:myImageAnalyzerParametersRef
                                       forProcessing:myImageAnalyzerRef];
      LynkeosIntegerRect newSel;

      NSAssert( params != nil, @"Update of analysis params without parameters" );

      if ( [_analyzeSideMenu integerValue] != params->_analysisRect.size.width )
      {
         [_analyzeSideMenu setIntegerValue:params->_analysisRect.size.width];
         [_analyzeSideMenu selectItemWithObjectValue:
            [NSNumber numberWithInt:params->_analysisRect.size.width]];
      }

      [_analyzeButton setEnabled:(params->_analysisRect.size.width != 0
                                  && params->_analysisRect.size.height != 0)];

      if ( (MyAnalysisMethod)[[_analyzeMethodMenu selectedItem] tag]
                                                            != params->_method )
         [_analyzeMethodMenu selectItemWithTag:params->_method];

      [_cutoffFreqSlider setDoubleLoValue:params->_lowerCutoff];
      [_lowFreqCutoffText setDoubleValue:params->_lowerCutoff];
      [_cutoffFreqSlider setDoubleHiValue:params->_upperCutoff];
      [_highFreqCutoffText setDoubleValue:params->_upperCutoff];

      newSel = params->_analysisRect;

      if ( [_analyzeFieldX floatValue] != newSel.origin.x )
         [_analyzeFieldX setFloatValue:newSel.origin.x];
      if ( [_analyzeFieldY floatValue] != newSel.origin.y )
         [_analyzeFieldY setFloatValue:newSel.origin.y];

      // Update the autoselect if needed
      [self updateAutoselect];

      [self highlightChange:nil];
   }
   else
      [self updateNumSelectedAndMinMax:NO];
}

- (void) listModified:(NSNotification*)notif
{
   MyImageAnalyzerParameters *params =
               [_list getProcessingParameterWithRef:myImageAnalyzerParametersRef
                                      forProcessing:myImageAnalyzerRef];

   // Modify the list of allowed values in the size popup
   NSEnumerator* list;
   MyImageListItem* item;
   long limit = -1;
   int side;

   // Check the minimum image size from the list
   if ( _list != nil )
   {
      list = [[_list imageArray] objectEnumerator];
      while ( (item = [list nextObject]) != nil )
      {
         LynkeosIntegerSize size = [item imageSize];
         if ( size.width < limit || limit < 0 )
            limit = size.width;
         if ( size.height < limit )
            limit = size.height;
      }
   }

   // Optimization : reconstruct only on size change
   if ( (u_int)limit <= _sideMenuLimit/2 || (u_int)limit >= _sideMenuLimit*2 )
   {
      [_analyzeSideMenu removeAllItems];
      for ( side = 16; side <= limit; side *= 2 )
      {
         NSNumber* label = [NSNumber numberWithInt:side];
         [_analyzeSideMenu addItemWithObjectValue:label];
      }
      _sideMenuLimit = side/2;

      [_analyzeSideMenu setEnabled:(_sideMenuLimit > 0)];

      if ( params != nil && params->_analysisRect.size.width > 0 )
         [_analyzeSideMenu selectItemWithObjectValue:
             [NSNumber numberWithInt:params->_analysisRect.size.width]];
      else
         [_analyzeSideMenu deselectItemAtIndex:[_analyzeSideMenu indexOfSelectedItem]];
   }

   // Update the number of selected images
   [self updateNumSelectedAndMinMax:YES];
   [self updateAutoselect];

   [_analyzeButton setEnabled:(params != nil
                               && params->_analysisRect.size.width != 0
                               && params->_analysisRect.size.height != 0)];
}
@end

@implementation MyImageAnalyzerView
+ (void) initialize
{
   // Register the monitor for document notifications
   NSNotificationCenter *notif = [NSNotificationCenter defaultCenter];

   monitorDictionary = [[NSMutableDictionary alloc] initWithCapacity:1];

   [notif addObserver:[MyImageAnalyzerMonitor class]
             selector:@selector(documentDidOpen:)
                 name:LynkeosDocumentDidOpenNotification
               object:nil];
   [notif addObserver:[MyImageAnalyzerMonitor class]
             selector:@selector(documentWillClose:)
                 name:LynkeosDocumentWillCloseNotification
               object:nil];

   // Register the result as displayable in a column
   [[LynkeosColumnDescriptor defaultColumnDescriptor] registerColumn:@"quality"
                                                   forProcess:myImageAnalyzerRef
                                              parameter:myImageAnalyzerResultRef
                                                          field:@"quality"
                                                         format:@"%.2f"];
}

+ (BOOL) isStandardProcessingViewController { return(YES); }

+ (ProcessingViewKind_t) processingViewKindForConfig:(id <NSObject>)config
{
   NSAssert( config == nil, @"Image analyzer does not support configuration" );
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
   NSAssert( config == nil, @"Image analyzer does not support configuration" );
   *title = NSLocalizedString(@"AnalyseMenu",@"Analysis menu");
   *toolTitle = NSLocalizedString(@"AnalyseTool",@"Analysis tool");
   *key = @"n";
   *icon = [NSImage imageNamed:@"Analysis"];
   *tip = NSLocalizedString(@"AnalysisTip",@"Analysis tooltip");;
}

+ (unsigned int) allowedDisplaysForConfig:(id <NSObject>)config
{
   NSAssert( config == nil, @"Image analyzer does not support configuration" );
   return( BottomTab|SeparateView );
}

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _document = nil;
      _imageView = nil;
      _list = nil;
      _sideMenuLimit = -1;
      _minQuality = HUGE;
      _maxQuality = -1.0;
      _qualityThreshold = 0.0;
      _isAnalyzing = NO;
      _filteredPreview = NO;
      _unfilteredItem = nil;

      [[NSBundle mainBundle] loadNibNamed:@"MyImageAnalyzer" owner:self topLevelObjects:nil];
   }

   return( self );
}

- (void) dealloc
{
   if ( _filteredImage != nil )
      [_filteredImage release];
   [super dealloc];
}

- (id) initWithWindowController: (id <LynkeosWindowController>)window
                       document: (id <LynkeosViewDocument>)document
                  configuration: (id <NSObject>)config
{
   NSAssert( config == nil, @"Image analyzer does not support configuration" );

   if ( (self = [self init]) != nil )
   {
      _window = window;
      _imageView = [_window getImageView];

      _document = document;
      _list = [_document imageList];

      // Create the analysis parameters if needed
      MyImageAnalyzerParameters *params =
         [_list getProcessingParameterWithRef:myImageAnalyzerParametersRef
                                    forProcessing:myImageAnalyzerRef];

      if ( params == nil )
         params = [[[MyImageAnalyzerParameters alloc] init] autorelease];

      if ( params->_lowerCutoff >= params->_upperCutoff )
      {
         NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
         params->_lowerCutoff = [defaults doubleForKey:
                                                  K_PREF_ANALYSIS_LOWER_CUTOFF];
         params->_upperCutoff = [defaults doubleForKey:
                                                  K_PREF_ANALYSIS_UPPER_CUTOFF];
      }

      [_list setProcessingParameter:params
                            withRef:myImageAnalyzerParametersRef
                      forProcessing:myImageAnalyzerRef];
   }

   return( self );
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
      [_imageView setSelectionMode:SingleSelection];

      // Become delegate for the selection change
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
                      selector:@selector(listModified:)
                          name: LynkeosItemAddedNotification
                        object:_document];
      [notifCenter addObserver:self
                      selector:@selector(listModified:)
                          name: LynkeosItemRemovedNotification
                        object:_document];
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

      // Synchronize the display
      [self listModified:nil];
      [self itemChanged:
         [NSNotification notificationWithName:LynkeosItemChangedNotification
                                       object:_document
                                     userInfo:
                       [NSDictionary dictionaryWithObject:_list
                                                  forKey:LynkeosUserInfoItem]]];

      _isAnalyzing = NO;
   }
   else
   {
      [_window setListSelectionAuthorization:YES];

      // Resign delegate to the image view
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

- (IBAction) analyzeSquareChange :(id)sender
{
   MyImageAnalyzerParameters *params =
           [_list getProcessingParameterWithRef:myImageAnalyzerParametersRef
                                      forProcessing:myImageAnalyzerRef];

   params->_analysisRect.origin.x = [_analyzeFieldX floatValue];
   params->_analysisRect.origin.y = [_analyzeFieldY floatValue];

   [_list setProcessingParameter:params
                        withRef:myImageAnalyzerParametersRef
                  forProcessing:myImageAnalyzerRef];
}

- (IBAction) analysisSquareSizeChange: (id)sender
{
   MyImageAnalyzerParameters *params =
           [_list getProcessingParameterWithRef:myImageAnalyzerParametersRef
                                      forProcessing:myImageAnalyzerRef];

   params->_analysisRect.size.width = [_analyzeSideMenu integerValue];
   params->_analysisRect.size.height = params->_analysisRect.size.width;

   [_list setProcessingParameter:params
                             withRef:myImageAnalyzerParametersRef
                       forProcessing:myImageAnalyzerRef];
}

- (IBAction) analyzeMethodChange :(id)sender
{
   MyImageAnalyzerParameters *params =
   [_list getProcessingParameterWithRef:myImageAnalyzerParametersRef
                              forProcessing:myImageAnalyzerRef];

   params->_method = (MyAnalysisMethod)[[sender selectedItem] tag];

   [_list setProcessingParameter:params
                             withRef:myImageAnalyzerParametersRef
                       forProcessing:myImageAnalyzerRef];
}

- (IBAction) autoSelectAction :(id)sender
{
   double selectThreshold = [sender doubleValue];
   NSEnumerator* list = [_list imageEnumerator];
   int numSel = 0, numImages = 0;
   MyImageListItem* item;

   while ( (item = [list nextObject]) != nil )
   {
      MyImageAnalyzerResult *res =
                   [item getProcessingParameterWithRef:myImageAnalyzerResultRef
                                         forProcessing:myImageAnalyzerRef];
      if ( selectThreshold >= _qualityThreshold )
      {
         if ( res->_quality < selectThreshold )
            [item setSelected:NO];
      }
      else
      {
         if ( res->_quality >= selectThreshold )
            [item setSelected:YES];
      }
      numImages++;
      if ( [item getSelectionState] == NSOnState )
         numSel++;
   }

   _qualityThreshold = selectThreshold;

   if ( numImages != 0 )
   {
      [_numSelectedTail setHidden:NO];
      [_numSelectedText setIntValue:numSel];
   }
   else
   {
      [_numSelectedTail setHidden:YES];
      [_numSelectedText setStringValue:@""];
   }

   // Save the autoselect parameters in the document
   MyAutoselectParams *params = [[[MyAutoselectParams alloc] init] autorelease];
   params->_qualityThreshold = _qualityThreshold;
   [_list setProcessingParameter:params withRef:myAutoselectParameterRef
                       forProcessing:myImageAnalyzerRef];
}

- (IBAction) cutoffFrequenciesChange:(id)sender
{
   double lo, hi;
   MyImageAnalyzerParameters *params =
      [_list getProcessingParameterWithRef:myImageAnalyzerParametersRef
                             forProcessing:myImageAnalyzerRef];

   if ( sender == _cutoffFreqSlider )
   {
      lo = [sender doubleLoValue];
      hi = [sender doubleHiValue];
      [_lowFreqCutoffText setDoubleValue:lo];
      [_highFreqCutoffText setDoubleValue:hi];
      params->_lowerCutoff = lo;
      params->_upperCutoff = hi;
   }
   else if ( sender == _lowFreqCutoffText )
   {
      lo = [sender doubleValue];
      hi = [_cutoffFreqSlider doubleHiValue];
      if ( lo > hi )
      {
         lo = hi;
         [_lowFreqCutoffText setDoubleValue:lo];
      }
      [_cutoffFreqSlider setDoubleLoValue:lo];
      params->_lowerCutoff = lo;
   }
   else if ( sender == _highFreqCutoffText )
   {
      hi = [sender doubleValue];
      lo = [_cutoffFreqSlider doubleLoValue];
      if ( hi < lo )
      {
         hi = lo;
         [_highFreqCutoffText setDoubleValue:hi];
      }
      [_cutoffFreqSlider setDoubleHiValue:hi];
      params->_upperCutoff = hi;
   }

   // Force preview re-filtering
   _unfilteredItem = nil;

   [_list setProcessingParameter:params
                         withRef:myImageAnalyzerParametersRef
                   forProcessing:myImageAnalyzerRef];
}

- (IBAction) previewChange:(id)sender
{
   _filteredPreview = ([sender state] == NSOnState);
   if ( ! _filteredPreview )
   {
      // Free useless memory
      [_filteredImage release];
      _filteredImage = nil;
      _unfilteredItem = nil;
   }
   [self highlightChange:nil];
}

- (IBAction) analyzeAction :(id)sender
{
   MyImageAnalyzerParameters *params=
           [_list getProcessingParameterWithRef:myImageAnalyzerParametersRef
                                      forProcessing:myImageAnalyzerRef];

   [sender setEnabled:NO];

   if ( _isAnalyzing )
      [_document stopProcess];

   else
   {
      // Disable all controls
      [_analyzeFieldX setEnabled: NO];
      [_analyzeFieldY setEnabled: NO];
      [_analyzeSideMenu setEnabled: NO];
      [_analyzeMethodMenu setEnabled: NO];
      [_selectThresholdSlide setEnabled: NO];
      [_window setItemSelectionAuthorization:NO];
      [_window setItemEditionAuthorization:NO];

      // Freeze the selection rectangle
      [_imageView setSelection:params->_analysisRect resizable:NO movable:NO];

      // Stop receiving some notifications
      [[NSNotificationCenter defaultCenter] removeObserver:self
                              name:LynkeosImageViewSelectionRectDidChangeNotification
                                                    object:_imageView];

      NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
      _imageUpdate = [defaults boolForKey:K_PREF_ANALYSIS_IMAGE_UPDATING];

      // Get an enumerator on the images
      NSEnumerator *strider = [_list imageEnumerator];

      // Ask the doc to analyse
      [_document startProcess:[MyImageAnalyzer class] withEnumerator:strider
                   parameters:params];
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
@end
