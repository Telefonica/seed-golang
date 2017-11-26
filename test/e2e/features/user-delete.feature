Feature: Delete a user
  As a user of the service
  I want to be able to delete a user

  Scenario: Delete a registered user
    Given a user is registered
    When I delete the user
    Then the service replies with status 204
    And the body is empty

  Scenario: Delete an unregistered user
    Given a user is unregistered
    When I delete the user
    Then the service replies with status 404
    And the error is "invalid_request" and the error description is "not found"
