//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on 03/01/11.
//  Copyright 2011-2020 Jean-Etienne LAMIAUD. All rights reserved.
//
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

#import <Cocoa/Cocoa.h>

#include "MyImageStacker.h"

/*!
 * @abstract Sigma reject strategy stacker
 * @discussion This stacking is performed in two pass, the first one computes
 *    the mean and standard deviation for each pixel, the second one
 *    excludes the pixels with values too far from the mean and performs a
 *    "regular" stacking with the remainig ones.
 */
@interface MyImageStacker_SigmaReject : NSObject
                                        <MyImageStackerModeStrategy>
{
   @private
   MyImageStackerParameters*   _params; //!< Stacking parameters
   LynkeosImageBuffer* _sum;    //!< Sum of images value
   LynkeosImageBuffer* _sum2;   //!< Sum of images square value
   u_short*                    _count;  //!< Buffer of pixel counts for pass 2
   id <LynkeosImageList>       _list;   //!< The list being stacked
   u_int                       _nbStacked; //!< Staked in this thread in pass 1
}

@end
