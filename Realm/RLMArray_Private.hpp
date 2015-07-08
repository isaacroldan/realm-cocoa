////////////////////////////////////////////////////////////////////////////
//
// Copyright 2014 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

#import "RLMArray_Private.h"
#import <Realm/RLMResults.h>

#import <memory>
#import <realm/views.hpp>

namespace realm {
    class LinkView;
    class Query;
    class TableView;

    namespace util {
        template<typename T> class bind_ptr;
    }
    typedef util::bind_ptr<LinkView> LinkViewRef;
}

@class RLMObjectSchema;

@protocol RLMFastEnumerable
@property (nonatomic, readonly) RLMRealm *realm;

- (NSUInteger)indexInSource:(NSUInteger)index;
- (realm::TableView)tableView;
@end

// RLMArray private properties/ivars for all subclasses
@interface RLMArray () {
  @protected
    // accessor ivars
    RLMRealm *_realm;
    NSString *_objectClassName;
}

// initializer
- (instancetype)initWithObjectClassName:(NSString *)objectClassName standalone:(BOOL)standalone;
@end


//
// LinkView backed RLMArray subclass
//
@interface RLMArrayLinkView : RLMArray <RLMFastEnumerable>
+ (instancetype)arrayWithObjectClassName:(NSString *)objectClassName
                                    view:(realm::LinkViewRef)view
                                   realm:(RLMRealm *)realm;

// deletes all objects in the RLMArray from their containing realms
- (void)deleteObjectsFromRealm;
@end


//
// RLMResults private methods
//
@interface RLMResults () <RLMFastEnumerable>
+ (instancetype)resultsWithObjectClassName:(NSString *)objectClassName
                                     query:(std::unique_ptr<realm::Query>)query
                                     realm:(RLMRealm *)realm;

+ (instancetype)resultsWithObjectClassName:(NSString *)objectClassName
                                     query:(std::unique_ptr<realm::Query>)query
                                      view:(realm::TableView &&)view
                                     realm:(RLMRealm *)realm;

+ (instancetype)resultsWithObjectClassName:(NSString *)objectClassName
                                     query:(std::unique_ptr<realm::Query>)query
                                      sort:(realm::RowIndexes::Sorter const&)sorter
                                     realm:(RLMRealm *)realm;

- (void)deleteObjectsFromRealm;
@end

//
// RLMResults subclass used when a TableView can't be created - this is used
// for readonly realms where we can't create an underlying table class for a
// type, and we need to return a functional RLMResults instance which is always empty.
//
@interface RLMEmptyResults : RLMResults
+ (instancetype)emptyResultsWithObjectClassName:(NSString *)objectClassName
                                          realm:(RLMRealm *)realm;
@end

// RLMResults backed by a realm::Table directly rather than using a TableView
@interface RLMTableResults : RLMResults
+ (RLMResults *)tableResultsWithObjectSchema:(RLMObjectSchema *)objectSchema realm:(RLMRealm *)realm;
@end

// An object which encapulates the shared logic for fast-enumerating RLMArray
// and RLMResults, and has a buffer to store strong references to the current
// set of enumerated items
@interface RLMFastEnumerator : NSObject
- (instancetype)initWithCollection:(id<RLMFastEnumerable>)collection objectSchema:(RLMObjectSchema *)objectSchema;

// Detach this enumerator from the source collection. Must be called before the
// source collection is changed.
- (void)detach;

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                    count:(NSUInteger)len;
@end
