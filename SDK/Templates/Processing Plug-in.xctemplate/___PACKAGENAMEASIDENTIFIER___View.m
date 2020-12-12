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

#include "___PACKAGENAMEASIDENTIFIER___View.h"

@implementation ___PACKAGENAMEASIDENTIFIER___View

+ (BOOL) isStandardProcessingViewController
{
}

+ (ProcessingViewKind_t) processingViewKindForConfig:(id <NSObject>)config
{
}

+ (BOOL) isViewControllingProcess:(Class)processingClass
                       withConfig:(id <NSObject>*)config
{
}

+ (void) getProcessingTitle:(NSString**)title
                  toolTitle:(NSString**)toolTitle
                        key:(NSString**)key
                       icon:(NSImage**)icon
                        tip:(NSString**)tip
                  forConfig:(id <NSObject>)config
{
}

+ (unsigned int) allowedDisplaysForConfig:(id <NSObject>)config
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

- (id) initWithWindowController: (id <LynkeosWindowController>)window
                       document: (id <LynkeosViewDocument>)document
                  configuration: (id <NSObject>)config
{
   if ( (self = [self init]) != nil )
   {
   }

   return( self );
}

- (NSView*) getProcessingView
{
}

- (LynkeosProcessingViewFrame_t) preferredDisplay
{
}

- (Class) processingClass
{
}

- (void) setActiveView:(BOOL)active
{
}

- (id <LynkeosProcessingParameter>) getCurrentParameters
{
}

@end
