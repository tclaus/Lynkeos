//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Tue Sep 30, 2003.
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

#import <AppKit/NSCell.h>

#include "LynkeosImageBufferAdditions.h"
#include "MyPluginsController.h"
#include "ProcessStackManager.h"
#include "MyImageListItem.h"
#include "LynkeosFourierBuffer.h"
#include "LynkeosInterpolator.h"

// V1 Compatibility includes
#ifndef NO_FILE_FORMAT_COMPATIBILITY_CODE
#include "LynkeosBasicAlignResult.h"
#include "MyImageAligner.h"
#include "MyImageAnalyzer.h"
#endif

#include "LynkeosColumnDescriptor.h"

static NSString * const K_URL_KEY	= @"url";
static NSString * const K_SELECTED_KEY	= @"selected";
static NSString * const K_INDEX_KEY	= @"index";
static NSString * const K_LONG_INDEX_KEY	= @"indexL";
static NSString * const K_IMAGES_KEY	= @"images";

NSString * const myImageListItemRef = @"MyImageListItem";
NSString * const myImageListItemDarkFrame = @"darkFrame";
NSString * const myImageListItemFlatField = @"flatField";

// V1 compatibility keys
#ifndef NO_FILE_FORMAT_COMPATIBILITY_CODE
static NSString * const K_MODBLACK_KEY  = @"black";
static NSString * const K_MODWHITE_KEY  = @"white";
static NSString * const K_GAMMA_CORRECTION_KEY = @"gamma";
#endif

// A bad hack for relative URL resolution (until I find a better solution)
extern NSString *basePath;

/*!
 * @abstract Phases of the parallel processing for the lock condition
 */
typedef enum
{
   ProcessInited,
   ProcessStarted,
   ProcessEnded
} ParallelImageProcessState_t;

/*!
 * @abstract Record of data needed for parallelized interpolation
 */
@interface ParallelInterpolationArgs : NSObject
{
@public
   Class                      interpolatorClass; //!< The interpolator class to use
   NSObject <LynkeosProcessableItem> *sourceItem; //!< The item from which to interpolate
   LynkeosImageBuffer *buffer;         //!< Operation result
   LynkeosIntegerRect          rect;
   NSAffineTransformStruct     transform;
   NSPoint                    *offsets;
   u_short                     y;              //!< Current line
   NSConditionLock            *lock;           //!< Exclusive access to this object
   u_short                     startedThreads; //!< Total number of started threads
   u_short                     livingThreads;  //!< Number of still living threads
}
@end

/*!
 * @category MyImageListItem(private)
 * @abstract Internal methods
 */
@interface MyImageListItem(private)
//! Common part of standard and decoder initializers
- (void) setURL:(NSURL*)url ;
//! Initializer for movie items
- (id) initWithParent:(MyImageListItem*)parent withIndex:(u_long)index ;
//! Set selection state with tri state option
- (void) setSelectionState :(int)state;
//! Update the container selection state according to the children
- (void) childrenSelectionChanged ;
//! Initialize the name of this item
- (void) setName :(NSString*)name ;

/*!
 * @method getDarkFrame
 * @abstract Shortcut to speed up calibration frames retrieval
 * @result The dark frame for this item
 */
- (LynkeosImageBuffer*) getDarkFrame ;

/*!
 * @method getFlatField
 * @abstract Shortcut to speed up calibration frames retrieval
 * @result The flat field for this item
 */
- (LynkeosImageBuffer*) getFlatField ;
@end

/** Comparison function for sorting readers (highest priority first) */
static NSComparisonResult compareReaders( id obj1, id obj2, void *ctx )
{
   int p1 = ((LynkeosReaderRegistry*)obj1)->priority;
   int p2 = ((LynkeosReaderRegistry*)obj2)->priority;

   if ( p1 == p2 )
      return( NSOrderedSame );
   else if ( p1 > p2 )
      return( NSOrderedAscending );

   return( NSOrderedDescending );
}

@implementation ParallelInterpolationArgs
@end

@implementation MyImageListItem(private)

