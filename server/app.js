const express = require('express');
const logger = require('morgan');
const cors = require('cors');
const auth = require('./routes/auth');
const users = require('./routes/users');
const linkEvents = require('./routes/linkEvents');
const linkTokens = require('./routes/linkTokens');
const items = require('./routes/items');
const { errorHandler } = require('./middleware');
const path = require('path'); // Add this line

const app = express();
const PORT = process.env.PORT || 3000;

// Serve static files
app.use('/.well-known', express.static(path.join(__dirname, 'static')));

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
// The rest of routes require token
app.use('/users', users);
app.use('/items', items);

app.use((err, req, res, next) => {
  console.error('Error caught:', err);
  errorHandler(err, req, res, next);
});
