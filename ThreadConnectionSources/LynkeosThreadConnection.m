/*
 * Connection between threads in the same adress space
 * $Id$
 *
 * Created by Jean-Etienne LAMIAUD on Wed May 21 2006
 * Copyright (C) 2006-2019 Jean-Etienne Lamiaud 
 * 
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */
#import <AppKit/AppKit.h>

#include "LynkeosThreadConnection.h"

NSString const * const MyMainThreadConnection = @"MyMainThreadConnection";

#define K_QUEUE_TIMEOUT 0.02

#define K_QUEUE_DEBUG_LEVEL 1
#define K_FULL_DEBUG_LEVEL 2
NSInteger debug = 0;

// Message ids used to switch state
#define InvocationMessage 100
#define InvocationEnd     101

/*!
 * @abstract Connection states
 * @discussion The waiting values are flags
 */
typedef enum
{
   InvocationIdle = 0,
   WaitingInvocationEnd = 1,
} ThreadCnxState_t;

static NSMutableDictionary *mainThreadCnxEnd = nil;

/*!
 * @abstract Connection endpoint
 */
@interface LynkeosThreadCnxEnd : NSObject <NSPortDelegate>
{
@public
   NSPort           *_port;           //!< This end mach port
   ThreadCnxState_t  _state;          //!< The current cnx end state
   int               _messageCount;    //!< Number of pending messages
}

/*!
 * @abstract Dedicated initializer
 * @param port This endpoint mach port
 * @param queueSize Second level queue size (can be 0)
 * @result Initialized connection endpoint
 */
- (id) initWithPort:(NSPort*)port;

/*!
 * @abstract Change the number of pending messages in the connection
 * @param n The number of messages to add (can be negative)
 */
- (void) adjustMessageCount:(int)n ;

/*!
 * @abstract Get the main thread connection end singleton
 */
+ (LynkeosThreadCnxEnd*) getMainThreadCnxEndWithPort:(NSPort*)port;
@end

@implementation LynkeosThreadCnxEnd

+ (void) initialize
{
   mainThreadCnxEnd = [[NSMutableDictionary alloc] init];
}

- (id) initWithPort:(NSPort*)port
{
   if ( (self = [self init]) != nil )
   {
      _port = [port retain];
      _state = InvocationIdle;
      _messageCount = 0;
      [_port setDelegate:self];
   }

   return( self );
}

- (void) dealloc
{
   if ( _port != nil )
   {
      NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
      if (runLoop != nil)
      {
         [runLoop removePort:_port forMode:NSDefaultRunLoopMode];
      }
   [_port release];
   }
   [super dealloc];
}

- (void) adjustMessageCount:(int)n
{
   while(!__sync_bool_compare_and_swap( &_messageCount, _messageCount, _messageCount+n ))
      ;
}

- (void)handlePortMessage:(NSPortMessage *)portMessage
{
   switch( [portMessage msgid] )
   {
      case InvocationMessage:
      {
         NSPortMessage *reply;
         NSInvocation *inv;
         [[[portMessage components] objectAtIndex:0] getBytes:&inv length:sizeof(NSInvocation*)];
         BOOL sync = ![[inv methodSignature] isOneway];

         [inv invoke];
         [self adjustMessageCount:-1];
         if ( debug >= K_FULL_DEBUG_LEVEL )
            NSLog( @"Handle  : %s", sel_getName([inv selector]) );

         if ( sync )
         {
            // Send the reply
            reply = [[NSPortMessage alloc] initWithSendPort: [portMessage sendPort]
                                                receivePort: [portMessage receivePort]
                                                 components: nil];
            [reply setMsgid:InvocationEnd];
            while ( ![reply sendBeforeDate: [NSDate dateWithTimeIntervalSinceNow:K_QUEUE_TIMEOUT]] )
            {
               if ( debug >= K_QUEUE_DEBUG_LEVEL )
                  NSLog( @"Failed to reply to a synchronous call, retrying..." );
            }
            if ( debug >= K_FULL_DEBUG_LEVEL )
               NSLog( @"Handle  : Sync call reply" );
         }
         else
            // Release async invocations here
            [inv release];
      }
      break;

      case InvocationEnd:
      {
         NSAssert1( (_state & WaitingInvocationEnd) != InvocationIdle,
                   @"Invocation end in unexpected state %d", _state );
         _state &= ~WaitingInvocationEnd;
      }
      break;

      default:
         NSAssert1( NO, @"Unknown thread message id %d", [portMessage msgid] );
         break;
   }
}

