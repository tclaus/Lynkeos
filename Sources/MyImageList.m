//
//  Lynkeos 
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Wed Sep 24 2003.
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

#include <math.h>

#import <AppKit/NSCell.h>

// V1 compatibility includes
#ifndef NO_FILE_FORMAT_COMPATIBILITY_CODE
//#include "MyImageAligner.h"
//#include "MyImageAnalyzer.h"
//#include "MyImageStacker.h"
//#include "MyDeconvolution.h"
//#include "MyUnsharpMask.h"
//#include "MyDocument.h"
#endif

#include "MyImageList.h"
#include "MyImageListEnumerator.h"
#include "MyMultiPassImageEnumerator.h"
#include "LynkeosFourierBuffer.h"

static NSString * const K_LIST_KEY =         @"images";
static NSString * const K_BLACK_LEVEL_KEY =  @"blackl";
static NSString * const K_WHITE_LEVEL_KEY =  @"whitel";
static NSString * const K_GAMMA_CORRECTION_KEY = @"gamma";
//! Key for saving the stacked image
static NSString * const K_IMAGE_KEY =        @"stack";
//! Key for saving the parameters

@interface MyImageList(Private)
- (void) connectParametersChain ;
@end

@implementation MyImageList(Private)
- (void) connectParametersChain
{
   // Connect the parameters chain
   NSEnumerator *en = [_list objectEnumerator];
   MyImageListItem *item;
   while( (item = [en nextObject]) != nil )
      [item setParametersParent:_parameters];   
}
@end

@implementation MyImageList

//==============================================================================
// Coding
//==============================================================================

- (void)encodeWithCoder:(NSCoder *)encoder
{
   [encoder encodeObject:_list forKey:K_LIST_KEY];

   [super encodeWithCoder:encoder];
}

- (id) initWithCoder:(NSCoder *)decoder
{
   if ( (self = [super initWithCoder:decoder]) != nil )
   {
      if ( [decoder containsValueForKey:K_LIST_KEY] )
      {
         id stack;

         // List data
         _list = [[decoder decodeObjectForKey:K_LIST_KEY] retain];

         // Compatibility for versions < V2.2
         if ( _originalImage == nil )
         {
            // Stack data
            if ( (stack = [decoder decodeObjectForKey:K_IMAGE_KEY]) != nil 
                 && [stack isKindOfClass:[LynkeosImageBuffer class]] )
            {
               _originalImage = [stack retain];
               _processedImage = stack;
               _size.width = [_originalImage width];
               _size.height = [_originalImage height];
               _nPlanes = [_originalImage numberOfPlanes];
            }
            // We don't even try to read stack from V1.0 .. V1.2 file as the 
            // endianness issues would be too hard to solve.
         }

         // Only global black and white for V2.1 and earlier
         if ( _originalImage != nil &&
              [decoder containsValueForKey:K_BLACK_LEVEL_KEY] &&
              [decoder containsValueForKey:K_WHITE_LEVEL_KEY] )
         {
            double vmin, vmax;
            u_short c;
            _black = (double*)malloc( sizeof(double)*(_nPlanes+1) );
            _white = (double*)malloc( sizeof(double)*(_nPlanes+1) );
            _gamma = (double*)malloc( sizeof(double)*(_nPlanes+1) );
            _black[_nPlanes] = [decoder decodeDoubleForKey:K_BLACK_LEVEL_KEY];
            _white[_nPlanes] = [decoder decodeDoubleForKey:K_WHITE_LEVEL_KEY];
            _gamma[_nPlanes] = [decoder decodeDoubleForKey:K_GAMMA_CORRECTION_KEY];
            if ( _gamma[_nPlanes] == 0.0 )
               _gamma[_nPlanes] = 1.0;

            [_originalImage getMinLevel:&vmin maxLevel:&vmax];
            for( c = 0; c < _nPlanes; c++ )
            {
               _black[c] = vmin;
               _white[c] = vmax;
               _gamma[c] = 1.0;
            }
         }

         [self connectParametersChain];
      }
      else
      {
         // File format is not compatible, abort loading
         [self release];
         self = nil;
      }
   }

   return( self );
}

//==============================================================================
// Initializers, Constructors and destructors
//==============================================================================
- (id)init
{
   if ( (self = [super init]) != nil )
   {
      _list = nil;
   }

   return self;
}

- (id) initWithArray :(NSArray*)list
{
   if ( (self = [self init]) != nil )
   {
      _list = [[list mutableCopy] retain];

      [self connectParametersChain];
   }

   return( self );
}

