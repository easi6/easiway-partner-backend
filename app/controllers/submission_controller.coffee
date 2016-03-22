db = require "#{RootPath}/app/models"
config = require 'config'
Promise = require 'bluebird'
moment = require 'moment'
co = require 'co'
path = require 'path'

class SubmissionController
  # helper method
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
      dest = path.join dir, "#{utils.randomToken()}_#{now.getTime()}#{path.extname(obj.path)}"
      promise = if fs.existsSync(dir) then Promise.resolve() else Promise.promisify(mkdirp)(dir)

    promise.then () ->
      Promise.promisify(fs.readFile)(obj.path)
    .then (data) ->
      Promise.promisify(fs.writeFile)(dest, data)
      path.sep + (path.relative RootPath, dest)

  driver: Multiparted (req, res, next) ->
    co ->
      license_copy_path = yield moveUploadedFile req.files?.license
      yield db.Submission.create
        type: 1
        name: req.body.name
        phone: ([req.body.hk_phone, req.body.cn_phone].filter (x) -> x?.length > 0).join(" / ")
        email: req.body.email
        license_copy: license_copy_path
      res.send ok: true
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

module.exports = new SubmissionController

# vim: set ts=2 sw=2 :

