#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The Moodle site in this workspace.')
parser.add_argument('-r', '--run',
                    default="_none_",
                    help='A command-line script of the site (admin/cli/<script>.php) with its arguments. Example: --run "cfg --name=release"')
parser.add_argument('-c', '--cron',
                    action='store_true',
                    default=False,
                    help='Run cron once now (it also runs on its own in the container, every minute).')
parser.add_argument('-p', '--purge-caches',
                    action='store_true',
                    default=False,
                    help='Purge all the caches of the site.')
parser.add_argument('-u', '--upgrade',
                    action='store_true',
                    default=False,
                    help='Run the upgrade of the site (after its code changed), without questions.')
parser.add_argument('-t', '--test-course',
                    action='store_true',
                    default=False,
                    help='Make the test course again from nothing, and give the default accounts back their roles in it.')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='Add the default accounts. An account that is already there gets its name, address, password and roles back.')
parser.add_argument('-x', '--cancel-users',
                    action='store_true',
                    default=False,
                    help='Delete the default accounts.')
ARGEOF
