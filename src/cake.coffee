# `cake` is a simplified version of Make (Rake, Jake) for CoffeeScript.

fs:       require 'fs'
path:     require 'path'
coffee:   require 'coffee-script'

tasks: {}

# Mixin the Cake functionality.
process.mixin {

  # Define a task with a name, a description, and the action itself.
  task: (name, description, action) ->
    tasks[name]: {name: name, description: description, action: action}

  # Invoke another task in the Cakefile.
  invoke: (name) ->
    tasks[name].action()
}

# Display the list of Cake tasks.
print_tasks: ->
  for name, task of tasks
    spaces: 20 - name.length
    spaces: if spaces > 0 then (' ' for i in [0..spaces]).join('') else ''
    puts "cake " + name + spaces + ' # ' + task.description

# Running `cake` runs the tasks you pass asynchronously (node-style), or
# prints them out, with no arguments.
exports.run: ->
  path.exists 'Cakefile', (exists) ->
    throw new Error('Cakefile not found in ' + process.cwd()) unless exists
    args: process.ARGV[2...process.ARGV.length]
    fs.readFile('Cakefile').addCallback (source) ->
      eval coffee.compile source
      return print_tasks() unless args.length
      for arg in args
        throw new Error('No such task: "' + arg + '"') unless tasks[arg]
        tasks[arg].action()

