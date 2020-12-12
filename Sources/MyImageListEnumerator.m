//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Sun Nov 30 2003.
//  Copyright (c) 2003-2014. Jean-Etienne LAMIAUD
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

#include "MyImageListEnumerator.h"

@implementation MyImageListEnumerator

- (id) init
{
   self = [super init];
   if ( self != nil )
   {
      _lock = [[NSRecursiveLock alloc] init];

      _itemList = nil;
      _listSize = 0;
      _step = 0;
      _skipUnselected = FALSE;
      _firstItem = nil;
   }

   return( self );
}

- (id) initWithImageList :(NSArray*)list startAt:(MyImageListItem*)item
              directSense:(BOOL)direct skipUnselected:(BOOL)skip
{
   if ( (self = [self init]) == nil )
      return( self );

   _itemList = [list retain];
   _listSize = [list count];
   _step = (direct ? 1 : -1);
   _skipUnselected = skip;
   _firstItem = item;

   if ( item != nil )
   {
      // Check that the item is in the list hierarchy
      MyImageListItem *parent, *topItem;
      for( parent = item, topItem = item;
           parent != nil ;
           parent = [topItem getParent] )
         topItem = parent;
      NSAssert( topItem != nil && [list containsObject:topItem],
                @"Initial item of enumerator is not in the list" );

      parent = [item getParent];
      if ( parent != nil )
      {
         NSAssert( [list indexOfObject:parent] != NSNotFound,
                   @"container is not present in the list" );
         NSAssert( [parent indexOfItem:item] != NSNotFound,
                   @"item is not present in the container" );
      }
   }

   [self reset];

   return( self );
}

- (id) initWithImageList :(NSArray*)list
{
   return( [self initWithImageList:list startAt:nil
                       directSense:YES skipUnselected:NO] );
}

- (void) dealloc
{
   [_lock release];
   [_itemList release];
   [super dealloc];
}

- (void) reset
{
   [_lock lock];

   if ( _firstItem != nil )
   {
      _currentContainer = [_firstItem getParent];
      if ( _currentContainer != nil )
      {
         _containerSize = [_currentContainer numberOfChildren];
         _itemIndex = [_itemList indexOfObject:_currentContainer];
         _itemIndexInContainer = [_currentContainer indexOfItem:_firstItem];

         if ( (_step > 0 && _itemIndexInContainer >= _containerSize-1) ||
             (_step < 0 && _itemIndexInContainer <= 0) )
         {
            _itemIndexInContainer = NSNotFound;
            if ( (_step > 0 && _itemIndex < _listSize-1) ||
                (_step < 0 && _itemIndex > 0) )
               _itemIndex += _step;
            else
               _itemIndex = NSNotFound;
         }
         else
            _itemIndexInContainer += _step;
      }
      else if ( (_containerSize = [_firstItem numberOfChildren]) != 0 )
      {
         _currentContainer = _firstItem;
         _itemIndex = [_itemList indexOfObject:_currentContainer];
         _itemIndexInContainer = (_step > 0 ? 0 : _containerSize-1);
      }
      else
      {
         _currentContainer = nil;
         _containerSize = 0;
         _itemIndex = [_itemList indexOfObject:_firstItem];
         if ( (_step > 0 && _itemIndex < _listSize-1) ||
             (_step < 0 && _itemIndex > 0) )
            _itemIndex += _step;
         else
            _itemIndex = NSNotFound;
         _itemIndexInContainer = NSNotFound;
      }
   }
   else
   {
      _currentContainer = nil;
      _containerSize = 0;
      _itemIndex = (_step > 0 ? 0 : _listSize-1);
      _itemIndexInContainer = NSNotFound;
   }

   [_lock unlock];
}

- (NSArray *) allObjects
{
   NSMutableArray *array = [NSMutableArray array];
   id item;

   [_lock lock];

   while ( (item = [self nextObject]) != nil )
      [array addObject:item];

   [_lock unlock];

   return( (NSArray*)array );
}

- (id) nextObject
{
   id item = nil;

   [_lock lock];

   while ( item == nil &&  _itemIndex != NSNotFound )
   {
      // Look for the next image item (inside a movie or self contained)
      if ( _currentContainer == nil || _itemIndexInContainer == NSNotFound )
      {
         // At first level
         item = [_itemList objectAtIndex:_itemIndex];
         if ( (_containerSize = [item numberOfChildren]) != 0 )
         {
            // First level item is a container, go down
            _currentContainer = item;
            item = nil;
            _itemIndexInContainer = (_step > 0 ? 0 : _containerSize-1);
         }

         else if ( (_step > 0 && _itemIndex < _listSize-1) ||
                   (_step < 0 && _itemIndex > 0) )
            _itemIndex += _step;

         else
            _itemIndex = NSNotFound;
      }

      if ( _currentContainer != nil )
      {
         // Inside a container
         if ( _itemIndexInContainer != NSNotFound )
         {
            item = [_currentContainer getChildAtIndex:_itemIndexInContainer];
            if ( (_step > 0 && _itemIndexInContainer < _containerSize-1) ||
                 (_step < 0 && _itemIndexInContainer > 0))
               _itemIndexInContainer += _step;
            else
               _itemIndexInContainer = NSNotFound;
         }
         if ( _itemIndexInContainer == NSNotFound )
         {
            if ( (_step > 0 && _itemIndex < _listSize-1) ||
                 (_step < 0 && _itemIndex > 0) )
               _itemIndex += _step;
            else
               _itemIndex = NSNotFound;
         }
      }

      // Do not iterate over unselected items if told so
      if ( _skipUnselected && item != nil &&
          [item getSelectionState] != NSOnState )
         item = nil;
   }

   [_lock unlock];

   return( item );
}

@end
