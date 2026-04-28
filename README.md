Edify
================

Edify is a tool for leaders in the Church of Jesus Christ of Latter-day Saints. It keeps track of speakers at Sacrament 
meetings and makes it easier to determine which members may be appropriate to invite to speak.

Ruby on Rails
-------------

This application requires:

- Ruby 4.0
- Rails 8.1

Learn more about [Installing Rails](https://gorails.com/setup/osx/10.12-sierra).

Getting Started
---------------
### Setup Local Environment

Instructions follow for setting up a local development environment in MacOS.

1. Clone the repository to your local machine by [forking the repo](https://help.github.com/articles/fork-a-repo/)

2. Install [Homebrew](http://brew.sh/).

**Ruby**

Ruby is installed by default on all MacOS systems, but it lives in the root directory and probably won't be the correct
version to run Edify. Nearly all Ruby developers use a Ruby environment manager like rbenv, rvm, or asdf. Instructions
for installing rbenv follow, but feel free to use one of the other tools if you wish.

#### Install rbenv

1. `$ brew update`
2. `$ brew install rbenv`

3. `$ cd` into your local `edify` directory
4. `$ rbenv init` For any questions around setting up rbenv see https://github.com/rbenv/rbenv
5. `$ rbenv local` to see the Ruby version Edify is currently using
6. `$ rbenv install <current ruby version>`
7. `$ rbenv rehash` then restart the terminal session

**Postgres**

Edify uses Postgres, so you'll need to install it if you haven't already.

1. `$ brew install postgres`
2. `$ brew services start postgres`

**VIPS**

Edify defaults to the Rails 7 standard of using `vips` for image processing. If you want to be able to test image 
uploads locally, you will need to install it.

> `$ brew install vips`

**Javascript Runtime + Yarn**

1. Node can be installed using homebrew, but it takes a long time and may cause dependency conflicts in your local
environment. Instead, install Node.js by downloading the package installer from nodejs.org
2. Install Yarn with homebrew

> `$ brew install yarn`

**Rails and Gems**

Setup the app by running the setup script:

1. `$ ./bin/setup`
2. `$ ./bin/dev` to start the servers in your dev environment
3. Type `localhost:3000` in a browser

**Loading Test Fixtures**

To populate your development database with test data from fixtures (users, units, meetings, etc.):

```bash
$ bundle exec rails db:from_fixtures
```

This command loads all fixture data from `spec/fixtures/` into your development database, creating test users, units, and associated records.

*Test Users*

After you setup/seed your database, you should have several test users:
```
| Role      | Email                  | Password | Unit            |
| -----     | ---------------------- | -------- | --------------- |
| admin     | admin@example.com      | password | [none]          |
| bishopric | bishopric@example.com  | password | Sunny Hills     |
| clerk     | clerk@example.com      | password | Sunny Hills     |
| music     | music@example.com      | password | Sunny Hills     |
| program   | program@example.com    | password | Sunny Hills     |
| user      | pleasant1@example.com  | password | Pleasant Forest |
| user      | pleasant2@example.com  | password | Pleasant Forest |
| [none]    | unassigned@example.com | password | [none]          |
| [none]    | newunit@example.com    | password | [none]          |
```

You will also have at least two test units (wards). Most test users belongs to a test unit, but some are as yet 
unassigned.

**Credentials**

Edify uses the [Rails Credentials](https://guides.rubyonrails.org/security.html#custom-credentials) feature for storing 
credentials. Credentials are stored in the `config/credentials.yml.enc` file, which can be decrypted using a master key
stored in the `config/master.key` file on your local machine. The `config/master.key` file is not checked into the
repository. Contact a member of the development team if you need access to the Rails master key.

Contact Mark Oveson or Evan Child for further information.

Infrastructure
--------------

Edify runs on **Digital Ocean** via [Hatchbox](https://www.hatchbox.io/):

- **Web + Worker**: DO droplets managed by Hatchbox
- **Database**: DO Managed Postgres
- **Background Jobs**: Solid Queue (runs inside Puma via `plugin :solid_queue`)
- **Email Delivery**: [Mailgun](https://www.mailgun.com/) API (via `mailgun-ruby` gem)
- **Email Event Tracking**: Mailgun webhooks at `POST /webhooks/mailgun_events`, stored as `Analytics::MailgunEvent` records
- **DNS/CDN**: Cloudflare
- **Monitoring**: Scout APM
- **File Storage**: Amazon S3 (via Active Storage)
- **Real-time**: Solid Cable (Action Cable adapter)

**Continuous Integration**

Edify uses Github Actions for CI/CD. When you push a branch, pipeline will run and should pass before merging to master.

Pipeline consists of:
- Specs
- Rubocop (linter)
- Brakeman (security checks)
- Bundle Audit (dependency vulnerability checker)

Support
-------------------------

Still having issues setting up your local environment?
Create an [issue](https://github.com/moveson/edify/issues/new) and we will try to help!

Contributing
-------------

We love Issues but we love Pull Requests more! If you want to change something or add something feel free to do so. If 
you don't have enough time or skills start an issue. Below are some loose guidelines for contributing.

### Pull Requests

Writing code for something is the fastest way to get feedback. It doesn't matter if the code is a work in progress or 
just a spike of an idea we'd love to see it. Testing is critical to our long-term success, so code submissions must 
include tests covering all critical logic. :heart:

### Issues

Be detailed. They only person who knows the bug you are experiencing or feature that you want is you! So please be as 
detailed as possible. Include labels like `bug` or `enhancement` and you know the saying a picture is worth a thousand 
words. So if you can grab a screenshot or gif of the behavior even better!


Credits
-------

Edify got a boost from [Jumpstart](https://github.com/excid3/jumpstart), an open-source project that provides
authentication, notifications, and administrator tools out of the box for new Rails apps.

License
-------

[The MIT License](https://github.com/moveson/edify/blob/master/LICENSE.md)

Copyright
---------

Copyright (c) 2022-2026 by Mark Oveson. See license for details.