- (void) setURL:(NSURL*)url
{
   if ( url != nil)
   {
      MyPluginsController *plugins = [MyPluginsController defaultPluginController];
      NSDictionary *myImageFileTypes = [plugins getImageReaders];
      NSDictionary *myMovieFileTypes = [plugins getMovieReaders];

      _itemURL = [url retain];

      _itemName = [[NSFileManager defaultManager] displayNameAtPath: [_itemURL path]];
      [_itemName retain];

      // Find the reader class which declares this file type, 
      // and accepts to open this file
      NSMutableArray *readers = [NSMutableArray array];
      NSEnumerator *list;
      LynkeosReaderRegistry *item;
      NSString *ext = [[[url path] pathExtension] lowercaseString];

      [readers addObjectsFromArray:[myMovieFileTypes objectForKey:ext]];
#if !defined GNUSTEP
      [readers addObjectsFromArray:[myMovieFileTypes objectForKey: NSHFSTypeOfFile([url path])]];
      NSString *uti;
      if ([url getResourceValue:&uti forKey:NSURLTypeIdentifierKey error:nil])
         [readers addObjectsFromArray:[myMovieFileTypes objectForKey: uti]];
      else
         uti = nil;
#endif
      [readers addObjectsFromArray:[myImageFileTypes objectForKey:ext]];
#if !defined GNUSTEP
      [readers addObjectsFromArray:[myImageFileTypes objectForKey: NSHFSTypeOfFile([url path])]];
      if (uti != nil)
         [readers addObjectsFromArray:[myImageFileTypes objectForKey: uti]];
#endif

      [readers sortUsingFunction:compareReaders context:NULL];

      // Try the readers until one accepts
      list = [readers objectEnumerator];
      while( (item = [list nextObject]) != nil )
      {
         _reader = [[item->reader alloc] initWithURL:url];
         if ( _reader != nil )
         {
            if ( [item->reader conformsToProtocol: @protocol(LynkeosCustomFileReader)] )
               _isCustomReader = YES;
            else
               _isCustomReader = NO;

            // Found it !
            break;
         }
      }

      if ( _reader != nil )
      {
         // Try to cache some characteristics
         _nPlanes = [_reader numberOfPlanes];
         [_reader imageWidth:&_size.width height:&_size.height];
      }
      else
         // Bad luck
         NSLog( @"Unable to create item for %@", [url absoluteString] );
   }
}

- (id) initWithParent:(MyImageListItem*)parent withIndex:(u_long)index
{
   if ( (self = [self init]) != nil )
   {
      _parent = parent;
      _reader = [parent->_reader retain];
      _itemName = [parent->_itemName retain];
      _index = index;
      _size = parent->_size;
      _nPlanes = parent->_nPlanes;
      [self  setParametersParent:parent->_parameters];
   }

   return( self );
}

- (void) setSelectionState :(int)state 
{
   _selection_state = state;
}

- (void) childrenSelectionChanged
{
   NSEnumerator* list = [_childList objectEnumerator];
   id item;
   unsigned int selection_count;

   // Recount the selection
   selection_count = 0;
   while ( (item = [list nextObject]) != nil )
      if ( [item getSelectionState] > 0 )
         selection_count ++;

   // Update the state
   if ( selection_count == 0 )
      [self setSelectionState:NSOffState];
   else if ( selection_count == [_childList count] )
      [self setSelectionState:NSOnState];
   else
      [self setSelectionState:NSMixedState];
}

- (void) setName :(NSString*)name
{
   if ( _itemName != nil )
      [_itemName release];
   _itemName = name;
   [_itemName retain];
}

- (LynkeosImageBuffer*) getDarkFrame
{
   if ( _dark != nil )
      return( _dark );

   // Search for a cached value in containers
   _dark = [_parent getDarkFrame];

   if ( _dark == nil )
      // Well, do it the expensive way
      _dark = (LynkeosImageBuffer*)[self getProcessingParameterWithRef:
                                                        myImageListItemDarkFrame
                                                             forProcessing:nil];

   if ( _dark != nil )
      [_dark retain];

   return( _dark );
}

- (void) one_thread_interpolate:(id)argument
{
   ParallelInterpolationArgs * const args = argument;
   id <LynkeosInterpolator> interpolator;
   u_short ourY = 0;

   // Count up on entry
   if ( _processStrategy == ParallelizedStrategy )
   {
      [args->lock lock];
      if ( args->startedThreads < numberOfCpus )
         args->startedThreads++;
      else
         NSLog( @"Too much thread start in one_thread_process_image" );
      args->livingThreads++;
      if ( args->startedThreads == numberOfCpus )
         [args->lock unlockWithCondition: ProcessStarted];
      else
         [args->lock unlock];
   }

//   NSLog(@"Interpolator started for %@ in rect %d,%d,%dx%d with transform\n\t[%.6f, %.6f; %.6f, %.6f; %.1f, %.1f]",
//         _itemName,
//         args->rect.origin.x, args->rect.origin.y, args->rect.size.width, args->rect.size.height,
//         args->transform.m11, args->transform.m12,
//         args->transform.m21, args->transform.m22,
//         args->transform.tX, args->transform.tY);
   interpolator = [[[args->interpolatorClass alloc] initWithItem:self
                                                          inRect:args->rect
                                              withNumberOfPlanes:args->buffer->_nPlanes
                                                    withTranform:args->transform
                                                     withOffsets:args->offsets
                                                  withParameters:nil]
                   autorelease];

   // Process by sharing lines with other threads
   for(;;)
   {
      ourY = args->y;
      if ( ourY >= args->buffer->_h )
         break;
      if ( __sync_bool_compare_and_swap(&(args->y), ourY, ourY + 1) )
      {
         u_short x, c;
         for ( c = 0; c < args->buffer->_nPlanes; c++ )
            for ( x = 0; x < args->buffer->_w; x += sizeof(REALVECT)/sizeof(REAL) )
            {
               colorVector(args->buffer, x, ourY, c)
                  = [interpolator interpolateVectInPLane:c atX:x atY:ourY];
            }
      }
   }

   // Count down on exit
   if ( _processStrategy == ParallelizedStrategy )
   {
      [args->lock lockWhenCondition:ProcessStarted];
      if ( args->livingThreads > 0 )
         args->livingThreads--;
      else
         NSLog( @"Too much thread end in one_thread_process_image" );

      if ( args->livingThreads == 0 )
         [args->lock unlockWithCondition:ProcessEnded];
      else
         [args->lock unlock];
   }
}

