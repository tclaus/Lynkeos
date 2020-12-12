//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Sun Dec 12 2005.
//  Copyright (c) 2005-2020. Jean-Etienne LAMIAUD
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
 * @abstract Image alignment process implementation
 */
#include <objc/runtime.h>
#include <Accelerate/Accelerate.h>

#include "processing_core.h"
#include "corelation.h"
#include "LynkeosImageBufferAdditions.h"

#include "LynkeosBasicAlignResult.h"

#include "MyImageAlignerPrefs.h"
#include "MyImageAligner.h"

// Debug
//#include "MyTiffWriter.h"
//#include "MyImageListItem.h"

NSString * const myImageAlignerRef = @"MyImageAligner";
NSString * const myImageAlignerParametersRef = @"AlignParams";

#define K_ALIGN_ORIGINS_KEY @"origins" //!< Array of specific origins
#define K_ALIGN_SQUARES_KEY @"squares" //!< Array of all alignment squares
#define K_ALIGN_ORIGIN_KEY    @"origin"    ///< Key for saving the square origin
#define K_ALIGN_SIZE_KEY      @"size"        ///< Key for saving the square size
#define K_ALIGN_DARKFRAME_KEY @"dark"        ///< Key for saving dark frame ref
#define K_ALIGN_FLATFIELD_KEY @"flat"        ///< Key for saving flat field ref
#define K_ALIGN_REF_KEY       @"refitem"  ///< Key for saving the reference item
#define K_ALIGN_CUTOFF_KEY    @"cutoff" ///< Key for saving the cutoff threshold
//! Key for saving the align precision threshold
#define K_ALIGN_PRECISION_KEY @"precision"

// V2 compatibility classes
/*!
 * @abstract General entry parameters for alignment (V2 file compatibility)
 * @ingroup Processing
 */
@interface MyImageAlignerParameters : NSObject <LynkeosProcessingParameter>
{
}
@end

/*!
 * @abstract Alignment parameters saved at the document level (V2 file compatibility)
 * @ingroup Processing
 */
@interface MyImageAlignerListParameters : MyImageAlignerParameters
{
}
@end

//==============================================================================
// Generic processing functions
//==============================================================================

/*!
 * Cut the highest frequencies from the spectrum to suppress noise
 */
static void cutoffSpectrum( LynkeosFourierBuffer *spectrum, u_short cutoff )
{
   u_short x, y;
   u_short h_2 = spectrum->_h/2;
   u_long cut2 = cutoff*cutoff;

   // Save time if there is no cutoff at all
   if ( cutoff >= sqrt(spectrum->_w*spectrum->_w+spectrum->_h*spectrum->_h) )
      return;

   for ( y = 0; y < spectrum->_h; y++ )
   {
      for ( x = 0; x < spectrum->_halfw; x++ )
      {
         short dx = x, dy = y;
         u_long f2; 
         if ( dy >= h_2 )
            dy -= spectrum->_h;
         f2 = dx*dx + dy*dy;

         if ( f2 > cut2 )
         {
            u_char c;

            for( c = 0; c < spectrum->_nPlanes; c++ )
               colorComplexValue(spectrum,x,y,c) = 0.0;
         }
      }
   }
}

static BOOL performAlignment( id <LynkeosProcessableItem> item,
                              LynkeosIntegerRect extractRect,
                              LynkeosFourierBuffer *buf,
                              LynkeosFourierBuffer *ref,
                              double cutoff,
                              double sigmaThreshold,
                              double valueThreshold,
                              CORRELATION_PEAK *peak )
{
   // Get the spectrum of that other image
   [item getFourierTransform:&buf forRect:extractRect prepareInverse:NO];
   cutoffSpectrum( buf, cutoff );

   // correlate it against the reference
   correlate_spectrums( ref, buf, buf );
   corelation_peak( buf, peak );

   return( peak->val >= valueThreshold &&
           peak->sigma_x < sigmaThreshold && peak->sigma_y < sigmaThreshold );
}

