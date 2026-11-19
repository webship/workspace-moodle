#!/usr/bin/env bash

# Moodle for the Webship Workspace: build a learning site from the release package with its own
# command-line installer, run its command-line scripts, add its default accounts and its test course,
# and wire its step pack into the testing setup.
#
# Placed by `plugins.sh --install moodle` in core/scripts/plugins/moodle/functions/, where bootstrap
# sources it after the core's own functions. Everything runs in the project's container (DDEV by
# default: `ddev exec php moodle/admin/cli/…`), never on the host. DDEV has no project type of its own
# for Moodle: a project is of type php, and the plugin knows it by its files (moodle/version.php, or
# moodle/public/version.php from 5.1 on). The release package sits in moodle/ and its data folder
# moodledata/ beside it, outside the web root; the top of the project stays free for the testing setup
# (the package's own package.json is its development tooling).
#
# Four names are the ones the core's tools look for:
#   set_moodle_users          the default accounts            (cmd-tools-add-users.sh <project> moodle)
#   add_moodle_users          create them through the site    (the same tool, and --add-users of the builder)
#   cancel_moodle_users       delete them                     (cmd-tools-cancel-users.sh <project> moodle)
#   testing_configure_moodle  the step pack in the testing stack (cmd-tools-testing.sh <project>)

# The step pack a Moodle site is tested with, and the release line it is required at.
readonly MOODLE_STEPS_PACKAGE='@webship-js/moodle-steps';
readonly MOODLE_STEPS_VERSION='^2.0.0';

# The PHP script that writes the test site through the site's own API (the settings the step pack relies
# on, the test course, the accounts): placed with the plugin in core/scripts/plugins/moodle/.
MOODLE_TEST_SITE_PHP="${WORKSPACE_SCRIPTS}/plugins/moodle/test-site.php";

# The default accounts, the ones a scenario logs in as: one per role the step pack's features use.
# Accounts are configuration, created once on the site; a test suite never creates or deletes one.
#   administrator  a site administrator
#   manager        the Manager role on the whole site (course management, not the site settings)
#   teacher        Teacher (editing) in the test course
#   student        Student in the test course
#   student2       in no course: the account that enrols itself with the key
function set_moodle_users() {
  users=(administrator manager teacher student student2);
  local user ;
  for user in "${users[@]}" ; do
    printf -v "user_${user}_name" '%s' "${user}" ;
    printf -v "user_${user}_mail" '%s' "${user}@example.com" ;
    printf -v "user_${user}_password" '%s' 'dD.123123ddd' ;
    printf -v "user_${user}_lastname" '%s' 'User' ;
  done
  user_administrator_firstname='Administrator' ;
  user_manager_firstname='Manager' ;
  user_teacher_firstname='Teacher' ;
  user_student_firstname='Student' ;
  user_student2_firstname='Student2' ;
  user_administrator_role='siteadmin' ;
  user_manager_role='manager' ;
  user_teacher_role='editingteacher' ;
  user_student_role='student' ;
  user_student2_role='' ;
}

# Is this folder a Moodle project? A container project with the release package in moodle/.
function moodle_is_project() {
  local project_path="$1";
  [ -f "${project_path}/.ddev/config.yaml" ] || return 1 ;
  local version="${project_path}/moodle/public/version.php" ;
  [ -f "${version}" ] || version="${project_path}/moodle/version.php" ;
  [ -f "${version}" ] && grep -q '\$release' "${version}" 2>/dev/null ;
}

# Is the site of the current folder installed? Its installer writes moodle/config.php.
function moodle_is_installed() {
  [ -f moodle/config.php ] ;
}

# Go to the project a tool was asked about, or say why not.
function moodle_enter_project() {
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}";
  if [ ! -d "${project_path}" ] ; then
    echo "No project ${PROJECT_NAME} in ${WORKSPACE_ROOT}/${doc_name}." ;
    return 1 ;
  fi
  if ! moodle_is_project "${project_path}" ; then
    echo "${doc_name}/${PROJECT_NAME} is not a Moodle project (it has no moodle/version.php of the release package)." ;
    return 1 ;
  fi
  cd "${project_path}" || return 1 ;
}

# The stable branch of a release line: 5.3 → 503, 4.5 → 405.
function moodle_branch() {
  local line="$1" major minor ;
  major="${line%%.*}" ; minor="${line#*.}" ;
  printf '%d%02d' "${major}" "${minor}" ;
}

