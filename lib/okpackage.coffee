OkpackageView = require './okpackage-view'
{CompositeDisposable} = require 'atom'

spawn = require('child_process').spawn
recursive = require('recursive-readdir')


module.exports = Okpackage =
  okpackageView: null
  modalPanel: null
  subscriptions: null

  activate: (state) ->
    @okpackageView = new OkpackageView(state.okpackageViewState)
    @modalPanel = atom.workspace.addModalPanel(item: @okpackageView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'okpackage:toggle': => @toggle()

    @tests = []

    thisser = this

    recursive atom.project.getPaths()[0], (err,files) ->
      thisser.tests = require i for i in files.filter((file) ->
        file.indexOf('.ok') > -1 and !(file.indexOf('_') > -1)
      )
      console.log thisser.tests


  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @okpackageView.destroy()

  serialize: ->
    okpackageViewState: @okpackageView.serialize()

  toggle: ->
    console.log 'Okpackage was toggled!'
    # TODO FIX!!!
    ok = spawn('/Users/maxjohansen/anaconda3/bin/python', [
      'ok'
    ], cwd: atom.project.getPaths()[0])

    thisser = this
    ok.stdout.on 'data', (data) ->
      thisser.okpackageView.setOutput(data)
      console.log 'stdout: ' + data
      return
    ok.stderr.on 'data', (data) ->
      console.log 'stderr: ' + data
      return
    ok.on 'close', (code) ->
      console.log 'child process exited with code ' + code
      return

    if @modalPanel.isVisible()
      @modalPanel.hide()
    else
      @modalPanel.show()
