//
//  TVHAdaptersStore.m
//  TvhClient
//
//  Created by zipleen on 06/03/13.
//  Copyright 2013 Luis Fernandes
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//

#import "TVHAdaptersStore.h"
#import "TVHServer.h"

@interface TVHAdaptersStore()
@property (nonatomic, weak) TVHJsonClient *jsonClient;
@property (nonatomic, strong) NSArray *adapters;
@end

@implementation TVHAdaptersStore

- (id)initWithTvhServer:(TVHServer*)tvhServer {
    self = [super init];
    if (!self) return nil;
    self.tvhServer = tvhServer;
    self.jsonClient = [self.tvhServer jsonClient];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(receiveSubscriptionNotification:)
                                                 name:@"tvAdapterNotificationClassReceived"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(fetchAdapters)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.adapters = nil;
}

- (void)receiveSubscriptionNotification:(NSNotification *) notification {
    if ([[notification name] isEqualToString:@"tvAdapterNotificationClassReceived"]) {
        NSDictionary *message = (NSDictionary*)[notification object];
        
        [self.adapters enumerateObjectsUsingBlock:^(TVHAdapter* obj, NSUInteger idx, BOOL *stop) {
            
            if ( [obj.identifier isEqualToString:[message objectForKey:@"identifier"]] ) {
                [obj updateValuesFromDictionary:message];
            }
        }];
        
        [self signalDidLoadAdapters];
    }
}

- (BOOL)fetchedData:(NSData *)responseData {
    NSError __autoreleasing *error;
    NSDictionary *json = [TVHJsonClient convertFromJsonToObject:responseData error:&error];
    if( error ) {
        [self signalDidErrorAdaptersStore:error];
        return false;
    }
    
    NSArray *entries = [json objectForKey:@"entries"];
    NSMutableArray *adapters = [[NSMutableArray alloc] init];
    
    [entries enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        TVHAdapter *adapter = [[TVHAdapter alloc] initWithTvhServer:self.tvhServer];
        [adapter updateValuesFromDictionary:obj];
        [adapter fetchMuxes];
        [adapters addObject:adapter];
    }];
    
    self.adapters = [adapters copy];
    
#ifdef TESTING
    NSLog(@"[Loaded Adapters]: %d", [self.adapters count]);
#endif
    return true;
}

- (void)fetchAdapters {
    
    [self.jsonClient getPath:@"tv/adapter" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        if ( [self fetchedData:responseObject] ) {
            [self signalDidLoadAdapters];
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self signalDidErrorAdaptersStore:error];
        NSLog(@"[Adapter Store HTTPClient Error]: %@", error.localizedDescription);
    }];
    
}

- (TVHAdapter *) objectAtIndex:(int) row {
    if ( row < [self.adapters count] ) {
        return [self.adapters objectAtIndex:row];
    }
    return nil;
}

- (int) count {
    return [self.adapters count];
}

- (void)setDelegate:(id <TVHAdaptersDelegate>)delegate {
    if (_delegate != delegate) {
        _delegate = delegate;
    }
}

- (void)signalWillLoadAdapters {
    if ([self.delegate respondsToSelector:@selector(willLoadAdapters)]) {
        [self.delegate willLoadAdapters];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"willLoadAdapters"
                                                        object:self];
}

- (void)signalDidLoadAdapters {
    if ([self.delegate respondsToSelector:@selector(didLoadAdapters)]) {
        [self.delegate didLoadAdapters];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"didLoadAdapters"
                                                        object:self];
}

- (void)signalDidErrorAdaptersStore:(NSError*)error {
    if ([self.delegate respondsToSelector:@selector(didErrorAdaptersStore:)]) {
        [self.delegate didErrorAdaptersStore:error];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"didErrorAdaptersStore"
                                                        object:error];
}

@end