# Cron for the site, the way it asks for it: admin/cli/cron.php again and again in the web container, run
# by the container's own process supervisor. Each run keeps polling for new tasks for a minute; a run that
# cannot start yet (no site, an install going on) is tried again ten seconds later.
function moodle_write_cron() {
  cat > .ddev/cron.sh <<'CRONEOF'
#!/usr/bin/env bash
while true; do
  if [ -f /var/www/html/moodle/config.php ]; then
    php /var/www/html/moodle/admin/cli/cron.php --keep-alive=60 >> /tmp/cron.log 2>&1 || sleep 10
  else
    sleep 10
  fi
done
CRONEOF
  cat > .ddev/config.cron.yaml <<'CRONEOF'
web_extra_daemons:
  - name: "cron"
    command: "bash /var/www/html/.ddev/cron.sh"
    directory: /var/www/html
CRONEOF
}

# Run the plugin's PHP script for the test site (test-site.php) in the web container, with the
# arguments given. The script is in the project only for the time of the call.
function moodle_test_site() {
  if [ ! -f "${MOODLE_TEST_SITE_PHP}" ] ; then
    echo "  ${MOODLE_TEST_SITE_PHP} is missing: install the plugin again (plugins.sh --install moodle)." ;
    return 1 ;
  fi
  cp "${MOODLE_TEST_SITE_PHP}" .webship-test-site.php || return 1 ;
  ddev exec php /var/www/html/.webship-test-site.php --config=/var/www/html/moodle/config.php "$@" < /dev/null ;
  local rc=$? ;
  rm -f .webship-test-site.php ;
  return ${rc} ;
}

# Write accounts through the site itself, with the test-site script: lines of
# "username|email|password|firstname|lastname|role" on standard input, where the role is siteadmin, a
# role of the whole site (manager), a role in the test course (editingteacher, student) or nothing (in
# no course). "delete" as the first argument removes the accounts of those user names instead.
function moodle_write_accounts() {
  local action="${1:-save}" ;
  if ! moodle_is_installed ; then
    echo "  The site is not installed yet: build it with --install to have accounts." ;
    return 1 ;
  fi
  python3 -c '
import json, sys
rows = [line.split("|") for line in sys.stdin.read().splitlines() if line.strip()]
accounts = []
for r in rows:
    r += [""] * (6 - len(r))
    a = {"username": r[0], "email": r[1], "password": r[2], "firstname": r[3], "lastname": r[4]}
    role = r[5]
    if role == "siteadmin": a["siteadmin"] = True
    elif role in ("manager", "coursecreator"): a["systemrole"] = role
    elif role: a["courserole"] = role
    accounts.append(a)
print(json.dumps(accounts))' > .webship-test-accounts.json || return 1 ;
  local rc=0 ;
  if [ "${action}" == 'delete' ] ; then
    moodle_test_site --delete-accounts=/var/www/html/.webship-test-accounts.json || rc=$? ;
  else
    moodle_test_site --accounts=/var/www/html/.webship-test-accounts.json || rc=$? ;
  fi
  rm -f .webship-test-accounts.json ;
  return ${rc} ;
}

