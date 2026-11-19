<?php
// The test site of the Moodle plugin of the Webship Workspace: its settings, its test course and its
// accounts, written through the site's own API by its own PHP, in its container. The same test site as
// the one the step pack (@webship-js/moodle-steps) builds, so the pack's features run on it as they are.
//
//   php test-site.php --config=/var/www/html/config.php --settings
//   php test-site.php --config=/var/www/html/config.php --course
//   php test-site.php --config=/var/www/html/config.php --accounts=/var/www/html/accounts.json
//   php test-site.php --config=/var/www/html/config.php --delete-accounts=/var/www/html/accounts.json
//   php test-site.php --config=/var/www/html/config.php --list-accounts
//
// --settings   the settings the suite relies on: the guest login button on the
//              login page, completion tracking, and no user tours (a tour opens
//              over the page the first time an account sees it).
// --course     the test course, made again from nothing when it is there: the
//              category "Test courses", the course "Software Testing 101"
//              (TEST101) with three named sections, a Page, an Assignment
//              (online text), a Quiz with three questions and a Forum, completion
//              on each, and self enrolment with the key "TEST101-key".
// --accounts   the accounts of a JSON list (username, email, firstname,
//              lastname, password, and siteadmin, systemrole or courserole):
//              created, or given back their name, address, password and roles.
//              An account without a course role is taken out of the test course.
// --delete-accounts  the accounts of a JSON list (by user name) deleted, as the
//              site deletes a user.
// --list-accounts    every account of the site: user name, address, full name,
//              site administrator or not.
//
// Accounts are configuration: the suite never creates or deletes one.

define('CLI_SCRIPT', true);

$options = getopt('', ['config:', 'settings', 'course', 'accounts:', 'delete-accounts:', 'list-accounts', 'help']);
if (isset($options['help']) || empty($options['config'])) {
    fwrite(STDERR, "Usage: php test-site.php --config=<path of config.php> [--settings] [--course] [--accounts=<json file>] [--delete-accounts=<json file>] [--list-accounts]\n");
    exit(isset($options['help']) ? 0 : 1);
}

require($options['config']);
require_once($CFG->libdir . '/clilib.php');
require_once($CFG->libdir . '/enrollib.php');
require_once($CFG->libdir . '/completionlib.php');
require_once($CFG->dirroot . '/user/lib.php');
require_once($CFG->dirroot . '/course/lib.php');
require_once($CFG->dirroot . '/mod/quiz/locallib.php');
require_once($CFG->libdir . '/testing/generator/lib.php');

// Act as the site administrator: the course and its activities are made the way
// an administrator makes them.
\core\session\manager::set_user(get_admin());

const TEST_CATEGORY = 'Test courses';
const TEST_COURSE_SHORTNAME = 'TEST101';
const TEST_COURSE_FULLNAME = 'Software Testing 101';
const TEST_COURSE_KEY = 'TEST101-key';

/** The site settings the suite relies on. */
function webship_test_settings(): void {
    global $DB;
    // The "Access as a guest" button of the login page.
    set_config('guestloginbutton', 1);
    // Completion tracking (on by default; the course page shows each activity's conditions).
    set_config('enablecompletion', 1);
    // No user tours: a tour opens a dialog over a page the first time an account sees it.
    if ($DB->get_manager()->table_exists('tool_usertours_tours')) {
        $DB->set_field('tool_usertours_tours', 'enabled', 0);
        if (class_exists('\tool_usertours\cache')) {
            \tool_usertours\cache::notify_tour_change();
        }
    }
    cli_writeln('  settings: the guest login button, completion tracking, no user tours');
}

/**
 * The default question category of the course's question bank: the course's
 * own bank (5.0 and later keep questions in a bank of the course), or the
 * course context (4.5).
 */
function webship_question_category(stdClass $course): stdClass {
    global $CFG;
    require_once($CFG->libdir . '/questionlib.php');
    $helper = 'core_question\local\bank\question_bank_helper';
    if (class_exists($helper) && method_exists($helper, 'get_default_open_instance_system_type')) {
        $bank = $helper::get_default_open_instance_system_type($course, true);
        $context = context_module::instance($bank->id);
    } else {
        $context = context_course::instance($course->id);
    }
    $category = question_get_default_category($context->id, true);
    return $category ?: question_make_default_categories([$context]);
}

/** A question saved through its question type, as the question editing form saves it. */
function webship_save_question(stdClass $category, string $qtype, array $form): stdClass {
    global $USER;
    $question = (object) ['category' => $category->id, 'qtype' => $qtype, 'createdby' => $USER->id, 'idnumber' => null];
    $fromform = (object) array_merge([
        'category' => $category->id . ',' . $category->contextid,
        'defaultmark' => 1,
        'penalty' => 0.3333333,
        'generalfeedback' => ['text' => '', 'format' => FORMAT_HTML],
        'hint' => [],
        'status' => \core_question\local\bank\question_version_status::QUESTION_STATUS_READY,
    ], $form);
    return question_bank::get_qtype($qtype)->save_question($question, $fromform);
}

