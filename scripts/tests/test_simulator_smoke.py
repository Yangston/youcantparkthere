import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('smoke', Path(__file__).resolve().parents[1] / 'simulator_smoke.py')
smoke = importlib.util.module_from_spec(spec)
spec.loader.exec_module(smoke)


class SmokeHarnessTests(unittest.TestCase):
    def test_runtime_versions_are_numeric(self):
        self.assertGreater(smoke.runtime_version('com.apple.CoreSimulator.SimRuntime.watchOS-26-10'),
                           smoke.runtime_version('com.apple.CoreSimulator.SimRuntime.watchOS-26-3'))

    def test_process_id_requires_positive_reported_pid(self):
        self.assertEqual(smoke.process_id('com.example.app: 1234\n'), 1234)
        for output in ('', 'failed', 'com.example.app: 0', 'com.example.app: -1'):
            with self.assertRaises(RuntimeError):
                smoke.process_id(output)

    def test_three_actual_states(self):
        for mode in ('docks', 'bikes', 'ride'):
            smoke.validate_report({'url': f'youcantparkthere://{mode}', 'accepted': True, 'demo': True,
                                   'mode': 'bikes' if mode == 'bikes' else 'docks',
                                   'riding': mode == 'ride', 'tab': 0}, mode)

    def test_wrong_or_missing_state_fails(self):
        for report in ({}, {'mode': 'bikes'}, {'url': 'youcantparkthere://ride', 'accepted': True,
                        'demo': True, 'mode': 'docks', 'riding': False, 'tab': 0}):
            with self.assertRaises(RuntimeError):
                smoke.validate_report(report, 'ride')

    def test_already_active_is_the_only_accepted_pair_error(self):
        expected = subprocess.CalledProcessError(37, 'pair_activate', stderr='This pair is already active.')
        with patch.object(smoke, 'run', side_effect=expected):
            smoke.activate_pair('test-pair')
        for error in (subprocess.CalledProcessError(37, 'pair_activate', stderr='Different failure'),
                      subprocess.CalledProcessError(1, 'pair_activate', stderr='This pair is already active.')):
            with patch.object(smoke, 'run', side_effect=error), self.assertRaises(subprocess.CalledProcessError):
                smoke.activate_pair('test-pair')

    def test_cleanup_timeout_does_not_mask_failure(self):
        with patch.object(smoke.subprocess, 'run', side_effect=subprocess.TimeoutExpired('shutdown', 30)):
            smoke.cleanup('shutdown')


if __name__ == '__main__':
    unittest.main()
