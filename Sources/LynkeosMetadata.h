//
//  Lynkeos
//  $Id: LynkeosCommon.h 452 2008-09-14 12:35:29Z j-etienne $
//
//  Created by Jean-Etienne LAMIAUD on Fri Jan 24 2014.
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

/*!
 * @header
 * @abstract Definition of metadata keys
 */

#ifndef Lynkeos_LynkeosMetadata_h
#define Lynkeos_LynkeosMetadata_h

#import <Foundation/Foundation.h>

// Capture info
extern const NSString *LynkeosMD_CameraModel(void);
extern const NSString *LynkeosMD_ExposureTime(void);
extern const NSString *LynkeosMD_Aperture(void);
extern const NSString *LynkeosMD_FocalLength(void);
extern const NSString *LynkeosMD_ISOSpeed(void);
extern const NSString *LynkeosMD_Telescope(void);
extern const NSString *LynkeosMD_CaptureDate(void);

// Copyrights and free comment
extern const NSString *LynkeosMD_Authors(void);
extern const NSString *LynkeosMD_Copyright(void);
extern const NSString *LynkeosMD_Comment(void);
extern const NSString *LynkeosMD_CreatorApp(void);

// Location (on earth)
extern const NSString *LynkeosMD_CaptureDateTime(void);
extern const NSString *LynkeosMD_Latitude(void);
extern const NSString *LynkeosMD_Longitude(void);
extern const NSString *LynkeosMD_Altitude(void);

// Location (in the sky)
extern const NSString *LynkeosMD_RightAscension(void);
extern const NSString *LynkeosMD_Declination(void);
extern const NSString *LynkeosMD_Epoch(void);

#endif
