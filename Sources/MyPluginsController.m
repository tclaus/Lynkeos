//
//  Lynkeos
//  $Id$
//
//  Created by Jean-Etienne LAMIAUD on Fri Mar 2, 2007.
//  Copyright (c) 2007-2019. Jean-Etienne LAMIAUD
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

#ifdef GNUSTEP

#include <GNUstepBase/GSObjCRuntime.h>

#define getClassList(c,n) GSClassList(c, n, NO)

#else

#include <Carbon/Carbon.h>
#include <objc/objc-runtime.h>

#define getClassList(c,n) objc_getClassList(c, n);

#endif

#include "processing_core.h"
#include "LynkeosFileReader.h"
#include "LynkeosFileWriter.h"
#include "LynkeosProcessingView.h"
#include "MyImageListWindow.h"
#include "LynkeosPreferences.h"
#include "LynkeosInterpolator.h"
#include "MyCachePrefs.h"
#include "MyGuiConstants.h"
#include "MyPluginsController.h"

NSString * const MyPluginsInitializedNotification = @"MyPluginsInitialized";

NSString * const LynkeosPluginName = @"PluginName";
NSString * const LynkeosPluginHelpFile = @"PluginHelpFile";

static MyPluginsController *myInstance = nil;

@implementation LynkeosReaderRegistry
+ (void) load
{
   // Nothing to do, but the zero-linker dumps this class if it is not defined
}
@end

@implementation LynkeosProcessingViewRegistry
+ (void) load
{
   // Nothing to do, but the zero-linker dumps this class if it is not defined
}

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      config = nil;
      ident = nil;
   }

   return( self );
}

- (void) dealloc
{
   if ( config != nil )
      [config release];
   if ( ident != nil )
      [ident release];
   [super dealloc];
}

- (NSComparisonResult)caseInsensitiveCompare:(LynkeosProcessingViewRegistry*)reg
{
   NSString *myName, *otherName;
   NSString *tool, *key, *tip;
   NSImage *icon;

   [controller getProcessingTitle:&myName toolTitle:&tool
                              key:&key icon:&icon tip:&tip
                        forConfig:config];
   [reg->controller getProcessingTitle:&otherName toolTitle:&tool
                                   key:&key icon:&icon tip:&tip
                        forConfig:reg->config];

   return( [myName caseInsensitiveCompare:otherName] );
}
@end

//! Comparison function for sorting writers by name
static NSComparisonResult compareWriters( id obj1, id obj2, void *ctx )
{
   return( [[obj1 writerName] caseInsensitiveCompare:[obj2 writerName]] );
}

@interface MyPluginsController(Private)
- (void) loadPlugins ;
- (void) processReaderClass:(Class)theClass;
- (void) processWriterClass:(Class)theClass;
- (void) processProcessingViewClass:(Class)theClass;
- (void) processPreferencesClass:(Class)theClass;
- (void) processInterpolatorClass:(Class)theClass;
- (void) finalizeReaders ;
- (void) finalizeWriters ;
- (void) finalizeProcessingViews ;
- (void) finalizePreferences ;
- (void) finalizeInterpolators ;
- (void) retrieveClasses ;
- (void) updateProcessMenu:(NSMenu*)procMenu forKind:(ProcessingViewKind_t)kind ;
- (void) updateGUI ;
- (void) openPluginHelp:(id)sender ;
@end

