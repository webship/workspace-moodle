# @webship.co/workspace-moodle

Moodle for the [Webship Workspace](https://github.com/webship/workspace) dashboard: a builder that
makes a real Moodle learning site in a container from the release package, installed by its own
command-line installer, with the test course of the step pack on request; a CLI tool that runs the
site's command-line scripts; the default accounts; the
[Moodle step pack](https://github.com/webship/moodle-steps) wired into the workspace's testing setup;
and its AI items — two agents, a skill, a command and two prompts — each listed in the workspace
folder of its kind.

The workspace is container-based (DDEV by default): a Moodle project is a row like any other, so the
row menus the core draws (start, stop, launch, backup, clone, remove, tests) work on it unchanged.

It is made from the reference platform plugin, `@webship.co/workspace-wordpress`.

## Use it

```bash
cd ~/workspace
bash core/scripts/plugins.sh --require @webship.co/workspace-moodle --with-needs   # npm install into the dashboard
bash core/scripts/plugins.sh --activate moodle --with-needs                         # plugins.moodle in settings.yml
bash core/scripts/plugins.sh --install moodle                                       # commands, functions, args, AI items
bash core/scripts/plugins.sh --configure moodle                                     # nothing to configure: it has no settings file
```

The same four steps are buttons on the dashboard's **Settings → Plugins** page. `--install` is
idempotent. `--uninstall` removes what it placed; an AI item you edited stays.

Everything the plugin carries lands in the folder it belongs to, when that folder is an active
workspace folder:

| What | Lands in |
| --- | --- |
| `cmd-moodle-project.sh`, `cmd-tools-moodle-cli.sh` | every active sites folder: `dev/`, `test/`, `sandboxes/`, `demos/` |
| The agents `moodle-site-builder`, `moodle-tester` | `ai-agents/` |
| The skill `moodle-scenarios` | `ai-skills/` |
| The command `/moodle-test` | `ai-commands/` |
| The prompts `moodle-build-and-test`, `moodle-scenarios-for-a-role` | `ai-prompts/` |

There they are listed like any other item of the folder, and installed into Claude Code from there.

## What it needs

A workspace starts empty, so the manifest says what else this plugin needs (`needs`):

- one sites folder, for the builder and the tool: `dev`, `test`, `sandboxes`, `demos` (`dev` is the one added when none is there). The folder also carries `cmd-tools-testing.sh` and the Users tools this plugin's hooks answer to.
- `ai-agents`, `ai-skills`, `ai-commands` and `ai-prompts`: the AI folders its agents, its skill, its command and its prompts are placed in.

`--require` says so, `--activate` and `--install` stop until the workspace has them, and `--with-needs` adds what is missing first:

```bash
bash core/scripts/plugins.sh --activate moodle --with-needs   # dev and the four AI folders are required, activated and installed first
bash core/scripts/plugins.sh --install moodle
```

Everything the builder runs for a site runs in the site's own container, through the container tool the workspace already needs: the release package is fetched and unpacked there, and its PHP runs there. The plugin asks for no command of its own on the machine.

## What the package holds

| Path | What it is |
| --- | --- |
| `commands/cmd-moodle-project.sh` | The builder, in the Build list as **Moodle (learning site)**, installed into every sites folder |
| `commands/cmd-tools-moodle-cli.sh` | The site's command-line scripts for one site: what the site is, a script, cron, the caches, an upgrade, the test course, the default accounts |
| `scripts/functions/fun-moodle.sh` | The bash functions behind both, sourced by bootstrap once installed; the names the core's tools look for (`set_moodle_users`, `add_moodle_users`, `cancel_moodle_users`, `testing_configure_moodle`) |
| `scripts/args/arg-moodle.sh`, `arg-moodle-cli.sh` | Their argparse; the Build form draws the builder's flags from the first |
| `scripts/php/test-site.php` | The test site, written through the site's own API by its own PHP in the container: the settings the step pack relies on, the test course, the accounts (the same as the step pack's build) |
| `testing/site.feature` | The first feature a Moodle project gets when testing is set up |
| `ai/agents/moodle-site-builder.md` | The agent that builds and maintains Moodle sites with these commands |
| `ai/agents/moodle-tester.md` | The agent that writes and runs scenarios with the Moodle step pack |
| `ai/skills/moodle-scenarios/` | The skill: the step pack's phrases by area, the traps found on a real site, three example features |
| `ai/commands/moodle-test.md` | The slash command `/moodle-test <site>`: set up, match every step, run, report |
| `ai/prompts/moodle-build-and-test.md`, `moodle-scenarios-for-a-role.md` | Two prompts: whole launch commands for a new session |
| `src/index.ts` | `register(api)`: what the assistant is told about Moodle here |
| `features/moodle.feature` | Scenarios for the dashboard's own browser suite |
| `features/moodle-runtimes.feature` | The row, the test users and two pages of a site built on Docker Compose and on Kubernetes |

The `workspacePlugin` block in `package.json` is the manifest the installer reads.

## What is different from a platform with a project type

DDEV has no project type for Moodle. The plugin keeps the shape of the reference and changes
only this:

| | WordPress (the reference) | Moodle |
| --- | --- | --- |
| Project | `--project-type=wordpress` | `--project-type=php --webserver-type=apache-fpm --docroot=moodle/public` (`moodle` for a release before 5.1), `--database=mariadb:11.4` (5.3 needs 11.4 or later), `max_input_vars = 5000` |
| Layout | The site at the project root | The release package in `moodle/`, its data folder `moodledata/` beside it (outside the web root), the testing stack at the top: the package's own `package.json` is its development tooling and stays apart |
| Recognised by | The DDEV project type | Its files: `moodle/public/version.php` (or `moodle/version.php`); on another runtime than DDEV also the plugin's claim, `platform: moodle` in the `x-webship` block |
| Getting the code | `wp core download` | The release package of the line (`--moodle-version`, 5.3 by default) from the project's download site, unpacked in the web container |
| Install | `wp core install` | `admin/cli/install.php --non-interactive`, with the container's own database settings and the workspace account as the administrator |
| Cron | WordPress's own | `admin/cli/cron.php` again and again, run by the web container's process supervisor (`web_extra_daemons`); on another runtime kept running beside the web server by the core's layer (`rt_daemon`) |
| Accounts | WP-CLI | `scripts/php/test-site.php`, run by the site's PHP for the time of the call |
| Users menu of the row | Reads the project type | Reads the plugin's claim (the type is `php`): `.ddev/config.moodle.yaml` on DDEV, `platform: moodle` in the `x-webship` block on another runtime |

## The commands

Run them from a sites folder. `--help` is safe on both.

### Build a site

```bash
cd ~/workspace/dev
bash cmd-moodle-project.sh mysite --install --add-users --test-course
```

| Flag | What it does |
| --- | --- |
| `--install` | Install the site with its own command-line installer; the workspace account is its administrator |
| `--test-course` | With `--install`: the test course of the step pack ("Software Testing 101": a page, an assignment, a quiz with three questions, a forum, self enrolment with the key `TEST101-key`), the guest login button shown, the user tours off |
| `--add-users` | With `--install`: add the default accounts |
| `--moodle-version <x>` | The release line: 5.3 (the default, the current release and a long-term support line), 5.2, 5.1, 5.0 or 4.5 (the long-term support line before it) |
| `--php-version <x>` | The PHP of the project container: 8.3 (the default) or 8.4 |
| `--runtime <name>` | The container runtime to build on: `ddev` (the default), `docker`, `kubernetes`, `podman`, `lando` or `docksal`. See [Runtimes](#runtimes) |
| `--launch` | Open the login page when the site is ready |

On DDEV the site answers at `https://mysite.ddev.site`, its login at `/login/index.php`. The build runs
`ddev config --project-type=php` with Apache, MariaDB 11.4 and the Node.js of the workspace (24),
fetches the release package of the line in the web container and unpacks it in `moodle/`, keeps the
data folder `moodledata/` beside it, starts cron, and with `--install` runs the installer. A project of
the same name is deleted first. A new site of the 5.x line asks every visitor to log in, and turns My
courses off (the Dashboard carries the course overview): both are the release's own defaults.


### Runtimes

```bash
bash cmd-moodle-project.sh mysite --install --add-users --test-course                        # DDEV, the default
bash cmd-moodle-project.sh mysite --install --add-users --test-course --runtime docker       # Docker Compose
bash cmd-moodle-project.sh mysite --install --add-users --test-course --runtime kubernetes   # a Kubernetes cluster
bash cmd-moodle-project.sh mysite --install --add-users --test-course --runtime lando        # Lando
bash cmd-moodle-project.sh mysite --install --add-users --test-course --runtime docksal      # Docksal
```

Without `--runtime` a build takes `container.runtime` of the workspace's `settings.yml`, then DDEV.
It needs a Webship Workspace with the container runtimes
([webship/workspace#694](https://github.com/webship/workspace/issues/694)); on an older one the
builder refuses `--runtime` and builds on DDEV only. Lando and Docksal need a Workspace whose runtime
layer has them ([webship/workspace#729](https://github.com/webship/workspace/issues/729),
[#730](https://github.com/webship/workspace/issues/730)). Moodle also needs a layer that takes a
project's PHP settings and its cron ([#825](https://github.com/webship/workspace/issues/825), and
[#836](https://github.com/webship/workspace/issues/836) on Lando and Docksal), and gives MariaDB 11.4 the
collation Moodle's installer takes ([#827](https://github.com/webship/workspace/issues/827)); without
the first the builder says so and builds on DDEV only.

| | DDEV | Docker Compose | Kubernetes | Podman | Lando | Docksal |
| --- | --- | --- | --- | --- | --- | --- |
| Build with `--install --add-users --test-course` (MariaDB 11.4) | Yes | Yes | Yes | Not yet run | Yes | Yes |
| The pages, and a login as the workspace account, a teacher and a student (refused the administration) | Yes | Yes | Yes | Not yet run | Yes | Yes |
| `cmd-tools-moodle-cli.sh`: the release, cron's last line and the accounts, `--run`, `--purge-caches` | Yes | Yes | Yes | Not yet run | Yes | Yes |
| Cron, kept running beside the web server | Yes | Yes | Yes | Not yet run | Yes | Yes |
| Test users, cancelled and added | Yes | Yes | Yes | Not yet run | Yes | Yes |
| Mail caught by Mailpit (the site's own notices, sent by its cron) | Yes | Yes | Yes | Not yet run | Yes | Yes |
| The testing setup and the first feature | Yes | Yes | Yes | Not yet run | Yes | Yes |
| The step pack's examples | Yes | Yes | Yes | Not yet run | Yes | Yes |
| Export and import the database | Yes | Yes | Yes | Not yet run | Yes | Yes |
| The row in the dashboard, and remove | Yes | Yes | Yes | Not yet run | Yes | Yes |

"Yes" means it was run on a real site of that runtime. Podman runs the same code as Docker Compose
and was not run yet.

| Runtime | The site's address | What the project carries |
| --- | --- | --- |
| DDEV | `https://mysite.ddev.site` | `.ddev/config.yaml`, and the plugin's claim `.ddev/config.moodle.yaml` |
| Docker Compose | `http://127.0.0.1:<port>`, printed by the build | `compose.yaml`, `.webship/runtime/Dockerfile` |
| Kubernetes | `http://<node address>:<port>`, printed by the build | The same, and `k8s/` (the namespace `ws-mysite`) |
| Lando | `http://127.0.0.1:<port>`, printed by the build | `.lando.yml` (Lando's proxy stays off) |
| Docksal | `http://mysite.docksal.site`, on Docksal's own proxy | `.docksal/docksal.env`, `.docksal/docksal.yml` |

What differs on Docker Compose, Kubernetes, Lando and Docksal:

- **The claim:** the type `php` names no platform, so the build claims the project for the plugin (`platform: moodle` in the `x-webship` block, the core's `rt_claim`): the console tool, the test users, the testing setup and the row's Tests menu know the site by it.
- **`max_input_vars = 5000` and cron** through the core's layer (webship/workspace#825): the setting in `.webship/php/moodle.ini` (`rt_php_ini`), which the web server and the command line read; cron, DDEV's own loop from the project's folder, kept running beside the web server (`rt_daemon`), its log in `.webship/moodle-cron.log`, which the console tool reads.
- **Where the project is in its container** (`/var/www/html`, `/app` on Lando, `/var/www` on Docksal) is asked of the container, for the package, the data folder, the installer and the test-site script.
- **MariaDB 11.4** with the collation DDEV gives it (webship/workspace#827), which Moodle's installer takes.
- **HTTPS and a host name** are DDEV's: a runtime's address is plain HTTP.

The same commands work on every runtime: `cmd-tools-moodle-cli.sh`, `cmd-tools-add-users.sh`,
`cmd-tools-testing.sh`. The pattern is the Workspace's
[`core/docs/plugins-on-runtimes.md`](https://github.com/webship/workspace/blob/1.0.x/core/docs/plugins-on-runtimes.md).

### Work on a site

```bash
bash cmd-tools-moodle-cli.sh mysite                                  # release, address, cron, accounts
bash cmd-tools-moodle-cli.sh mysite --run "cfg --name=release"       # moodle/admin/cli/<script>.php with its arguments
bash cmd-tools-moodle-cli.sh mysite --cron                           # cron once, now
bash cmd-tools-moodle-cli.sh mysite --purge-caches
bash cmd-tools-moodle-cli.sh mysite --upgrade                        # after the code changed
bash cmd-tools-moodle-cli.sh mysite --test-course                    # the test course again, from nothing
bash cmd-tools-moodle-cli.sh mysite --add-users                      # the default accounts
bash cmd-tools-moodle-cli.sh mysite --cancel-users                   # delete them
```

### The default accounts

| Account | Address | Full name | Role | Handle in the tests |
| --- | --- | --- | --- | --- |
| `administrator` | `administrator@example.com` | Administrator User | a site administrator | `administrator` |
| `manager` | `manager@example.com` | Manager User | the Manager role on the whole site | `manager` |
| `teacher` | `teacher@example.com` | Teacher User | Teacher (editing) in the test course | `teacher` |
| `student` | `student@example.com` | Student User | Student in the test course | `student` |
| `student2` | `student2@example.com` | Student2 User | in no course (it enrols itself with the key) | `student2` |

One account per role the step pack's features use. Each account has the password of the workspace's
other default lists. They are for local sites and for tests; the site's administrator from the build
is the workspace account and is never written into a test. The course roles need the test course
(`--test-course`). `bash cmd-tools-moodle-cli.sh mysite --add-users` and `bash cmd-tools-add-users.sh
mysite moodle` add the same list; adding them again gives them back their name, address, password and
roles. The dashboard's Users menu of a project row picks its actions by the container project type,
which says `php` for a Moodle site: manage the accounts with `cmd-tools-moodle-cli.sh` (`--add-users`,
`--cancel-users`, `--run "reset_password"`) instead.

### Test a site

```bash
bash cmd-tools-testing.sh mysite                 # webship-js, the step pack, the users registry, a first feature
bash cmd-tools-testing.sh mysite --run           # run the suite in the container
bash cmd-tools-testing.sh mysite --run --path tests/features/site.feature
```

`cmd-tools-testing.sh` is the workspace's own. For a Moodle project it also adds
`@webship-js/moodle-steps` to `package.json`, lists its step definitions in `cucumber.js` after
webship-js's own, writes the users registry (the handles above, with the full names, overridable with
`MOODLE_<HANDLE>_USERNAME`, `MOODLE_<HANDLE>_PASSWORD`, `MOODLE_<HANDLE>_EMAIL` and
`MOODLE_<HANDLE>_NAME`) and the tags that keep the pack's assertions that must fail out of a normal
run, places `tests/features/site.feature` when the project has none, and makes sure the default
accounts are on the site. The testing stack lives at the top of the project, beside `moodle/`. Run it
again and it adds what is missing and keeps what you changed.

`tests/features/site.feature` passes on a site built with `--install --add-users --test-course`, on
5.3 and on 4.5. The features of the step pack run on a 5.3 site built that way as they are: the test
course and the accounts are the same as the pack's own build. The pack is made for the 5.x line; on
4.5 some pages and messages differ (the refusal of a wrong password, the page after logging out).

## The AI items

| Item | Kind | What it does |
| --- | --- | --- |
| `moodle-site-builder` | agent | Builds, maintains and removes Moodle sites with the builder, the CLI tool and the workspace's own tools; containers only |
| `moodle-tester` | agent | Writes and runs scenarios with the step pack: the Playwright MCP browser first, then the scenario; never an account created by a suite, never a platform name in a step phrase |
| `moodle-scenarios` | skill | The step pack's phrases by area, the traps found on a real site, three example features that pass on a site with the test course |
| `/moodle-test <site>` | command | Set the testing stack up when missing, match every step, run the suite (or a feature, or a tag), report |
| `moodle-build-and-test` | prompt | A new session that builds a site with the test course and runs its first feature |
| `moodle-scenarios-for-a-role` | prompt | A new session that writes and runs the scenarios of what one role may do |

Every phrase an item shows is a phrase of the step pack or of webship-js
(`tests/fixtures/step-definitions.txt`, read from the pack at the version the builder pins), and every
command and flag it names exists: the tests check both.

## Develop it

```bash
npm install
npm run lint && npm test         # the manifest, the commands, the functions, the items
git ls-files -z '*.sh' | xargs -0 -n1 bash -n
```

Prove it in a throwaway workspace before a release: `webship-workspace init`, then require the plugin
from its packed tarball, activate and install it with `--with-needs`; check that Settings lists it, the
Build list of `dev` offers the builder, and each AI folder lists its items; build one real site with
`--install --add-users --test-course`, run `cmd-tools-testing.sh <name>` and its first feature; then
uninstall and check that nothing is left behind.
