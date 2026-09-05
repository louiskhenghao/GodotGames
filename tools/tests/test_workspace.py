import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import workspace


class WorkspaceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.patch = patch.object(workspace, 'ROOT', self.root)
        self.patch.start()
        self.addCleanup(self.patch.stop)
        self.source = self.root / 'packages/core'
        self.source.mkdir(parents=True)
        (self.source / 'service.gd').write_text('v1')
        (self.root / 'workspace.json').write_text(json.dumps({'packages': {'core': {'source': 'packages/core', 'mount': 'addons/core'}}}))
        self.game = self.root / 'games/Example'
        self.game.mkdir(parents=True)
        (self.game / 'game.json').write_text('{"packages":["core"]}')
        self.target = self.game / 'addons/core/service.gd'

    def test_fresh_sync_update_and_stale_file_removal(self):
        workspace.sync(self.game)
        self.assertEqual(self.target.read_text(), 'v1')
        (self.source / 'service.gd').unlink()
        (self.source / 'replacement.gd').write_text('v2')
        with self.assertRaises(ValueError): workspace.sync(self.game, check=True)
        workspace.sync(self.game)
        self.assertFalse(self.target.exists())
        workspace.sync(self.game, check=True)

    def test_sync_never_overwrites_manual_edits(self):
        workspace.sync(self.game)
        self.target.write_text('valuable local edit')
        with self.assertRaises(ValueError): workspace.sync(self.game)
        self.assertEqual(self.target.read_text(), 'valuable local edit')

    def test_check_is_read_only_and_game_lookup_is_scoped(self):
        with self.assertRaises(ValueError): workspace.sync(self.game, check=True)
        self.assertFalse(self.target.parent.exists())
        self.assertEqual(workspace.project('Example'), self.game)
        with self.assertRaises(ValueError): workspace.project('../packages')

    def test_create_refuses_existing_directory(self):
        with self.assertRaises(ValueError): workspace.create(self.game, 'Example')
        self.assertTrue((self.game / 'game.json').exists())

if __name__ == '__main__': unittest.main()