@implementation MyPluginsController(Private)
- (void) loadPlugins
{
   NSFileManager *fMgr = [NSFileManager defaultManager];
   NSMutableArray *bundleSearchPaths = [NSMutableArray array];
   NSArray *librarySearchPaths;
   NSEnumerator *searchPathEnum;
   NSString *currPath;
   NSBundle *currBundle;

#ifndef NO_FRAMEWORK_CHECK
   NSError *err;

   // Delete the LynkeosCore framework, if obsolete, from our home folder
   // It could allow obsolete plugins to load and crash Lynkeos
   NSString *framework = @"/Library/Frameworks/LynkeosCore.framework";
   NSString *homeFramework = [NSString stringWithFormat:@"%@%@",
                                 NSHomeDirectory(), framework];

   if ( [fMgr fileExistsAtPath:homeFramework] &&
       ![fMgr fileExistsAtPath:[homeFramework stringByAppendingFormat:
                                  @"/Versions/%s", FRAMEWORK_VERSION]] )
   {
      if ( ![fMgr removeItemAtPath:homeFramework error:&err] )
      {
         NSLog( @"Cannot remove obsolete LynkeosCore.framework, error : %@",
                [err localizedDescription] );
         NSRunAlertPanel(NSLocalizedString(@"ObsoleteFrameworkTitle",
                                           @"Obsolete system framework alert panel title"),
                         @"%@", [NSString stringWithFormat:
                            NSLocalizedString(@"ObsoleteFrameworkText",
                                              @"Obsolete system framework text"),
                            homeFramework],
                         nil, nil, nil );
      }
   }

   // If an obsolete framework is present in the system folder, we can not
   // remove it. Therefore, alert the user
   if ( [fMgr fileExistsAtPath:framework] &&
        ![fMgr fileExistsAtPath:[framework stringByAppendingFormat:
                                              @"/Versions/%s", FRAMEWORK_VERSION]] )
   {
      NSRunAlertPanel(NSLocalizedString(@"ObsoleteFrameworkTitle",
                                        @"Obsolete system framework alert panel title"),
                      [NSString stringWithFormat:
                         NSLocalizedString(@"ObsoleteFrameworkText",
                                           @"Obsolete system framework text"),
                         framework],
                      nil, nil, nil );
   }
#endif

   // Build the plugins paths list
   librarySearchPaths = NSSearchPathForDirectoriesInDomains(
                NSLibraryDirectory, NSAllDomainsMask - NSSystemDomainMask, YES);

   searchPathEnum = [librarySearchPaths objectEnumerator];
   while( (currPath = [searchPathEnum nextObject]) != nil )
      [bundleSearchPaths addObject: [currPath stringByAppendingPathComponent:
                                       @"Application Support/Lynkeos/PlugIns"]];

   [bundleSearchPaths addObject: [[NSBundle mainBundle] builtInPlugInsPath]];

   // Load every plugin in each directory
   searchPathEnum = [bundleSearchPaths objectEnumerator];
   while( (currPath = [searchPathEnum nextObject]) != nil )
   {
      NSDirectoryEnumerator *bundleEnum;
      NSString *currBundlePath;

      bundleEnum = [fMgr enumeratorAtPath:currPath];

      if(bundleEnum)
      {
         while( (currBundlePath = [bundleEnum nextObject]) != nil )
         {
            if( [[currBundlePath pathExtension] isEqualToString:@"bundle"] )
            {
               currBundle = [NSBundle bundleWithPath:
                               [currPath stringByAppendingPathComponent:
                                                               currBundlePath]];
               if( currBundle != nil )
               {
                  if ( [currBundle load] )
                     [_bundlesList addObject:currBundle];
               }
            }
         }
      }
   }
}

- (void) processWriterClass:(Class)theClass
{
   // This test is to make sure we don't send conformsToProtocol to 
   // something which will assert when receiving it
   if ( class_getClassMethod(theClass,
                         @selector(writerForURL:planes:width:height:metaData:)) != NULL )
   {
      if ( [theClass conformsToProtocol:@protocol(LynkeosImageFileWriter)] )
         [_imageWritersList addObject:theClass];
      else if ( [theClass conformsToProtocol:@protocol(LynkeosMovieFileWriter)] )
         [_movieWritersList addObject:theClass];
   }
}

- (void) processProcessingViewClass:(Class)theClass
{
   // Same test to avoid assert
   if ( class_getClassMethod(theClass,
                             @selector(isStandardProcessingViewController)) != NULL
        && [theClass conformsToProtocol:@protocol(LynkeosProcessingView)] )
   {
      if ( [theClass isStandardProcessingViewController] )
         [self registerProcessingViewController:theClass
                              withConfiguration:nil
                                     identifier:nil];
   }
}

- (void) processReaderClass:(Class)theClass
{
   if ( class_getClassMethod(theClass, @selector(lynkeosFileTypes:)) != NULL )
   {
      NSArray *types;

      // Store the file types that this class handles
      [theClass lynkeosFileTypes:&types];

      if ( types != nil )
      {
         NSEnumerator *list = [types objectEnumerator];
         id item;
         NSString *oneType;

         while( (item = [list nextObject]) != nil )
         {
            LynkeosReaderRegistry *entry =
                                    [[LynkeosReaderRegistry alloc] autorelease];
            NSMutableArray *registry;

            // If a NSNumber is in the list, it is the priority of the 
            // following file type for this item
            if ( [item isKindOfClass:[NSNumber class]] )
            {
               entry->priority = [item intValue];
               oneType = [list nextObject];
            }
            else
            {
               entry->priority = 0;
               oneType = item;
            }

            entry->reader = theClass;

            // Find this file type in the right dictionary
            NSMutableDictionary *dict = nil;

            if ( [theClass conformsToProtocol:
                                            @protocol(LynkeosImageFileReader)] )
               dict = _imageReadersDict;
            else if ( [theClass conformsToProtocol:
                                            @protocol(LynkeosMovieFileReader)] )
               dict = _movieReadersDict;
            else
               NSAssert(NO,
                       @"Found a Lynkeos file reader not for image nor movie" );

            registry = [dict objectForKey:oneType];
            if ( registry == nil )
            {
               // This file type is not registered yet
               registry = [NSMutableArray arrayWithCapacity:1];
               [dict setObject:registry forKey:oneType];
            }

            // Add this reader (priorities will be sorted later)
            [registry addObject:entry];
         }
      }
   }
}

