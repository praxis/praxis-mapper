# praxis-mapper changelog

## 4.5 (6/25/2019)

* Support wrapping associations in resources for targets that do not explicitly contain the `Enumerable` module. For example,  `ActiveRecord::Associations::CollectionProxy` are actually not enumerable, yet they proxy the calls directly to the underlying objects when necessary.

## 4.4.1 (6/25/2019)

* Fix `Resource` to not override association methods already defined 
* Migrate to FactoryBot

## 4.4 (12/10/2017)

* Fix selector generator to properly handle composite key associations.
* Fix `default_selection` in `Query::Base` to accountt for models with composite identities.
* Support `many_to_many` relationships without requiring the `:through` annotations (for ORMs that
  can transparently load the intermediate relationships)

## 4.3

* Added a `:through` option to `Resource.property` to specify that the property
  effectively traverses the association(s) given so that it may continue to
  process additional subfield selections.
* Fixed `SystemStackError` from `IdentityMap#add_selectors` if the provided
  field hashes are self-referencing. I.e. `{author: {posts: {author: {...}}}}`
* Fixed `SystemStackError` from `SelectorGenerator` for circular `Resource.property` definitions like `property :foo, dependencies: [:foo, :bar]`.
* Fixed `Query::Sequel` not working with raw SQL queries.
* Fixed SQL logging in `Query::Sequel` for query execution passing a dataset.

## 4.2

* Added `Resource.property` to specify the fields and associations from the
  underlying model that are needed by methods added to the `Resource`.
    * For example:
      * `property :full_name, dependencies: [:first, :last]` specifies that the `full_name` method on the resource depends upon the values of the `first`
      and `last` fields from the model.
      * `property :owner_name, dependencies: ['owner.first', 'owner.last']`
      defines a dependency on the `first` and `last` fields from the associated
      `owner`.
    * Dependencies must always be an array. Symbol values should be used for
    fields or associations from the same resource, and strings can be used
    for fields from associated resources.
    * `:*` or `'association.*'` may be used to specify a
    dependency on all of the fields of the resource (analagous to 'SELECT *').
    * Additionally, property dependencies may specify other properties on the
    same or related resources.
* Added `IdentityMap#add_selectors(resource, field_selector)` to define fields to
  `select` and associations to `track` given `resource` and `field_selectors`.
    * For example:
      * `identity_map#add_selectors(PersonResource, full_name: true)` would
      ensure any loads done for the model the `PersonResource` describes will
      select any fields required by the `full_name` property (`first` and `last`
      in the example above).
      * `identity_map#add_selectors(PersonResource, id: true, address: true)`
      could result in selecting the `id` and `address_id` fields of `PersonModel`,
      as well as tracking the `address` association, for any queries involving
      `PersonModel`.
* Added the ability to explicitly perform a "SELECT *" by specifying `select :*`
  or `select '*'` in a query.
* Added `:through` option to many_to_many associations to define the series of
  associations necessary to resolve it. This is unused by Sequel, but is required
  by the SelectorGenerator to handle such associations. Specify it as an array
  of symbols.
  * For example: `many_to_many :commented_posts, through: [:comments, :post], ...`

## 4.1.2

* Remove finalizer from IdentityMap to fix memory leak that was preventing them from being GC'd properly.


## 4.1.1

* Fixed critical bug in `IdentityMap#finalize!`=


## 4.1

* Added instrumentation through `ActiveSupport::Notifications`
  * Use the 'praxis.mapper.load' to subscribe to `IdentityMap.load` calls
  * Use the 'praxis.mapper.finalize' to subscribe to `IdentityMap.finalize!` calls

## 4.0

