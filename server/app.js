const express = require('express');
const logger = require('morgan');
const cors = require('cors');
const { authenticateJwt, errorHandler } = require('./middleware');

const { noAuthRouter, authRouter } = require('./routes');

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

app.use(noAuthRouter);
app.use(authenticateJwt);
app.use(authRouter);

app.use(errorHandler);