NSArray* itemAlignSquares(id <LynkeosProcessableItem> item,
                          MyImageAlignerListParametersV3* params)
{
   NSMutableArray *squares = [[NSMutableArray alloc ] initWithArray:params->_alignSquares
                                                          copyItems:YES];
   MyImageAlignerImageParametersV3 *itemOrigins
      = [item getProcessingParameterWithRef:myImageAlignerParametersRef
                              forProcessing:myImageAlignerRef];

   if ( itemOrigins != nil
       && [itemOrigins isMemberOfClass:[MyImageAlignerImageParametersV3 class]] )
   {
      NSEnumerator *originsList = [itemOrigins->_alignSquares objectEnumerator];
      NSInteger index = 0;
      MyImageAlignerOriginV3 *origin;

      while ( (origin = [originsList nextObject]) != nil )
      {
         if ( [origin isMemberOfClass:[MyImageAlignerOriginV3 class]] )
         {
            // Override the root parameter origin with the item's one
            MyImageAlignerSquareV3 *s = [squares objectAtIndex:index];

            s->_alignOrigin = origin->_alignOrigin;
         }

         index++;
      }
   }

   return( (NSArray*)squares );
}

@implementation MyImageAlignerOriginV3
- (id) init
{
   self = [super init];
   if ( self != nil )
   {
      _alignOrigin.x = 0;
      _alignOrigin.y = 0;
   }

   return( self );
}

- (id) initWithCoder:(NSCoder*)decoder
{
   self = [self init];

   if ( self != nil )
      _alignOrigin = LynkeosIntegerPointFromNSPoint
                        ([decoder decodePointForKey:K_ALIGN_ORIGIN_KEY]);

   return( self );
}

- (id) copyWithZone:(NSZone *)zone
{
   MyImageAlignerOriginV3 *newOrigin = [[self class] allocWithZone:zone];

   newOrigin->_alignOrigin = _alignOrigin;

   return( newOrigin );
}

- (void) encodeWithCoder:(NSCoder*)encoder
{
   [encoder encodePoint: NSPointFromIntegerPoint(_alignOrigin)
                 forKey: K_ALIGN_ORIGIN_KEY];
}
@end

@implementation MyImageAlignerSquareV3
- (id) init
{
   self = [super init];
   if ( self != nil )
   {
      _alignSize.width = 0;
      _alignSize.height = 0;
   }

   return( self );
}

- (id)initWithCoder:(NSCoder *)decoder
{
   self = [super initWithCoder:decoder];

   if ( self != nil )
      _alignSize = LynkeosIntegerSizeFromNSSize
                      ([decoder decodeSizeForKey:K_ALIGN_SIZE_KEY]);

   return( self );
}

- (id) copyWithZone:(NSZone *)zone
{
   MyImageAlignerSquareV3 *newSquare = [super copyWithZone:zone];

   newSquare->_alignSize = _alignSize;

   return( newSquare );
}

- (void) encodeWithCoder:(NSCoder*)encoder
{
   [super encodeWithCoder:encoder];

   [encoder encodeSize: NSSizeFromIntegerSize(_alignSize)
                forKey: K_ALIGN_SIZE_KEY];
}
@end

@implementation MyImageAlignerImageParametersV3
- (id) init
{
   self = [super init];
   if ( self != nil )
      _alignSquares = [[NSMutableArray array] retain];

   return( self );
}

- (id)initWithCoder:(NSCoder *)decoder
{
   self = [self init];

   if ( self != nil )
   {
      if ([decoder containsValueForKey:K_ALIGN_ORIGINS_KEY])
      {
         _alignSquares = [[decoder decodeObjectForKey:K_ALIGN_ORIGINS_KEY] retain];
      }
      else
      {
         if ( [decoder containsValueForKey:K_ALIGN_ORIGIN_KEY] )
         {
            MyImageAlignerOriginV3 *o = [[[MyImageAlignerOriginV3 alloc] init] autorelease];
            o->_alignOrigin = LynkeosIntegerPointFromNSPoint([decoder decodePointForKey:K_ALIGN_ORIGIN_KEY]);

            [_alignSquares addObject:o];
         }
      }
   }

   return( self );
}

- (void) dealloc
{
   [_alignSquares release];
   [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
   [encoder encodeObject:_alignSquares forKey:K_ALIGN_ORIGINS_KEY];
}
@end

@implementation MyImageAlignerSquareData
- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _referenceOrigin = LynkeosMakeIntegerPoint(0, 0);

      _cutoff = 0.0;
      _precisionThreshold = 0.0;
      _valueThreshold = 0.0;

      _referenceSpectrum = nil;
   }

   return( self );
}

