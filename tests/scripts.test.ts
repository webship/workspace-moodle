import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { spawnSync } from 'child_process';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const FUNCTIONS = path.join(PKG, 'scripts', 'functions', 'fun-moodle.sh');

// The cucumber.js webship-js scaffolds, as far as the testing hook reads it.
const SCAFFOLD = `module.exports = {
  default: {
    requireModule: ['tsx/cjs'],
    require: [
      'node_modules/webship-js/tests/step-definitions/**/*.js',          // Webship-js core step definitions.
      'tests/step-definitions/**/*.js',                                  // Your custom step definitions.
    ],
    paths: ['tests/features/**/*.feature'],
    worldParameters: {
      launchUrl: process.env.LAUNCH_URL || 'http://localhost:8080',
    },
  },
};
`;

/**
 * A project folder with the testing stack scaffolded, and the tooling folder the installer would have filled.
 * A Moodle site has the release package in moodle/ (public/ from 5.1 on); `installed` adds its config.php.
 */
function project(kind: 'moodle' | 'drupal', { installed = true, publicFolder = true } = {}) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'moodle-plugin-'));
  const dir = path.join(root, 'dev', 'site1');
  fs.mkdirSync(path.join(dir, '.ddev'), { recursive: true });
  fs.writeFileSync(path.join(dir, '.ddev', 'config.yaml'), `name: site1\ntype: ${kind === 'moodle' ? 'php' : 'drupal11'}\ndocroot: ${kind === 'moodle' ? 'moodle/public' : 'web'}\n`);
  if (kind === 'moodle') {
    const code = publicFolder ? path.join(dir, 'moodle', 'public') : path.join(dir, 'moodle');
    fs.mkdirSync(code, { recursive: true });
    fs.writeFileSync(path.join(code, 'version.php'), "<?php\ndefined('MOODLE_INTERNAL') || die();\n$version = 2026100501.01;\n$release = '5.3.1+ (Build: 20261117)';\n");
    if (installed) fs.writeFileSync(path.join(dir, 'moodle', 'config.php'), '<?php\n');
  }
  fs.writeFileSync(path.join(dir, 'cucumber.js'), SCAFFOLD);
  fs.writeFileSync(path.join(dir, 'package.json'), JSON.stringify({ name: 'site1', devDependencies: { 'webship-js': '^2.0.16' } }, null, 2));
  const scripts = path.join(root, 'core', 'scripts');
  fs.mkdirSync(path.join(scripts, 'plugins', 'moodle'), { recursive: true });
  fs.copyFileSync(path.join(PKG, 'testing', 'site.feature'), path.join(scripts, 'plugins', 'moodle', 'site.feature'));
  fs.copyFileSync(path.join(PKG, 'scripts', 'php', 'test-site.php'), path.join(scripts, 'plugins', 'moodle', 'test-site.php'));
  return { root, dir, scripts };
}

/** Run bash with the plugin's functions sourced and `ddev` replaced by a recorder that also logs the account list a call reads. */
function bash(script: string, env: Record<string, string> = {}) {
  const fake = 'ddev() { echo "ddev $*" >> "${DDEV_LOG:-/dev/null}" ; if [ "$1" == "exec" ] && [ -f .webship-test-accounts.json ] ; then cat .webship-test-accounts.json >> "${DDEV_LOG:-/dev/null}" ; echo >> "${DDEV_LOG:-/dev/null}" ; fi ; return 0 ; }';
  return spawnSync('bash', ['-c', `${fake}\nMOODLE_TEST_SITE_PHP="\${WORKSPACE_SCRIPTS}/plugins/moodle/test-site.php"\nsource ${FUNCTIONS}\nMOODLE_TEST_SITE_PHP="\${WORKSPACE_SCRIPTS}/plugins/moodle/test-site.php"\n${script}`],
    { encoding: 'utf8', env: { ...process.env, ...env } });
}

