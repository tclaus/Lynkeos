//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Wed Sep 24 2003.
//  Copyright (c) 2003-2019. Jean-Etienne LAMIAUD
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

#include "ProcessStackManager.h"
#include "MyImageView.h"

#define K_MAX_ZOOM 4.0
#define K_TILE_SIZE 256

static const double MM_LN_10 = -M_LN10;

@interface ImageViewTile : NSObject
{
@public
   CGImageRef tileImage;
   CGRect tileRect;
}
@end

@interface MyImageView(Tile)
- (void) applyTile:(ImageViewTile*)tile;
@end

@interface ImageViewTileOperation : NSOperation
{
@private
   NSRect _requestedReq;
   id <LynkeosProcessableItem> _item;
   MyImageView *_view;
}

- (id) initWithRect:(NSRect)rect inView:(NSObject *)view forItem:(id <LynkeosProcessableItem>)item;
@end

@implementation ImageViewTile

- (id) initWithImage:(CGImageRef)image inRect:(CGRect)rect
{
   if ((self = [super init]))
   {
      tileImage = image;
      tileRect = rect;
   }
   return self;
}

- (void) dealloc
{
   CGImageRelease(tileImage);
   [super dealloc];
}
@end

@implementation ImageViewTileOperation

- (id) initWithRect: (NSRect)rect inView: (MyImageView *) view forItem:(id <LynkeosProcessableItem>)item
{
   if ((self = [super init]) != nil)
   {
      _requestedReq = rect;
      _view = view;
      _item = item;
   }

   return self;
}

- (void) main
{
   // Retrieve the image (converting the coordinates to bitmap reference)
   CGRect r = _requestedReq;
   r.origin.y = [_item imageSize].height - r.origin.y - r.size.height;
   CGImageRef img = [_item getImageTileInRect:r];

   if (!self.cancelled)
   {
      ImageViewTile *tile = [[ImageViewTile alloc] initWithImage:img inRect:_requestedReq];
      if ([NSThread isMainThread])
         [_view applyTile:tile];
      else
         [_view performSelectorOnMainThread:@selector(applyTile:) withObject:tile waitUntilDone:NO];
   }
}
@end

/*!
 * @abstract Zoom management part of MyImageView.
 */
@interface MyImageView(Zoom)

/*!
 * @method applyZoom:from:
 * @abstract Set the zoom factor to the required value.
 * @param newZoom The zoom factor to apply
 * @param sender The object asking for zoom
 */
- (void) applyZoom :(double)newZoom from:(id)sender withRedraw:(BOOL)redraw;

/*!
 * @method stepZoom:
 * @abstract Step the zoom factor to the nearest half integer power of two.
 * @param step The step to apply to the log2 of the zoom factor.
 */
- (void) stepZoom :(double)step;
@end

@implementation MyImageView(Tile)
- (void) applyTile:(ImageViewTile*)tile
{
   CGContextRef ctx = NULL;

   if (_imageLayer != NULL)
      ctx = CGLayerGetContext(_imageLayer);

   if (ctx != NULL)
   {
      CGContextDrawImage(ctx, tile->tileRect, tile->tileImage);

      // Compute the view rectangle wich encloses the image tile (rotated, scaled)
      NSPoint bottomRight = {HUGE, HUGE}, topLeft = {-HUGE, -HUGE};
      int i = 0;

      for (i = 0; i < 4; i++)
      {
         NSPoint p = NSMakePoint(tile->tileRect.origin.x + (CGFloat)(i % 2)*tile->tileRect.size.width,
                                 tile->tileRect.origin.y + (CGFloat)(i / 2)*tile->tileRect.size.height);
         p = [_imageTransform transformPoint:p];
         if (bottomRight.x > p.x)
            bottomRight.x = p.x;
         if (bottomRight.y > p.y)
            bottomRight.y = p.y;
         if (topLeft.x < p.x)
            topLeft.x = p.x;
         if (topLeft.y < p.y)
            topLeft.y = p.y;
      }
      [self setNeedsDisplayInRect:NSMakeRect(bottomRight.x, bottomRight.y,
                                             topLeft.x - bottomRight.x, topLeft.y - bottomRight.y)];
   }

   [tile release];

   if (_tilesQueue.operationCount == 0)
      // No more tile to retrieve, redraw the image surroundings if needed
      [self setNeedsDisplay:YES];
}
@end

