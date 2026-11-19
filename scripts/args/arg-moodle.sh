#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The name of the project: its folder, its DDEV project and its host name.')
parser.add_argument('-i', '--install',
                    action='store_true',
                    default=False,
                    help='Install the site with its own command-line installer; the workspace account is its administrator.')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='With --install, add the default accounts: the ones the test scenarios log in as.')
parser.add_argument('-t', '--test-course',
                    action='store_true',
                    default=False,
                    help='With --install, add the test course of the step pack (a page, an assignment, a quiz and a forum), show the guest login button and turn the user tours off.')
parser.add_argument('-m', '--moodle-version',
                    default="5.3",
                    choices=['5.3', '5.2', '5.1', '5.0', '4.5'],
                    help='The release line: its latest package (5.3 is the current release and a long-term support line, 4.5 the one before it). Example: --moodle-version 4.5')
parser.add_argument('-l', '--launch',
                    action='store_true',
                    default=False,
                    help='Open the login page in a browser when the site is ready.')
parser.add_argument('--php-version',
                    default="",
                    choices=['8.4', '8.3'],
                    help='PHP version for the project container; empty means 8.3 (the lowest 5.3 takes). Example: --php-version 8.4')
ARGEOF
