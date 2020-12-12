//
//  Lynkeos
//  $Id:  $
//
//  Created by Jean-Etienne LAMIAUD on Thu Aug 2 2018.
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
//
//  ProcessTestUtilities.h
//  Lynkeos
//
//  Created by Jean-Etienne LAMIAUD on 02/08/2018.
//

#ifndef __ProcessTestUtilities_h
#define __ProcessTestUtilities_h

#include "LynkeosFileReader.h"

extern void initializeProcessTests( void );

// Fake reader
@interface InterpolatorTestReader : NSObject <LynkeosImageFileReader>
{
}

+ (void) setImage:(LynkeosImageBuffer*)image;
@end

// Image generator polynomial
@interface TestImagePolynomial : NSObject
{
   CGPoint _firstZero;
   CGPoint _secondZero;
   CGPoint _factor;
   CGFloat _offset;
}

- (id) initWithFirstZero:(CGPoint)firstZero secondZero:(CGPoint)secondZero
                  factor:(CGPoint)factor offset:(CGFloat)offset;
- (double) valueAtPoint:(CGPoint)point;
@end

#endif /* __ProcessTestUtilities_h */
