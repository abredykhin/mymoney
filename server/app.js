const express = require('express');
const logger = require('morgan');
const cors = require('cors');
const auth = require('./routes/auth');
const users = require('./routes/users');
const linkEvents = require('./routes/linkEvents');
const linkTokens = require('./routes/linkTokens');
const items = require('./routes/items');
const { errorHandler, verifyToken } = require('./middleware');

const app = express();
const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log('Server Listening on PORT:', PORT);
});

app.use(logger('dev'));
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: false }));
app.disable('etag');

app.get('/status', (request, response) => {
  const status = {
    Status: 'Running',
  };

  response.send(status);
});

app.use('/users', auth);
app.use('/link-event', linkEvents);
app.use('/link-token', linkTokens);
app.use(errorHandler);
app.use(verifyToken);
// The rest of routes require token
app.use('/users', users);
app.use('/items', items);
