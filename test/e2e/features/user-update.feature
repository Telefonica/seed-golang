Feature: Update a user
  As a user of the service
  I want to be able to update a user

  Scenario Outline: Update a registered user with valid data
    Given a user is registered
    And I want to modify login "<login>", name "<name>", msisdn "<msisdn>", and role "<role>"
    When I update the user
    Then the service replies with status 200
    And the body is empty
    And the user was updated in the service

    Examples:
      | login | name | msisdn | role |
      | updated_login | Test User Updated | 34000000000 | admin |
      | updated_login | | | |
      | | Test User Updated | | |
      | | | 34000000000 | |
      | | | | admin |

  Scenario: Delete an unregistered user
    Given a user is unregistered
    When I update the user
    Then the service replies with status 404
    And the error is "invalid_request" and the error description is "not found"
