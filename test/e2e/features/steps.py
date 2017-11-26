from lettuce import *
import json
import os
import requests

SEED_SERVER = os.environ.get('SEED_SERVER', 'http://localhost:9000')

def clean_empty_from_dict(**kwargs):
    for k in kwargs.keys():
        if not kwargs[k]:
            del kwargs[k]
    return kwargs

def create_user(user):
    return requests.post(SEED_SERVER + '/seed/users', json=user, allow_redirects=False)

def get_user(user_id):
    return requests.get(SEED_SERVER + '/seed/users/' + user_id)

def check_user(got_user, expected_user):
    for k in expected_user.keys():
        assert expected_user[k] == got_user.get(k), 'For %s, got: %s, expected: %s' % (k, expected_user[k], got_user.get(k))

def update_user(user_id, patch):
    return requests.patch(SEED_SERVER + '/seed/users/' + user_id, json=patch)

def delete_user(user_id):
    return requests.delete(SEED_SERVER + '/seed/users/' + user_id)

def get_location_user_id(location):
    return location[location.rfind('/') + 1:]

@step('a user with login "(.*)", name "(.*)", msisdn "(.*)", and role "(.*)"')
def user(step, login, name, msisdn, role):
    world.user = clean_empty_from_dict(login=login, name=name, msisdn=msisdn, role=role)

@step('I want to modify login "(.*)", name "(.*)", msisdn "(.*)", and role "(.*)"')
def patch(step, login, name, msisdn, role):
    world.patch = clean_empty_from_dict(login=login, name=name, msisdn=msisdn, role=role)

@step('a user is registered')
def user_registered(step):
    world.user = {
        'login': 'demo',
        'name': 'Test user',
        'msisdn': '34123456789',
        'role': 'user'
    }
    response = create_user(world.user)
    location = response.headers.get('location')
    assert location, 'Location header is missing'
    world.user['id'] = get_location_user_id(location)

@step('a user is unregistered')
def user_unregistered(step):
    world.user = {
        'id': 'd5b7aaaa-d215-11e7-9cb2-0242ac1a0003'
    }

@step('I create the user')
def create_the_user(step):
    world.response = create_user(world.user)

@step('I get the user')
def get_the_user(step):
    world.response = get_user(world.user['id'])

@step('I update the user')
def update_the_user(step):
    world.response = update_user(world.user['id'], world.patch)

@step('I delete the user')
def delete_the_user(step):
    world.response = delete_user(world.user['id'])

@step('the service replies with status (\d+)')
def response_status(step, expected):
    assert world.response.status_code == int(expected), 'Got status %d. Expected %d' % (world.response.status_code, int(expected))

@step('the location header targets the new user')
def response_location(step):
    location = world.response.headers.get('location')
    assert location, 'Location header is missing'
    world.user['id'] = get_location_user_id(location)
    response = get_user(world.user['id'])
    check_user(response.json(), world.user)

@step('the location header is not available')
def response_location_unavailable(step):
    location = world.response.headers.get('location')
    assert location is None, 'Location header is available: %s' % location

@step('the body contains the user information')
def response_location(step):
    check_user(world.response.json(), world.user)

@step('the user was updated in the service')
def user_updated(step):
    response = get_user(world.user['id'])
    expected_user = world.user.copy()
    expected_user.update(world.patch)
    check_user(response.json(), expected_user)

@step('the body is empty')
def response_location(step):
    assert world.response.text == '', 'Expected empty body but got %s' % world.response.text

@step('the error is "(.*)" and the error description is "(.*)"')
def response_error(step, error, error_description):
    body = world.response.json()
    assert error == body.get('error'), 'Got error %s. Expected %s' % (body.get('error'), error)
    assert error_description == body.get('error_description'), 'Got error description %s. Expected %s' % (body.get('error_description'), error_description)
