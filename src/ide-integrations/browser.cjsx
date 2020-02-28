React = require 'react'
createReactClass = require 'create-react-class'
_l = require 'lodash'

{Editor} = require '../editor/edit-page'
{Doc} = require '../doc'
core = require '../core'
config = require '../config'
util = require '../util'

# This loads node.js APIs if in electron.  If run in a browser, this should crash, or something.
# We want to be careful to not use 'require' or webpack might try to bundle the node modules for
# us, or something.  This file will be built into the static js package that's on the cloud editor
# that runs in the web, so let's try not to break it.
###
fs = window.require('fs')
path = window.require('path')
electron = window.require('electron').remote
filendir = window.require('filendir')
readdirRecursive = window.require 'fs-readdir-recursive'
###
fs = require('fs')
path = require('path')
filendir = require('filendir')
readdirRecursive = () -> {[]}



#currentWindow = electron.getCurrentWindow(['openFile'])

#openResults = electron.dialog.showOpenDialog()
###
if openResults?
    open_file = openResults[0]
    initialDocjson = JSON.parse fs.readFileSync(open_file, 'utf-8')

else
    open_file = electron.dialog.showSaveDialog({
        defaultPath: 'untitled.pagedraw.json',
        buttonLabel: 'Create'
    })
    ###
initialDocjson = (new Doc()).serialize()
console.log(initialDocjson)
#fs.writeFileSync(open_file, initialDocjson, 'utf-8')

#currentWindow.setRepresentedFilename?(open_file)

module.exports = createReactClass
    componentWillMount: ->

    #componentDidMount: ->
    #    currentWindow.maximize()
    #    currentWindow.show()

    render: ->
        <Editor
            initialDocJson={initialDocjson}
            onChange={@handleDocjsonChanged}
            windowTitle="Pagedraw"
        />

    handleDocjsonChanged: (docjson) ->
        # save the .pagedraw file
        fs.writeFileSync(open_file, JSON.stringify(docjson), 'utf-8')

        # write the compiled files
        root_dir = path.dirname(open_file)
        managed_dir = path.join(root_dir, 'src/pagedraw/')
        generated_by_header = "Generated by #{path.basename(open_file)}"

        # pass extra arguments to compileReact through compileDoc— not great
        config.extraJSPrefix = "// #{generated_by_header}"
        config.extraCSSPrefix = "/* #{generated_by_header} */"
        build_results = core.compileDoc(Doc.deserialize(docjson))

        build_results = build_results.map (r) -> [path.join(root_dir, r.filePath), r.contents]

        # don't let files go outside the managed directory
        build_results = build_results.filter(([filePath, contents]) -> isInsideDir(managed_dir, filePath))

        existing_built_files = _l.fromPairs readdirRecursive(managed_dir).map (existing_file_path_inside_managed_dir) ->
            existing_file_path = path.join(managed_dir, existing_file_path_inside_managed_dir)
            is_overwritable =
                try
                    first_5_lines = fs.readFileSync(existing_file_path, 'utf-8').split('\n').slice(0, 5).join('\n')

                    # see if any of them match pattern
                    _l.includes(first_5_lines, generated_by_header)

                catch
                    # if the read fails, we treat the file as not existing
                    undefined

            [existing_file_path, is_overwritable]

        for filePath, [new_contents, is_overwritable] of util.zip_dicts [_l.fromPairs(build_results), existing_built_files]
            if is_overwritable == true and not new_contents?
                fs.unlinkSync(filePath)

            else if (is_overwritable == true or is_overwritable == undefined) and new_contents?
                filendir.writeFile filePath, new_contents, (() -> )

            # else if new_contents? and is_overwritable == false then no-op; someone else owns the file
            # else if not new_contents? and is_overwritable == false then no-op; not relevant to us
            # else if not new_contents? and is_overwritable == undefined then no-op; not relevant to us


# definitely not "right", kind of a hack
isInsideDir = (dir_path, file_path) -> file_path.startsWith(dir_path)
