OkpackageView = require './okpackage-view'
{CompositeDisposable} = require 'atom'
{MessagePanelView, LineMessageView, PlainMessageView} = require 'atom-message-panel'

spawn = require('child_process').spawn
recursive = require('recursive-readdir')
fs = require 'fs'
path = require 'path'
os = require 'os'
giphy = require( 'giphy' )( 'dc6zaTOxFJmzC' )
process = require('process')
smalltalk = require('smalltalk')

module.exports = Okpackage =
  packageName: require('../package.json').name

  spawnOk: (test, args) ->
    flags = ['ok']

    if(args?)
      if(args.submit?)
        flags.push '--submit'
    else if(test != 'all-tests')
      flags.push '-q'
      flags.push test


    # Override @python with path to python3 binary
    if process.env.PYTHONPATH?
      @python = process.env.PYTHONPATH
    else if os.platform() == 'darwin'
      @python = "/usr/local/bin/python3"
    else
      alert 'I don\'t know where your python is :\'-('

    ok = spawn(@python, flags, cwd: atom.project.getPaths()[0])

    # ok.stdout.on 'data', (data) =>
    #   @messages.add new PlainMessageView
    #     message: data
    #     raw: false
    #   console.log 'stdout: ' + data
    #   return
    ok.stderr.on 'data', (data) ->
      console.log 'stderr: ' + data
      return
    chunk = ''

    ok.stdout.on 'data', (data) ->
      chunk += data
      if chunk.indexOf('bCourses email') > -1
        console.log 'email required'
        smalltalk.prompt('Question', 'bCourses email?').then((value) ->
          ok.stdin.write value+'\n'
        )

    ok.on 'close', (code) =>
      # console.log 'child process exited with code ' + code
      summary = chunk.slice(chunk.indexOf('Test summary') + 'Test summary'.length, chunk.indexOf('Back up'))

      @messages.setTitle('Ok: ' + summary)

      word = 'fail'

      if chunk.indexOf('No cases failed') > -1
        word = 'success'

      console.log word

      giphy.random {'tag':word}, (err, results) =>
        url = results.data.image_url
        # url = url.slice(0, url.length - 1)
        @messages.clear()
        @messages.add new PlainMessageView
          message: "<div>" + chunk.replace(/\r?\n/g, "<br />") + "</div>" + "<img src=" + url + " />"
          raw: true
          className: 'okpackage'
      return

  activate: ->
    @cwd = atom.project.getPaths()[0]

    try
      fs.statSync path.join @cwd, 'ok'

      @okpackageView = new OkpackageView()
      @modalPanel = atom.workspace.addModalPanel(item: @okpackageView.getElement(), visible: false)

      @messages = new MessagePanelView
        title: 'OK tests'

      @messages.attach()

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

      @subscriptions.add atom.commands.add 'atom-workspace',
        'okpackage:toggle': => @toggle()

      @onNewTask 'submit', {submit:true}
      @onNewTask 'all-tests'

      files = fs.readdirSync @cwd

      okFile = path.join @cwd, (files.filter (file) -> file.indexOf('.ok') > -1 and !(file.indexOf('_') > -1))[0]
      okFileTests = (JSON.parse fs.readFileSync okFile, encoding: 'utf8').tests

      @onNewTask test.slice(test.indexOf(':') + 1) for test, type of okFileTests when type == "doctest"

      try
        fs.statSync path.join @cwd, 'tests'
        files = fs.readdirSync path.join @cwd, 'tests'

        testFiles = files.filter (file) -> file.indexOf('.py') > -1 and !(file.indexOf('__') > -1)

        @onNewTask test.replace '.py', '' for test in testFiles
      catch err
        # file doesn't exist, do nothing
        console.log 'no tests directory'
    catch err
      # ok file doesn't exist, do nothing
      console.log 'no ok in project'

  deactivate: ->
    @subscriptions.dispose()

  toggle: ->
    # console.log 'Toggled!'
    #
    # if @modalPanel.isVisible()
    #   @modalPanel.hide()
    # else
    #   @modalPanel.show()

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
