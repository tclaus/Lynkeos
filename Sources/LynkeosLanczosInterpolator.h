//
//  Lynkeos
//  $Id:$
//
//  Created by Jean-Etienne LAMIAUD on Tue Sep 18 2018.
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
 * @abstract Class for a Lanczos interpolator
 */

#ifndef __LYNKEOSLANCZOSINTERPOLATOR_H
#define __LYNKEOSLANCZOSINTERPOLATOR_H

#import <Cocoa/Cocoa.h>

#include "processing_core.h"
#include "LynkeosCore/LynkeosInterpolator.h"

extern const NSString *axParameters;
extern const NSString *ayParameters;
extern const NSString *scaleParameters;

@interface LynkeosLanczosInterpolator : NSObject <LynkeosInterpolator>
{
@private
   LynkeosImageBuffer* _image;
   u_short                     _numberOfPlanes;
   NSAffineTransform          *_inverseTransform;
   NSPoint                    *_offsets;
   NSPoint                     _origin;
   double                      _ax;
   double                      _ay;
   double                      _scale;
}
@end

#endif /* __LYNKEOSLANCZOSINTERPOLATOR_H */
