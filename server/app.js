const express = require('express');
const logger = require('morgan');
const cors = require('cors');
const usersRoute = require('./routes/users');
const { errorHandler } = require('./middleware');

const app = express();
const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log('Server Listening on PORT:', PORT);
});

app.use(logger('dev'));
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: false }));

app.get('/status', (request, response) => {
  const status = {
    Status: 'Running',
  };

  response.send(status);
});

app.use('/users', usersRoute);

//app.use(errorHandler);
