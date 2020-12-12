//
//  Lynkeos
//  $Id: $
//
//  Created by Jean-Etienne LAMIAUD on Thu Oct 18 2018.
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
 * @abstract Reader for SER movie format.
 */

#ifndef __SER_IMAGEBUFFER_H
#define __SER_IMAGEBUFFER_H

#include "LynkeosImageBuffer.h"
#include "SER.h"

NS_ASSUME_NONNULL_BEGIN

@interface SER_ImageBuffer : LynkeosImageBuffer
{
   @public
   LynkeosImageBuffer *_weight;
   double              _accumulations;
   BOOL                _substractive;
}

- (id) initWithData:(REAL*)data format:(ColorID_t)format
              width:(u_short)width lineW:(u_short)lineW height:(u_short)height
                atX:(u_short)x Y:(u_short)y W:(u_short)w H:(u_short)h
      withTransform:(NSAffineTransformStruct)transform
        withOffsets:(const NSPoint*)offsets
           withDark:(SER_ImageBuffer*)dark withFlat:(LynkeosImageBuffer*)flat;
@end

NS_ASSUME_NONNULL_END

#endif