- (LynkeosImageBuffer*) getFlatField
{
   if ( _flat != nil )
      return( _flat );

   // Search for a cached value in containers
   _flat = [_parent getFlatField];
   if ( _flat == nil )
      // Well, do it the expensive way
      _flat = (LynkeosImageBuffer*)[self
                          getProcessingParameterWithRef:myImageListItemFlatField
                                          forProcessing:nil];

   if ( _flat != nil )
      [_flat retain];

   return( _flat );
}
@end

@implementation MyImageListItem

+ (void) initialize
{
   // Register some of our properties as displayable in a column
   [[LynkeosColumnDescriptor defaultColumnDescriptor] registerColumn:@"select"
                                                     forProcess:myImageListItemRef
                                                      parameter:myImageListItemRef
                                                          field:@"selectionState"
                                                         format:nil];
   [[LynkeosColumnDescriptor defaultColumnDescriptor] registerColumn:@"name"
                                                     forProcess:myImageListItemRef
                                                      parameter:myImageListItemRef
                                                          field:@"name"
                                                         format:nil];
   [[LynkeosColumnDescriptor defaultColumnDescriptor] registerColumn:@"index"
                                                     forProcess:myImageListItemRef
                                                      parameter:myImageListItemRef
                                                          field:@"index"
                                                         format:nil];
}

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _reader = nil;
      _isCustomReader = NO;
      _itemURL = nil;
      _itemName = nil;
      _childList = nil;

      _index = NSNotFound;
      _parent = nil;
      _selection_state = 1;

      _flat = nil;
      _dark = nil;
   }

   return( self );
}

- (id) initWithURL :(NSURL*)url
{
   if ( (self = [self init]) != nil )
   {
      [self setURL:url];

      // Abort if there is no reader found
      if ( _reader == nil )
      {
         [self release];
         self = nil;
         return( self );
      }

      if ( [_reader conformsToProtocol:@protocol(LynkeosImageFileReader)] )
      {
         // Nothing more to do
      }

      else if ( [_reader conformsToProtocol:@protocol(LynkeosMovieFileReader)] )
      {
         // Create children for the movie images
         const u_long childrenNb = [_reader numberOfFrames];
         u_long i;

         _childList = [[NSMutableArray arrayWithCapacity:childrenNb] retain];
         for( i = 0; i < childrenNb; i++ )
            [_childList addObject:[[[MyImageListItem alloc] initWithParent:self
                                                                 withIndex:i]
                autorelease]];
      }
      else
         NSAssert( NO, @"Invalid file reader selected" );
   }

   return( self );
}

- (void) dealloc
{
   [_reader release];
   [_itemURL release];
   [_itemName release];
   [_childList release];
   if ( _dark != nil )
      [_dark release];
   if ( _flat != nil )
      [_flat release];

   [super dealloc];
}

// Coding
- (void)encodeWithCoder:(NSCoder *)encoder
{
   if ( _itemURL != nil )
   {
      // Try to resolve item path against document path
      NSURL *itemRelativeURL;

      if ( basePath != nil )
      {
         NSArray *itemPath = [[_itemURL path] pathComponents];
         NSArray *docPath = [basePath pathComponents];
         NSMutableString *relativePath = [NSMutableString string];
         NSString *itemComp, *docComp;
         NSUInteger i, j, nItems = [itemPath count], nDoc = [docPath count];

         // Scan the common part
         for ( i = 0; i < nDoc && i < nItems; i++ )
         {
            docComp = [docPath objectAtIndex:i];
            itemComp = [itemPath objectAtIndex:i];
            if ( ![itemComp isEqualToString:docComp] )
               break;
         }

         NSAssert2( i > 0, @"Doc or item URL to encode is not absolute\n%@\n%@",
                    _itemURL, basePath );

         if ( i > 1 )
         {
            // Go back from the doc to the divergence point
            for ( j = i; j < nDoc; j++ )
               [relativePath appendString:@"../"];

            // Append the item's remaining components (including file name)
            for ( ; i < nItems; i++ )
            {
               [relativePath appendString:[itemPath objectAtIndex:i]];
               if ( i < (nItems-1) )
                  [relativePath appendString:@"/"];
            }

            NSURL *baseURL = [NSURL fileURLWithPath:basePath];
            NSString *relURL =
               [relativePath stringByAddingPercentEscapesUsingEncoding:
                                                          NSUTF8StringEncoding];
            itemRelativeURL = [NSURL URLWithString:relURL
                                      relativeToURL:baseURL];
         }
         else
            // The paths diverge immediately after "/", better be absolute
            itemRelativeURL = _itemURL;
      }
      else
         itemRelativeURL = _itemURL;

      [encoder encodeObject:itemRelativeURL forKey:K_URL_KEY];
   }
   if ( _childList != nil )
      [encoder encodeObject:_childList forKey:K_IMAGES_KEY];
   else
   {
      [encoder encodeInt64:_index forKey:K_LONG_INDEX_KEY];
      [encoder encodeBool:(_selection_state == NSOnState) 
                   forKey:K_SELECTED_KEY];
   }

   [super encodeWithCoder:encoder];
}

