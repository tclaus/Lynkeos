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

#import <CoreServices/CoreServices.h>
#include "LynkeosMetadata.h"

// Capture info
const NSString *LynkeosMD_CameraModel(void) { return (NSString*)kMDItemAcquisitionModel; }
const NSString *LynkeosMD_ExposureTime(void) { return (NSString*)kMDItemExposureTimeSeconds; }
const NSString *LynkeosMD_Aperture(void) { return (NSString*)kMDItemAperture; }
const NSString *LynkeosMD_FocalLength(void) { return (NSString*)kMDItemFocalLength; }
const NSString *LynkeosMD_ISOSpeed(void) { return (NSString*)kMDItemISOSpeed; }
const NSString *LynkeosMD_Telescope(void) { return (NSString*)kMDItemLensModel; }
const NSString *LynkeosMD_CaptureDate(void) {return (NSString*)kMDItemContentCreationDate; }

// Copyrights and free comment
const NSString *LynkeosMD_Authors(void) {return (NSString*)kMDItemAuthors;}
const NSString *LynkeosMD_Copyright(void) { return (NSString*)kMDItemCopyright; }
const NSString *LynkeosMD_Comment(void) { return (NSString*)kMDItemComment; }
const NSString *LynkeosMD_CreatorApp(void) { return (NSString*)kMDItemCreator; }

// Location (on earth)
const NSString *LynkeosMD_CaptureDateTime(void) { return (NSString*)kMDItemContentCreationDate; }
const NSString *LynkeosMD_Latitude(void) { return (NSString*)kMDItemLatitude; }
const NSString *LynkeosMD_Longitude(void) { return (NSString*)kMDItemLongitude; }
const NSString *LynkeosMD_Altitude(void) { return (NSString*)kMDItemAltitude; }

// Location (in the sky)
const NSString *LynkeosMD_RightAscension(void) { return @"RightAscension"; }
const NSString *LynkeosMD_Declination(void) { return @"Declination"; }
const NSString *LynkeosMD_Epoch(void) { return @"Epoch"; }
