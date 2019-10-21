#!/usr/bin/env bash

# VARIABLE BELOW COMES FROM READING A VALUE FROM LANDO ENV VARS AND MUST BE SET
# BEFORE STARTING THE PROJECT OR THERE WON'T BE A SUCCESSFUL GIT CLONE OPERATION
# AND THE SCRIPT WILL FAIL.
DRUPAL_REPO_URL=`grep DRUPAL_PROJECT_URL /app/config/local.envvars | sed 's/^.*=//'`
DRUPAL_ROOT=/app/drupal/web
DRUPAL_SETTINGS_FILE=$DRUPAL_ROOT/sites/default/settings.php
DRUPAL_SERVICES_FILE=$DRUPAL_ROOT/sites/default/services.yml
DRUPAL_CUSTOM_CODE=$DRUPAL_ROOT/modules/custom

# List of repos we want to check for dev branches + pull to update after provisioning.
REPOS=(
    modules/custom
)

# Semaphore files to control whether we need to trigger an install
# of supporting software or config files.
NODE_YARN_INSTALLED=/etc/NODE_YARN_INSTALLED

# Create export directories for config and data.
if [ ! -d "/app/exports" ]; then
  echo "Creating export directories"
  mkdir -p /app/exports/config && mkdir /app/exports/data
fi

# If we don't have a Drupal 8 install, download it.
if [ ! -d "/app/drupal" ]; then
  echo "Cloning NICS Origins archetype repository..."
  git clone $DRUPAL_REPO_URL /app/drupal/
  composer -d/app/drupal install
  echo "Building Drupal files..."
  composer -d/app/drupal drupal:scaffold
  composer -d/app/drupal run-script post-install-cmd
fi

if [ ! -d "/app/drupal/web/modules/custom" ]; then
  echo "Creating folder for custom modules..."
  mkdir -p /app/drupal/web/modules/custom
fi

if [ ! -d "/app/drupal/web/profiles/custom" ]; then
  echo "Creating folder for custom profiles..."
  mkdir -p /app/drupal/web/profiles/custom
fi

if [ ! -d "/app/drupal/web/themes/custom" ]; then
  echo "Creating folder for custom themes..."
  mkdir -p /app/drupal/web/themes/custom
fi

if [ ! -d "/app/drupal/config/sync" ]; then
  echo "Creating folder for Drupal config..."
  mkdir -p /app/drupal/config/sync
fi

if [ ! -d "/app/drupal/config/production" ]; then
  echo "Creating folder for production config split..."
  mkdir -p /app/drupal/config/production
fi

if [ ! -d "/app/drupal/config/local" ]; then
  echo "Creating folder for local development config split..."
  mkdir -p /app/drupal/config/local
fi

# Scan through repos we know could be on non-tagged releases
# and git pull to ensure latest code; something composer doesn't do for us.
for repo in "${REPOS[@]}"
do
  cd $DRUPAL_ROOT/$repo

  # Tags won't show any output, so git pull the ones that aren't tags.
  if [[ $(git symbolic-ref --short HEAD) ]]; then
    echo "Fetching latest contents of repository at ${DRUPAL_ROOT}/${repo}"
    git pull
  else
    echo "Skipping ${DRUPAL_ROOT}/${repo} as it is presently checked out on release tag"
  fi
done

# Create Drupal private file directory above web root.
if [ ! -d "/app/drupal/private" ]; then
  echo "Creating private Drupal files directory"
  mkdir -p /app/drupal/private
fi

# Set local environment settings at end of settings.php file.
chmod -R +rw $DRUPAL_ROOT/sites/default
cp -v $DRUPAL_ROOT/sites/default/default.settings.php $DRUPAL_SETTINGS_FILE

echo "Append local environment settings to settings.php file"
cat /app/config/drupal.settings >> $DRUPAL_SETTINGS_FILE

echo "Creating settings.local file"
cp -v $DRUPAL_ROOT/sites/example.settings.local.php $DRUPAL_ROOT/sites/default/settings.local.php

# Copy default services config and replace key values for local development.
cp /app/config/default.services.yml $DRUPAL_SERVICES_FILE
sed -i -e "s|\(gc_maxlifetime\:\) \(200000\)|\1 86400|g" $DRUPAL_SERVICES_FILE
sed -i -e "s|\(cookie_lifetime\:\) \(2000000\)|\1 86400|g" $DRUPAL_SERVICES_FILE
sed -i -e "s|\(http.response.debug_cacheability_headers\: \)|\1 false|g" $DRUPAL_SERVICES_FILE

chmod -w $DRUPAL_ROOT/sites/default