@implementation MyImageView(Zoom)

- (void) applyZoom :(double)newZoom from:(id)sender withRedraw:(BOOL)redraw
{
   NSRect newFrame, newBounds = _canvasRect;
   NSRect visible = [self visibleRect];
   NSRect enclosing = [[self superview] bounds];

   // Adjust the enclosing bounds to the intended zoom
   enclosing.origin.x /= newZoom;
   enclosing.origin.y /= newZoom;
   enclosing.size.width /= newZoom;
   enclosing.size.height /= newZoom;

   // Set the bounds to the largest between image rect and enclosing NSClipView bounds
   if (newBounds.origin.x > enclosing.origin.x)
   {
      newBounds.size.width += newBounds.origin.x - enclosing.origin.x;
      newBounds.origin.x = enclosing.origin.x;
   }
   if ((newBounds.origin.x + newBounds.size.width) < (enclosing.origin.x + enclosing.size.width))
      newBounds.size.width  = enclosing.origin.x + enclosing.size.width - newBounds.origin.x;
   if (newBounds.origin.y > enclosing.origin.y)
   {
      newBounds.size.height += newBounds.origin.y - enclosing.origin.y;
      newBounds.origin.y = enclosing.origin.y;
   }
   if ((newBounds.origin.y + newBounds.size.height) < (enclosing.origin.y + enclosing.size.height))
      newBounds.size.height  = enclosing.origin.y + enclosing.size.height - newBounds.origin.y;

   // Apply zoom
   if ( newBounds.size.width != 0 )
   {
      newFrame.size.width = newBounds.size.width * newZoom;
      newFrame.origin.x = newBounds.origin.x * newZoom;
   }
   else
   {	// NSView don't like null sizes
      newFrame.size.width = 1;
      newFrame.origin.x = 0;
      newBounds.size.width = 1;
      newBounds.origin.x = 0;
   }

   if ( newBounds.size.height != 0 )
   {
      newFrame.size.height = newBounds.size.height * newZoom;
      newFrame.origin.y = newBounds.origin.y * newZoom;
   }
   else
   {	// NSView don't like null sizes
      newFrame.size.height = 1;
      newFrame.origin.y = 0;
      newBounds.size.height = 1;
      newBounds.origin.y = 0;
   }

   [self setFrameSize:newFrame.size];
   [self setFrameOrigin:newFrame.origin];
   [self setBoundsSize:newBounds.size];
   [self setBoundsOrigin:newBounds.origin];

   if ( newZoom != _zoom )
   {
      // Adjust scroll to keep center still
      if ( _canvasRect.size.width != 0 && _canvasRect.size.height != 0 )
      {
         visible.origin.x += (1 - _zoom/newZoom)*visible.size.width/2;
         if ( visible.origin.x < 0 )
            visible.origin.x = 0;
         visible.origin.y += (1 - _zoom/newZoom)*visible.size.height/2;
         if ( visible.origin.y < 0 )
            visible.origin.y = 0;
         visible.size.width *= _zoom/newZoom;
         visible.size.height *= _zoom/newZoom;

         [self scrollRectToVisible:visible];
      }

      _zoom = newZoom;
      if ( sender != _zoomField )
         [_zoomField setDoubleValue:_zoom*100.0];
      if ( sender != _zoomSlider )
         [_zoomSlider setDoubleValue:log(_zoom)/log(K_MAX_ZOOM)];

      [[NSNotificationCenter defaultCenter] postNotificationName: LynkeosImageViewZoomDidChangeNotification
                                                          object: self];
   }

   if (redraw)
      // Make me redraw
      [self setNeedsDisplay:YES];
}

- (void) stepZoom :(double)step
{
   double z = log(_zoom)/log(2);

   // Get the wanted half integer value
   if ( step < 0.0 && z > 0.0 )
      z += 0.49999999;
   else if ( step > 0.0 && z < 0.0 )
      z -= 0.49999999;

   z = (double)((int)((z+step)*2))/2.0;
   z = exp(log(2)*z);

   [self applyZoom: z from:nil withRedraw:YES];
}
@end

