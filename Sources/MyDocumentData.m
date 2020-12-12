//
//  Lynkeos 
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Thu Jul 29 2004.
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

#include "MyDocumentData.h"

// Common keys
#define K_DATA_REVISION_KEY     @"revision"
#define K_OBJECT_LIST_KEY	@"object"
#define K_DARK_FRAME_LIST_KEY   @"darkframes"
#define K_FLAT_FIELD_LIST_KEY   @"flatfields"
#define K_WINDOW_SIZES_KEY      @"window sizes"

//==============================================================================
// V2 file format
//==============================================================================
#define K_PARAMETERS_KEY        @"params" //!< Key for saving the parameters

@implementation MyDocumentDataV2

- (void)encodeWithCoder:(NSCoder *)encoder
{
   [encoder encodeInt:K_DATA_REVISION forKey:K_DATA_REVISION_KEY];

   [encoder encodeObject:_imageList forKey:K_OBJECT_LIST_KEY];
   [encoder encodeObject:_darkFrameList forKey:K_DARK_FRAME_LIST_KEY];
   [encoder encodeObject:_flatFieldList forKey:K_FLAT_FIELD_LIST_KEY];
   [encoder encodeObject:_parameters forKey:K_PARAMETERS_KEY];
   [encoder encodeObject:_windowSizes forKey:K_WINDOW_SIZES_KEY];
}

- (id)initWithCoder:(NSCoder *)decoder
{
   if ( [decoder containsValueForKey:K_OBJECT_LIST_KEY] )
   {
      _formatRevision = [decoder decodeIntForKey:K_DATA_REVISION_KEY];

      _imageList = [[decoder decodeObjectForKey:K_OBJECT_LIST_KEY] retain];
      [_imageList setMode:ImageMode];
      _darkFrameList
         = [[decoder decodeObjectForKey:K_DARK_FRAME_LIST_KEY] retain];
      [_darkFrameList setMode:DarkFrameMode];
      _flatFieldList
         = [[decoder decodeObjectForKey:K_FLAT_FIELD_LIST_KEY] retain];
      [_flatFieldList setMode:FlatFieldMode];
      _parameters = [[decoder decodeObjectForKey:K_PARAMETERS_KEY] retain];

      _windowSizes = [[decoder decodeObjectForKey:K_WINDOW_SIZES_KEY] retain];

      return( self );
   }
   else
   {
      [self release];
      return( nil );
   }
}

// No override of dealloc since this class only contains references to objects
// later owned by the document
@end