# Build a learning site from nothing: the container, the release package in moodle/ with its data folder
# beside it, and with --install the site installed by its own command-line installer, with the workspace
# account as its administrator; --test-course and --add-users write the test site.
function moodle_build() {
  trim_project_name ;
  local base_url="https://${PROJECT_NAME}.ddev.site" ;
  local php_version="${PHP_VERSION:-${site_php_version:-8.3}}" ;
  local line="${MOODLE_VERSION:-5.3}" ;
  local branch ; branch="$(moodle_branch "${line}")" ;
  local package_url="https://download.moodle.org/download.php/direct/stable${branch}/moodle-latest-${branch}.tgz" ;
  local database='mariadb:11.4' ;

  cd ${WORKSPACE_ROOT}/${doc_name} || exit 1 ;

  drop_database ;
  rm -rf "${PROJECT_NAME}" ;
  mkdir -p "${PROJECT_NAME}" ;
  cd ${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME} || exit 1 ;

  # DDEV has no project type for Moodle: php, served by Apache as the documented DDEV way does (the file and
  # theme addresses carry a path after the script), from moodle/public (5.1 and later; moodle/ before),
  # with the database the release needs (5.3: MariaDB 11.4 or later).
  ddev config --project-type=php --docroot=moodle/public --webserver-type=apache-fpm --project-name=${PROJECT_NAME} \
    --database="${database}" --nodejs-version=$(ddev_nodejs_version) --php-version="${php_version}" --auto || exit 1 ;
  mkdir -p .ddev/php ;
  printf 'max_input_vars = 5000\n' > .ddev/php/moodle.ini ;
  moodle_write_cron ;
  ddev_up start -y || exit 1 ;

  # The release package of the line, unpacked in the web container, and the data folder beside it.
  ddev exec "rm -rf /var/www/html/moodle /tmp/moodle && curl -fsSL '${package_url}' -o /tmp/moodle.tgz && tar -xzf /tmp/moodle.tgz -C /tmp && rm /tmp/moodle.tgz && mv /tmp/moodle /var/www/html/moodle && mkdir -p /var/www/html/moodledata" < /dev/null \
    || { echo "The release package ${package_url} could not be fetched." ; exit 1 ; } ;
  if [ ! -f moodle/public/version.php ] ; then
    # A release before 5.1 has no public/ folder: it is served from moodle/.
    ddev config --docroot=moodle --auto || exit 1 ;
    ddev restart -y || exit 1 ;
  fi

  if [ "${INSTALL}" == 'yes' ] ; then
    # The release's own installer: moodle/config.php, the database, and the workspace account as the administrator.
    ddev exec php /var/www/html/moodle/admin/cli/install.php --non-interactive --agree-license --lang=en \
      --wwwroot="${base_url}" --dataroot=/var/www/html/moodledata \
      --dbtype=mariadb --dbhost=db --dbname=db --dbuser=db --dbpass=db --prefix=mdl_ \
      --fullname="${doc_name} ${PROJECT_NAME}" --shortname="${PROJECT_NAME}" \
      --adminuser="${account_name}" --adminpass="${account_pass}" --adminemail="${account_mail}" \
      --supportemail=support@example.com --noreplyemail=noreply@example.com < /dev/null \
      || { echo "The installer failed." ; exit 1 ; } ;
    if [ "${TEST_COURSE}" == 'yes' ] ; then
      moodle_test_site --settings --course || { echo "The test course could not be written." ; exit 1 ; } ;
    fi
    if [ "${ADD_USERS}" == 'yes' ] ; then
      set_moodle_users ;
      add_moodle_users ;
      cd ${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME} || exit 1 ;
    fi
    # The first cron run, so that the scheduled tasks of a new site have run once.
    ddev exec php /var/www/html/moodle/admin/cli/cron.php < /dev/null > /dev/null 2>&1 ;
  elif [ "${ADD_USERS}" == 'yes' ] || [ "${TEST_COURSE}" == 'yes' ] ; then
    echo "--add-users and --test-course need --install: there is no site to add them to yet." ;
  fi

  local release ;
  release="$(ddev exec php /var/www/html/moodle/admin/cli/cfg.php --name=release < /dev/null 2>/dev/null)" ;
  if [ "${INSTALL}" == 'yes' ] ; then
    echo "${doc_name} ${PROJECT_NAME} has been installed: Moodle ${release}.";
    echo "Go to ${base_url}/login/index.php and log in as ${account_name}";
  else
    echo "${doc_name} ${PROJECT_NAME} is ready: the release package of Moodle ${line} in moodle/. Install it with its installer: bash cmd-tools-moodle-cli.sh ${PROJECT_NAME} --run \"install --help\"";
    echo "Go to ${base_url}";
  fi

  if [ "${LAUNCH}" == 'yes' ] ; then
    ddev launch /login/index.php ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name};
}

# Create the default accounts through the site. An account that is already there gets its name, address,
# password and roles back. The list is loaded by the caller (set_moodle_users): the core's add_users, the
# builder, the CLI tool.
function add_moodle_users() {
  moodle_enter_project || return 1 ;
  local user lines="" n m p f l r ;
  for user in "${users[@]}" ; do
    n="user_${user}_name"; m="user_${user}_mail"; p="user_${user}_password";
    f="user_${user}_firstname"; l="user_${user}_lastname"; r="user_${user}_role";

    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!n}";
    echo "      User mail: ${!m}";
    echo "  User password: ${!p}";
    echo "      Full name: ${!f:-${!n}} ${!l:-User}";
    echo "      User role: ${!r:-(in no course)}";
    echo " ================================================================= ";

    lines="${lines}${!n}|${!m}|${!p}|${!f:-${!n}}|${!l:-User}|${!r:-}"$'\n' ;
  done
  printf '%s' "${lines}" | moodle_write_accounts save ;
  local rc=$? ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${rc} ;
}

# Delete the default accounts.
function cancel_moodle_users() {
  moodle_enter_project || return 1 ;
  local user lines="" n m ;
  for user in "${users[@]}" ; do
    n="user_${user}_name"; m="user_${user}_mail";
    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!n}";
    echo " ================================================================= ";
    lines="${lines}${!n}|${!m}|||||"$'\n' ;
  done
  printf '%s' "${lines}" | moodle_write_accounts delete ;
  local rc=$? ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${rc} ;
}

