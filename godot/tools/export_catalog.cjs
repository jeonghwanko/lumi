#!/usr/bin/env node
'use strict';
// Data-only export. Never edits or upgrades the source art status/atlas fields.
const fs = require('node:fs');
const path = require('node:path');
const catalog = require('../../cafe-catalog.js');
const target = path.join(__dirname, '../data/catalog.json');
if (catalog.facilities.length !== 36 || catalog.chapters.length !== 6 || catalog.decorations.length !== 19) {
  throw new Error('Unexpected catalog dimensions; review the migration.');
}
fs.writeFileSync(target, JSON.stringify(catalog, null, 2) + '\n');
console.log(`Exported ${catalog.facilities.length} facilities, ${catalog.chapters.length} chapters, ${catalog.decorations.length} decorations`);
