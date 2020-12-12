//
//  Lynkeos
//  $Id:$
//
//  Created by Jean-Etienne LAMIAUD on Fri Jul 13 2018.
//  Copyright (c) 2018-2020. Jean-Etienne LAMIAUD
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

/*!
 * @header
 * @abstract Class for a bicubic interpolator
 */

#ifndef __LYNKEOSBICUBICINTERPOLATOR_H
#define __LYNKEOSBICUBICINTERPOLATOR_H

#import <Cocoa/Cocoa.h>

#include "processing_core.h"
#include "LynkeosCore/LynkeosInterpolator.h"

@interface LynkeosBicubicInterpolator : NSObject <LynkeosInterpolator>
{
@private
   LynkeosImageBuffer* _image;
   u_short                     _numberOfPlanes;
   NSAffineTransform          *_inverseTransform;
   NSPoint                    *_offsets;
   NSPoint                     _origin;
   int                         _x;
   int                         _y;
   REALVECT                    _a[3][4];
}
@end

#endif /* __LYNKEOSBICUBICINTERPOLATOR_H */