/** The test course, made again from nothing. */
function webship_test_course(): stdClass {
    global $DB, $CFG;

    if ($old = $DB->get_record('course', ['shortname' => TEST_COURSE_SHORTNAME])) {
        delete_course($old, false);
        cli_writeln('  the test course of an earlier build is deleted');
    }

    $category = $DB->get_record('course_categories', ['idnumber' => 'webship-test-courses']);
    if (!$category) {
        $category = core_course_category::create([
            'name' => TEST_CATEGORY,
            'idnumber' => 'webship-test-courses',
            'description' => 'The courses the test suite runs in.',
        ]);
    }

    $generator = new testing_data_generator();
    $start = usergetmidnight(time()) - 7 * DAYSECS;
    $course = $generator->create_course([
        'fullname' => TEST_COURSE_FULLNAME,
        'shortname' => TEST_COURSE_SHORTNAME,
        'idnumber' => TEST_COURSE_SHORTNAME,
        'category' => $category->id,
        'summary' => '<p>A short course about testing software, made for the test suite.</p>',
        'summaryformat' => FORMAT_HTML,
        'format' => 'topics',
        'numsections' => 3,
        'startdate' => $start,
        'enddate' => 0,
        'enablecompletion' => 1,
        'showcompletionconditions' => 1,
        'showgrades' => 1,
        'newsitems' => 5,
    ], ['createsections' => true]);

    foreach ([1 => 'Getting started', 2 => 'Practice', 3 => 'Wrap-up'] as $number => $name) {
        $section = $DB->get_record('course_sections', ['course' => $course->id, 'section' => $number], '*', MUST_EXIST);
        course_update_section($course, $section, ['name' => $name]);
    }

    $generator->create_module('page', [
        'course' => $course->id,
        'section' => 1,
        'name' => 'Course handbook',
        'intro' => '<p>How the course works.</p>',
        'content' => '<h3>How this course works</h3><p>Read this handbook, write in the testing diary, '
            . 'take the basics quiz and join the class discussion.</p>',
        'completion' => COMPLETION_TRACKING_AUTOMATIC,
        'completionview' => 1,
    ]);

    $generator->create_module('assign', [
        'course' => $course->id,
        'section' => 1,
        'name' => 'Testing diary',
        'intro' => '<p>Write a short entry about a defect you found this week.</p>',
        'assignsubmission_onlinetext_enabled' => 1,
        'assignsubmission_file_enabled' => 0,
        'assignfeedback_comments_enabled' => 1,
        'submissiondrafts' => 0,
        'sendstudentnotifications' => 1,
        'grade' => 100,
        'allowsubmissionsfromdate' => $start,
        'duedate' => usergetmidnight(time()) + 7 * DAYSECS + 17 * HOURSECS,
        'completion' => COMPLETION_TRACKING_AUTOMATIC,
        'completionsubmit' => 1,
    ]);

    $quiz = $generator->create_module('quiz', [
        'course' => $course->id,
        'section' => 2,
        'name' => 'Basics quiz',
        'intro' => '<p>Three questions about the basics of testing.</p>',
        'grade' => 10,
        'questionsperpage' => 0,
        'attempts' => 0,
        'preferredbehaviour' => 'deferredfeedback',
        'completion' => COMPLETION_TRACKING_AUTOMATIC,
        'completionusegrade' => 1,
    ]);

    // Three questions in the course's own question bank, saved through the
    // question types' own API.
    $bank = webship_question_category($course);
    $made = [];
    $made[] = webship_save_question($bank, 'truefalse', [
        'name' => 'Testing shows defects',
        'questiontext' => ['text' => 'Testing can show that defects are present.', 'format' => FORMAT_HTML],
        'generalfeedback' => ['text' => 'Testing shows the presence of defects, not their absence.', 'format' => FORMAT_HTML],
        'correctanswer' => '1',
        'feedbacktrue' => ['text' => '', 'format' => FORMAT_HTML],
        'feedbackfalse' => ['text' => '', 'format' => FORMAT_HTML],
        'penalty' => 1,
    ]);
    $made[] = webship_save_question($bank, 'multichoice', [
        'name' => 'Smallest part',
        'questiontext' => ['text' => 'Which test checks the smallest testable part of the software?', 'format' => FORMAT_HTML],
        'generalfeedback' => ['text' => 'A unit test checks one unit on its own.', 'format' => FORMAT_HTML],
        'single' => '1',
        'shuffleanswers' => 0,
        'answernumbering' => 'abc',
        'showstandardinstruction' => 0,
        'shownumcorrect' => 0,
        'noanswers' => 4,
        'answer' => [
            ['text' => 'Unit test', 'format' => FORMAT_PLAIN],
            ['text' => 'System test', 'format' => FORMAT_PLAIN],
            ['text' => 'Acceptance test', 'format' => FORMAT_PLAIN],
            ['text' => 'Load test', 'format' => FORMAT_PLAIN],
        ],
        'fraction' => ['1.0', '0.0', '0.0', '0.0'],
        'feedback' => array_fill(0, 4, ['text' => '', 'format' => FORMAT_HTML]),
        'correctfeedback' => ['text' => 'Your answer is correct.', 'format' => FORMAT_HTML],
        'partiallycorrectfeedback' => ['text' => 'Your answer is partially correct.', 'format' => FORMAT_HTML],
        'incorrectfeedback' => ['text' => 'Your answer is incorrect.', 'format' => FORMAT_HTML],
    ]);
    $made[] = webship_save_question($bank, 'shortanswer', [
        'name' => 'A flaw in the software',
        'questiontext' => ['text' => 'In one word, what do testers call a flaw in the software?', 'format' => FORMAT_HTML],
        'generalfeedback' => ['text' => 'A flaw in the software is a defect, or a bug.', 'format' => FORMAT_HTML],
        'usecase' => 0,
        'answer' => ['defect', 'bug', '*'],
        'fraction' => ['1.0', '1.0', '0.0'],
        'feedback' => [
            ['text' => 'Right.', 'format' => FORMAT_HTML],
            ['text' => 'Right.', 'format' => FORMAT_HTML],
            ['text' => 'Not quite.', 'format' => FORMAT_HTML],
        ],
    ]);
    $quizrecord = $DB->get_record('quiz', ['id' => $quiz->id], '*', MUST_EXIST);
    foreach ($made as $question) {
        quiz_add_quiz_question($question->id, $quizrecord, 0, 1);
    }
    \mod_quiz\quiz_settings::create($quiz->id)->get_grade_calculator()->recompute_quiz_sumgrades();

    $generator->create_module('forum', [
        'course' => $course->id,
        'section' => 2,
        'name' => 'Class discussion',
        'intro' => '<p>Ask and answer questions about the course.</p>',
        'type' => 'general',
        'completion' => COMPLETION_TRACKING_MANUAL,
    ]);

    // Self enrolment with a key: the instance every new course gets, turned on.
    $self = enrol_get_plugin('self');
    $instance = $DB->get_record('enrol', ['courseid' => $course->id, 'enrol' => 'self']);
    if (!$instance) {
        $instanceid = $self->add_default_instance($course);
        $instance = $DB->get_record('enrol', ['id' => $instanceid], '*', MUST_EXIST);
    }
    // The status first: update_status() writes the instance it is given back whole.
    $self->update_status($instance, ENROL_INSTANCE_ENABLED);
    $DB->update_record('enrol', (object) [
        'id' => $instance->id,
        'password' => TEST_COURSE_KEY,
        'customint6' => 1,
        'roleid' => $DB->get_field('role', 'id', ['shortname' => 'student']),
    ]);

    // No guest access: a guest is asked to log in.
    if ($guest = $DB->get_record('enrol', ['courseid' => $course->id, 'enrol' => 'guest'])) {
        enrol_get_plugin('guest')->update_status($guest, ENROL_INSTANCE_DISABLED);
    }

    rebuild_course_cache($course->id, true);
    cli_writeln('  the test course: ' . TEST_COURSE_FULLNAME . ' (' . TEST_COURSE_SHORTNAME . ') in "' . TEST_CATEGORY
        . '": Course handbook, Testing diary, Basics quiz (3 questions), Class discussion; self enrolment key ' . TEST_COURSE_KEY);
    return $course;
}