- (id)initWithCoder:(NSCoder *)decoder	// This is also an initialization
{
   if ( (self = [super initWithCoder:decoder]) != nil )
   {
      // Try absolute and doc relative URL resolution
      NSFileManager *fManager = [NSFileManager defaultManager];
      NSURL *itemURL = [decoder decodeObjectForKey:K_URL_KEY];
      if ( itemURL != nil && basePath != nil && ![fManager fileExistsAtPath:[itemURL path]] )
      {
         NSURL *relURL = [NSURL URLWithString:[itemURL relativeString]
                                relativeToURL:[NSURL fileURLWithPath:basePath]];
         if ( [fManager fileExistsAtPath:[relURL path]] )
            itemURL = relURL;
      }

      [self setURL:itemURL];

      _childList = [[decoder decodeObjectForKey:K_IMAGES_KEY] retain];
      if ( [decoder containsValueForKey:K_LONG_INDEX_KEY] )
         // V3 : OS X 10.8 64 bits index
         _index = [decoder decodeInt64ForKey:K_LONG_INDEX_KEY];

      else if ( [decoder containsValueForKey:K_INDEX_KEY] )
      {
         // V2 : 32 bits index
         int i = [decoder decodeInt32ForKey:K_INDEX_KEY];
         _index = (i >= 0 ? i : NSNotFound);
      }
      if ( _childList == nil )
         [self setSelected: [decoder decodeBoolForKey:K_SELECTED_KEY]];

      // V1 compatibility code
#ifndef NO_FILE_FORMAT_COMPATIBILITY_CODE
      // Compatibility code for version < V2.2

      // Try to get the black and white levels, only if the item is processed
      if ( [self getProcessingParameterWithRef:K_PROCESS_STACK_REF
                                 forProcessing:nil] != nil
           && [decoder containsValueForKey:K_MODBLACK_KEY]
           && [decoder containsValueForKey:K_MODWHITE_KEY] )
      {
         double vmin, vmax;
         u_short c;
         _black = (double*)malloc( sizeof(double)*(_nPlanes+1) );
         _white = (double*)malloc( sizeof(double)*(_nPlanes+1) );
         _gamma = (double*)malloc( sizeof(double)*(_nPlanes+1) );
         _black[_nPlanes] = [decoder decodeDoubleForKey:K_MODBLACK_KEY];
         _white[_nPlanes] = [decoder decodeDoubleForKey:K_MODWHITE_KEY];
         _gamma[_nPlanes] = [decoder decodeDoubleForKey:K_GAMMA_CORRECTION_KEY];
         if ( _gamma[_nPlanes] == 0.0 )
            _gamma[_nPlanes] = 1.0;

         [(LynkeosImageBuffer*)[self getImage] getMinLevel:&vmin
                                                          maxLevel:&vmax];
         for( c = 0; c < _nPlanes; c++ )
         {
            _black[c] = vmin;
            _white[c] = vmax;
            _gamma[c] = 1.0;
         }
      }
      // End of compatibility code
#endif

      // Fill the missing data in the children
      if ( _childList != nil )
      {
         NSEnumerator *children = [_childList objectEnumerator];
         MyImageListItem *item;

         while ( (item = [children nextObject]) != nil )
         {
            item->_parent = self;
            [item setParametersParent:_parameters];
            // When the reader is not found, we go on, and the document will
            // alert the user and delete bad items
            if ( _reader != nil )
               item->_reader = [_reader retain];
            item->_itemName = [_itemName retain];
            item->_size = _size;
            item->_nPlanes = _nPlanes;
         }

         // Refresh the parent (myself) selection state
         [self childrenSelectionChanged];
      }
   }

   return( self );
}

- (void) setMode:(ListMode_t)mode
{
   // Propagate the mode to the custom reader, if any
   if ( _isCustomReader )
   {
      [(id <LynkeosCustomFileReader>)_reader setMode:mode];
      // The mode can drive some image characteristics
      _nPlanes = [_reader numberOfPlanes];
      [_reader imageWidth:&_size.width height:&_size.height];
   }
}

// Accessors
- (NSURL*) getURL { return( _itemURL ); }

- (u_long) numberOfChildren
{
   return( _childList == nil ? 0 : [_childList count] );
}

- (int) getSelectionState { return( _selection_state ); }
- (NSNumber*) selectionState
{
   return( [NSNumber numberWithInt:_selection_state] );
}

- (NSString*)name { return( _itemName ); }

