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

/*!
 * @header
 * @abstract Multipass image enumerator
 */

#ifndef __MYMULTIPASSENUM_H
#define __MYMULTIPASSENUM_H

#include "MyImageListEnumerator.h"

/*!
 * @abstract An enumerator which can do multiple successive enumerations
 * @discussion When this enumerator reaches its end, it calls the delegate to determine if another pass is
 *           needed, in which case it returns a NSNull object until reset to start a new pass.
 */
@interface MyMultiPassImageEnumerator : MyImageListEnumerator
                                        <LynkeosMultiPassEnumerator>
{
   id <LynkeosMultiPassEnumeratorDelegate> _delegate;
   u_int    _pass;
}
@end

#endif
