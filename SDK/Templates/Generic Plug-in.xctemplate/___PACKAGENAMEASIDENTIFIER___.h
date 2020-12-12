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

#ifndef _____PROJECTNAMEASIDENTIFIER____H
#define _____PROJECTNAMEASIDENTIFIER____H

#import <Cocoa/Cocoa.h>

// Delete the include files which you do not need
#include <LynkeosCore/LynkeosFileReader.h>
#include <LynkeosCore/LynkeosFileWriter.h>
#include <LynkeosCore/LynkeosProcessing.h>
#include <LynkeosCore/LynkeosProcessingView.h>
#include <LynkeosCore/LynkeosPreferences.h>

@interface ___PACKAGENAMEASIDENTIFIER___ : NSObject
// Keep only one protocol (the one suited to the plugin you want to create) in
// this class declaration
                           <LynkeosImageFileReader,
                            LynkeosMovieFileReader,
                            LynkeosImageFileWriter,
                            LynkeosMovieFileWriter,
                            LynkeosProcessing,
                            LynkeosProcessingView,
                            LynkeosPreferences>
{

}


@end

#endif /* _____PACKAGENAMEASIDENTIFIER____H */