test('the default accounts are one per role the step pack uses, with example addresses and full names', () => {
  const r = bash('set_moodle_users ; for u in "${users[@]}" ; do n="user_${u}_name" ; m="user_${u}_mail" ; p="user_${u}_password" ; f="user_${u}_firstname" ; l="user_${u}_lastname" ; g="user_${u}_role" ; echo "${!n}|${!m}|${!p}|${!f} ${!l}|${!g}" ; done');
  assert.strictEqual(r.status, 0, r.stderr);
  const rows = r.stdout.trim().split('\n').map((l) => l.split('|'));
  assert.deepStrictEqual(rows.map((x) => x[0]), ['administrator', 'manager', 'teacher', 'student', 'student2']);
  assert.deepStrictEqual(rows.map((x) => x[3]), ['Administrator User', 'Manager User', 'Teacher User', 'Student User', 'Student2 User']);
  assert.deepStrictEqual(rows.map((x) => x[4]), ['siteadmin', 'manager', 'editingteacher', 'student', '']);
  for (const [name, mail, password] of rows) {
    assert.strictEqual(mail, `${name}@example.com`);
    assert.match(password, /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$/, 'it passes the password policy of a new site');
  }
});

test('the accounts are written through the site by its own PHP, with their roles, and removed through it', () => {
  const p = project('moodle');
  const log = path.join(p.root, 'ddev.log');
  const env = { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log };
  let r = bash('set_moodle_users ; add_moodle_users', env);
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  let written = fs.readFileSync(log, 'utf8');
  assert.match(written, /^ddev exec php \/var\/www\/html\/\.webship-test-site\.php --config=\/var\/www\/html\/moodle\/config\.php --accounts=\/var\/www\/html\/\.webship-test-accounts\.json$/m);
  const accounts = JSON.parse(written.split('\n').find((l) => l.startsWith('[')) as string);
  assert.deepStrictEqual(accounts.map((a: any) => [a.username, a.email, `${a.firstname} ${a.lastname}`, a.siteadmin || a.systemrole || a.courserole || '']), [
    ['administrator', 'administrator@example.com', 'Administrator User', true],
    ['manager', 'manager@example.com', 'Manager User', 'manager'],
    ['teacher', 'teacher@example.com', 'Teacher User', 'editingteacher'],
    ['student', 'student@example.com', 'Student User', 'student'],
    ['student2', 'student2@example.com', 'Student2 User', ''],
  ]);
  assert.ok(!fs.existsSync(path.join(p.dir, '.webship-test-site.php')), 'the script of the call is gone');
  assert.ok(!fs.existsSync(path.join(p.dir, '.webship-test-accounts.json')), 'and its list too');
  fs.writeFileSync(log, '');
  r = bash('set_moodle_users ; cancel_moodle_users', env);
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  written = fs.readFileSync(log, 'utf8');
  assert.match(written, /--delete-accounts=\/var\/www\/html\/\.webship-test-accounts\.json$/m);
  const removal = JSON.parse(written.split('\n').find((l) => l.startsWith('[')) as string);
  assert.deepStrictEqual(removal.map((a: any) => a.username), ['administrator', 'manager', 'teacher', 'student', 'student2']);
});

