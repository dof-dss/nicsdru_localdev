# NICS Drupal 8 local development framework

A framework for local development, using the NICS Origins archetype.

# What's in it?

- A local PaaS platform provided by [Lando](https://github.com/lando/lando) giving you a full stack of services, including:
    - Apache web server, running PHP 7.2 with XDebug support.
    - MariaDB database server.
    - Memcached.
    - Solr 7.
    - Mailhog.
    - Chromedriver for headless browser testing (via docker-composer.yml).
- Tooling including:
    - Static analysis tools:
        - PHPCS using Drupal coding standards + best practice profile.
        - Deprecated code check using drupal-check.
        - PHPUnit for unit testing custom code. 
    - Functional testing using Nightwatch.js, based on Drupal core profile.
    - Composer, in case you don't want to or cannot run on your host system.
    - XDebug enable/disable.
    - Drush 8.x and Drupal console
- Origins profile/archetype to give you:
    - Circle CI integration.
    - Standardised Drupal features/config for:
        - Content editing
        - Content workflow
        - Application configuration and structure based on drupal-composer/drupal-project.

# Pre-requisites

- [Lando](https://github.com/lando/lando) [Installation instructions](https://docs.lando.dev/basics/installation.html)

# Get started

## Repository setup

NICS Drupal projects originate from a template repository that you will need to use when setting up a new repo for your project.

1. Create a new repository for the Drupal project in GitHub under [github.com/dof-dss](https://github.com/dof-dss) using the [Origins repository](https://github.com/dof-dss/nicsdru_origins_drupal) as a template.

To allow you to to work locally, you should fork this repository to your own GitHub namespace.

2. Fork this repository allow Lando to run the project on your machine. Eg: `git clone git@github.com:dof-dss/nicsdru_localdev.git nicsdru_projectname`

3. Set up a few key values:

- `config/local.envvars`: set the URL of the new repository created in step 1.
- `cp .lando.example.yml .lando.local.yml`: set a local application name and any local overrides or options.

4. Start Lando / provision the containers:

`cd nicsdru_projectname && lando start`

This may take a while depending on your network speed and machine spec. Docker will need to fetch the container images
if you don't have them, which could be several GB to download at first. Once you have them and Lando's provisioning
script has run then future spin-up times will be very quick.

4. Create feature branches and push/pull in accordance with the git workflow of the team.

# How your project should look once setup has completed

> NB: not every directory/files listed below.

```
.lando.yml [Lando config]
.lando.local.yml [Lando local overrides]
LICENSE
README.md [this file]
drupal/ [where github.com:dof-dss/nicsdru_your-site-name will install to via composer]
    ├── composer.json [defines your Drupal project and dependencies]
    ├── composer.lock [see above]
    ├── config/
        ├── sync [default Drupal config location]
        ├── local [config split for local development]
        └── production [config split for production environment]
    ├── private/ [private files managed by Drupal]
    ├── profiles/ [contrib and custom install profiles]
    ├── web/
        ├── libraries/ [external libraries; managed by composer]
        ├── modules/ [contrib and custom modules]
        ├── themes/ [contrib and custom themes]
        ├── sites/default/
            ├── files/ [managed files]
            ├── services.yml [production services config; referenced in settings.php]
            └── settings.php [built by Lando]
        └── core [Drupal core]
    ├── vendor/ [third party vendor code; managed by composer]
    └── phpcs.sh [PHPCS helper script]
├── config/ [any Lando config]
├── scripts/ [supporting scripts for Lando]
├── imports/ [anything for importing databases/files/content]
└── exports/ [anything coming out from Lando; eg: screenshots]
```

# Tips / troubleshooting

- Your project will contain a few git repos/remotes, be mindful of which repository/remote you are operating against.
- Install https://github.com/thoughtworks/talisman on your host system to avoid committing any sensitive content.