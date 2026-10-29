import unittest
import test_api


class AccountTest(unittest.TestCase):
    setUp = test_api.ApiTest.setUp
    tearDown = test_api.ApiTest.tearDown
    request = test_api.ApiTest.request

    def test_recovery_is_single_use_and_revokes_sessions(self):
        credentials = {'email': 'recover@example.com', 'password': 'original password 123'}
        token = self.request('POST', '/api/v1/auth/register', credentials)[1]['token']
        status, result = self.request('POST', '/api/v1/account/recovery-code', {'password': credentials['password']}, token)
        self.assertEqual(status, 200)
        reset = {'email': credentials['email'], 'newPassword': 'replacement password 123', 'recoveryCode': result['recoveryCode']}
        self.assertEqual(self.request('POST', '/api/v1/auth/recover', reset)[0], 200)
        self.assertEqual(self.request('GET', '/api/v1/state', token=token)[0], 401)
        self.assertEqual(self.request('POST', '/api/v1/auth/recover', reset)[0], 400)
        self.assertEqual(self.request('POST', '/api/v1/auth/login', credentials)[0], 401)
        credentials['password'] = reset['newPassword']
        self.assertEqual(self.request('POST', '/api/v1/auth/login', credentials)[0], 200)

    def test_change_and_delete_require_password_and_remove_owned_groups(self):
        credentials = {'email': 'delete@example.com', 'password': 'original password 123'}
        token = self.request('POST', '/api/v1/auth/register', credentials)[1]['token']
        self.assertEqual(self.request('POST', '/api/v1/groups', {'name': 'Owned group'}, token)[0], 201)
        self.assertEqual(self.request('POST', '/api/v1/account/delete', {'password': 'incorrect password'}, token)[0], 401)
        self.assertEqual(self.request('POST', '/api/v1/account/password', {'password': credentials['password'], 'newPassword': 'new password 12345'}, token)[0], 200)
        self.assertEqual(self.request('GET', '/api/v1/state', token=token)[0], 401)
        credentials['password'] = 'new password 12345'
        token = self.request('POST', '/api/v1/auth/login', credentials)[1]['token']
        self.assertEqual(self.request('POST', '/api/v1/account/delete', {'password': credentials['password']}, token)[0], 200)
        self.assertEqual(self.request('POST', '/api/v1/auth/login', credentials)[0], 401)

    def test_deleted_account_id_is_not_reused(self):
        credentials = {'email': 'reuse@example.com', 'password': 'original password 123'}
        first = self.request('POST', '/api/v1/auth/register', credentials)[1]
        self.assertEqual(self.request('POST', '/api/v1/account/delete', {'password': credentials['password']}, first['token'])[0], 200)
        second = self.request('POST', '/api/v1/auth/register', credentials)[1]
        self.assertNotEqual(first['user']['id'], second['user']['id'])
        self.assertLess(second['user']['id'], 2**53)