- (NSNumber*) index
{
   if ( _index == NSNotFound )
      return( nil );
   else
      return( [NSNumber numberWithUnsignedInteger:_index] );
}

- (MyImageListItem*) getParent { return( _parent ); }

- (id <LynkeosFileReader>) getReader { return(_reader ); }

- (MyImageListItem*) getChildAtIndex:(u_long)index
{
   NSAssert( _childList != nil, @"getChildAtIndex called on a leaf item" );
   return( [_childList objectAtIndex:index] );
}

- (NSUInteger) indexOfItem:(MyImageListItem*)item
{
   NSAssert( _childList != nil, @"indexOfItem called on a leaf item" );
   return( [_childList indexOfObject:item] );
}

- (void) addChild:(MyImageListItem*)item
{
   NSEnumerator *iter = [_childList objectEnumerator];
   MyImageListItem *child;
   u_long itemIndex = item->_index;
   int arrayIndex = 0;

   // Look for the first image whose index is after this one
   while ( (child = [iter nextObject]) != nil && child->_index < itemIndex )
      arrayIndex++;

   // There shall not be two images for the same movie frame
   NSAssert( child == nil || child->_index != itemIndex,
            @"Add a preexisting frame in MyImageListItem" );

   // And insert this one before it
   [_childList insertObject:item atIndex:arrayIndex];

   // Connect the parameters chain
   [item setParametersParent:_parameters];

   [self childrenSelectionChanged];
}

- (void) deleteChild:(MyImageListItem*)item
{
   NSAssert( [_childList containsObject:item], 
            @"Cannot delete a nonexistent child!" );
   [_childList removeObject:item];
   [self childrenSelectionChanged];
}

- (void) setSelected :(BOOL)value
{
   _selection_state = value ? NSOnState : NSOffState;

   if ( _childList != nil )
   {
      NSEnumerator* list = [_childList objectEnumerator];
      id item;

      // Propagate that state on all the images
      while ( (item = [list nextObject]) != nil )
         [item setSelected:value];
   }
   else
   {
      MyImageListItem *parent = [self getParent];

      if ( parent != nil )
         [parent childrenSelectionChanged];
   }

   // Notify for some change
   [_parameters notifyItemModification:self];
}

- (void) setParametersParent :(LynkeosProcessingParameterMgr*)parent;
{
   if ( _parameters->_parent != nil )
      [_parameters->_parent release];
   _parameters->_parent = [parent retain];

   // Now that the parameters are connected, get the calibration frames
   _dark = (LynkeosImageBuffer*)[self getProcessingParameterWithRef:
                                                        myImageListItemDarkFrame
                                                          forProcessing:nil];
   if ( _dark != nil )
      [_dark retain];
   _flat = (LynkeosImageBuffer*)[self getProcessingParameterWithRef:
                                                        myImageListItemFlatField
                                                          forProcessing:nil];
   if ( _flat != nil )
      [_flat retain];

   if ( _isCustomReader )
   {
      [(id <LynkeosCustomFileReader>)_reader setDarkFrame:_dark];
      [(id <LynkeosCustomFileReader>)_reader setFlatField:_flat];
   }
}

#pragma mark = LynkeosProcessableItem protocol
- (u_short) numberOfPlanes
{
   if ( _nPlanes == 0 )
      _nPlanes = [_reader numberOfPlanes];

   return( _nPlanes );
}

- (LynkeosIntegerSize) imageSize
{
   if ( _size.width == 0 && _size.height == 0 )
      [_reader imageWidth:&_size.width height:&_size.height];

   return( _size );
}

- (LynkeosImageBuffer*) getImage
{
   LynkeosImageBuffer* image = [super getImage];

   if ( image == nil )
   {
      LynkeosIntegerRect r = { {0.0,0.0}, _size };
      [self getImageSample:&image inRect:r];
   }

   return( image );
}

- (void) setOperatorsStrategy:(ImageOperatorsStrategy_t)strategy
{
   _processStrategy = strategy;
}

- (BOOL) hasImage
{
   if ( _processedImage != nil || _processedSpectrum != nil )
      return(YES);
   else
      return ( _childList == nil );
}

- (BOOL) supportsTiling
{
   if ( _processedImage != nil || _processedSpectrum != nil )
      return [super supportsTiling];
   else
      return NO;
}

- (CGImageRef) getImageTileInRect:(CGRect)rect
{
   CGImageRef image = NULL;
   NSImage *nsImg = nil;

   if ( _processedImage != nil || _processedSpectrum != nil )
      image = [super getImageTileInRect:rect];

   else if ( _childList != nil )
      // No image at movie level
      ;
   else if ( _index == NSNotFound )
      // Image file
      nsImg = [_reader getNSImage];
   else
      // Movie image
      nsImg = [_reader getNSImageAtIndex:_index];

   if (nsImg != nil)
   {
      image = [nsImg CGImageForProposedRect:&rect context:NULL hints:nil];
      CGImageRetain(image);
   }

   return( image );
}

