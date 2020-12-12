//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Wed jun 6 2007.
//  Copyright (c) 2007-2020. Jean-Etienne LAMIAUD
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
#include <math.h>
#include <objc/runtime.h>

#include "processing_core.h"
#include "MyImageAnalyzerPrefs.h"
#include "MyImageAnalyzer.h"
#include "LynkeosImageBufferAdditions.h"

NSString * const myImageAnalyzerRef = @"MyImageAnalyzer";
NSString * const myImageAnalyzerParametersRef = @"AnalysisParams";
NSString * const myImageAnalyzerResultRef = @"AnalysisResult";

static NSString * const K_ANALYSIS_METHOD_KEY = @"analysmethod";
static NSString * const K_ANALYZE_RECT_KEY    = @"analysrect";
static NSString * const K_QUALITY_KEY         = @"quality";
static NSString * const K_UPPER_CUTOFF_FREQ_KEY = @"upCutFreq";
static NSString * const K_LOWER_CUTOFF_FREQ_KEY = @"lowCutFreq";

void filterImageForAnalysis( LynkeosFourierBuffer *image,
                             double down,
                             double up )
{
   double vmin, vmax, bmax;
   u_short x, y, c;
   const double d2 = down*down, u2 = up*up;
   LynkeosFourierBuffer *orig;

   // Normalize the image on a [0 .. 1] range
   [image getMinLevel:&vmin maxLevel:&vmax];
   bmax = vmax - vmin;

   [image substractBias:vmin andScale:1.0/bmax];
   orig = [image copy];

   // Apply a bandpass filter
   [image directTransform];
   for( y = 0; y < image->_h; y++ )
   {
      double dy = (double)y / (double)image->_h;
      if ( dy >= 0.5 )
         dy -= 1.0;

      for ( x = 0; x < image->_halfw; x++ )
      {
         double dx = (double)x / (double)image->_w;
         const double f2 = dx*dx + dy*dy;

         if ( f2 <= d2 || f2 >= u2 )
         {
            for ( c = 0; c < image->_nPlanes; c++)
               colorComplexValue(image,x,y,c) = 0.0;
         }
      }
   }
   [image inverseTransform];

   // And multiply this gradient with the original image, in order to
   // filter out the noise from the dark parts of the image
   [image multiplyWith:orig result:image];
   [orig release];
   orig = nil;
}

@implementation MyImageAnalyzerParameters
- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _analysisRect = LynkeosMakeIntegerRect(0,0,0,0);
      _method = EntropyAnalysis;
      _lowerCutoff = 0.0;
      _upperCutoff = 0.0;
   }

   return( self );
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
   [encoder encodeRect:NSRectFromIntegerRect(_analysisRect)
                forKey:K_ANALYZE_RECT_KEY];
   [encoder encodeInt:_method forKey:K_ANALYSIS_METHOD_KEY];
   if ( _upperCutoff > _lowerCutoff )
   [encoder encodeDouble:_upperCutoff forKey:K_UPPER_CUTOFF_FREQ_KEY];
   [encoder encodeDouble:_lowerCutoff forKey:K_LOWER_CUTOFF_FREQ_KEY];
}

- (id)initWithCoder:(NSCoder *)decoder
{
   if ( (self = [self init]) != nil )
   {
      if ( [decoder containsValueForKey:K_ANALYZE_RECT_KEY] )
         _analysisRect = LynkeosIntegerRectFromNSRect(
                                [decoder decodeRectForKey:K_ANALYZE_RECT_KEY]);
      _method = [decoder decodeIntForKey:K_ANALYSIS_METHOD_KEY];
      if ( [decoder containsValueForKey:K_UPPER_CUTOFF_FREQ_KEY] )
         _upperCutoff = [decoder decodeDoubleForKey:K_UPPER_CUTOFF_FREQ_KEY];
      if ( [decoder containsValueForKey:K_LOWER_CUTOFF_FREQ_KEY] )
         _lowerCutoff = [decoder decodeDoubleForKey:K_LOWER_CUTOFF_FREQ_KEY];
   }

   return( self );
}
@end

@implementation MyImageAnalyzerResult
- (id) init
{
   if ( (self = [super init]) != nil )
      _quality = 0.0;

   return( self );
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
   [encoder encodeDouble:_quality forKey:K_QUALITY_KEY];
}

- (id)initWithCoder:(NSCoder *)decoder
{
   if ( (self = [self init]) != nil
        && [decoder containsValueForKey:K_QUALITY_KEY] )
      _quality = [decoder decodeDoubleForKey:K_QUALITY_KEY];

   return( self );
}

- (NSNumber*) quality { return( [NSNumber numberWithDouble:_quality]  ); }
@end

/*!
 * Evaluate the power spectrum quality
 */