# What cmd-tools-moodle-cli.sh does: the first of --run, --cron, --purge-caches, --upgrade, --test-course,
# --add-users, --cancel-users that was asked for; with none of them, what the site is.
function moodle_cli_tool() {
  trim_project_name ;
  moodle_enter_project || exit 1 ;

  if ! ddev describe -j 2>/dev/null | grep -q '"status":"running"' ; then
    ddev start -y || exit 1 ;
  fi

  if [ ! "${RUN}" == '_none_' ] ; then
    # --run "<script> <arguments>": admin/cli/<script>.php with its arguments. Unquoted on purpose.
    local script="${RUN%% *}" rest="" ;
    [ "${RUN}" != "${script}" ] && rest="${RUN#* }" ;
    script="${script%.php}" ;
    if [ ! -f "moodle/admin/cli/${script}.php" ] ; then
      echo "moodle/admin/cli/${script}.php does not exist. The scripts: $(ls moodle/admin/cli | sed 's/\.php$//' | tr '\n' ' ')" ;
      exit 1 ;
    fi
    ddev exec php /var/www/html/moodle/admin/cli/${script}.php ${rest} < /dev/null ;
    exit $? ;
  fi

  if [ "${CRON}" == 'yes' ] ; then
    ddev exec php /var/www/html/moodle/admin/cli/cron.php < /dev/null ;
  elif [ "${PURGE_CACHES}" == 'yes' ] ; then
    ddev exec php /var/www/html/moodle/admin/cli/purge_caches.php < /dev/null ;
  elif [ "${UPGRADE}" == 'yes' ] ; then
    ddev exec php /var/www/html/moodle/admin/cli/upgrade.php --non-interactive < /dev/null ;
  elif [ "${TEST_COURSE}" == 'yes' ] ; then
    moodle_test_site --settings --course ;
    set_moodle_users ;
    add_moodle_users ;
  elif [ "${ADD_USERS}" == 'yes' ] ; then
    set_moodle_users ;
    add_moodle_users ;
  elif [ "${CANCEL_USERS}" == 'yes' ] ; then
    set_moodle_users ;
    cancel_moodle_users ;
  else
    echo "${doc_name}/${PROJECT_NAME}: Moodle $(ddev exec php /var/www/html/moodle/admin/cli/cfg.php --name=release < /dev/null 2>/dev/null) at https://${PROJECT_NAME}.ddev.site" ;
    echo "  Cron: $(ddev exec 'tail -n 1 /tmp/cron.log' < /dev/null 2>/dev/null || echo 'not run yet')" ;
    echo "" ; echo "Accounts:" ;
    moodle_test_site --list-accounts ;
  fi
  cd ${WORKSPACE_ROOT}/${doc_name};
}