@implementation MyImageView

// Initializations and allocation stuff
- (id)initWithFrame:(NSRect)frameRect
{
   LynkeosIntegerRect nowhere = { {0,0}, {0,0} };

   if ( (self = [super initWithFrame:frameRect]) == nil )
      return( self );

   _selectionDelegate = nil;
   _item = nil;
   _itemSequenceNumber = 0;
   _itemSize = LynkeosMakeIntegerSize(0, 0);
   _imageTransform = nil;
   _tilesQueue = [[NSOperationQueue alloc] init];
   _layerContext = NULL;
   _imageLayer = NULL;

   _zoom = 1.0;

   _selectionMode = NoSelection;
   _savedSelectionMode = NoSelection;
   _freezeCounter = 0;
   _selectionOrigin = nowhere.origin;
   _lastPoint = nowhere.origin;
   _selection = [[NSMutableArray array] retain];
   _inProgressSelection = nowhere;
   _currentSelectionIndex = NSNotFound;
   _previousSelectionIndex = NSNotFound;
   _autoscrollTimer = nil;

   [self initCursors];

    return self;
}

- (void) dealloc
{
   if (_layerContext != NULL)
      CGContextRelease(_layerContext);
   if ( _imageLayer != NULL )
      CGLayerRelease(_imageLayer);
   if ( _item != nil )
      [_item release];
   if ( _imageTransform != nil )
      [_imageTransform release];

   [_selection release];
   [_topLeftCursor release];
   [_topRightCursor release];
   [_bottomLeftCursor release];
   [_bottomRightCursor release];
   [_insideCursor release];

   [super dealloc];
}

- (void) awakeFromNib
{
   [_blackText setEnabled:NO];
   [_whiteText setEnabled:NO];
   [_blackWhiteSlider setEnabled:NO];
   [_gammaText setEnabled:NO];
   [_gammaSlider setEnabled:NO];
   [_blackText setStringValue:@""];
   [_whiteText setStringValue:@""];
   [_gammaText setStringValue:@""];   
}

// Image and zoom
- (IBAction)doZoom:(id)sender
{
   double z;

   if ( sender == _zoomSlider )
      z = exp(log(K_MAX_ZOOM)*[sender doubleValue]);
   else
      z = [sender doubleValue]/100.0;

   [self applyZoom: z from:sender withRedraw:YES];
}

- (IBAction)moreZoom:(id)sender
{
   if ( _zoom < K_MAX_ZOOM )
      [self stepZoom:0.5];
}

- (IBAction)lessZoom:(id)sender
{
   if ( _zoom > 1.0/K_MAX_ZOOM )
      [self stepZoom:-0.5];	// To be improved in stepZoom
}

- (IBAction) blackWhiteChange :(id)sender
{
   // Reconcile slider and text fields
   double black = 0, white = 255;
   if ( sender == _blackWhiteSlider )
   {
      black = [sender doubleLoValue];
      [_blackText setDoubleValue:black];
      white = [sender doubleHiValue];
      [_whiteText setDoubleValue:white];
   }
   else if ( sender == _blackText )
   {
      black = [sender doubleValue];
      white = [_blackWhiteSlider doubleHiValue];
      if ( black > white )
      {
         black = white;
         [sender setDoubleValue:black];
      }
      if ( black < [_blackWhiteSlider minValue] )
         [_blackWhiteSlider setMinValue:black];
      [_blackWhiteSlider setDoubleLoValue:black];
   }
   else if ( sender == _whiteText )
   {
      black = [_blackWhiteSlider doubleLoValue];
      white = [sender doubleValue];
      if ( white < black )
      {
         white = black;
         [sender setDoubleValue:white];
      }
      if ( white > [_blackWhiteSlider maxValue] )
         [_blackWhiteSlider setMaxValue:white];
      [_blackWhiteSlider setDoubleHiValue:white];
   }
   else
      NSAssert(NO,@"Unknown control in blackWhiteChange");

   // Set the levels in the item
   [_item setBlackLevel:black whiteLevel:white gamma:[_gammaText doubleValue]];

   // Refresh the image
   [self updateImage];
}

