//
//  Lynkeos
//  ___PACKAGENAME___
//  $Id$
//
//  Created by ___FULLUSERNAME___ on ___DATE___.
//  ___COPYRIGHT___
//  From Lynkeos template
//  Copyright (c) 2013-2020. Jean-Etienne LAMIAUD
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

#include "___PACKAGENAMEASIDENTIFIER___.h"

@implementation ___PACKAGENAMEASIDENTIFIER___

+ (void) lynkeosFileTypes:(NSArray**)fileTypes
{
}

- (id) init
{
   if ( (self = [super init]) != nil )
   {
   }

   return( self );
}

- (void) dealloc
{

   [super dealloc];
}

- (id) initWithURL:(NSURL*)url
{
   if ( (self = [self init]) != nil )
   {
   }

   return( self );
}

- (void) imageWidth:(u_short*)w height:(u_short*)h
{
}

- (u_short) numberOfPlanes
{
}

- (void) getMinLevel:(double*)vmin maxLevel:(double*)vmax
{
}

- (NSDictionary*) getMetaData
{
}

- (NSImage*) getNSImage
{
}

- (void) getImageSample:(REAL * const * const)sample
             withPlanes:(u_short)nPlanes
                    atX:(u_short)x Y:(u_short)y W:(u_short)w H:(u_short)h
              lineWidth:(u_short)lineW
{
}

@end
