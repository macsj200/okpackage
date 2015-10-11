OkpackageView = require './okpackage-view'
{CompositeDisposable} = require 'atom'

spawn = require('child_process').spawn
recursive = require('recursive-readdir')
fs = require 'fs'
path = require 'path'
os = require 'os'

module.exports = Okpackage =
  packageName: require('../package.json').name

  spawnOk: (test, args) =>
    flags = ['ok']

    if(args?)
      if(args.submit?)
        flags.push '--submit'
    else if(test != 'all-tests')
      flags.push '-q'
      flags.push test


    # Override @python with path to python3 binary
    @python = "/Library/Frameworks/Python.framework/Versions/3.4/bin/python3"
    ok = spawn(@python, flags, cwd: atom.project.getPaths()[0])

    ok.stdout.on 'data', (data) ->
      console.log 'stdout: ' + data
      return
    ok.stderr.on 'data', (data) ->
      console.log 'stderr: ' + data
      return
    ok.on 'close', (code) ->
      console.log 'child process exited with code ' + code
      return

  activate: ->
    cwd = atom.project.getPaths()[0]

    if not @python
      if os.type() == "Darwin"
        @python = "/System/Library/Frameworks/Python.framework/Python"
        try
          fs.statSync @python
        catch err
          # file doesn't exist
          console.error 'unable to find python3 in', @python, 'override script by specifying path to python3 binary'
      else
        console.error "Don't know where python is on",os.type(),'Override script by specifying path to python3 binary'

    @subscriptions = new CompositeDisposable
    @subscriptions.add @taskMenuItems = new CompositeDisposable
    @subscriptions.add @taskCommands = new CompositeDisposable
    @tasks = []
    @tests = []

    @onNewTask 'submit', {submit:true}
    @onNewTask 'all-tests'

    files = fs.readdirSync cwd

    okFile = path.join cwd, (files.filter (file) -> file.indexOf('.ok') > -1 and !(file.indexOf('_') > -1))[0]
    okFileTests = (JSON.parse fs.readFileSync okFile, encoding: 'utf8').tests

    @onNewTask test.slice(test.indexOf(':') + 1) for test, type of okFileTests when type == "doctest"

    try
      fs.statSync path.join cwd, 'tests'
      files = fs.readdirSync path.join cwd, 'tests'

      testFiles = files.filter (file) -> file.indexOf('.py') > -1 and !(file.indexOf('__') > -1)

      @onNewTask test.replace '.py', '' for test in testFiles
    catch err
      # file doesn't exist, do nothing
      console.log 'no tests directory'

  deactivate: ->
    @subscriptions.dispose()

  onNewTask: (taskName, args) ->
    newTaskMenuItem = atom.menu.add [
      {
        label: @camelCase @packageName
        submenu : [
          {
            label: @camelCase taskName
            command: "#{@packageName}:#{taskName}"
          }
        ]
      }
    ]
    newTaskCommand = atom.commands.add 'atom-workspace', "#{@packageName}:#{taskName}", => @spawnOk(taskName, args)
    @tasks.push {
      name: taskName
      taskMenuItem: newTaskMenuItem
      taskCommand: newTaskCommand
    }
    @taskMenuItems.add newTaskMenuItem
    @taskCommands.add newTaskCommand

  onTaskRemoved: (taskName) ->
    for task, i in @tasks
      if task.name is taskName
        task.taskMenuItem.dispose()
        task.taskCommand.dispose()
        @tasks.splice i, 1
        break

  camelCase: (word) ->
    re = /(\b[a-z](?!\s))/g
    word.replace re, (letter) ->
      letter.toUpperCase()