- (IBAction) gammaChange :(id)sender
{
   double gammaCorrect = 1.0;

   // Reconcile controls
   if ( sender == _gammaSlider )
   {
      gammaCorrect = exp(MM_LN_10*[sender doubleValue]);
      [_gammaText setDoubleValue:gammaCorrect];
   }
   else if ( sender == _gammaText )
   {
      gammaCorrect = [sender doubleValue];
      [_gammaSlider setDoubleValue:log(gammaCorrect)/MM_LN_10];
   }
   else
      NSAssert( NO, @"Unknown gamma control" );

   // Set the levels in the item
   [_item setBlackLevel:[_blackText doubleValue]
             whiteLevel:[_whiteText doubleValue]
                  gamma:gammaCorrect];

   // Refresh the image
   [self updateImage];
}

- (void) displayItem:(id <LynkeosProcessableItem>)item
{
   [self displayItem:item withTransform:[NSAffineTransform transform]];
}

- (void) displayItem:(id <LynkeosProcessableItem>)item
       withTransform:(NSAffineTransform*)transform
{
   NSAffineTransform *newTransform
      = [[[NSAffineTransform alloc] initWithTransform:transform] autorelease];
   if ( item != nil )
   {
      // Get the align transform if any
      id <LynkeosViewAlignResult> res = (id <LynkeosViewAlignResult>)
         [item getProcessingParameterWithRef:LynkeosAlignResultRef
                               forProcessing:LynkeosAlignRef];
      if ( res != nil )
         [newTransform prependTransform:[res alignTransform]];
   }

   // Avoid useless updates
   if ( item == _item &&
       ( item == nil ||
        ( [item getSequenceNumber] == _itemSequenceNumber &&
          [_imageTransform isEqual:newTransform] ) ) )
      return;

   // Save the parameters
   if ( _imageTransform != nil )
      [_imageTransform release];
   _imageTransform = newTransform;
   if ( _imageTransform != nil )
      [_imageTransform retain];

   if ( _item != item )
   {
      if ( _item != nil )
         [_item release];
      _itemSequenceNumber = 0;
      _item = item;
      if ( _item != nil )
         [_item retain];
   }
   if ( _item != nil )
   {
      _itemSequenceNumber = [item getSequenceNumber];
   }

   // Display that new image
   [self updateImage];
}

