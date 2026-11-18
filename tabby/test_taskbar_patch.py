import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("taskbar_patch", Path(__file__).with_name("patch-dash-to-panel.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class TaskbarPatchTests(unittest.TestCase):
    def test_only_expected_hook_changes(self):
        source = "before\n" + module.ORIGINAL + "after\n"
        self.assertEqual(module.patch(source), "before\n" + module.REPLACEMENT + "after\n")

    def test_idempotent(self):
        once = module.patch(module.ORIGINAL)
        self.assertEqual(module.patch(once), once)

    def test_rejects_missing_hook(self):
        with self.assertRaises(ValueError):
            module.patch("upstream changed\n")

    def test_rejects_ambiguous_hook(self):
        with self.assertRaises(ValueError):
            module.patch(module.ORIGINAL * 2)


if __name__ == "__main__":
    unittest.main()