- (void) dealloc
{
   if ( _referenceSpectrum != nil )
      [_referenceSpectrum release];

   [super dealloc];
}
@end

@implementation MyImageAlignerListParametersV3
- (id) init
{
   self = [super init];
   if ( self != nil )
   {
      _alignSquares = [[NSMutableArray array] retain];
      _referenceItem = nil;
      _alignLock = [[NSLock alloc] init];
      _dataReady = FALSE;
      _squaresData = [[NSMutableArray array] retain];
      _cutoff = 0.0;
      _precisionThreshold = 0.0;
      _checkAlignResult = NO;
      _computeRotation = NO;
      _computeScale = NO;
   }

   return( self );
}

- (void) dealloc
{
   [_alignLock release];
   [_squaresData release];

   [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
   [encoder encodeObject:_alignSquares forKey: K_ALIGN_SQUARES_KEY];
   [encoder encodeConditionalObject:_referenceItem forKey:K_ALIGN_REF_KEY];
}

- (id) initWithCoder:(NSCoder *)decoder
{
   self = [self init];

   if ( self != nil )
   {
      if ([decoder containsValueForKey:K_ALIGN_SQUARES_KEY])
      {
         _alignSquares = [[decoder decodeObjectForKey:K_ALIGN_SQUARES_KEY] retain];
         _referenceItem = [[decoder decodeObjectForKey:K_ALIGN_REF_KEY] retain];
      }
      else
      {
         MyImageAlignerSquareV3 *square = [[[MyImageAlignerSquareV3 alloc] init] autorelease];
         BOOL hasSquare = NO;

         if ( [decoder containsValueForKey:K_ALIGN_ORIGIN_KEY] )
         {
            square->_alignOrigin
               = LynkeosIntegerPointFromNSPoint([decoder decodePointForKey:K_ALIGN_ORIGIN_KEY]);
            hasSquare = YES;
         }
         if ( [decoder containsValueForKey:K_ALIGN_SIZE_KEY] )
         {
            square->_alignSize
               = LynkeosIntegerSizeFromNSSize([decoder decodeSizeForKey:K_ALIGN_SIZE_KEY]);
            hasSquare = YES;
         }

         if ( hasSquare )
            [_alignSquares addObject:square];

         _referenceItem = [[decoder decodeObjectForKey:K_ALIGN_REF_KEY] retain];
      }
   }

   return( self );
}
@end

// V2 compatibility classes
@implementation MyImageAlignerParameters
- (id)initWithCoder:(NSCoder *)decoder
{
   // Release this object, and return a MyImageAlignerImageParametersV3 instead
   [self release];
   self = (MyImageAlignerParameters*)[[MyImageAlignerImageParametersV3 alloc] initWithCoder:decoder];

   return( self );
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
   [self doesNotRecognizeSelector:_cmd];
}
@end

@implementation MyImageAlignerListParameters
- (id) initWithCoder:(NSCoder *)decoder
{
   // Release this object, and return a MyImageAlignerListParametersV3 instead
   [self release];
   self = (MyImageAlignerListParameters*)[[MyImageAlignerListParametersV3 alloc] initWithCoder:decoder];

   return( self );
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
   [self doesNotRecognizeSelector:_cmd];
}
@end

@implementation MyImageAligner

+ (ParallelOptimization_t) supportParallelization
{
   return( [[NSUserDefaults standardUserDefaults] integerForKey:
                                                         K_PREF_ALIGN_MULTIPROC]
           & ListThreadsOptimizations);
}

- (id <LynkeosProcessing>) initWithDocument:(id <LynkeosDocument>)document
                                 parameters:(id <NSObject>)params
{
   self = [self init];
   if ( self == nil )
      return( self );

   _document = document;
   NSAssert1( [params isMemberOfClass:[MyImageAlignerListParametersV3 class]],
              @"Wrong parameter class %s for Image Aligner",
              class_getName([params class]) );
   _rootParams = (MyImageAlignerListParametersV3*)[params retain];

   // Prepare the squares related data in only one thread
   if ( [_rootParams->_alignLock tryLock] )
   {
      if ( [_rootParams->_squaresData count] == 0 )
      {
         // Get the squares for the reference item
         NSArray *squares = itemAlignSquares(_rootParams->_referenceItem, _rootParams);
         NSEnumerator *squaresList = [squares objectEnumerator];
         MyImageAlignerSquareV3 *square;

         // Fill align square related data for all align points
         while ( (square = [squaresList nextObject]) != nil )
         {
            MyImageAlignerSquareData *data
               = [[[MyImageAlignerSquareData alloc] init] autorelease];
            LynkeosFourierBuffer *refSpectrum;
            LynkeosIntegerRect r;

            // Allocate the reference spectrum
            refSpectrum
               = [[LynkeosFourierBuffer fourierBufferWithNumberOfPlanes:1
                                       width:square->_alignSize.width
                                      height:square->_alignSize.height
                                    withGoal:FOR_DIRECT|FOR_INVERSE] retain];

            r.origin = square->_alignOrigin;
            r.size = square->_alignSize;

            // Take any previous alignment into account
            LynkeosBasicAlignResult *align = (LynkeosBasicAlignResult*)
                  [_rootParams->_referenceItem getProcessingParameterWithRef:
                                                           LynkeosAlignResultRef
                                                 forProcessing:LynkeosAlignRef];
            if ( align != nil )
            {
               // Apply alignment to the align square center
               NSPoint p = NSMakePoint(
                              (CGFloat)r.origin.x + (CGFloat)r.size.width/2.0,
                              (CGFloat)r.origin.y + (CGFloat)r.size.height/2.0);
               p = [[align alignTransform] transformPoint:p];
               r.origin.x = (short)floor(p.x - (CGFloat)r.size.width/2.0 + 0.5);
               r.origin.y = (short)floor(p.y - (CGFloat)r.size.height/2.0 + 0.5);
            }

            data->_referenceOrigin = r.origin;

            // Convert the coordinate system from Cocoa to bitmap
            r.origin.y = [_rootParams->_referenceItem imageSize].height
                         - r.origin.y - r.size.height;

            // Get the sample
            [_rootParams->_referenceItem getImageSample:&refSpectrum
                                                 inRect:r];
            // Calculate the minimum valid correlation peak height
            double vmin, vmax;
            [refSpectrum getMinLevel:&vmin maxLevel:&vmax];
            data->_valueThreshold = (vmax-vmin)*(vmax-vmin);
            // Get the spectrum
            [refSpectrum directTransform];

            // Cut the highest frequencies
            data->_cutoff = _rootParams->_cutoff*square->_alignSize.width;
            cutoffSpectrum( refSpectrum, data->_cutoff );

            // The spectrum is ready to be shared
            data->_referenceSpectrum = refSpectrum;

            data->_precisionThreshold = _rootParams->_precisionThreshold
                                        * square->_alignSize.width;

            [_rootParams->_squaresData addObject:data];
         }
         _rootParams->_dataReady = [_rootParams->_squaresData count] != 0;
      }
      // Else, nothing to do : we got the lock but squares data was already initialized

      [_rootParams->_alignLock unlock];
   }
   else // Initialization is under way, wait for it to end
   {
      [_rootParams->_alignLock lock];
      [_rootParams->_alignLock unlock];
      // Now squares data is initialized
   }
   // From now on, squares data is initialized
   NSAssert(_rootParams->_dataReady, @"Inconsistent alignment data initialization");

   // Allocate a buffer per align point for each other images
   _spectrumBuffers = [[NSMutableArray arrayWithCapacity:
                                             [_rootParams->_alignSquares count]]
                       retain];
   NSEnumerator *squaresList = [_rootParams->_alignSquares objectEnumerator];
   MyImageAlignerSquareV3 *square;
   while ( (square = [squaresList nextObject]) != nil )
   {
      [_spectrumBuffers addObject:
         [LynkeosFourierBuffer fourierBufferWithNumberOfPlanes:1
                                                 width:square->_alignSize.width
                                                height:square->_alignSize.height
                                              withGoal:FOR_DIRECT|FOR_INVERSE]];
   }

   return( self );
}

- (void) dealloc
{
   [_spectrumBuffers release];
   // The view part takes care of emptying the squares data at processing end
   [_rootParams release];

   [super dealloc];
}

- (void) processItem:(id <LynkeosProcessableItem>)item
{
   LynkeosBasicAlignResult *res = nil;

   NSAssert(_rootParams->_dataReady, @"Inconsistent alignment data initialization");

   if ( item == _rootParams->_referenceItem )
   {
      // Set the reference item to 0,0 offset, no rotation, no scaling
      res = [[[LynkeosBasicAlignResult alloc] init] autorelease];
   }
   else
   {
      // Get the align squares for the item
      NSArray *squares = itemAlignSquares(item, _rootParams);
      NSEnumerator *squaresList = [squares objectEnumerator];
      MyImageAlignerSquareV3 *square;
      // Prepare for alignment on every point
      const int nPoints = (int)[squares count];
      NSEnumerator *squaresDataList = [_rootParams->_squaresData objectEnumerator];
      NSEnumerator *bufferList = [_spectrumBuffers objectEnumerator];
      NSPoint refMatrix[nPoints], resultMatrix[nPoints];
      NSPoint refBarycenter= {0, 0}, resBarycenter = {0, 0};
      int nbResults = 0;
      NSAffineTransformStruct m = {1.0, 0.0, 0.0, 1.0, 0.0, 0.0};

      // Process the alignment for all align points
      while ( (square = [squaresList nextObject]) != nil )
      {
         MyImageAlignerSquareData *data = [squaresDataList nextObject];
         LynkeosIntegerRect r;

         NSAssert(data != nil, @"No data for square");

         // Retrieve the alignment rectangle for the item
         r.origin = square->_alignOrigin;
         r.size = square->_alignSize;

         // Take any previous alignment into account
         LynkeosBasicAlignResult *align = (LynkeosBasicAlignResult*)
         [item getProcessingParameterWithRef:LynkeosAlignResultRef
                               forProcessing:LynkeosAlignRef];
         if ( align != nil )
         {
            // Apply alignment to the align square center
            NSPoint p = NSMakePoint((CGFloat)r.origin.x + (CGFloat)r.size.width/2.0,
                                    (CGFloat)r.origin.y + (CGFloat)r.size.height/2.0);
            NSAffineTransform *t
               = [[[NSAffineTransform alloc] initWithTransform: [align alignTransform]]
                  autorelease];

            [t invert];
            p = [t transformPoint:p];
            r.origin.x = (short)floor(p.x - (CGFloat)r.size.width/2.0 + 0.5);
            r.origin.y = (short)floor(p.y - (CGFloat)r.size.height/2.0 + 0.5);
         }
         
         LynkeosIntegerRect extractRect;
         CORRELATION_PEAK peak;
         BOOL isAligned;

         // correlate it against the reference
         LynkeosFourierBuffer *buf = [bufferList nextObject];
         NSAssert(buf != nil, @"No buffer for square");

         extractRect = r;
         extractRect.origin.y = [item imageSize].height - extractRect.origin.y
                                - extractRect.size.height;
         isAligned = performAlignment( item, extractRect, buf,
                                      data->_referenceSpectrum, data->_cutoff,
                                      data->_precisionThreshold,
                                      data->_valueThreshold, &peak );

         if ( isAligned && _rootParams->_checkAlignResult )
         {
            // Verify the alignment and flip it if needed
            BOOL alignChecked = NO;
            double ox, oy;
            for( oy = 0.0;
                 !alignChecked && oy <= r.size.width;
                 oy += r.size.width )
            {
               for( ox = 0.0;
                    !alignChecked && ox <= r.size.width;
                    ox += r.size.width )
               {
                  CORRELATION_PEAK checkPeak;
                  NSPoint flippedPeak;
                  LynkeosIntegerPoint shift;
                  LynkeosIntegerRect checkRect = extractRect;

                  // Realign with a rectangle adjusted by the (flipped) result
                  if ( peak.x >= 0.0 )
                  {
                     flippedPeak.x = peak.x - ox;
                     shift.x = (int)(-flippedPeak.x - 1);
                  }
                  else
                  {
                     flippedPeak.x = peak.x + ox;
                     shift.x = (int)(-flippedPeak.x);
                  }
                  if ( peak.y >= 0.0 )
                  {
                     flippedPeak.y = peak.y - oy;
                     shift.y = (int)(-flippedPeak.y - 1);
                  }
                  else
                  {
                     flippedPeak.y = peak.y + oy;
                     shift.y = (int)flippedPeak.y;
                  }
                  checkRect.origin.x += shift.x;
                  checkRect.origin.y += shift.y;
                  alignChecked = performAlignment( item, checkRect,
                                                   buf, data->_referenceSpectrum,
                                                   data->_cutoff,
                                                   data->_precisionThreshold,
                                                   data->_valueThreshold,
                                                   &checkPeak );
                  if ( alignChecked )
                  {
                     // Verify that the new peak is the residual of the
                     // (flipped) one
                     if ( fabs(checkPeak.x - (double)shift.x
                               - flippedPeak.x) >= 0.5
                         || fabs(checkPeak.y - (double)shift.y
                                 - flippedPeak.y) >= 0.5 )
                        // Alas! this alignment is not consistent
                        isAligned = NO;
                     else
                     {
                        // Adjust the result
                        peak.x = checkPeak.x - (double)shift.x;
                        peak.y = checkPeak.y - (double)shift.y;
                     }
                  }
               }
            }
         }

#if 0 // Debug code
         if ( !isAligned || [[(MyImageListItem*)item index] intValue] == 0)
         {
            LynkeosImageBuffer *img = nil;
            if ( !isAligned )
            {
               NSLog(@"Failed to align image %d", [[(MyImageListItem*)item index] intValue]);
               // Save the extracted image
               [item getImageSample:&img inRect:extractRect];
               [img multiplyWithScalar:1.0/255.0];
               NSURL *squareURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"misalignedSquare%06d.tif", [[(MyImageListItem*)item index] intValue]]];
               MyTiffWriter *writer = (MyTiffWriter*)[MyTiffWriter writerForURL:squareURL
                                                                         planes:img->_nPlanes
                                                                          width:img->_w
                                                                         height:img->_h
                                                                       metaData:nil];
               [writer saveImageAtURL:squareURL withData:(const REAL * const *)[img colorPlanes]
                           blackLevel:0.0 whiteLevel:255.0 withPlanes:img->_nPlanes
                                width:img->_w lineWidth:img->_padw height:img->_h metaData:nil];
            }
         }
#endif

         if ( isAligned )
         {
            NSPoint result, refPt;

            // The reference point is in the center of the align square
            refPt.x = (CGFloat)data->_referenceOrigin.x
                      + (CGFloat)square->_alignSize.width/2.0;
            refPt.y = (CGFloat)data->_referenceOrigin.y
                      + (CGFloat)square->_alignSize.height/2.0;

            // Beware, there is a y-flip between the bitmap and the screen
            result.x =  peak.x - r.origin.x + data->_referenceOrigin.x;
            result.y = -peak.y - r.origin.y + data->_referenceOrigin.y;

            // Accumulate the barycenters
            refBarycenter.x += refPt.x;
            refBarycenter.y += refPt.y;
            resBarycenter.x += result.x;
            resBarycenter.y += result.y;

            // Fill the ref and result matrices
            refMatrix[nbResults].x = refPt.x;
            refMatrix[nbResults].y = refPt.y;
            resultMatrix[nbResults].x = refPt.x - result.x;
            resultMatrix[nbResults].y = refPt.y - result.y;

            nbResults++;
         }
      }

      switch ( nbResults )
      {
         case 0:
            // Failed to align anything
            break;

         case 1:
            if ( nPoints == 1 || (!_rootParams->_computeScale
                                  && !_rootParams->_computeRotation) )
            {
               // Translation only
               res = [[[LynkeosBasicAlignResult alloc] init] autorelease];
               m.tX = resBarycenter.x;
               m.tY = resBarycenter.y;
               [res setTransformStruct:m];
               [res setOffset:resBarycenter]; // Offset for display
            }
            // Otherwise, the user wanted a multipoint align, and we failed
            break;

         default:
         {
            double covariances[4] = {0.0, 0.0, 0.0, 0.0};
            double s[2], u[4], vt[4], work[10], scale;
            int i, info;

            // More than one point

            res = [[[LynkeosBasicAlignResult alloc] init] autorelease];

            // Get the barycenters, to give the translation
            refBarycenter.x /= (CGFloat)nbResults;
            refBarycenter.y /= (CGFloat)nbResults;
            resBarycenter.x /= (CGFloat)nbResults;
            resBarycenter.y /= (CGFloat)nbResults;

            // Convert reference and result coordinate to originate on their
            // respective barycenters
            if ( _rootParams->_computeScale || _rootParams->_computeRotation )
            {
               for ( i = 0; i < nbResults; i++ )
               {
                  refMatrix[i].x -= refBarycenter.x;
                  refMatrix[i].y -= refBarycenter.y;
                  resultMatrix[i].x -= refBarycenter.x - resBarycenter.x;
                  resultMatrix[i].y -= refBarycenter.y - resBarycenter.y;
               }
            }

            // Find the scaling, if requested
            if ( _rootParams->_computeScale )
            {
               // Procrustes algorithm
               // Mean the scaling of each segment from the barycenters
               scale = 0.0;
               for ( i = 0; i < nbResults; i++ )
               {
                  scale += sqrt(  ((refMatrix[i].x * refMatrix[i].x)
                                   + (refMatrix[i].y * refMatrix[i].y))
                                / ((resultMatrix[i].x * resultMatrix[i].x)
                                   + (resultMatrix[i].y * resultMatrix[i].y)) );
               }
               scale /= (double)nbResults;
            }
            else
               scale = 1.0;

            // Find the rotation if requested
            if ( _rootParams->_computeRotation )
            {
               // Kabsch algorithm
               // First compute the covariance, taking the scaling into account
               for ( i = 0; i < nbResults; i++ )
               {
                  covariances[0] += refMatrix[i].x * resultMatrix[i].x / scale;
                  covariances[1] += refMatrix[i].x * resultMatrix[i].y / scale;
                  covariances[2] += refMatrix[i].y * resultMatrix[i].x / scale;
                  covariances[3] += refMatrix[i].y * resultMatrix[i].y / scale;
               }

               // Perform a singular value decomposition on the covariances
               char job = 'A';
               int dim = 2, lwork = 10;
               int status = dgesvd_(&job, &job, &dim, &dim, covariances, &dim,
                                    s, u, &dim, vt, &dim, work, &lwork, &info);
               NSAssert(status == 0, @"Singular value decomposition failed");

               // The final rotation matrix is U * V' (with a positive
               // determinant)
               if ( (u[0]*u[3] - u[1]*u[2]) * (vt[0]*vt[3] - vt[1]*vt[2]) < 0.0 )
               {
                  u[2] = -u[2];
                  u[3] = -u[3];
               }
               m.m11 = scale*(u[0]*vt[0] + u[2]*vt[1]);
               m.m21 = scale*(u[1]*vt[0] + u[3]*vt[1]);
               m.m12 = scale*(u[0]*vt[2] + u[2]*vt[3]);
               m.m22 = scale*(u[1]*vt[2] + u[3]*vt[3]);

               // Adjust the translation to put the center of rotation on the origin
               m.tX = (resBarycenter.x - refBarycenter.x)*m.m11
                      + (resBarycenter.y - refBarycenter.y)*m.m21
                      + refBarycenter.x;
               m.tY = (resBarycenter.x - refBarycenter.x)*m.m12
                      + (resBarycenter.y - refBarycenter.y)*m.m22
                      + refBarycenter.y;

               [res setTransformStruct:m];
            }
            else
            {
               m.m11 = scale;
               m.m22 = scale;
               m.m12 = 0.0;
               m.m21 = 0.0;
               m.tX = resBarycenter.x;
               m.tY = resBarycenter.y;
               [res setTransformStruct:m];
            }
            // Set the displayed offset to the one between barycenters
            [res setOffset:resBarycenter];
         }
            break;
      }
   }

   [item setProcessingParameter:res withRef:LynkeosAlignResultRef
                  forProcessing:LynkeosAlignRef];
}

- (void) finishProcessing
{
}
@end
