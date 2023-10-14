# Firetail

Welcome to the Firetail Ruby gem. Before we start, ensure that your ruby version is 2.7 or greater. We do not support ruby versions lower than 2.7.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'firetail'
```

And then execute:

    $ `bundle install`

Or install it yourself with:

    $ `gem install firetail`

Finally, if you are using Rails, run:

    $ `rails g firetail:install`

This will configure your Rails app to use Firetail gem as middleware and generate configuration and json schema template.

Finally, if you are using Rails, run:

    $ rails g firetail:install

This will configure your Rails app to use the Firetail gem as middleware, and generate configuration and json schema templates.

## Usage

1. Setup your Firetail key by setting environment variable `FIRETAIL_API_KEY`
2. Setup Firetail backend URL by setting the environment variable `FIRETAIL_URL`
**NOTE** For US based customers, use `https://api.logging.us-east-2.prod.us.firetail.app` for `FIRETAIL_URL`. By default `FIRETAIL_URL` uses **EUROPE(EU)** servers.
3. Update `config/schema.json` to match your API endpoints.
4. That's it! Happy coding!

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/firetail-io/firetail-ruby-lib. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the LGPL License.

## Code of Conduct

Everyone interacting in the Firetail project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/firetail-io/firetail-ruby-lib/blob/main/CODE_OF_CONDUCT.md).
