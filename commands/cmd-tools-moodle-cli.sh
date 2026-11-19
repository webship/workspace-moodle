#!/usr/bin/env bash

# Installed by the Moodle plugin (plugins.sh --install moodle); __WORKSPACE__ is the workspace it was installed into.
#
# The command-line scripts of one Moodle site of this workspace (admin/cli/<script>.php), in its
# container: say what the site is, run a script, run cron, purge the caches, upgrade, make the test
# course again, add or remove the default accounts. Nothing here runs on the host.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="moodle";

ARGPARSE_DESCRIPTION="Run the command-line scripts of a Moodle site of __WORKSPACE__: status, a script, cron, caches, upgrade, the test course, the default accounts"
# The args file comes with the plugin: core/scripts/plugins/moodle/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/moodle/args/arg-moodle-cli.sh || exit 1 ;

shift $#;

moodle_cli_tool ;
