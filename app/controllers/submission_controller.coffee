db = require "#{RootPath}/app/models"
config = require 'config'
Promise = require 'bluebird'
moment = require 'moment'
co = require 'co'
path = require 'path'
request = require 'request'
request = request.defaults(jar: true)
mkdirp = require 'mkdirp'
nodemailer = require('nodemailer')
ses = require('nodemailer-ses-transport')
jade = require 'jade'

getRequest = Promise.promisify request.get
postRequest = Promise.promisify request.post

CSV = require('csv-string')

fs = require('fs')
openFile = Promise.promisify fs.open, fs
closeFile = Promise.promisify fs.close, fs
writeFile = Promise.promisify fs.write, fs

# mail transporter setup
transporter = nodemailer.createTransport ses {
  accessKeyId: config.aws.accessKeyId
  secretAccessKey: config.aws.secretAccessKey
}

class SubmissionController
  # helper method
  randomToken = (len=8) ->
    chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    charlen = chars.length
    getRandomInt = (min, max) ->
        Math.floor(Math.random() * (max - min + 1)) + min
    ([0...len].map () -> chars[getRandomInt(0, charlen - 1)]).join("")

  moveUploadedFile = Promise.method (obj, dest, make_thumb = true, crop_to_square = true) ->
    # obj validation check
    if obj? && typeof obj == 'string' # path를 바로 넘겨준것
      path = obj
      return path.resolve RootPath, obj

    if !(obj? && obj.path? && obj.size? && obj.name? && obj.type? && obj.size > 0)
      return null

    # multipart로 올라온 파일을 적절한 위치로 옮긴다.
    if dest?
      dir = path.dirname(dest)
      promise = Promise.promisify(mkdirp)(dir)
    else
      # 폴더 위치 및 파일 이름은 날짜를 기준으로 생성한다.
      # ex: 2014.7.27 14:21(unix timestamp: 1406438508)에
      # 올라온 파일이면 directory는 uploads/14/7/27/14/[randomhex]_1406438508.[ext]
      now = new Date()
      dir = path.join RootPath, "uploads", "#{now.getYear()-100}", "#{now.getMonth()+1}", "#{now.getDate()}", "#{now.getHours()}"
      dest = path.join dir, "#{randomToken()}_#{now.getTime()}#{path.extname(obj.path)}"
      promise = if fs.existsSync(dir) then Promise.resolve() else Promise.promisify(mkdirp)(dir)

    promise.then () ->
      Promise.promisify(fs.readFile)(obj.path)
    .then (data) ->
      Promise.promisify(fs.writeFile)(dest, data)
      path.sep + (path.relative RootPath, dest)

  driver: Multiparted (req, res, next) ->
    co ->
      license_copy_path = yield moveUploadedFile req.files?.license

      # locale sanitize
      locale = req.body.locale.replace("-", "_").toLowerCase()
      if locale.indexOf("hans") >= 0 || locale.indexOf("cn") >= 0
        locale = "zh_hans"
      else if locale.indexOf("hant") >= 0 || locale.indexOf("hk") >= 0
        locale = "zh_hant"
      else
        locale = "en"

      yield db.Submission.create
        type: 1
        name: req.body.name
        phone: ([req.body.hk_phone, req.body.cn_phone].filter (x) -> x?.length > 0).join(" / ")
        email: req.body.email
        license_copy: license_copy_path
        car_model: req.body.model
        car_type: req.body.carownership
        car_year: req.body.year
        car_brand: req.body.brand
        locale: locale
      res.type('text/html').send "<script>alert('thank you!'); history.go(-1)</script>"

    .catch (err) ->
      res.status(500).json message: err.message

  driver_requests: (req, res, next) ->
    co ->
      per_page = parseInt(req.query.per_page) || 20
      page = parseInt(req.query.page) || 1

      results = yield db.Submission.findAndCountAll
        where:
          type: 1
        limit: per_page
        offset: (page-1)*per_page

      driver_requests = results.rows
      total_count = results.count
      total_page = Math.ceil results.count / per_page

      res.send {
        driver_requests: driver_requests,
        total_count: total_count, total_page: total_page
      }

    .catch (err) ->
      res.status(500).json message: err.message

  partner: (req, res, next) ->
    co ->
      yield db.Submission.create
        type: 0
        name: req.body.name
        phone: req.body.mobile
        email: req.body.email
        company_address: req.body.company_addr
        company_name: req.body.company_name
      res.send ok: true
    .catch (err) ->
      res.status(500).json message: err.message

  corp: (req, res, next) ->
    co ->
      response = yield getRequest "#{config.api.host}/corporate/signup_csrf"
      csrftoken = response.body

      params =
        locale: req.body.prefLang
        sz_addresses: ""
        hk_addresses: ""
        website: req.body.companyWeb
        business_name: req.body.companyName
        email: req.body.delegateEmail
        phone: req.body.delegatePhone
        name: req.body.delegateName

      [response, body] = postRequest "#{config.api.host}/corporate/signup_request?_csrf=#{csrftoken}", form: params
      #res.type("application/json").send body
      res.send ok: true
    .catch (err) ->
      res.status(500).json message: err.message

  inquiry: (req, res, next) ->
    co ->
      submission =
        name: req.body.name
        email: req.body.email
        phone: req.body.phone
        content: req.body.content
      email_html = jade.compileFile("./app/views/homepage_inquiry.jade")(submission)

      params =
        from: config.email.from
        to: config.email.to
        subject: "[easiway] geteasiway.com support 문의메일"
        html: email_html

      setTimeout ->
        transporter.sendMail(params)
      , 0

      res.type('text/html').send "<script>alert('Thank you for your contact'); window.location='http://geteasiway.com/support';</script>"
    .catch (err) ->
      res.status(500).json message: err.message

  # this is for ride conference
  rides: Multiparted (req, res, next) ->
    co ->
      pitch_deck_path = yield moveUploadedFile req.files?.pitch_deck

      #add csv row
      row = [
        req.body.service.name, req.body.service.url,
        req.body.company.name, req.body.company.founded, req.body.company.funding,
        req.body.explain.text, pitch_deck_path,
        req.body.contact.name, req.body.contact.email
      ]

      csv_row = CSV.stringify row

      fd = yield openFile path.join(RootPath, "rides_submission.csv"), 'a'
      yield writeFile(fd, csv_row)
      yield closeFile(fd)

      res.redirect 'http://rides.easi-way.com/after_apply.html#thankyou'
    .catch (err) ->
      res.status(500).json message: err.message

module.exports = new SubmissionController

# vim: set ts=2 sw=2 :
