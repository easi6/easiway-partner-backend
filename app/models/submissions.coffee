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
    我是易路的Euna!

    感謝您申請成為易路平台的私人司機。

    這需要一些時間，但我們會努力工作，讓您盡快加入我們，成為我們的合作夥伴！

    我們會在六月給您最新的答復。

    您誠摯的，
    Euna
    """
    zh_hans: """
    尊敬的%{user_name}，
    我是易路的Euna!

    感谢您申请成为易路平台的私人司机。

    这需要一些时间，但我们会努力工作，让您尽快加入我们，成为我们的合作伙伴！

    我们会在六月给您最新的答复。

    您诚挚的，
    Euna
    """
    en: """
    Dear %{user_name},
    My name is Euna of Easiway!

    Thank you for applying as a private driver for Easiway.

    This may take a while but we are working hard to let you drive with us as soon as possible!

    We will give you an update in June.

    Best,
    Euna
    """

  Submission.afterCreate (submission, options) ->
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
      text: mail_texts[submission.locale]

    Promise.join(
      transporter.sendMail(param_to_easiway),
      transporter.sendMail(param_to_driver)
    , ->
      return submission
    ).catch (err) ->
      console.log err
      console.error err.stack
      throw err


  return Submission
