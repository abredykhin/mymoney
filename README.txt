Monday, September 2, 2024

How to Run BabloApp
Connect to cloud
Execute ssha
DigitalOcean account: use Google

Run server
Execute nodemon app.js inside server directory
Local server address: http://localhost:3000
Auth header: Bearer token
Most of routes protected by token: everything below use(verifyToken) in app.js

Accounts
Register: http --form POST localhost:3000/users/register username='<username>' password='<password>'
Login: http GET localhost:3000/users/login username='<username>' password='<password>'
Pass token: https -A bearer -a token pie.dev/bearer
iOS
By default on simulator, server is localhost
Controlled by Client+Extensions
Auth and noAuth clients - send or not auth headers


servers:
  - url: http://babloapp.com:5001
    description: Main (production) server
  - url: http://localhost:3000
    description: Localhost dev server

