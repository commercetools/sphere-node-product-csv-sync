'use strict'

module.exports = (grunt) ->
  # project configuration
  grunt.initConfig
    # load package information
    pkg: grunt.file.readJSON 'package.json'

    meta:
      banner: "/* ===========================================================\n" +
        "# <%= pkg.name %> - v<%= pkg.version %>\n" +
        "# ==============================================================\n" +
        "# Copyright (c) 2014 <%= pkg.author.name %>\n" +
        "# Licensed under the MIT license.\n" +
        "*/\n"

    coffeelint:
      options: grunt.file.readJSON('node_modules/sphere-coffeelint/coffeelint.json')
      default: ["Gruntfile.coffee", "src/**/*.coffee"]

    clean:
      default: "lib"
      test: "test"

    coffee:
      options:
        bare: true
      default:
        files: grunt.file.expandMapping(['**/*.coffee'], 'lib/',
          flatten: false
          cwd: 'src/coffee'
          ext: '.js'
          rename: (dest, matchedSrcPath) ->
            dest + matchedSrcPath
          )
      test:
        files: grunt.file.expandMapping(['**/*.spec.coffee'], 'test/',
          flatten: false
          cwd: 'src/spec'
          ext: '.spec.js'
          rename: (dest, matchedSrcPath) ->
            dest + matchedSrcPath
          )
      testhelper:
        files: grunt.file.expandMapping(['**/testhelpers.coffee'], 'test/',
          flatten: false
          cwd: 'src/spec'
          ext: '.js'
          rename: (dest, matchedSrcPath) ->
            dest + matchedSrcPath
          )

    concat:
      options:
        banner: "<%= meta.banner %>"
      default:
        expand: true
        flatten: true
        cwd: "lib"
        src: ["*.js"]
        dest: "lib"
        ext: ".js"

    # watching for changes
    watch:
      default:
        files: ["src/coffee/*.coffee"]
        tasks: ["build"]
      test:
        files: ["src/**/*.coffee"]
        tasks: ["test"]
      unittest:
        files: ["src/**/*.coffee"]
        tasks: ["test"]

    shell:
      options:
        stdout: true
        stderr: true
        failOnError: true
      jasmine:
        command: "jasmine-node --verbose --captureExceptions test"
      coverage:
        command: "istanbul cover jasmine-node --captureExceptions test && cat ./coverage/lcov.info | ./node_modules/coveralls/bin/coveralls.js && rm -rf ./coverage"
      publish:
        command: 'npm publish'

    bump:
      options:
        files: ['package.json']
        updateConfigs: ['pkg']
        commit: true
        commitMessage: 'Bump version to %VERSION%'
        commitFiles: ['-a']
        createTag: true
        tagName: 'v%VERSION%'
        tagMessage: 'Version %VERSION%'
        push: true
        pushTo: 'origin'
        gitDescribeOptions: '--tags --always --abbrev=1 --dirty=-d'

  # load plugins that provide the tasks defined in the config
  grunt.loadNpmTasks "grunt-coffeelint"
  grunt.loadNpmTasks "grunt-contrib-clean"
  grunt.loadNpmTasks "grunt-contrib-coffee"
  grunt.loadNpmTasks "grunt-contrib-concat"
  grunt.loadNpmTasks "grunt-contrib-watch"
  grunt.loadNpmTasks "grunt-shell"
  grunt.loadNpmTasks 'grunt-bump'

  # register tasks
  grunt.registerTask "build", ["clean", "coffeelint", "coffee", "concat"]
  grunt.registerTask "coverage", ["build", "shell:coverage"]
  grunt.registerTask "test", ["build", "shell:jasmine"]
  grunt.registerTask 'release', 'Release a new version, push it and publish it', (target) ->
    target = 'patch' unless target
    grunt.task.run "bump-only:#{target}", 'test', 'bump-commit', 'shell:publish'
