#!/usr/bin/env bash

# workspace-name: Moodle (learning site)

# Installed by the Moodle plugin (plugins.sh --install moodle); __WORKSPACE__ is the workspace it was installed into.
#
# Build a Moodle learning site in a container from the release package, on DDEV (the default) at
# https://<name>.ddev.site, or with --runtime docker, podman, kubernetes, lando or docksal at the address the build prints
# (DDEV project type php, the package in moodle/ served from moodle/public, its data folder beside it,
# cron running in the web container). With --install the release's own command-line installer sets it up
# with the workspace account as its administrator; --test-course adds the test course the step pack's
# features use, and --add-users the default accounts.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="moodle";
distribution_title="Moodle";
distribution_webroot="moodle/public";

ARGPARSE_DESCRIPTION="Build a ${distribution_title} learning site in __WORKSPACE__"
# The args file comes with the plugin: core/scripts/plugins/moodle/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/moodle/args/arg-moodle.sh || exit 1 ;

shift $#;

moodle_build ;
