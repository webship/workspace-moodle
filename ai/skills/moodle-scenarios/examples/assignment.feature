Feature: The assignment
  A student hands in online text, the teacher grades it, and both take it back.

  Scenario: A submission handed in, graded and taken back
    Given I am a logged in user with the "student" user
    And I open the course "Software Testing 101"
    When I submit the text "Found a defect in the login form." for the assignment "Testing diary"
    Then the "Submission status" of the assignment "Testing diary" should be "Submitted for grading"
    Given I am a logged in user with the "teacher" user
    And I open the course "Software Testing 101"
    When I grade "student" with "85" for the assignment "Testing diary" with the feedback "Well found."
    Then I should see the message "The changes to the grade and feedback were saved"
    And the grader report should show "85.00" for "student" in "Testing diary"
    When I clear the grade of "student" for the assignment "Testing diary"
    Given I am a logged in user with the "student" user
    And I open the course "Software Testing 101"
    When I remove my submission for the assignment "Testing diary"
    Then the "Submission status" of the assignment "Testing diary" should be "No submissions have been made yet"
