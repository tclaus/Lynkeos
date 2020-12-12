//
//  Lynkeos
//  $Id:$
//
//  Created by Jean-Etienne LAMIAUD on Fri Oct 20 2017.
//  Copyright (c) 2017-2018. Jean-Etienne LAMIAUD
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

#import <Foundation/Foundation.h>

#include "LynkeosInterpolator.h"
#include "MyPluginsController.h"

static NSDictionary *namedInterpolator = nil;

@implementation LynkeosInterpolatorManager

+ (Class) interpolatorWithScaling:(Scaling_t)scaling transform:(NSAffineTransformStruct)transform
{
   // Iterate on known interpolators, and select the (autodeclared) best
   int bestScore = 0;
   Class bestInterpolator = nil;
   NSEnumerator *interpolators
      = [[[MyPluginsController defaultPluginController] getInterpolators] objectEnumerator];
   Class interpolator;
   while ((interpolator = [interpolators nextObject]) != nil)
   {
      int score = [interpolator isCompatibleWithScaling:scaling
                                          withTransform:transform];
//      NSLog(@"%@ interpolator score is %d", [interpolator name], score);
      if (score > bestScore)
      {
         bestScore = score;
         bestInterpolator = interpolator;
      }
   }

   return(bestInterpolator);
}

+ (Class) interpolatorWithName:(NSString*)name
{
   if ( namedInterpolator == nil )
   {
      NSMutableDictionary *interpolatorDict = [[NSMutableDictionary alloc] init];
      NSEnumerator *interpolators
         = [[[MyPluginsController defaultPluginController] getInterpolators] objectEnumerator];
      Class interpolator;

      while ((interpolator = [interpolators nextObject]) != nil)
      {
         [interpolatorDict setObject:interpolator forKey:[interpolator name]];
      }

      namedInterpolator = interpolatorDict;
   }

   return( [namedInterpolator objectForKey:name] );
}

@end