- (void) getImageSample:(LynkeosImageBuffer**)buffer
                 inRect:(LynkeosIntegerRect)rect
{
   if ( _processedImage != nil || _processedSpectrum != nil )
      [super getImageSample:buffer inRect:rect];

   else
   {
      LynkeosImageBuffer* data = nil;
      LynkeosIntegerRect wRect;
      REAL * const * planes;
      u_short x, y, c;
      LynkeosImageBuffer* flat = [self getFlatField];
      LynkeosImageBuffer* dark = [self getDarkFrame];

      // No image sample should be retrieved at movie level
      NSAssert( _childList == nil, @"getImageSample called at movie level" );

      // Create an image buffer if needed
      if ( *buffer == nil )
         *buffer = [LynkeosImageBuffer imageBufferWithNumberOfPlanes: [_reader numberOfPlanes]
                                                                       width: rect.size.width
                                                                      height: rect.size.height];
      else
         // Otherwise, reset its remanent characteristics
         [*buffer resetMinMax];

      NSAssert( (*buffer)->_w == rect.size.width && (*buffer)->_h == rect.size.height,
                @"Sample size inconsistency" );

      // There is no transformation, do not use an interpolator

      // Intersect the rectangle with the image
      wRect = IntersectIntegerRect(rect, LynkeosMakeIntegerRect(0,0,_size.width,_size.height) );

      // Fill with black outside the image
      if ( wRect.size.width != rect.size.width
          || wRect.size.height < rect.size.height )
      {
         for( c = 0; c < (*buffer)->_nPlanes; c++ )
         {
            // Upper margin
            for( y = 0;
                y < wRect.origin.y-rect.origin.y && y < (*buffer)->_h;
                y++ )
               for( x = 0; x < (*buffer)->_w; x++ )
                  colorValue(*buffer,x,y,c) = 0.0;
            if ( wRect.size.width != rect.size.width )
            {
               for( ; y < wRect.origin.y+wRect.size.height-rect.origin.y
                   && y < (*buffer)->_h; y++ )
               {
                  // Left margin
                  for( x = 0;
                      x < wRect.origin.x-rect.origin.x && x < (*buffer)->_w;
                      x++ )
                     colorValue(*buffer,x,y,c) = 0.0;
                  // Right margin
                  for( x = wRect.origin.x+wRect.size.width-rect.origin.x;
                      x < (*buffer)->_w;
                      x++ )
                     colorValue(*buffer,x,y,c) = 0.0;
               }
            }
            // Bottom margin
            for( ; y < (*buffer)->_h; y++ )
               for( x = 0; x < (*buffer)->_w; x++ )
                  colorValue(*buffer,x,y,c) = 0.0;
         }
      }

      // If, for some reason, the rectangle is outside the image, it's over now
      if ( wRect.size.width == 0 || wRect.size.height == 0 )
         return;

      // Fake the planes origin for the reader or the conversion to fill the
      // intersection (the fake image is said to have rect.size.height to keep
      // the planes aligned, but we fill only wRect.size.height)
      LynkeosImageBuffer *transBuf
         = [LynkeosImageBuffer imageBufferWithData:&colorValue(*buffer,
                                                                       wRect.origin.x - rect.origin.x,
                                                                       wRect.origin.y - rect.origin.y,
                                                                       0)
                                                      copy:NO freeWhenDone:NO
                                            numberOfPlanes:(*buffer)->_nPlanes
                                                     width:wRect.size.width
                                               paddedWidth:(*buffer)->_padw
                                                    height:(*buffer)->_h];
      planes = [transBuf colorPlanes];

      // Try to get the data from a custom image if we can calibrate in it
      NSAffineTransformStruct t = {1.0, 0.0, 0.0, 1.0, 0.0, 0.0};
      NSPoint offsets[3] = {{0.0, 0.0}, {0.0, 0.0}, {0.0, 0.0}};
      if ( _isCustomReader )
         data = [self getCustomImageSampleinRect:wRect withTransform:t withOffsets:offsets];

      // And read as a last (but common ;o) resort
      if ( data == nil )
      {
         REAL * const *readPlanes;
         short readPlanesNb = [_reader numberOfPlanes];

         if ( ( (dark == nil && flat == nil) ||
               (wRect.size.width == rect.size.width
                && wRect.size.height == rect.size.height) )
             && readPlanesNb == transBuf->_nPlanes )
         {
            // Optimisation : as the planearity is the same as the reader (and
            // calibration frames), we can read directly in the buffer and spare
            // the conversion.
            // But to calibrate, we also need the sample to be fully inside the
            // image.
            data = transBuf;
            readPlanes = planes;
         }

         else
         {
            // We need a temporary buffer to read in
            data = [LynkeosImageBuffer imageBufferWithNumberOfPlanes:readPlanesNb
                                                                       width:wRect.size.width
                                                                      height:wRect.size.height];
            readPlanes = [(LynkeosImageBuffer*)data colorPlanes];
         }

         if ( _index == NSNotFound )
            // Image file
            [_reader getImageSample:(REAL*const*const)readPlanes
                         withPlanes:((LynkeosImageBuffer*)data)->_nPlanes
                                atX:wRect.origin.x Y:wRect.origin.y
                                  W:wRect.size.width H:wRect.size.height
                          lineWidth:((LynkeosImageBuffer*)data)->_padw];
         else
            // Movie image
            [_reader getImageSample:(REAL*const*const)readPlanes
                            atIndex:_index
                         withPlanes:((LynkeosImageBuffer*)data)->_nPlanes
                                atX:wRect.origin.x Y:wRect.origin.y
                                  W:wRect.size.width H:wRect.size.height
                          lineWidth:((LynkeosImageBuffer*)data)->_padw];
      }

      NSAssert( data != nil, @"Failed to read a sample" );

      if ( dark != nil || flat != nil )
         [data calibrateWithDarkFrame:dark flatField:flat
                                  atX:wRect.origin.x Y:wRect.origin.y];

      if ( data != transBuf )
         [data convertToPlanar:(REAL*const*const)planes
                    withPlanes:transBuf->_nPlanes
                     lineWidth:transBuf->_padw];
   }
}