test('a site that is not installed has no accounts to write, and says so', () => {
  const p = project('moodle', { installed: false });
  const r = bash('set_moodle_users ; add_moodle_users', { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1' });
  assert.notStrictEqual(r.status, 0);
  assert.match(r.stdout, /not installed/);
});

test('a site of a release before 5.1 (no public/ folder) is a Moodle project too', () => {
  const p = project('moodle', { publicFolder: false });
  const r = bash(`moodle_is_project ${p.dir} && echo yes`, {});
  assert.strictEqual(r.stdout.trim(), 'yes');
});

test('the testing hook adds the step pack, the users registry, the tags and a first feature to a Moodle project, once', () => {
  const p = project('moodle');
  const log = path.join(p.root, 'ddev.log');
  const run = () => bash(`cd ${p.dir} && testing_configure_moodle ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log });
  const r = run();
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const pkg = JSON.parse(fs.readFileSync(path.join(p.dir, 'package.json'), 'utf8'));
  assert.strictEqual(pkg.devDependencies['@webship-js/moodle-steps'], '^2.0.0');
  assert.strictEqual(pkg.devDependencies['webship-js'], '^2.0.16', 'what was there stays');
  const cucumber = fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8');
  const lines = cucumber.split('\n');
  const core = lines.findIndex((l) => l.includes('node_modules/webship-js/tests/step-definitions'));
  assert.strictEqual(lines[core + 1], "      'node_modules/@webship-js/moodle-steps/tests/step-definitions/**/*.js',", 'the pack is listed right after webship-js');
  assert.match(cucumber, /administrator: \{ username: process\.env\.MOODLE_ADMINISTRATOR_USERNAME \|\| 'administrator', password: process\.env\.MOODLE_ADMINISTRATOR_PASSWORD \|\| '[^']+', email: process\.env\.MOODLE_ADMINISTRATOR_EMAIL \|\| 'administrator@example\.com', name: process\.env\.MOODLE_ADMINISTRATOR_NAME \|\| 'Administrator User' \},/);
  assert.match(cucumber, /tags: process\.env\.CUCUMBER_TAGS \|\| 'not @wip and not @must-fail',/);
  // Still a module node can load, with the registry where the pack reads it.
  const loaded = spawnSync(process.execPath, ['-e', `const c = require(${JSON.stringify(path.join(p.dir, 'cucumber.js'))}).default; console.log(JSON.stringify([c.require, Object.keys(c.worldParameters.users), c.tags, c.worldParameters.users.student]))`], { encoding: 'utf8', env: { ...process.env, LAUNCH_URL: 'https://site1.ddev.site' } });
  assert.strictEqual(loaded.status, 0, loaded.stderr);
  const [requires, handles, tags, student] = JSON.parse(loaded.stdout);
  assert.strictEqual(requires.length, 3);
  assert.deepStrictEqual(handles, ['administrator', 'manager', 'teacher', 'student', 'student2']);
  assert.match(tags, /not @must-fail/);
  assert.strictEqual(student.username, 'student');
  assert.strictEqual(student.name, 'Student User');
  assert.ok(fs.existsSync(path.join(p.dir, 'tests', 'features', 'site.feature')));
  assert.match(fs.readFileSync(log, 'utf8'), /"username": "student2", "email": "student2@example\.com"/, 'an installed site gets the default accounts');
  // Again, after a person changed the feature: nothing is doubled, nothing is reset.
  fs.writeFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'Feature: mine\n');
  assert.strictEqual(run().status, 0);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), cucumber);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'utf8'), 'Feature: mine\n');
});

test('the testing hook leaves a project of another platform alone', () => {
  const p = project('drupal');
  const r = bash(`cd ${p.dir} && testing_configure_moodle ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1' });
  assert.strictEqual(r.status, 0);
  assert.strictEqual(r.stdout, '');
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), SCAFFOLD);
  assert.ok(!fs.existsSync(path.join(p.dir, 'tests')));
});

test('the CLI tool refuses a project that is not Moodle', () => {
  const p = project('drupal');
  const r = bash('PROJECT_NAME=site1 ; RUN="cfg --name=release" ; trim_project_name() { :; } ; moodle_cli_tool', { WORKSPACE_ROOT: p.root, doc_name: 'dev' });
  assert.strictEqual(r.status, 1);
  assert.match(r.stdout, /is not a Moodle project/);
});

test('the first feature names no platform in a step, and no password', () => {
  const feature = fs.readFileSync(path.join(PKG, 'testing', 'site.feature'), 'utf8');
  const steps = feature.split('\n').filter((l) => /^\s*(Given|When|Then|And|But) /.test(l));
  assert.ok(steps.length >= 10);
  for (const s of steps) assert.doesNotMatch(s, /moodle/i, s);
  assert.doesNotMatch(feature, /password "(?!wrong)/);
  assert.doesNotMatch(feature, /create_user|user_create|signup/i, 'a suite never creates an account');
});
