import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

spec = importlib.util.spec_from_file_location('smoke', Path(__file__).resolve().parents[1] / 'simulator_smoke.py')
smoke = importlib.util.module_from_spec(spec)
spec.loader.exec_module(smoke)


class SmokeHarnessTests(unittest.TestCase):
    def test_capture_shutdown_waits_for_exit(self):
        with patch.object(smoke.os, 'kill', side_effect=[None, ProcessLookupError()]), \
             patch.object(smoke, 'run') as command, patch.object(smoke.time, 'sleep'):
            smoke.finish_launch('watch', 123)
            command.assert_called_once_with('xcrun', 'simctl', 'terminate', 'watch', smoke.BUNDLE)

    def test_crash_before_shutdown_is_not_hidden(self):
        with patch.object(smoke.os, 'kill', side_effect=ProcessLookupError()), patch.object(smoke, 'run') as command:
            with self.assertRaises(ProcessLookupError): smoke.finish_launch('watch', 123)
            command.assert_not_called()

    def test_shutdown_timeout_is_not_a_pass(self):
        with patch.object(smoke.os, 'kill'), patch.object(smoke, 'run'), \
             patch.object(smoke.time, 'monotonic', side_effect=[0, 16]):
            with self.assertRaisesRegex(RuntimeError, 'did not exit'): smoke.finish_launch('watch', 123)

    def test_watch_size_is_numeric(self):
        self.assertLess(smoke.watch_size({'name': 'Apple Watch SE (40mm)'}),
                        smoke.watch_size({'name': 'Apple Watch Ultra (49mm)'}))

    def test_inventory_timeout_retries_once_without_hiding_other_failures(self):
        devices = json.dumps({'devices': {'watchOS': [{'udid': 'test', 'state': 'Booted'}]}})
        with patch.object(smoke, 'run', side_effect=[subprocess.TimeoutExpired('list', 180), devices, '']) as command:
            smoke.boot_if_needed('test')
            self.assertEqual(command.call_count, 3)
        with patch.object(smoke, 'run', side_effect=subprocess.TimeoutExpired('list', 180)) as command:
            with self.assertRaises(subprocess.TimeoutExpired): smoke.boot_if_needed('test')
            self.assertEqual(command.call_count, 2)
        with patch.object(smoke, 'run', side_effect=subprocess.CalledProcessError(1, 'list')) as command:
            with self.assertRaises(subprocess.CalledProcessError): smoke.boot_if_needed('test')
            self.assertEqual(command.call_count, 1)

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
                                   'cycling': False, 'screen': 'map'}, mode)

    def test_wrong_or_missing_state_fails(self):
        for report in ({}, {'mode': 'bikes'}, {'url': 'youcantparkthere://ride', 'accepted': True,
                        'demo': True, 'mode': 'docks', 'cycling': True, 'screen': 'map'}):
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