- (void) getImageSample:(LynkeosImageBuffer**)buffer
                 inRect:(LynkeosIntegerRect)rect
          withTransform:(NSAffineTransformStruct)transform
            withOffsets:(NSPoint *)offsets
{
   int i;
   Class interpolatorClass = [LynkeosInterpolatorManager interpolatorWithScaling:UseTransform
                                                                       transform:transform];
   NSAssert(interpolatorClass != nil, @"Could not find an interpolator");


   if ( *buffer == nil )
      *buffer = [LynkeosImageBuffer imageBufferWithNumberOfPlanes: [_reader numberOfPlanes]
                                                                    width: rect.size.width
                                                                   height: rect.size.height];
   else
      // Otherwise, reset its remanent characteristics
      [*buffer resetMinMax];

   NSAssert( *buffer != nil, @"No buffer to extract a sample");
   NSAssert( (*buffer)->_w == rect.size.width
            && (*buffer)->_h == rect.size.height,
            @"Sample size inconsistency" );

   // No need to calibrate here, the interpolator will use getImageSample:inRect:, which calibrates
   ParallelInterpolationArgs *args = [[[ParallelInterpolationArgs alloc] init] autorelease];
   args->interpolatorClass = interpolatorClass;
   args->sourceItem = self;
   args->buffer = *buffer;
   args->rect = rect;
   args->transform = transform;
   args->offsets = (NSPoint*)malloc(sizeof(NSPoint)*(*buffer)->_nPlanes);
      for (i = 0; i < (*buffer)->_nPlanes; i++)
      {
         args->offsets[i] = (offsets != NULL ? offsets[i] : CGPointMake(0.0, 0.0));
      }
   args->y = 0;
   args->lock = nil;
   args->startedThreads = 0;
   args->livingThreads = 0;

   // When parallelization is required
   if (_processStrategy == ParallelizedStrategy)
   {
      args->lock = [[NSConditionLock alloc] initWithCondition:ProcessInited];

      // Start a thread for each "other processor"
      for( i =  1; i < numberOfCpus; i++ )
         [NSThread detachNewThreadSelector:@selector(one_thread_interpolate:)
                                  toTarget:self
                                withObject:args];
   }

   // Do our part of the job
   [self one_thread_interpolate:args];

   // Finally, wait or all threads completion, if any
   if (_processStrategy == ParallelizedStrategy)
   {
      [args->lock lockWhenCondition:ProcessEnded];
      [args->lock unlock];
      [args->lock release];
   }
   free(args->offsets);
}

- (LynkeosImageBuffer*) getCustomImageSampleinRect:(LynkeosIntegerRect)rect
                                         withTransform:(NSAffineTransformStruct)transform
                                           withOffsets:(NSPoint *)offsets
{
   LynkeosImageBuffer* customImage = nil;

   if ([[_reader class] conformsToProtocol:@protocol(LynkeosCustomFileReader)])
   {
      NSPoint *lOffsets = (NSPoint*)malloc(sizeof(NSPoint)*_nPlanes);
      u_short p;
      for (p = 0; p < _nPlanes; p++)
         lOffsets[p] = (offsets != nil ? offsets[p] : NSMakePoint(0.0, 0.0));

      if ( _index == NSNotFound )
         // Image file
         customImage = [(id <LynkeosCustomImageFileReader>)_reader
                                    getCustomImageSampleAtX:rect.origin.x
                                                          Y:rect.origin.y
                                                          W:rect.size.width
                                                          H:rect.size.height
                                              withTransform:transform
                                                withOffsets:lOffsets];
      else
         // Movie image
         customImage = [(id <LynkeosCustomMovieFileReader>)_reader
                                getCustomImageSampleAtIndex:_index
                                                        atX:rect.origin.x
                                                          Y:rect.origin.y
                                                          W:rect.size.width
                                                          H:rect.size.height
                                              withTransform:transform
                                                withOffsets:lOffsets];

      free(lOffsets);
   }

   return( customImage );
}


