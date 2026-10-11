import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1'))
const source = fs.readFileSync(path.join(root, 'harmonyos/ets-source/pages/MainWindowNativeNode.ets'), 'utf8')

assert.match(source, /@State private keyboardTextInputFocused: boolean = false/)
assert.match(source, /if \(this\.keyboardTextInputFocused\) \{ return false \}/)
assert.match(source, /KeyCode\.KEYCODE_DEL && event\.keyCode !== KeyCode\.KEYCODE_FORWARD_DEL/)
assert.match(source, /TextInput\(\{ text: this\.searchText, placeholder: I18n\.t\('i0063'\) \}\)[\s\S]*?\.onFocus\(\(\) => \{\n\s*this\.keyboardTextInputFocused = true/)
assert.match(source, /TextInput\(\{ text: this\.locSearchQuery, placeholder: I18n\.t\('loc_search_placeholder'\) \}\)[\s\S]*?\.onFocus\(\(\) => \{\n\s*this\.keyboardTextInputFocused = true/)
assert.match(source, /this\.locationSearchScanRegionFilter = this\.locationSearchRegionFilter\(q\)/)
assert.match(source, /this\.locationSearchScanContinents = this\.locationSearchScanRegionFilter === undefined/)
assert.match(source, /this\.locationSearchScanRegionFilter\.has\(region\)/)
assert.match(source, /setTimeout\(\(\) => \{ this\.searchLocations\(value\) \}, 120\)/)
assert.match(source, /Date\.now\(\) - startedAt < 8/)
assert.match(source, /now - this\.locationSearchLastPublishMs >= 40/)

console.log('HarmonyOS search input routing and location search contract passed.')