- (void) processPreferencesClass:(Class)theClass
{
   // Same test to avoid assert
   if ( class_getClassMethod(theClass, @selector(getPreferenceInstance)) != NULL
        && [theClass conformsToProtocol:@protocol(LynkeosPreferences)] )
   {
      [_preferencesList addObject:theClass];
   }
}

- (void) processInterpolatorClass:(Class)theClass
{
   // Same test to avoid assert
   if ( class_getClassMethod(theClass, @selector(isCompatibleWithScaling:withTransform:)) != NULL
       && [theClass conformsToProtocol:@protocol(LynkeosInterpolator)] )
   {
      [_interpolatorsList addObject:theClass];
   }
}

- (void) finalizeProcessingViews
{
}

- (void) finalizeReaders
{
}

- (void) finalizeWriters
{
   // Sort the writers by name
   [_imageWritersList sortUsingFunction:compareWriters context:NULL];
   [_movieWritersList sortUsingFunction:compareWriters context:NULL];
}

- (void) finalizePreferences
{
}

- (void) finalizeInterpolators
{
}

- (void) retrieveClasses
{
   int numClasses, i;
   Class * classes = NULL;

   // Iterate over every classes to find plugin classes
   numClasses = getClassList(NULL, 0);

   if( numClasses > 0 )
   {
      classes = malloc( sizeof(Class) * numClasses );

      (void)getClassList( classes, numClasses );

      for( i = 0; i < numClasses; i++ )
      {
         Class c = classes[i];

         // Retrieve every kind of helper classes we use
         @try
         {
            [self processReaderClass:c];
            [self processWriterClass:c];
            [self processProcessingViewClass:c];
            [self processPreferencesClass:c];
            [self processInterpolatorClass:c];
         }
         @catch (NSException *exception)
         {
            // This class simply cannot be used
            NSLog(@"Exception in plugin initialisation, in class %@", [c className]);
         }
      }

      free(classes);
   }

   [self finalizeReaders];
   [self finalizeWriters];
   [self finalizeProcessingViews];
   [self finalizePreferences];
   [self finalizeInterpolators];
}

- (void) updateProcessMenu:(NSMenu*)procMenu forKind:(ProcessingViewKind_t)kind
{
   NSEnumerator *list = [_processingViewsList objectEnumerator];
   LynkeosProcessingViewRegistry *reg;
   NSMutableArray *kindList = [NSMutableArray array];

   // Extract all the processing view controllers for this kind
   while ( (reg = [list nextObject]) != nil )
   {
      if ( [reg->controller processingViewKindForConfig:reg->config] == kind )
         [kindList addObject:reg];
   }

   // Add to the menu if any controller was found
   if ( [kindList count] != 0 )
   {
      if ( kind != ListManagementKind )
      {
         // Place a separator
         NSMenuItem *sep = [NSMenuItem separatorItem];
         [sep setTag:-1];     // -1 to avoid confusion with the first process
         [procMenu addItem:sep];
      }

      // Sort the controllers by name
      [kindList sortUsingSelector:@selector(caseInsensitiveCompare:)];

      // Add a menu item for each controller
      list = [kindList objectEnumerator];
      while ( (reg = [list nextObject]) != nil )
      {
         NSString *title, *tool, *key, *tip;
         NSImage *icon;

         [reg->controller getProcessingTitle:&title toolTitle:&tool
                                         key:&key icon:&icon tip:&tip
                                   forConfig:reg->config];
         NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title
                                       action:@selector(activateProcessingView:)
                                                keyEquivalent:key];
         if ( [key length] != 0 )
            [item setKeyEquivalentModifierMask: NSCommandKeyMask|NSControlKeyMask];
         if ( tip != nil )
            [item setToolTip:tip];
         NSUInteger tag = [_processingViewsList indexOfObject:reg];
         NSAssert( tag != NSNotFound,
                   @"Unknown processing class for menu item" );
         [item setTag:(NSInteger)tag];
         [procMenu addItem:item];
      }
   }
}