/** The accounts of a JSON list, created or given back their name, address, password and roles. */
function webship_test_accounts(string $file): void {
    global $DB, $CFG;
    $accounts = json_decode((string) file_get_contents($file), true, 512, JSON_THROW_ON_ERROR);
    $course = $DB->get_record('course', ['shortname' => TEST_COURSE_SHORTNAME]);
    $manual = enrol_get_plugin('manual');
    $instance = $course ? $DB->get_record('enrol', ['courseid' => $course->id, 'enrol' => 'manual']) : null;

    foreach ($accounts as $account) {
        $username = core_text::strtolower($account['username']);
        $user = $DB->get_record('user', ['username' => $username, 'mnethostid' => $CFG->mnet_localhost_id, 'deleted' => 0]);
        $fields = [
            'email' => $account['email'],
            'firstname' => $account['firstname'],
            'lastname' => $account['lastname'],
            'auth' => 'manual',
            'confirmed' => 1,
            'suspended' => 0,
            'policyagreed' => 1,
        ];
        if (!$user) {
            $id = user_create_user((object) ($fields + [
                'username' => $username,
                'password' => $account['password'],
                'mnethostid' => $CFG->mnet_localhost_id,
                'lang' => $CFG->lang ?? 'en',
            ]), true, false);
            $user = $DB->get_record('user', ['id' => $id], '*', MUST_EXIST);
        } else {
            user_update_user((object) ($fields + ['id' => $user->id]), false, false);
            $user = $DB->get_record('user', ['id' => $user->id], '*', MUST_EXIST);
            update_internal_user_password($user, $account['password']);
        }
        unset_user_preference('auth_forcepasswordchange', $user);
        set_user_preference('htmleditor', '', $user);

        $roles = [];
        if (!empty($account['siteadmin'])) {
            $admins = array_filter(explode(',', (string) $CFG->siteadmins));
            if (!in_array((string) $user->id, $admins, true)) {
                $admins[] = (string) $user->id;
                set_config('siteadmins', implode(',', $admins));
            }
            $roles[] = 'site administrator';
        }
        if (!empty($account['systemrole'])) {
            $roleid = $DB->get_field('role', 'id', ['shortname' => $account['systemrole']], MUST_EXIST);
            role_assign($roleid, $user->id, context_system::instance()->id);
            $roles[] = $account['systemrole'] . ' (site)';
        }
        if ($course && $instance) {
            if (!empty($account['courserole'])) {
                $roleid = $DB->get_field('role', 'id', ['shortname' => $account['courserole']], MUST_EXIST);
                $manual->enrol_user($instance, $user->id, $roleid, 0, 0, ENROL_USER_ACTIVE);
                $context = context_course::instance($course->id);
                // Exactly that role in the course: a role a run added and left is taken back.
                foreach (get_user_roles($context, $user->id, false) as $assignment) {
                    if ((int) $assignment->roleid !== (int) $roleid) {
                        role_unassign($assignment->roleid, $user->id, $context->id, $assignment->component, $assignment->itemid);
                    }
                }
                role_assign($roleid, $user->id, $context->id);
                $roles[] = $account['courserole'] . ' (' . TEST_COURSE_SHORTNAME . ')';
            } else {
                // Not enrolled: a run stopped half way may have left an enrolment behind.
                foreach (enrol_get_instances($course->id, false) as $any) {
                    $plugin = enrol_get_plugin($any->enrol);
                    if ($plugin && $DB->record_exists('user_enrolments', ['enrolid' => $any->id, 'userid' => $user->id])) {
                        $plugin->unenrol_user($any, $user->id);
                    }
                }
            }
        }
        cli_writeln(sprintf('  %s <%s> %s %s: %s', $user->username, $user->email, $user->firstname, $user->lastname,
            $roles ? implode(', ', $roles) : 'no role'));
    }
}