+ (LynkeosThreadCnxEnd*) getMainThreadCnxEndWithPort:(NSPort *)port
{
   LynkeosThreadCnxEnd *cnxEnd = [mainThreadCnxEnd objectForKey:port];
   if (cnxEnd == nil)
   {
      cnxEnd = [[[LynkeosThreadCnxEnd alloc] initWithPort:port] autorelease];
      [mainThreadCnxEnd setObject:cnxEnd forKey:port];

      // Install the port as an input source on the current run loop (main thread).
      [[NSRunLoop currentRunLoop] addPort: port forMode: NSDefaultRunLoopMode];
      // and also for event tracking in the main thread
      [[NSRunLoop currentRunLoop] addPort: port forMode: NSEventTrackingRunLoopMode];
   }

   return cnxEnd;
}
@end

/*!
 * @abstract Internal part of the connection class
 */
@interface LynkeosThreadConnection(QueueMgt)
/*!
 * @abstract Send a method invocation to an object over the connection
 * @param inv The invocation
 * @param inThread NO if the receiver is in the main thread
 */
- (void) sendInvocation:(NSInvocation*)inv inThread:(BOOL)inThread ;
@end

#define K_MAIN_ENDPOINT   0
#define K_THREAD_ENDPOINT 1

/*!
 * @abstract Proxy object for an object accessed across a MyThreadConnection
 */
@interface MyThreadProxy : NSProxy
{
@private
   id                  _object;    //!< Object for which we are a proxy
   BOOL                _inThread;  //!< Is the proxy for a "thread side" object
   LynkeosThreadConnection *_cnx;       //!< Owner connection
}

/*!
 * @abstract Creation of a proxy object
 * @param object The object for which we will be a proxy
 * @param cnx The connection through wich messages are sent and received
 * @param inThread Wether the object is in the thread
 * @result The new proxy object
 */
- (id) initWithObject:(id)object cnx:(LynkeosThreadConnection*)cnx inThread:(BOOL)inThread;

@end

@implementation MyThreadProxy

- (id) init
{
   _object = nil;
   _cnx = nil;

   return( self );
}

- (id) initWithObject:(id)object cnx:(LynkeosThreadConnection*)cnx inThread:(BOOL)inThread
{
   if ( (self = [self init]) != nil )
   {
      // Do not retain object because we are agregated to it
      _object = object;
      _cnx = cnx;  // Loose binding
      _inThread = inThread;
   }

   return( self );
}

- (NSMethodSignature *) methodSignatureForSelector:(SEL)aSelector
{
   return( [_object methodSignatureForSelector: aSelector] );
}


- (void) forwardInvocation:(NSInvocation *)anInvocation
{
   [anInvocation setTarget:_object];
   [_cnx sendInvocation:anInvocation inThread:!_inThread];
}

@end

@implementation LynkeosThreadConnection(QueueMgt)

- (void) sendInvocation:(NSInvocation*)inv inThread:(BOOL)inThread
{
   BOOL sync = ![[inv methodSignature] isOneway];
   LynkeosThreadCnxEnd *sendPoint = _endPoint[inThread ? K_MAIN_ENDPOINT : K_THREAD_ENDPOINT ];
   LynkeosThreadCnxEnd *recvPoint = _endPoint[inThread ? K_THREAD_ENDPOINT : K_MAIN_ENDPOINT ];

   // Retain the arguments because they may be autoreleased before invocation in the thread
   [inv retainArguments];

   if ( ! sync )
      // Retain the invocation because it will be released by the caller
      // and will not be retained by the port message (cf. "by address")
      [inv retain];

   // Send the invocation by address through the port
   NSPortMessage* messageObj = [[NSPortMessage alloc] initWithSendPort: sendPoint->_port
                                                           receivePort: recvPoint->_port
                                                            components: [NSArray arrayWithObject:
                                                   [NSData dataWithBytes:&inv length:sizeof(NSInvocation*)]]];
   [messageObj setMsgid:InvocationMessage];

   // Prepare synchronous calls
   if ( sync )
      recvPoint->_state |= WaitingInvocationEnd;

   // Try to send until it succeed
   while( ![messageObj sendBeforeDate: [NSDate dateWithTimeIntervalSinceNow:K_QUEUE_TIMEOUT]] )
      ;
   [sendPoint adjustMessageCount:1];
   if ( debug >= K_FULL_DEBUG_LEVEL )
      NSLog( @"Forward : sent %s", sel_getName([inv selector]) );

   // Wait synchronous call end
   if ( sync )
   {
      if ( debug >= K_FULL_DEBUG_LEVEL )
         NSLog( @"Forward : Sync call waiting for end" );
      while ( recvPoint->_state != InvocationIdle )
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                     beforeDate:[NSDate distantFuture]];
      if ( debug >= K_FULL_DEBUG_LEVEL )
         NSLog( @"Forward : Sync call ended" );
   }
}
@end

