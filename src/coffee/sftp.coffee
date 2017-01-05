_ = require 'underscore'
Promise = require 'bluebird'
fs = Promise.promisifyAll require('fs')
{Sftp} = require 'sphere-node-utils'

fsExistsAsync = (path) ->
  new Promise (resolve, reject) ->
    fs.exists path, (exists) ->
      if exists
        resolve(true)
      else
        resolve(false)

module.exports = class

  ###*
   * @constructor
   * Initialize {Sftp} client
   * @param {Object} [options] Configuration for {Sftp}
  ###
  constructor: (options = {}) ->
    {host, username, password, @sourceFolder, @targetFolder, @fileRegex, @logger} = options
    # TODO: validate options
    @sftpClient = new Sftp
      host: host
      username: username
      password: password
      logger: @logger

  download: (tmpFolder) ->
    fsExistsAsync(tmpFolder)
    .then (exists) =>
      if exists
        Promise.resolve()
      else
        @logger.debug 'Creating new tmp folder'
        fs.mkdirAsync tmpFolder
    .then => @sftpClient.openSftp()
    .then (sftp) =>
      @logger.debug 'New connection opened'
      @_sftp = sftp
      @sftpClient.downloadAllFiles(sftp, tmpFolder, @sourceFolder, @fileRegex)
    .then -> fs.readdirAsync(tmpFolder)
    .then (files) ->
      Promise.resolve _.filter files, (fileName) ->
        switch
          when fileName.match /\.csv$/i then true
          when fileName.match /\.xml$/i then true
          else false
    .finally =>
      # TODO: # use .using() + .disposer() to close connection
      @logger.debug 'Closing connection'
      @sftpClient.close(@_sftp)

  finish: (originalFileName, renamedFileName) ->
    @sftpClient.openSftp()
    .then (sftp) =>
      @logger.debug 'New connection opened'
      @_sftp = sftp
      @logger.debug "Renaming file #{originalFileName} to #{renamedFileName} on the remote server"
      @sftpClient.safeRenameFile(sftp, "#{@sourceFolder}/#{originalFileName}", "#{@targetFolder}/#{renamedFileName}")
    .then -> Promise.resolve()
    .finally =>
      # TODO: # use .using() + .disposer() to close connection
      @logger.debug 'Closing connection'
      @sftpClient.close(@_sftp)