- (void) updateImage
{
   double vmin, vmax, black, white, gamma;
   BOOL validRange = NO, validLevels = NO;

   // Cleanup before else
   _canvasRect = NSMakeRect(0.0, 0.0, 0.0, 0.0);
   [_tilesQueue cancelAllOperations];
   if (_imageLayer != NULL)
   {
      CGLayerRelease(_imageLayer);
      _imageLayer = NULL;
   }
   if (_layerContext != NULL)
   {
      CGContextRelease(_layerContext);
      _layerContext = NULL;
   }

   // Prepare for the new image
   if ( _item != nil )
   {
      const LynkeosIntegerSize s = [_item imageSize];


      if (_itemSize.width != s.width || _itemSize.height != s.height)
         _itemSize = s;
      _canvasRect = NSMakeRect(0.0, 0.0, (CGFloat)_itemSize.width, (CGFloat)_itemSize.height);

      if (_itemSize.width != 0 && _itemSize.height != 0)
      {
         // Create the layer which will be filled by the tiles
         _layerContext = CGBitmapContextCreate(NULL, _itemSize.width, _itemSize.height, 8, 0,
                                               CGColorSpaceCreateDeviceRGB(),
                                               (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
         _imageLayer = CGLayerCreateWithContext(_layerContext,
                                                NSMakeSize(_itemSize.width, _itemSize.height), NULL);
//         CGContextRef layerCtx = CGLayerGetContext(_imageLayer);
//         CGContextSetGrayFillColor(layerCtx, 0.5, 1.0);
//         CGContextFillRect(layerCtx, _canvasRect);

         // Adjust the view frame if the image size has changed
         CGFloat x, y;

         NSRect itemRect = _canvasRect;

         // Compute the rectangle wich encloses the transformed image (rotated, scaled)
         for ( y = 0.0; y <= itemRect.size.height; y +=  itemRect.size.height )
         {
            for ( x = 0.0; x <= itemRect.size.width; x+= itemRect.size.width )
            {
               NSPoint p = [_imageTransform transformPoint:NSMakePoint(x, y)];

               if ( p.x < _canvasRect.origin.x )
               {
                  _canvasRect.size.width += (_canvasRect.origin.x - p.x);
                  _canvasRect.origin.x = p.x;
               }
               else if ( p.x > _canvasRect.origin.x + _canvasRect.size.width )
                  _canvasRect.size.width = p.x - _canvasRect.origin.x;
               if ( p.y < _canvasRect.origin.y )
               {
                  _canvasRect.size.height += (_canvasRect.origin.y - p.y);
                  _canvasRect.origin.y = p.y;
               }
               else if ( p.y > _canvasRect.origin.y + _canvasRect.size.height )
                  _canvasRect.size.height = p.y - _canvasRect.origin.y;
            }
         }

         ImageViewTileOperation *firstOp = nil;
         if ([_item supportsTiling])
         {
            // Gather all the image tiles in a "scattered" spiral motion starting at the view center
            NSRect vis = self.visibleRect;
            NSPoint center = NSMakePoint(vis.origin.x + vis.size.width/2.0, vis.origin.y + vis.size.height/2.0);
            NSAffineTransform *t = [[[NSAffineTransform alloc] initWithTransform:_imageTransform] autorelease];
            [t invert];
            center = [t transformPoint:center]; // View center in image coordinates
            // Tiles are aligned with image origin, get the center tile origin
            center = NSMakePoint(floor(center.x/K_TILE_SIZE)*K_TILE_SIZE, floor(center.y/K_TILE_SIZE)*K_TILE_SIZE);
            const int pseudoRadius = MAX(MAX((int)(_itemSize.width - center.x)/K_TILE_SIZE,
                                             (int)(_itemSize.height - center.y)/K_TILE_SIZE),
                                         MAX((int)(center.x)/K_TILE_SIZE,
                                             (int)(center.y)/K_TILE_SIZE));
            int maxDist;
            for (maxDist = 0; maxDist <= pseudoRadius; maxDist++)
            {
               int iY;
               for (iY = 0; ; iY++)
               {
                  // Get the "scattered" y
                  const int deltY = (iY + (iY % 2))/2 * (2*(iY % 2) - 1);
                  if (abs(deltY) > maxDist)
                     break;

                  int iX;
                  for (iX = 0; ; iX++)
                  {
                     // Get the "scattered" x
                     const int deltX = (iX + (iX % 2))/2 * (2*(iX % 2) - 1);
                     if (abs(deltX) > maxDist)
                        break;

                     if (MAX(abs(deltX), abs(deltY)) == maxDist)
                     {
                        NSPoint tileOrigin = NSMakePoint(center.x + deltX*K_TILE_SIZE,
                                                         center.y + deltY*K_TILE_SIZE);
                        if (tileOrigin.x >= 0 && tileOrigin.y >= 0 &&
                            tileOrigin.x < _itemSize.width && tileOrigin.y < _itemSize.height)
                        {
                           NSRect tileRect = NSMakeRect(tileOrigin.x, tileOrigin.y,
                                                        MIN(K_TILE_SIZE,_itemSize.width - tileOrigin.x),
                                                        MIN(K_TILE_SIZE, _itemSize.height - tileOrigin.y));
                           ImageViewTileOperation *op
                              = [[[ImageViewTileOperation alloc] initWithRect: tileRect
                                                                       inView: self
                                                                      forItem: _item]
                                                         autorelease];
                           // Keep the center tile for synchronous read (see below)
                           if (firstOp == nil)
                              firstOp = op;
                           else
                           {
                              // Give priority to the visible part of the view
                              if (NSIntersectsRect(vis, tileRect))
                                 op.queuePriority = NSOperationQueuePriorityHigh;
                              else
                                 op.queuePriority = NSOperationQueuePriorityNormal;
                              [_tilesQueue addOperation:op];
                           }
                        }
                     }
                  }
               }
            }

            // Force blocking on first tile, as the view often wants redraw before any tile is available
            if (firstOp != nil)
            {
               [firstOp start];
            }
         }
         else
         {
            NSRect r = NSMakeRect(0.0, 0.0, (CGFloat)_itemSize.width, (CGFloat)_itemSize.height);
            CGImageRef img = [_item getImageTileInRect:r];
            [self applyTile:[[ImageViewTile alloc] initWithImage:img inRect:r]];
         }
      }

      validRange = [_item isProcessed]
                   && [_item getMinLevel:&vmin maxLevel:&vmax];
      validLevels= [_item getBlackLevel:&black whiteLevel:&white gamma:&gamma];
   }

   [_blackText setEnabled:(validRange && validLevels)];
   [_whiteText setEnabled:(validRange && validLevels)];
   [_blackWhiteSlider setEnabled:(validRange && validLevels)];
   [_gammaText setEnabled:(validRange && validLevels)];
   [_gammaSlider setEnabled:(validRange && validLevels)];

   if ( validRange )
   {
      [_blackWhiteSlider setMinValue:fmin(vmin,black)];
      [_blackWhiteSlider setMaxValue:fmax(vmax,white)];
      [_blackWhiteSlider setDoubleLoValue:black];
      [_blackWhiteSlider setDoubleHiValue:white];
      [_gammaSlider setDoubleValue:log(gamma)/MM_LN_10];
   }

   if ( validLevels )
   {
      [_blackText setDoubleValue:black];
      [_whiteText setDoubleValue:white];
      [_gammaText setDoubleValue:gamma];
   }
   else
   {
      [_blackText setStringValue:@""];
      [_whiteText setStringValue:@""];
      [_gammaText setStringValue:@""];
   }

   [self applyZoom:_zoom from:nil withRedraw:NO];
}

- (void) resetBounds
{
   NSRect r = {{0.0, 0.0}, {1.0, 1.0}};
   [self setFrameSize:r.size];
   [self setFrameOrigin:r.origin];
   [self setBoundsSize:r.size];
   [self setBoundsOrigin:r.origin];
}

// Drawing
- (void)drawRect:(NSRect)rect
{
   NSGraphicsContext *g = [NSGraphicsContext currentContext];

   if ( _imageLayer != NULL )
   {
      NSRect r = NSMakeRect(0.0, 0.0, _itemSize.width, _itemSize.height);
      [g saveGraphicsState];
      if ( _imageTransform != nil )
         [_imageTransform concat];
      CGContextDrawLayerInRect(g.CGContext, r, _imageLayer);
      [g restoreGraphicsState];
   }

   if ( _draggingMode != SelNone || [_selection count] != 0 )
   {
      [g saveGraphicsState];
      [[NSColor orangeColor] set];

      NSEnumerator *selectionList = [_selection objectEnumerator];
      MyImageSelection *sel = nil;
      SelectionIndex_t i = NSNotFound;

      do
      {
         LynkeosIntegerRect r;

         if ( sel == nil )
            r = _inProgressSelection;
         else
            r = sel->_rect;

         if ( r.size.width != 0 && r.size.height != 0 )
         {
            if ( i == _currentSelectionIndex
                 && (_inProgressSelection.size.width != 0
                     || _inProgressSelection.size.height != 0) )
               // Do not display the active selection during modification
               continue;
            if ( sel == nil || i == _currentSelectionIndex )
            {
               [g saveGraphicsState];
               [[NSColor redColor] set];
            }
            [NSBezierPath strokeRect:NSRectFromIntegerRect(r)];
            if ( sel == nil || i == _currentSelectionIndex )
               [g restoreGraphicsState];
         }
         i = (i == NSNotFound ? 0 : i+1);
      } while ( (sel = [selectionList nextObject]) != nil );

      [g restoreGraphicsState];
   }

   // Give an opportunity to add drawings
   [[NSNotificationCenter defaultCenter] postNotificationName: LynkeosImageViewRedrawNotification
                                                       object: self];
}

- (NSSize) imageSize { return( _canvasRect.size ); }

- (double) getZoom { return ( _zoom ); }

- (void) setZoom:(double)zoom
{
   [self applyZoom:zoom from:nil withRedraw:YES];
}

- (LynkeosIntegerRect) getSelection
{
   if ( _currentSelectionIndex < [_selection count])
      return( [self getSelectionAtIndex:_currentSelectionIndex] );
   else
      return( LynkeosMakeIntegerRect(0, 0, 0, 0) );
}

- (SelectionIndex_t) numberOfSelections
{ return( [_selection count] ); }

- (SelectionIndex_t) activeSelectionIndex
{ return( _currentSelectionIndex); }

- (LynkeosIntegerRect) getSelectionAtIndex:(SelectionIndex_t)index
{
   if ( [_selection count] > 0 )
   {
      MyImageSelection *sel = [_selection objectAtIndex:index];
      NSAssert( sel != nil, @"No selection in non nil selection list" );
      return( sel->_rect );
   }
   else
      return( LynkeosMakeIntegerRect(0, 0, 0, 0) );
}

- (unsigned int) getModifiers { return( _modifiers ); }

- (void) setSelectionMode:(SelectionMode_t)mode
{
   NSAssert( [_selection count] == 0,
             @"setSelectionMode called with active selections" );
   _selectionMode = mode;
}

- (void) freezeSelections:(BOOL)freeze
{
   if ( freeze )
   {
      if ( _freezeCounter == 0 )
      {
         _savedSelectionMode = _selectionMode;
         _selectionMode = NoSelection;
      }
      _freezeCounter++;
   }
   else
   {
      _freezeCounter--;
      if ( _freezeCounter == 0 )
      {
         _selectionMode = _savedSelectionMode;
         _savedSelectionMode = NoSelection;
      }
   }
}

- (void) setSelection :(LynkeosIntegerRect)selection
             resizable:(BOOL)resize
               movable:(BOOL)move
{
   SelectionIndex_t index;

   if ( _selectionMode == SingleSelection )
      index = 0;

   else if ( _currentSelectionIndex < [_selection count] )
      index = _currentSelectionIndex;

   else
      index = [_selection count];

   [self setSelection:selection atIndex:index resizable:resize movable:move];
}

- (void) setSelection :(LynkeosIntegerRect)selection
               atIndex:(SelectionIndex_t)index
             resizable:(BOOL)resize
               movable:(BOOL)move
{
   const SelectionIndex_t nSel = [_selection count];
   LynkeosIntegerRect selRect = selection;
   LynkeosIntegerRect oldRect = {{0,0},{0,0}};
   BOOL oldMovable = NO, oldResizable = NO;
   SelectionIndex_t oldIndex = index;

   if (_selectionMode == NoSelection)
   {
      NSLog(@"Trying to set a selection in NoSelection mode" );
      return;
   }
   NSAssert( index <= nSel,
             @"Trying to add a selection at an invalid index" );

   if ( index < nSel )
      [self getSelectionAtIndex:index
                           rect:&oldRect
                      resizable:&oldResizable movable:&oldMovable];

   // Correct the selection if needed
   if ( _selectionDelegate != nil )
   {
      if ( ![_selectionDelegate validateSelection:&selRect
                                          atIndex:index] )
      {
         selRect.origin.x = 0;
         selRect.origin.y = 0;
         selRect.size.width = 0;
         selRect.size.height = 0;
      }
   }

   // Do not allow selection to be outside the image, even partly
   if ( _canvasRect.size.width == 0 || _canvasRect.size.height == 0 )
   {
      selRect.origin.x = 0;
      selRect.origin.y = 0;
      selRect.size.width = 0;
      selRect.size.height = 0;
   }
   else
   {
      if ( selRect.origin.x < _canvasRect.origin.x )
         selRect.origin.x = _canvasRect.origin.x;
      else if ( selRect.origin.x + selRect.size.width
                 > _canvasRect.origin.x + _canvasRect.size.width )
         selRect.origin.x = _canvasRect.size.width - selRect.size.width - 1;
      if ( selRect.origin.y < _canvasRect.origin.y )
         selRect.origin.y = _canvasRect.origin.y;
      else if ( selRect.origin.y + selRect.size.height
                 > _canvasRect.origin.y + _canvasRect.size.height )
         selRect.origin.y = _canvasRect.size.height - selRect.size.height - 1;
   }

   // Check if something has changed
   if ( (index < nSel && index == _currentSelectionIndex
         && oldRect.origin.x == selection.origin.x
         && oldRect.origin.y == selection.origin.y
         && oldRect.size.width == selection.size.width
         && oldRect.size.height == selection.size.height
         && oldMovable == move && oldResizable == resize)
        || (nSel == 0 && (selection.size.width == 0
                          || selection.size.height == 0)) )
   {
      // Nothing to do
      return;
   }
   else if ( _isNotifying  )
   {
      NSLog(@"Attempt to modify the selection during a selection change notification");
      return;
   }

   // If the final selection size is zero, remove it
   if ( selRect.size.width == 0 || selRect.size.height == 0 )
   {
      if (index < [_selection count])
         [self removeSelectionAtIndex:index];
   }
   else
   {
      MyImageSelection *sel = [[[MyImageSelection alloc] initWithRect:selRect
                                                              movable:move
                                                            resizable:resize]
                                                                   autorelease];

      _modifiers = 0;

      if ( index < nSel )
      {
         if ( ![sel isEqual:[_selection objectAtIndex:index]] )
            [_selection replaceObjectAtIndex:index withObject:sel];
      }
      else
         [_selection addObject:sel];
      _currentSelectionIndex = index;


      [self setNeedsDisplay:YES];
      [[self window] invalidateCursorRectsForView:self];

      // If the selection was adjusted, notify it
      if (    index != oldIndex
           || selRect.origin.x    != oldRect.origin.x
           || selRect.origin.y    != oldRect.origin.y
           || selRect.size.width  != oldRect.size.width
           || selRect.size.height != oldRect.size.height )
      {
         _isNotifying = YES;
         [[NSNotificationCenter defaultCenter] postNotificationName:
                              LynkeosImageViewSelectionRectDidChangeNotification
                                                             object: self
                                                           userInfo:
          [NSDictionary dictionaryWithObjectsAndKeys:
              [NSNumber numberWithUnsignedInteger: _currentSelectionIndex],
              LynkeosImageViewSelectionRectIndex,
              nil]];
         _isNotifying = NO;
      }
   }
}

- (void) removeSelectionAtIndex:(SelectionIndex_t)index
{
   if (_selectionMode == NoSelection)
   {
      NSLog(@"Trying to remove a selection in NoSelection mode" );
      return;
   }
   NSAssert( index < [_selection count],
             @"Trying to remove a nonexistent selection" );

   [_selection removeObjectAtIndex:index];
   SelectionIndex_t newCount = [_selection count];
   if ( newCount != 0 && _currentSelectionIndex >= newCount )
      _currentSelectionIndex = newCount - 1;

   else if ( newCount == 0 )
      _currentSelectionIndex = NSNotFound;

   [self setNeedsDisplay:YES];
   [[self window] invalidateCursorRectsForView:self];

   _isNotifying = YES;
   [[NSNotificationCenter defaultCenter] postNotificationName:
                                 LynkeosImageViewSelectionWasDeletedNotification
                                                       object: self
                                                     userInfo:
                                 [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSValue valueWithRange:
                                                         NSMakeRange(index, 1)],
                                    LynkeosImageViewSelectionRange,
                                    nil]];
   _isNotifying = NO;
}

- (void) removeAllSelections
{
   const SelectionIndex_t nSel = [_selection count];

   if (nSel == 0)
      // Nothing to remove
      return;
   if (_selectionMode == NoSelection)
   {
      NSLog(@"Trying to remove selections in NoSelection mode" );
      return;
   }

   if ( nSel != 0 )
   {
      [_selection removeAllObjects];
      _currentSelectionIndex = NSNotFound;

      [self setNeedsDisplay:YES];
      [[self window] invalidateCursorRectsForView:self];

      _isNotifying = YES;
      [[NSNotificationCenter defaultCenter] postNotificationName:
                                 LynkeosImageViewSelectionWasDeletedNotification
                                                       object: self
                                                     userInfo:
                                 [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSValue valueWithRange:
                                                          NSMakeRange(1, nSel)],
                                  LynkeosImageViewSelectionRange,
                                  nil]];
      _isNotifying = NO;
   }
}


- (void) setSelectionDelegate:(id <LynkeosImageViewDelegate>)delegate
{
   _selectionDelegate = delegate;
}
@end