static double quality( LynkeosFourierBuffer *spectrum, double down, double up )
{
   u_short x, y, c;
   double q = 0.0;
   double d2 = down*down, u2 = up*up;
   u_long n = 0;

   for( c = 0; c < spectrum->_nPlanes; c++ )
   {
      double lum = (__real__ colorComplexValue(spectrum,0,0,c))
      /(double)spectrum->_w/(double)spectrum->_h;
      double planeq = 0.0;

      for( y = 0; y < spectrum->_h; y++ )
      {
         double dy = (double)y / (double)spectrum->_h;
         if ( dy >= 0.5 )
            dy -= 1.0;

         for ( x = 0; x < spectrum->_halfw; x++ )
         {
            double dx = (double)x / (double)spectrum->_w;
            const double f2 = dx*dx + dy*dy;

            if ( f2 > d2 && f2 < u2 )
            {
               LNKCOMPLEX s = colorComplexValue(spectrum,x,y,c);
               planeq += __real__ s * __real__ s + __imag__ s * __imag__ s;
               n++;
            }
         }
      }

      q += planeq / lum / lum;
   }

   return( q/(double)n );
}

static double entropy( LynkeosFourierBuffer *image, double down, double up )
{
   double v, e = 0.0;
   u_short x, y, c;
   const double area = image->_h * image->_w * image->_nPlanes;

   filterImageForAnalysis(image, down, up);

   // Compute the information, based on assumption of a normal distribution of
   // brightness transitions
   for( y = 0; y < image->_h; y++ )
   {
      for ( x = 0; x < image->_w; x++ )
      {
         for ( c = 0; c < image->_nPlanes; c++)
         {
            // Normalized brightness transition
            v = 200.0 * colorValue(image,x,y,c);
            // The probability is proportional to exp(-v*v),
            // and the information quantity is -log(p), hence v*v (200 is arbitrary)
            e += v*v;
         }
      }
   }

   e /= area;

   return( e );
}

@implementation MyImageAnalyzer
+ (ParallelOptimization_t) supportParallelization
{
   return( [[NSUserDefaults standardUserDefaults] integerForKey:
                                                      K_PREF_ANALYSIS_MULTIPROC]
           & ListThreadsOptimizations );
}

- (id <LynkeosProcessing>) initWithDocument: (id <LynkeosDocument>)document
                                 parameters:(id <NSObject>)params
{
   self = [self init];
   if ( self == nil )
      return( self );

   _document = document;
   NSAssert1( [params isMemberOfClass:[MyImageAnalyzerParameters class]],
             @"Wrong parameter class %s for Image Analyzer",
             class_getName([params class]) );
   _params = (MyImageAnalyzerParameters*)[params retain];

   _lowerCutoff = _params->_lowerCutoff;
   _upperCutoff = _params->_upperCutoff;

   // Allocate the buffer for each image
   _bufferSpectrum = [[LynkeosFourierBuffer fourierBufferWithNumberOfPlanes:1
                                        width:_params->_analysisRect.size.width
                                       height:_params->_analysisRect.size.height 
                                     withGoal: FOR_DIRECT|FOR_INVERSE] retain];
   return( self );
}

- (void) dealloc
{
   if ( _bufferSpectrum != nil )
      [_bufferSpectrum release];
   [_params release];

   [super dealloc];
}

- (void) processItem:(id <LynkeosProcessableItem>)item
{
   LynkeosIntegerRect r = _params->_analysisRect;
   id <LynkeosAlignResult> aligned =
      (id <LynkeosAlignResult>)[item getProcessingParameterWithRef:
                                                         LynkeosAlignResultRef
                                                         forProcessing:
                                                               LynkeosAlignRef];
   LynkeosIntegerSize imageSize = [item imageSize];
   MyImageAnalyzerResult *res;

   // Take alignment into account
   if ( aligned != nil )
   {
      NSAffineTransform *t
         = [[[NSAffineTransform alloc] initWithTransform:
                                                 [aligned alignTransform]]
            autorelease];
      [t invert];

      // Displace the center of the square according to the alignment
      NSPoint c = {(CGFloat)r.origin.x + (CGFloat)r.size.width/2.0,
                   (CGFloat)r.origin.y + (CGFloat)r.size.height/2.0};

      c = [t transformPoint:c];
      r.origin.x = (short)(c.x - (CGFloat)r.size.width/2.0 + 0.5);
      r.origin.y = (short)(c.y - (CGFloat)r.size.height/2.0 + 0.5);
   }

   // Convert from Cocoa to bitmap coordinates
   r.origin.y = imageSize.height - r.origin.y - r.size.height;

   // Get the sample in that image
   [item getImageSample:&_bufferSpectrum inRect:r];

   if ( _params->_method == SpectrumAnalysis )
      [_bufferSpectrum directTransform];

   // Analyze its quality
   res = [[[MyImageAnalyzerResult alloc] init] autorelease];
   switch ( _params->_method )
   {
      case SpectrumAnalysis:
         res->_quality = quality( _bufferSpectrum, _lowerCutoff, _upperCutoff );
         break;
      case EntropyAnalysis:
         res->_quality = entropy(_bufferSpectrum,  _lowerCutoff, _upperCutoff);
         break;
      default:
         NSAssert(NO, @"Invalid analysis method");
   }

   // Save the result
   [item setProcessingParameter:res withRef:myImageAnalyzerResultRef 
                  forProcessing:myImageAnalyzerRef];
}

- (void) finishProcessing
{
   // Nothing to do
}

@end