* Optimization on handling repeated ids (especially noticeable when using subloads)
* Refactored `ConnectionManager` repository handling to improve integration with other connection-pooling (specifically Sequel's at present).
* Added two types of connection factory under `Praxis::Mapper::ConnectionFactories::`:
  * `Simple`: Takes a `connection:` option to specify the raw object to return for all `checkout`. Also, preserves current behavior with proc-based uses when `ConnectionManager.repository` is given a block. This is the default factory type if one is not specified for the repository.
  * `Sequel`: Takes `connection:` option to specify a `Sequel::Database`, or hash of options to pass to `Sequel.connect`.
* `IdentityMap#finalize!` now calls `ConnectionManager#release` to ensure any connections are returned to their respective pools, if applicable.
* Added `SequelCompat` module, which provides support for using `Sequel::Model` objects with an `IdentityMap` when included in model class.
  * This overrides the association accessors on instances associated with an `IdentityMap` (see below for more on this) to query the map instead of database.
  * See (spec/support/spec_sequel_models.rb) for example definition.
* Added prototype for write-path support to `IdentityMap` (for `Sequel::Model` models):
  * `IdentityMap#attach(record)`: adds the record to the identity map, saving it to the database first if it does not have a value for its primary key (or other identities).
  * `IdentityMap#detatch(record)`: removes the record from the identity map
  * `IdentityMap#flush!(record_or_class=nil)`: depending on the value of `record_or_class` it:
    * with no argument, or nil, given it saves all modified records in the identity map.
    * with an instance of a model, it saves just that record.
    * with a model class, it saves all modified records for that class in the identity map.
  * `IdentityMap#remove`: calls `detatch` with the record, and then calls`record.delete` to delete it.


## 3.4.0

* Add preliminary Sequel-centric `Query::Sequel` class that exposes a a Sequel dataset with an interface compatible with other `Query` types.
* Removed `member_name` and `collection_name` methods from `Resource`, as well as the `type` alias.
* Fixed `IdentityMap#load` to return the records from the identity map corresponding to rows returned from the database. This fixes a bug where loading rows already existing in the identity map would return new record objects rather than the objects in the map.

## 3.3.0

* Tightened up handling of missing records in `IdentityMap#all` and `Resource.wrap`. They now will never return `nil` values.


## 3.2.0

* Add `Resource.decorate` for extending/overriding methods on Resource associations. See `PersonResource` in [spec_resources.rb](spec/support/spec_resources.rb) for usage.

## 3.1.2

* Fixed handling of loads where :staged, which could cause an incorrect underlying query using a "staged" column.
* Relaxed ActiveSupport version dependency from 4 to >=3

## 3.1

* Begin migration to Sequel for `Query::Sql`.
  * `#_execute` uses it for a database-agnostic adapter for running raw SQL.
  * `#_multi_get` uses it generate a datbase-agnostic where clause
* Added accessor generation for `one_to_many` associations in resources.
* Imported `Model` extensions for FactoryGirl to `praxis-mapper/support/factory_girl`.
 * This also adds `IdentityMap#persist!` to insert all rows in the identity map into the database.
* Added `SchemaDumper` and `SchemaLoader` for dumping and loading schema information in `praxis-mapper/support/schema_dumper` and `praxis-mapper/support/schema_loader` respectively.
* `IdentityMap#all` now accepts non-identity keys as conditions, and will create a secondary index for the key the first time it's queried.
* Added `Model#identities` to get a hash of identities and values for a record.
* Auto-generated attribute accessors on `Blueprint` do not load (coerce) the value using the attribute. Ensure values passed in already have the appropriate types. Blueprint attributes will still be wrapped properly, however.
* Performance and memory use optimizations.
* `IdentityMap#load` now supports eagerly-loading associated records in a query, and supports the full set of options on the inner query, including
* Tracked `:one_to_many` associations now support where clauses. Using `where` clauses when tracking other association types is not supported and will raise an exception.


## 3.0

* Moved Blueprint inner attribute creation to finalize!
* Added :dsl_compiler and :identity as valid options for Blueprint.
* `Praxis::Mapper::Model`
  * `Model.context` allows named query parameters to be reused across queries. See documentation for details.
  * `Model#_query` references original query that loaded the record.
  * `Model.serialized_fields` returns hash of fields defined with either `json` or `yaml` directives as serialized fields.
  * Fixed accessors will to raise `KeyError` if the record does not the field (i.e., if it was not loaded from the database), rather than silently returning `nil`.
* `Praxis::Mapper::Query`:
  * Multiple `select` and `track` calls within one query are now additive.
  * `track` option now takes a block that will be applied to the query used to load the tracked records.
  * `context` directive to apply the named context from the model to the query. See documentation for more.
* `Praxis::Mapper::IdentityMap`
  * Removed `:track` option from `#add_records` in favor of using `Model#_query` to determine tracked associations.
* Added `Praxis::Mapper::Support` with `MemoryQuery` and `MemoryRepository` for use in testing data loading without requiring a database.


### Notices

The `Model` accessor changes may break existing applications that (incorrectly) expect unloaded attributes to return `nil`.


## 2.1.0

*  Blueprint.validate now only accepts objects of the its type.
*  Improved handling of Blueprints with circular relations.


## 2.0.0

* First pass at reworking model associations.
  * Split `belongs_to` into `many_to_one` and `array_to_many` associations
  * Added `one_to_many` and `many_to_array` associations (the inverse of the above associations, aka: has_many)
  * Added association configuration DSL to replace previous hash-based configuration.


## 0.3.1

* Added support for code coverage
* Added support for 'guard' gem (use 'bundle exec guard')
* Fixed bug in Praxis::Mapper::Model.undefine\_data\_accessors when method doesn't exist.
* Safer version checking with Gem::Version class
* Cleaned up Gemfile
* Updated 'slop' gem


## 0.3.0

* identity map hotfix


## 0.2.0

* don't know what happened here, check git log I guess


## 0.1.0

* initial release