- (void) updateGUI
{
   // Populate the process menu
   NSMenu *procMenu = [[[NSApp mainMenu] itemWithTag:K_PROCESS_MENU_TAG] submenu];
   ProcessingViewKind_t k;

   for( k = ListManagementKind; k <= OtherProcessingKind; k++ )
      [self updateProcessMenu:procMenu forKind:k];

   // And populate the plugin help menu
   NSMenu *helpMenu = [[[NSApp mainMenu] itemWithTag:K_HELP_MENU_TAG] submenu];
   NSMenuItem *pluginHelp = [helpMenu itemWithTag:K_PLUGIN_HELP_MENU_TAG];
   NSEnumerator *bundleList = [_bundlesList objectEnumerator];
   NSBundle *bundle;

   helpMenu = [pluginHelp submenu];
   while( (bundle = [bundleList nextObject]) != nil )
   {
      // Get the help if present
      NSString *helpBook = [bundle objectForInfoDictionaryKey: @"CFBundleHelpBookName"];
      if (helpBook != nil)
      {
         BOOL success = [[NSHelpManager sharedHelpManager] registerBooksInBundle:bundle];
         if (success)
         {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:
                                   [bundle objectForInfoDictionaryKey:@"CFBundleName"]
                                                          action:@selector(openPluginHelp:)
                                                   keyEquivalent:@""];

            [item setTarget:self];
            [item setRepresentedObject:helpBook];
            [helpMenu addItem:item];
         }
      }
   }
}

- (void) openPluginHelp:(id)sender
{
#if !defined GNUSTEP
   NSString *name = [sender representedObject];
   [[NSHelpManager sharedHelpManager] openHelpAnchor:name inBook:name];
#endif
}
@end

@implementation MyPluginsController

+ (MyPluginsController*) defaultPluginController
{
   NSAssert( myInstance != nil, @"The plugin controller is not created" );
   return( myInstance );
}

- (id) init
{
   NSAssert( myInstance == nil,
             @"The plugin controller is already instantiated" );
   if ( (self = [super init]) != nil )
   {
      _imageReadersDict = [[NSMutableDictionary dictionary] retain];
      _movieReadersDict = [[NSMutableDictionary dictionary] retain];
      _imageWritersList = [[NSMutableArray array] retain];
      _movieWritersList = [[NSMutableArray array] retain];
      _processingViewsList = [[NSMutableArray array] retain];
      _preferencesList = [[NSMutableArray array] retain];
      _interpolatorsList = [[NSMutableArray array] retain];
      _bundlesList = [[NSMutableArray array] retain];

      // Load every plugins from their locations
      [self loadPlugins];
      // Retrieve the helpers classes, whether compiled in or a loaded plugin
      [self retrieveClasses];

      myInstance = self;
   }

   return( self );
}

- (void) dealloc
{
   myInstance = nil;

   [_imageReadersDict release];
   [_movieReadersDict release];
   [_imageWritersList release];
   [_movieWritersList release];
   [_processingViewsList release];
   [_preferencesList release];
   [_interpolatorsList release];
   [_bundlesList release];

   [super dealloc];
}

- (void) awakeFromNib
{
   // Update the main menu with processing actions
   [self updateGUI];
}

- (void) registerProcessingViewController:(Class)c
                        withConfiguration:(id)config
                               identifier:(NSString*)ident
{
   LynkeosProcessingViewRegistry *reg =
                     [[[LynkeosProcessingViewRegistry alloc] init] autorelease];

   reg->controller = c;
   reg->config = [config retain];
   reg->ident = [ident retain];

   [_processingViewsList addObject:reg];

}

- (NSDictionary*) getImageReaders { return( _imageReadersDict ); }
- (NSDictionary*) getMovieReaders { return( _movieReadersDict ); }
- (NSArray*) getImageWriters { return( _imageWritersList ); }
- (NSArray*) getMovieWriters { return( _movieWritersList ); }
- (NSArray*) getProcessingViews { return( _processingViewsList ); }
- (NSArray*) getPreferencesPanes { return( _preferencesList ); }
- (NSArray*) getInterpolators { return( _interpolatorsList ); }
- (NSArray*) getLoadedBundles { return( _bundlesList ); }

@end