+ (id) imageListWithArray :(NSArray*)list
{
   return( [[[self alloc] initWithArray:list] autorelease] );
}

- (void) dealloc
{
   [_list release];

   [super dealloc];
}

//==============================================================================
// Read accessors
//==============================================================================
   // List
- (NSMutableArray*) imageArray { return( _list ); }

   // Enumerator access
- (id <LynkeosProcessableItem>) firstItem
{
   NSEnumerator* list = [self imageEnumeratorStartAt:nil
						  directSense:YES
                                               skipUnselected:YES];
   return( [list nextObject] );
}

- (id <LynkeosProcessableItem>) lastItem
{
   NSEnumerator* list = [self imageEnumeratorStartAt:nil
						  directSense:NO
                                               skipUnselected:YES];
   return( [list nextObject] );
}

- (NSEnumerator*)imageEnumerator
{
   return( [[[MyImageListEnumerator alloc] initWithImageList:_list] 
                                                                 autorelease] );
}

- (NSEnumerator*) imageEnumeratorStartAt:(id)item 
                                      directSense:(BOOL)direct
                                   skipUnselected:(BOOL)skip
{
   return( [[[MyImageListEnumerator alloc] initWithImageList:_list 
                                                     startAt:item
                                                 directSense:direct
                                              skipUnselected:skip]
            autorelease] );
}

- (NSEnumerator <LynkeosMultiPassEnumerator> *)
                                    multiPassImageEnumeratorStartAt:(id)item
                                                        directSense:(BOOL)direct
                                                     skipUnselected:(BOOL)skip
{
   return( [[[MyMultiPassImageEnumerator alloc] initWithImageList:_list
                                                          startAt:item
                                                      directSense:direct
                                                   skipUnselected:skip]
                                                                 autorelease] );
}

//==============================================================================
// Actions
//==============================================================================

- (BOOL) addItem :(MyImageListItem*)item
{
   if ( _list == nil )
      _list = [[NSMutableArray array] retain];

   [_list addObject: item];

   // Connect the parameters chain
   [item setParametersParent:_parameters];

   return( YES );
}

- (BOOL) deleteItem :(MyImageListItem*)item
{
   MyImageListItem *movie = [item getParent];
   if ( movie != nil )
   {
      NSAssert( [_list containsObject:movie], 
                @"Cannot delete from a nonexistent movie!" );
      [movie deleteChild:item];
      // Remove the movie when empty
      if ( [movie numberOfChildren] == 0 )
         [_list removeObject:movie];
   }
   else
   {
      NSAssert( [_list containsObject:item], 
                @"Cannot delete a nonexistent item!" );
      [_list removeObject:item];
   }

   // Clear the resulting image when list is emptied
   if ( [_list count] == 0 )
      [self setOriginalImage:nil];

   return( YES );
}

- (void) setMode:(ListMode_t)mode
{
   // Propagate the mode to the items in the list
   NSEnumerator *list = [_list objectEnumerator];
   MyImageListItem *item;

   while ( (item = [list nextObject]) != nil )
      [item setMode:mode];
}

#pragma mark LynkeosProcessable protocol

- (BOOL) changeItemSelection :(MyImageListItem*)item value:(BOOL)v
{
   if ( [item getSelectionState] == (v ? NSOnState : NSOffState) )
      return( NO );

   // Set the desired value
   [item setSelected:v];

   return( YES );
}

- (void) setParametersParent :(LynkeosProcessingParameterMgr*)parent
{
   if ( _parameters->_parent != nil )
      [_parameters->_parent release];
   _parameters->_parent = [parent retain];
}

- (void) setProcessingParameter:(id <LynkeosProcessingParameter>)parameter
                        withRef:(NSString*)ref 
                  forProcessing:(NSString*)processing
{
   [_parameters setProcessingParameter:parameter withRef:ref 
                         forProcessing:processing];

   // Propagate the dark frame and flat field down for optimisation
   if ( processing == nil
        && ( [ref isEqual:myImageListItemDarkFrame]
             || [ref isEqual:myImageListItemFlatField] ) )
   {
      NSEnumerator *list;
      MyImageListItem *item;

      list = [_list objectEnumerator];
      while( (item = [list nextObject]) != nil )
         [item setProcessingParameter:parameter withRef:ref 
                        forProcessing:processing];
   }

   // Notify of the change
   [_parameters notifyItemModification:self];
}

- (NSDictionary*) getMetaData
{
   return(nil);
}
@end
