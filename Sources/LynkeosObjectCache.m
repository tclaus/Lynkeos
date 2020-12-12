//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Fri Mar 14 2008.
//  Copyright (c) 2008-2020. Jean-Etienne LAMIAUD
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

#include <LynkeosCore/LynkeosImageBuffer.h>
#include "LynkeosObjectCache.h"

//! Movie cache singleton instance
static LynkeosObjectCache *movieCache = nil;
//! Image processing cache singleton instance
static LynkeosObjectCache *imageProcessingCache = nil;

/*!
 * @abstract Private methods of LynkeosObjectCache
 */
@interface LynkeosObjectCache(Private)
//! Change the size of the memory strategy cache
- (void) adjustCacheSize ;
@end

@implementation LynkeosObjectCache(Private)
- (void) adjustCacheSize
{
   // Delete now obsolete object
   while ( (_capacityStrategy == CacheNumberOfObjects
            && [_keyAge count] >= _capacity) ||
          (_capacityStrategy == CacheMemorySize && _size >= _capacity) )
   {
      id cachedKey = [_keyAge objectAtIndex:0];
      LynkeosImageBuffer *cachedObj = [_cacheDict objectForKey:cachedKey];

      if ( _capacityStrategy == CacheMemorySize )
      {
         u_long objSize = [cachedObj memorySize];

         if ( objSize < _size )
            _size -= objSize;
         else
            _size = 0;
      }

      [_cacheDict removeObjectForKey:cachedKey];
      [_keyAge removeObjectAtIndex:0];
   }
}
@end

@implementation LynkeosObjectCache

+ (LynkeosObjectCache*) movieCache { return( movieCache ); }
+ (LynkeosObjectCache*) imageProcessingCache { return( imageProcessingCache ); }

+ (void) setMovieCache:(LynkeosObjectCache*)cache
{
   NSAssert( movieCache == nil || cache == nil,
             @"Duplicate creation of the movie cache" );
   if ( movieCache != nil )
      [movieCache release];
   if ( cache != nil )
      [cache retain];
   movieCache = cache;
}

+ (void) setImageProcessingCache:(LynkeosObjectCache*)cache
{
   NSAssert( imageProcessingCache == nil || cache == nil,
            @"Duplicate creation of the image processing cache" );
   if ( imageProcessingCache != nil )
      [imageProcessingCache release];
   if ( cache != nil )
      [cache retain];
   imageProcessingCache = cache;
}

- (id) initWithStrategy:(CacheCapacityStrategy_t)strategy
               capacity:(u_long)capacity policy:(u_short)policy
{
   if ( (self = [self init]) != nil )
   {
      u_long initialCapacity;

      _capacityStrategy = strategy;
      if ( strategy == CacheNumberOfObjects )
         initialCapacity = capacity+1;
      else
         initialCapacity = 1;
      _cacheDict =
          [[NSMutableDictionary dictionaryWithCapacity:initialCapacity] retain];
      _keyAge = [[NSMutableArray arrayWithCapacity:initialCapacity] retain];
      _capacity = capacity;
      _policy = policy;
      _size = 0;
   }

   return( self );
}

- (void) dealloc
{
   [_cacheDict release];
   [_keyAge release];

   [super dealloc];
}

- (void) setObject:(NSObject*)obj forKey:(id)key
{
   NSUInteger keyIdx;

   if ( _capacityStrategy == CacheMemorySize )
      NSAssert( [obj isKindOfClass:[LynkeosImageBuffer class]],
                @"Inconsistent object for memory size cache strategy" );

   // Put the object in the dictionary
   [_cacheDict setObject:obj forKey:key];

   // If the key is not already known
   keyIdx = [_keyAge indexOfObject:key];
   if ( keyIdx == NSNotFound )
   {
      // Add it to the keys array
      [_keyAge addObject:key];

      // Update cache size for memory strategy
      if ( _capacityStrategy == CacheMemorySize )
         _size += [(LynkeosImageBuffer*)obj memorySize];

      // If the cache is full,
      // delete the oldest objects to restore the cache capacity
      [self adjustCacheSize];
   }
   else
   {
      // Otherwise, change keys order according to policy
      if ( _policy & WriteRefresh )
      {
         [_keyAge addObject:key];
         [_keyAge removeObjectAtIndex:keyIdx];
      }
   }
}

- (NSObject*) getObjectForKey:(id)key
{
   // Find the object if still in the cache
   NSObject *obj = [_cacheDict objectForKey:key];

   // Change keys order according to policy
   if ( obj != nil && (_policy & ReadRefresh) )
   {
      NSUInteger keyIdx = [_keyAge indexOfObject:key];
      [_keyAge addObject:key];
      [_keyAge removeObjectAtIndex:keyIdx];
   }

   return( obj );
}

- (void) removeObjectForKey:(id)key
{
   [_cacheDict removeObjectForKey:key];
   NSUInteger keyIdx = [_keyAge indexOfObject:key];
   if ( keyIdx != NSNotFound )
      [_keyAge removeObjectAtIndex:keyIdx];
}

- (void) setCapacity:(u_long)capacity
{
   _capacity = capacity;

   // Delete now obsolete object
   [self adjustCacheSize];
}
@end
