//==============================================================================
//
//  Lynkeos
//
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Thu Jan 30 2014.
//  Copyright (c) 2014-2018. Jean-Etienne LAMIAUD
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
//------------------------------------------------------------------------------

#include "MyMultiPassImageEnumerator.h"

@implementation MyMultiPassImageEnumerator

- (id) init
{
   self = [super init];
   if ( self != nil )
   {
      _delegate = nil;
      _pass = 0; // It will be reset in superclass dedicated initializer
   }

   return( self );
}

- (void) reset
{
   [super reset];
   _pass ++;
   [[NSNotificationCenter defaultCenter] postNotificationName: LynkeosEnumeratorDidStartNewPass
                                                       object: self];
}
- (u_int) pass
{
   return( _pass );
}

- (void) setDelegate:(id <LynkeosMultiPassEnumeratorDelegate>)delegate
{
   _delegate = delegate;
}

- (id) nextObject
{
   id next;

   [_lock lock];

   next = [super nextObject];

   if ( next == nil && _delegate != nil && [_delegate shouldPerformOneMorePass:self] )
   {
      next = [NSNull null];
   }

   [_lock unlock];

   return( next );
}
@end
