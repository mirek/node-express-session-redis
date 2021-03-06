module.exports = (grunt) ->
  grunt.loadNpmTasks 'grunt-mocha-test'
  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-watch'

  grunt.initConfig
    pkg: grunt.file.readJSON("package.json")

    coffee:
      compile:
        files:
          'lib/index.js': 'src/index.coffee'

    watch:
      coffee:
        files: ['src/**/*.coffee'],
        tasks: ['coffee']

    mochaTest:
      test:
        options:
          reporter: 'spec'
          require: [
            'coffee-script'
          ]
        src: ['spec/**/*.coffee']

  grunt.registerTask 'test', ['mochaTest']
  grunt.registerTask "compile", ["coffee"]
  grunt.registerTask "default", ["compile"]
