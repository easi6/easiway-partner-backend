Promise = require 'bluebird'
nodemailer = require('nodemailer')
ses = require('nodemailer-ses-transport')
jade = require 'jade'
config = require 'config'

module.exports = (sequelize, DataTypes) ->
  Submission = sequelize.define 'Submission',
    # attributes
      type:
        type: DataTypes.INTEGER
        allowNull: false
        defaultValue: 0 # 0 means company 1 means private driver
      name: DataTypes.STRING
      phone: DataTypes.STRING
      email: DataTypes.STRING
      company_address: DataTypes.STRING
      company_name: DataTypes.STRING
      license_copy: DataTypes.STRING
    ,
      underscored: true
      freezeTableName: true
      tableName: "submissions"

      getterMethods:
        _model_name: ->
          @Model.name

  # mail transporter setup
  transporter = nodemailer.createTransport ses {
    accessKeyId: config.aws.accessKeyId
    secretAccessKey: config.aws.secretAccessKey
  }

  Submission.afterCreate (submission, options) ->
    if submission.type == 0
      subject = "Partner company request submission"
      email_html = jade.compileFile("./app/views/partner_company_request.jade")(submission)
    else if submission.type == 1
      subject = "Private driver request submission"
      email_html = jade.compileFile("./app/views/private_driver_request.jade")(submission)

    param =
      from: "Easiway <noreply@easi-way.com>"
      to: "info@easi-way.com"
      subject: subject
      html: email_html

    transporter.sendMail param, (err, info) ->
      if err?
        return console.dir err
      console.dir info

  return Submission