- (void) setImage:(LynkeosImageBuffer*)buffer
{
   [super setImage:buffer];

   if ( _processedImage == nil )
   {
      [_reader imageWidth:&_size.width height:&_size.height];
      _nPlanes = [_reader numberOfPlanes];
   }
}

- (void) setOriginalImage:(LynkeosImageBuffer*)buffer
{
   NSLog( @"Impossible to set the original image on MyImageListItem" );
}

- (void) revertToOriginal
{
   // Easy ! The original image always comes from the reader
   [self setImage:nil];
}

- (BOOL) isProcessed
{
   return( ![self isOriginal] );
}

- (BOOL) getBlackLevel:(double*)black whiteLevel:(double*)white
                 gamma:(double*)gamma
{
   if ( _processedImage != nil || _processedSpectrum != nil )
      return( [super getBlackLevel:black whiteLevel:white gamma:gamma] );

   else
   {
      [_reader getMinLevel:black maxLevel:white];
      *gamma = 1.0;
   }

   return( YES );
}

- (BOOL) getBlackLevel:(double*)black whiteLevel:(double*)white
                 gamma:(double*)gamma  forPlane:(u_short)plane
{
   if ( _processedImage != nil || _processedSpectrum != nil )
      return( [super getBlackLevel:black whiteLevel:white gamma:gamma
                          forPlane:plane] );

   else
   {
      [_reader getMinLevel:black maxLevel:white];
      *gamma = 1.0;
   }

   return( YES );
}

- (void) setBlackLevel:(double)black whiteLevel:(double)white
                  gamma:(double)gamma
{
   // Forget the reader and start a processed image
   if ( _processedImage == nil && _processedSpectrum == nil )
      [self setImage:[self getImage]];
   [super setBlackLevel:black whiteLevel:white gamma:gamma];
}

- (void) setBlackLevel:(double)black whiteLevel:(double)white
                 gamma:(double)gamma forPlane:(u_short)plane
{
   // Forget the reader and start a processed image
   [self setImage:[self getImage]];
   [super setBlackLevel:black whiteLevel:white gamma:gamma forPlane:plane];
}

- (BOOL) getMinLevel:(double*)vmin maxLevel:(double*)vmax
{
   if ( _processedImage != nil || _processedSpectrum != nil )
      return( [super getMinLevel:vmin maxLevel:vmax] );

   else
      [_reader getMinLevel:vmin maxLevel:vmax];

   return( YES );
}

- (BOOL) getMinLevel:(double*)vmin maxLevel:(double*)vmax
            forPlane:(u_short)plane
{
   if ( _processedImage != nil || _processedSpectrum != nil )
      return( [super getMinLevel:vmin maxLevel:vmax forPlane:plane] );

   else
      [_reader getMinLevel:vmin maxLevel:vmax];

   return( YES );
}

- (id <LynkeosProcessingParameter>) getProcessingParameterWithRef:(NSString*)ref 
                                             forProcessing:(NSString*)processing
{
   return( [self getProcessingParameterWithRef:ref forProcessing:processing
                                          goUp:YES] );
}

- (id <LynkeosProcessingParameter>) getProcessingParameterWithRef:(NSString*)ref 
                                             forProcessing:(NSString*)processing
                                                             goUp:(BOOL)goUp
{
   // Present ourselves as a parameter for displaying some fields in the GUI
   if ( [processing isEqual:myImageListItemRef] )
      return( self );
   else
      return( [_parameters getProcessingParameterWithRef:ref
                                           forProcessing:processing goUp:goUp] );
}

- (void) setProcessingParameter:(id <LynkeosProcessingParameter>)parameter
                        withRef:(NSString*)ref 
                  forProcessing:(NSString*)processing
{
   [_parameters setProcessingParameter:parameter withRef:ref 
                         forProcessing:processing];

   // Handle the shortcut for calibration frames
   if ( processing == nil )
   {
      if ( [ref isEqual:myImageListItemDarkFrame] )
      {
         if ( _dark != nil )
            [_dark release];
         _dark = (LynkeosImageBuffer*)[parameter retain];
         if ( _isCustomReader )
            [(id <LynkeosCustomFileReader>)_reader setDarkFrame:_dark];
      }
      else if ( [ref isEqual:myImageListItemFlatField] )
      {
         if ( _flat != nil )
            [_flat release];
         _flat = (LynkeosImageBuffer*)[parameter retain];
         if ( _isCustomReader )
            [(id <LynkeosCustomFileReader>)_reader setFlatField:_flat];
      }
   }


   // Notify of the change
   [_parameters notifyItemModification:self];
}

- (NSDictionary*) getMetaData
{
   return([_reader getMetaData]);
}

+ (id) imageListItemWithURL :(NSURL*)url
{
   return( [[[self alloc] initWithURL:url] autorelease] );
}

+ (NSArray*) imageListItemFileTypes
{
   MyPluginsController *plugins = [MyPluginsController defaultPluginController];
   return( [[[plugins getImageReaders] allKeys] arrayByAddingObjectsFromArray:
                                          [[plugins getMovieReaders] allKeys]]);
}

@end
