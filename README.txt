Monday, September 2, 2024

How to Run BabloApp
Connect to cloud
Execute ssha
DigitalOcean account: use Google
Code lives in /home/anton

Run server
Execute nodemon app.js inside server directory
Local server address: http://localhost:3000
Auth header: Bearer token
Most of routes protected by token: everything below use(verifyToken) in app.js

Run Docker
[Optional] Clean cache: docker system prune -a
Run the image: docker-compose up —build
Server runs on :5001
Database user: anton
Database port: 5432
netstat -vanp tcp | grep  5432
Stop docker: docker-compose down -v
Nuke Docker on Ubuntu
docker-compose down -v —remove-orphans
docker system prune --all —volumes

SSL


Accounts
Register: http --form POST localhost:3000/users/register username='anton9' password='yoyoyo'
Login: http GET localhost:3000/users/login username='anton12' password=‘yoyoyo'
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

