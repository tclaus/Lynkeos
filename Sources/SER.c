//
//  Lynkeos
//  $Id: $
//
//  Created by Jean-Etienne LAMIAUD on Thu Sep 27 2018.
//
//  Copyright (c) 2018. Jean-Etienne LAMIAUD
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

#include <string.h>
#include "SER.h"

int SER_read_header(FILE *ser, SER_Header_t *hdr)
{
   // Read field by field, as they are not aligned on 32 bits boundaries
   size_t nread;
   int32_t value;

   nread = fread(&hdr->FileID, sizeof(char), SER_ID_LENGTH, ser);
   if (nread != SER_ID_LENGTH || memcmp(&hdr->FileID, "LUCAM-RECORDER", SER_ID_LENGTH))
      return(-1);

   nread = fread(&hdr->LuID, sizeof(int32_t), 1, ser);
   if (nread != 1)
      return(-1);

   nread = fread(&value, sizeof(int32_t), 1, ser);
   if (nread != 1)
      return(-1);
   hdr->ColorID = value;

   nread = fread(&value, sizeof(int32_t), 1, ser);
   if (nread != 1)
      return(-1);
   hdr->LittleEndian = value;

   nread = fread(&hdr->ImageWidth, sizeof(int32_t), 1, ser);
   if (nread != 1)
      return(-1);

   nread = fread(&hdr->ImageHeight, sizeof(int32_t), 1, ser);
   if (nread != 1)
      return(-1);

   nread = fread(&hdr->PixelDepthPerPlane, sizeof(int32_t), 1, ser);
   if (nread != 1)
      return(-1);

   nread = fread(&hdr->FrameCount, sizeof(int32_t), 1, ser);
   if (nread != 1)
      return(-1);

   hdr->Observer[SER_STRING_LENGTH] = '\0';
   nread = fread(&hdr->Observer, sizeof(char), SER_STRING_LENGTH, ser);
   if (nread != SER_STRING_LENGTH)
      return(-1);

   hdr->Instrument[SER_STRING_LENGTH] = '\0';
   nread = fread(&hdr->Instrument, sizeof(char), SER_STRING_LENGTH, ser);
   if (nread != SER_STRING_LENGTH)
      return(-1);

   hdr->Telescope[SER_STRING_LENGTH] = '\0';
   nread = fread(&hdr->Telescope, sizeof(char), SER_STRING_LENGTH, ser);
   if (nread != SER_STRING_LENGTH)
      return(-1);

   nread = fread(&hdr->DateTime, sizeof(int64_t), 1, ser);
   if (nread != 1)
      return(-1);

   nread = fread(&hdr->DateTime_UTC, sizeof(int64_t), 1, ser);
   if (nread != 1)
      return(-1);

   return(0);
}
