const http = require('http');

const data = JSON.stringify({
  username: 'admin',
  password: 'password'
});

const options = {
  hostname: 'localhost',
  port: 8080,
  path: '/v1/auth/login',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(data)
  }
};

const req = http.request(options, res => {
  let responseData = '';
  res.on('data', d => {
    responseData += d;
  });
  res.on('end', () => {
    console.log("Login Status:", res.statusCode);
    if(res.statusCode !== 200) {
        console.log("Login Response:", responseData);
        return;
    }
    const json = JSON.parse(responseData);
    const token = json.token;
    console.log("Got Token");

    const getOptions = {
        hostname: 'localhost',
        port: 8080,
        path: '/v1/departments',
        method: 'GET',
        headers: {
            'Authorization': 'Bearer ' + token
        }
    };
    const req2 = http.request(getOptions, res2 => {
        let data2 = '';
        res2.on('data', d => data2 += d);
        res2.on('end', () => console.log("Departments Response:", data2.substring(0, 500)));
    });
    req2.end();
  });
});

req.on('error', error => {
  console.error(error);
});

req.write(data);
req.end();
