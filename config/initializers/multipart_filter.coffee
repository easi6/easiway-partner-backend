multipart = require 'connect-multiparty'
Multiparted = () ->
  [].concat.apply [multipart()], arguments
global["Multiparted"] = Multiparted
module.exports = Multiparted
