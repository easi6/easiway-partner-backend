var fs = require('fs');

//같은 디렉토리에 있는 database.json으로부터 설정을 가져옴
database = JSON.parse(fs.readFileSync("config/database.json"))

module.exports =
  {
    "database": database["development"],
    "host": {
      "protocol": "http", // or "https"
      "name": "localhost",
      "port": 9900
    },
  }

