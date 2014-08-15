# Praxis::Mapper

Praxis::Mapper is a library that allows for large amounts of data to be loaded for a tree of associated models,
while minimizing requests to external services.
It does multi-stage fetch, with compaction between each stage.

Maintained by the RightScale Salmon Team

## Setup

Praxis::Mapper requires Ruby 2.1.0 or higher.

Praxis::Mapper uses rconf to install bundler.

Install latest rconf:

    gem install rconf

Run rconf:

    rconf

## Data store

The configured data stores must be SQL-like.
Examples include:
- MySQL
- CQL
- TagService API

To implement a data store, you must:
- implement one or more models
- configure a connection manager
- configure an identity map
- optionally extend base.rb

## Testing

To run unit tests:

    bundle exec rspec

## Documentation

    bundle exec yard
    bundle exec yard server

## License

This software is released under the [MIT License](http://www.opensource.org/licenses/MIT). Please see  [LICENSE](LICENSE) for further details.

Copyright (c) 2014 RightScale
