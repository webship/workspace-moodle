/**
 * Moodle for Webship Workspace: a platform plugin.
 *
 * What the package carries is placed by the installer from the manifest: the builder and the CLI tool
 * in the sites folders, their functions, argparse and the test-site script under
 * core/scripts/plugins/moodle/, and its AI items (ai/ in this package) in the folder of their kind: the
 * agents in AI Agents, the skill in AI Skills, the command in AI Commands, the prompts in AI Prompts.
 * The dashboard needs nothing drawn for it: the builder is in the Build list because it is a
 * cmd-*-project.sh, the row menus are the core's, the AI items are listed like any other. What
 * register() adds is what the assistant is told.
 *
 * Everything the dashboard is asked for goes through `api`; this package requires nothing from the
 * dashboard's own files, so it can be installed from npm and removed without a trace.
 */

import type { PluginApi } from '@webship.co/workspace-plugin-api';

/** The plugin's name. A Moodle project has the DDEV project type php: the plugin knows it by its files. */
export const PLATFORM = 'moodle';

/** The commands the installer places in every sites folder. */
export const COMMANDS = ['cmd-moodle-project.sh', 'cmd-tools-moodle-cli.sh'];

/** The agents the installer places in the AI Agents folder. */
export const AGENTS = ['moodle-site-builder', 'moodle-tester'];

/** The skill the installer places in the AI Skills folder (a folder each, with its SKILL.md). */
export const SKILLS = ['moodle-scenarios'];

/** The slash command the installer places in the AI Commands folder. */
export const AI_COMMANDS = ['moodle-test'];

/** The prompts the installer places in the AI Prompts folder: each a whole launch command for a new session. */
export const PROMPTS = ['moodle-build-and-test', 'moodle-scenarios-for-a-role'];

/** What the assistant is told about Moodle in this workspace. */
export function assistantContext(): string {
  return [
    'Moodle (a plugin, @webship.co/workspace-moodle): a Moodle learning site is built with',
    '`bash cmd-moodle-project.sh <name> --install --add-users --test-course` from a sites folder (dev, test, sandboxes, demos),',
    'from the release package installed by its own command-line installer, in a container like every other project',
    '(DDEV project type php, the package in moodle/ served from moodle/public, its data folder moodledata/ beside it, cron running),',
    'at https://<name>.ddev.site; `--moodle-version 4.5` builds the long-term support line before 5.3.',
    '`bash cmd-tools-moodle-cli.sh <name>` says what the site is; `--run "<script> <arguments>"` runs moodle/admin/cli/<script>.php in it,',
    '`--cron` runs cron, `--purge-caches` and `--upgrade` do what they say, `--test-course` makes the test course again,',
    '`--add-users` adds the default accounts (administrator, manager, teacher, student, student2).',
    '`bash cmd-tools-testing.sh <name>` sets up webship-js with the Moodle step pack; `--run` runs the suite.',
    `For Moodle work, hand over to the agents ${AGENTS.map((a) => `\`${a}\``).join(' and ')}.`,
    `The plugin also places the skill ${SKILLS.map((a) => `\`${a}\``).join(', ')} (the step pack's phrases, by area) in ai-skills/,`,
    `the command ${AI_COMMANDS.map((a) => `\`/${a} <site>\``).join(', ')} in ai-commands/ and the prompts ${PROMPTS.map((a) => `\`${a}\``).join(' and ')} in ai-prompts/.`,
    'Never run php or a script of the site on the host for a project; the database settings in moodle/config.php are the container\'s own (db, db, db).',
  ].join(' ');
}

export function register(api: PluginApi): void {
  api.addAssistantContext(assistantContext);
}
