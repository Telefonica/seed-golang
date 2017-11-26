Feature: Create user
  As a user of the service
  I want to be able to create users

  Scenario Outline: Create a user with valid data
    Given a user with login "<login>", name "<name>", msisdn "<msisdn>", and role "<role>"
    When I create the user
    Then the service replies with status 201
    And the body is empty
    And the location header targets the new user

    Examples:
      | login | name | msisdn | role |
      | lorenzo | Jorge Lorenzo | 34123456789 | admin |
      | pedrosa | Dani Pedrosa | 34987654321 | user |
      | marquez | Marc Márquez | 34111111111 | |

  Scenario Outline: Create a user with invalid data
    Given a user with login "<login>", name "<name>", msisdn "<msisdn>", and role "<role>"
    When I create the user
    Then the service replies with status 400
    And the location header is not available
    And the error is "<error>" and the error description is "<error_description>"

    Examples:
      | login | name | msisdn | role | error | error_description |
      | | John Doe | 34123456789 | user | invalid_request | login: login is required |
      | username | | 34123456789 | user | invalid_request | name: name is required |
      | username | John Doe | | user | invalid_request | msisdn: msisdn is required |
      | username | John Doe | invalid phone | admin | invalid_request | msisdn: Does not match pattern '^\d{9,11}$' |
      | username | John Doe | 34123456789 | invalid role | invalid_request | role: role must be one of the following: "user", "admin" |