@implementation LynkeosThreadConnection

- (id) init
{
   if ( (self = [super init]) != nil )
   {
      _endPoint[K_MAIN_ENDPOINT] = nil;
      _endPoint[K_THREAD_ENDPOINT] = nil;
      _rootObject = nil;
      _rootProxy = nil;
      debug = [[NSUserDefaults standardUserDefaults] integerForKey: @"ThreadConnectionDebug"];
   }

   return( self );
}

- (void) dealloc
{
   // Wait first for processing of all messages
   while ( _endPoint[K_THREAD_ENDPOINT]->_messageCount != 0 )
      [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
                               beforeDate: [NSDate dateWithTimeIntervalSinceNow:K_QUEUE_TIMEOUT]];

   if ( _endPoint[K_MAIN_ENDPOINT] != nil )
      [_endPoint[K_MAIN_ENDPOINT] release];
   if ( _endPoint[K_THREAD_ENDPOINT] != nil )
      [_endPoint[K_THREAD_ENDPOINT] release];

   if ( _rootObject != nil )
      [_rootObject release];
   if ( _rootProxy != nil )
      // The proxy is aggregated to us
      [_rootProxy dealloc];

   [super dealloc];
}

- (NSPort*) mainPort { return _endPoint[K_MAIN_ENDPOINT]->_port; }

- (NSPort*)threadPort { return _endPoint[K_THREAD_ENDPOINT]->_port; }

- (BOOL) connectionIdle
{
   return( _endPoint[K_THREAD_ENDPOINT]->_messageCount == 0
           && _endPoint[K_THREAD_ENDPOINT]->_state == InvocationIdle);
}

- (void) setRootObject:(id)anObject
{
   NSAssert(_rootObject == nil,@"Forbidden change of connection root object");
   _rootObject = [anObject retain];
}

- (NSProxy*) proxyForObject:(id)object inThread:(BOOL)inThread
{
   return( [[[MyThreadProxy alloc] initWithObject:object cnx:self
                                         inThread:inThread] autorelease]);
}

- (NSProxy*) rootProxy
{
   NSAssert( _rootObject != nil, @"Call to rootProxy without root object" );
   if ( _rootProxy == nil )
   {
      _rootProxy = [[self proxyForObject:_rootObject inThread:NO] retain];
      // Register the port 
      [[NSRunLoop currentRunLoop] addPort:_endPoint[K_THREAD_ENDPOINT]->_port
                                  forMode:NSDefaultRunLoopMode];
      // And register that we are the connection with the main thread
      NSMutableDictionary *dict = [[NSThread currentThread] threadDictionary];
      [dict setObject:self forKey:MyMainThreadConnection];
   }
   return( _rootProxy );
}

+ (void) performSelectorOnMainThread:(SEL)sel forObject:(NSObject*)target
                             withArg:(id)arg
{
   LynkeosThreadConnection* cnx =
      [[[NSThread currentThread] threadDictionary] objectForKey:
                                                        MyMainThreadConnection];
   NSAssert( cnx != nil, @"no connection in thread" );

   NSMethodSignature* sig = [target methodSignatureForSelector:sel];
   NSInvocation* inv = [NSInvocation invocationWithMethodSignature:sig];
   [inv setSelector:sel];
   [inv setTarget:target];
   if ( arg != nil )
      [inv setArgument:&arg atIndex:2];

   [cnx sendInvocation:inv inThread:YES];
}

- (id)initWithMainPort:(NSPort*)mainPort threadPort:(NSPort*)threadPort
{
   if ( (self = [self init]) != nil )
   {
      _endPoint[K_MAIN_ENDPOINT] = [[LynkeosThreadCnxEnd getMainThreadCnxEndWithPort:mainPort] retain];
      _endPoint[K_THREAD_ENDPOINT] = [[LynkeosThreadCnxEnd alloc] initWithPort:threadPort];
   }

   return( self );
}
@end
