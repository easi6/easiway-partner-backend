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
      locale: DataTypes.STRING
      car_model: DataTypes.STRING
      car_brand: DataTypes.STRING
      car_year: DataTypes.INTEGER
      car_type: DataTypes.STRING # car owned type
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

  # mail text to drivers
  mail_subjects =
    zh_hant: "感謝您申請易路平台司機"
    zh_hans: "感谢您申请易路平台司机"
    en: "Thank you for applying to be an Easiway driver"

  mail_texts =
    zh_hant: """
    尊敬的%{user_name}，
    易路團隊歡迎您！
    感謝您申請成為易路平台的私人司機。
    如果有任何的更新變動，我們會儘快通知您。
    
    謹致最好的問候！
    易路團隊
    """
    zh_hans: """
    尊敬的%{user_name}，
    易路团队欢迎您！
    感谢您申请成为易路平台的私人司机。
    如果有任何的更新变动，我们会尽快通知您。
    
    谨致最好的问候！
    易路团队
    """
    en: """
    Dear %{user_name},
    This is Easiway!
    Thank you for applying as a private driver for Easiway.
    We will let you know if there is an update.
    
    Best,
    Easiway Team
    """

  Submission.afterCreate (submission, options, done) ->
    if submission.type == 0
      subject = "Partner company request submission"
      email_html = jade.compileFile("./app/views/partner_company_request.jade")(submission)
    else if submission.type == 1
      subject = "Private driver request submission"
      email_html = jade.compileFile("./app/views/private_driver_request.jade")(submission)

    param_to_easiway =
      from: config.email.from
      to: config.email.to
      subject: subject
      html: email_html

    param_to_driver =
      from: config.email.to
      to: submission.email
      subject: mail_subjects[submission.locale]
      text: mail_texts[submission.locale].replace("%{user_name}", submission.name)

    transporter.sendMail(param_to_easiway)
    transporter.sendMail(param_to_driver)
    done()

  return Submission