/** The accounts of a JSON list deleted, by user name, the way the site deletes a user. */
function webship_delete_accounts(string $file): void {
    global $DB, $CFG;
    $accounts = json_decode((string) file_get_contents($file), true, 512, JSON_THROW_ON_ERROR);
    foreach ($accounts as $account) {
        $username = core_text::strtolower($account['username']);
        $user = $DB->get_record('user', ['username' => $username, 'mnethostid' => $CFG->mnet_localhost_id, 'deleted' => 0]);
        if (!$user) {
            cli_writeln("  {$username} is not there");
            continue;
        }
        if (is_siteadmin($user)) {
            $admins = array_diff(array_filter(explode(',', (string) $CFG->siteadmins)), [(string) $user->id]);
            set_config('siteadmins', implode(',', $admins));
        }
        delete_user($user);
        cli_writeln("  {$username} deleted");
    }
}

/** Every account of the site, one line each. */
function webship_list_accounts(): void {
    global $DB, $CFG;
    $admins = array_filter(explode(',', (string) $CFG->siteadmins));
    foreach ($DB->get_records('user', ['deleted' => 0], 'id', 'id, username, email, firstname, lastname, suspended') as $user) {
        if ($user->username === 'guest') {
            continue;
        }
        printf("  %s <%s> %s %s%s%s\n", $user->username, $user->email, $user->firstname, $user->lastname,
            in_array((string) $user->id, $admins, true) ? ' (site administrator)' : '', $user->suspended ? ' (suspended)' : '');
    }
}

if (isset($options['settings'])) {
    webship_test_settings();
}
if (isset($options['course'])) {
    webship_test_course();
}
if (!empty($options['accounts'])) {
    webship_test_accounts($options['accounts']);
}
if (!empty($options['delete-accounts'])) {
    webship_delete_accounts($options['delete-accounts']);
}
if (isset($options['list-accounts'])) {
    webship_list_accounts();
    exit(0);
}
purge_all_caches();