# The step pack in the testing stack of a Moodle project. The core's testing_configure calls this in the
# project folder once webship-js is scaffolded and before the dependencies are installed; for a project
# that is not Moodle it changes nothing.
#
# It adds the pack to package.json, lists its step definitions in cucumber.js after webship-js's own,
# gives cucumber.js the users registry of the default accounts (a handle a scenario reads, mapped to an
# account, with its full name; never the workspace account) and the tags that keep the pack's
# assertions that must fail out of a normal run, and writes a first feature when the project has none of
# its own. Every part is skipped when it is already there, so a second run adds what the first missed
# and never resets a suite.
function testing_configure_moodle() {
  local project_path="$1";
  moodle_is_project "${project_path}" || return 0 ;
  if [ ! -f "${project_path}/cucumber.js" ] || [ ! -f "${project_path}/package.json" ] ; then
    echo "  Moodle: cucumber.js is not here yet — run the testing setup again once webship-js is scaffolded." ;
    return 1 ;
  fi

  echo "Adding the Moodle step pack (${MOODLE_STEPS_PACKAGE} ${MOODLE_STEPS_VERSION}).";
  set_moodle_users ;
  local registry="" user n m p f l ;
  for user in "${users[@]}" ; do
    n="user_${user}_name"; m="user_${user}_mail"; p="user_${user}_password"; f="user_${user}_firstname"; l="user_${user}_lastname";
    registry="${registry}${user}|${!n}|${!m}|${!p}|${!f} ${!l}"$'\n' ;
  done

  python3 - "${project_path}" "${MOODLE_STEPS_PACKAGE}" "${MOODLE_STEPS_VERSION}" 'MOODLE' "${registry}" <<'PYEOF' || return 1
import json, re, sys

project, pack, version, prefix, registry = sys.argv[1:6]

# package.json: the pack as a dev dependency, at the release line this plugin was proven on.
pkg_file = project + '/package.json'
pkg = json.load(open(pkg_file))
if pack not in pkg.get('dependencies', {}) and pack not in pkg.get('devDependencies', {}):
    pkg.setdefault('devDependencies', {})[pack] = version
    open(pkg_file, 'w').write(json.dumps(pkg, indent=4) + '\n')
    print('  package.json: %s %s' % (pack, version))

# cucumber.js: the pack's step definitions after webship-js's own, the users registry and the tags.
cucumber_file = project + '/cucumber.js'
src = open(cucumber_file).read()
before = src

if ('node_modules/%s/' % pack) not in src:
    line = "'node_modules/%s/tests/step-definitions/**/*.js'," % pack
    core = re.search(r"^([ \t]*)'node_modules/webship-js/tests/step-definitions/[^']*',.*$", src, re.M)
    opening = re.search(r"^([ \t]*)require:[ \t]*\[[ \t]*$", src, re.M)
    if core:
        src = src[:core.end()] + '\n' + core.group(1) + line + src[core.end():]
    elif opening:
        src = src[:opening.end()] + '\n' + opening.group(1) + '  ' + line + src[opening.end():]
    else:
        sys.exit("  cucumber.js has no require list this can add to. Add this line to it:\n    " + line)
    print('  cucumber.js: the step definitions of %s' % pack)

if not re.search(r"^[ \t]*tags:", src, re.M):
    default = re.search(r"^([ \t]*)default:[ \t]*\{[ \t]*$", src, re.M)
    if default:
        pad = default.group(1) + '  '
        block = [
            pad + "// The pack's assertions that must fail are no part of a normal run.",
            pad + "tags: process.env.CUCUMBER_TAGS || 'not @wip and not @must-fail',",
        ]
        src = src[:default.end()] + '\n' + '\n'.join(block) + src[default.end():]
        print('  cucumber.js: the tags that keep the assertions that must fail out of a normal run')

world = re.search(r"^([ \t]*)worldParameters:[ \t]*\{[ \t]*$", src, re.M)
if not world:
    sys.exit("  cucumber.js has no worldParameters block to add the users registry to.")
pad = world.group(1) + '  '
additions = []
if not re.search(r"^[ \t]*users:[ \t]*\{", src, re.M):
    rows = [r.split('|') for r in registry.splitlines() if r.strip()]
    additions += [
        pad + "// The users registry: a handle a scenario reads, mapped to an account of this site (the default",
        pad + "// accounts: cmd-tools-moodle-cli.sh --add-users), with the full name the site shows. Override one",
        pad + "// with %s_<HANDLE>_USERNAME, %s_<HANDLE>_PASSWORD, %s_<HANDLE>_EMAIL and %s_<HANDLE>_NAME." % (prefix, prefix, prefix, prefix),
        pad + "users: {",
    ]
    for handle, name, email, password, full in rows:
        env = '%s_%s' % (prefix, handle.upper())
        additions.append(pad + "  %s: { username: process.env.%s_USERNAME || '%s', password: process.env.%s_PASSWORD || '%s', email: process.env.%s_EMAIL || '%s', name: process.env.%s_NAME || '%s' }," % (handle, env, name, env, password, env, email, env, full))
    additions.append(pad + "},")
    print('  cucumber.js: the users registry (%s)' % ', '.join(r[0] for r in rows))
if additions:
    src = src[:world.end()] + '\n' + '\n'.join(additions) + src[world.end():]

if src != before:
    open(cucumber_file, 'w').write(src)
PYEOF

  # A first feature, when the project has none for the site yet: the login page, each default account in
  # its role, the test course.
  local feature="${WORKSPACE_SCRIPTS}/plugins/moodle/site.feature" ;
  if [ -f "${feature}" ] && [ ! -f "${project_path}/tests/features/site.feature" ] ; then
    mkdir -p "${project_path}/tests/features" && cp "${feature}" "${project_path}/tests/features/site.feature" \
      && echo "  tests/features/site.feature: a first feature for the site" ;
  fi

  # The scenarios log in as the default accounts: make sure an installed site has them.
  if ( cd "${project_path}" && moodle_is_installed ) ; then
    if ( add_moodle_users > /dev/null 2>&1 ) ; then
      echo "  the default accounts are on the site (${users[*]})" ;
    else
      echo "  The default accounts could not be written: bash cmd-tools-moodle-cli.sh ${PROJECT_NAME} --add-users says why." ;
    fi
  else
    echo "  The site is not installed: the scenarios that log in need a site built with --install." ;
  fi
}