# Set Simple test variables and put PHPUnit config in place.
if [ ! -f "${DRUPAL_ROOT}/core/phpunit.xml" ]; then
  echo "Adding localised PHPUnit config to Drupal webroot"
  cp $DRUPAL_ROOT/core/phpunit.xml.dist $DRUPAL_ROOT/core/phpunit.xml
  # Fix bootstrap path
  sed -i -e "s|bootstrap=\"tests/bootstrap.php\"|bootstrap=\"${DRUPAL_ROOT}/core/tests/bootstrap.php\"|g" $DRUPAL_ROOT/core/phpunit.xml
  # Inject database params for kernel tests.
  sed -i -e "s|name=\"SIMPLETEST_DB\" value=\"\"|name=\"SIMPLETEST_DB\" value=\"${DB_DRIVER}://${DB_USER}:${DB_PASS}@${DB_HOST}/${DB_NAME}\"|g" $DRUPAL_ROOT/core/phpunit.xml
  # Uncomment option to switch off Symfony deprecatons helper (we use drupal-check for this).
  sed -i -e "s|<!-- <env name=\"SYMFONY_DEPRECATIONS_HELPER\" value=\"disabled\"/> -->|<env name=\"SYMFONY_DEPRECATIONS_HELPER\" value=\"disabled\"/>|g" $DRUPAL_ROOT/core/phpunit.xml
  # Set the base URL for kernel tests.
  sed -i -e "s|name=\"SIMPLETEST_BASE_URL\" value=\"\"|name=\"SIMPLETEST_BASE_URL\" value=\"http:\/\/${LANDO_APP_NAME}.${LANDO_DOMAIN}\"|g" $DRUPAL_ROOT/core/phpunit.xml
fi

# Add yarn/nodejs packages to allow functional testing on this service.
if [ ! -f "$NODE_YARN_INSTALLED" ]; then
  # Update packages and add gnupg and https for apt to fetch yarn packages.
  apt update
  apt install -y gnupg apt-transport-https
  # Add yarn deb repo.
  curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
  echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
  apt update
  apt install -y yarn
  # Add and fetch up to date nodejs to allow yarn to run correctly.
  curl -sL https://deb.nodesource.com/setup_10.x | bash -
  apt install -y nodejs

  # Copy Drupal .env.example file, inject Lando vars and set in place for use by Nightwatch conf.
  cat $DRUPAL_ROOT/core/.env.example | sed -e "s|\(^DRUPAL_TEST_BASE_URL\)\(.\+\)|\1=http:\/\/${LANDO_APP_NAME}.${LANDO_DOMAIN}|g" > $DRUPAL_ROOT/core/.env
  # Alter a few more variables.
  sed -i -e "s|\(#\)\(DRUPAL_NIGHTWATCH_SEARCH_DIRECTORY\)=|\2=../|g" $DRUPAL_ROOT/core/.env
  sed -i -e "s|sqlite:\/\/localhost\/sites\/default\/files/db.sqlite|${DB_DRIVER}://${DB_USER}:${DB_PASS}@${DB_HOST}/${DB_NAME}|g" $DRUPAL_ROOT/core/.env
  sed -i -e "s|\(^DRUPAL_TEST_WEBDRIVER_HOSTNAME\)=localhost|\1=chromedriver|g" $DRUPAL_ROOT/core/.env
  sed -i -e "s|^DRUPAL_TEST_CHROMEDRIVER_AUTOSTART=true|DRUPAL_TEST_CHROMEDRIVER_AUTOSTART=false|g" $DRUPAL_ROOT/core/.env
  sed -i -e "s|\(#\)\(DRUPAL_TEST_WEBDRIVER_CHROME_ARGS\)=|\2=\"--disable-gpu --headless --no-sandbox\"|g" $DRUPAL_ROOT/core/.env
  sed -i -e "s|\(^DRUPAL_NIGHTWATCH_OUTPUT\)=reports/nightwatch|\1=/app/exports/nightwatch-reports|g" $DRUPAL_ROOT/core/.env

  # Fetch and install node packages if they're not already present.
  if [ ! -d "${DRUPAL_ROOT}/core/node_modules" ]; then
    cd $DRUPAL_ROOT/core && yarn install
  fi

  # Install any known extra npm packges for, eg: migrations.
  if [ ! -d "${DRUPAL_MIGRATE_CODE}/migrate_nidirect_node/node_modules" ]; then
    cd $DRUPAL_MIGRATE_CODE/migrate_nidirect_node
    npm install
  fi

  if [ ! -d "${DRUPAL_CUSTOM_CODE}/node_modules" ]; then
    cd $DRUPAL_CUSTOM_CODE
    npm install
  fi

  touch $NODE_YARN_INSTALLED

fi

# Add talismanrc to all known repos in this project, so we don't accidentally commit anything sensitive.
echo "Adding talismanrc files to repos in this project"
cp /app/config/talisman.config /app/.talismanrc
cp /app/config/talisman.config /app/drupal/.talismanrc
cp /app/config/talisman.config $DRUPAL_CUSTOM_CODE/.talismanrc

cat << EOF

===============================================================================
⚠️                  INSTALL TALISMAN FOR LOCAL DEVELOPMENT                   ⚠️

You are *STRONGLY* recommend to use Talisman (by Thoughtworks) to ensure that
potential secrets or sensitive information do not leave your workstation.

Talisman runs on your host OS and scans your commits against open-source
detector plugins for things such as auth tokens, SSH keys, credit card numbers
or large binary files that can indicate unwanted data in a repository.

If it finds something suspicious it will reject your local commit and tell you,
allowing you to fix it or tell Talisman to ignore a false-positive.

PLEASE NOTE:

- You need to install Talisman on your HOST system.
- Talisman is most effective as a global pre-commit git hook.
- You can install it per repository but it requires more configuration on your part.
- It is a one-off task, but it can save you a very awkward conversation in future.

INSTALLATION:

👉 https://github.com/thoughtworks/talisman#installation-as-a-global-hook-template

EOF
